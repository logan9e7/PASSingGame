# Original vision → current milestone

Source: the owner's Passing Game Concept v1 PDF, supplied November 22, 2026.

The intended experience is an Android-first, colorful third-person 3D multiplayer chase. Players move through a bounded playground, turn the camera, call another runner and pass the chase through a verbal acknowledgement. Survival is the objective. No combat, powers, safe zones or paid advantages.

The earlier top-down browser prototype tested rules but did not deliver that camera, character or world experience. This Godot project starts the intended game rather than extending that browser presentation.

## First milestone

One park arena, original rules, third-person camera, touch controls, local practice and reachable private LAN rooms. Geometry and characters are original procedural placeholders so movement, visibility and chasing can be evaluated before commissioning art.

## Next milestones

1. Playtest chase speed, camera, readability and acknowledgement timing with four people; validate touch and sustained running on physical Android devices.
2. Establish the final stylized character and park direction, then replace proxies with licensed original assets and proper animation/audio.
3. Export a signed Android test build with templates, SDK and signing configured; measure frame time and thermal performance on target phones.
4. Introduce dedicated authoritative hosting and room discovery for private online rooms and Quick Match. Nakama/Postgres is a candidate from the concept, not an installed dependency or implemented service.
5. Add voice acknowledgement with an explicit confirmation path and microphone permission UX; define persistence, reconnect, moderation and production operations before public release.

## Rules decisions needing live feedback

A runner crossing the boundary is eliminated without ending the round. If that runner was the target, the target clears and the chaser calls another runner. If no runners remain, or the chaser exits/disconnects, the round stops without awarding a catch. These resolve unspecified edge cases without adding powers. A pending PASS never protects the current target.
