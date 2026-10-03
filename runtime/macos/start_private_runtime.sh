#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: start_private_runtime.sh <component-dir> <state-dir> <capability-manifest>" >&2
  exit 64
fi

component_dir="$(cd "$1" && pwd -P)"
state_dir="$2"
manifest="$(cd "$(dirname "$3")" && pwd -P)/$(basename "$3")"
app_path="$component_dir/CuaDriver.app"
driver_path="$app_path/Contents/MacOS/cua-driver"
socket_path="$state_dir/cua-driver.sock"
pid_path="$state_dir/cua-driver.pid"

[[ -d "$app_path" ]] || { echo "CuaDriver.app not found" >&2; exit 1; }
[[ -x "$driver_path" ]] || { echo "cua-driver entry is not executable" >&2; exit 1; }
[[ -f "$manifest" ]] || { echo "capability manifest not found" >&2; exit 1; }

mkdir -p "$state_dir"
chmod 700 "$state_dir"
rm -f "$socket_path" "$pid_path"

export CUA_DRIVER_RS_TELEMETRY_ENABLED=false
export CUA_DRIVER_RS_UPDATE_CHECK=false

open -n -g "$app_path" --args serve \
  --socket "$socket_path" \
  --pid-file "$pid_path" \
  --permission-mode bounded \
  --capability-manifest "$manifest" \
  --approve-capability-manifest

for _ in {1..100}; do
  if [[ -S "$socket_path" ]]; then
    printf '%s\n' "$socket_path"
    exit 0
  fi
  sleep 0.1
done

echo "Cua Driver private socket did not become ready" >&2
exit 1
