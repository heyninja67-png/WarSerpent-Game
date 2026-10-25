# Android boot, full-screen and texture audit — v1.1

This was a read-only packaging/source audit against the installed **Godot 4.6.3 stable** engine/templates and the v1.1 project settings. No SDK download, APK build, application-code edit or Android execution was performed for this audit. Only this report was written.

## Engine boot logo

`project.godot` sets `application/boot_splash/show_image=false` and a dark `boot_splash/bg_color`. This is a supported Godot setting. In the exact engine source, `main/main.cpp` lines 3829–3862 read the setting; when false, Godot constructs a transparent 1×1 image and displays that against the configured background. The default Godot logo is reached only through the other fallback branch. Removing the engine's visual boot logo does **not** require rebuilding the engine or modifying its APK template.

The application's own animated Emnio splash remains separate and is driven by the main scene. Hiding the engine boot image does not remove third-party license obligations or embedded engine code; it only controls the rendered engine boot image.

Source: <https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp#L3829>.

## Native Android launch screen

The verified `android_source.zip` bundled with the engine contains:

- `src/main/AndroidManifest.xml`: activity theme `@style/GodotAppSplashTheme`.
- `src/main/java/com/godot/game/GodotApp.java`: calls `SplashScreen.installSplashScreen(this)` before engine activity creation.
- `res/values/themes.xml`: launch icon `windowSplashScreenAnimatedIcon=@mipmap/icon_foreground`; background references `@mipmap/icon_background`, with `postSplashScreenTheme=@style/GodotAppMainTheme`.

The precompiled `android_debug.apk` template was also inspected using `aapt dump --values resources`: the launch theme points to the foreground resource `0x7f0a0002`, independently confirming the source-template configuration.

The export preset explicitly supplies the original project icon for both the regular icon and adaptive foreground. The exact engine exporter supports this for **direct APK export**: `load_icon_refs()` loads the custom foreground, and the APK-copy loop replaces each density's `LAUNCHER_ADAPTIVE_ICON_FOREGROUNDS` bitmap. Therefore the supported configuration replaces the native launch icon with War Serpent artwork, rather than the default Godot artwork. This was established from source/settings; the next APK still needs its resources checked after rebuilding.

Android 12 and later control the system launch-screen phase. `boot_splash/show_image=false` does not remove that system phase. A brief OS-managed app-icon launch screen can remain before Emnio appears. This should not be described as a remaining Godot-logo splash. Its timing, masking, visual transitions and OEM-specific appearance require an actual Android execution test.

The blank custom monochrome field leaves the normal adaptive icon XML in use: the exporter enables the themed-icon XML only if a valid custom monochrome image is supplied. The unused template monochrome resource is consequently not evidence that the displayed foreground remains the Godot logo. The default background resource is a simple solid bitmap; it is not the engine-logo image.

Sources:

- <https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp#L1882>
- <https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp#L4128>
- <https://developer.android.com/develop/ui/views/launch/splash-screen>

## Full-screen, edge-to-edge and physical cutouts

The v1.1 export preset sets `screen/immersive_mode=true` and `screen/edge_to_edge=true`. Both are supported by the direct exporter: it serializes `--fullscreen` and `--edge_to_edge` into the APK command-line resource.

In Godot's exact Android runtime source, `Godot.kt`:

- Parses `--edge_to_edge` into the runtime flag.
- `enableEdgeToEdge()` calls `WindowCompat.setDecorFitsSystemWindows(window, false)` when enabled, removes the root inset listener and clears root padding.
- `enableImmersiveMode()` hides the system bars and permits transient bars to reappear by swipe.
- `GodotApp.java` calls AndroidX `EdgeToEdge.enable(this)` and reapplies Godot's window appearance on resume and when the engine main loop starts.

This is the supported full-bleed path. It does not itself guarantee that interactive controls avoid every camera hole, display cutout, rounded corner or OEM navigation overlay. No call to `DisplayServer.get_display_safe_area()` was found in the project scripts at audit time. Centered menu layout gives extra side space on wide screens, but safe placement of critical HUD/touch controls must still be checked on representative hardware; a device-aware safe-area adjustment is the supported way to address any overlap.

Project stretch settings are `canvas_items` with aspect `expand`, 1280×720 reference size. The current menu code centers its reference layout and sizes the background/shade to the expanded viewport; the background uses `STRETCH_KEEP_ASPECT_COVERED`. This avoids adding a fixed-ratio letterbox to the menu background. The 1536×1024 menu artwork is cropped to cover the available area, so some peripheral artwork is intentionally outside the viewport. Black areas caused by a device's physical cutout, system compositor, launch window or an app-specific layout are distinct from texture decoding.

Sources:

- <https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp#L3189>
- <https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/Godot.kt#L376>

## PNG import and GL compatibility

All **58** inspected PNG import sidecars use lossless `compress/mode=0`, `vram_texture=false`, `mipmaps/generate=false`, `process/fix_alpha_border=true`, and straight alpha (`process/premult_alpha=false`). These are standard 2D texture imports and do not require ASTC/ETC2 hardware decoding. The project chooses Godot's `gl_compatibility` renderer; enabling ETC2/ASTC import availability in the project does not change these lossless per-texture imports.

Representative source assets inspected with Pillow:

| Asset | Dimensions | Channels |
|---|---:|---|
| App icon | 512×512 | RGBA |
| Menu background | 1536×1024 | RGB |
| Volt head | 96×76 | RGBA |
| Volt body | 64×64 | RGBA |

No missing file or decode error was detected for those sources. Alpha-border fixing helps filtered transparent sprite edges. Disabled mipmaps can make small distant sprites shimmer; this is a visual-quality tradeoff, not evidence of missing PNG support. The PNG import flags do not impose screen letterboxing.

## Evidence limits and next verification

At audit time `builds/WarSerpentIO-debug.apk` was still the **2026-10-24 20:08 UTC** artifact, predating v1.1 changes. Its stored command line contained `--fullscreen` but did not contain `--edge_to_edge`. It must not be presented as verification of the newer preset. After the next build, verify the new APK timestamp/version, `assets/_cl_` flags, native foreground bitmap, signature and package, as well as the packed Godot boot setting.

No `/dev/kvm` exists and no running emulator or connected Android device was supplied for this audit. No native cold-start, display-cutout, Android lifecycle or mobile GPU execution result is claimed here. Desktop rendered screenshots may verify application visuals, but cannot establish the Android system launch-screen or hardware cutout behavior.

## Verification after the v1.1 release-template rebuild

The subsequent actual v1.1 APK was independently inspected. Its packed `project.binary` has `boot_splash/show_image=false` and aspect`expand`; its stored Android command line includes both `--fullscreen` and `--edge_to_edge`. All six native adaptive foreground bitmaps match the original custom icon after the engine resize. The native libraries match the official release template, and the output is not debuggable. See [android_v1_1_validation.md](android_v1_1_validation.md) and [apk_validation_details.txt](apk_validation_details.txt) for exact current-artifact evidence. The physical-device and OS-launch-screen limits above still apply.
