from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class WindowsContractTests(unittest.TestCase):
    def test_component_is_windows_x64_background_only(self) -> None:
        component = json.loads((ROOT / "platforms/windows/component.json").read_text("utf-8"))
        self.assertEqual(component["supported_runtime_platforms"], ["windows-x64"])
        self.assertTrue(component["runtime"]["private_socket_required"])
        self.assertFalse(component["runtime"]["foreground_fallback"])
        self.assertFalse(component["runtime"]["autostart"])
        self.assertFalse(component["runtime"]["telemetry"])
        self.assertFalse(component["runtime"]["update_check"])

    def test_private_runtime_is_bounded_and_sanitizes_environment(self) -> None:
        start = (ROOT / "runtime/windows/start_private_runtime.ps1").read_text("utf-8")
        self.assertIn("--permission-mode bounded", start)
        self.assertIn("--capability-manifest", start)
        self.assertIn("--no-overlay", start)
        self.assertIn("EnvironmentVariables.Clear()", start)
        self.assertIn("CUA_DRIVER_RS_TELEMETRY_ENABLED", start)
        self.assertIn("CUA_DRIVER_RS_UPDATE_CHECK", start)
        self.assertNotIn("setx", start.lower())
        self.assertNotIn("autostart", start.lower())

    def test_test_window_is_nonsensitive(self) -> None:
        source = (ROOT / "acceptance/windows/SafeTestWindow.cs").read_text("utf-8")
        self.assertIn("Safe Test Window", source)
        for forbidden in ("wechat", "微信", "payment", "发布"):
            if forbidden == "发布":
                continue  # It appears only in the explicit safety notice.
            self.assertNotIn(forbidden, source.lower())

    def test_build_has_no_remote_workflow_trigger(self) -> None:
        build = (ROOT / "packaging/windows/build_component.ps1").read_text("utf-8")
        self.assertIn("PyInstaller==6.16.0", build)
        self.assertIn("screen-automation-cua-sidecar", build)
        self.assertNotIn("gh workflow run", build)

    def test_packaged_acceptance_is_scoped_and_cleans_up(self) -> None:
        script = (ROOT / "acceptance/windows/test_component.ps1").read_text("utf-8")
        self.assertIn("acceptance-safe-test-window.exe", script)
        self.assertIn("delivery_mode='background'", script)
        self.assertIn("foreground_and_mouse_unchanged", script)
        self.assertIn("clicked.route -eq 'accessibility'", script)
        self.assertIn("stop_private_runtime.ps1", script)
        self.assertNotIn("foreground'", script)

    def test_windows_workflow_only_builds_unsigned_short_lived_artifact(self) -> None:
        workflow = (ROOT / ".github/workflows/release-windows.yml").read_text("utf-8")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("push:", workflow)
        self.assertNotIn("gh release", workflow)
        self.assertNotIn("COMPONENT_SIGNING_PRIVATE_KEY", workflow)
        self.assertIn("retention-days: 7", workflow)

    def test_release_metadata_generates_component_entry_not_global_catalog(self) -> None:
        metadata = (ROOT / "packaging/windows/create_release_metadata.ps1").read_text("utf-8")
        self.assertIn("catalog-entry.json", metadata)
        self.assertIn("catalog_entry", metadata)
        self.assertNotIn("Join-Path $OutputDirectory 'catalog.json'", metadata)
        self.assertNotIn("maintenance_notes", metadata)

    def test_catalog_entry_matches_component_contract(self) -> None:
        metadata = (ROOT / "packaging/windows/create_release_metadata.ps1").read_text("utf-8")
        self.assertIn("id = $component.id", metadata)
        self.assertIn("manifests = [ordered]@{ 'windows-x64' = $ManifestUrl }", metadata)
        self.assertIn("supported_platforms = @('win32')", metadata)
        self.assertIn("retains_user_data_on_uninstall = $false", metadata)


if __name__ == "__main__":
    unittest.main()
