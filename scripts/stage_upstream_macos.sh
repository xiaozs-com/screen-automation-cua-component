#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
lock_file="${1:-$repo_root/upstream/cua-driver-0.32.0-macos-universal.lock.json}"
cache_dir="${2:-$repo_root/build/upstream-cache}"
output_dir="${3:-$repo_root/build/staged-upstream-macos}"

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS is required" >&2; exit 1; }
[[ ! -e "$output_dir" ]] || { echo "refusing to overwrite: $output_dir" >&2; exit 1; }

read_lock() {
  /usr/bin/python3 - "$lock_file" "$1" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

asset_name="$(read_lock asset.name)"
asset_url="$(read_lock asset.url)"
asset_size="$(read_lock asset.size)"
asset_sha="$(read_lock asset.sha256)"
bundle_id="$(read_lock bundle.identifier)"
license_path="$(read_lock license_file.local_path)"
license_size="$(read_lock license_file.size)"
license_sha="$(read_lock license_file.sha256)"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
verify_file() {
  local path="$1" expected_size="$2" expected_sha="$3"
  [[ "$(stat -f %z "$path")" == "$expected_size" ]] || { echo "size mismatch: $path" >&2; exit 1; }
  [[ "$(sha256 "$path")" == "$expected_sha" ]] || { echo "SHA-256 mismatch: $path" >&2; exit 1; }
}

mkdir -p "$cache_dir" "$(dirname "$output_dir")"
asset_path="$cache_dir/$asset_name"
if [[ ! -f "$asset_path" ]]; then
  partial="$asset_path.partial"
  rm -f "$partial"
  curl --fail --location --proto '=https' --tlsv1.2 "$asset_url" --output "$partial"
  verify_file "$partial" "$asset_size" "$asset_sha"
  mv "$partial" "$asset_path"
fi
verify_file "$asset_path" "$asset_size" "$asset_sha"

license_full_path="$repo_root/$license_path"
verify_file "$license_full_path" "$license_size" "$license_sha"

tmp_dir="$(mktemp -d "$(dirname "$output_dir")/.stage-macos.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

tar -xzf "$asset_path" -C "$tmp_dir"
app_path="$tmp_dir/CuaDriver.app"
driver_path="$app_path/Contents/MacOS/cua-driver"
[[ -d "$app_path" && -x "$driver_path" ]] || { echo "expected CuaDriver.app is missing" >&2; exit 1; }

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$bundle_id" ]] || { echo "unexpected bundle id: $actual_bundle_id" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$app_path"
archs="$(lipo -archs "$driver_path")"
[[ " $archs " == *" x86_64 "* && " $archs " == *" arm64 "* ]] || { echo "driver is not universal: $archs" >&2; exit 1; }

cp "$license_full_path" "$tmp_dir/LICENSE"
cp "$lock_file" "$tmp_dir/UPSTREAM.lock.json"
mv "$tmp_dir" "$output_dir"
trap - EXIT

printf '{"version":"%s","platform":"macos-universal","output":"%s","sha256":"%s"}\n' \
  "$(read_lock upstream.version)" "$output_dir" "$asset_sha"
