extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	var mission = level.get_node("Mission")
	var ship = level.get_node("Ship")
	for drone in get_nodes_in_group("enemies"): drone.detection_range = 0
	mission.interact("generator")
	check(not mission.generator_active,"Remote interaction rejected")
	var query := PhysicsRayQueryParameters3D.create(Vector3(0,44,-69),Vector3(0,44,-75),1)
	check(mission.get_world_3d().direct_space_state.intersect_ray(query).get("collider") != null and mission.door.is_ancestor_of(mission.get_world_3d().direct_space_state.intersect_ray(query).get("collider")),"Closed door blocks passage")
	ship.position = Vector3(0,0,-20)
	await frames(2)
	check(mission.objective == 1,"Entry objective")
	ship.position = Vector3(-5,0,-42)
	await frames(2)
	mission.interact("maintenance")
	check(mission.terminal_active and mission.objective == 3,"Power report")
	check(not mission.door_open,"Unpowered door closed")
	check(mission.save_game("user://signal_lost_early.json"),"Save before power")
	ship.position = Vector3(5,34,-42)
	await frames(2)
	mission.interact("generator")
	check(mission.generator_active and mission.objective == 4,"Generator")
	ship.position = Vector3(0,44,-68)
	await frames(3)
	check(mission.door.opening and not mission.door_open,"Powered door begins animated opening")
	var left_x: float = mission.door.leaves[0].position.x
	await frames(40)
	check(mission.door.leaves[0].position.x < left_x and not mission.door_open,"Door leaves move gradually")
	check(mission.save_game("user://signal_lost_moving.json"),"Save during door motion")
	await frames(120)
	check(mission.door_open and mission.objective == 5,"Powered door finishes opening")
	check(mission.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Open door clears passage")
	check(mission.load_game("user://signal_lost_moving.json"),"Load during-motion snapshot")
	await frames(2)
	check(mission.door_open and not mission.door.opening and mission.door.progress == 1.0,"Moving door restores safely open")
	check(mission.controls.generator.readout.text.contains("OUTPUT STABLE"),"Terminal displays restored supply state")
	ship.position = Vector3(0,44,-83)
	await frames(2)
	mission.interact("security")
	check(mission.objective == 6,"Mission complete")
	ship.shield = 67
	ship.energy = 42
	ship.basis = Basis.from_euler(Vector3(0.2,0.4,0.6))
	var saved_basis: Basis = ship.basis
	var drone = get_nodes_in_group("enemies")[0]
	drone.take_damage(999)
	check(mission.save_game("user://signal_lost_test.json"),"Save succeeds")
	ship.reset_ship()
	mission.objective = 0
	check(mission.load_game("user://signal_lost_test.json"),"Load succeeds")
	await frames(2)
	check(ship.position.distance_to(Vector3(0,44,-83)) < 0.01 and ship.basis.is_equal_approx(saved_basis),"Transform restored")
	check(ship.shield == 67 and ship.energy >= 42 and mission.objective == 6,"Resources and objective restored")
	check(mission.generator_active and mission.door_open and get_nodes_in_group("enemies").size() == 1,"Persistent world restored")
	var file := FileAccess.open("user://signal_lost_bad.json",FileAccess.WRITE)
	file.store_string('{"version":999}')
	file.close()
	check(not mission.load_game("user://signal_lost_bad.json") and mission.objective == 6,"Invalid load leaves world intact")
	check(not mission.load_game("user://missing_signal_lost.json"),"Missing save handled")
	check(mission.load_game("user://signal_lost_early.json"),"Load pre-power checkpoint")
	await frames(3)
	check(mission.objective == 3 and not mission.generator_active and not mission.door_open and get_nodes_in_group("enemies").size() == 2,"Earlier save closes door and restores destroyed enemy")
	for path in ["user://signal_lost_test.json","user://signal_lost_bad.json","user://signal_lost_early.json","user://signal_lost_moving.json"]: DirAccess.remove_absolute(path)
	print("Signal Lost: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
