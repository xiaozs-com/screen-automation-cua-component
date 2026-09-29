from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from sah_cua_component.driver_cli import CuaDriverCli, DriverError


class DriverCliTests(unittest.TestCase):
    def test_call_uses_compact_json_and_parses_object(self) -> None:
        calls = []

        def runner(command, timeout):
            calls.append((command, timeout))
            return subprocess.CompletedProcess(command, 0, '{"effect":"confirmed"}', "")

        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "cua-driver.exe"
            executable.write_bytes(b"test")
            result = CuaDriverCli(executable, runner=runner).call(
                "list_windows", {"on_screen_only": True}
            )

        self.assertEqual(result["effect"], "confirmed")
        self.assertEqual(calls[0][0][1:3], ("call", "list_windows"))
        self.assertEqual(json.loads(calls[0][0][3]), {"on_screen_only": True})

    def test_failure_preserves_bounded_diagnostic(self) -> None:
        def runner(command, timeout):
            return subprocess.CompletedProcess(command, 7, "", "background_unavailable")

        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "cua-driver.exe"
            executable.write_bytes(b"test")
            with self.assertRaisesRegex(DriverError, "background_unavailable"):
                CuaDriverCli(executable, runner=runner).call("list_windows", {})


if __name__ == "__main__":
    unittest.main()

