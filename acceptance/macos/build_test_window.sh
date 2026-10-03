#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd -P)"
output="${1:-$repo_root/build/macos-acceptance/SafeTestWindow.app}"
contents="$output/Contents"
macos_dir="$contents/MacOS"

rm -rf "$output"
mkdir -p "$macos_dir"
swiftc "$repo_root/acceptance/macos/SafeTestWindow.swift" \
  -framework AppKit \
  -o "$macos_dir/SafeTestWindow"

cat > "$contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>SafeTestWindow</string>
  <key>CFBundleIdentifier</key><string>com.xiaozs.ScreenAutomationCuaTestWindow</string>
  <key>CFBundleName</key><string>Cua Safe Test Window</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST

codesign --force --sign - "$output"
printf '%s\n' "$output"
