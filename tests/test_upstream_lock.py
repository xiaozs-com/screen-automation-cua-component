from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCK_PATH = ROOT / "upstream" / "cua-driver-0.34.0-windows-x64.lock.json"


class UpstreamLockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))

    def test_release_is_exactly_pinned_to_windows_x64(self) -> None:
        self.assertEqual(self.lock["platform"], "windows-x64")
        self.assertEqual(self.lock["upstream"]["version"], "0.34.0")
        self.assertEqual(len(self.lock["upstream"]["commit"]), 40)
        self.assertIn("windows-x86_64-binary.zip", self.lock["asset"]["name"])

    def test_archive_allowlist_has_no_forbidden_payloads(self) -> None:
        names = set(self.lock["files"])
        self.assertEqual(
            names,
            {
                "cua-cursor-theme.exe",
                "cua-driver-uia.exe",
                "cua-driver.exe",
                "cua_driver_abi.h",
                "cua_driver_node_runtime.node",
                "cua_driver_sdk.dll",
            },
        )
        lowered = " ".join(names).lower()
        for forbidden in ("perception", "ffmpeg", "model", "workflow"):
            self.assertNotIn(forbidden, lowered)

        signature = self.lock["files"]["cua-driver.exe"]["authenticode"]
        self.assertEqual(signature["status"], "Valid")
        self.assertEqual(len(signature["signer_thumbprint"]), 40)

    def test_vendored_license_matches_lock(self) -> None:
        license_info = self.lock["license_file"]
        payload = (ROOT / license_info["local_path"]).read_bytes()
        self.assertEqual(len(payload), license_info["size"])
        self.assertEqual(hashlib.sha256(payload).hexdigest(), license_info["sha256"])


if __name__ == "__main__":
    unittest.main()
