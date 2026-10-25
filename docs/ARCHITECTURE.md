# Architecture — v1.1

Godot4.6.3, GDScript, native Android GL Compatibility. No web runtime or external game service is required for offline play.

## Entrypoint / UI

`scenes/Main.tscn` → `scripts/ui/Main.gd`: loads profile, shows custom animated Emnio/game branding while real resource jobs finish, then presents the animated menu. UI content uses a centered1280×720 safe frame; background and gameplay cover the expanded viewport. Music is streamed from two looped OGGs. SFX and preview textures are cached. `SerpentPreview.gd` redraws at24Hz rather than allocating/loading per frame. Eight cards are paginated four at a time.

## Simulation

`SnakeModel` stores a fixed-capacity distance-sampled ring history. The body reuses its PackedVector2Array and interpolates evenly spaced segments. A fresh player starts at mass36/ten segments, with boost floor12. Models share movement, powers, collection and damage rules between bots, local humans and remote humans.

`ArenaGame` owns pools of food, snakes, bounded effects, collision/food grids, camera, controls and HUD. Food uses one tintable texture/MultiMesh; bodies use one MultiMesh per skin. Heads/tails/labels remain individual. HUD styles and ranking are cached. Physics uses60Hz; rendering is budgeted to30/60. Low/Medium/High budgets are5/7/9bots and420/650/1000food. Mobile Auto starts Low. See PERFORMANCE_V1_1.md for controlled comparisons.

`ArenaBrain` samples local food/body candidates through spatial hashes and makes staggered steering/boost/power decisions. It avoids edges/bodies and may pursue weak rivals on higher difficulty. AI obeys the same collision rules as humans.

## Online

`OnlineArena` subclasses the same arena. The host is authoritative; three bot slots can become remote humans. Clients disable local simulation, send steering/boost/power at20Hz and interpolate host snapshots at12Hz. Compressed movement data uses bounded packet chunks; food uses an initial state plus reliable deltas. Sender validation never accepts client-provided positions or rewards. See ONLINE.md for room/NAT limits and the headless server.

## Progression

`PlayerProfile` is a RefCounted service with schema2 JSON, atomic rename, backup recovery and migration of schema1. It preserves user progress and maps old Portuguese quality choices to English. Music/SFX toggles are independent. `data/catalog.json` defines eight prices, rarities and ability metadata; the model has matching eight ability implementations and cooldown/duration constants.

Coins buy skins locally. Gems/fragments are persisted rewards without a dedicated shop. Daily rewards and mission claims are idempotent. No real payments, online identity, ranked server economy or account backend is implemented.

## Android / source

The direct exporter uses verified official release templates, so no Gradle/NDK/javac is needed. `tools/build_android.sh` checks the original public signing certificate, exports release, repairs one known AndroidX authority bug, aligns, signs and validates before replacing the artifact. The development private key is external to the checkout and excluded from the source archive. `tools/validate_android.py` independently validates actual APK payloads and engine mode; it is not an Android-device test.

Tests use isolated user-data directories. Network tests use two actual Godot processes. Source packaging excludes runtime saves/caches/SDK/templates/keystores. Code is MIT; asset/font/engine licenses are documented separately.
