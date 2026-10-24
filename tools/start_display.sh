#!/usr/bin/env bash
# Start a local X11 display for Godot screenshot/functional checks.
# No TCP listener is created; this is a local cloud-development helper.
set -euo pipefail
WARSERPENT_XVFB_ROOT="${WARSERPENT_XVFB_ROOT:-/workspace/toolchains/xvfb}"
WARSERPENT_DISPLAY="${WARSERPENT_DISPLAY:-:99}"
if DISPLAY="$WARSERPENT_DISPLAY" xdpyinfo >/dev/null 2>&1; then
    printf 'Display ready: DISPLAY=%s\n' "$WARSERPENT_DISPLAY"
    exit 0
fi
if [[ ! -x "$WARSERPENT_XVFB_ROOT/usr/bin/Xvfb" ]]; then
    printf 'Xvfb missing: install it locally or set WARSERPENT_XVFB_ROOT.\n' >&2
    exit 1
fi
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
"$WARSERPENT_XVFB_ROOT/usr/bin/Xvfb" "$WARSERPENT_DISPLAY" -screen 0 1280x720x24 -nolisten tcp -ac > "$WARSERPENT_XVFB_ROOT/Xvfb.log" 2>&1 &
printf '%s\n' "$!" > "$WARSERPENT_XVFB_ROOT/Xvfb.pid"
for attempt in {1..40}; do
    if DISPLAY="$WARSERPENT_DISPLAY" xdpyinfo >/dev/null 2>&1; then
        printf 'Display ready: DISPLAY=%s\n' "$WARSERPENT_DISPLAY"
        exit 0
    fi
    sleep 0.1
done
cat "$WARSERPENT_XVFB_ROOT/Xvfb.log" >&2
exit 1
