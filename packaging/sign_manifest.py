from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path

from cryptography.hazmat.primitives import serialization


KEY_ID = "xiaozs-components-2026-01"


def canonical_manifest(value: dict) -> bytes:
    unsigned = {key: item for key, item in value.items() if key != "signature"}
    return json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--private-key-env", default="COMPONENT_SIGNING_PRIVATE_KEY")
    args = parser.parse_args()
    encoded = os.environ.get(args.private_key_env, "").strip()
    if not encoded:
        raise RuntimeError(f"missing signing secret: {args.private_key_env}")
    private = serialization.load_pem_private_key(encoded.encode("utf-8"), password=None)
    value = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    value["signature"] = {
        "algorithm": "ed25519",
        "key_id": KEY_ID,
        "value": base64.b64encode(private.sign(canonical_manifest(value))).decode("ascii"),
    }
    args.manifest.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
