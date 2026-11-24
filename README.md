# ProjectMine 1.1 — Ammunition & Homing Missiles

A self-contained Godot 4 / GDScript first-person 6DoF spaceship combat prototype. All runtime assets are included; no external art downloads or plugins are required. Blender is needed only to regenerate the authored drone model.

## Launch

Open `project.godot` in Godot 4 and press **F6** with the test mine open, or **F5** to run the configured main scene. From this directory:

```sh
godot --path .
```

Tested with Godot 4.7.2. Uses the Compatibility renderer and built-in Godot physics.

## Controls

| Input | Action |
| --- | --- |
| W / S | Forward / backward |
| A / D | Strafe left / right |
| Space / Ctrl | Rise / descend along ship up |
| Mouse movement | Aim by rotating the ship (yaw / pitch) |
| Escape / left click | Release cursor / recapture (recapture click does not fire) |
| P | Toggle proximity warning system |
| L | Toggle both ship headlights |
| F3 | Toggle collision wireframes (green hull, cyan level) |
| F4 | Toggle enemy state / health / detection labels |
| C | Toggle the complete 3D cockpit and functional dashboard / classic HUD |
| F6 | Toggle camera shake (restores last enabled intensity) |
| [ / ] | Decrease / increase shake intensity by 10 percentage points |
| F | Interact with nearby mission controls |
| F5 / F9 | Save / load mission |
| Up / Down arrows | Pitch up / down |
| Left / Right arrows | Yaw left / right |
| Q / E | Roll left / right |
| Shift | Boost while moving; consumes energy |
| Left mouse / Enter | Fire primary cannons; consumes finite cannon ammo and existing energy cost |
| Right mouse | Launch homing missile after confirmed lock |
| R | Restart encounter; restore position, orientation, shield, energy and both drones |

All movement and rotation follow the ship's current orientation. There is no gravity, automatic leveling or external ship model. Releasing movement smoothly brakes the ship. Energy regenerates whenever boost is inactive. After boost runs out, release Shift to rearm it; the HUD shows a reminder. Speed reports actual travel, including when blocked by a wall. Shield starts at 100%. Enemy lasers deplete it; at zero the ship is disabled until R restarts the encounter.

## Test mine

Follow cyan lighting from the launch room through the horizontal corridor into the shaft chamber. Ascend through its ceiling into the upper room, then continue forward through the rising angled tunnel to the final chamber. The route is reversible. Numbered room signs help orientation. Walls block the ship and lasers; laser hits produce brief expanding flashes. Two security drones patrol the shaft chamber and upper chamber. There is no random generation or multiplayer.

## Structure and tuning

- `scenes/levels/` and `scripts/levels/`: main scene and fixed primitive test layout, lights, collision and input bindings.
- `scenes/player/` and `scripts/player/`: CharacterBody3D ship, cockpit camera and headlight. Select Ship to tune exported cruise speed, boost multiplier, acceleration, deceleration, rotation speed and rotation acceleration in the Inspector.
- `scenes/weapons/` and `scripts/weapons/`: laser scene, swept collision ray and timed impact effect.
- `scenes/ui/` and `scripts/ui/`: crosshair, speed, shield, energy and controls.
- `tests/`: automated physics smoke test, including clearance along the full route.

The level's `_ready()` builds a fixed authored arrangement of primitive walls; it does not generate random terrain. Laser raycasts sweep the entire distance traveled each physics frame to prevent tunneling through walls.

## Validation

```sh
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script tests/prototype_smoke.gd
```

The smoke test checks player-sized clearance through every passage, local-axis acceleration, braking, boost and energy, compound rotation, projectile collision/cleanup and reset. Interactive X11 playtest on the Intel UHD 620 Compatibility renderer completed the full route and return trip (horizontal corridor, vertical shaft, angled tunnel and final chamber) at approximately 60 FPS. All movement and rotation bindings, reset, boost depletion/rearm, both fire bindings, HUD and wall impacts were checked.

Playtest fixes: actual speed at walls, stable boost depletion with release-to-rearm, point-blank laser collision, and a smaller impact flash. Regression tests cover the corrected behaviors.

## 0.2 proximity warnings and mouse aiming

The cursor is captured at launch. Move the mouse to rotate the actual ship; the camera remains fixed to the cockpit. Arrow aiming, Q/E roll and all movement/inertia are preserved. Left mouse fires while aiming. Escape releases the cursor, and clicking the game recaptures it. The recapture click is consumed, and the first motion event is discarded to prevent a cursor-warp rotation jump. Losing window focus also releases the cursor. Mouse displacement is accumulated and applied in the existing physics rotation step without multiplying it by frame time.

Select **Ship** in `scenes/levels/test_mine.tscn` to tune `mouse_sensitivity` (default 0.0025 radians per pixel) and `invert_mouse_y`. Mouse rotation has no artificial horizon or pitch clamp.

The **Ship/Proximity** child is an independent sensor/audio module in `scripts/systems/proximity.gd`. Set its exported `enabled` property, or press **P**, to disable/re-enable it without changing flight or weapons. The compact upper-right panel displays all six ship-relative directions. Yellow means warning, orange means urgent, red means critical; a stronger outline marks the nearest relevant obstacle. Its summary shows hull clearance and TTC when closing. P displays a brief enabled/disabled status message.

Six RayCast3D probes scan at 30 Hz after ship movement. They explicitly exclude the ship, ignore areas and query level layer 1 plus drone layer 3 in the combat scene (bitmask 5). Lasers, lights and impact visuals have no collision body and are not detected. Put new physical obstacles on the configured sensor mask. Hull clearance subtracts the player collider's extent (currently a 0.55 m sphere) plus a 0.02 m allowance. Sphere and box colliders are supported; other hull shapes use a conservative configurable allowance with a 0.55 m base. Probes measure along six axes rather than a full volumetric sweep.

Closing speed uses `get_real_velocity()` projected onto the detected surface's inward normal. TTC uses hull separation along that normal divided by closing speed, so facing a wall alone does not imply a collision course. Clearance now drives parking-style beeps even while stationary, moving parallel to a wall or receding. TTC can only accelerate that cadence during rapid closing; it never suppresses distance warnings. Nearby tunnel sides therefore produce slow beeps under this parking-style behavior.

Select **Ship/Proximity** to configure:

| Export | Default | Meaning |
| --- | --- | --- |
| `detection_distance` / `collision_mask` | 4 m / layers 1 + 3 | Probe range beyond the hull and obstacle layers |
| `hull_margin` / `scan_rate` | 0.02 m / 30 Hz | Extra hull allowance and scan frequency |
| `warning_range` / `urgent_range` / `rapid_range` / `critical_range` | 4 / 2 / 1 / 0.4 m | Clearance severity thresholds; keep them in descending order |
| `minimum_closing_speed` | 0.25 m/s | Minimum projected motion for TTC acceleration only |
| `warning_ttc` / `urgent_ttc` | 1.2 / 0.5 s | TTC cadence sensitivity / extra HUD urgency |
| `distance_hysteresis` / `ttc_hysteresis` | 0.05 m / 0.15 s | Extra release margin to avoid threshold chatter |
| `release_delay` | 0.18 s | Brief hold before lowering a warning state |
| `audio_volume_db` / `tone_frequency` | -12 dB / 880 Hz | Warning volume and oscillator pitch |
| `slow_beep_interval` / `medium_beep_interval` / `rapid_beep_interval` / `fast_beep_interval` | 1.2 / 0.7 / 0.3 / 0.1 s | Interpolated onset intervals at 4 / 2 / 1 / 0.4 m |
| `sensor_switch_margin` | 0.15 m | Retain selected axis until another obstacle is meaningfully nearer |
| `ttc_cadence_boost` | 0.35 | Maximum fractional interval reduction due to rapid closing |
| `beep_duration` | 0.065 s | Short gated tone; interval always retains a silent gap |

Detection distance bounds the available look-ahead, even if TTC sensitivity is increased. Continuous tone is reserved for critical clearance. A single looping, low-amplitude PCM oscillator is synthesized using Godot's AudioStreamWAV and AudioStreamPlayer on the Master bus; a gain envelope produces beeps without overlapping voices or clipping. There are no audio asset dependencies. Disabling the module stops audio immediately; an unfocused game is also silent. Oscillator pitch is built when the module enters the scene; reload after changing pitch.

Additional validation commands:

```sh
godot --headless --path . --script tests/proximity_mouse_smoke.gd
# A real display is required for capture/release/recapture checks:
godot --path . --script tests/proximity_mouse_smoke.gd
```

0.2 validation includes six-axis clearance and rotated axes, actual lateral closing speed/TTC, stationary/parallel/receding distance warnings, critical proximity, hysteresis, slow tunnel beeps, toggle/status behavior, oscillator headroom/cadence, and mouse rotation/capture/inversion. The original flight/laser smoke test still passes. Live X11 testing verified OS mouse input and firing, P toggling, the full mine route and approximately 60 FPS on Intel UHD 620. An isolated system-audio monitor confirmed non-clipping tone output and zero output after disabling proximity.

## Progressive parking audio

Clearance is the primary audio input, including at rest:

| Hull clearance | Beep interval (smoothly interpolated) |
| --- | --- |
| Above 4 m | Silent |
| 2–4 m | 700–1200 ms |
| 1–2 m | 300–700 ms |
| 0.4–1 m | 100–300 ms |
| Below 0.4 m | Continuous tone |

The cadence changes without waiting for the old slow-beep deadline. Pulses are normally 65 ms; configured durations are shortened automatically to retain silent gaps. Continuous tone is controlled only by critical distance, never by TTC. A 5 cm release margin and brief release delay stabilize the warning/continuous boundaries; an existing warning can remain just beyond 4 m during that release guard. The selected direction retains its 15 cm switching margin without restarting the audio phase. Audio volume defaults to -12 dB for clearer pulses with ample oscillator headroom.

Regression checks include actual hull clearances at 4.5, 3, 1.5, 0.7 and 0.25 m, stationary warning persistence, piecewise interpolation, threshold hysteresis, rapid cadence adjustment, TTC acceleration and pulse separation:

```sh
godot --headless --path . --script tests/parking_audio_smoke.gd
# Requires a real display and audio driver; captures the mixed waveform on a test bus:
godot --path . --script tests/parking_audio_runtime.gd
```

The rendered audio test measures real pulse intervals, silence and continuous output at several stationary distances, including 0.45 m just outside continuous range, and checks for clipping. Run it with the game window focused.

## 0.2.1 collision geometry audit and fix

The escape was reproduced **before changing geometry**, at ordinary 18 m/s flight speed. The player used a centered sphere of radius 0.55 m (1.1 m diameter), layer 2, with obstacle mask 1. All 75 static wall/trim bodies used layer 1. The horizontal corridor and vertical shaft already overlapped their room walls correctly.

The fault was the angled tunnel's end cuts. Its four wall boxes ended perpendicular to the slope and extended only 0.4 m beyond their centerline endpoints, while the adjoining room openings lie on vertical Z planes. Across an 8 m wide tunnel rising 10 m over 20 m, the corners need approximately 2 m of additional axial reach to meet those planes. This left a wedge below the lower entrance and above the upper exit. Rays from `(0,34,-52.9)` downward and `(0,44,-71.4)` upward found no surface. Moving the original sphere downward from `(0,32,-52.9)` escaped to approximately `(0,5,-52.85)` at 18 m/s. This reproduces a real hole without requiring high-speed collision tunneling.

The angled walls now use convex prisms cut on the same planes as the room portals, with a 0.25 m overlap covering the room walls' 0.20 m half-thickness. Rendered meshes and colliders share exactly the same vertices. This closes the wedges without adding end caps, widening passages, adding a hidden outer cage, or extending sloped walls unnecessarily into rooms. The straight corridor and shaft retain their original geometry; level collision layers are now explicit.

Press **F3** to show actual collision wireframes through surfaces: green for the live player hull and cyan for all static level colliders, including the new mitered walls. The player wire follows its collision transform while moving or rotating. Press F3 again to hide the overlay; it has no collision geometry and does not affect proximity rays, lasers or mouse capture. The overlay performs no frame updates while disabled.

### Ship dimensions

A reasonable future ship envelope is **2.4 m wide × 1.5 m high × 3.2 m long**, with its cockpit/collider centered. A BoxShape3D of those dimensions was checked along the entire route before any collider change, at 0.2 m spacing and four orientations: level, 45° roll, 45° pitch and combined pitch/yaw/roll. It fits the 8 m passages and all chamber transitions, both before and after the seam repair. The box's half-diagonal is approximately 2.14 m.

**The playable hull remains the original 0.55 m sphere in this fix.** Enlarging it would change wall clearance and the feel of close maneuvering. The opening is repaired for the original hull rather than concealed by making the ship too large to fit through it. Adopting the proposed box later should also account for rotational contacts near walls, because manually rotating a non-spherical CharacterBody3D is distinct from sweeping its linear movement. Flight acceleration, braking, boost, mouse/keyboard rotation, weapons and proximity sensing code are unchanged by the geometry repair.

```sh
godot --headless --path . --script tests/collision_geometry_smoke.gd
```

The collision regression checks both hull shapes along the full route, enclosure rays from interior samples, dense scans around both angled joints and their corners, and actual CharacterBody3D movement against walls at cruise and boost speeds (18 and 39.6 m/s), including rolled and pitched orientations. It also verifies the proposed box against side walls and checks the debug overlay and collision masks. The original escape is included as a regression case. These tests are sampled coverage of the authored level, not a mathematical proof for every possible trajectory.

## 0.3 — First Contact

Two hovering industrial security drones now guard the existing mine: one in the lower shaft chamber, another in the upper room. Both stay out of the launch room at the start and patrol roomy areas with room to fly around them. Destroy both to see **SECTOR CLEAR**. At zero shield the ship is disabled; **R** restores the player and respawns both drones. R also restarts a cleared encounter. There is no contact damage or automatic shield regeneration.

Aim with the existing mouse/arrow controls and fire with **left mouse / Enter**. A bright crosshair hit marker confirms damage to an enemy. Incoming damage briefly flashes the screen red and reduces the existing shield readout. Enemy lasers are orange/red; player lasers remain green. The existing boost, inertia, roll, cursor capture/release, parking sensors, collision geometry and F3 collision display remain available. Proximity sensors also detect drone hulls using their existing configurable mask.

### Robot and AI

`scenes/enemies/security_drone.tscn` is a reusable CharacterBody3D actor with a 0.70 m radius hull (approximately 1.4 m overall span). Its primitive visual assembly has noise-textured steel, dark armor, yellow safety markings, a red optic, side thrusters, bolts and a compact laser barrel. Material noise and PCM sounds are generated in Godot; no external art, models or audio files are needed.

- **PATROL** follows predefined offsets from the spawn location, including changes in height. The body turns and moves freely in 3D.
- **ALERT** confirms the player using distance, a forward field-of-view cone and an unobstructed ray to the actual player body; it sounds an alert and turns to face the target.
- **ATTACK** approaches to a configurable standoff distance, turns toward the player and fires only when aligned, in range and with current line of sight.
- **SEARCH** moves toward the last known player position after losing visibility. It respects wall collision and returns to patrol on timeout or arrival.
- **DESTROYED** immediately disables collision and firing, shrinks/spins the chassis, emits short-lived debris and a destruction sound, then removes the actor.

This is waypoint steering, not general 3D pathfinding: a robot can stop against cover during SEARCH and abandon the attempt when its search timer expires. Sensing runs at 5 Hz per drone with staggered scans, plus a fresh LOS check before each shot. The two drones use inexpensive primitives, shared steel/audio resources and short mesh/tween effects for Compatibility rendering.

Press **F4** for optional floating labels showing state, health, LOS status and distance. These are disabled by default. F3 continues to show the player and level colliders; dynamic robot diagnostics use F4.

### Combat configuration

Select a drone instance or its reusable scene in the Inspector:

| Export | Default | Purpose |
| --- | --- | --- |
| `max_health` | 60 | Three default player laser hits |
| `patrol_offsets` | Three relative 3D offsets | Authored patrol points in world-axis offsets from spawn |
| `move_speed` / `acceleration` / `turn_speed` | 1.8 / 5 / 3 | Navigation speed, acceleration and orientation response |
| `detection_range` / `field_of_view` | 24 m / 120° | Acquisition range and full view-cone angle |
| `detection_interval` / `alert_delay` | 0.2 / 0.65 s | Sense cadence and initial reaction delay |
| `search_duration` | 4 s | Time spent investigating lost contact |
| `attack_range` / `standoff_distance` | 21 / 9 m | Fire range and desired approach distance |
| `fire_interval` | 1.25 s | Time between enemy shots |
| `projectile_speed` / `projectile_damage` | 32 m/s / 10 | Enemy laser tuning |
| `debug_visible` | false | Enemy diagnostic label |

Player weapon tuning is exported on **Ship**: `laser_damage` (20), `laser_speed` (100 m/s), `laser_interval` (0.14 s) and `laser_scene`. Energy cost and existing recharge/boost behavior are preserved.

Collision bits: **1 = level, 2 = player, 4 = drones**. Player projectiles query level + drones; enemy projectiles query level + player and exclude their shooter. Friendly drones do not take enemy laser damage, and neither faction hits its own shooter. Projectile sweeps still start at the shooter center to avoid spawning beyond a nearby wall. Player and enemy bodies also collide with each other; the passages remain 8 m wide.

### Audio and source layout

- `scripts/enemies/security_drone.gd`: FSM, sensing, waypoint steering, combat and health.
- `scripts/enemies/drone_visual.gd`: procedural materials and primitive chassis.
- `scripts/audio/combat_audio.gd`: cached PCM propulsion, alert, weapon, hit and destruction placeholders.
- `scripts/effects/combat_effects.gd`: bounded destruction debris and positional sound.
- `scripts/weapons/laser.gd`: shared swept projectile with faction masks and damage delivery.

Propulsion, alert, firing, damage and destruction sounds use AudioStreamPlayer3D with distance attenuation. The existing proximity tone remains independent. Enemy engine loops are skipped under the headless display driver; all gameplay and damage logic still runs.

### Validation

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/combat_smoke.gd
godot --headless --path . --script tests/prototype_smoke.gd
godot --headless --path . --script tests/proximity_mouse_smoke.gd
godot --headless --path . --script tests/parking_audio_smoke.gd
godot --headless --fixed-fps 60 --path . --script tests/collision_geometry_smoke.gd
```

Combat checks cover both spawns, acquisition/FOV/range/occlusion, ALERT → ATTACK → SEARCH → PATROL, vertical patrol movement, both projectile factions, wall blocking, friendly/self-fire exclusion, hit confirmation, shield depletion, destruction/effect cleanup, objective count and R restart. Baseline flight/geometry/audio tests explicitly disable encounters in their fixtures using the level's `spawn_encounters` export, so unrelated AI cannot disturb those checks. Live Compatibility-renderer testing also confirmed a real mouse-aimed kill, incoming shield damage and roughly 60 FPS on Intel UHD 620.

## 0.4a — Industrial visual test section

The existing **24 m horizontal corridor between the launch room and shaft chamber** now has an industrial mining treatment: rough concrete and exposed rock, steel reinforcement frames, rust-colored pipes/flanges, ventilation ductwork, cable ladders/conduits, equipment panels, restrained yellow/black keep-clear markings and warm caged maintenance lights. Two small red status indicators mark the far portal. The rest of the map and both enemy models are unchanged.

All decorative geometry is visual-only. A regression test compares every original collider's transform, dimensions and layers with the upgrade enabled/disabled; they are identical. Wall-mounted details stay outside the original camera's navigable volume, so near-wall and ceiling flight still work. Lasers, AI sight tests and proximity warnings continue to use the original collision shell and drone hulls.

### Reuse and tuning

- `scenes/visuals/industrial_section.tscn`: authored 8 × 8 × 24 m decorative corridor prefab, with local entry at Z=-14 and exit at Z=-38. `retrofit_existing_shell` controls the optional material/light retrofit of matching test-level surfaces.
- `scripts/visuals/industrial_section.gd`: static placement and batching of supports, services, fixtures and panels. It has no per-frame update loop or physics nodes.
- `assets/materials/industrial/`: reusable concrete, rock, steel, dark steel, painted metal, pipe and hazard materials. They share one tiling 256 × 256 procedural texture and a Compatibility PBR shader with configurable color, roughness, metallic response, world tiling and subtle variation.
- The main level's exported `industrial_upgrade` flag enables the section at scene startup. Set it false before running to compare the old visual treatment. Flight, combat and collision behavior are the same in both modes.
- The existing HUD now includes a half-second-smoothed **FPS / frame-ms** counter; `HUD.show_fps` controls its visibility.

305 repeated details use 11 MultiMesh batches. Three warm shadowless lights replace five cyan corridor lights. Render-layer isolation avoids unnecessary overlap from legacy room lights; those rooms retain their original appearance. Rock patches use shallow, low-poly geometry, and the shader uses a single shared texture sample with a small static ambient term. No GI, volumetrics, bloom, real-time shadows or external art packages are required.

### Performance and validation

On Intel UHD 620 at native **1920 × 1080**, the controlled corridor view measured **52.5 → 77.5 FPS**, with mean frame time **19.04 → 12.90 ms**. Other sampled upgraded views measured approximately 77–83 FPS. A normal fullscreen/VSync run reported around 60–61 FPS. Measurements are view-specific; AI was paused for the A/B benchmark and normal desktop/GPU load can vary.

See [method, all views and raw results](docs/performance/industrial_report.md). Preview images are documentation only and are excluded from Godot imports:

[Before](docs/previews/industrial_before.png) · [After](docs/previews/industrial_after.png)

```sh
godot --headless --path . --script tests/industrial_visuals_smoke.gd
godot --path . --script tests/visual_benchmark.gd -- --baseline
godot --path . --script tests/visual_benchmark.gd
```

Visual checks verify collision equivalence, collision-free decoration, camera clearance, batching, shadowless fixtures and the FPS counter. The existing combat, flight, parking audio, proximity and collision regression suites also pass with the upgraded section enabled.

## 0.4b — Industrial security drone model

The primitive placeholder is replaced by a Blender-authored industrial machine: a bevelled armoured casting, worn gunmetal/steel, yellow hazard paint, one large red optic, twin ducted propulsion units with restrained blue indicators, an integrated laser, mechanical pivots, radiator fins, fasteners, a lifting handle, stencilled identifier and an asymmetric service box/power cable.

The asset has **4,134 triangles**, **five rigid mesh components**, **three materials** and **two embedded 512 × 512 atlases**. Its dimensions are approximately **1.46 × 0.85 × 1.15 m**. Geometry is bevelled and uses weighted hard-surface normals. Colour and roughness/metallic variation are baked into small shared images because Blender procedural shader graphs are not portable glTF runtime materials.

### Source and runtime files

- `tools/blender/generate_industrial_drone.py`: reproducible Blender Python generator; all coordinates are specified in Godot metres and converted for Blender/glTF.
- `assets/models/enemies/source/industrial_drone.blend`: editable source with packed textures and a separate source-only inspection studio.
- `assets/models/enemies/industrial_drone.glb`: self-contained runtime asset, approximately 0.51 MiB.
- `assets/models/enemies/industrial_drone_manifest.json`: triangle count, bounds, pivot names, units and attachment coordinates.
- `tools/blender/validate_industrial_drone.py`: standard-library GLB validation; no Blender/Godot module required.

The source folder has `.gdignore`, so Godot imports the GLB directly and never launches Blender to import the `.blend`. The committed GLB import settings embed the images as GPU-compressed Basis textures in the imported scene, avoiding generated external PNG dependencies and texture UID warnings. The source studio's lights/camera are explicitly excluded from export. Only meshes, rigid-component pivots and attachment nodes enter the game.

The imported model uses +Y up and **-Z forward**, with an identity root transform. `Chassis`, `PropulsionLeft`, `PropulsionRight`, `Optics` and `Weapon` remain separate. `Muzzle` is at `(0.235, -0.18, -0.68)` relative to the actor; `OpticalAxis` marks the forward sensor. No corrective scene rotation or scale is required.

### Integration and feedback

The existing enemy AI script is unchanged. The original sphere collider (radius 0.70 m), detection, patrol points, health, weapon damage/speed/rate and projectile masks remain intact. `Visual.hit()` still receives the existing damage callback. Visual firing feedback observes the existing `shots_fired` counter, so it needs no AI or weapon-logic change.

The visual hierarchy gently hovers with the original 3.5 cm amplitude. Propulsion pivots tilt by about one degree and blue emission pulses subtly. Firing adds a short muzzle flash and 2.2 cm receiver recoil; hits briefly brighten the optic. Emissive materials are duplicated only for per-robot feedback, while geometry and atlas textures remain shared. One drone being hit therefore does not flash the other. No new real-time lights, bloom, physics bodies or collision shapes are added.

The muzzle is a visual attachment; the existing safe projectile sweep origin at the actor centre is preserved. Moving components and hover never affect the collision body, and the existing destruction animation still shrinks/spins the complete `Visual` hierarchy.

### Regenerate and validate

Tested with installed **Blender 4.0.2**:

```sh
blender --background --python-exit-code 1 --python tools/blender/generate_industrial_drone.py -- --render
python3 tools/blender/validate_industrial_drone.py
godot --headless --editor --path . --quit
godot --headless --path . --script tests/drone_model_smoke.gd
godot --headless --path . --script tests/combat_smoke.gd
# Actual in-engine material/feedback preview; requires a display:
godot --path . --script tests/drone_model_preview.gd
```

Generation overwrites the generated `.blend`, GLB and manifest. Keep durable design edits in the Python script, or save a separate copy of manually edited source before regenerating. `--render` also creates a transparent Blender studio PNG in the source folder. The Godot preview writes normal and hit/fire images to `/tmp` and uses a temporary close-up camera; gameplay FOV and level placement are unchanged.

Blender generation/reopening, GLB validation, Godot import and model/animation tests pass. The existing combat suite confirms patrol, detection, attacks, damage, destruction and restart with the GLB visual. Representative 1080p Compatibility benchmark views measured approximately **53–74 FPS** on Intel UHD 620; the close-up preview ran at 60 FPS with VSync. [Full validation, measurements and exporter notes](docs/performance/drone_report.md).

[Blender preview](docs/previews/industrial_drone_blender.png) · [Godot preview](docs/previews/industrial_drone_godot.png) · [Hit/fire feedback](docs/previews/industrial_drone_feedback.png)

## 0.4c — Ship lighting and combat effects

**L** toggles two warm-white ship headlights. Their moderately wide beams rotate with the complete ship, including vertical flight and roll. Both are shadowless for Compatibility rendering. Select `Ship/Headlights` to configure `enabled`, `intensity` (3.0 per light), `light_range` (18 m), `color` and `beam_angle` (42°). Soft distance/cone falloff preserves dark areas; headlights start enabled and the HUD briefly reports toggles.

Player energy bolts now have a cyan-white core, blue halo and short tapered trails; enemy bolts use orange-red. Small paired player muzzle flashes stay below the reticle, while the drone's existing weapon attachment flashes and recoils. Trails follow the actual velocity, including inherited ship motion, and grow only behind the successfully swept projectile path. Camera-centred collision origins, speeds, damage, energy cost, fire rates and faction masks remain unchanged.

Wall impacts emit a small energy flash and six spark ribbons. Enemy hits add electrical jitter to those sparks alongside the existing local damage flash. Shield hits briefly tint the player's view blue with low opacity. Muzzle flashes last about 45 ms; impacts expire after 180–260 ms. No decals or effects persist. A shared additive shader creates the halo without bloom, textures, screen-space effects or projectile lights. Meshes/materials are cached; at most 24 impact bursts may coexist. The measured encounter peaked at four projectiles and five bursts, so pooling is deferred.

Implementation is separated into `scripts/systems/ship_headlights.gd`, `scripts/effects/player_weapon_vfx.gd`, `energy_vfx.gd`, `energy_impact.gd` and `assets/materials/combat/energy.gdshader`. Projectile visual length can be adjusted with `trail_seconds` (0.020) and `maximum_trail` (2 m). Existing flight physics, proximity logic, AI, collider geometry, level layout and combat tuning are preserved.

Validation commands:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/lighting_combat_vfx_smoke.gd
godot --headless --path . --script tests/combat_smoke.gd
# Native GPU checks; requires a display:
godot --path . --script tests/lighting_combat_preview.gd
godot --path . --script tests/active_combat_benchmark.gd
```

Two isolated 1080p active-combat runs on Intel UHD 620 measured **56.4 and 64.2 FPS** (mean), with 95th-percentile frame times of **22.74 and 21.10 ms**. Shared desktop/GPU load varies; these are observations rather than a locked-60 guarantee.

The preview writes horizontal/vertical headlight comparisons, firing and impact images to `/tmp/projectmine-04c-*.png`. Its paused actors and camera poses are test-only. The benchmark keeps both drones' AI running and fires both factions continuously; health overrides prevent premature encounter termination only in that fixture. [Performance and validation details](docs/performance/combat_vfx_report.md).

## 0.5 — Industrial audio and environment

Player firing now combines a sharp filtered transient, a low electrical discharge and short metallic resonances. Enemy fire has a shorter, higher-pitched discharge and remains positional. Player shield damage adds a metallic strike and electrical decay, with gain/pitch based on damage actually applied. A short cooldown and one shield voice prevent loud stacking; shield values and combat tuning are unchanged.

`Ship/Audio` observes the actual CharacterBody contacts after movement. Hull impacts use the incoming world velocity captured immediately **before** `move_and_slide()`, projected onto the contact normal. Gentle contacts are silent; faster normal impacts are louder and slightly lower-pitched. Scraping uses actual tangential movement along a contacted wall, a short sustained-contact delay, speed hysteresis and smooth gain fades. Impact and scrape have independent channels, so a hard glancing hit can produce both. Resting against a wall is quiet, and separating or stopping fades the scrape out. A 2.5 cm real-hull test retains an already-established contact during perfectly parallel movement; it is not a proximity sensor and does not modify physics.

All new sounds are deterministic mono 22,050 Hz PCM generated once per kind and shared from `scripts/audio/industrial_sounds.gd`. No external sound assets or additional licences are needed. The one-second scraping loop uses periodic harmonics for a seamless boundary. Weapon voices are bounded; scrape playback starts once per sliding episode rather than restarting each physics frame. `IndustrialFX` provides a limiter with a -6 dB ceiling, reserving headroom for unchanged proximity audio and drone ambience. Master volume and sonar settings are untouched.

### Audio configuration

Select the `Audio` node in `scenes/player/ship.tscn`:

| Parameters | Defaults / purpose |
| --- | --- |
| `enabled` | Enable the player's industrial audio module |
| `weapon_volume_db`, `shield_volume_db` | -9 / -10 dB |
| `full_shield_damage`, `shield_cooldown` | 25 damage / 0.09 s; intensity reference and retrigger limit |
| `impact_threshold`, `full_impact_speed` | 2.5 / 25 m/s **normal** speed |
| `impact_cooldown`, `impact_volume_db` | 0.20 s / -9 dB |
| `scrape_start_speed`, `scrape_stop_speed` | 1.5 / 0.8 m/s tangential speed; hysteresis |
| `full_scrape_speed`, `scrape_volume_db` | 20 m/s / -15 dB |
| `sustained_contact_time`, `contact_slop` | 0.055 s / 0.025 m |
| `scrape_fade_in`, `scrape_fade_out` | 0.12 / 0.16 s for a full gain transition |

Enemy weapon volume and attenuation remain on `WeaponAudio` in `scenes/enemies/security_drone.tscn`. Its stream is assigned once at startup, routed to `IndustrialFX` and reused for every shot. The existing engine, detection, damage and destruction sounds remain available. To change the shared sound character, edit the cached synthesis recipes; this never runs in the per-frame flight loop.

### Consistent mine surfaces

The original industrial corridor is joined by a launch service bay, shaft access chamber, vertical service shaft, upper ventilation/transfer chamber, angled ore passage and power gallery. They reuse the existing concrete, rock, steel, pipe, paint and hazard materials. Wall-mounted supports, maintenance panels, vents, pipes, cable ladders, ducts and warm fixtures sit outside the navigable camera volume. Red fixture faces are used sparingly in service/power areas. Spacing, patch placement and service layouts vary by function.

No physics bodies, collider dimensions, portals, patrol points or route geometry are changed. Angled-tunnel decorations are inset from the existing mitered portal cuts. Decoration has no collision and is grouped into 41 spatial/material batches for 646 new pieces. The 71 existing box-shaped shell visuals are drawn in 15 spatial/material batches with identical bounds; their original physics bodies remain active. Four unique mitered wall meshes remain in place. The original 0.4a decoration remains intact.

Existing lights are reused and retuned, with alternating shaft lights disabled to reduce overlap. The extension adds no real-time lights or shadows. Small decorative geometry has a configurable 42 m visibility range with a 3 m hysteresis margin; the enclosing walls remain visible. Adjust `decoration_distance` in `scenes/visuals/industrial_environment.tscn`, or use `extended_industrial` on the test level for an A/B visual comparison. `industrial_upgrade=false` disables both industrial visual layers for diagnostics.

### Validate 0.5

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/industrial_audio_smoke.gd
godot --headless --path . --script tests/industrial_visuals_smoke.gd
godot --headless --path . --script tests/collision_geometry_smoke.gd
godot --headless --path . --script tests/combat_smoke.gd
# Native display/audio checks:
godot --path . --script tests/industrial_audio_runtime.gd
godot --path . --script tests/mine_traversal_runtime.gd
godot --path . --script tests/environment_benchmark.gd
godot --path . --script tests/active_combat_benchmark.gd
# Default-size combat measurement:
godot --path . --script tests/active_combat_benchmark.gd -- --windowed-720
```

The audio smoke test exports diagnostic WAVs to `/tmp/projectmine-05-*.wav`. The runtime audio fixture stages firing, shield damage, gentle/heavy impact, slow/fast scraping, stopping and separation in the actual launch bay. The traversal fixture flies the complete route through the existing controller with live enemies; it raises shield only in the test to prevent premature termination. Neither fixture changes production balance. On the measured UHD 620, upgraded 1080p static views averaged **58–87 FPS**, active combat **50.7 FPS**, and the default 1280×720 combat fixture **110.2 FPS** with VSync disabled. The reference 1080p combat fixture measured 58.7 FPS, so full-mine materials have a measurable cost at that resolution. Run one graphical game instance at a time when measuring performance. [Measurements and validation report](docs/performance/industrial_05_report.md).

## 0.6 — Environmental audio and atmosphere

The mine now has quiet spatial ventilation, machinery hum and damaged-equipment buzz, with sparse creaks, pipe vibrations, distant impacts, fan starts and electrical malfunctions. These are original procedural **placeholders**, since the project contains no licensed environmental recording library. Eight cached 22,050 Hz PCM recipes add roughly 0.6 MiB of sample data. Periodic loops have seamless boundaries; event envelopes and filtered spectra avoid sharp clicks or fatiguing noise. Collision/scraping samples and the existing industrial sound bank are unchanged.

### Acoustic zones

`EnvironmentAudio` is a separate child of the test mine. Seven analytic oriented boxes cover four chambers, the concrete corridor, vertical shaft and steel ore tunnel. They add no physics bodies or Area3D nodes. Profiles are reusable resources in `assets/audio/profiles/`:

| Profile | Character | Room size / damping / wet |
| --- | --- | --- |
| Steel | Short, relatively bright reflections | 0.30 / 0.30 / 0.070 |
| Concrete | Restrained, dampened reflections | 0.35 / 0.85 / 0.055 |
| Chamber | Deeper, longer reverberation | 0.74 / 0.62 / 0.130 |
| Shaft | Spacious decay and longer pre-delay | 0.88 / 0.42 / 0.160 |
| Open | Minimal reflections; fallback outside zones | 0.10 / 0.80 / 0.000 |

Zone boundaries use signed box distance, a configurable blend margin (1.5 m by default) and normalized profile weights. The resulting target is smoothed over `transition_seconds` (0.8 s). This uses **one fixed AudioEffectReverb**, interpolating its supported parameters, rather than assuming Godot has a generic effect-blending or parallel-send API. The direct component stays at 1.0; wetness is capped at 0.18. A single shared effect avoids one reverb per source and limits buildup during rapid firing. Small settled-value thresholds avoid repeatedly writing unchanged audio-server parameters.

To add a custom zone, place a Node3D below the manager, attach `scripts/audio/acoustic_zone.gd`, set its `dimensions`, transform, `blend_margin`, `weight_scale` and profile resource. Set `build_test_mine_zones=false` if replacing the default mine zones. Scripts can also call `add_zone()` or query `sample_acoustics(world_position)`. Rotation supports arbitrary tunnel orientations and full 6DoF flight.

### Bus routing and internal/external separation

The manager creates and removes its owned buses at runtime:

```text
Proximity sonar -------------------------------> Master
Ship impact / scrape / shield -> IndustrialFX -> Master
Local weapon discharge --------> ExternalWorld -> IndustrialFX -> Master
External 3D sources -> WorldSource00..11 -------> ExternalWorld
```

`IndustrialFX` retains its existing -6 dB limiter. `ExternalWorld` contains the single reverb, with unity direct gain. Each `WorldSource` bus has a low-pass filter and an occlusion gain. All three sounds on one enemy share its source bus; positional playback, attenuation, rates and original channel volumes remain on their existing AudioStreamPlayer3D nodes. Player firing gets room reflections without a self-occlusion ray. Sonar, collision, scraping and shield sounds remain clear and direct. Future cockpit/engine vibration sounds can use the internal branch. No new ship vibration sound or enemy hearing logic is introduced here.

The controller, enemy AI and existing industrial sound generator are unchanged. Enemy and destruction sounds are registered from scene-tree notifications, including encounter restart. Removing the manager restores previous routes, releases its buses and stops its ambient players. Headless runs retain zone/event logic and signals but skip automatic ambient/event playback to avoid unnecessary Dummy-audio work during accelerated physics tests. Keep one manager per active listener/level.

### Sources, occlusion and events

Six fixed emitter anchors use AudioStreamPlayer3D. The nearest three loops are targeted at once; old/new loops crossfade over 0.9 s, so up to six may briefly coexist while their combined gain remains bounded. Pitch varies subtly on restart. Distance attenuation is continuous, with no hard distance cutoff on the new emitters; `ambience_range` is an additional soft distance reference. Source priority and the loop budget can still fade out less relevant emitters. `max_db` caps near-field loudness so flying directly into an audio anchor cannot amplify a quiet hum excessively.

Occlusion checks static geometry (collision mask 1) between the listener and active source owners. The listener and source body are excluded. The round-robin budget is **three rays per 0.35 s**, at most about 8.6 queries/s with defaults; inactive sources receive no rays. Obstructed sources fade toward -10 dB with a 2,400 Hz low-pass over 0.22 s. Occlusion never hard-mutes a source. This is a listener-based approximation: it does not find paths around corners, simulate propagation, or drive AI. Owner grouping and pooled source buses bound processing to 12 filtered emitters; overflow retains spatial playback and room acoustics without an individual occlusion filter.

One event player chooses a nearby existing anchor or an additional pipe-event point in the horizontal corridor and an event recipe every 14–32 s, with pitch/level variation. Only one event can play at once. Events never create enemies, change objectives or apply damage. `environmental_event(kind, position)` is available for future integrations; no Silent Running, passive sonar or enemy hearing is implemented.

### Configure and extend

Edit `scenes/audio/environment_audio.tscn`:

| Parameters | Purpose / defaults |
| --- | --- |
| `enabled`, `transition_seconds`, `maximum_wet` | Smoothly enable atmosphere; 0.8 s / 0.18 wet ceiling |
| `occlusion_interval`, `rays_per_update`, `obstacle_mask` | 0.35 s / 3 rays / static layer 1 |
| `blocked_volume_db`, `blocked_cutoff_hz`, `occlusion_fade_seconds` | -10 dB / 2,400 Hz / 0.22 s |
| `source_slots`, `maximum_loops` | 12 filtered owner groups / 3 targeted loops |
| `ambience_range`, `ambience_volume_db` | 35 m soft distance reference / -31 dB |
| `event_volume_db`, `event_interval_min`, `event_interval_max` | -24 dB / 14–32 s |
| `random_seed` | 0 randomizes; nonzero enables reproducible scheduling |
| `additional_event_points` | Extra event positions in manager-local coordinates; one corridor pipe point by default |

For a new environmental sound, create a Node3D emitter with an AudioStreamPlayer3D child, assign a cached/licensed stream and suitable level/attenuation, then call `register_source(emitter, [player])` on the manager. The emitter position and lifetime remain owned by the caller. Freeing it releases its filter slot at the next update. To add a built-in ambient recipe, extend `ambient_sounds.gd`, prewarm it and add an anchor in `_build_ambience()`. Do not route internal warning sounds to the external branch.

### Validate 0.6

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script tests/environment_audio_smoke.gd
godot --headless --path . --script tests/industrial_audio_smoke.gd
# Native display/audio review, with no enemies:
godot --path . --script tests/environment_audio_runtime.gd
# Isolated weapon tails across five acoustic profiles:
godot --path . --script tests/environment_audio_runtime.gd -- --tails
# Stereo positioning, distance attenuation and a physical occlusion wall:
godot --path . --script tests/environment_audio_runtime.gd -- --occlusion
# Comparable active-combat measurements:
godot --path . --script tests/active_combat_benchmark.gd -- --no-atmosphere
godot --path . --script tests/active_combat_benchmark.gd
godot --path . --script tests/mine_traversal_runtime.gd
```

`environmental_audio=false` on the test level removes the entire module for A/B checks. Run only one graphical instance when profiling. The runtime fixtures use test-only positions and survival settings; production gameplay remains unchanged. [Measured audio output, performance and limitations](docs/performance/environment_audio_06_report.md).

## ProjectMine 0.7 — Signal Lost

Launch the existing main scene. Enter the mine, find the cyan maintenance console
on the left of the lower shaft chamber, and press **F** within 3.5 metres with a
clear line of sight. Read its power report, ascend the shaft, and activate the
auxiliary supply on the right of the upper transfer chamber. Follow the incline
back to Sector B's sealed door; powered access opens automatically on approach.
Investigate the security console at the rear of the reactor chamber to finish.
HUD objectives and local signs provide hints; there is no waypoint arrow or kill
requirement. Both drone encounters can be bypassed. Existing flight, headlights,
sonar, weapons and environmental acoustics retain their controls.

**F5** manually saves; **F9** loads `user://signal_lost_v1.json`. Saves include
position, full orientation, shield, energy, objective, consoles, auxiliary power,
door state and destroyed drone IDs. Loading clears active projectiles, stops
player motion and recreates surviving drones at their patrol starts with full
health. This is intentional: enemy health and transient AI state are not saved.
Missing, malformed and unsupported saves display a HUD message without applying
a partial load. Writes use a temporary file followed by replacement. **R** retains
the original ship/encounter reset behavior; mission progress remains intact.

Drone Inspector parameters: `move_speed` (patrol speed, default 1.8 m/s),
`acceleration` (5 m/s²), `aggression` (combat speed multiplier, 2.0),
`dodge_frequency` (damage-triggered chance, 0.35), `standoff_distance` (preferred
combat distance, 9 m), `minimum_distance` (retreat threshold, 5 m),
`avoidance_distance` (probe reach, 2.4 m), and local `patrol_offsets`.
Weapon damage, projectile speed and firing interval are unchanged. F4 shows the
extended PATROL → ALERT → APPROACH → ATTACK → SEARCH → RETURN_TO_PATROL state
machine; lethal damage enters DESTROYED. Patrol includes scan pauses and visual
hover. Combat adds randomized smooth lateral/vertical maneuvers and brief damage
repositioning. Six lightweight 3D probes contract movement around walls and other
drones; CharacterBody collision remains authoritative. This local steering uses breadcrumb waypoints to retrace travel back to patrol, and does
not solve arbitrary mazes: author patrol offsets inside connected open spaces.

New automated mission regression:
`godot --headless --path . --script res://tests/signal_lost_smoke.gd`.
Legacy fixtures disable mission props to retain their original geometry checks.
Manual gameplay checks still needed: encounter difficulty and bypass routes,
zigzag readability in wide/narrow spaces, audio mix, door/console presentation,
and rendered Compatibility performance on the target GPU.

Validation on Godot 4.7.2: 12 headless suites passed (the two new mission/AI
suites and existing combat, prototype, collision geometry, proximity/mouse,
drone model, lighting/VFX, environment audio, industrial audio/visuals and
parking audio smoke tests). Display-backed mouse capture and original mine
traversal also passed; traversal recorded no static impacts. The mixed sonar
audio capture passed all six distances. Its test cleanup now resolves its bus by
name after environmental buses are removed.

A six-second active-combat sample after warm-up, with mission props enabled,
measured **141.4 mean FPS**, **9.41 ms p95**, and roughly **109 draw calls** at
1280×720 on Intel UHD 620 / Mesa Compatibility. See
`docs/performance/signal_lost_07_combat.json`. This short fixture uses benchmark
health overrides and does not establish performance throughout the entire mine.
The mission smoke test verifies progression, sealed-door collision, remote
interaction rejection, completed and pre-power save restoration, orientation,
resources, destroyed enemies, missing saves and invalid versions. AI smoke tests
cover vertical patrol, near-wall steering, collision containment, moving fire,
non-straight attacks and damage dodges. Human playtesting is still required for
combat feel, full mission pacing, multi-drone congestion, audio balance and visual
quality at different resolutions.

Long-range encounter tuning: drones detect unobstructed targets within 60 m and a
140° cone, and fire while approaching from up to 48 m. Detection updates every
0.12 s; the initial warning lasts 0.4 s. Combat speed defaults to 3.6 m/s with
stronger lateral evasion during approach and attack, still reduced near walls.
A confirmed player hit briefly bypasses the view cone for 2.5 s, but never line of
sight or range checks. Damage, projectile speed and firing interval are unchanged.

Terminal and door presentation: consoles now have framed status screens,
protective rails, keypads, vents and warning plates. Screen text and amber/green
status bars reflect maintenance, auxiliary power and security-log progress,
including after loading. Sector B has two reinforced sliding leaves, a fixed
frame, hazard markings and status lamps. Opening takes 2.4 seconds with eased
motion and a local motor sound; collision shapes move with the visible leaves.
The access objective advances only once opening completes. A save made during
opening restores fully open to avoid closing a leaf around the saved ship.
`opening_duration` is configurable on the door script.

Visual inspection screenshots can be regenerated on a display with
`godot --path . --rendering-method gl_compatibility --script res://tests/mission_visual_preview.gd`;
outputs are `/tmp/projectmine_terminal.png`, `/tmp/projectmine_door_closed.png`
and `/tmp/projectmine_door_opening.png`. Mission regression also covers gradual
leaf movement, cleared passage, saving during motion and restored screen state.

## ProjectMine 0.8 — Camera shake and physical feedback

**F6** toggles visual shake; **[ / ]** decrease/increase global intensity by ten
percentage points, clamped to **0–100%**. Default is a restrained **55%**. Changes
appear briefly on the HUD and persist in `user://feedback_settings.cfg`,
independently of mission saves. Zero clears pending motion immediately, including
barrel recoil. These keys leave all flight/weapon/mission controls available.

`Ship/Camera3D` remains the unshaken aiming reference. Its dedicated
`VisualOffset/RenderCamera` only translates the rendered view; there is **no
angular shake**. Weapon effects follow the visual mount while both barrels have
separate mechanical recoil. Projectile spawn, orientation, inherited velocity,
ship physics and collision shape are unchanged. The reticle projects the actual
shot line (including inherited velocity) through the visual camera to compensate
for near-surface parallax. It never feeds back into flight or aiming.

Inspector parameters on `cockpit_feedback.gd`:

| Channel | Default intensity at 100% | Duration |
| --- | --- | --- |
| Weapon | 0.003 m | 0.080 s |
| Shield hit | 0.022 m at 25 damage | 0.240 s |
| Hull collision | 0.030 m at 25 m/s normal closing speed | 0.220 s |
| Sustained scraping | 0.0015 m, scaled by tangential speed | Contact only, short fade |

`intensity` scales the component, `damping` defaults to 32/s, and
`maximum_displacement` caps the combined offset at 0.035 m before the global
comfort multiplier. Durations, per-channel intensities, damage/speed references,
contact thresholds and collision cooldown are configurable. Barrels expose
`barrel_recoil` (0.045 m) and `recoil_duration` (0.085 s) separately. Exponential
return damping is independent of frame rate. Each transient channel replaces its
previous impulse, preventing accumulation under rapid fire or repeated hits.

Enemy hits use the projectile's incoming travel direction and actual applied
shield damage; the existing cyan flash now scales with damage and remains capped
at 12% opacity. Hull impacts read pre-resolution normal closing velocity from
actual slide contacts, with a 2.5 m/s threshold and a cooldown. Scraping requires
sustained wall contact and tangential motion; a short hull probe retains exactly
parallel contact, while separation, stopping, ship reset, load and disable clear
or fade the appropriate feedback. The system works independently of audio mute.

Run `godot --headless --path . --script res://tests/camera_feedback_smoke.gd` for
rapid/repeated impulses, damage direction/scaling, actual enemy projectile hits,
reticle projection, 6DoF aim invariants, normal-speed collision response, gentle
contact, parallel scraping, separation, damping and complete disable/reset.
The same script can run with a display and Compatibility renderer. Subjective
comfort and perceived mass still need human gameplay testing at the intended
resolution; the 55% default is intended as a conservative starting point.

0.8 validation: all 13 headless smoke suites passed, including the new camera
feedback fixture and existing flight, collision, combat, AI, mission/save,
lighting, sonar, audio, industrial visuals and drone-model checks. The feedback
fixture and mouse controls also passed with a real Compatibility display.
The regression run exposed a pre-existing lost drone damage-flash override;
local hit feedback now takes precedence over the alert optic without changing AI.
The combat fixture explicitly resets its patrol state after placement, since
long-range drones can already see the launch bay during setup.

The active-combat Compatibility fixture at 1280×720 on Intel UHD 620 measured
144.5 mean FPS and 9.25 ms p95 in a short sample with the mission enabled; see
`docs/performance/feedback_08_combat.json`. This is not a whole-mine guarantee.
Run `tests/feedback_preview.gd` with a display for cockpit/recoil/shield PNGs under
`/tmp/projectmine08-*.png`. Comfort, perceptual recoil timing and the feeling of
mass remain manual gameplay checks, particularly at low frame rates and high
user-selected intensities.


## ProjectMine 0.8.1 — Heavy industrial cannons

Player fire now layers a breech impact, a deep 62–97 Hz discharge with harmonics,
a short electrical chirp and a quiet metallic cabin ring. The original waveform
is generated once and cached. It lasts 260 ms, rejects sub-bass/DC, and peaks at
0.60 full scale rather than the previous 0.65; player gain and the existing
IndustrialFX limiter are unchanged. Two voices permit short overlapping tails.
Enemy firing PCM is byte-identical to 0.8, and environmental routing, occlusion,
reverb and other sound recipes remain unchanged.

Each actual shot alternates the visible left/right cannon. The same
`weapon_fired` event starts audio, the selected muzzle flash, mechanical recoil
and camera/cockpit impulse. There is still exactly one centrally aimed projectile
per shot, with the same 20 damage, 100 m/s speed, 0.14 s interval and energy cost.
Cannon selection is cosmetic; it does not move the projectile origin to a barrel.

Current tuning (supersedes the 0.8 weapon-only defaults above):

| Feedback | Default at 100% | Timing / limit |
| --- | --- | --- |
| Barrel stroke | 7.5 cm along local +Z | 75 ms main impulse, 200 ms return |
| Camera impulse | 1.2 cm target, no rotation | 75 ms impulse, 190 ms recovery; existing shared cap |
| Cockpit/gun-mount impulse | 2.4 cm target | 3 cm local cap, exponential smoothing |
| Cockpit rotation | Small damped pitch/yaw/roll vibration | 0.25° default cap; camera axis stays unchanged |
| Housing / brackets | 2.5 mm vibration / 1.5 mm reaction | Independent from the sliding barrel |

The existing 55% comfort setting yields approximately 4.1 cm peak barrel stroke
and a restrained camera impulse. F6 and [ / ] still control motion globally.
Barrels, fixed housings and mounting brackets are separate visual nodes. Each
cannon has its own shot age, while the cockpit impulse replaces the previous one
and smoothly follows a bounded target; sustained fire cannot add unlimited
translation or rotation. All animation is local to the ship and works when
pitched, rolled or inverted. Only the visual cockpit has rotational vibration;
the aiming and rendered-camera axes remain parallel.

New tests:

- `godot --headless --path . --script res://tests/heavy_cannon_smoke.gd` checks
  single shots, both cannons, 6DoF poses, event synchronization, full recovery,
  80-shot sustained feedback, limits, disable, balance and enemy PCM preservation.
- `godot --path . --rendering-method gl_compatibility --script res://tests/heavy_cannon_runtime.gd`
  captures 12 real-time shots with ambience through the final PulseAudio mix.
  The WAV is written to `/tmp/projectmine081-cannon-mix.wav`; the isolated cached
  cannon sample from the smoke test is `/tmp/projectmine081-cannon.wav`.

The mixed-audio run measured peak 0.284 and RMS 0.060, with no clipping.
Subjective sound weight, fatigue and recoil comfort still need human listening
and gameplay testing on the intended speakers/headphones.

All 14 headless smoke suites passed. The live cannon mix capture also passed.
A short sustained-combat Compatibility benchmark on Intel UHD 620 at 1280×720
measured **138.8 mean FPS** and **9.8 ms p95**; it uses benchmark-only health
overrides and is not a whole-mine guarantee. Results are recorded in
`docs/performance/heavy_cannon_081.json`. An isolated sound preview is included at
`docs/previews/heavy_cannon_081.wav`.


## ProjectMine 0.9 — Hybrid industrial cockpit

The supplied concept guides the composition: two cylindrical industrial cannons,
connected mechanical saddles and hydraulic arms, diagonal protective pillars,
orange inserts, hazard paint and a three-instrument lower dashboard. The
reference is not a fullscreen image overlay. Cannons, fins, vents, hex bolts,
armour, collars, pistons, cabling and load-bearing frame are authored 3D geometry.
The lower instruments are native Godot controls with live values.

**C** toggles the complete cockpit. In cockpit mode, shield and energy move to
the lower panel and the central display uses the existing six-axis proximity
sensor. Rings/markers indicate hull clearances, not enemies. Low shield, low
energy, discharge and brief damage flicker are driven by gameplay signals/values.
Speed, disable feedback and mission objectives remain readable above the panel.
The redundant corner sonar/resource readouts are hidden. C off restores the
classic HUD and objective placement. All controls ignore pointer events.

Architecture:

- `assets/models/cockpit/industrial_cockpit.glb`: seven rigid animated components,
  8,440 triangles, two shared materials, embedded 512px albedo/PBR atlases, orange
  emission, and named left/right muzzle attachments. No collision or studio lights.
- `tools/blender/generate_industrial_cockpit.py`: deterministic procedural Blender
  authoring/export script; editable source is
  `assets/models/cockpit/source/industrial_cockpit.blend`. Regenerate with
  `blender --background --python-exit-code 1 --python tools/blender/generate_industrial_cockpit.py`.
  Generated files are overwritten; preserve hand edits separately or in the script.
- `scripts/effects/player_weapon_vfx.gd`: binds imported barrel/housing/mount
  pivots and muzzle nodes to the existing alternating recoil and shared shot event.
  The structural frame follows the existing bounded cockpit vibration.
- `scripts/effects/cockpit_presentation.gd`: transparent live 3D foreground pass on
  visual layer 20. It shares the main World3D but excludes level geometry and has
  no audio listener. Main camera excludes layer 20, preventing duplicate drawing.
  One shadowless cockpit-only key and a 128px reflection sky light the shared PBR
  material. The pass follows the visual camera, so nearby walls never cut through
  the cockpit. `render_scale` (0.5–1.0, default 1.0) adjusts only this 3D pass;
  dashboard text remains native resolution. Hidden/headless passes do not render.
- `scripts/ui/cockpit_dashboard.gd`: actual shield/energy labels and segmented
  ProgressBars, six-axis sonar scope, warning lights and damage flicker. Layout is
  proportional and clamped for common laptop aspect ratios; no enemy radar exists.
- `scripts/ui/hud.gd`: switches layouts and keeps objectives above the cockpit.

Shot physics still starts at the unshaken aim camera, preserving point-blank wall
handling, central hit accuracy, velocity, damage and cadence. Only the visible
tracer bridges from the active GLB muzzle to the actual shot line over 65 ms.
The bridge is suppressed when geometry obstructs the muzzle/visual segment. This
avoids changing combat accuracy or shooting through a nearby wall. Muzzle flashes
are children of the recoiling GLB attachments. Flight, enemies, mission progression,
level collision geometry and environmental acoustics are unchanged.

Validation commands:

- `godot --headless --path . --script res://tests/cockpit_smoke.gd`
- `godot --path . --rendering-method gl_compatibility --script res://tests/cockpit_preview.gd`

The preview produces 1280×720 cockpit/classic HUD and 1280×800 low-shield/sonar
screenshots at `/tmp/projectmine09-*.png`. The new regression checks the C toggle,
repeat suppression, actual resource values, warning thresholds, sensor binding,
objective placement, geometry/material budget, render masks, full 3D muzzle poses,
unchanged projectile physics, cosmetic tracer convergence and damage feedback.

0.9 validation: all 15 headless smoke suites passed. Display-backed previews,
mouse capture, real cannon mix, six-distance mixed sonar audio and full mine
traversal passed. Traversal recorded zero static impacts; the new cockpit added
no physics geometry. A short uncapped 1280×720 active-combat sample on Intel UHD
620 measured **116.3 mean FPS / 12.0 ms p95**. The separate fullscreen traversal
fixture measured roughly **52–74 FPS** across its segments; this is not a guarantee
of 60 FPS at every native resolution. Lower `render_scale` if needed on larger
screens. Results are in `docs/performance/industrial_cockpit_09.json`; screenshots
are in `docs/previews/industrial_cockpit_09*.png`. Long sessions, subjective
recoil/visual comfort and performance over the whole mission still need manual
playtesting on the target laptop.

### Physical response to incoming projectile hits

Enemy hits now add a short, damage-scaled world-space shove to the actual ship
body along the incoming projectile direction. A normal 10-damage hit adds
1.8 m/s of impact velocity; exponential damping at 8/s yields roughly 20 cm of
free-space movement. Repeated hits cap only this extra component at 3 m/s, leaving
ordinary flight/boost speeds untouched. The normal CharacterBody sweep resolves
the shove against walls; there is no teleport or forced rotation. Ship reset and
load clear the residual impulse. Visual F6 shake settings remain independent.

Ship Inspector parameters: `physical_impacts`, `hit_impulse_speed`,
`full_impulse_damage`, `maximum_hit_velocity`, `hit_impulse_damping`.
`tests/physical_hit_smoke.gd` covers actual displacement in rotated poses,
settling, repeated-hit limits, enemy projectiles, adjacent walls and disable/reset.


## ProjectMine 1.0 — Deep Mine

The main scene is now `scenes/levels/deep_mine.tscn`. The original test mine
remains available for regression fixtures. Two connected loops join entrance /
maintenance, transport, utility corridors, excavation, auxiliary power and
Sector B security. From launch, take the forward corridor toward maintenance or
the right-hand excavation branch. Both reach transport. Two vertical shafts link
the lower network to the utility/power cross-corridor; a service cache forms an
optional guarded dead end. The existing inclined passage leads to the powered
Sector B door. Room signs, cyan trim, ore pillars and power markings provide
local hints; there is no permanent objective arrow.

Read the original maintenance terminal, follow the upper cross-corridor to the
auxiliary generator in the power gallery, then return to Sector B and investigate
security. No kill quota exists. Ten stable-ID drones provide single patrols,
guarding pairs, an optional service ambush and generator-gated security. Distant
AI sleeps outside 70 m; event guards stay inactive until power is restored.
Existing flight, collision, industrial cockpit, sonar and drone combat remain.
Additional sectors reuse industrial decoration/materials and distinct acoustic
profiles, with quiet ventilation and machinery at transport/power.

Main cannons start with **120 rounds**, hold **200**, and consume one per
projectile. Damage, speed, energy cost and 0.14 s firing interval are unchanged.
The dashboard footer and classic HUD show actual ammo. Empty fire attempts give
a throttled sound and HUD message. **Hold V** for an unlimited emergency emitter:
5 damage every 0.65 s, much weaker than the 20-damage main cannons. It has a quiet
separate sound and does not animate the main cannon barrels.

Drones have a configurable **70%** chance to leave **15–35** energy cells.
Green rotating packs collect within 1.8 m with clear sight; they never exceed
capacity or collect twice. Three guaranteed 30-round caches reward exploration.
Drop placement checks a 0.6-metre free sphere around the destroyed hull.
Larger cosmetic metal fragments and short sparks have no collision and expire
within 0.8 s. There are no debris rigid bodies or new explosion lights.

Inspector tuning: Ship `starting_ammo`, `max_ammo`, `ammo_per_shot`; drone
`ammo_drop_probability`, `ammo_drop_min`, `ammo_drop_max`. The existing **R**
restart helper restores starting ammo/ship and respawns encounters, retaining
mission/pickup progress. F5/F9 retain manual save/load controls. JSON version 2
uses the existing `user://signal_lost_v1.json` path and adds ammunition plus stable
pickup definitions/collected IDs and expanded destroyed-enemy IDs. Old version-1
saves load with starting ammo and fresh resource caches. Surviving enemies still
restart at their patrol spawns; transient AI/partial enemy health are not saved.

`tests/deep_mine_smoke.gd` verifies branching route/shaft hull clearance, sleeping
enemies, ammo depletion, emergency fire, collection/capacity, real destruction
drops, mission completion without clearing enemies, expanded persistence and v1
migration. Run it with `godot --headless --path . --script res://tests/deep_mine_smoke.gd`.
The regression suite continues to use the original mine for baseline geometry.
The combat benchmark accepts `--deep-mine` to exercise the expanded scene.
Manual exploration is still needed to assess pacing, resource abundance, ambush
fairness and corner pursuit throughout the network.

1.0 validation: **17 headless suites passed**, including the new deep-mine
regression. Route checks include actual hull-sized clearance through both loops,
shafts and the service branch, plus 448 enclosure rays from sector centres.
The expanded mission completes without eliminating all drones. A short 720p
Compatibility multi-enemy combat fixture on Intel UHD 620 measured **100.5 mean
FPS / 14.7 ms p95** with benchmark-only health overrides. This does not establish
native-resolution performance throughout the entire facility. Details:
`docs/performance/deep_mine_10.json`; excavation screenshot:
`docs/previews/deep_mine_10.png`.

Tunnel-opening polish: authored wall openings now reserve a decoration-free
volume, including side branches, shaft apertures and inclined portals. Cosmetic
pipes, panels, posts and labels are omitted when they overlap that volume.
Collision geometry and combat tuning are unchanged. Run
`tests/portal_decoration_smoke.gd` to verify batched decorations remain clear of
all authored openings in the expanded mine.


## ProjectMine 1.1 — Ammunition and homing missiles

**CANNON AMMO** is a finite resource, separate from the regenerating **ENERGY
RESERVE**. The cockpit now has a prominent dedicated ammunition/missile readout
above the instruments; classic HUD mode shows both counters too. Cannons start
at 120, capacity 200, one round per projectile. Ammo never regenerates. Green
packs replenish cannon ammo only; the previous ambiguous “energy cells” label
now says “CANNON AMMUNITION”. Low-ammo highlighting defaults to 20 rounds and is
configurable via Ship `low_ammo_threshold`. Existing shield/energy regeneration
and the original two-energy-unit primary firing cost are preserved. Holding V
still fires the weak 5-damage emergency emitter without consuming either ammo
resource; its cadence remains 0.65 s.

Aim near a drone with the crosshair and maintain unobstructed sight for 0.7 s.
The small target label shows acquisition progress and an orange confirmed lock;
a quiet beep confirms readiness. **Right mouse** fires a missile while the mouse
is captured. Initial range is 35 m and acquisition cone is 6°. Occlusion, leaving
the cone, range loss or destruction immediately cancels the lock. A launched
missile guides independently and can follow beyond the initial lock range.

Missiles start at **5**, capacity **12**, never regenerate, and consume one per
successful launch. Two orange fixed packs in the excavation and service cache
supply two missiles each. Pickups require clear sight, obey capacity and retain
stable collected IDs. Main cannon damage/cadence, flight and enemy AI are unchanged.

The visible twin-tube industrial launcher is attached to the cockpit weapon
mount. Actual missiles launch from its muzzle, accelerate from 8 to 30 m/s at
20 m/s², and turn at no more than 110°/s. They deal three primary-projectile hits
(default 60 damage), have a 1.2 s launch cooldown and a global cap of four active
missiles. Guidance has no perfect interception or instant turns: agile drones
can evade it. A swept 0.1 m sphere catches thin walls/obstacles and excludes the
player. Target loss allows 0.8 s of straight flight before safe removal; maximum
lifetime is 5 s. There is no area damage or self-damage. Impact reuses short-lived
mechanical sparks/debris and spatial sound; nearby camera feedback is restrained.
Exhaust is a short orange mesh, not an expensive particle system or dynamic light.

Architecture/configuration: `scripts/weapons/missile_system.gd` owns acquisition,
launcher, lock feedback and launch limits; `homing_missile.gd` owns bounded steering,
acceleration, swept collision and effects. These are Inspector-configurable on
`Ship/MissileSystem` and the missile script. Ship owns separate `ammo` and
`missiles` counters, starting supplies and capacities. Saved JSON version **3**
adds missile count; versions 1/2 migrate with five missiles (v1 also receives
starting cannon ammo). Existing save path and F5/F9 controls are retained. Loading
resets target lock and removes in-flight projectiles; it does not save transient
missile flight. The existing R restart helper restores starting supplies.

Run `tests/missile_smoke.gd` headlessly for consumption, live energy regeneration
without ammo regeneration, both pickup types/capacities, save migration, clear and
blocked locks, moving targets, bounded turns, swept walls, damage, self-collision
exclusion, full 6DoF launch attitudes, lost targets and active-count limits.
`tests/missile_preview.gd` produces display-backed lock/launch screenshots under
`/tmp/projectmine11-*.png`. The active-combat benchmark accepts `--missiles` with
`--deep-mine` to include real guided launches. Subjective lock readability, missile
feel and balance against agile opponents still require human gameplay testing.

1.1 validation: **19 headless suites passed**, including lock/occlusion, guided
impacts, thin walls, moving targets, 6DoF launch attitudes, no regeneration,
primary/missile pickups, v1/v2/v3 save migration, mission completion and the
existing flight/audio/geometry regressions. Display-backed lock/launch previews
also ran successfully. On Intel UHD 620 at 1280×720 Compatibility, the short
normal combined-combat fixture measured **100.1 mean FPS / 13.3 ms p95**. A separate
fixture-only cooldown bypass forced the production cap of **four simultaneous
missiles** and measured **87.3 mean FPS / 14.6 ms p95**. This is not a whole-mission
native-resolution guarantee. Details: `docs/performance/homing_missiles_11.json`;
preview: `docs/previews/homing_missiles_11.png`. Human playtesting remains necessary
for perceived lock feedback, missile evasion and longer-term resource balance.
