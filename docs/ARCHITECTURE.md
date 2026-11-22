# Prototype architecture

`RoundRules` is a deterministic-style, rendering-independent state machine. It owns participant eligibility, target changes, pending PASS, acknowledgement, catch precedence, elimination, next chaser and survival counters. Movement is a normalized intent at fixed speed, integrated in small substeps. Analytic collisions use the same bench/tree dimensions as the rendered park. Clients never submit positions, catches or survival values.

`Session` owns Godot ENet and the practice driver. A host simulates at physics ticks and sends state at 20 Hz. Regular snapshots use compressed, unreliable ordered delivery; phase/round/chaser/target/PASS/participant changes use reliable delivery. A monotonic snapshot sequence prevents a late packet from replacing newer state. Clients interpolate avatar visuals; there is no client prediction or lag compensation yet.

Registration checks protocol, room code, capacity, round status and distinct names. RPC identity comes from the sender peer. Inputs are finite, bounded, sequence-checked and rate-limited. Missing movement input expires after 350 ms. Only the host can start, only the chaser can call, only the target can PASS and only its recipient can acknowledge. Catch checks precede acknowledgement processing. This protects the prototype from ordinary malformed client actions; a player-host can still modify their authoritative game. Production requires trusted dedicated hosting, service-side authentication, abuse controls and transport review.

`arena.gd` builds a single park from primitives. `avatar.gd` renders server state and animates proxy limbs. `main.gd` manages the camera and camera-relative movement. `game_hud.gd` uses one shared modal for help and records. `touch_controls.gd` separates left-side joystick and right-side camera finger IDs.

Survival total measures time as an eligible runner. Streak records span successive rounds until the player becomes chaser or is eliminated. Records live only in the current process/session. No database, cloud account, voice transmission or analytics is present.

All code, icon, geometry, character proxies and synthesized tones in this milestone are original generated project content. No third-party models, textures, fonts, music or asset packs are bundled. Godot's engine license and notices remain subject to its distribution terms when exporting; export templates are not included here.
