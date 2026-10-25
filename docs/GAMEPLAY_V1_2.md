# Gameplay and reference-aligned HUD — v1.2

The gameplay screen now follows the supplied arena reference layout using original Emnio Games artwork. The project retains eight functional skins, a ten-segment starting snake, offline bots, and the existing direct-connect multiplayer protocol. No additional modes, fake powers, score multipliers, or paid purchases were introduced.

## Screen layout and actual data

- A circular radar at the upper left shows the **actual live player and opponents**, arena boundary and camera footprint. Its world-to-map transform handles arena corners and keeps markers inside the circular display. Positions refresh through a cached snapshot every 0.15 seconds, approximately 6–7 Hz, rather than rebuilding during every draw.
- Time is centered at the top. The compact score header sits to the right, and a narrow leaderboard displays up to ten real competitors without a large opaque panel covering the arena.
- The joystick remains at the lower left and the large hold-to-boost control at the lower right. Two smaller center widgets provide the equipped ability and a second, functional hold area for the same boost. The second widget is not an additional invented ability; it uses the real boost state, mass reserve and input path.
- Spawn/temporary protection displays its real remaining time. Active powers show duration and cooldown, pickups show aggregated actual energy, and the arena edge warning points inward before the lethal boundary.
- The new purple beveled arena texture is drawn with white modulation so its authored material remains visible. All eight original glossy snake sets remain integrated. Bodies retain instanced rendering; per-segment tint shading adds depth without an additional draw for each segment. Heads are slightly larger and starting camera framing is closer for readability.
- Direct-connect host addresses remain readable below the radar; radar bounds finish before the existing network labels. Pickup feedback sits above the center controls rather than covering those addresses.

The original reference was used for layout and presentation direction, not copied into the game. Generated/painted project assets and their sources remain in the repository.

## Control and movement refinement

The virtual stick applies a radial hysteresis deadzone: an inactive stick engages at 18% of its radius and releases at 12%. The active radius is remapped smoothly. This removes center noise and avoids repeatedly engaging/releasing around a single threshold. Filtering changes `joystick_vector` at the input stage, so offline simulation and online input submission share it.

Compact snakes turn at up to 4.8 radians/second, tapering to 3.8 for large snakes. Speed remains 162 world units/second before boost or ability modifiers. Short-angle targets snap without overshooting, and heading wrap uses the shortest angular route. The existing fixed-distance circular body history keeps spacing stable through rapid boost/dash turns.

Pause and application focus loss clear all held touch identities, mouse dragging, boost and the steering latch. An Android application pause also pauses active gameplay. Emulated mouse events are still ignored by gameplay to prevent a touch toggling pause twice. Gameplay scoring, growth, power cooldowns and collision eligibility remain unchanged.

## Checks actually executed

- **72 gameplay/model checks passed, zero failures.** Coverage includes 30/60 Hz steering, angular wrap, no overshoot, rapid boost turns, all eight powers, joystick hysteresis/recovery, protection and pickup feedback, shield consumption, head/body and head/head collision rules, remote control hooks, real minimap marker mapping and throttling, and the center boost hold area.
- **169 application integration checks passed**, including real Godot input dispatch, independent simultaneous touch controls, pause/resume, eight skins, save/load and the complete splash → menu → play → defeat → results → restart flow.
- Five actual rendered framebuffers were saved. The gameplay capture shows the new circular radar, compact headers, center powers, purple arena and glossy characters.
- Existing direct-connect network checks continue to exercise real host/client processes; the packet schema was not changed for this refinement.

Gameplay log and raw benchmark JSON are retained in [benchmarks/v1.2](benchmarks/v1.2/). Final APK packaging, signature checks and exact network check counts are recorded by the build report, rather than inferred from these model tests.

## Measured performance and limits

Godot 4.6.3, Linux development server, X11/Mesa llvmpipe software rendering. These values are server measurements, **not Android FPS or hardware touch latency**.

The physics comparison uses the v1.1 commit `e31130e` and the current source with the same benchmark script, ten snakes, exactly forty body segments per snake throughout the timed run, 1,000 energy particles and 3,600 steps. Fixing body length prevents faster steering/collection from silently changing the measured load. AI remains enabled. Both versions use the same test-only collision protection.

| Fixed workload CPU work | v1.1 | v1.2 |
|---|---:|---:|
| One 40-segment model step | 20.62 µs | 22.11 µs |
| Ten-snake body-grid rebuild | 109.96 µs | 112.41 µs |
| One AI decision | 15.95 µs | 16.09 µs |
| Complete physics step, 3,600-step mean | 465.58 µs | 449.82 µs |

The comparable full physics run did not regress: approximately **3.4% lower mean CPU time** in this observation. Individual timings vary with shared server load; the new per-model steering calculation adds a small amount of work.

The rendered benchmark holds the camera fixed and displays ten forty-segment snakes for 180 frames. The updated reference layout adds a real minimap and expands the leaderboard from five to ten entries, so the HUD workload is larger:

| Render command measurement | v1.1 | v1.2 reference HUD |
|---|---:|---:|
| Mean `_draw()` CPU command recording | 799.01 µs | 1,037.22 µs |
| 95th percentile | 1,017 µs | 1,909 µs |
| Submitted draw calls, final sampled frame | 81 | 104 |

This is an observed **29.8% increase in draw-command CPU time**, about **0.24 ms on this server**, accompanying the requested richer HUD. It is reported explicitly; it is not described as a rendering speedup. Food and bodies still use instanced draws, the minimap data update is throttled, particles remain bounded, and Low/mobile Auto keeps its conservative population and effects budget. No expensive full-screen shader was added.

Reproduce from the project root:

```sh
godot --headless --path . --script tests/test_gameplay.gd
godot --headless --path . --script tests/benchmark_gameplay.gd -- --output=/tmp/physics.json
bash tools/start_display.sh
DISPLAY=:99 godot --audio-driver Dummy --path . --script tests/benchmark_draw.gd -- --output=/tmp/draw.json
```

Android device testing is still necessary for frame pacing, battery, thermal behavior and physical touch feel. Desktop rendering, headless tests and compilation do not substitute for that hardware run.

## Frozen gameplay source

- `scripts/gameplay/ArenaGame.gd`: SHA256 `22ab716a2bd080e086acef98e1823bd22b19dac9547ca3ed88e4286aff70f2f3`
- `scripts/movement/snake_model.gd`: SHA256 `5a61304a33ff2f3782c9cf1afe9fa49a5d5b1b28d184198cd0e5d33d92c45512`

These hashes identify the application source sent to Android export after the final reference-aligned HUD review. Documentation and test result files were saved afterward.
