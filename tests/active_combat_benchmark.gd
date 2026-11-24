extends SceneTree
## Sustained live AI + both weapon factions. Health overrides are test-fixture only.
var _ship: CharacterBody3D
var _drones: Array[Node] = []
var _shot_clock: float = 0.0
var _elapsed: float = 0.0
var _shots: int = 0
var _peak_projectiles: int = 0
var _peak_effects: int = 0
var _peak_missiles: int = 0
var _missile_stress_done := false
func _initialize() -> void: call_deferred("run")
func _process(delta: float) -> bool:
	if not is_instance_valid(_ship): return false
	_elapsed += delta
	_shot_clock -= delta
	var target: Node3D = _drones[int(_elapsed/1.2)%2] as Node3D
	_ship.basis = Basis.looking_at(target.global_position-_ship.global_position,Vector3.UP)
	if _shot_clock <= 0.0:
		_shot_clock += _ship.laser_interval
		_ship.fire()
		_shots += 1
	var controller = _ship.get_node("MissileSystem")
	if "--missile-stress" in OS.get_cmdline_user_args() and not _missile_stress_done:
		if _elapsed > 3.5 and controller.locked:
			# Fixture-only cooldown bypass to exercise the production four-missile cap.
			for i in range(4):
				controller.wait = 0
				controller.launch()
			_missile_stress_done = true
	elif "--missiles" in OS.get_cmdline_user_args(): controller.launch()
	_peak_missiles = maxi(_peak_missiles,get_nodes_in_group("guided_missiles").size())
	_peak_projectiles = maxi(_peak_projectiles,get_nodes_in_group("combat_projectiles").size())
	_peak_effects = maxi(_peak_effects,get_nodes_in_group("combat_vfx").size())
	return false
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real display/GPU is required.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	if "--windowed-720" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		root.size=Vector2i(1280,720)
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var deep := "--deep-mine" in OS.get_cmdline_user_args()
	var level = load("res://scenes/levels/deep_mine.tscn" if deep else "res://scenes/levels/test_mine.tscn").instantiate()
	if "--reference" in OS.get_cmdline_user_args(): level.extended_industrial=false
	if "--no-atmosphere" in OS.get_cmdline_user_args(): level.environmental_audio=false
	level.signal_lost = "--mission" in OS.get_cmdline_user_args()
	root.add_child(level)
	current_scene = level
	_ship = level.get_node("Ship")
	_ship.set_physics_process(false)
	_ship.position = Vector3(56 if deep else 0,0,-30)
	_ship.shield = 10000
	_ship.get_node("Proximity").enabled = false
	_drones.assign(get_nodes_in_group("enemies"))
	for index in range(2):
		var drone = _drones[index]
		drone.position = Vector3((-2 if index == 0 else 2)+(56 if deep else 0),1,-44)
		drone.basis = Basis(Vector3.UP,PI)
		drone.health = 10000
		drone._sense_time = 0.05
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(3.0).timeout
	var times: Array[float] = []
	var draws: float = 0.0
	var finish := Time.get_ticks_usec()+6000000
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_usec() < finish:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous=now
		draws+=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var sum: float = 0.0
	for time in times: sum+=time
	times.sort()
	var result := {"resolution":str(root.get_texture().get_size()),"gpu":RenderingServer.get_video_adapter_name(),"mean_fps":1000.0*times.size()/sum,"mean_ms":sum/times.size(),"p95_ms":times[int(times.size()*.95)],"draw_calls":draws/times.size(),"player_shots":_shots,"enemy_shots":[_drones[0].shots_fired,_drones[1].shots_fired],"peak_projectiles":_peak_projectiles,"peak_effects":_peak_effects,"peak_missiles":_peak_missiles,"missiles_remaining":_ship.missiles,"shield_damage":10000-_ship.shield,"enemy_damage":[10000-_drones[0].health,10000-_drones[1].health],"health_overrides":"benchmark only; production balance unchanged"}
	var output := "/tmp/projectmine-combat-performance.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("ACTIVE COMBAT ",JSON.stringify(result))
	_ship = null
	level.queue_free()
	await create_timer(.15).timeout
	quit()
