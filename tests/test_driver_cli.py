from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from sah_cua_component.driver_cli import CuaDriverCli, DriverError, _safe_environment


class DriverCliTests(unittest.TestCase):
    def test_subprocess_environment_excludes_common_secrets(self) -> None:
        environment = _safe_environment()
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", environment)
        self.assertNotIn("OPENAI_API_KEY", environment)
        self.assertEqual(environment["CUA_DRIVER_RS_TELEMETRY_ENABLED"], "false")
        self.assertEqual(environment["CUA_DRIVER_RS_UPDATE_CHECK"], "false")

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

    def test_call_can_target_component_private_socket(self) -> None:
        calls = []

        def runner(command, timeout):
            calls.append(command)
            return subprocess.CompletedProcess(command, 0, '{"ok":true}', "")

        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "cua-driver"
            executable.write_bytes(b"test")
            socket = Path(directory) / "runtime.sock"
            CuaDriverCli(executable, socket_path=socket, runner=runner).call(
                "list_windows", {}
            )

        self.assertEqual(calls[0][1:4], ("call", "--socket", str(socket)))
        self.assertEqual(calls[0][4], "list_windows")


if __name__ == "__main__":
    unittest.main()
