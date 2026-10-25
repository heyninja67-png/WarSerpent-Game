#!/usr/bin/env bash
# Build an optimized release-template APK with the existing development identity.
# Only replace the delivered APK after export, manifest repair, signing and checks.
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/workspace/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/workspace/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/workspace/.cache}
export ANDROID_HOME=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/workspace/toolchains/android-sdk}}
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
export WARSERPENT_TOOLCHAINS=${WARSERPENT_TOOLCHAINS:-/workspace/toolchains}
export WARSERPENT_EXPECTED_CERT_SHA256=${WARSERPENT_EXPECTED_CERT_SHA256:-5764b2c60e35c535276fccf3e112de4f5d5f991c6512f8b584624743d61db620}
GODOT=${GODOT:-godot}
# Official Godot4.6.3 environment overrides (export_plugin.h), no credentials file.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$WARSERPENT_TOOLCHAINS/debug.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
cd "$PROJECT_ROOT"
mkdir -p builds
# Preserve update compatibility: do not silently generate/reuse a different key.
python3 - <<'PY'
import hashlib,os,subprocess
from pathlib import Path
key=Path(os.environ['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'])
if not key.is_file():raise SystemExit('Existing signing keystore missing; original key required for an update')
result=subprocess.run([str(Path(os.environ['JAVA_HOME'])/'bin/keytool'),'-exportcert','-keystore',str(key),'-alias','androiddebugkey','-storepass','android'],capture_output=True)
if result.returncode:raise SystemExit('Unable to read the existing signing certificate')
digest=hashlib.sha256(result.stdout).hexdigest()
if digest!=os.environ['WARSERPENT_EXPECTED_CERT_SHA256']:raise SystemExit('Certificate differs from the intended installed app; refusing update build')
print('Existing signing certificate verified: '+digest,flush=True)
PY
BUILD_DIR=$(mktemp -d "$PROJECT_ROOT/builds/.android-build.XXXXXX")
trap 'rm -rf -- "$BUILD_DIR"' EXIT
APK="$BUILD_DIR/WarSerpentIO-debug.apk"
"$GODOT" --headless --path "$PROJECT_ROOT" --editor --import > "$BUILD_DIR/import.log" 2>&1
cat "$BUILD_DIR/import.log"
if rg -q 'SCRIPT ERROR:|Parse Error:|^ERROR:' "$BUILD_DIR/import.log"; then
    printf 'Godot resource import reported an error; delivered APK preserved.\n' >&2
    exit 1
fi
# Filename retained for existing download links; the APK itself is release mode.
"$GODOT" --headless --path "$PROJECT_ROOT" --export-release Android "$APK" > "$BUILD_DIR/export.log" 2>&1
cat "$BUILD_DIR/export.log"
if rg -q 'SCRIPT ERROR:|Parse Error:|^ERROR:' "$BUILD_DIR/export.log"; then
    printf 'Godot export reported an error; delivered APK preserved.\n' >&2
    exit 1
fi
# Godot4.6.3 rewrites AndroidX provider authorities incorrectly during direct
# export. Correct this one field, then recreate alignment and valid signatures.
python3 tools/fix_android_manifest.py "$APK"
"$ANDROID_HOME/build-tools/35.0.1/zipalign" -P 16 -f 4 "$APK" "$BUILD_DIR/aligned.apk"
mv "$BUILD_DIR/aligned.apk" "$APK"
"$ANDROID_HOME/build-tools/35.0.1/apksigner" sign --ks "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" --ks-key-alias androiddebugkey --ks-pass pass:android "$APK"
"$ANDROID_HOME/build-tools/35.0.1/apksigner" verify --verbose --print-certs "$APK"
"$ANDROID_HOME/build-tools/35.0.1/aapt" dump badging "$APK" > "$BUILD_DIR/badging.txt"
cat "$BUILD_DIR/badging.txt"
if rg -q '^application-debuggable' "$BUILD_DIR/badging.txt"; then
    printf 'Unexpected debuggable APK; delivered APK preserved.\n' >&2
    exit 1
fi
"$ANDROID_HOME/build-tools/35.0.1/zipalign" -c -P 16 4 "$APK"
mv "$APK" builds/WarSerpentIO-debug.apk
if [[ -f "$APK.idsig" ]]; then mv "$APK.idsig" builds/WarSerpentIO-debug.apk.idsig; fi
sha256sum builds/WarSerpentIO-debug.apk
