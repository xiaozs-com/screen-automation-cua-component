#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: stop_private_runtime.sh <component-dir> <state-dir>" >&2
  exit 64
fi

component_dir="$(cd "$1" && pwd -P)"
state_dir="$2"
driver_path="$component_dir/CuaDriver.app/Contents/MacOS/cua-driver"
socket_path="$state_dir/cua-driver.sock"

if [[ -S "$socket_path" ]]; then
  "$driver_path" stop --socket "$socket_path"
fi

for _ in {1..50}; do
  [[ ! -S "$socket_path" ]] && exit 0
  sleep 0.1
done

echo "Cua Driver private socket did not stop cleanly" >&2
exit 1
