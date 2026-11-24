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
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	await frames(4)
	var drones := get_nodes_in_group("enemies")
	var drone = drones[0]
	drones[1].set_physics_process(false)
	var ship = level.get_node("Ship")
	ship.position = Vector3(0,0,5)
	# The player can see down the launch corridor well beyond the old 24 m range.
	drone._rng.seed = 711
	drone.position = Vector3(0,0,-44)
	drone.basis = Basis(Vector3.UP,PI)
	ship.position = Vector3(0,0,-4)
	drone._sense_time = 0
	await frames(2)
	check(drone.detect_player(),"Acquire visible player at 40 m")
	await frames(100)
	check(drone.shots_fired > 0,"Open fire beyond the old detection range")
	check(drone.position.z > -43 and Vector2(drone.position.x,drone.position.y).length() > 0.1,"Approach with evasion at long range")
	ship.position = Vector3(0,0,5)
	drone.change_state(drone.State.PATROL)
	drone.velocity = Vector3.ZERO
	drone.detection_range = 0
	drone.position = Vector3(0,12,-44)
	drone._home = drone.position
	drone._pause = 0
	drone.patrol_offsets = PackedVector3Array([Vector3(0,7,0)])
	await frames(100)
	check(drone.position.y > 14,"Vertical shaft patrol")
	drone.position = Vector3(0,0,-26)
	await frames(2)
	var wide: float = drone.probe(Vector3.RIGHT)
	drone.position.x = 3.0
	await frames(2)
	check(drone.probe(Vector3.RIGHT) < wide,"Narrow wall probe reduces clearance")
	var avoided: Vector3 = drone.avoid_obstacles(Vector3(3,0,0))
	check(avoided.x < 1,"Wall approach suppressed")
	# Drive into tunnel wall for multiple seconds; authoritative body must remain inside.
	drone._home = drone.position
	drone._pause = 0
	drone.patrol_offsets = PackedVector3Array([Vector3(8,0,0)])
	await frames(150)
	check(drone.position.x <= 3.31,"Drone cannot cross tunnel wall")
	drone.position = Vector3(0,0,-30)
	ship.position = Vector3(0,0,-18)
	drone.detection_range = 24
	drone.basis = Basis(Vector3.UP,PI)
	drone._sense_time = 0
	drone.change_state(drone.State.ALERT)
	await frames(220)
	check(drone.shots_fired > 0,"Moving attack fires")
	check(absf(drone.position.x) + absf(drone.position.y) > 0.05,"Attack deviates from straight pursuit")
	# A confirmed hit reveals the attacker briefly even outside the patrol cone.
	drone.position = Vector3(0,0,-26)
	drone.basis = Basis.IDENTITY
	ship.position = Vector3(0,0,-18)
	check(not drone.detect_player(),"Patrol cone still permits sneaking behind drones")
	drone.dodge_frequency = 1
	await frames(2) # Teleported fixtures must synchronize the physics broadphase.
	drone.take_damage(1,ship)
	check(drone.detect_player(),"Damage reveals attacker behind drone with clear sight")
	check(drone._dodge > 0,"Damage can trigger repositioning")
	check(drone.projectile_speed == 32 and drone.projectile_damage == 10 and drone.fire_interval == 1.25,"Weapon balance preserved")
	print("Dynamic AI: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
