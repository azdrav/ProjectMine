extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		failures += 1
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func clear_projectiles() -> void:
	for node in get_nodes_in_group("combat_projectiles"): node.queue_free()
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	await frames(3)
	var ship = level.get_node("Ship")
	ship.get_node("Proximity").enabled = false
	var drones := get_nodes_in_group("enemies")
	check(drones.size() == 2,"Two encounter drones")
	var drone = drones[0]
	var friend = drones[1]
	friend.set_physics_process(false)
	drone.move_speed = 0.0
	drone.global_position = Vector3(0,0,-44)
	drone.basis = Basis(Vector3.UP,PI)
	drone.alert_delay = 0.35
	drone.detection_interval = 0.05
	drone._sense_time = 0.0
	var debug_key := InputEventKey.new()
	debug_key.physical_keycode = KEY_F4
	debug_key.pressed = true
	drone._unhandled_key_input(debug_key)
	drone.fire_interval = 0.4
	drone.projectile_speed = 60.0
	ship.global_position = Vector3(0,0,-30)
	# Long-range detection can acquire the launch bay before fixture placement.
	drone.change_state(drone.State.PATROL)
	check(drone.state == drone.State.PATROL,"Initial PATROL state")
	await frames(10)
	check(drone.state == drone.State.ALERT and drone.sees_player,"Range / FOV / LOS acquire player")
	check(drone.debug_label.visible and drone.debug_label.text.contains("ALERT"),"F4 exposes state/health/detection label")
	await frames(65)
	check(drone.state == drone.State.ATTACK and drone.shots_fired > 0,"ALERT transitions to ATTACK and fires")
	check(ship.shield < 100,"Enemy projectiles damage player shield")
	check(level.get_node("HUD").dashboard.shield_bar.value == ship.shield,"Cockpit shield instrument reflects combat damage")
	# Add real cover and verify both sensing and projectiles respect it.
	var cover := StaticBody3D.new()
	cover.position = Vector3(0,0,-36)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7,7,0.5)
	collider.shape = shape
	cover.add_child(collider)
	level.add_child(cover)
	clear_projectiles()
	await frames(5)
	check(not drone.has_line_of_sight() and drone.state == drone.State.SEARCH,"Cover blocks sight and triggers SEARCH")
	drone.search_duration = 0.2
	await frames(20)
	check(drone.state in [drone.State.RETURN_TO_PATROL,drone.State.PATROL],"Search timeout returns toward patrol")
	ship.shield = 100
	drone.fire()
	await frames(25)
	check(ship.shield == 100,"Walls stop enemy projectiles")
	cover.queue_free()
	await frames(3)
	drone.set_physics_process(false)
	drone.global_position = Vector3(0,0,-44)
	drone.basis = Basis(Vector3.UP,PI)
	ship.position = Vector3(0,0,-47)
	check(not drone.detect_player(),"FOV rejects player behind drone")
	ship.position = Vector3(0,0,30)
	check(not drone.detect_player(),"Detection range rejects distant player")
	# Full 3D patrol movement, independent of ship orientation.
	drone._home = Vector3(2,0,-44)
	drone.position = drone._home
	drone.patrol_offsets = PackedVector3Array([Vector3(0,2,0)])
	drone._patrol_index = 0
	drone._pause = 0.0
	drone.move_speed = 1.8
	drone.detection_range = 0.1
	drone.change_state(drone.State.PATROL)
	drone.set_physics_process(true)
	await frames(45)
	check(drone.position.y > 0.6,"Patrol includes vertical movement")
	drone.set_physics_process(false)
	clear_projectiles()
	ship.reset_ship()
	ship.position = Vector3(0,0,-30)
	drone.position = Vector3(0,0,-35)
	drone.health = drone.max_health
	await frames(2)
	var sensor = ship.get_node("Proximity")
	sensor.enabled = true
	sensor.scan(1.0)
	check(sensor.readings.FWD.severity > 0 and absf(sensor.readings.FWD.clearance-3.73) < 0.05,"Existing proximity module detects drone hull")
	sensor.enabled = false
	var collision_debug = level.get_node("CollisionDebug")
	collision_debug.set_enabled(true)
	check(collision_debug._overlay.get_child_count() == 76,"F3 retains player and level geometry without stale dynamic hulls")
	collision_debug.set_enabled(false)
	var hits := [0]
	ship.hit_confirmed.connect(func(): hits[0] += 1)
	ship.fire()
	await frames(8)
	check(drone.health == 40 and hits[0] == 1,"Player laser damages drone and confirms hit")
	check(ship.shield == 100,"Player does not shoot own hull")
	# Friendly robot directly in the enemy firing line must not take friendly damage.
	drone.position = Vector3(0,0,-44)
	friend.position = Vector3(0,0,-38)
	var friend_health: float = friend.health
	drone.fire()
	await frames(24)
	check(friend.health == friend_health and ship.shield == 90,"Enemy lasers ignore allies and hit player")
	friend.position = Vector3(2,35,-44)
	clear_projectiles()
	drone.position = Vector3(0,0,-35)
	drone.health = 20
	ship.fire()
	await frames(8)
	check(drone.state == drone.State.DESTROYED and drone.collision_layer == 0,"Lethal hit enters DESTROYED and removes collision")
	check(level.enemies_remaining() == 1,"Destroyed drone leaves objective count immediately")
	await frames(65)
	check(not is_instance_valid(drone),"Drone destruction animation removes robot")
	check(level.find_children("DroneDestruction*","Node3D",true,false).is_empty(),"Destruction effects clean up")
	friend.take_damage(999,ship)
	await frames(2)
	check(level.enemies_remaining() == 0 and level.get_node("HUD/Status").text.contains("SECTOR CLEAR"),"Both kills complete encounter")
	var sound_factory = load("res://scripts/audio/combat_audio.gd")
	for kind in ["engine","alert","fire","hit","destroy"]:
		var stream: AudioStreamWAV = sound_factory.sound(kind)
		check(stream.data.size() > 1000,"Generated audio: " + kind)
	ship.take_damage(999)
	await frames(2)
	check(ship.shield == 0 and level.get_node("HUD/Status").text.contains("SHIP DISABLED"),"Shield depletion and restart feedback")
	Input.action_press("reset_ship")
	await frames(2)
	Input.action_release("reset_ship")
	check(ship.shield == 100 and level.enemies_remaining() == 2,"R restores shield and encounter")
	for actor in get_nodes_in_group("enemies"):
		check(actor.health == actor.max_health,"Restart creates healthy drones")
	print("First contact combat: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	level.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
