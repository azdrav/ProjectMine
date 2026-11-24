extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func wall(parent: Node, point: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.position = point
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8,8,0.3)
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body
func run() -> void:
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	level.spawn_encounters = false
	root.add_child(level)
	current_scene = level
	await frames(4)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	level.set_physics_process(false)
	check(ship.ammo == 120 and ship.max_ammo == 200 and ship.missiles == 5 and ship.max_missiles == 12,"Starting supplies and capacities")
	ship.position = Vector3(200,0,0)
	ship.basis = Basis.IDENTITY
	var controller = ship.get_node("MissileSystem")
	var drone = load("res://scenes/enemies/security_drone.tscn").instantiate()
	drone.position = Vector3(200,0,-18)
	drone.encounter_id = "deep_2"
	level.add_child(drone)
	drone.set_physics_process(false)
	await frames(4)
	check(controller.visible_target(drone),"Initial acquisition requires range and crosshair cone")
	await frames(50)
	check(controller.locked,"Continuous 0.7-second lock")
	var cover = wall(level,Vector3(200,0,-8))
	await frames(4)
	check(not controller.locked and not controller.visible_target(drone),"Cover immediately loses lock")
	cover.queue_free()
	await frames(50)
	var blockers: Array[Node] = []
	for i in range(4):
		var active := Node.new()
		level.add_child(active)
		active.add_to_group("guided_missiles")
		blockers.append(active)
	check(not controller.launch() and ship.missiles == 5,"Global active missile cap does not consume ammunition")
	for active in blockers: active.free()
	ship.missiles = 0
	check(not controller.launch(),"No launch with empty missile stores")
	ship.missiles = 5
	check(controller.locked and controller.launch(),"Confirmed lock launches missile")
	check(ship.missiles == 4 and not controller.launch(),"One missile consumed and cooldown enforced")
	await frames(95)
	check(not is_instance_valid(drone) or drone.health == 0,"Missile deals three primary hits")
	check(ship.shield == 100,"Missile cannot hit its shooter")
	# A fast missile must sweep a thin wall, not tunnel through.
	var obstacle = wall(level,Vector3(200,0,-3))
	await frames(3)
	var missile := Node3D.new()
	missile.set_script(load("res://scripts/weapons/homing_missile.gd"))
	missile.shooter = ship
	missile.direction = Vector3.FORWARD
	missile.speed = 30
	level.add_child(missile)
	missile.position = Vector3(200,0,0)
	await frames(12)
	check(not is_instance_valid(missile),"Swept sphere collides with thin walls")
	obstacle.queue_free()
	# Gradual turns obey the angular-rate cap in arbitrary ship attitudes.
	var target = load("res://scenes/enemies/security_drone.tscn").instantiate()
	target.position = Vector3(220,10,0)
	level.add_child(target)
	target.set_physics_process(false)
	ship.missiles = 12
	for pose in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(-PI/2,0,0),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		ship.basis = Basis.from_euler(pose)
		target.position = ship.position-ship.global_basis.z*20
		await frames(2)
		controller.reset_lock()
		controller._physics_process(0.71)
		check(controller.locked and controller.launch(),"Acquisition and launch in rolled/vertical orientations")
		var launched = get_nodes_in_group("guided_missiles")[-1]
		check(launched.direction.is_equal_approx(-ship.global_basis.z),"Missile launch follows real ship orientation")
		launched.free()
	ship.basis = Basis.IDENTITY
	target.position = Vector3(200,0,-40)
	await frames(2)
	check(not controller.visible_target(target),"Initial locks limited to 35 metres")
	target.position = Vector3(220,10,0)
	var guided := Node3D.new()
	guided.set_script(load("res://scripts/weapons/homing_missile.gd"))
	guided.shooter = ship
	guided.target = target
	level.add_child(guided)
	guided.position = Vector3(200,0,0)
	guided.set_physics_process(false)
	var before: Vector3 = guided.direction
	guided._physics_process(0.016)
	check(before.angle_to(guided.direction) <= deg_to_rad(110)*0.016+0.001,"Missile turn rate is bounded")
	check(guided.speed < 30,"Missile accelerates smoothly")
	for i in range(8):
		target.position += Vector3(0,0,-0.4)
		before = guided.direction
		guided._physics_process(0.016)
		check(before.angle_to(guided.direction) <= deg_to_rad(110)*0.016+0.001,"Moving target still obeys gradual steering")
	guided.queue_free()
	target.queue_free()
	var abandoned := Node3D.new()
	abandoned.set_script(load("res://scripts/weapons/homing_missile.gd"))
	abandoned.shooter = ship
	abandoned.direction = Vector3.UP
	level.add_child(abandoned)
	abandoned.position = Vector3(300,0,0)
	await frames(55)
	check(not is_instance_valid(abandoned),"Lost target missile safely expires after brief straight flight")
	ship.ammo = 7
	ship.missiles = 2
	ship.energy = 50
	ship.set_physics_process(true)
	await frames(80)
	ship.set_physics_process(false)
	check(ship.energy > 50,"Energy regeneration preserved independently of ammo")
	var energy: float = ship.energy
	check(ship.ammo == 7 and ship.missiles == 2,"Neither ammunition resource regenerates")
	ship.ammo = 0
	var count := get_nodes_in_group("combat_projectiles").size()
	ship.fire()
	check(get_nodes_in_group("combat_projectiles").size() == count,"Zero primary ammo blocks fire")
	ship.ammo = 195
	ship.position = Vector3(-5,0,-42)
	await create_timer(0.2).timeout
	check(ship.ammo == 200 and ship.energy == energy,"Primary pickup replenishes ammo only and respects capacity")
	ship.missiles = 11
	ship.position = Vector3(50,0,5)
	await create_timer(0.2).timeout
	check(ship.missiles == 12 and ship.energy == energy,"Missile cache respects capacity and never replenishes energy")
	ship.ammo = 37
	check(level.get_node("Mission").save_game("user://missile_test.json"),"Save v3")
	ship.ammo = 0
	ship.missiles = 0
	check(level.get_node("Mission").load_game("user://missile_test.json") and ship.ammo == 37 and ship.missiles == 12,"Ammo and missiles restored")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://missile_test.json"))
	for version in [1,2]:
		saved.version = version
		saved.erase("missiles")
		if version == 1: saved.erase("ammo")
		else: saved.ammo = 29
		var legacy := FileAccess.open("user://missile_test.json",FileAccess.WRITE)
		legacy.store_string(JSON.stringify(saved))
		legacy.close()
		check(level.get_node("Mission").load_game("user://missile_test.json") and ship.missiles == 5 and ship.ammo == (120 if version == 1 else 29),"Legacy ammunition migration for save version "+str(version))
	DirAccess.remove_absolute("user://missile_test.json")
	print("Missiles and ammo: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)
