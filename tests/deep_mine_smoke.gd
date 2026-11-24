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
	await frames(4)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	var mission = level.get_node("Mission")
	check(get_nodes_in_group("enemies").size() == 10,"Ten dispersed drones")
	var sleeping := 0
	for drone in get_nodes_in_group("enemies"):
		if not drone.is_physics_processing(): sleeping += 1
		drone.detection_range = 0
	check(sleeping >= 5,"Most encounters sleep outside the player area")
	var routes := [[Vector3(0,0,0),Vector3(56,0,0),Vector3(56,0,-44),Vector3(0,0,-44),Vector3(0,0,0)],[Vector3(56,0,-44),Vector3(56,34,-44),Vector3(0,34,-44),Vector3(0,0,-44)],[Vector3(56,34,-44),Vector3(88,34,-44)]]
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	for route in routes:
		for index in range(route.size()-1):
			var a: Vector3 = route[index]
			var b: Vector3 = route[index+1]
			for i in range(int(a.distance_to(b)*2)+1):
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.collision_mask = 1
				query.transform.origin = a.lerp(b,float(i)/maxf(1,int(a.distance_to(b)*2)))
				check(level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Hull-clear branch/shaft at "+str(query.transform.origin))
	for center in [Vector3.ZERO,Vector3(0,0,-44),Vector3(0,34,-44),Vector3(56,0,0),Vector3(56,0,-44),Vector3(56,34,-44),Vector3(88,34,-44)]:
		for i in range(64):
			var y := 1.0-2.0*(i+0.5)/64.0
			var radius := sqrt(1-y*y)
			var direction := Vector3(cos(i*2.39996)*radius,y,sin(i*2.39996)*radius)
			var ray := PhysicsRayQueryParameters3D.create(center,center+direction*400,1)
			check(not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Enclosed sector shell at "+str(center))
	ship.ammo = 1
	ship.fire()
	check(ship.ammo == 0,"One round per projectile")
	var count := get_nodes_in_group("combat_projectiles").size()
	ship.fire()
	check(get_nodes_in_group("combat_projectiles").size() == count,"Empty cannons do not fire")
	ship.fire_emergency()
	check(get_nodes_in_group("combat_projectiles").size() == count+1 and ship.ammo == 0,"Emergency weapon remains available without ammo")
	ship.position = Vector3(88,34,-42)
	await create_timer(0.15).timeout
	check(ship.ammo == 30 and level.collected.has("cache_1"),"Automatic cell collection")
	await frames(4)
	check(ship.ammo == 30,"No duplicate collection")
	ship.ammo = 195
	ship.position = Vector3(50,0,6)
	await frames(3)
	check(ship.ammo == 200,"Capacity respected")
	mission.objective = 2
	ship.position = Vector3(-5,0,-42)
	await frames(2)
	mission.interact("maintenance")
	ship.position = Vector3(52,34,-46)
	await frames(2)
	mission.interact("generator")
	check(mission.generator_active,"Power objective relocated to power sector")
	ship.position = Vector3(0,44,-68)
	await frames(165)
	ship.position = Vector3(0,44,-83)
	await frames(2)
	mission.interact("security")
	check(mission.objective == 6,"Expanded mission completes without clearing enemies")
	var drone = get_nodes_in_group("enemies")[2]
	drone.ammo_drop_probability = 1.0
	drone.take_damage(999,ship)
	check(level.pickups.has("drop_"+drone.encounter_id),"Guaranteed test drop from real destruction")
	ship.ammo = 73
	check(mission.save_game("user://deep_mine_test.json"),"Save version two")
	ship.ammo = 0
	level.collected.clear()
	check(mission.load_game("user://deep_mine_test.json"),"Load expanded state")
	await frames(3)
	check(ship.ammo == 73 and level.collected.has("cache_1") and mission.objective == 6 and get_nodes_in_group("enemies").size() == 9,"Ammo, pickups, enemy and mission persistence")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://deep_mine_test.json"))
	legacy.version = 1
	legacy.erase("ammo")
	legacy.erase("expansion")
	legacy.destroyed = {"lower":true}
	var file := FileAccess.open("user://deep_mine_test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(mission.load_game("user://deep_mine_test.json") and ship.ammo == 120 and level.collected.is_empty(),"Legacy v1 saves receive starting ammunition and fresh resource caches")
	DirAccess.remove_absolute("user://deep_mine_test.json")
	print("Deep mine: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	level.queue_free()
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)
