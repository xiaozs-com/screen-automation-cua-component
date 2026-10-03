#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
arch="${1:-$(uname -m)}"
case "$arch" in
  x86_64) platform="macos-x64" ;;
  arm64) platform="macos-arm64" ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

[[ "$(uname -m)" == "$arch" ]] || { echo "native $arch runner required" >&2; exit 1; }

version="$(/usr/bin/python3 - "$repo_root/platforms/macos/component.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["version"])
PY
)"
work="$repo_root/build/macos-$arch"
upstream="$work/upstream"
package_root="$work/package"
dist="$repo_root/dist"

rm -rf "$work"
mkdir -p "$work" "$dist"
"$repo_root/scripts/stage_upstream_macos.sh" \
  "$repo_root/upstream/cua-driver-0.32.0-macos-universal.lock.json" \
  "$repo_root/build/upstream-cache" \
  "$upstream"

python3 -m venv "$work/venv"
"$work/venv/bin/python" -m pip install --disable-pip-version-check --upgrade pip
"$work/venv/bin/python" -m pip install --disable-pip-version-check 'PyInstaller==6.16.0' "$repo_root"
"$work/venv/bin/pyinstaller" --clean --noconfirm --onefile \
  --name screen-automation-cua-sidecar \
  "$repo_root/packaging/sidecar_entry.py"

mkdir -p "$package_root/runtime"
ditto "$upstream/CuaDriver.app" "$package_root/CuaDriver.app"
cp "$work/dist/screen-automation-cua-sidecar" "$package_root/"
cp "$repo_root/platforms/macos/component.json" "$package_root/component.json"
cp "$repo_root/licenses/CUA_DRIVER_LICENSE.md" "$package_root/LICENSE"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$package_root/"
cp "$repo_root/upstream/cua-driver-0.32.0-macos-universal.lock.json" "$package_root/UPSTREAM.lock.json"
cp "$repo_root/runtime/macos/start_private_runtime.sh" "$package_root/runtime/"
cp "$repo_root/runtime/macos/stop_private_runtime.sh" "$package_root/runtime/"
chmod 755 "$package_root/screen-automation-cua-sidecar" "$package_root/runtime/"*.sh

codesign --verify --deep --strict --verbose=2 "$package_root/CuaDriver.app"
file "$package_root/screen-automation-cua-sidecar" | grep -q "$arch"
"$package_root/screen-automation-cua-sidecar" --help >/dev/null

archive="$dist/screen-automation-cua-component-$version-$platform.zip"
rm -f "$archive"
ditto -c -k --keepParent "$package_root" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
printf '%s\n' "$archive"
