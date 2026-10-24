#!/usr/bin/env bash
# Prepare missing tools locally; never change global SDK/JDK settings.
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export WARSERPENT_TOOLCHAINS=${WARSERPENT_TOOLCHAINS:-/workspace/toolchains}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/workspace/.config}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/workspace/.local/share}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/workspace/.cache}
export ANDROID_HOME=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$WARSERPENT_TOOLCHAINS/android-sdk}}
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
GODOT=${GODOT:-godot}
version=$($GODOT --headless --version 2>/dev/null)
[[ "$version" == 4.6.3.stable.* ]] || { printf 'Godot 4.6.3 required; found %s\n' "$version" >&2; exit 1; }
[[ -x "$JAVA_HOME/bin/java" && -x "$JAVA_HOME/bin/keytool" ]] || { echo 'Java and keytool required' >&2; exit 1; }
mkdir -p "$WARSERPENT_TOOLCHAINS/downloads" "$XDG_CONFIG_HOME/godot" "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable" "$XDG_CACHE_HOME"
# Direct template export does not require Gradle, javac, an NDK, or a new JDK.
python3 "$PROJECT_ROOT/tools/install_sdk.py"
export WARSERPENT_TEMPLATE_DIR="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
python3 - <<'PY'
import hashlib, os, pathlib, shutil, urllib.request, zipfile
root=pathlib.Path(os.environ['WARSERPENT_TOOLCHAINS'])
dest=pathlib.Path(os.environ['WARSERPENT_TEMPLATE_DIR'])
archive=root/'downloads/Godot_v4.6.3-stable_export_templates.tpz'
expected='da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
def digest(p):
 h=hashlib.sha512()
 with p.open('rb') as f:
  for block in iter(lambda:f.read(16*1024*1024), b''):h.update(block)
 return h.hexdigest()
# Official release SHA512-SUMS.txt pins this archive; retain verification.
if not archive.exists() or digest(archive)!=expected:
 url='https://github.com/godotengine/godot/releases/download/4.6.3-stable/'+archive.name
 with urllib.request.urlopen(url,timeout=120) as response,archive.open('wb') as out:shutil.copyfileobj(response,out)
if digest(archive)!=expected:raise RuntimeError('Godot template checksum mismatch; refusing export')
with zipfile.ZipFile(archive) as z:
 for name in ['android_debug.apk','android_release.apk','android_source.zip','version.txt']:
  data=z.read('templates/'+name)
  target=dest/name
  if not target.exists() or hashlib.sha256(target.read_bytes()).digest()!=hashlib.sha256(data).digest():target.write_bytes(data)
print('Official Godot Android templates: SHA512 verified')
PY
if [[ ! -f "$WARSERPENT_TOOLCHAINS/debug.keystore" ]]; then
 "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$WARSERPENT_TOOLCHAINS/debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Emnio,C=BR"
 chmod 600 "$WARSERPENT_TOOLCHAINS/debug.keystore"
fi
# Preserve unrelated editor settings; only set the local Android tool locations.
python3 - <<'PY'
import json,os,pathlib,re
p=pathlib.Path(os.environ['XDG_CONFIG_HOME'])/'godot/editor_settings-4.6.tres'
s=p.read_text() if p.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
settings={
'export/android/android_sdk_path':os.environ['ANDROID_HOME'],
'export/android/java_sdk_path':os.environ['JAVA_HOME'],
'export/android/debug_keystore':str(pathlib.Path(os.environ['WARSERPENT_TOOLCHAINS'])/'debug.keystore'),
'export/android/debug_keystore_user':'androiddebugkey',
'export/android/debug_keystore_pass':'android'}
for key,val in settings.items():
 line=key+' = '+json.dumps(val)
 pattern=r'^'+re.escape(key)+r'\s*=.*$'
 s=re.sub(pattern,lambda m:line,s,flags=re.M) if re.search(pattern,s,re.M) else s+line+'\n'
p.write_text(s)
PY
"$JAVA_HOME/bin/java" -version
"$ANDROID_HOME/platform-tools/adb" version
"$ANDROID_HOME/build-tools/35.0.1/apksigner" version
printf 'Prepared Android SDK: %s\nGodot editor settings: %s/godot/editor_settings-4.6.tres\n' "$ANDROID_HOME" "$XDG_CONFIG_HOME"
