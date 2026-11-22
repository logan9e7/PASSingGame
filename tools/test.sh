#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p artifacts
"$GODOT_BIN" --headless --path . --editor --quit > artifacts/import.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' artifacts/import.log; then exit 1; fi
"$GODOT_BIN" --headless --path . --script tests/rules_test.gd > artifacts/rules.log 2>&1
cat artifacts/rules.log
"$GODOT_BIN" --headless --path . --quit-after 120 -- --practice > artifacts/smoke.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' artifacts/smoke.log; then exit 1; fi
python3 tools/network_test.py
