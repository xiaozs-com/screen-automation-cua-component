"""Small, injectable client for the stable Cua Driver CLI surface."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any, Callable, Sequence


class DriverError(RuntimeError):
    pass


Runner = Callable[[Sequence[str], float], subprocess.CompletedProcess[str]]


def _default_runner(command: Sequence[str], timeout: float) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(command),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        check=False,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )


class CuaDriverCli:
    def __init__(
        self,
        executable: Path,
        *,
        runner: Runner = _default_runner,
        timeout_seconds: float = 30.0,
    ) -> None:
        self.executable = Path(executable)
        self.runner = runner
        self.timeout_seconds = float(timeout_seconds)

    def _run(self, arguments: Sequence[str], *, timeout: float | None = None) -> str:
        if not self.executable.is_file():
            raise DriverError(f"Cua Driver 入口不存在：{self.executable}")
        completed = self.runner(
            (str(self.executable), *arguments),
            self.timeout_seconds if timeout is None else float(timeout),
        )
        stdout = completed.stdout.strip()
        stderr = " ".join(completed.stderr.split())[-2000:]
        if completed.returncode != 0:
            detail = stderr or stdout or "没有诊断信息"
            raise DriverError(f"Cua Driver 调用失败（退出码 {completed.returncode}）：{detail}")
        return stdout

    def version(self) -> str:
        return self._run(("--version",), timeout=10)

    def doctor(self) -> dict[str, Any]:
        return self._parse_json(self._run(("doctor", "--json"), timeout=30))

    def call(self, tool: str, arguments: dict[str, Any]) -> dict[str, Any]:
        payload = json.dumps(arguments, ensure_ascii=False, separators=(",", ":"))
        return self._parse_json(self._run(("call", tool, payload)))

    @staticmethod
    def _parse_json(value: str) -> dict[str, Any]:
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError as exc:
            raise DriverError("Cua Driver 未返回有效 JSON") from exc
        if not isinstance(parsed, dict):
            raise DriverError("Cua Driver JSON 响应必须是对象")
        return parsed

