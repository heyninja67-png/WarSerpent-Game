#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/workspace/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/workspace/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/workspace/.cache}
export ANDROID_HOME=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/workspace/toolchains/android-sdk}}
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
GODOT=${GODOT:-godot}
cd "$PROJECT_ROOT"
mkdir -p builds
"$GODOT" --headless --path "$PROJECT_ROOT" --editor --import
"$GODOT" --headless --path "$PROJECT_ROOT" --export-debug Android builds/WarSerpentIO-debug.apk
# Godot4.6.3 rewrites AndroidX provider authorities incorrectly during direct
# export. Correct this one field, then recreate alignment and valid signatures.
python3 tools/fix_android_manifest.py builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/zipalign" -P 16 -f 4 builds/WarSerpentIO-debug.apk builds/WarSerpentIO-aligned.apk
mv builds/WarSerpentIO-aligned.apk builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/apksigner" sign --ks "${WARSERPENT_TOOLCHAINS:-/workspace/toolchains}/debug.keystore" --ks-key-alias androiddebugkey --ks-pass pass:android builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/apksigner" verify --verbose --print-certs builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/aapt" dump badging builds/WarSerpentIO-debug.apk
"$ANDROID_HOME/build-tools/35.0.1/zipalign" -c -P 16 4 builds/WarSerpentIO-debug.apk
sha256sum builds/WarSerpentIO-debug.apk
