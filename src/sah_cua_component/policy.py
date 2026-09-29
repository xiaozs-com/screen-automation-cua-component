"""Fail-closed action policy for the Cua Driver adapter."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


class PolicyRefusal(ValueError):
    """Raised when a request would cross the component's authority boundary."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


READ_TOOLS = frozenset({"list_windows", "get_window_state"})
ACTION_TOOLS = frozenset({"click", "type_text", "press_key", "hotkey", "scroll"})
PIXEL_ACTION_TOOLS = frozenset({"click", "type_text", "press_key", "hotkey", "scroll"})


@dataclass(frozen=True)
class ActionPolicy:
    allow_foreground: bool = False

    def validate(self, tool: str, arguments: dict[str, Any]) -> dict[str, Any]:
        if tool not in READ_TOOLS | ACTION_TOOLS:
            raise PolicyRefusal("tool_not_allowed", f"组件不允许调用 Cua 工具：{tool}")
        if tool == "list_windows":
            return dict(arguments)

        target = arguments.get("target")
        if not isinstance(target, dict) or target.get("kind") != "window":
            raise PolicyRefusal("exact_window_required", "操作必须绑定明确的窗口目标")
        for key in ("pid", "window_id"):
            value = target.get(key)
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                raise PolicyRefusal("invalid_window_target", f"窗口目标缺少有效的 {key}")

        normalized = dict(arguments)
        normalized["target"] = {
            "kind": "window",
            "pid": target["pid"],
            "window_id": target["window_id"],
        }
        if tool == "get_window_state":
            normalized.pop("delivery_mode", None)
            normalized.pop("user_confirmed", None)
            return normalized

        delivery = str(normalized.get("delivery_mode") or "background")
        if delivery not in {"background", "foreground"}:
            raise PolicyRefusal("invalid_delivery_mode", "投递模式必须是 background 或 foreground")
        if delivery == "foreground":
            if not self.allow_foreground:
                raise PolicyRefusal("foreground_disabled", "组件策略未允许占用前台")
            if normalized.get("user_confirmed") is not True:
                raise PolicyRefusal("foreground_confirmation_required", "本次前台操作尚未获得用户确认")
        normalized["delivery_mode"] = delivery
        normalized.pop("user_confirmed", None)

        uses_pixel_coordinates = "x" in normalized or "y" in normalized
        if uses_pixel_coordinates:
            if not all(isinstance(normalized.get(key), (int, float)) for key in ("x", "y")):
                raise PolicyRefusal("invalid_pixel_target", "像素动作必须同时提供有效的 x 和 y")
            if not isinstance(normalized.get("capture_id"), str) or not normalized["capture_id"].strip():
                raise PolicyRefusal("capture_required", "像素动作必须绑定本次观察的 capture_id")
        if "element_index" in normalized:
            index = normalized["element_index"]
            if not isinstance(index, int) or isinstance(index, bool) or index < 0:
                raise PolicyRefusal("invalid_element_index", "element_index 必须是非负整数")
        if uses_pixel_coordinates and "element_index" in normalized:
            raise PolicyRefusal("ambiguous_action_target", "元素目标和像素目标不能同时提供")
        if not uses_pixel_coordinates and "element_index" not in normalized:
            raise PolicyRefusal("action_target_required", "动作必须提供 element_index 或绑定截图的坐标")
        return normalized

