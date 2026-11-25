extends CharacterBody3D
signal damaged(amount: float)
signal impact_feedback(amount: float, incoming_direction: Vector3)
signal hit_confirmed
signal flight_contact_sample(incoming: Vector3, delta: float)
signal flight_reset
signal weapon_fired
## Local-axis, gravity-free arcade flight. Speeds are in metres per second.
@export var cruise_speed: float = 18.0
@export var boost_multiplier: float = 2.2
@export var acceleration: float = 42.0
@export var deceleration: float = 30.0
@export var rotation_speed: float = 1.8
@export var rotation_acceleration: float = 10.0
@export_group("Physical projectile impacts")
@export var physical_impacts: bool = true
@export var hit_impulse_speed: float = 1.8
@export var full_impulse_damage: float = 10.0
@export var maximum_hit_velocity: float = 3.0
@export var hit_impulse_damping: float = 8.0
var _hit_velocity := Vector3.ZERO
@export_group("Mouse aiming")
## Radians per mouse pixel; mouse displacement is never multiplied by delta.
@export_range(0.0001, 0.02) var mouse_sensitivity: float = 0.0025
@export var invert_mouse_y: bool = false
@export_group("Weapons")
@export var laser_damage: float = 20.0
@export var laser_speed: float = 100.0
@export var laser_interval: float = 0.14
@export var laser_scene: PackedScene = preload("res://scenes/weapons/laser.tscn")
@export_group("Ammunition")
@export var starting_ammo: int = 120
@export var max_ammo: int = 200
@export var ammo_per_shot: int = 1
@export var low_ammo_threshold: int = 20
@export var starting_missiles: int = 5
@export var max_missiles: int = 12
var missiles: int = 5
var ammo: int = 120
var emergency_cooldown := 0.0
var _dry_wait := 0.0
var _mouse_motion := Vector2.ZERO
var _discard_mouse_motion := false
var _recapture_click := false
var shield: float = 100.0
var energy: float = 100.0
var angular_velocity := Vector3.ZERO
var fire_cooldown: float = 0.0
## Visual cannon selection only; one unchanged projectile is emitted per shot.
var last_fired_cannon: int = -1
var boosting := false
var boost_exhausted := false
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	ammo = mini(starting_ammo,max_ammo)
	missiles = mini(starting_missiles,max_missiles)
	# Browsers require a click before pointer lock; the web start panel supplies it.
	if not OS.has_feature("web"): capture_mouse()

func capture_mouse() -> void:
	_mouse_motion = Vector2.ZERO
	_discard_mouse_motion = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_motion = Vector2.ZERO
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_recapture_click = false
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_recapture_click = true
			capture_mouse()
			# A recapture click is not a shot; subsequent clicks still fire normally.
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _discard_mouse_motion:
			_discard_mouse_motion = false
		else:
			_mouse_motion += event.relative

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_motion = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_ship"):
		reset_ship()
		if get_tree().current_scene.has_method("reset_encounter"):
			get_tree().current_scene.reset_encounter()
		return
	if shield <= 0.0:
		_hit_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		_mouse_motion = Vector2.ZERO
		return
	emergency_cooldown = maxf(0.0,emergency_cooldown-delta)
	_dry_wait = maxf(0.0,_dry_wait-delta)
	if Input.is_physical_key_pressed(KEY_V) and emergency_cooldown <= 0.0: fire_emergency()
	var movement := Vector3(Input.get_axis("strafe_left", "strafe_right"), Input.get_axis("move_down", "move_up"), Input.get_axis("move_forward", "move_backward")).limit_length()
	var boost_pressed := Input.is_action_pressed("boost")
	if not boost_pressed:
		boost_exhausted = false
	elif energy <= 0.0:
		boost_exhausted = true
	boosting = boost_pressed and not boost_exhausted and energy > 0.0 and not movement.is_zero_approx()
	var speed := cruise_speed * (boost_multiplier if boosting else 1.0)
	var target_velocity := global_basis * movement * speed
	# Keep the short impact response separate from flight braking; no-hit flight is unchanged.
	var flight_velocity := velocity-_hit_velocity
	_hit_velocity *= exp(-maxf(0.1,hit_impulse_damping)*delta)
	if _hit_velocity.length() < 0.001: _hit_velocity = Vector3.ZERO
	velocity = flight_velocity.move_toward(target_velocity, (deceleration if movement.is_zero_approx() else acceleration) * delta)+_hit_velocity
	var turn := Vector3(Input.get_axis("pitch_down", "pitch_up"), Input.get_axis("yaw_right", "yaw_left"), Input.get_axis("roll_right", "roll_left")) * rotation_speed
	angular_velocity = angular_velocity.move_toward(turn, rotation_acceleration * delta)
	# Compose intrinsic rotations so pitch, yaw and roll always follow the cockpit.
	var mouse_turn := Vector3(-_mouse_motion.y * (-1.0 if invert_mouse_y else 1.0), -_mouse_motion.x, 0.0) * mouse_sensitivity
	_mouse_motion = Vector2.ZERO
	var rotation_step := angular_velocity * delta + mouse_turn
	if rotation_step.length_squared() > 0.0:
		basis = (basis * Basis(Quaternion.from_euler(rotation_step))).orthonormalized()
	var incoming_velocity := velocity
	move_and_slide()
	# Resolve the impulse against the same real hull contacts as ordinary flight.
	for i in range(get_slide_collision_count()):
		var contact := get_slide_collision(i)
		for hit in range(contact.get_collision_count()):
			var normal := contact.get_normal(hit)
			if _hit_velocity.dot(normal) < 0.0: _hit_velocity = _hit_velocity.slide(normal)
	flight_contact_sample.emit(incoming_velocity,delta)
	energy = clampf(energy + (-22.0 if boosting else 14.0) * delta, 0.0, 100.0)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var firing := Input.is_action_pressed("fire")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _recapture_click):
		firing = Input.is_physical_key_pressed(KEY_ENTER)
	if firing and fire_cooldown <= 0.0 and energy >= 2.0:
		fire()

func fire() -> void:
	if ammo < maxi(1,ammo_per_shot):
		if _dry_wait <= 0.0:
			_dry_wait = 0.45
			fire_cooldown = 0.14
			if get_tree().current_scene.has_method("resource_message"): get_tree().current_scene.resource_message("CANNONS EMPTY — HOLD V: emergency emitter",global_position)
		return
	ammo -= maxi(1,ammo_per_shot)
	var laser = laser_scene.instantiate()
	laser.shooter = self
	laser.damage = laser_damage
	get_tree().current_scene.add_child(laser)
	# Camera3D is the unshaken aim reference; VisualOffset only moves RenderCamera.
	laser.global_transform = camera.global_transform
	# Start the collision sweep at the camera: an offset muzzle can cross a
	# nearby wall before the projectile has performed its first raycast.
	laser.launch_velocity = -camera.global_basis.z * laser_speed + velocity
	last_fired_cannon = (last_fired_cannon+1)%2
	var cockpit = $Camera3D/WeaponEffects
	if cockpit.cockpit_enabled:
		laser.visual_muzzle = cockpit.muzzle_world(last_fired_cannon)
		laser.use_visual_muzzle = true
	weapon_fired.emit()
	energy -= 2.0
	fire_cooldown = maxf(0.05,laser_interval)

func fire_emergency() -> void:
	if shield <= 0.0: return
	var pulse = laser_scene.instantiate()
	pulse.shooter = self
	pulse.damage = 5.0
	get_tree().current_scene.add_child(pulse)
	pulse.global_transform = camera.global_transform
	pulse.launch_velocity = -camera.global_basis.z*laser_speed+velocity
	emergency_cooldown = 0.65
	$Audio.emergency_fire()

func reset_ship() -> void:
	global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 5))
	velocity = Vector3.ZERO
	_hit_velocity = Vector3.ZERO
	_mouse_motion = Vector2.ZERO
	angular_velocity = Vector3.ZERO
	energy = 100.0
	shield = 100.0
	boosting = false
	boost_exhausted = false
	fire_cooldown = 0.0
	last_fired_cannon = -1
	missiles = mini(starting_missiles,max_missiles)
	ammo = mini(starting_ammo,max_ammo)
	emergency_cooldown = 0.0
	flight_reset.emit()

func take_damage(amount: float, source: Node = null, incoming_direction: Vector3 = Vector3.ZERO) -> void:
	if shield <= 0.0: return
	var applied := minf(shield,maxf(0.0,amount))
	shield -= applied
	if applied > 0.0:
		damaged.emit(applied)
		if incoming_direction.is_zero_approx() and source is Node3D:
			incoming_direction = (global_position-source.global_position).normalized()
		if physical_impacts and shield > 0.0 and not incoming_direction.is_zero_approx():
			var previous := _hit_velocity
			var strength := maxf(0.0,hit_impulse_speed)*clampf(applied/maxf(0.1,full_impulse_damage),0.0,1.5)
			_hit_velocity = (_hit_velocity+incoming_direction.normalized()*strength).limit_length(maxf(0.0,maximum_hit_velocity))
			velocity += _hit_velocity-previous
		impact_feedback.emit(applied,incoming_direction)
