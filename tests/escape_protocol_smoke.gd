extends SceneTree
const Slots=preload("res://scripts/flow/save_slots.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1;push_error(text)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var level=load("res://scenes/levels/deep_mine.tscn").instantiate()
	root.add_child(level);current_scene=level
	level.set_physics_process(false)
	var ship=level.get_node("Ship");ship.set_physics_process(false)
	var m=level.get_node("Mission");var escape=level.get_node("EscapeProtocol")
	m.terminal_active=true;m.generator_active=true;m.door_open=true;m.objective=5;m.door.restore(true);m.apply_power()
	ship.position=Vector3(0,44,-83)
	await frames(3)
	check(m.save_game("user://test13_pre_escape.json"),"Pre-escape save")
	m.interact("security")
	check(m.objective==6 and escape.phase==escape.Phase.ACTIVE and escape.remaining>239,"Final terminal starts four-minute evacuation")
	check(escape.transport.emergency_door.powered and escape.transport.emergency_door.opening,"Emergency route unlocks")
	await frames(160)
	check(escape.transport.emergency_door.progress==1 and escape.transport.gate.progress==1,"Both evacuation interlocks clear")
	var safe_route=[Vector3(0,44,-83),Vector3(0,44,-72),Vector3(0,34,-52),Vector3(0,33,-42),Vector3(56,33,-42),Vector3(88,33,-42),Vector3(118,34,-44),Vector3(118,70,-44),Vector3(118,70,-106),Vector3(118,70,-128)]
	var shape:=SphereShape3D.new();shape.radius=.55
	for i in range(safe_route.size()-1):
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=5;query.exclude=[ship.get_rid()]
		query.transform.origin=safe_route[i];query.motion=safe_route[i+1]-safe_route[i]
		var motion: PackedFloat32Array=ship.get_world_3d().direct_space_state.cast_motion(query)
		check(motion[0]>.999,"Player hull clears escape segment %d"%i)
	var remaining: float=escape.remaining
	paused=true
	await create_timer(.2,true).timeout
	check(escape.remaining==remaining,"Pause freezes evacuation countdown")
	paused=false
	for point in escape.ROUTE.slice(0,3):
		ship.position=point
		await frames(3)
	check(escape.stage==3,"Connected route progresses in order")
	escape.remaining=190
	await frames(170)
	check(escape.zones[0].triggered,"Structural failures advance behind player")
	for body in get_nodes_in_group("escape_debris"): check(body.collision_layer==0 and body.collision_mask==1,"Collapse debris cannot block player or damage combat balance")
	check(m.save_game("user://test13_escape.json"),"Active countdown saves")
	var saved=Slots.read("user://test13_escape.json")
	check(saved.version==4 and saved.escape.stage==3,"Version 4 stores route progress")
	escape.remaining=1;ship.position=Vector3.ZERO
	check(m.load_game("user://test13_escape.json"),"Escape save loads")
	check(escape.stage==3 and absf(escape.remaining-float(saved.escape.remaining))<.01,"Countdown and progression restore exactly")
	check(m.load_game("user://test13_pre_escape.json"),"Earlier save resets escape")
	check(m.power_light.light_color.is_equal_approx(Color(.3,1,.6)) and m.power_light.light_energy==2,"Earlier powered save restores generator lighting, not emergency tint")
	check(escape.phase==0 and not escape.transport.emergency_door.powered and not escape.zones[0].triggered,"Earlier state restores closed route and undamaged zones")
	# Legacy completed Signal Lost saves become a fresh evacuation, never a dead end.
	var legacy=Slots.read("user://test13_pre_escape.json")
	legacy.version=3;legacy.erase("escape");legacy.erase("elapsed")
	legacy.objective=6;legacy.security=true
	var file:=FileAccess.open("user://test13_legacy_escape.json",FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	check(m.load_game("user://test13_legacy_escape.json") and escape.phase==1 and escape.remaining==escape.evacuation_duration,"Legacy completion migrates to full escape countdown")
	for point in escape.ROUTE:
		ship.position=point
		await frames(3)
	ship.position=Vector3(118,70,-126)
	await frames(3)
	check(escape.phase==2 and m.objective==7 and not escape.alarm.playing,"Gate crossing completes mission and stops alarm")
	remaining=escape.remaining
	await frames(10)
	check(escape.remaining==remaining,"Completion stops countdown")
	m.load_game("user://test13_escape.json")
	escape.remaining=.01
	await frames(3)
	check(escape.phase==3 and ship.shield==0,"Timeout fails mission, never allows late completion")
	for path in ["user://test13_pre_escape.json","user://test13_escape.json","user://test13_legacy_escape.json"]: DirAccess.remove_absolute(path)
	level.queue_free();await create_timer(.3).timeout
	print("Escape protocol: ","PASS" if failures==0 else str(failures)+" failures")
	quit(0 if failures==0 else 1)
