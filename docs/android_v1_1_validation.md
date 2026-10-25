# Android v1.1 — artifact and update validation

The current artifact was actually exported with **Godot4.6.3's release template**, then corrected, aligned and signed with the **same existing development key used for v1.0**. The output filename `WarSerpentIO-debug.apk` is retained for existing download links; the manifest is not debuggable and the native binaries match the official release template. A filename does not select the build mode.

| Field | Verified result |
|---|---|
| Application ID | `com.emnioggs.warserpent` |
| Version | `1.1.0`, code`2` |
| APK bytes | `56276085` (53.67MiB) |
| APK SHA256 | `a39e98986e79775ad9398917fd442b09aa86ad63d47888d85c54bc0922a70a9c` |
| Signer certificate SHA256 | `5764b2c60e35c535276fccf3e112de4f5d5f991c6512f8b584624743d61db620` |
| Android | min API24; target/compile API36; landscape |
| Architectures | ARM64 and ARMv7 |
| Permission set | `android.permission.INTERNET` only, for direct multiplayer |
| Signature | APK Signature Scheme v2 and v3 valid |
| Alignment | ZIP16KB check passed; all ARM64 ELF LOAD segments aligned16KB |

Package identity, increasing version code and the identical signing certificate satisfy the checked metadata prerequisites for updating v1.0. **An actual `adb install -r` update and save retention on Android have not been executed**, because no device or emulator is connected. The signing key remains outside the project and source ZIP.

## Commands executed

From the repository root:

```sh
./tools/build_android.sh > builds/android-build.log 2>&1
python3 tools/validate_android.py > builds/android-validation.log 2>&1
```

Both completed with exit0. Full independent evidence is saved in [apk_validation_details.txt](apk_validation_details.txt), with the current artifact summary in [apk_validation.txt](apk_validation.txt).

The build helper uses the official Godot4.6.3 environment overrides `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` to sign a release-template export with the existing local development key. These names and their use were verified in the exact engine's `platform/android/export/export_plugin.h` and `_get_keystore_path`/`get_or_env` code. No `.godot/export_credentials.cfg` or private key was created in the source tree. This is an optimized game build with a development identity, not a store-production signing identity.

Before export, the helper hashes the existing public DER certificate and rejects a different signer. It builds in an isolated temporary subdirectory of `builds`, checks import/export errors, applies the documented narrow AndroidX authority correction, realigns and re-signs, checks the resulting manifest/signature, and only then replaces the delivered APK. The previous delivered APK stays intact if those stages fail. The temporary build directory is removed afterward.

An independent developer building this open-source project needs their own signing key. Set `WARSERPENT_EXPECTED_CERT_SHA256` to that key's public certificate digest for both build and validation helpers. Such a differently signed app cannot update this distributed identity; do not remove the signer check merely to make an update pass. Lost original private signing keys cannot be reconstructed from a certificate or source archive.

## Checks on the actual packed game

The independent validator extracts the APK's Godot assets to an isolated temporary directory and uses the matching desktop Godot to read its **packed `project.binary` and compiled `.gdc` files**, rather than inspecting only editable source settings. The app scene is instantiated without being attached to a running scene tree, so this check does not read/write a player save or start network services.

All58 packaged-resource assertions passed:

- Game version1.1.0, GL Compatibility mobile renderer, viewport aspect`expand` and `boot_splash/show_image=false`.
- Compiled Main scene and OnlineArena script load successfully. The actual compiled room code caches a LAN address and generates the HUD hint with UDP port24680; LAN selection accepts a private IPv4 address and rejects loopback.
- All eight skins' head/body/tail sprites and ability icons load, plus the new energy sprite.
- Both actual imported OGG streams load and decode non-silent finite PCM. Each lasts45.176464seconds. The **compiled app's `set_music_track` method** sets `AudioStreamOggVorbis.loop=true`; this was exercised for menu and arena. Source import sidecars may retain `loop=false`, because the app explicitly sets the loaded stream's loop flag.
- All six native Android adaptive foreground bitmaps match the custom War Serpent icon exactly after the engine's Lanczos resize. The Android native splash does not use the default Godot foreground art.

Additional APK checks verified CRC for every ZIP entry, all compiled game modules, the eight-entry JSON catalog matching source, the bundled DejaVu font notice, all four native library payloads matching the official release-template libraries byte-for-byte, and distinct corrected provider authorities. The actual packaged Android arguments include both `--fullscreen` and `--edge_to_edge`, with no remote-debug connection flag.

## Scope limits

Android12+ can still show a brief **system-managed custom app-icon launch screen** before Emnio. Hiding the Godot engine boot image does not remove Android's system launch phase. The packed settings and icon assets were verified; its actual timing, OEM rendering, cutout behavior and cold-start transition were not tested on Android.

There is no connected Android device, emulator or `/dev/kvm`. No Android installation, actual update, native launch, lifecycle, hardware multitouch, real GPU/FPS, memory, battery or sustained thermal result is claimed. Desktop rendering, gameplay and multi-process ENet tests are separate evidence. Selecting the release template removes debug-mode packaging/instrumentation, but does not by itself prove any measured FPS improvement.
