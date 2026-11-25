# ProjectMine 1.3 validation and play guide

Start the configured main scene (`godot --path .`, or F5 in the editor). Individual
F6 test scenes intentionally do not start the managed menu/pause/death flow.

## Playable sequence

1. Choose New Game, or Continue/Load Game to restore a valid save.
2. Explore maintenance, read the power report, activate auxiliary power, return to
   Sector B and activate its security terminal as before.
3. The final terminal starts the four-minute Escape Protocol. Fly back down the
   incline; follow AUX east through the upper gallery and SERVICE, then the newly
   unlocked E-04 interlock. Ascend the new shaft and cross the windowed bridge.
4. Pass through the evacuation gate to complete the mission. A short departure
   shot and statistics follow; Return to Main Menu ends the session.

The countdown is deliberately configurable and forgiving. Facility security shuts
its weapons/navigation down for the escape; its physical bodies remain visible
sonar obstacles. They can be bypassed within the existing wide rooms. Emergency
lighting and fixed strips/signs guide the route rather than an on-screen arrow.

## Saves and recovery

- Three manual slots are available from Escape → Save Game / Load Game.
- F5/F9 quick-save/load slot 1. Browser controls add J/K and M as an alternate
  pause key; Z avoids the browser Ctrl+W shortcut while descending.
- Automatic checkpoint: arrival, maintenance, generator and pre-security console.
  A successful evacuation stores a completed checkpoint for Continue.
- Retry Checkpoint reloads the current run's recovery point. A pre-security retry
  gives the full configured escape time when the terminal is activated again.
- Continue is disabled when no living, valid save is available. Invalid data never
  replaces the loaded world. Manual slots remain independent when New Game starts.
- Legacy v1–v3 files remain loadable. A legacy completed Signal Lost save begins
  the new evacuation with a full timer instead of stranding the player at the old
  ending. Browser saves remain isolated by protocol/host/port/profile.

## Automated evidence

Git checkpoint before implementation: `6aa0f33`, branch
`codex/escape-protocol-1.3`. The player flight and enemy AI/weapon scripts are
unchanged from that checkpoint. The only old level aperture changed is the
service-cache exit, with an additional enclosed shaft/transport/gate extension.

The full **26 headless smoke suites** passed. New integration suites also cover:

- New Game resources/mission state; unavailable/available Continue; three slots;
  corrupt slots; checkpoint ownership across runs; repeated scene changes.
- Active AI, projectiles, mission time and door movement frozen during pause;
  Options without resuming; no Resume after death; a living checkpoint retry.
- Departure/completion UI, unchanged actual player pose during the cinematic,
  returning to Main Menu and clearing the paused state.
- Security terminal activation, 240-second countdown, powered interlocks,
  player-hull clearance including drone obstacles along a safe corridor lane,
  paused/restored time, progressive bounded debris, previous-save rollback,
  generator-light restoration, legacy final-save migration, success and timeout.

`tests/escape_route_runtime.gd` drives **the unchanged flight controller** using
forward input, its original acceleration/inertia/braking and rolled/vertical
orientations. It flies from security to the exit through actual physics, then
checks completion. It uses an isolated save directory and fixture-only mission
setup at the terminal, not a human full-campaign completion time.

Performance reports on Intel UHD 620 / Compatibility at 1280×720:

- `docs/performance/escape_protocol_13.json`: rendered evacuation traversal, about
  88.6 mean FPS / 18.0 ms p95; maximum six escape debris bodies and one simultaneous
  explosion during the recorded route.
- `docs/performance/mixed_combat_13.json`: about 91 mean FPS / 17.6 ms p95 in the
  existing short combat/missile fixture. Health overrides are fixture-only.

These are short local runs, not minimum-FPS guarantees. Automated X11 runs may
report NO GRAB when launched unfocused; mouse capture needs checking in a normal
focused play session. Screenshots are in `docs/previews/*_13.png`.

## Manual checks still required

The exported browser build passed New Game, pause, manual save/load and Continue
availability checks. A slot and checkpoint survived a full page reload on the
same origin. Proof: `docs/previews/save_slots_web_13.jpg`. The embedded Chromium
reported its existing pointer-lock UnknownError; no Godot script errors appeared.
Focused ordinary Linux/Windows browsers still need the manual checks below.

- Full exploration → power → security → escape without fixture setup.
- Human 6DoF turns/boost/braking in the shaft and bridge; sonar readability;
  maneuvering around dormant robots and fixed side housings.
- Alarm versus cannon/environment mix, visual comfort during nearby failures,
  and readability of signs/countdown at laptop resolutions and other aspect ratios.
- Repeated death, Retry, older manual loads and saves near timeout; check that a
  safe recovery point remains available rather than replaying an expired snapshot.
- Browser mouse capture/fullscreen/Escape interception, audio latency and save
  persistence on both Linux and Windows. The existing HTTPS certificate is
  unchanged. Use New Game/Continue, then Enter Cockpit after browser loading.

No completed human run, Windows performance or subjective audio approval is
claimed by these automated tests.

## Refined departure shot

The ending now uses `scripts/flow/cinematic_models.gd` to build a deterministic,
cratered asteroid with a real opening, an octagonal armored tunnel sleeve and
reinforced illuminated portal. The departing mining skiff has chamfered armor,
a glazed cabin, twin cooling-ring cannons, hydraulic braces, vented engine pods,
hazard markings and animated orange exhaust. Rock color/grain uses a small
256-pixel procedural texture and vertex colors; no external asset download is
required. These objects have no gameplay collision bodies.

`escape_cinematic.gd` gives this isolated stage its own camera environment and
warm/cool lighting. It retains the three-second departure, two existing explosion
cues and GameFlow's completion callback; the real player never moves during it.
The escape tunnel in the playable level is unchanged. One bounded orthogonal
sun shadow is used only in this shot, keeping it suitable for Compatibility and
UHD 620; the fill and rim lights do not cast shadows.

Validate construction with:

```sh
godot --headless --path . --script res://tests/cinematic_preview.gd
godot --path . --rendering-method gl_compatibility --script res://tests/cinematic_preview.gd
```

The rendered fixture saves three frames to `docs/previews/cinematic_refined_*.png`
and a short isolated-shot report to `docs/performance/cinematic_refined.json`.
The integration checks remain `game_flow_smoke.gd` and `escape_protocol_smoke.gd`;
the fixture also checks that translated visual ship assemblies remain attached
and no collision body is introduced.

The refined shot passed headless construction, GameFlow and Escape Protocol
integration tests, and another actual-flight evacuation traversal with zero
failures. Its isolated 1280×720 Compatibility capture on UHD 620 measured about
130 mean FPS / 9.7 ms p95 (short sample, not a gameplay or Web performance
guarantee). The Web pack was rebuilt and HTTPS delivery verified; subjective
ending appearance and browser frame pacing still need a normal play session.
