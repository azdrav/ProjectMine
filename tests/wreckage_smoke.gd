extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	await frames(3)
	for drone in get_nodes_in_group("enemies"): drone.set_physics_process(false)
	var drone = get_nodes_in_group("enemies")[0]
	drone.ammo_drop_probability = 1
	drone.take_damage(999,level.get_node("Ship"))
	check(drone.state == drone.State.DESTROYED and not drone.is_physics_processing() and drone.collision_layer == 0,"Immediate AI and collision shutdown")
	check(drone.visual.scale == Vector3.ONE,"Intact drone does not shrink")
	await frames(15)
	check(not is_instance_valid(drone),"Intact visual removed after mechanical break")
	var wreck = get_nodes_in_group("drone_wreckage")[0]
	check(wreck.bodies.size() == 5,"Five recognizable model components")
	for body in wreck.bodies:
		check(body.collision_layer == 0 and body.collision_mask in [0,1] and body.gravity_scale == 0,"Wall-only, non-blocking zero-g debris")
	check(level.pickups.has("drop_lower"),"Salvage drop retained")
	var attacker = get_nodes_in_group("enemies")[0]
	attacker.position = Vector3(3,0,-26)
	attacker.change_state(attacker.State.ATTACK)
	attacker.take_damage(999)
	await frames(15)
	var near_wall = get_nodes_in_group("drone_wreckage")[-1]
	await frames(90)
	for body in near_wall.bodies: check(body.global_position.x < 4.2,"Debris stays inside narrow corridor wall")
	for enemy in get_nodes_in_group("enemies"):
		enemy.take_damage(999)
	await frames(15)
	var active := 0
	for group in get_nodes_in_group("drone_wreckage"):
		if not group.fading: active += 1
	check(active <= 4,"Burst destruction respects active group cap")
	wreck.retire()
	await frames(110)
	check(not is_instance_valid(wreck),"Old wreckage fades out")
	level.queue_free()
	await create_timer(0.4).timeout
	print("Wreckage: ","PASS" if failures == 0 else str(failures)+" failures")
	quit(0 if failures == 0 else 1)
