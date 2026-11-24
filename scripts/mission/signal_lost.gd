extends Node3D
## Mission authority; interaction is proximity + unobstructed sight, never a waypoint arrow.
const SAVE_PATH := "user://signal_lost_v1.json"
const OBJECTIVES := ["Enter the mining complex", "Locate maintenance control — lower shaft chamber", "Read the maintenance power report [F]", "Activate auxiliary power — follow POWER markings", "Return to the sealed Sector B door", "Investigate Sector B security control", "Signal Lost complete — security lockdown confirmed"]
var objective: int = 0
var terminal_active := false
var generator_active := false
var door_open := false
var security_active := false
var destroyed: Dictionary = {}
var message := "Communications lost. Explore the facility. F: interact · F5: save · F9: load"
var controls: Dictionary = {}
var door: Node3D
var power_light: OmniLight3D
var audio: AudioStreamPlayer3D
var hud: Label
var prompt := ""
var ship: CharacterBody3D

func _ready() -> void:
	ship = get_tree().get_first_node_in_group("player")
	control("maintenance",Vector3(-5,0,-44),"MAINTENANCE / POWER REPORT")
	control("generator",Vector3(5,34,-44),"AUXILIARY GENERATOR / SECTOR B")
	control("security",Vector3(0,44,-85),"SECTOR B / SECURITY CONTROL")
	door = Node3D.new()
	door.set_script(preload("res://scripts/mission/sliding_door.gd"))
	door.name = "SectorBDoor"
	door.position = Vector3(0,44,-72)
	add_child(door)
	door.opened.connect(_on_door_opened)
	var sign := Label3D.new()
	sign.name = "DoorSign"
	sign.text = "SECTOR B / POWER ISOLATED\nAUX SUPPLY: UPPER TRANSFER"
	sign.position = Vector3(0,47.2,-71.15)
	sign.font_size = 28
	sign.pixel_size = 0.01
	add_child(sign)
	power_light = OmniLight3D.new()
	power_light.position = Vector3(4,35,-44)
	power_light.light_color = Color(1,0.25,0.04)
	power_light.light_energy = 0.6
	power_light.omni_range = 9
	add_child(power_light)
	audio = AudioStreamPlayer3D.new()
	audio.position = controls.generator.position
	audio.stream = preload("res://scripts/audio/ambient_sounds.gd").sound("startup")
	audio.volume_db = -14
	audio.max_distance = 28
	add_child(audio)
	build_generator()
	hud = Label.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 24
	hud.offset_top = -175
	hud.offset_bottom = -80
	hud.add_theme_font_size_override("font_size",16)
	hud.modulate = Color(0.65,0.86,0.85)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().get_node("HUD").add_child(hud)
	refresh_terminals()


func build_generator() -> void:
	# Compact service machinery beside the control; all pieces share one hull.
	var housing := StaticBody3D.new()
	housing.position = Vector3(6.2,32.8,-46)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4,2.0,3.0)
	collision.shape = shape
	housing.add_child(collision)
	for i in range(5):
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.4,2.0,0.4)
		fin.mesh = box
		fin.position.z = -1.2 + i*0.6
		fin.material_override = get_parent().material(Color(0.22,0.25,0.23))
		housing.add_child(fin)
	add_child(housing)

func control(id: String, point: Vector3, title: String) -> void:
	var body := StaticBody3D.new()
	body.set_script(preload("res://scripts/mission/control_terminal.gd"))
	body.terminal_id = id
	body.title = title
	body.position = point
	add_child(body)
	controls[id] = body

func refresh_terminals() -> void:
	controls.maintenance.set_status("POWER REPORT\nSECTOR B: ISOLATED\n"+("REPORT ACCESSED" if terminal_active else "AWAITING OPERATOR"),terminal_active)
	controls.generator.set_status("AUXILIARY SUPPLY\n"+("OUTPUT STABLE\nSECTOR B: ONLINE" if generator_active else "OUTPUT: OFFLINE\n"+("READY TO START" if terminal_active else "MAINTENANCE LOCK")),generator_active)
	controls.security.set_status("SECURITY CONTROL\n"+("LOG RECOVERED\nLOCKDOWN CONFIRMED" if security_active else "COMMUNICATIONS LOST\nACCESS LOG [F]"),security_active)

func _on_door_opened() -> void:
	door_open = true
	objective = maxi(objective,5)
	message = "Sector B access restored. Investigate the security console."
	$DoorSign.text = "SECTOR B / ACCESS OPEN"

func accessible(id: String) -> bool:
	var target: Node3D = controls[id]
	if ship.global_position.distance_to(target.global_position) > 3.5: return false
	var query := PhysicsRayQueryParameters3D.create(ship.global_position,target.global_position,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func interact(id: String) -> void:
	if not accessible(id) or ship.shield <= 0: return
	match id:
		"maintenance":
			if objective < 2: return
			terminal_active = true
			objective = maxi(objective,3)
			message = "Sector B power disabled by security lockdown. Auxiliary supply above the shaft."
		"generator":
			if not terminal_active:
				message = "Supply locked: consult maintenance power report first."
				return
			if not generator_active:
				generator_active = true
				objective = 4
				message = "Auxiliary supply online. Return along the incline to Sector B."
				audio.play()
				apply_power()
		"security":
			if not door_open: return
			security_active = true
			objective = 6
			message = "Security log: communications isolated by automated lockdown. Mission complete."

	refresh_terminals()

func apply_power() -> void:
	door.powered = generator_active
	door.update_indicators()
	refresh_terminals()
	$DoorSign.text = "SECTOR B / ACCESS OPEN" if door_open else "SECTOR B / AUXILIARY POWER ONLINE" if generator_active else "SECTOR B / POWER ISOLATED\nAUX SUPPLY: UPPER TRANSFER"
	power_light.light_color = Color(0.3,1,0.6) if generator_active else Color(1,0.25,0.04)
	power_light.light_energy = 2.0 if generator_active else 0.6

func _physics_process(_delta: float) -> void:
	if objective == 0 and ship.position.z < -16: objective = 1
	if objective == 1 and accessible("maintenance"): objective = 2
	if generator_active and not door_open and not door.opening and ship.position.distance_to(door.position) < 8:
		door.request_open()
		message = "Sector B interlock released. Stand clear — door opening."
		$DoorSign.text = "SECTOR B / OPENING"
	prompt = ""
	for id in controls:
		if accessible(id): prompt = "[F] " + str(id).to_upper()
	hud.text = "SIGNAL LOST / " + OBJECTIVES[objective] + "\n" + message + "\n" + prompt

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F:
			for id in controls:
				if accessible(id):
					interact(id)
					break
		KEY_F5: save_game()
		KEY_F9: load_game()

func save_game(path: String = SAVE_PATH) -> bool:
	# A save taken while moving restores the door fully open, never around the ship.
	var saved_door: bool = door_open or door.opening
	var saved_objective: int = maxi(objective,5) if door.opening else objective
	var data := {"version":3,"position":[ship.position.x,ship.position.y,ship.position.z],"basis":[],"shield":ship.shield,"energy":ship.energy,"objective":saved_objective,"terminal":terminal_active,"generator":generator_active,"door":saved_door,"security":security_active,"destroyed":destroyed}
	data["ammo"] = ship.ammo
	data["missiles"] = ship.missiles
	if get_parent().has_method("save_expansion"): data["expansion"] = get_parent().save_expansion()
	for axis in [ship.basis.x,ship.basis.y,ship.basis.z]: data.basis.append_array([axis.x,axis.y,axis.z])
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		message = "Save failed: cannot write file."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		message = "Save failed: incomplete write."
		return false
	var error := DirAccess.rename_absolute(path+".tmp",path)
	message = "Saved." if error == OK else "Save failed: cannot replace file."
	return error == OK

func valid_numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		message = "No readable save found."
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not validate_save(data):
		message = "Save rejected: invalid data or unsupported version."
		return false
	var b: Array = data.basis
	var restored := Basis(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]),Vector3(b[6],b[7],b[8]))
	if absf(restored.determinant()) < 0.01:
		message = "Save rejected: invalid orientation."
		return false
	ship.reset_ship()
	ship.position = Vector3(data.position[0],data.position[1],data.position[2])
	ship.basis = restored.orthonormalized()
	ship.shield = data.shield
	ship.energy = data.energy
	ship.ammo = int(data.ammo) if data.version >= 2 else ship.starting_ammo
	ship.missiles = int(data.missiles) if data.version >= 3 else ship.starting_missiles
	if get_parent().has_method("restore_expansion"):
		if data.has("expansion"): get_parent().restore_expansion(data.expansion)
		else: get_parent().restore_expansion({"collected":{},"pickups":{"cache_0":{"position":[50,0,6],"amount":30},"cache_1":{"position":[88,34,-42],"amount":30},"cache_2":{"position":[-5,0,-42],"amount":30}}})
	objective = int(data.objective)
	terminal_active = data.terminal
	generator_active = data.generator
	door_open = data.door
	security_active = data.security
	destroyed = data.destroyed.duplicate()
	door.restore(door_open)
	apply_power()
	get_parent().reset_encounter(false)
	for drone in get_tree().get_nodes_in_group("enemies"):
		if destroyed.has(drone.encounter_id):
			drone.get_parent().remove_child(drone)
			drone.queue_free()
	message = "Loaded."
	return true

func validate_save(data: Dictionary) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2 and data.get("version") != 3) or not valid_numbers(data.get("position"),3) or not valid_numbers(data.get("basis"),9): return false
	if data.get("version") == 3:
		if not valid_numbers([data.get("missiles")],1) or data.missiles < 0 or data.missiles > ship.max_missiles or data.missiles != floor(data.missiles): return false
	if data.get("version") >= 2:
		if not valid_numbers([data.get("ammo")],1) or data.ammo < 0 or data.ammo > ship.max_ammo or data.ammo != floor(data.ammo): return false
	if data.has("expansion") and (not get_parent().has_method("valid_expansion") or not get_parent().valid_expansion(data.expansion)): return false
	for key in ["shield","energy","objective"]:
		if not valid_numbers([data.get(key)],1): return false
	if data.objective < 0 or data.objective > 6 or data.objective != floor(data.objective): return false
	if data.shield < 0 or data.shield > 100 or data.energy < 0 or data.energy > 100: return false
	for key in ["terminal","generator","door","security"]:
		if not data.get(key) is bool: return false
	if not data.get("destroyed") is Dictionary: return false
	for id in data.destroyed:
		if data.destroyed[id] != true: return false
		if id not in ["lower","upper"] and (not get_parent().has_method("valid_enemy_id") or not get_parent().valid_enemy_id(id)): return false
	if data.terminal != (data.objective >= 3) or data.generator != (data.objective >= 4) or data.door != (data.objective >= 5) or data.security != (data.objective == 6): return false
	return not (data.generator and not data.terminal or data.door and not data.generator or data.security and not data.door)

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
