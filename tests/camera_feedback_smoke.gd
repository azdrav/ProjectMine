extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		push_error(text)
		failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func step(ship: CharacterBody3D, velocity: Vector3, count: int) -> void:
	for i in range(count):
		await physics_frame
		ship.velocity = velocity
		ship.move_and_slide()
		var pose := ship.global_transform
		var resolved := ship.velocity
		ship.flight_contact_sample.emit(velocity,1.0/60.0)
		check(ship.global_transform == pose and ship.velocity == resolved,"Feedback never changes contact resolution")
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	await frames(3)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled = false
	var settings = root.get_node("FeedbackSettings")
	settings.intensity = 1.0
	var feedback = ship.get_node("Camera3D/VisualOffset")
	feedback.set_process(false)
	var weapons = ship.get_node("Camera3D/WeaponEffects")
	weapons.set_process(false)
	ship.position = Vector3(0,0,-24)
	ship.velocity = Vector3(1,2,3)
	for euler in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(-PI/2,0,0),Vector3(0,PI/2,PI/2),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		ship.basis = Basis.from_euler(euler)
		feedback.reset_feedback()
		var pose: Transform3D = ship.global_transform
		var speed: Vector3 = ship.velocity
		ship.fire()
		feedback.advance(0.016)
		weapons._process(0.016)
		var projectiles := get_nodes_in_group("combat_projectiles")
		var laser = projectiles[-1]
		check(laser.global_transform.is_equal_approx(ship.camera.global_transform),"Unshaken projectile origin in every 6DoF pose")
		check(laser.launch_velocity.is_equal_approx(-ship.global_basis.z*100+speed),"Unshaken projectile velocity in every 6DoF pose")
		feedback.update_aim_point()
		level.get_node("HUD")._process(0.0)
		var crosshair: Label = level.get_node("HUD/Crosshair")
		var screen_center := crosshair.position+crosshair.size*0.5
		var visual_ray: Vector3 = feedback.render_camera.project_ray_normal(screen_center)
		var to_target: Vector3 = (feedback.aim_point-feedback.render_camera.global_position).normalized()
		check(visual_ray.dot(to_target) > 0.9999,"Crosshair projection stays on actual projectile aim under shake")
		check(feedback.render_camera.global_basis.is_equal_approx(ship.global_basis),"Render axis stays parallel to actual aim")
		check(ship.global_transform == pose and ship.velocity == speed,"Shake does not move ship")
		check(weapons.barrels[ship.last_fired_cannon].position.z > weapons._rest[ship.last_fired_cannon].z,"Selected firing barrel recoils")
		check(feedback.position.length() > 0 and feedback.position.length() < weapons.barrels[ship.last_fired_cannon].position.z-weapons._rest[ship.last_fired_cannon].z,"Barrel recoil exceeds camera recoil")
		feedback.reset_feedback()
		feedback.hit_impulse(25,ship.global_basis.x)
		feedback.advance(0.016)
		check(feedback.position.x > 0,"World hit direction converts correctly for every ship orientation")
		laser.queue_free()
	# Repeated events never accumulate beyond three independently bounded channels.
	for i in range(100):
		feedback.weapon_impulse()
		feedback.hit_impulse(25,Vector3.RIGHT)
		feedback.advance(0.001)
		check(feedback.position.length() <= feedback.maximum_displacement+0.00001,"Repeated fire/hits bounded")
	check(feedback.channels.size() == 2,"Rapid impulses replace channels rather than accumulating")
	feedback.add_impulse("wall",feedback.maximum_displacement,0.22,Vector3.UP,true)
	feedback.advance(0.016)
	check(feedback.channels.size() == 3 and feedback.position.length() <= feedback.maximum_displacement,"All three feedback channels share one comfort cap")
	feedback.reset_feedback()
	feedback._rng.seed = 17
	feedback.weapon_impulse()
	feedback.advance(0.016)
	var full: Vector3 = feedback.position
	feedback.reset_feedback()
	settings.intensity = 0.5
	feedback._rng.seed = 17
	feedback.weapon_impulse()
	feedback.advance(0.016)
	check(feedback.position.is_equal_approx(full*0.5),"Global percentage scales displacement proportionally")
	settings.intensity = 1.0
	feedback.reset_feedback()
	feedback.hit_impulse(5,Vector3.RIGHT)
	var small: float = feedback.channels.shield.amplitude
	feedback.hit_impulse(25,Vector3.LEFT)
	check(feedback.channels.shield.amplitude > small and feedback.channels.shield.direction == Vector3.LEFT,"Damage magnitude and incoming direction preserved")
	var received := [Vector3.ZERO]
	ship.impact_feedback.connect(func(_damage: float, direction: Vector3): received[0] = direction)
	ship.take_damage(5,null,Vector3.DOWN)
	check(received[0] == Vector3.DOWN,"Damage signal passes projectile travel direction")
	check(level.get_node("HUD")._damage_flash.color.a <= 0.12,"Shield flash remains subtle")
	ship.position = Vector3(100,0,0)
	ship.shield = 100
	var enemy_laser = load("res://scenes/weapons/laser.tscn").instantiate()
	enemy_laser.team = "enemy"
	enemy_laser.damage = 7
	enemy_laser.launch_velocity = Vector3.DOWN*32
	level.add_child(enemy_laser)
	enemy_laser.position = Vector3(100,2,0)
	await frames(8)
	check(ship.shield == 93 and received[0] == Vector3.DOWN,"Real enemy projectile supplies its incoming direction")
	# Isolate return damping at different rendering rates.
	feedback.reset_feedback()
	feedback.position = Vector3(0.02,0.01,0)
	for i in range(30): feedback.advance(1.0/60)
	var sixty: Vector3 = feedback.position
	feedback.reset_feedback()
	feedback.position = Vector3(0.02,0.01,0)
	for i in range(15): feedback.advance(1.0/30)
	check(feedback.position.distance_to(sixty) < 0.00001,"Exponential return damping is frame-rate independent")
	feedback.weapon_impulse()
	feedback.advance(0.016)
	settings.intensity = 0.0
	check(feedback.position == Vector3.ZERO and feedback.channels.is_empty(),"Zero setting immediately clears camera shake")
	feedback.hit_impulse(25,Vector3.UP)
	feedback.advance(0.016)
	weapons.fire()
	weapons._process(0.016)
	check(feedback.position == Vector3.ZERO and is_equal_approx(weapons.barrels[0].position.z,weapons._rest[0].z),"Disabled setting prevents all camera and barrel shake")
	settings.intensity = 1.0
	# Real wall contacts, including exactly parallel sliding and separation.
	var wall := StaticBody3D.new()
	wall.position = Vector3(205,0,0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1,40,100)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await frames(2)
	feedback.set_process(true)
	ship.position = Vector3(203.9,0,0)
	await step(ship,Vector3.RIGHT,10)
	check(feedback.impact_events == 0,"Gentle contact produces no hull impulse")
	for euler in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(-PI/2,0,0),Vector3(0,PI/2,PI/2),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		feedback.reset_feedback()
		ship.position = Vector3(203.9,0,0)
		ship.basis = Basis.from_euler(euler)
		await step(ship,Vector3(25,0,0),1)
		check(feedback.normal_speed > 24.9 and feedback.channels.has("wall"),"Hull impulse uses real normal closing speed in every orientation")
	var impact_count: int = feedback.impact_events
	await step(ship,Vector3(0.2,0,-8),30)
	check(feedback.scrape_gain > 0.1,"Continuous sliding produces low vibration")
	check(feedback.impact_events == impact_count,"Tangential speed does not create heavy impacts")
	await step(ship,Vector3(0,0,-8),20)
	check(feedback.scrape_gain > 0.1,"Parallel sliding retains real wall contact")
	await step(ship,Vector3(-6,0,-8),25)
	check(feedback.scrape_gain == 0.0,"Leaving wall stops scraping vibration")
	await frames(60)
	check(feedback.position == Vector3.ZERO,"All transient motion settles completely")
	ship.reset_ship()
	check(feedback.position == Vector3.ZERO and feedback.channels.is_empty(),"Ship reset/load clears residual feedback")
	print("Camera feedback: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
