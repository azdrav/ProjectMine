extends SceneTree
## Run with godot --headless --path . --script tests/prototype_smoke.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame

func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	var ship = level.get_node("Ship")
	var shape := SphereShape3D.new()
	shape.radius = 0.6 # Slightly larger than the player.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var route: Array[Vector3] = [Vector3(0, 0, 5), Vector3(0, 0, -44), Vector3(0, 34, -44), Vector3(0, 34, -52), Vector3(0, 44, -72), Vector3(0, 44, -80)]
	for index in range(route.size() - 1):
		var start := route[index]
		var end := route[index + 1]
		var samples := ceili(start.distance_to(end) / 0.2)
		for sample in range(samples + 1):
			query.transform = Transform3D(Basis.IDENTITY, start.lerp(end, float(sample) / samples))
			check(level.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Obstructed route at %s" % query.transform.origin)
	Input.action_press("move_forward")
	await frames(45)
	check(ship.velocity.z < -15.0, "Forward acceleration")
	Input.action_release("move_forward")
	await frames(55)
	check(ship.velocity.length() < 0.01, "Braking to rest")
	ship.reset_ship()
	ship.basis = Basis(Vector3.UP, PI / 2)
	Input.action_press("move_forward")
	await frames(30)
	check(ship.velocity.x < -10 and absf(ship.velocity.z) < 0.1, "Movement follows ship axes")
	Input.action_press("boost")
	await frames(30)
	check(ship.velocity.length() > ship.cruise_speed, "Boost increases speed")
	check(ship.energy < 100, "Boost consumes energy")
	ship.energy = 0.1
	await frames(3)
	check(ship.boost_exhausted and not ship.boosting, "Depleted boost locks until release")
	await frames(12)
	check(not ship.boosting and ship.energy > 1.0, "Boost stays off while energy recovers")
	Input.action_release("boost")
	await frames(2)
	Input.action_press("boost")
	await frames(2)
	check(ship.boosting, "Releasing and pressing Shift rearms boost")
	Input.action_release("boost")
	Input.action_release("move_forward")
	ship.reset_ship()
	Input.action_press("roll_left")
	Input.action_press("pitch_up")
	await frames(30)
	Input.action_release("roll_left")
	Input.action_release("pitch_up")
	check(not ship.basis.is_equal_approx(Basis.IDENTITY), "Pitch and roll change orientation")
	check(absf(ship.basis.determinant() - 1.0) < 0.001, "Rotation remains orthonormal")
	ship.reset_ship()
	ship.fire()
	await frames(4)
	check(level.find_children("Laser*", "Node3D", true, false).size() == 1, "Laser spawns")
	await frames(100)
	check(level.find_children("Laser*", "Node3D", true, false).is_empty(), "Laser collides and cleans up")
	ship.reset_ship()
	ship.position = Vector3(0, 0, -48)
	Input.action_press("move_forward")
	await frames(45)
	check(ship.get_real_velocity().length() < 0.05, "Actual speed is zero against wall")
	check("SPEED   000.0" in level.get_node("HUD/Status").text, "HUD reports actual blocked speed")
	Input.action_release("move_forward")
	ship.fire()
	await frames(3)
	check(level.find_children("Laser*", "Node3D", true, false).is_empty(), "Point-blank laser cannot start beyond wall")
	check(not level.find_children("ImpactFlash*", "MeshInstance3D", true, false).is_empty(), "Point-blank hit creates visible impact")
	await frames(30)
	check(level.find_children("ImpactFlash*", "MeshInstance3D", true, false).is_empty(), "Impact effect cleans up")
	ship.reset_ship()
	check(ship.position.is_equal_approx(Vector3(0, 0, 5)), "Reset restores launch position")
	print("Prototype smoke: %s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)
