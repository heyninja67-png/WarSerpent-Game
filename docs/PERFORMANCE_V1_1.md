# War Serpent.io 1.1 performance validation

The reported Android lag motivated an actual before/after profile and renderer changes. These measurements were executed in the development environment with Godot **4.6.3**, Linux **X11**, and Mesa **llvmpipe**, a software renderer. They measure server CPU work and submitted rendering commands. **They are not Android FPS, touch latency, battery, or GPU measurements.** An Android device benchmark is still required before promising 30/60 FPS.

## Comparable workload and results

The baseline is the original committed game, `750f8ca`, extracted into a separate temporary directory. The current working project was tested with the same benchmark scripts. Both scenes contain **10 snakes, initially 40 segments per snake, and 1,000 food particles**. A test-only shield prevents body deaths during the 3,600-step physics run. Gameplay and AI can subsequently collect food and grow; this is a live simulation, not a replay with identical AI decisions. The body-grid and individual-model microbenchmarks use fixed body sizes. The drawing test keeps all bodies at 40 segments for 180 rendered frames.

| Measured server CPU work | Version 1.0 | Version 1.1 | Reduction |
|---|---:|---:|---:|
| Move/sample one fixed 40-segment snake | 43.88 µs | 20.19 µs | 54.0% |
| Rebuild body grid for ten 40-segment snakes | 217.27 µs | 120.40 µs | 44.6% |
| One AI decision | 94.05 µs | 15.67 µs | 83.3% |
| Full arena physics step, mean of 3,600 steps | 1,079.80 µs | 494.89 µs | 54.2% |
| `_draw()` CPU command recording, 180-frame mean | 3,744.85 µs | 732.27 µs | 80.4% |
| `_draw()` CPU command recording, 95th percentile | 5,318 µs | 857 µs | 83.9% |

The AI microbenchmark calls the public standalone `decide()` compatibility path: the new implementation bounds food samples and culls distant bodies. Normal arena play additionally passes the food and body grids, so it queries nearby entries rather than scanning the entire arena. The before/after timings came from sequential runs on a shared development server; background load can vary. Raw results are retained in [benchmarks](benchmarks/).

A separate rendered counter run of the same fixed scene recorded **661 → 81 draw calls per frame** (87.7% fewer) and **1,310 → 342 rendered objects**. That counter run also records its own timing in the JSON files; its baseline timing was noisier under shared server load and is not substituted into the timing table above. Performance monitors describe the final sampled frame, not a device-wide guarantee.

## Changes tied to the measured costs

- **Food rendering:** one textured `MultiMesh` submits the whole bounded pool. Collecting or respawning food updates its instance directly. There is no per-render-frame loop drawing four circles per food particle. The energy orb is a reusable authored texture with per-instance colors.
- **Snake rendering:** bodies use one instanced mesh per skin texture, with at most eight body batches. Heads and tails retain their authored sprites. Off-camera segments are excluded. This removes repeated CanvasItem transforms and individual body sprite drawing commands.
- **Movement history:** fixed-capacity circular position/distance buffers replace `Array.push_front()` and repeated path trimming. Segment storage is resized only when length changes. Body placement still samples distance along the curved path.
- **Spatial queries:** buckets are retained, body entries use native encoded integers instead of a new dictionary for every segment, and queries reuse result arrays.
- **AI:** decisions run at distributed intervals and use nearby food/body buckets. The compatibility path bounds its food samples instead of scanning the whole food pool.
- **HUD:** style resources, name widths, and leaderboard order are cached. Leaderboard sorting updates every 0.3 seconds, not every rendered frame.
- **Audio:** four effects are loaded once; three reusable playback voices limit overlap. Pellets never evict an ability/death sound when all voices are busy.

## Default budgets and starter size

| Setting | Offline bots | Initial energy | Effects |
|---|---:|---:|---|
| Low | 5 | 420 | Reduced sparks, no added high-quality aura |
| Medium | 7 | 650 | Basic particles |
| High | 9 | 1,000 | Additional head aura |
| Auto on mobile | Low | 420 | Conservative initial budget |

On desktop, Auto uses Low on fewer than four reported CPU cores and Medium otherwise. Core count is only a coarse fallback, not a measured GPU capability. The main application caps Low and mobile Auto rendering at 30 FPS, other profiles at 60 FPS; physics remains 60 Hz. These are requested frame limits, not measured device outcomes.

A new player starts with **10 connected segments and 36 mass**, compared with 33 segments previously. Boost is immediately usable, consumes mass, and stops at the 12-mass floor. Growth and all eight powers remain functional. The fixed-size benchmarks above deliberately use 40-segment bodies so the measured improvement does not rely solely on the smaller starting snake.

Online rooms use the Low simulation population consistently on host and clients. Snapshot rendering calls `sync_food_visual(index)` for food deltas and `invalidate_food_visuals()` after initial food state. The host remains authoritative for movement, collection, abilities, and collisions.

## Reproduce

From the project root, using a writable Godot user-data directory if required by the host:

```sh
godot --headless --path . --script tests/benchmark_gameplay.gd -- --output=/tmp/physics.json
bash tools/start_display.sh
DISPLAY=:99 godot --audio-driver Dummy --path . --script tests/benchmark_draw.gd -- --output=/tmp/draw.json
godot --headless --path . --script tests/simulate_arena.gd
```

The rendering command needs an actual display backend. Running it with the dummy headless renderer does not validate rendering cost. `benchmark_draw.gd` records its backend and rendering counters. `simulate_arena.gd` exercises all eight skins with the actual arena/model/AI; the latest run executed **14,400 physics steps**, **zero failures**, **3.530 seconds wall time**, averaging **0.245 ms per step** on this server. That separate simulation uses the normal Medium population, so its timing is not compared with the fixed-load table.
