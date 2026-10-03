from __future__ import annotations

import io
import json
import unittest

from sah_cua_component import PROTOCOL_ID
from sah_cua_component.policy import ActionPolicy
from sah_cua_component.sidecar import MAX_MESSAGE_BYTES, SidecarService, serve


class FakeDriver:
    def __init__(self) -> None:
        self.calls = []

    def version(self):
        return "cua-driver 0.test"

    def doctor(self):
        return {"ok": True}

    def call(self, tool, arguments):
        self.calls.append((tool, arguments))
        return {"effect": "confirmed", "delivery": {"mode": arguments.get("delivery_mode")}}


class SidecarTests(unittest.TestCase):
    def test_health_reports_component_and_driver(self) -> None:
        response = SidecarService(FakeDriver()).dispatch(
            {"protocol": PROTOCOL_ID, "id": "1", "method": "health", "params": {}}
        )
        self.assertTrue(response["ok"])
        self.assertEqual(response["result"]["driver_version"], "cua-driver 0.test")
        self.assertFalse(response["result"]["foreground_enabled"])

    def test_click_is_policy_checked_before_driver_call(self) -> None:
        driver = FakeDriver()
        response = SidecarService(driver).dispatch({
            "protocol": PROTOCOL_ID,
            "id": "2",
            "method": "action.click",
            "params": {
                "target": {"kind": "window", "pid": 5, "window_id": 9},
                "element_index": 4,
                "snapshot_id": "snapshot-4",
            },
        })
        self.assertTrue(response["ok"])
        self.assertEqual(driver.calls[0][1]["delivery_mode"], "background")

    def test_unknown_method_is_rejected_without_driver_call(self) -> None:
        driver = FakeDriver()
        response = SidecarService(driver).dispatch(
            {"protocol": PROTOCOL_ID, "id": "3", "method": "shell.run", "params": {}}
        )
        self.assertFalse(response["ok"])
        self.assertEqual(response["error"]["code"], "method_not_allowed")
        self.assertEqual(driver.calls, [])

    def test_ndjson_server_survives_invalid_line(self) -> None:
        source = io.StringIO("not-json\n" + json.dumps({
            "protocol": PROTOCOL_ID, "id": "4", "method": "health", "params": {}
        }) + "\n")
        sink = io.StringIO()
        serve(SidecarService(FakeDriver(), policy=ActionPolicy()), source, sink)
        responses = [json.loads(line) for line in sink.getvalue().splitlines()]
        self.assertEqual(responses[0]["error"]["code"], "invalid_request")
        self.assertTrue(responses[1]["ok"])

    def test_oversized_request_is_rejected(self) -> None:
        source = io.StringIO("x" * (MAX_MESSAGE_BYTES + 1) + "\n")
        sink = io.StringIO()
        serve(SidecarService(FakeDriver()), source, sink)
        response = json.loads(sink.getvalue())
        self.assertEqual(response["error"]["code"], "invalid_request")


if __name__ == "__main__":
    unittest.main()
