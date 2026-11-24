extends Node
const Missile = preload("res://scripts/weapons/homing_missile.gd")
@export var lock_distance: float = 35.0
@export var lock_seconds: float = 0.7
@export var lock_cone_degrees: float = 6.0
@export var cooldown: float = 1.2
@export var maximum_active: int = 4
@export var missile_speed: float = 30.0
@export var missile_turn_rate: float = 110.0
var target: Node3D
var progress := 0.0
var locked := false
var wait := 0.0
var scan_wait := 0.0
var launcher: Node3D
var label: Label
var beep: AudioStreamPlayer
@onready var ship = get_parent()
func _ready() -> void:
	launcher = Node3D.new()
	launcher.name = "MissileLauncher"
	launcher.position = Vector3(0.34,-0.20,-0.65)
	ship.get_node("Camera3D/WeaponEffects").add_child(launcher)
	for x in [-0.055,0.055]:
		var body := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.055
		mesh.height = 0.24
		mesh.radial_segments = 10
		body.mesh = mesh
		body.position.x = x
		body.rotation.x = PI/2
		body.layers = 1<<19
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.13,0.17,0.18)
		steel.metallic = 0.6
		steel.roughness = 0.5
		body.material_override = steel
		launcher.add_child(body)
		var recess := MeshInstance3D.new()
		var inset := CylinderMesh.new()
		inset.top_radius = 0.033
		inset.bottom_radius = 0.033
		inset.height = 0.008
		inset.radial_segments = 10
		recess.mesh = inset
		recess.rotation.x = PI/2
		recess.position = Vector3(x,0,0.124)
		recess.layers = 1<<19
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.018,0.025,0.026)
		recess.material_override = dark
		launcher.add_child(recess)
	var mount := MeshInstance3D.new()
	var bracket := BoxMesh.new()
	bracket.size = Vector3(0.28,0.055,0.30)
	mount.mesh = bracket
	mount.position = Vector3(0.08,-0.075,0.03)
	mount.layers = 1<<19
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.16,0.19,0.20)
	mount.material_override = armor
	launcher.add_child(mount)
	var support := MeshInstance3D.new()
	var arm := BoxMesh.new()
	arm.size = Vector3(0.26,0.06,0.10)
	support.mesh = arm
	support.position = Vector3(0.20,-0.15,-0.08)
	support.rotation.z = -0.4
	support.layers = 1<<19
	support.material_override = armor
	launcher.add_child(support)
	beep = AudioStreamPlayer.new()
	beep.stream = preload("res://scripts/audio/combat_audio.gd").sound("alert")
	beep.volume_db = -24
	add_child(beep)
	ship.flight_reset.connect(reset_lock)
func reset_lock() -> void:
	target = null
	progress = 0
	locked = false
	wait = 0
	scan_wait = 0
func visible_target(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or enemy.health <= 0: return false
	var offset: Vector3 = enemy.global_position-ship.camera.global_position
	if offset.length()>lock_distance or offset.length()<0.01: return false
	var aim: Vector3 = (-ship.camera.global_basis.z*ship.laser_speed+ship.velocity).normalized()
	if offset.normalized().dot(aim)<cos(deg_to_rad(lock_cone_degrees)): return false
	var ray := PhysicsRayQueryParameters3D.create(ship.camera.global_position,enemy.global_position,5)
	var hit: Dictionary = ship.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider == enemy
func acquire() -> void:
	var candidate: Node3D
	var best := -1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if visible_target(enemy):
			var score: float = (enemy.global_position-ship.camera.global_position).normalized().dot(-ship.camera.global_basis.z)
			if score > best:
				best = score
				candidate = enemy
	if candidate != target:
		target = candidate
		progress = 0
		locked = false
func _physics_process(delta: float) -> void:
	wait = maxf(0.0,wait-delta)
	if ship.shield <= 0:
		reset_lock()
		return
	scan_wait -= delta
	if scan_wait <= 0:
		scan_wait = 0.1
		acquire()
	if is_instance_valid(target) and not visible_target(target):
		target = null
		progress = 0
		locked = false
	if is_instance_valid(target):
		progress = minf(lock_seconds,progress+delta)
		if progress >= lock_seconds and not locked:
			locked = true
			beep.play()
	else:
		progress = 0
		locked = false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): launch()
func launch() -> bool:
	if ship.shield <= 0 or ship.missiles <= 0 or wait>0 or not locked or not visible_target(target) or get_tree().get_nodes_in_group("guided_missiles").size()>=maximum_active: return false
	var origin: Vector3 = launcher.to_global(Vector3(-0.055,0,-0.13))
	var path := PhysicsRayQueryParameters3D.create(ship.camera.global_position,origin,1)
	if not ship.get_world_3d().direct_space_state.intersect_ray(path).is_empty(): return false
	var missile := Node3D.new()
	missile.set_script(Missile)
	missile.shooter = ship
	missile.target = target
	missile.damage = ship.laser_damage*3
	missile.max_speed = missile_speed
	missile.turn_rate_degrees = missile_turn_rate
	missile.direction = -ship.camera.global_basis.z
	get_tree().current_scene.add_child(missile)
	missile.global_transform = Transform3D(ship.camera.global_basis,origin)
	ship.missiles -= 1
	wait = cooldown
	ship.get_node("Audio").emergency_fire()
	return true
func _process(_delta: float) -> void:
	if not is_instance_valid(label):
		var hud = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
		if hud == null: return
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",14)
		hud.add_child(label)
	label.text = ("◇ NO MISSILES" if locked and ship.missiles <= 0 else "◇ LOCKED / RMB" if locked else "◇ ACQUIRING %d %%" % roundi(progress/maxf(0.01,lock_seconds)*100)) if is_instance_valid(target) else ""
	label.modulate = Color(1,0.55,0.12) if locked else Color(0.7,0.85,0.8)
	var view: Camera3D = ship.get_node("Camera3D/VisualOffset/RenderCamera")
	if is_instance_valid(target) and not view.is_position_behind(target.global_position): label.position = view.unproject_position(target.global_position)+Vector2(18,12)
func _exit_tree() -> void:
	if is_instance_valid(label): label.queue_free()
	if is_instance_valid(beep):
		beep.stop()
		beep.stream = null
