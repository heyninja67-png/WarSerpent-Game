# Android SDK preparation

The initial cloud machine had Godot 4.6.3 and OpenJDK runtime 21 but no discoverable Android SDK, `adb`, `android.jar`, Build Tools, or `sdkmanager` under `/opt`, `/usr/local`, `/usr/lib`, `/home`, `/root`, or `/workspace`. `ANDROID_HOME` and `ANDROID_SDK_ROOT` were unset. Only missing tools were downloaded locally; no SDK was reinstalled and no global configuration changed.

Local SDK: `/workspace/toolchains/android-sdk`.

Reproduce or refresh with:

```sh
python3 tools/install_sdk.py
```

The helper uses TLS verification and validates pinned archive checksums against Google's current HTTPS repository metadata at <https://dl.google.com/android/repository/repository2-1.xml>. Google currently publishes SHA-1 checksums for these archives; the independent SHA-256 values below were computed after SHA-1 verification. Verification was never disabled. Extraction preserves executable permissions. Re-running the helper was tested and skips the installed components.

| Component | Official archive | Version | Official SHA-1 | Observed SHA-256 |
|---|---|---|---|---|
| Build Tools | `build-tools_r35.0.1_linux.zip` | 35.0.1 | `e009a9b188cfeb1d2b4c318ab5cb4f1ddc368861` | `5993499f3229a021b89f87088c57242aeefaa62316bf3d69da7de40bfd5350f1` |
| Platform | `platform-35_r02.zip` | API 35 revision 2 | `0bb560a90a7a2cbd0dd8348224d518b638fe7949` | `0988cacad01b38a18a47bac14a0695f246bc76c1b06c0eeb8eb0dc825ab0c8e0` |
| Platform Tools | `platform-tools_r37.0.1-linux.zip` | 37.0.1 | `477254aa5f903c15cf51001717bdf347fb6b53e0` | `d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1` |

Executed checks:

- `aapt version` passed: Android Asset Packaging Tool v0.2-12874835.
- `apksigner version` passed under the installed JRE 21: 0.9.
- `zipalign` executable runs and provides its normal CLI usage.
- `adb version` and `adb devices -l` passed after an approved directory-only creation of `/home/agent/.android`, required by this ADB binary. The device list was empty. Both Android home-variable overrides had failed to avoid that directory requirement. No Android execution test was possible without a connected device or emulator.

SDK package license files are preserved in the installation. They are third-party tooling, not redistributable project assets. SDK archives and installation paths are deliberately excluded from the source ZIP.
