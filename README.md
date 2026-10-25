# War Serpent.io 1.2.0 — Emnio Games

Native optimized Android update. Package com.emnioggs.warserpent, version code3, Android7/API24+, ARM64/ARMv7, OpenGL ES3.

Install over the previous version without uninstalling to retain progress; the signing certificate is unchanged.

- Game-style lobby: top profile/currencies, left navigation, a large expressive serpent on a neon podium, collection rail, and gold START button at bottom right.
- Real circular minimap, compact time/score/leaderboard and real power controls; purple raised-block arena.
- Eight glossy expressive serpent designs, a new War Serpent.io logo/icon and original Emnio Games studio mark.
- Responsive controls, joystick hysteresis and safe control reset, protection/power/boundary feedback.
- Offline AI plus real direct host/join rooms, background music, economy and persistent saves remain functional.

345 logic/flow/network checks passed;146checks of the actual APK payload passed. Five real framebuffers included in source docs. No Android hardware/emulator was connected: installation and actual phone FPS/Wi-Fi still need device validation.

The expanded HUD costs more draw work than the previous minimal HUD; instanced rendering remains. Detailed measurements and limitations are in BUILD_REPORT.md and docs/GAMEPLAY_V1_2.md.

Release-mode engine, same development signing identity as previous releases; not a Play Store production signing identity. MIT code; original artwork/audio and other notices included in source ZIP.
