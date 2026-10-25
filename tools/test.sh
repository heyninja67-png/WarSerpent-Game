#!/usr/bin/env bash
# Isolated user-data directory prevents tests from touching a real player's save.
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WARSERPENT_TEST_ROOT=$(mktemp -d /tmp/warserpent-flow-tests.XXXXXX)
export XDG_DATA_HOME="$WARSERPENT_TEST_ROOT/data"
export XDG_CONFIG_HOME="$WARSERPENT_TEST_ROOT/config"
export XDG_CACHE_HOME="$WARSERPENT_TEST_ROOT/cache"
GODOT=${GODOT:-godot}
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
cd "$PROJECT_ROOT"
"$GODOT" --headless --path "$PROJECT_ROOT" --editor --import --quit > "$WARSERPENT_TEST_ROOT/import.log" 2>&1
for suite in test_profile test_gameplay test_flow; do
    "$GODOT" --headless --path "$PROJECT_ROOT" --script "tests/$suite.gd" 2>&1 | tee "$WARSERPENT_TEST_ROOT/$suite.log"
done
python3 tools/test_network.py
printf 'Logs da execução: %s\n' "$WARSERPENT_TEST_ROOT"
