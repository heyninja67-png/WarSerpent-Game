# Android v1.2.1 — classic art restoration and UI fixes

This APK was actually exported after the final classic-snake restoration, UI interaction fixes, animations, HUD layout fixes and asset freezes. It uses the verified **Godot4.6.3 release template**, with the **same existing development signing identity as v1.0/v1.1**. `WarSerpentIO-debug.apk` is retained as the build helper's compatibility filename; the APK is not debuggable. The release publisher may provide a versioned alias with identical bytes.

| Field | Verified result |
|---|---|
| Application ID | `com.emnioggs.warserpent` |
| App label | War Serpent.io |
| Version | `1.2.1`, code`4` |
| APK bytes | `64639547` (61.65MiB) |
| APK SHA256 | `505dfbe75e13618fa83b5ba0b375e8dd0f4b4765c2183be314ad17febcdbc990` |
| Signer certificate SHA256 | `5764b2c60e35c535276fccf3e112de4f5d5f991c6512f8b584624743d61db620` |
| Android | min API24; target/compile API36; landscape |
| Architectures | ARM64 and ARMv7 |
| Permission set | `android.permission.INTERNET` only, for direct multiplayer |
| Signature | v2 and v3 verified |
| Alignment | ZIP16KB check passed; ARM64 ELF LOAD16KB alignment verified |

The package name, increasing version code and unchanged signing certificate satisfy the checked metadata prerequisites for an update from prior versions. An actual Android update/install and device save-retention test has **not** been performed, because no device or emulator is connected. The private signing key remains outside the project and source archive.

## Executed commands and evidence

From the repository root, both commands completed with exit0:

```sh
./tools/build_android.sh > builds/android-build.log 2>&1
python3 tools/validate_android.py > builds/android-validation.log 2>&1
```

Full final-artifact evidence: [apk_validation_details.txt](apk_validation_details.txt). Concise generated summary, including exact source and image hashes: [apk_validation.txt](apk_validation.txt).

The build helper checks the existing public signing certificate before starting. It imports resources, exports with `--export-release`, corrects the known Godot4.6.3 AndroidX authority defect, aligns, re-signs and verifies a temporary APK before replacing the delivered file. It uses official `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment overrides with the original local development key, not a new production identity. No SDK was reinstalled and no private signing key or credentials file was added to source.

## Actual packaged-resource checks: 146 passed

The validator extracts the APK's Godot assets to an isolated temporary directory and runs the matching desktop Godot against the **packed `project.binary`, compiled `.gdc` scripts and imported `.ctex`/audio/font resources**. The app scene is instantiated without being attached to a live scene tree. This check does not read/write a player save or start a room server.

- Packed version1.2.1, GL Compatibility mobile renderer, viewport aspect`expand` and `boot_splash/show_image=false`.
- Compiled Main, LobbyPlatform, MenuAtmosphere, SerpentPreview, gameplay and networking modules present/loadable. Frozen Main source hash starts`13e42c5e`; ArenaGame starts`540d32fd`; OnlineArena starts`b0f0445b`.
- The real compiled room code generates a cached LAN address/UDP-port HUD hint. The displayed container LAN address in the raw test log is a local test result, not a public matchmaking endpoint.
- Eight skin head/body/tail textures and ability icons load. All24 restored classic snake sprite files and the purple arena-floor texture reconstruct to exactly the current source pixels, detecting stale imports.
- All three generated branding images reconstruct to current-source pixels: War Serpent logo1942×809, app icon1254×1254, and **Emnio Games** studio logo1983×793.
- Both packaged fonts load and contain English uppercase/lowercase letters and digits. The bundled DejaVu notice matches source bytes exactly.
- Both actual OGG tracks decode finite, non-silent PCM and last45.176464seconds. The compiled app's `set_music_track` method enables stream looping for both tracks.
- All six native Android adaptive foreground densities match the custom app icon after the engine's Lanczos resize. The default Godot foreground image is not selected for that system phase.

To compare lossless imported art correctly, the validator converts both decoded `.ctex` pixels and source PNG pixels to RGBA8, then applies the source importer's `fix_alpha_edges` operation before comparing bytes. This accounts for RGB padding under transparent pixels without changing visible artwork. The exact pixel hashes are recorded in the evidence. Native icon comparison reproduces the exporter's resize operation independently.

Additional artifact checks passed: ZIP CRC on every entry, the eight-skin JSON catalog matching source, actual DEX executable payloads, all four native-library hashes matching the official release template byte-for-byte, valid signature, distinct corrected provider authorities, and ZIP/ELF alignment. The APK contains220 Godot resource entries, including92 imported resources.

## Canonical restoration proof

All24 original head/body/tail PNG files are byte-identical to commit `e31130e13de1bd6b8ebee193da3f64602aa14b5d` (the v1.1 classic angular cyber art). This was independently checked with native `git show` before export, not inferred from filenames or generator success. A separate comparison confirmed the other50 PNG files remain byte-identical to the preceding v1.2 source commit `d2d0e2310e74b24d43bd9cccdb2c4030453cf2cd`.

The validator checks `assets/snakes/RESTORE_PROOF.json` against a pinned canonical hash-map digest:

`42b8818e9679c97343691727e9cb971c948f3561bf07803b6fe512a7a4e03a18`

It then verifies all24 source PNG SHA256 values and checks that the same restoration proof is packaged in the APK. This requires no `.git` directory when validating a fresh source ZIP. The actual imported APK sprite pixels are independently decoded and compared against those byte-verified source files, including the normal importer alpha-edge operation. The source bytes therefore match the requested historical art, and the compiled game contains its actual corresponding pixels.

The War Serpent logo/icon, EMNIO GAMES studio mark, gold lobby materials, purple floor and eight-skin inventory remain in this patch. The earlier `android_v1_2_validation.md` was left unchanged as the historical v1.2 report.

## Full-screen, launch and runtime limits

The actual packaged Android command line includes `--fullscreen` and `--edge_to_edge`, with no remote-debug connection flag. The packed engine boot image setting is false. Android12+ can still show a brief **OS-managed custom app-icon launch screen** before the application's Emnio Games animation; that system phase is separate from the Godot engine boot image.

No Android device, emulator or `/dev/kvm` is available. No native installation, update, cold launch, lifecycle, physical cutout, real multitouch, GPU/FPS, memory, battery or sustained thermal test was executed. Desktop-rendered screenshots, gameplay/integration tests and multi-process networking tests are separate evidence. Release-template selection and successful compilation do not establish measured performance on a phone.
