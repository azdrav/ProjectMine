extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	level.environmental_audio = false
	root.add_child(level)
	current_scene = level
	await frames(3)
	var ship = level.get_node("Ship")
	ship.get_node("Proximity").enabled = false
	for euler in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		ship.reset_ship()
		ship.position = Vector3(100,0,0)
		ship.basis = Basis.from_euler(euler)
		var orientation: Basis = ship.basis
		ship.take_damage(10,null,Vector3.RIGHT)
		check(ship.velocity.x > 1.7 and ship.shield == 90,"Hit supplies real directional velocity with unchanged damage")
		await frames(35)
		check(ship.position.x > 100.10 and ship.position.x < 100.35,"Whole collision body moves a short controlled distance")
		check(ship.basis.is_equal_approx(orientation),"Physical hit does not rotate aiming or controls")
		await frames(40)
		check(ship.velocity.length() < 0.001,"Physical impact settles completely")
	ship.reset_ship()
	ship.position = Vector3(100,0,0)
	for i in range(20): ship.take_damage(1,null,Vector3.LEFT)
	check(ship._hit_velocity.length() <= ship.maximum_hit_velocity and ship.velocity.length() <= ship.maximum_hit_velocity,"Repeated hits cannot accumulate uncontrolled speed")
	ship.reset_ship()
	check(ship._hit_velocity == Vector3.ZERO and ship.velocity == Vector3.ZERO,"Reset/load removes residual impact")
	# Real enemy projectile path supplies the shove even when visual shake is disabled.
	root.get_node("FeedbackSettings").intensity = 0
	ship.position = Vector3(100,0,0)
	var laser = load("res://scenes/weapons/laser.tscn").instantiate()
	laser.team = "enemy"
	laser.launch_velocity = Vector3.DOWN*32
	laser.damage = 10
	level.add_child(laser)
	laser.position = Vector3(100,2,0)
	await frames(20)
	check(ship.shield == 90 and ship.position.y < -0.05,"Actual projectile moves ship independently of cosmetic shake setting")
	# Hull sweep must prevent penetration when a hit pushes toward an adjacent wall.
	ship.reset_ship()
	ship.position = Vector3(3.35,0,-26)
	await frames(2)
	ship.take_damage(10,null,Vector3.RIGHT)
	await frames(25)
	check(ship.position.x <= 3.46 and absf(ship._hit_velocity.x) < 0.001,"Real level collisions stop the impact without wall penetration")
	ship.reset_ship()
	ship.physical_impacts = false
	ship.take_damage(10,null,Vector3.RIGHT)
	check(ship.velocity == Vector3.ZERO,"Physical hit response configurable independently")
	print("Physical hits: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.25).timeout
	quit(0 if failures == 0 else 1)
