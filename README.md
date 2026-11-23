# ProjectMine

A self-contained Godot 4 / GDScript first-person 6DoF flight prototype. No external assets or plugins are required.

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
| Up / Down arrows | Pitch up / down |
| Left / Right arrows | Yaw left / right |
| Q / E | Roll left / right |
| Shift | Boost while moving; consumes energy |
| Left mouse / Enter | Fire lasers; consumes energy |
| R | Reset position, orientation, shield and energy |

All movement and rotation follow the ship's current orientation. There is no gravity, automatic leveling or external ship model. Releasing movement smoothly brakes the ship. Energy regenerates whenever boost is inactive. After boost runs out, release Shift to rearm it; the HUD shows a reminder. Speed reports actual travel, including when blocked by a wall. Shield starts at 100%; damage is reserved for a later prototype.

## Test mine

Follow cyan lighting from the launch room through the horizontal corridor into the shaft chamber. Ascend through its ceiling into the upper room, then continue forward through the rising angled tunnel to the final chamber. The route is reversible. Numbered room signs help orientation. Walls block the ship and lasers; laser hits produce brief expanding flashes. There are no enemies, random generation or multiplayer.

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
