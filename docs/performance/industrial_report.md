# Industrial section performance — 0.4a

Measured on 2026-11-23 using Godot 4.7.2, Compatibility/OpenGL 4.6, Mesa Intel UHD Graphics 620 (WHL GT2).

## Method

The same build and camera poses were tested with `industrial_upgrade` disabled and enabled. Each pose warmed up for 1.2 seconds, then collected 3 seconds of wall-clock frame timings. Fullscreen output and captured framebuffer images were verified as **1920 × 1080**, with 3D resolution scale 1.0. VSync and the frame cap were disabled for measurement. Benchmark canvas scaling is disabled to keep viewport coordinates equal to physical pixels; normal gameplay retains the existing HUD scaling.

Both original drone models remain rendered, but AI/movement and proximity audio are paused in the benchmark to keep the scene comparable. Debug overlays are off. This measures these views, not the worst case for the entire map or a combat stress test. Desktop activity, power limits and shared-memory GPU clocks can change results.

## Results

| View | Baseline FPS | Industrial FPS | Mean frame ms, before → after | 95th percentile ms, before → after | Draw calls, before → after |
| --- | ---: | ---: | ---: | ---: | ---: |
| Portal approach | 69.9 | 83.4 | 14.30 → 11.99 | 17.31 → 15.95 | 148 → 164 |
| Inside corridor | 52.5 | 77.5 | 19.04 → 12.90 | 22.58 → 16.66 | 105 → 119 |
| Oblique wall/detail view | 53.7 | 77.0 | 18.61 → 12.99 | 22.95 → 16.65 | 93 → 106 |

Raw results: [baseline JSON](industrial_before.json), [industrial JSON](industrial_after.json). Counters are engine-wide rendered draw calls/primitives, not the polygon count of the new assets alone. The final signage adds one batched plate; it does not require an additional material batch.

The extra decoration increases rendered geometry, but local light isolation reduces expensive overlapping light evaluations on the corridor surfaces. Five original cyan corridor lights are hidden; three warm, shadowless fixture lights illuminate the new render layer. Legacy room lights still illuminate the unchanged areas and actors, but are excluded from the industrial surfaces. The shader uses one shared texture fetch and a cheap constant indirect-light approximation instead of GI, screen-space effects or triplanar blending.

The section contains **305 decorative instances in 11 MultiMesh batches**, four shallow exposed-rock patches, a maintenance plate label, and three shadowless lights. Seven reusable material resources share one 256 × 256 seamless procedural noise texture. Small lamp glass/status indicators use two unshaded materials; no red real-time lights, shadows, reflections, volumetric fog or new post-processing passes are added.

A separate fullscreen run with the normal gameplay/HUD scaling and VSync enabled reported approximately **60–61 FPS** inside the corridor. The remainder of the mine retains its previous visuals and lighting; these measurements do not claim that the whole map has been optimized.

## Reproduce

```sh
godot --path . --script tests/visual_benchmark.gd -- --baseline --output=/tmp/industrial-before.json
godot --path . --script tests/visual_benchmark.gd -- --output=/tmp/industrial-after.json
# Optional framebuffer captures for each pose:
godot --path . --script tests/visual_benchmark.gd -- --capture=/tmp/industrial-preview
```

A real display and GPU are required. The tool temporarily switches its own window to fullscreen and exits when finished. `docs/.gdignore` keeps performance data and preview PNGs out of Godot's runtime asset imports.
