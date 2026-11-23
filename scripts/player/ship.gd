extends CharacterBody3D
## Local-axis, gravity-free arcade flight. Speeds are in metres per second.
@export var cruise_speed: float = 18.0
@export var boost_multiplier: float = 2.2
@export var acceleration: float = 42.0
@export var deceleration: float = 30.0
@export var rotation_speed: float = 1.8
@export var rotation_acceleration: float = 10.0
@export var laser_scene: PackedScene = preload("res://scenes/weapons/laser.tscn")
var shield: float = 100.0
var energy: float = 100.0
var angular_velocity := Vector3.ZERO
var fire_cooldown: float = 0.0
var boosting := false
var boost_exhausted := false
@onready var camera: Camera3D = $Camera3D

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_ship"):
		reset_ship()
		return
	var movement := Vector3(Input.get_axis("strafe_left", "strafe_right"), Input.get_axis("move_down", "move_up"), Input.get_axis("move_forward", "move_backward")).limit_length()
	var boost_pressed := Input.is_action_pressed("boost")
	if not boost_pressed:
		boost_exhausted = false
	elif energy <= 0.0:
		boost_exhausted = true
	boosting = boost_pressed and not boost_exhausted and energy > 0.0 and not movement.is_zero_approx()
	var speed := cruise_speed * (boost_multiplier if boosting else 1.0)
	var target_velocity := global_basis * movement * speed
	velocity = velocity.move_toward(target_velocity, (deceleration if movement.is_zero_approx() else acceleration) * delta)
	var turn := Vector3(Input.get_axis("pitch_down", "pitch_up"), Input.get_axis("yaw_right", "yaw_left"), Input.get_axis("roll_right", "roll_left")) * rotation_speed
	angular_velocity = angular_velocity.move_toward(turn, rotation_acceleration * delta)
	# Compose intrinsic rotations so pitch, yaw and roll always follow the cockpit.
	var rotation_step := angular_velocity * delta
	if rotation_step.length_squared() > 0.0:
		basis = (basis * Basis(Quaternion.from_euler(rotation_step))).orthonormalized()
	move_and_slide()
	energy = clampf(energy + (-22.0 if boosting else 14.0) * delta, 0.0, 100.0)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0 and energy >= 2.0:
		fire()

func fire() -> void:
	var laser = laser_scene.instantiate()
	get_tree().current_scene.add_child(laser)
	laser.global_transform = camera.global_transform
	# Start the collision sweep at the camera: an offset muzzle can cross a
	# nearby wall before the projectile has performed its first raycast.
	laser.launch_velocity = -camera.global_basis.z * 100.0 + velocity
	energy -= 2.0
	fire_cooldown = 0.14

func reset_ship() -> void:
	global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 5))
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	energy = 100.0
	shield = 100.0
	boosting = false
	boost_exhausted = false
	fire_cooldown = 0.0
