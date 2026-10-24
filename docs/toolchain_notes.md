# Android build toolchain — current machine

Detected and verified on 2026-10-24:

- Godot `4.6.3.stable.official.7d41c59c4`, existing `/usr/local/bin/godot`.
- OpenJDK runtime `21.0.12.1+1-1-deb13u1-Debian`, existing `/usr/lib/jvm/java-21-openjdk-amd64`.
- `java` and `keytool` are present. `javac` and Gradle are absent; neither is needed by Godot's direct precompiled APK template export. No Gradle or native extension build is used.
- Android SDK was not found in environment variables or standard searched paths. Only the missing Android packages were installed locally in `/workspace/toolchains/android-sdk`. Nothing was installed system-wide.
- Android Build Tools35.0.1: aapt v0.2-12874835, apksigner0.9, zipalign available. API35 platform revision2. Platform Tools37.0.1 (`adb`1.0.41).
- Godot official Android debug/release/source templates installed under `/workspace/.local/share/godot/export_templates/4.6.3.stable`.

## Integrity

Godot archive:

- `https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz`
- SHA512 from the official release `SHA512-SUMS.txt`:
  `da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68`
- The full downloaded archive was verified before extraction. Only Android templates were extracted.

Google SDK archive checksums, URLs, and actual tool checks are recorded in [sdk_notes.md](sdk_notes.md). HTTPS certificate checks and artifact checksums were never disabled.

## Reproduce

From the repository root:

```sh
./tools/setup_android.sh
./tools/build_android.sh
```

The setup helper detects/reuses Java and the SDK variable bindings, verifies templates and SDK archives, creates a local development signing key if absent, and updates only Android paths in the separate local Godot editor settings. `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME` default to writable `/workspace` directories. Set them and `ANDROID_HOME`/`WARSERPENT_TOOLCHAINS` if using another machine. The editor must be Godot4.6.3. The helper does not install Godot itself.

No release signing identity is included. The random local `debug.keystore` is stored outside the project, excluded from the source ZIP. Android's conventional development password is not a production secret. Release builds require the developer's own private release key.

The Android export preset selects `com.emnioggs.warserpent`, version1.0.0/code1, min API24 and target API36 (the immutable defaults of the Godot4.6.3 precompiled APK template), ARMv7 and ARM64, offline operation, and no optional dangerous permissions. Landscape orientation is set in `project.godot`. GL Compatibility supports OpenGL ES3-capable devices.

## Device availability

`adb devices -l` was executed successfully and returned no connected devices or emulators. No installation, touch testing on hardware, GPU profiling, battery, or actual device FPS measurements have been performed. The initial sandbox prevented ADB from creating `/home/agent/.android`; an approved directory-only creation resolved it. No global Java or Android settings were modified. This current-machine directory can be required by ADB independently of SDK location.

## Godot4.6.3 direct-export manifest correction

Inspection of the generated binary manifest found an upstream exporter defect: Godot's `platform/android/export/export_plugin.cpp` rewrites every provider `authorities` attribute to `<package>.fileprovider`, including `androidx.startup.InitializationProvider`. This created duplicate authorities in the otherwise signed APK. The official unmodified template has distinct `.fileprovider` and `.androidx-startup` values; the export step introduced the duplicate.

`tools/fix_android_manifest.py` performs a narrow deterministic AXML postprocess on this project's package. It appends the correct `<package>.androidx-startup` string, updates only the startup provider's attribute reference, and asserts the expected provider classes, package, distinct authorities, unchanged unrelated ZIP payloads, ZIP CRC integrity, and idempotence. It refuses unexpected formats or package identities rather than guessing. The source template and its trusted checksums remain unchanged.

The build helper runs this correction after export, removes stale signing metadata, realigns the APK with `zipalign -P16`, re-signs with the local development key, and verifies the resulting signature. The final manifest is checked independently with `aapt dump xmltree`. Signature verification is never bypassed. The postprocess script was executed twice; the second execution correctly reported that the authority was already correct without further edits.

Independent final artifact validation can be repeated with `python3 tools/validate_android.py`. It also verifies that the bundled DejaVu font notice matches the source byte-for-byte and refreshes `docs/apk_validation.txt` and `docs/apk_validation_details.txt`.
