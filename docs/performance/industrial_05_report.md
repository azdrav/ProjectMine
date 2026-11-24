# ProjectMine 0.5 validation and performance

Godot 4.7.2, Compatibility/OpenGL, Mesa 25.2.8, Intel UHD Graphics 620. Measurements use a native viewport at the stated resolution, VSync disabled. Only one graphical game instance was running. Early measurements with a second game window open were discarded. Desktop/GPU power state remains uncontrolled; these are observed results, not guaranteed frame rates.

## Whole-mine comparison at 1920 × 1080

`tests/environment_benchmark.gd` measures six identical camera poses, 0.8 s warm-up and 2 s sampling per pose. `--reference` disables only the new extension, retaining the existing 0.4a corridor. Both variants use the new audio module, with AI paused for these static views.

| View | Reference FPS | 0.5 FPS | Draw calls, reference / 0.5 | 0.5 p95 frame ms |
| --- | ---: | ---: | ---: | ---: |
| launch | 84.6 | 65.7 | 140 / 92 | 17.80 |
| lower_chamber | 57.7 | 62.1 | 53 / 50 | 18.91 |
| vertical | 40.4 | 59.5 | 70 / 68 | 19.49 |
| upper_chamber | 46.0 | 57.6 | 72 / 65 | 20.61 |
| incline | 46.8 | 61.0 | 46 / 52 | 19.14 |
| reactor | 85.7 | 86.6 | 33 / 37 | 14.25 |

Materials and lighting are substantially different between versions. Mixed gains/losses and short measurement windows do not establish a universal performance improvement. Raw observations are in `environment_05_before.json` and `environment_05_after.json`.

## Live combat

Both production drone FSMs run in the lower encounter chamber, with player fire alternating between them. Fixture-only health increases keep them alive through the 3 s warm-up and 6 s measurement; production health, damage, speed and fire intervals are unchanged.

| Setup | Mean FPS | Mean ms | p95 ms | Mean draw calls |
| --- | ---: | ---: | ---: | ---: |
| Reference visuals, 1080p | 58.70 | 17.04 | 20.00 | 108.33 |
| 0.5, 1080p | 50.74 | 19.71 | 23.57 | 93.88 |
| 0.5, 1280 × 720 | 110.25 | 9.07 | 12.26 | 93.94 |

The 1080p combat pair shows a measurable frame-time cost from the full-mine materials despite fewer draw calls. The default 720p window has considerably more headroom. No resolution, renderer or gameplay setting was reduced to obtain the 1080p results. Combat tests recorded 65 player shots, 7 shots from each enemy and 140 shield damage, with at most five live bursts/four projectiles. Raw outputs are in `combat_05_reference.json`, `combat_05_1080.json` and `combat_05_720.json`.

## Geometry budget and preservation

- 646 new decorative pieces, merged into 41 spatial/material MultiMesh batches across six areas. The 0.4a corridor's 305 pieces/11 batches remain.
- 71 existing box shell visuals are rendered in 15 spatial/material batches with identical world bounds. Original bodies, masks, dimensions and the four unique mitered wall meshes remain intact.
- Decoration has no physics nodes. Camera-clearance bounds are verified from CPU instance transforms, since the headless Dummy renderer does not return reliable MultiMesh instance transforms.
- Warm lighting reuses the existing fixtures, with redundant shaft lights disabled and ranges reduced to limit overlap. No additional lights are introduced by the extension. All practical lights and both ship headlights are shadowless.
- Small decoration is culled beyond 42 m with a 3 m hysteresis margin. Enclosure geometry remains visible at all distances. No external textures or sound assets were added.

## Audio validation

Five cached 22,050 Hz PCM recipes cover the two weapon factions, shield, hull impact and scraping. Non-looping PCM peaks are normalized to 0.65; the seamless periodic scrape loop peaks at 0.24. Diagnostic spectral checks show a lower energy centroid for player fire (about 478 Hz) than enemy fire (772 Hz), and less than 1.6% of weapon energy above 6 kHz. These checks support the heavier/softer-high-frequency design; final taste and volume remain adjustable.

A native application-only PulseAudio/PipeWire monitor capture of the staged launch-bay fixture measured a peak of 0.295 linear and **zero clipped samples**. It recorded one heavy hull impact, two distinct scrape episodes, five shield sounds and zero scrape gain after separation. Gentle contact, stopping and separation were included; no microphone was recorded. See `audio_05_capture.json` and `tests/industrial_audio_runtime.gd`. The `IndustrialFX` limiter reserves -6 dB of master headroom; proximity audio is not routed through it or modified.

## Checks

- Headless editor/import and runtime parser checks.
- Dedicated audio smoke: cached PCM/headroom/loop boundary; real low/high-speed and rolled/pitched hull collisions; pre-resolution normal speed; read-only physics observer; no impact repetition at rest; slow/fast and exactly parallel sliding; no per-frame loop restart; stopping/separation; shield intensity/cooldown/math; reset cleanup.
- Industrial visual smoke: full collision signature equality, exact shell render bounds, all six new areas, no decorative physics, protected camera volumes and bounded batches.
- Collision audit: 4,896 clearance samples, 1,742 enclosure rays and 56 cruise/boost cases, including rolled/pitched collisions.
- Existing flight, combat, GLB model, proximity, parking audio and lighting/projectile VFX tests.
- Native mouse capture/release/recapture and aiming regression.
- Native full-route flight through the actual controller, including roll, both shaft junctions and the angled tunnel and live AI. All five waypoints reached within 6.5 cm, no static impacts, both enemies remained active and inflicted shield damage. Survival shield override is fixture-only. `traversal_05.json` contains per-leg FPS and positions.

The traversal fixture uses programmed input/orientation, not a human playthrough. The dedicated runtime audio fixture and graphical captures verify actual engine output; subjective sound balance remains user-adjustable in Ship/Audio. Preview images are in `docs/previews/industrial_05_*.png`.
