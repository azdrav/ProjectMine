# Industrial security drone — 0.4b asset and performance validation

Blender 4.0.2 and Godot 4.7.2 were used on 2026-11-23. The generator completed, the saved `.blend` was reopened in Blender, and a second generation produced a byte-identical GLB. The GLB validator confirms the header, embedded resources, triangles, PBR maps, component nodes, transformed bounds and forward-facing attachment points.

## Asset budget

- 4,134 base triangles, five rigid mesh components, three material resources.
- Eight material surfaces in the imported model; the small muzzle flash is visible only when firing.
- Two embedded 512 × 512 atlases: base colour and standard roughness(G)/metallic(B).
- GLB: 530,804 bytes, approximately 0.51 MiB. Source `.blend`: approximately 1.4 MiB with packed images.
- Dimensions: 1.46 m wide × 0.852 m high × 1.155 m deep. Origin is the original actor/physics origin; +Y is up and -Z is forward.
- Existing 0.70 m sphere, collision layers/masks, AI, patrol paths, damage and projectile logic are unchanged.
- No imported cameras, lights, collision bodies, skeleton or runtime Blender dependency. Godot import embeds GPU-compressed Basis textures rather than extracting PNG files. The source-only studio and `.blend` live under `.gdignore`.

## Actual Compatibility render

The model was reviewed inside the industrial corridor at 1920 × 1080 with the existing lighting and Compatibility renderer on Intel UHD 620. The red optic and two blue propulsion indicators render with standard glTF emission; they do not need bloom or real-time lights. The preview reported 60 FPS with VSync enabled. Both a normal and a hit/fire feedback screenshot were captured.

The existing three-view uncapped benchmark was run before replacing the placeholder and after the final embedded-Basis import. Earlier extraction-mode samples reached 79–81 FPS; the final saved run ranged from 53 to 74 FPS, so a universal 60 FPS at 1080p is not claimed. Draw calls and primitive counts decrease, but texture/import formats and shared-GPU desktop load can affect frame times. Resolution, scene and industrial lighting were the same, with AI paused for repeatable views. Frame timings are short desktop samples and can vary with GPU clocks/background load; fewer draw calls do not imply every view must have higher FPS.

| View | FPS, placeholder → GLB | Draw calls, placeholder → GLB | Rendered primitives, placeholder → GLB |
| --- | ---: | ---: | ---: |
| Approach | 85.8 → 74.0 | 164 → 132 | 22852 → 14189 |
| Corridor | 76.4 → 53.5 | 119 → 103 | 15722 → 12580 |
| Oblique view | 73.1 → 53.4 | 106 → 90 | 15496 → 12354 |

Raw data: [before](drone_before.json), [after](drone_after.json). Engine counters include the whole rendered frame, not just the robot. See the [original method](industrial_report.md) for benchmark settings.

## Validation and limits

`tests/drone_model_smoke.gd` verifies Godot's imported triangle count, scale, origin, component hierarchy, muzzle/optic positions, embedded PBR textures, standard emissive surfaces and per-robot feedback material isolation. It also checks recoil, propulsion motion and that animation leaves the physics transform untouched. The existing combat test verifies actual patrol, detection, attack, damage, destruction and restart with the imported visual.

The visual muzzle node is used for flash/recoil; projectile sweeps still originate at the actor centre, preserving the existing point-blank collision safety. The collider intentionally remains the existing approximate sphere rather than matching every protruding bolt/propulsion shroud. Emission is visibly bright geometry, not GI or light cast onto surrounding walls.

The installed Blender glTF exporter prints a diagnostic about its unavailable optional Draco library even though compression is explicitly disabled, and a shared-sampler warning while combining roughness and metallic channels. Neither prevents export: the validated asset is uncompressed, uses ordinary glTF PBR with two embedded images, and imports directly in Godot without a Draco decoder. No manual pipeline step is required. Final aesthetic judgment and close-up playtesting remain available through the source and preview commands.
