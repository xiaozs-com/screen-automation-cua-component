from __future__ import annotations

import unittest

from sah_cua_component.policy import ActionPolicy, PolicyRefusal


WINDOW = {"kind": "window", "pid": 42, "window_id": 88}


class ActionPolicyTests(unittest.TestCase):
    def test_element_click_defaults_to_background(self) -> None:
        result = ActionPolicy().validate(
            "click", {"target": WINDOW, "element_index": 3, "snapshot_id": "snap-1"}
        )
        self.assertEqual(result["delivery_mode"], "background")

    def test_element_index_requires_matching_snapshot(self) -> None:
        with self.assertRaises(PolicyRefusal) as raised:
            ActionPolicy().validate("click", {"target": WINDOW, "element_index": 3})
        self.assertEqual(raised.exception.code, "snapshot_required")

    def test_element_token_is_accepted_without_separate_snapshot(self) -> None:
        result = ActionPolicy().validate(
            "click", {"target": WINDOW, "element_token": "opaque-token"}
        )
        self.assertEqual(result["element_token"], "opaque-token")

    def test_desktop_target_is_rejected(self) -> None:
        with self.assertRaisesRegex(PolicyRefusal, "明确的窗口"):
            ActionPolicy().validate(
                "click",
                {"target": {"kind": "desktop", "display_id": "primary"}, "x": 1, "y": 2},
            )

    def test_pixel_click_requires_capture(self) -> None:
        with self.assertRaises(PolicyRefusal) as raised:
            ActionPolicy().validate("click", {"target": WINDOW, "x": 10, "y": 20})
        self.assertEqual(raised.exception.code, "capture_required")

    def test_pixel_click_accepts_capture(self) -> None:
        result = ActionPolicy().validate(
            "click", {"target": WINDOW, "x": 10, "y": 20, "capture_id": "cap-1"}
        )
        self.assertEqual(result["capture_id"], "cap-1")

    def test_foreground_is_disabled_by_default(self) -> None:
        with self.assertRaises(PolicyRefusal) as raised:
            ActionPolicy().validate(
                "click",
                {"target": WINDOW, "element_token": "token", "delivery_mode": "foreground", "user_confirmed": True},
            )
        self.assertEqual(raised.exception.code, "foreground_disabled")

    def test_foreground_requires_per_request_confirmation(self) -> None:
        with self.assertRaises(PolicyRefusal) as raised:
            ActionPolicy(allow_foreground=True).validate(
                "click", {"target": WINDOW, "element_token": "token", "delivery_mode": "foreground"}
            )
        self.assertEqual(raised.exception.code, "foreground_confirmation_required")

    def test_confirmed_foreground_removes_internal_confirmation_flag(self) -> None:
        result = ActionPolicy(allow_foreground=True).validate(
            "click",
            {"target": WINDOW, "element_token": "token", "delivery_mode": "foreground", "user_confirmed": True},
        )
        self.assertEqual(result["delivery_mode"], "foreground")
        self.assertNotIn("user_confirmed", result)


if __name__ == "__main__":
    unittest.main()
