# ProjectMine 0.4c validation

Godot 4.7.2, OpenGL Compatibility, Mesa 25.2.8, Intel UHD Graphics 620 (WHL GT2), native 1920 × 1080 viewport, VSync disabled. No other ProjectMine process was running during the two recorded runs. Three-second warm-up, six-second measurement; see `tests/active_combat_benchmark.gd`.

Both production drone FSMs remain active. The fixture puts both drones in the lower encounter chamber and alternates player fire between them. Health is increased only in this test to keep the encounter running; projectile speeds, damage and fire intervals are unchanged. Production health and encounter placement are untouched.

| Measurement | Run 1 | Run 2 |
| --- | ---: | ---: |
| Mean FPS | 64.15 | 56.44 |
| Mean frame time | 15.59 ms | 17.72 ms |
| 95th-percentile frame time | 21.10 ms | 22.74 ms |
| Mean draw calls | 108.34 | 108.39 |
| Peak live projectiles | 4 | 4 |
| Peak impact bursts | 5 | 5 |
| Player shots, including warm-up | 65 | 65 |
| Enemy shots per drone | 7 / 7 | 7 / 7 |
| Shield damage received | 140 | 140 |
| Damage to the two drones | 640 / 620 | 640 / 620 |

Raw outputs: `combat_vfx_run1.json`, `combat_vfx_run2.json`. Desktop/GPU scheduling and power state are uncontrolled, so the difference between runs is not attributed to the implementation. Early runs with a second game instance open were discarded. These measurements do not establish a before/after performance delta or guarantee locked 60 FPS.

## Rendering budget

Two shadowless ship spotlights replace the original single headlight. No muzzle, projectile or impact lights are added. Four cached shader materials (two factions × streak/billboard) and shared quad/crossed-ribbon meshes serve all shots. Each projectile draws one four-triangle streak and one two-triangle head. Each impact has one flash and one six-spark procedural mesh, lasting at most 260 ms. The global cap is 24 bursts; the fixture reached five. There are no external VFX textures, GPU particles, persistent decals, screen-space effects or bloom. Pooling is deferred because this bounded encounter does not show a large population of live effects.

## Checks

- Headless editor/import: no parser errors.
- New lighting/VFX test: two warm shadowless lamps, L toggle and key-repeat protection, HUD status, configurable intensity, pitch/roll inheritance, actual-velocity trail alignment and length bounds, short muzzle flashes, shared resources, faction colors, six-spark limit, burst cap, cleanup and subtle shield feedback.
- Existing prototype/combat/model/industrial/proximity/parking-audio tests pass. Collision audit passes 4,896 clearance samples, 1,742 enclosure rays and 56 cruise/boost collision cases, including pitched and rolled poses.
- Native Compatibility preview (including a frozen, actually swept 40 ms side view of both trails) inspected with headlights on/off in horizontal and rolled vertical tunnels; player firing, drone firing and damage feedback rendered without shader errors.
- Native mouse test passes capture/release/recapture, relative ship aiming and existing fire handling.

The accelerated headless proximity/mouse fixture can report three Dummy-audio playback objects at shutdown; its native-display run exits cleanly. Gameplay and the new VFX tests show no such shutdown warning. Proximity audio code was preserved.

Preview fixture camera poses and actor pauses apply only to inspection. Gameplay retains its existing 90° first-person camera, AI, colliders, weapon origins, damage and movement values. Screenshots are in `docs/previews/ship_headlights.png`, `vertical_headlights.png` `combat_energy.png` and `combat_trails.png`.
