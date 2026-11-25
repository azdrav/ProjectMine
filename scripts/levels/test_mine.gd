extends Node3D
## Fixed primitive layout. Rooms have rectangular apertures, never overlapping caps.
@export var signal_lost: bool = true
@export var environmental_audio: bool = true
const EnvironmentAudio = preload("res://scenes/audio/environment_audio.tscn")
@export var spawn_encounters: bool = true
@export var industrial_upgrade: bool = true
@export var extended_industrial: bool = true
const IndustrialEnvironment = preload("res://scenes/visuals/industrial_environment.tscn")
const IndustrialSection = preload("res://scenes/visuals/industrial_section.tscn")
const DroneScene = preload("res://scenes/enemies/security_drone.tscn")
const TunnelWall = preload("res://scripts/levels/tunnel_wall.gd")

var decoration_portals: Array[Dictionary] = []

var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var trim_material: StandardMaterial3D

func _ready() -> void:
	configure_inputs()
	wall_material = material(Color(0.16, 0.23, 0.30))
	floor_material = material(Color(0.10, 0.14, 0.19))
	trim_material = material(Color(0.12, 0.75, 0.85), true)
	room(Vector3.ZERO, Vector3(24, 16, 28), {"back": Vector2(8, 8)}, "01 / LAUNCH • FORWARD")
	tunnel(Vector3(0, 0, -14), Vector3(0, 0, -38), 8.0)
	room(Vector3(0, 0, -44), Vector3(16, 16, 12), {"front": Vector2(8, 8), "top": Vector2(8, 8)}, "02 / SHAFT • ASCEND")
	tunnel(Vector3(0, 8, -44), Vector3(0, 28, -44), 8.0)
	room(Vector3(0, 34, -44), Vector3(16, 12, 16), {"bottom": Vector2(8, 8), "back": Vector2(8, 8.944272)}, "03 / INCLINE • FORWARD")
	tunnel(Vector3(0, 34, -52), Vector3(0, 44, -72), 8.0)
	room(Vector3(0, 44, -80), Vector3(20, 16, 16), {"front": Vector2(8, 8.944272)}, "04 / REACTOR • TURN BACK")
	if industrial_upgrade:
		add_child(IndustrialSection.instantiate())
		if extended_industrial: add_child(IndustrialEnvironment.instantiate())
	if environmental_audio: add_child(EnvironmentAudio.instantiate())
	if spawn_encounters: _spawn_drones()
	if signal_lost:
		var mission := Node3D.new()
		mission.name = "Mission"
		mission.set_script(preload("res://scripts/mission/signal_lost.gd"))
		add_child(mission)

func material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if glowing:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func box(center: Vector3, size: Vector3, surface: Material, orientation: Basis = Basis.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = center
	body.basis = orientation
	var mesh := MeshInstance3D.new()
	var primitive := BoxMesh.new()
	primitive.size = size
	mesh.mesh = primitive
	mesh.material_override = surface
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

# A wall in its own XY plane, optionally cut into four strips around an opening.
func wall(center: Vector3, width: float, height: float, orientation: Basis, opening: Vector2) -> void:
	if opening != Vector2.ZERO:
		decoration_portals.append({"pose":Transform3D(orientation,center),"half":Vector3(opening.x/2+0.15,opening.y/2+0.15,0.7)})
	if opening == Vector2.ZERO:
		box(center, Vector3(width, height, 0.4), wall_material, orientation)
		return
	var side := (width - opening.x) / 2.0
	var cap := (height - opening.y) / 2.0
	for sign_value in [-1.0, 1.0]:
		if side > 0.0:
			box(center + orientation * Vector3(sign_value * (opening.x + side) / 2.0, 0, 0), Vector3(side, height, 0.4), wall_material, orientation)
		if cap > 0.0:
			box(center + orientation * Vector3(0, sign_value * (opening.y + cap) / 2.0, 0), Vector3(opening.x, cap, 0.4), wall_material, orientation)

func room(center: Vector3, size: Vector3, openings: Dictionary, title: String) -> void:
	wall(center + Vector3(0, 0, size.z / 2), size.x, size.y, Basis.IDENTITY, openings.get("front", Vector2.ZERO))
	wall(center - Vector3(0, 0, size.z / 2), size.x, size.y, Basis.IDENTITY, openings.get("back", Vector2.ZERO))
	for sign_value in [-1.0, 1.0]:
		wall(center + Vector3(sign_value * size.x / 2, 0, 0), size.z, size.y, Basis(Vector3.UP, PI / 2), openings.get("right" if sign_value > 0 else "left", Vector2.ZERO))
	wall(center + Vector3(0, size.y / 2, 0), size.x, size.z, Basis(Vector3.RIGHT, PI / 2), openings.get("top", Vector2.ZERO))
	wall(center - Vector3(0, size.y / 2, 0), size.x, size.z, Basis(Vector3.RIGHT, PI / 2), openings.get("bottom", Vector2.ZERO))
	for x in [-size.x * 0.4, size.x * 0.4]:
		box(center + Vector3(x, -size.y / 2 + 0.25, 0), Vector3(0.12, 0.12, size.z - 0.5), trim_material)
	var light := OmniLight3D.new()
	light.position = center
	light.omni_range = size.length()
	light.light_energy = 3.0
	light.light_color = Color(0.6, 0.8, 1.0)
	add_child(light)
	var label := Label3D.new()
	label.text = title
	label.position = center + Vector3(0, size.y / 2 - 1.3, -size.z / 2 + 0.3)
	label.font_size = 48
	label.pixel_size = 0.012
	label.modulate = Color(0.3, 0.95, 1.0)
	add_child(label)

func tunnel(start: Vector3, end: Vector3, width: float) -> void:
	var direction := (end - start).normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var frame := Basis.looking_at(direction, up)
	var center := (start + end) / 2.0
	var length := start.distance_to(end)
	var axis_alignment := direction.abs()[direction.abs().max_axis_index()]
	for sign_value in [-1.0, 1.0]:
		if axis_alignment < 0.999:
			# Cut each tilted slab on the portal plane, not perpendicular to the tunnel.
			# The 25 cm overlap covers the room wall's 20 cm half-thickness.
			var side_min := width / 2.0 if sign_value > 0.0 else -width / 2.0 - 0.4
			add_child(TunnelWall.build(start, end, frame, Vector2(side_min, -width / 2.0 - 0.4), Vector2(side_min + 0.4, width / 2.0 + 0.4), wall_material))
			add_child(TunnelWall.build(start, end, frame, Vector2(-width / 2.0, side_min), Vector2(width / 2.0, side_min + 0.4), floor_material))
		else:
			box(center + frame * Vector3(sign_value * (width / 2 + 0.2), 0, 0), Vector3(0.4, width + 0.8, length + 0.8), wall_material, frame)
			box(center + frame * Vector3(0, sign_value * (width / 2 + 0.2), 0), Vector3(width, 0.4, length + 0.8), floor_material, frame)
	for index in range(1, int(length / 4.0)):
		var marker := start + direction * (index * 4.0)
		box(marker + frame * Vector3(-width / 2 + 0.08, 0, 0), Vector3(0.08, width - 0.3, 0.1), trim_material, frame)
		var light := OmniLight3D.new()
		light.position = marker
		light.omni_range = 10.0
		light.light_energy = 0.6
		light.light_color = Color(0.25, 0.8, 1.0)
		add_child(light)

func configure_inputs() -> void:
	var bindings := {
		"move_forward": [KEY_W], "move_backward": [KEY_S],
		"strafe_left": [KEY_A], "strafe_right": [KEY_D],
		"move_up": [KEY_SPACE], "move_down": [KEY_CTRL],
		"pitch_up": [KEY_UP], "pitch_down": [KEY_DOWN],
		"yaw_left": [KEY_LEFT], "yaw_right": [KEY_RIGHT],
		"roll_left": [KEY_Q], "roll_right": [KEY_E],
		"boost": [KEY_SHIFT], "fire": [KEY_ENTER], "reset_ship": [KEY_R]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mouse)

func _spawn_drones() -> void:
	for point in [Vector3(2,1,-44),Vector3(2,35,-44)]:
		var drone = DroneScene.instantiate()
		drone.position = point
		drone.encounter_id = "lower" if point.y < 10 else "upper"
		drone.rotation.y = PI
		add_child(drone)

func reset_encounter(clear_destroyed: bool = true) -> void:
	for wreck in get_tree().get_nodes_in_group("drone_wreckage"): wreck.queue_free()
	if clear_destroyed and has_node("Mission"): $Mission.destroyed.clear()
	for drone in get_tree().get_nodes_in_group("enemies"):
		drone.get_parent().remove_child(drone)
		drone.queue_free()
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		projectile.queue_free()
	if spawn_encounters: _spawn_drones()

func enemies_remaining() -> int:
	var count: int = 0
	for drone in get_tree().get_nodes_in_group("enemies"):
		if drone.health > 0.0: count += 1
	return count
