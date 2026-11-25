extends SceneTree
const Sounds = preload("res://scripts/audio/industrial_sounds.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var cannon: AudioStreamWAV = Sounds.player_cannon()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(Sounds.sound("enemy_fire").data)
	check(hash.finish().hex_encode() == "429f06cb2ccfbd08dde2cd9e75d5626cc6ba95d8c822de4f0b2a6fc47c29f1fc","Enemy firing PCM remains byte-identical to 0.8")
	var peak := 0.0
	var mean := 0.0
	for i in range(cannon.data.size()/2):
		var value := cannon.data.decode_s16(i*2)/32767.0
		peak = maxf(peak,absf(value))
		mean += value
	mean /= cannon.data.size()/2
	check(peak <= 0.601 and absf(mean) < 0.005,"Cannon PCM has headroom and negligible DC")
	check(cannon.get_length() >= 0.20 and cannon.get_length() <= 0.4,"Short cannon sound fits bounded three-voice rapid fire")
	check(cannon == Sounds.player_cannon(),"Recorded cannon loaded once and cached")
	cannon.save_to_wav("/tmp/projectmine081-cannon.wav")
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
	var weapons = ship.get_node("Camera3D/WeaponEffects")
	var camera = ship.get_node("Camera3D/VisualOffset")
	var audio = ship.get_node("Audio")
	weapons.set_process(false)
	camera.set_process(false)
	ship.position = Vector3(100,0,0)
	ship.velocity = Vector3(3,-2,1)
	var shot_count := 0
	for euler in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(-PI/2,0,0),Vector3(0,PI/2,PI/2),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		ship.basis = Basis.from_euler(euler)
		for side in range(2):
			weapons.reset_feedback()
			camera.reset_feedback()
			var pose: Transform3D = ship.global_transform
			var velocity: Vector3 = ship.velocity
			var events: int = audio.weapon_events
			ship.fire()
			var active: int = ship.last_fired_cannon
			check(active == shot_count%2,"Left and right cannons alternate per actual shot")
			shot_count += 1
			check(weapons._flashes[active].visible and not weapons._flashes[1-active].visible,"Selected muzzle flash starts on firing event")
			check(weapons.shot_ages[active] == 0 and weapons._cockpit_age == 0 and camera.channels.weapon.age == 0,"Barrel, cockpit and camera start on same firing event")
			check(audio.weapon_events == events+1 and audio.weapon.stream == cannon,"One firing event triggers one cannon sound")
			var laser = get_nodes_in_group("combat_projectiles")[-1]
			check(laser.global_transform.is_equal_approx(ship.camera.global_transform) and laser.launch_velocity.is_equal_approx(-ship.global_basis.z*100+velocity),"Alternating visual cannons preserve central shot and inherited velocity")
			laser.free()
			for i in range(6):
				camera.advance(1.0/120)
				weapons._process(1.0/120)
			var stroke: float = weapons.barrels[active].position.z-weapons._rest[active].z
			check(stroke > 0.04 and stroke <= 0.08,"Heavy cannon shows 4–8 cm peak mechanical stroke")
			check(is_equal_approx(weapons.barrels[1-active].position.z,weapons._rest[1-active].z),"Idle cannon stays at rest")
			check(weapons.housings[active].position.distance_to(weapons._housing_rest[active]) > 0 and weapons.brackets[active].position.z > weapons._bracket_rest[active].z,"Housing vibration and bracket reaction remain separate from barrel stroke")
			check(weapons._cockpit_offset.length() > camera.position.length() and camera.position.length() <= 0.015,"Cockpit impulse stronger than restrained camera displacement")
			check(camera.render_camera.global_basis.is_equal_approx(ship.global_basis),"Rotational vibration never reaches actual aiming/view axis")
			check(weapons.rotation.length() <= deg_to_rad(0.25)+0.00001,"Strict visual cockpit rotation limit")
			check(ship.global_transform == pose and ship.velocity == velocity,"Mechanical feedback never changes physics")
			for i in range(70):
				camera.advance(1.0/120)
				weapons._process(1.0/120)
			check(weapons.barrels[active].position.is_equal_approx(weapons._rest[active]) and camera.position == Vector3.ZERO,"Smooth complete recovery after single shot")
	# Sustained firing at the production interval; no additive kick growth.
	await create_timer(0.35).timeout # Let real audio voices finish before accelerated visual simulation.
	audio.enabled = false
	ship.energy = 10000 # Fixture only; production energy cost and cadence remain unchanged.
	for shot in range(80):
		ship.fire()
		get_nodes_in_group("combat_projectiles")[-1].free()
		for i in range(17):
			camera.advance(1.0/120)
			weapons._process(1.0/120)
			check(camera.position.length() <= camera.maximum_displacement and weapons._cockpit_offset.length() <= weapons.maximum_cockpit_displacement,"Sustained fire has bounded camera and cockpit motion")
			check(weapons.rotation.length() <= deg_to_rad(0.25)+0.00001,"Sustained fire never accumulates rotation")
	check(camera.channels.size() == 1 and audio.weapon.max_polyphony == 3,"Bounded impulse channel and three sound voices during sustained fire")
	check(ship.laser_damage == 20 and ship.laser_speed == 100 and ship.laser_interval == 0.14,"Weapon balance preserved")
	settings.intensity = 0
	check(camera.position == Vector3.ZERO and weapons._cockpit_offset == Vector3.ZERO and weapons.rotation == Vector3.ZERO,"Comfort disable clears all mechanical view motion")
	print("Heavy cannon: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
