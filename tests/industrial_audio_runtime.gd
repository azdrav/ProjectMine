extends SceneTree
## Real-time, audible stages plus actual CharacterBody contacts inside the launch bay.
var ship: CharacterBody3D
func _initialize() -> void: call_deferred("run")
func stage(label: String, seconds: float) -> void:
	print("AUDIO STAGE ",label," ",Time.get_ticks_msec())
	await create_timer(seconds).timeout
func drive(velocity: Vector3, count: int) -> void:
	for index in range(count):
		await physics_frame
		ship.velocity=velocity
		ship.move_and_slide()
		ship.flight_contact_sample.emit(velocity,1.0/60)
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	ship=level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for drone in get_nodes_in_group("enemies"):
		drone.set_physics_process(false)
		drone.engine_audio.stop()
	await stage("silence / recorder setup",3.0)
	for index in range(6):
		ship.fire()
		await create_timer(.15).timeout
	await stage("player weapon tail",.4)
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.position=Vector3(2,0,-8)
	for index in range(3):
		enemy.fire()
		await create_timer(.35).timeout
	await stage("enemy weapon / shield tail",.8)
	ship.take_damage(5)
	await stage("light shield hit",.4)
	ship.take_damage(25)
	await stage("heavy shield hit",.5)
	ship.position=Vector3(11.20,0,3)
	await drive(Vector3(1,0,0),10)
	await stage("gentle contact / quiet",.4)
	ship.position=Vector3(11.20,0,3)
	await drive(Vector3(30,0,0),1)
	await stage("heavy hull impact",.5)
	print("AUDIO STAGE slow scrape ",Time.get_ticks_msec())
	await drive(Vector3(.2,0,-4),35)
	print("AUDIO STAGE fast scrape ",Time.get_ticks_msec())
	await drive(Vector3(.2,0,-12),35)
	await drive(Vector3.ZERO,20)
	await stage("stopped against wall / quiet",.5)
	await drive(Vector3(.2,0,8),25)
	await drive(Vector3(-8,0,0),20)
	await stage("separated / quiet",.5)
	var audio = ship.get_node("Audio")
	print("RUNTIME AUDIO ",JSON.stringify({"impact_events":audio.impact_events,"shield_events":audio.shield_events,"scrape_starts":audio.scrape_starts,"scrape_gain_end":audio.scrape_gain,"shield":ship.shield}))
	level.queue_free()
	await create_timer(.2).timeout
	quit()
