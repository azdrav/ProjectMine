extends "res://scripts/levels/test_mine.gd"
const Cell = preload("res://scripts/resources/ammo_cell.gd")
var collected: Dictionary = {}
var pickups: Dictionary = {}
var _activation_clock := 0.0
@export_range(10,3600) var evacuation_duration: float = 240.0
@export_range(0,12) var evacuation_debris_limit: int = 6
const ENCOUNTERS := [Vector3(2,1,-44),Vector3(2,35,-44),Vector3(55,0,-3),Vector3(58,2,2),Vector3(54,0,-44),Vector3(58,2,-44),Vector3(54,34,-44),Vector3(59,35,-44),Vector3(87,34,-44),Vector3(-3,44,-80)]
func _ready() -> void:
	configure_inputs()
	wall_material = material(Color(0.16,0.20,0.23))
	floor_material = material(Color(0.10,0.13,0.15))
	trim_material = material(Color(0.2,0.7,0.75),true)
	room(Vector3.ZERO,Vector3(24,16,28),{"back":Vector2(8,8),"right":Vector2(8,8)},"ENTRANCE / MAINTENANCE ↓  •  EXCAVATION →")
	tunnel(Vector3(0,0,-14),Vector3(0,0,-38),8)
	room(Vector3(0,0,-44),Vector3(16,16,12),{"front":Vector2(8,8),"top":Vector2(8,8),"right":Vector2(8,8)},"MAINTENANCE / SHAFT ↑  •  TRANSPORT →")
	tunnel(Vector3(0,8,-44),Vector3(0,28,-44),8)
	room(Vector3(0,34,-44),Vector3(16,12,16),{"bottom":Vector2(8,8),"back":Vector2(8,8.944272),"right":Vector2(8,8)},"UTILITY JUNCTION / AUX POWER →  •  SECTOR B ↑")
	tunnel(Vector3(0,34,-52),Vector3(0,44,-72),8)
	room(Vector3(0,44,-80),Vector3(20,16,16),{"front":Vector2(8,8.944272)},"SECURITY / SECTOR B")
	tunnel(Vector3(12,0,0),Vector3(44,0,0),8)
	room(Vector3(56,0,0),Vector3(24,24,24),{"left":Vector2(8,8),"back":Vector2(8,8)},"EXCAVATION / ORE LIFT  •  TRANSPORT AHEAD")
	tunnel(Vector3(56,0,-12),Vector3(56,0,-36),8)
	room(Vector3(56,0,-44),Vector3(16,16,16),{"front":Vector2(8,8),"left":Vector2(8,8),"top":Vector2(8,8)},"TRANSPORT / MAINTENANCE ←  •  POWER ↑")
	tunnel(Vector3(8,0,-44),Vector3(48,0,-44),8)
	tunnel(Vector3(56,8,-44),Vector3(56,28,-44),8)
	room(Vector3(56,34,-44),Vector3(16,12,16),{"bottom":Vector2(8,8),"left":Vector2(8,8),"right":Vector2(8,8)},"AUX POWER / SECTOR B ←  •  SERVICE CACHE →")
	tunnel(Vector3(8,34,-44),Vector3(48,34,-44),8)
	tunnel(Vector3(64,34,-44),Vector3(80,34,-44),8)
	room(Vector3(88,34,-44),Vector3(16,12,16),{"left":Vector2(8,8),"right":Vector2(8,8)},"SERVICE / RESERVE CELLS")
	# Landmarks leave the central flight paths unobstructed.
	for x in [48.0,64.0]: box(Vector3(x,-6,0),Vector3(2,10,2),material(Color(0.32,0.24,0.10)))
	if industrial_upgrade:
		add_child(IndustrialSection.instantiate())
		add_child(IndustrialEnvironment.instantiate())
		for point in [Vector3(56,0,0),Vector3(56,0,-44),Vector3(56,34,-44),Vector3(88,34,-44)]:
			var area := Node3D.new()
			area.set_script(preload("res://scripts/visuals/industrial_area.gd"))
			area.center = point
			area.dimensions = Vector3(24,24,24) if point.z == 0 else Vector3(16,12,16)
			area.area_index = 3 if point.y > 0 else 1
			add_child(area)
	if environmental_audio:
		var ambience = EnvironmentAudio.instantiate()
		for i in range(4):
			var zone := Node3D.new()
			zone.set_script(preload("res://scripts/audio/acoustic_zone.gd"))
			zone.position = [Vector3(56,0,0),Vector3(56,0,-44),Vector3(56,34,-44),Vector3(88,34,-44)][i]
			zone.dimensions = Vector3(24,24,24) if i == 0 else Vector3(16,12,16)
			zone.profile = load("res://assets/audio/profiles/"+["open","steel","chamber","concrete"][i]+".tres")
			ambience.add_child(zone)
		add_child(ambience)
		for point in [Vector3(56,34,-44),Vector3(56,0,-44)]:
			var loop := AudioStreamPlayer3D.new()
			loop.position = point
			loop.stream = preload("res://scripts/audio/ambient_sounds.gd").sound("machinery" if point.y > 0 else "ventilation")
			loop.volume_db = -27
			loop.unit_size = 8
			loop.max_distance = 32
			add_child(loop)
			if DisplayServer.get_name() != "headless": loop.play()
	var mission := Node3D.new()
	mission.name = "Mission"
	mission.set_script(preload("res://scripts/mission/signal_lost.gd"))
	add_child(mission)
	mission.get_node("DoorSign").text = "SECTOR B / POWER ISOLATED\nAUX SUPPLY: POWER GALLERY"
	mission.controls.generator.position = Vector3(52,34,-48)
	mission.power_light.position = Vector3(54,35,-44)
	mission.audio.position = Vector3(52,34,-44)
	for body in mission.get_children():
		if body is StaticBody3D and body.position == Vector3(6.2,32.8,-46): body.position += Vector3(56,-1.3,0)
	if spawn_encounters: _spawn_drones()
	for i in range(3): spawn_cell("cache_"+str(i),[Vector3(50,0,6),Vector3(88,34,-42),Vector3(-5,0,-42)][i],30)
	spawn_cell("missile_cache_0",Vector3(50,0,5),2,"missiles")
	spawn_cell("missile_cache_1",Vector3(86,34,-42),2,"missiles")
	var escape := Node3D.new()
	escape.name="EscapeProtocol"
	escape.set_script(preload("res://scripts/flow/escape_protocol.gd"))
	escape.evacuation_duration=evacuation_duration
	escape.maximum_debris=evacuation_debris_limit
	add_child(escape)

func _spawn_drones() -> void:
	for i in range(ENCOUNTERS.size()):
		var template: PackedScene = preload("res://scenes/enemies/heavy_guardian.tscn") if i == 3 else preload("res://scenes/enemies/scout_drone.tscn") if i == 4 else DroneScene
		var drone = template.instantiate()
		drone.position = ENCOUNTERS[i]
		drone.encounter_id = "lower" if i == 0 else "upper" if i == 1 else "deep_"+str(i)
		drone.rotation.y = PI
		add_child(drone)
		drone.set_physics_process(false)
		drone.engine_audio.stop()
func _physics_process(delta: float) -> void:
	if $Mission.objective == 0 and $Ship.position.x > 16: $Mission.objective = 1
	_activation_clock -= delta
	if _activation_clock > 0: return
	_activation_clock = 0.4
	var ship = $Ship
	for drone in get_tree().get_nodes_in_group("enemies"):
		if drone.health <= 0: continue
		if has_node("EscapeProtocol") and $EscapeProtocol.phase!=0:
			drone.set_physics_process(false)
			drone.velocity=Vector3.ZERO
			drone.engine_audio.stop()
			if drone.has_method("suspend_variant"): drone.suspend_variant()
			continue
		var event_ready: bool = drone.encounter_id not in ["deep_7","deep_9"] or $Mission.generator_active
		drone.set_meta("alarm_enabled",event_ready)
		var active: bool = event_ready and (drone.position.distance_to(ship.position)<70 or drone.alarm_awake_until > Time.get_ticks_msec())
		drone.set_physics_process(active)
		if not active:
			if drone.has_method("suspend_variant"): drone.suspend_variant()
			drone.velocity = Vector3.ZERO
			drone.engine_audio.stop()
		elif not drone.engine_audio.playing and DisplayServer.get_name() != "headless": drone.engine_audio.play()
func valid_enemy_id(id: String) -> bool:
	return id in ["lower","upper","deep_2","deep_3","deep_4","deep_5","deep_6","deep_7","deep_8","deep_9"]
func spawn_cell(id: String, point: Vector3, amount: int, kind: String = "ammo") -> void:
	if pickups.has(id): return
	pickups[id] = {"position":[point.x,point.y,point.z],"amount":amount,"kind":kind}
	if collected.has(id): return
	var cell := Node3D.new()
	cell.set_script(Cell)
	cell.pickup_id = id
	cell.amount = amount
	cell.resource_kind = kind
	if id.begins_with("drop_"): cell.salvage_direction = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()
	cell.position = point
	add_child(cell)
func drone_destroyed(drone: Node3D) -> void:
	if drone.ammo_drop_probability <= 0.0 or (drone.ammo_drop_probability < 1.0 and randf() >= drone.ammo_drop_probability): return
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	for offset in [Vector3.ZERO,Vector3.UP,Vector3.RIGHT,Vector3.LEFT,Vector3.DOWN]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = drone.position+offset
		query.collision_mask = 1
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			spawn_cell("drop_"+drone.encounter_id,drone.position+offset,randi_range(drone.ammo_drop_min,drone.ammo_drop_max))
			return
func resource_message(message: String, point: Vector3) -> void:
	$Mission.message = message
	var sound := AudioStreamPlayer3D.new()
	sound.position = point
	sound.stream = preload("res://scripts/audio/ambient_sounds.gd").sound("malfunction" if message.begins_with("CANNONS EMPTY") else "pipe")
	sound.volume_db = -18
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
func save_expansion() -> Dictionary:
	return {"collected":collected,"pickups":pickups}
func valid_expansion(data: Variant) -> bool:
	if not data is Dictionary or not data.get("collected") is Dictionary or not data.get("pickups") is Dictionary: return false
	if data.pickups.size()>30 or data.collected.size()>30: return false
	for id in data.pickups:
		if id not in ["cache_0","cache_1","cache_2","missile_cache_0","missile_cache_1"] and not (str(id).begins_with("drop_") and valid_enemy_id(str(id).trim_prefix("drop_"))): return false
		var entry: Variant = data.pickups[id]
		if not entry is Dictionary or not $Mission.valid_numbers(entry.get("position"),3) or not $Mission.valid_numbers([entry.get("amount")],1): return false
		if entry.get("kind","ammo") not in ["ammo","missiles"]: return false
		if entry.amount < 1 or entry.amount > 200: return false
	for id in data.collected:
		if not data.pickups.has(id) or data.collected[id] != true: return false
	return true
func restore_expansion(data: Dictionary) -> void:
	for child in get_children():
		if child.get_script() == Cell:
			remove_child(child)
			child.queue_free()
	collected = data.collected.duplicate(true)
	pickups = {}
	for id in data.pickups:
		var entry: Dictionary = data.pickups[id]
		spawn_cell(id,Vector3(entry.position[0],entry.position[1],entry.position[2]),int(entry.amount),entry.get("kind","ammo"))

	spawn_cell("missile_cache_0",Vector3(50,0,5),2,"missiles")
	spawn_cell("missile_cache_1",Vector3(86,34,-42),2,"missiles")

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
