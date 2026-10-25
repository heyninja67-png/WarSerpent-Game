#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/workspace/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/workspace/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/workspace/.cache}
exec "${GODOT:-godot}" --headless --path "$PROJECT_ROOT" --script res://scripts/network/RoomServer.gd -- "${1:-24680}"
