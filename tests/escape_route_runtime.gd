extends SceneTree
## Real collision-body traversal, rendered escape and completion UI; scripted pilot only.
const Slots=preload("res://scripts/flow/save_slots.gd")
var failures:=0
var times: Array[float]=[]
var sampling:=false
var peak_debris:=0
var peak_explosions:=0
var draw_sum:=0.0
func _initialize() -> void: call_deferred("run")
func _process(delta: float) -> bool:
	if sampling:
		times.append(delta*1000)
		peak_debris=maxi(peak_debris,get_nodes_in_group("escape_debris").size())
		peak_explosions=maxi(peak_explosions,get_nodes_in_group("industrial_explosions").size())
		draw_sum+=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return false
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1;push_error(text)
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1);return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	Slots.directory="user://test13_runtime";Slots.legacy_path="user://test13_runtime_legacy.json"
	var flow=root.get_node("GameFlow")
	await flow.to_main();await create_timer(.5).timeout
	await capture("res://docs/previews/main_menu_13.png")
	root.grab_focus()
	await flow.new_game()
	var level=current_scene;level.set_physics_process(false)
	var ship=level.get_node("Ship");ship.set_physics_process(false)
	for drone in get_nodes_in_group("enemies"): drone.set_physics_process(false)
	var mission=level.get_node("Mission");var escape=level.get_node("EscapeProtocol")
	mission.objective=5;mission.terminal_active=true;mission.generator_active=true;mission.door_open=true
	mission.door.restore(true);mission.apply_power()
	ship.position=Vector3(0,44,-83)
	await physics_frame;await physics_frame
	mission.interact("security")
	await create_timer(.5).timeout
	flow.pause_game()
	await capture("res://docs/previews/pause_menu_13.png")
	root.grab_focus()
	flow.resume_game()
	var route=[Vector3(0,44,-72),Vector3(0,34,-52),Vector3(0,33,-42),Vector3(56,33,-42),Vector3(88,33,-42),Vector3(118,34,-44),Vector3(118,70,-44),Vector3(118,70,-74),Vector3(118,70,-106),Vector3(118,70,-128)]
	ship.set_physics_process(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	sampling=true
	for index in range(route.size()):
		var target: Vector3=route[index]
		var direction: Vector3=(target-ship.global_position).normalized()
		var up:=Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP
		ship.basis=Basis.looking_at(direction,up)*Basis(Vector3.FORWARD,.25 if index%2 else -.25)
		Input.action_press("move_forward")
		var steps:=0
		while escape.phase==1 and steps<600:
			await physics_frame
			var distance: float=(target-ship.global_position).dot(direction)
			var braking: float=pow(maxf(0,ship.velocity.dot(direction)),2)/(2*ship.deceleration)
			if distance<braking+.15: Input.action_release("move_forward")
			steps+=1
			if not Input.is_action_pressed("move_forward") and ship.velocity.length()<.02: break
		Input.action_release("move_forward")
		print("ESCAPE LEG ",target," at ",ship.global_position," steps ",steps)
		check(steps<600 and (escape.phase==2 or ship.global_position.distance_to(target)<1),"Flight controls traverse segment to "+str(target))
		if steps>=600: break
		if target==Vector3(118,70,-74): await capture("res://docs/previews/escape_bridge_13.png")
	sampling=false
	check(escape.phase==2 and mission.objective==7 and flow.screen==flow.Screen.COMPLETE,"Live flight reaches evacuation gate")
	await create_timer(1.2,true).timeout
	await capture("res://docs/previews/escape_departure_13.png")
	await create_timer(2.2,true).timeout
	await capture("res://docs/previews/mission_complete_13.png")
	var total:=0.0
	for t in times: total+=t
	times.sort()
	var report={"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"mean_fps":1000*times.size()/maxf(1,total),"p95_ms":times[int(times.size()*.95)] if not times.is_empty() else 0,"draw_calls":draw_sum/maxi(1,times.size()),"peak_escape_bodies":peak_debris,"peak_explosions":peak_explosions,"failures":failures,"fixture":"Autopilot uses unchanged forward input, inertia, braking and collision body, with rolled orientations. AI suspended for escape; manual mouse/combat testing still required."}
	var file:=FileAccess.open("res://docs/performance/escape_protocol_13.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ESCAPE RUNTIME ",JSON.stringify(report))
	await flow.to_main()
	for path in [Slots.manual(1),Slots.manual(2),Slots.manual(3),Slots.checkpoint()]: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(Slots.directory)
	quit(0 if failures==0 else 1)
