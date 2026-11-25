extends SceneTree
## Real level activation and projectile hits: no manual AI ticks or teleports of the guardian.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func run() -> void:
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.position = Vector3(0,2,2)
	var guardian
	for enemy in get_nodes_in_group("enemies"):
		if enemy.encounter_id == "deep_3": guardian = enemy
		else: enemy.queue_free()
	await physics_frame
	await physics_frame
	check(guardian.is_physics_processing(),"Level activates Guardian on a fresh start")
	check(guardian.has_line_of_sight(),"Entrance sightline is clear")
	ship.basis = Basis.looking_at(guardian.global_position-ship.global_position,Vector3.UP)
	ship.fire()
	for i in range(180):
		await physics_frame
		if guardian.health < guardian.max_health: break
	check(guardian.health < guardian.max_health,"Actual primary projectile damages Guardian from entrance")
	for i in range(480):
		await physics_frame
		if guardian.shots_fired > 0: break
	check(guardian.shots_fired > 0,"Guardian retaliates while confined to its chamber")
	check(guardian.global_position.distance_to(guardian._home) < guardian.territory_radius+0.6,"Guardian retains its chamber leash")
	ship.position = Vector3(50,2,2)
	guardian.take_damage(20,ship,Vector3.RIGHT)
	guardian.visual._process(.016)
	for emitter in guardian.visual._emitters:
		if emitter.optic: check(emitter.material.emission.is_equal_approx(Color(1,.35,.16)),"Guardian hit flash is not overwritten by variant tint")
	ship.shield = 100
	var previous_shots: int = guardian.shots_fired
	for i in range(480):
		await physics_frame
		if guardian.shots_fired > previous_shots: break
	check(guardian.shots_fired > previous_shots and guardian.sees_player,"Live AI continues charging and firing inside chamber")
	# A projectile that outlives a destroyed shooter must still resolve damage and be removed.
	var dead_owner := Node3D.new()
	level.add_child(dead_owner)
	var projectile = load("res://scenes/weapons/laser.tscn").instantiate()
	projectile.team = "enemy"
	projectile.shooter = dead_owner
	projectile.damage = 10
	level.add_child(projectile)
	projectile.global_position = ship.global_position+Vector3(0,0,2)
	projectile.launch_velocity = Vector3.FORWARD*32
	projectile.set_physics_process(false)
	dead_owner.free()
	var shield_before: float = ship.shield
	await physics_frame
	projectile._physics_process(.1)
	check(is_equal_approx(ship.shield,shield_before-10),"Orphaned projectile applies damage without freed-owner errors")
	check(projectile.is_queued_for_deletion(),"Orphaned projectile cleans up after impact")
	level.queue_free()
	await create_timer(.2).timeout
	print("Guardian live encounter: ","PASS" if failures == 0 else str(failures)+" failures")
	quit(0 if failures == 0 else 1)
