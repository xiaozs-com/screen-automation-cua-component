from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class MacosContractTests(unittest.TestCase):
    def test_component_is_background_only_and_cross_arch(self) -> None:
        component = json.loads(
            (ROOT / "platforms/macos/component.json").read_text(encoding="utf-8")
        )
        self.assertEqual(component["id"], "cua-driver-macos")
        self.assertEqual(
            set(component["supported_runtime_platforms"]),
            {"macos-x64", "macos-arm64"},
        )
        self.assertFalse(component["runtime"]["foreground_fallback"])
        self.assertTrue(component["runtime"]["private_socket_required"])
        self.assertFalse(component["runtime"]["autostart"])
        self.assertFalse(component["runtime"]["telemetry"])
        self.assertFalse(component["runtime"]["update_check"])

    def test_upstream_lock_is_universal_and_exact(self) -> None:
        lock = json.loads(
            (ROOT / "upstream/cua-driver-0.32.0-macos-universal.lock.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(lock["platform"], "macos-universal")
        self.assertEqual(lock["upstream"]["version"], "0.32.0")
        self.assertEqual(set(lock["supported_architectures"]), {"x86_64", "arm64"})
        self.assertEqual(lock["bundle"]["identifier"], "com.trycua.driver")
        self.assertEqual(len(lock["asset"]["sha256"]), 64)

    def test_runtime_scripts_disable_external_state_and_require_private_socket(self) -> None:
        start = (ROOT / "runtime/macos/start_private_runtime.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("CUA_DRIVER_RS_TELEMETRY_ENABLED=false", start)
        self.assertIn("CUA_DRIVER_RS_UPDATE_CHECK=false", start)
        self.assertIn("--permission-mode bounded", start)
        self.assertIn("--socket", start)
        self.assertNotIn("autostart", start)
        self.assertNotIn("foreground", start)

    def test_workflow_is_manual_only_and_has_native_intel_job(self) -> None:
        workflow = (ROOT / ".github/workflows/build-macos.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("push:", workflow)
        self.assertIn("runs-on: macos-15-intel", workflow)
        self.assertIn("build_component.sh x86_64", workflow)


if __name__ == "__main__":
    unittest.main()
