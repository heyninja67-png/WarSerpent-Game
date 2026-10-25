# Real direct-connect multiplayer

War Serpent.io 1.1 supports **real host/join rooms using ENet UDP**, up to four human players. The host simulates movement, energy, powers, collisions and scores; guests send only steering, boost and skill requests. A selected bot slot becomes a guest snake; the remaining bots keep playing. This is not simulated matchmaking.

## Connect two phones

1. Connect both devices to the same Wi-Fi network (guest/client isolation must be disabled).
2. On one device select **Online → Host room**, using UDP port **24680**.
3. The host's HUD displays **LAN ROOM address:port**. On the other device select **Online → Join room**, enter that LAN IPv4 address and the same port. The game caches a plausible Wi-Fi/Ethernet interface address once; with VPNs or multiple adapters, verify that it belongs to the Wi-Fi network shared by both devices. A displayed local interface address does not prove public internet reachability.
4. Both players move in the same authoritative arena. If the host leaves or its match ends, the room closes; guests receive an honest network error rather than rewards for an abandoned match.

For different networks, the host must be publicly reachable at the selected UDP port. Router forwarding/firewall rules may be required; carrier-grade NAT commonly prevents inbound hosting. No public game server, automatic matchmaking, account system, relay, NAT traversal or anti-cheat service is supplied/deployed by this project. A private LAN room does not imply a publicly hosted service.

Pause opens a local overlay but **does not freeze the room** for the other players. Steering requests are rate limited and all physics/cooldown rules stay on the host. Direct rooms trust their host and do not provide competitive security or encrypted transport. No credentials are sent.

## Optional headless room host

With Godot 4.6.3 and imported resources:

```sh
./tools/run_multiplayer_server.sh 24680
```

The headless room's host pilot circles near the origin and three slots remain for guests. Use your own machine/VPS and expose its UDP port if public access is wanted. This script does not create cloud infrastructure or configure router rules. Processes must remain running; source files are not a deployed service.

## Synchronization and limits

- Server simulation uses the same `ArenaGame` and `SnakeModel` rules as offline play.
- Guest steering is sent at 20 Hz; host validates finite angles and at most 50 accepted inputs/second.
- Movement snapshots are sent at 12 Hz and interpolated on guests. Compressed snapshots use bounded 950-byte chunks to stay below the ENet MTU; incomplete older frames are discarded. A full initial food state is followed by reliable food deltas; the host does not send the entire arena every frame.
- At most three guests, bounded food (1500) and body segment (160) decode sizes. No arbitrary object deserialization is enabled.
- Rooms currently run a conservative visual/food budget to bound CPU and bandwidth across devices.
- Rejoining starts a fresh snake. Guest progress is not a server account; internet disconnections abandon the current local result.

## Actual transport verification

```sh
python3 tools/test_network.py
```

This launches **two separate Godot OS processes** exchanging real ENet UDP over loopback. The client uses the actual `Main.tscn` application root; the headless host uses the matching `WarSerpentIO/OnlineArena` RPC path. It verifies remote assignment, human steering, visible snapshot movement, growth/score, powers/cooldowns, food synchronization, tiny active joystick steering after radial hysteresis, host closure and unreachable-room timeout. **25 checks passed, zero failures**, with no script errors, resource leaks or packet-MTU warnings in the final run. Logs are stored under `/tmp/warserpent-network-*`; captured final output is in `docs/network-validation.txt`.

Loopback tests do not establish Android Wi-Fi performance, WAN latency, router compatibility, public service availability or multiplayer device compatibility. These require real devices and network testing.
