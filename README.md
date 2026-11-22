# PASSingGame

A third-person 3D adaptation of the original childhood chasing game, built in Godot for an Android-first direction. This repository is the new game prototype; the older top-down browser site is a separate build.

## Play the prototype

Use **Godot 4.7.2**, the version used for validation. Import `project.godot`, then press **F5**. Choose **Practice** to play immediately with three bots, or create a private LAN room.

```sh
godot --path .
# Start directly in practice:
godot --path . -- --practice
```

- **WASD / arrows:** move relative to the camera.
- **Hold right mouse and drag:** rotate camera. **Tab:** toggle mouse capture.
- **Touch:** left joystick moves; drag the right side to look.
- **Esc:** close the shared help/records panel, or toggle the menu.
- Use the runner buttons to call a target or request a PASS. The recipient must press **ACKNOWLEDGE PASS** before the target changes.

### Four-player LAN game

1. All players run this same project on the same network.
2. One player chooses **Create a private LAN room** and shares their local IP and the displayed six-character code.
3. Three more players enter that host IP and code, with distinct names. The default transport port is **UDP 24567**.
4. The host can start once four players have joined. After a catch, the caught player becomes the next chaser; the host starts the next round.

The code checks admission to an already reachable host. It is not a public room directory, authentication system, or substitute for an IP address. No hosted matchmaking service is connected. The host must remain connected.

## What is playable

- Third-person follow camera in a colorful 3D park with character proxies, running animation, benches, trees and marked boundaries.
- Original chase, pending PASS, acknowledgement, catch-before-ack precedence, no immediate return pass, boundary elimination and next-chaser rules.
- Authoritative host simulation, four-to-eight-player ENet LAN rooms, compressed state snapshots and reliable critical transitions.
- Three-bot practice, shirt selection, session survival totals and best survival streaks, shared help/records panel, keyboard and touch input paths.

The art is a procedural prototype, not finished character art. Voice recognition, voice chat, public Quick Match, reconnect, account records, internet hosting, mobile safe-area tuning, and an installable Android release remain future work. Button acknowledgement currently represents the verbal response. This is not yet the public mobile release described in the concept.

## Verify

With Godot on PATH and Python 3 installed:

```sh
bash tools/test.sh
```

This imports/parses the project, runs 85 rules assertions, runs a headless practice smoke check, and starts four real Godot processes over loopback ENet. The network check covers admission, calling, PASS/ACK, movement into a catch, scoring and the next round on every peer. Reports are written under ignored `artifacts/`. Loopback success does not establish internet latency, Android performance or physical touch usability.

See [the design direction](docs/VISION.md), [architecture](docs/ARCHITECTURE.md) and [release progress](docs/PROGRESS.md).
