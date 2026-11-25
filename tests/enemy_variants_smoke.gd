extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		push_error(text)
		failures += 1
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	await frames(3)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var heavy: Node3D
	var scout: Node3D
	var guard: Node3D
	for enemy in get_nodes_in_group("enemies"):
		if enemy.encounter_id == "deep_3": heavy = enemy
		if enemy.encounter_id == "deep_4": scout = enemy
		if enemy.encounter_id == "deep_5": guard = enemy
	check(heavy != null and scout != null and get_nodes_in_group("enemies").size() == 10,"Variants replace encounters without increasing population")
	heavy.position = Vector3(200,0,0)
	heavy.basis = Basis.IDENTITY
	ship.position = Vector3(200,0,-18)
	await frames(2)
	heavy.take_damage(20,ship,Vector3.BACK)
	check(is_equal_approx(heavy.health,203),"Front armour reduces 20 damage to 7")
	heavy.take_damage(20,ship,Vector3.FORWARD)
	check(is_equal_approx(heavy.health,183),"Rear takes full damage")
	heavy.take_damage(20,ship,Vector3.LEFT)
	check(is_equal_approx(heavy.health,163),"Side hits bypass front armour")
	heavy.sees_player = true
	heavy.last_known_position = ship.position
	heavy.change_state(heavy.State.ATTACK)
	heavy.fire()
	check(heavy.charging and heavy.shots_fired == 0,"Heavy telegraphs charge before firing")
	heavy._physics_process(0.4)
	check(heavy.shots_fired == 0,"No projectile during charge")
	heavy._physics_process(0.6)
	check(heavy.shots_fired == 1,"Charged shot fires after delay")
	heavy.fire()
	var shutter := StaticBody3D.new()
	shutter.position = Vector3(200,0,-6)
	var collider := CollisionShape3D.new()
	var barrier := BoxShape3D.new()
	barrier.size = Vector3(8,8,0.3)
	collider.shape = barrier
	shutter.add_child(collider)
	level.add_child(shutter)
	await frames(2)
	heavy._physics_process(0.2)
	check(not heavy.charging and heavy.shots_fired == 1,"Cover cancels charging without a blind shot")
	shutter.queue_free()
	await frames(2)
	check(ship.get_node("MissileSystem").visible_target(heavy) == false,"Lock cone still excludes hostile behind aim")
	ship.basis = Basis(Vector3.UP,PI)
	await frames(2)
	check(ship.get_node("MissileSystem").visible_target(heavy),"Missiles recognize Guardian")
	scout.position = Vector3(200,0,-10)
	guard.position = Vector3(205,0,-10)
	await frames(2)
	scout.last_known_position = ship.position
	scout.broadcast_alarm()
	check(guard.state == guard.State.SEARCH and guard.last_known_position == ship.position,"Scout relays last known location locally")
	guard.change_state(guard.State.PATROL)
	var wall := StaticBody3D.new()
	wall.position = Vector3(202.5,0,-10)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4,8,8)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await frames(2)
	scout.broadcast_alarm()
	check(guard.state == guard.State.PATROL,"Walls block local alarm propagation")
	scout.position = Vector3(220,0,0)
	scout.basis = Basis.IDENTITY
	scout._home = scout.position
	ship.position = Vector3(220,0,-8)
	await frames(2)
	check(ship.get_node("MissileSystem").visible_target(scout),"Missiles recognize Scout")
	scout.alarm_wait = 0
	scout.alarm_progress = 0
	scout.sees_player = true
	scout.last_known_position = ship.position
	scout.change_state(scout.State.ATTACK)
	var alarms: int = scout.alarms_sent
	scout._physics_process(0.3)
	check(scout.alarms_sent == alarms and scout.velocity.z > 0,"Scout retreats while providing pre-alarm grace period")
	check(scout.shots_fired == 0,"Scout does not become a strong combat weapon")
	scout._physics_process(1.1)
	check(scout.alarms_sent == alarms+1 and scout.alarm_wait > 0,"Scout alarm activates only after delay and has cooldown")
	scout.alarm_wait = 0
	scout.alarm_progress = 0.9
	ship.position.x += 100
	await frames(2)
	scout._physics_process(0.1)
	check(scout.alarm_progress == 0,"Escaping detection cancels unfinished alarm")
	heavy.take_damage(9999,ship,Vector3.FORWARD)
	scout.take_damage(9999,ship)
	await frames(15)
	check(level.get_node("Mission").destroyed.has("deep_3") and level.get_node("Mission").destroyed.has("deep_4"),"Variant deaths preserve stable save IDs")
	check(get_nodes_in_group("drone_wreckage").size() >= 2,"Variants reuse mechanical wreckage")
	var mission = level.get_node("Mission")
	check(mission.save_game("user://enemy_variants_test.json"),"Save after variant destruction")
	check(mission.load_game("user://enemy_variants_test.json"),"Load variant encounter state")
	await frames(3)
	check(level.enemies_remaining() == 8 and mission.destroyed.has("deep_3") and mission.destroyed.has("deep_4"),"Destroyed variants stay destroyed on load")
	DirAccess.remove_absolute("user://enemy_variants_test.json")
	print("Enemy variants: ","PASS" if failures == 0 else str(failures)+" failures")
	level.queue_free()
	await create_timer(0.5).timeout
	quit(0 if failures == 0 else 1)
