# ProjectMine 0.6 — environmental audio validation

Godot 4.7.2 / Compatibility renderer, Mesa Intel UHD Graphics 620. No external audio downloads or third-party licensing dependencies were introduced. Existing sounds remain in the industrial bank; the new ambience uses original procedural placeholders.

## Routing and acoustic behavior

The system uses one fixed external reverb bus with unity direct gain, not an assumed crossfade between arbitrary effects. Oriented analytic zone boxes produce normalized targets, then supported reverb parameters interpolate over time. A wet ceiling of 0.18 limits rapid-fire buildup. Internal shield, collision and scraping channels keep their existing IndustrialFX route; sonar keeps Master. Local player discharge and external source groups receive environmental reflections. Per-owner buses add independent occlusion gain and low-pass filtering before the shared reverb.

The manager owns 12 source-filter slots and one reverb bus, created once and removed on teardown. Six ambient anchors target at most three loops, with bounded crossfades; one event voice is scheduled at 14–32 s intervals. Both enemies' three original 3D channels are grouped per actor. Source cleanup, additional streams on one owner and repeated encounter reset are tested. No nodes with physics collision or visual geometry are introduced.

## Native acoustic output

Application-only PipeWire/PulseAudio null-sink monitoring captured actual Godot audio, not microphone input. The normal ambient fixture visited chamber, concrete corridor, shaft, steel tunnel and exterior fallback, then combined ambience, a sparse event and a 16-shot rapid burst. **No clipped samples** were found; the final mono mix peaked at approximately **0.299 linear**. Near-field caps prevent ambient anchors from becoming loud when the listener approaches them.

An isolated weapon-tail fixture muted ambient loops and used the same firing sample in each zone. RMS values below cover 0.4–1.4 s after the shot onset, after the direct 0.23 s discharge has ended:

| Listening profile | Tail RMS |
| --- | ---: |
| chamber | 0.00265254 |
| concrete | 0.00022521 |
| shaft | 0.00605157 |
| steel | 0.00022815 |
| open | 0.00000994 |

The measurements distinguish the longer chamber/shaft tails from the restrained corridor/steel tails and nearly dry open fallback. They do not establish physically accurate room responses or subjective sound quality. See `acoustics_06_tails.json`, `acoustics_06_tails_capture.json`, `acoustics_06_tail_analysis.json`, `acoustics_06_ambience.json` and `acoustics_06_ambience_capture.json`.

## Native occlusion and spatial positioning

A separate stereo diagnostic fixture used 180 Hz and 4,200 Hz tones, a real static wall and a source moved right/left outside the level. This test signal is not a gameplay asset. Measurements use settled windows after each move:

- At 14 m, right-channel RMS was 49.9% of its 2 m value.
- Adding a solid wall at the same distance reduced RMS to 29.0% of the unobstructed level, while remaining audible.
- The high/low tone power ratio behind the wall fell to 1.29% of the clear-path ratio, confirming actual low-pass action.
- Right-side source RMS favored the right channel by 2.00:1; moving left reversed the ratio to 2.00:1.

See `acoustics_06_occlusion_analysis.json` and `acoustics_06_occlusion_capture.json`. Default ray work is capped at three active source owners per 0.35 s; the 33 s ambient fixture recorded 273 queries (about 8.2/s). The round-robin approximation can take multiple update intervals plus its fade to catch up. It does not trace indirect paths around portals and cannot model material-dependent physical propagation.

## Performance

Native active-combat tests retain both production drone FSMs, two weapon factions and the existing graphics. Health overrides apply only inside the benchmark to keep the encounter alive. VSync is disabled; sample window is 6 s after a 3 s warm-up. No other graphical ProjectMine process was running.

| Resolution / atmosphere | Mean FPS | Mean ms | p95 ms | Mean draw calls |
| --- | ---: | ---: | ---: | ---: |
| 1280 × 720 / off | 140.97 | 7.09 | 9.89 | 94.01 |
| 1280 × 720 / on | 144.04 | 6.94 | 8.23 | 94.00 |
| 1920 × 1080 / off | 54.64 | 18.30 | 22.61 | 93.81 |
| 1920 × 1080 / on | 61.67 | 16.22 | 18.59 | 93.83 |

Runs used on/off ordering at each resolution. GPU/CPU power state and desktop load are uncontrolled, so these samples support no noticeable regression in the tested scenario, not a claim that adding audio improves performance. Draw calls remain unchanged. An early 720p measurement exposed unnecessary repeated audio-server writes; settled-value checks removed that overhead before the recorded comparison above.

The full native traversal reached all five waypoints through the unchanged controller with roll, live enemies and no static impacts. Mean per-leg rates were about 58–88 FPS at 1080p; waypoint error remained below 6.5 cm, both enemies stayed active and shield damage occurred. See `traversal_06.json`. This is programmed input/orientation, not a human playthrough.

## Regression and lifecycle checks

- Headless editor/import and new acoustic smoke: seven zones; distinct profiles; continuous spatial boundaries and temporal interpolation; dry gain/wet cap; internal/external routes; real wall occlusion and clearing; explicit player/source exclusions even with their physics layers selected; loop/event limits; cached PCM/headroom/seam boundaries; automatic event timing; disabled scheduling; no enemy spawning/damage; pooled-source cleanup and encounter restart; custom source registration; bus cleanup.
- Existing flight, combat, drone model, lighting/projectile VFX, industrial visuals, proximity, parking audio and industrial collision/scrape suites pass.
- Geometry audit: 4,896 clearance samples, 1,742 enclosure rays and 56 cruise/boost collision cases, including pitched/rolled poses. Collider signatures and the existing shell visual bounds remain identical.
- Native mouse capture/release/recapture regression passes.
- `preserved_06.sha256` records unchanged player controller, AI, proximity module, ship audio and industrial PCM generator. From the repository root: `sha256sum -c docs/performance/preserved_06.sha256`.

Accelerated headless testing initially exposed pending Dummy-audio playback references during shutdown. Automatic ambient/event playback is now skipped without a display, while zone logic, event signals and timing still run. Explicit test-source playback remains possible. The accelerated audit subsequently exits cleanly; real audio verification uses native display/audio runs.

## Limits requiring listening or future work

Profiles approximate the listener's current space. Source-room convolution, portal propagation, HRTF-specific vertical localization and physically accurate material acoustics are not implemented. Occlusion is a smoothed line-of-sight approximation; very fast movement can outrun its update interval. Voice-budget changes can fade out lower-priority loops; a full filter pool retains basic external playback/reverb without per-source filtering.

Timbre, tension, acceptable bass levels and comfort on the user's own speakers/headphones cannot be certified automatically. The sources are deliberately restrained procedural placeholders, ready to be replaced with verified licensed recordings later. No Silent Running, passive sonar or enemy hearing behavior was added.
