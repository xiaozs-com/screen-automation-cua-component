"""NDJSON Sidecar that exposes a bounded subset of Cua Driver."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, TextIO

from . import PROTOCOL_ID, __version__
from .driver_cli import CuaDriverCli, DriverError
from .policy import ActionPolicy, PolicyRefusal


METHOD_TO_TOOL = {
    "windows.list": "list_windows",
    "window.observe": "get_window_state",
    "action.click": "click",
    "action.type_text": "type_text",
    "action.press_key": "press_key",
    "action.hotkey": "hotkey",
    "action.scroll": "scroll",
}


class SidecarService:
    def __init__(self, driver: CuaDriverCli, *, policy: ActionPolicy | None = None) -> None:
        self.driver = driver
        self.policy = policy or ActionPolicy()

    def dispatch(self, request: dict[str, Any]) -> dict[str, Any]:
        request_id = str(request.get("id") or "")
        if request.get("protocol") != PROTOCOL_ID:
            return self._error(request_id, "protocol_mismatch", "Sidecar 协议不匹配")
        method = str(request.get("method") or "")
        params = request.get("params", {})
        if not isinstance(params, dict):
            return self._error(request_id, "invalid_params", "params 必须是 JSON 对象")
        try:
            if method == "health":
                result = {
                    "component_version": __version__,
                    "driver_version": self.driver.version(),
                    "doctor": self.driver.doctor(),
                    "foreground_enabled": self.policy.allow_foreground,
                }
            else:
                tool = METHOD_TO_TOOL.get(method)
                if tool is None:
                    return self._error(request_id, "method_not_allowed", f"不支持的方法：{method}")
                result = self.driver.call(tool, self.policy.validate(tool, params))
            return {"protocol": PROTOCOL_ID, "id": request_id, "ok": True, "result": result}
        except PolicyRefusal as exc:
            return self._error(request_id, exc.code, str(exc))
        except (DriverError, TimeoutError) as exc:
            return self._error(request_id, "driver_unavailable", str(exc))

    @staticmethod
    def _error(request_id: str, code: str, message: str) -> dict[str, Any]:
        return {
            "protocol": PROTOCOL_ID,
            "id": request_id,
            "ok": False,
            "error": {"code": code, "message": message},
        }


def serve(service: SidecarService, source: TextIO, sink: TextIO) -> None:
    for raw_line in source:
        if not raw_line.strip():
            continue
        try:
            request = json.loads(raw_line)
            if not isinstance(request, dict):
                raise ValueError("请求必须是 JSON 对象")
            response = service.dispatch(request)
        except (json.JSONDecodeError, ValueError) as exc:
            response = SidecarService._error("", "invalid_request", str(exc))
        sink.write(json.dumps(response, ensure_ascii=False, separators=(",", ":")) + "\n")
        sink.flush()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver", required=True, type=Path)
    parser.add_argument("--allow-foreground", action="store_true")
    args = parser.parse_args(argv)
    service = SidecarService(
        CuaDriverCli(args.driver),
        policy=ActionPolicy(allow_foreground=args.allow_foreground),
    )
    serve(service, sys.stdin, sys.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

