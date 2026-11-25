extends "res://scripts/enemies/security_drone.gd"
## Shared FSM, sensing, avoidance, projectiles, destruction and persistence.
enum Variant { HEAVY, SCOUT }
@export var variant: Variant = Variant.HEAVY
@export_group("Variant profile")
@export var variant_health: float = 210
@export var patrol_speed: float = 0.8
@export var combat_acceleration: float = 3.5
@export var combat_evasion: float = 0.16
@export var preferred_distance: float = 15
@export var model_scale := Vector3(1.8,1.8,1.8)
@export var hull_radius: float = 1.26
@export_group("Guardian / scout abilities")
@export var charge_duration: float = 0.95
@export var frontal_damage_multiplier: float = 0.35
@export var frontal_cone_degrees: float = 55.0
@export var alarm_delay: float = 1.3
@export var alarm_radius: float = 28.0
@export var alarm_cooldown: float = 10.0
var charge_glow: MeshInstance3D
var charging := false
var charge_remaining := 0.0
var alarm_progress := 0.0
var alarm_wait := 0.0
var alarms_sent := 0
func _ready() -> void:
	max_health = variant_health
	move_speed = patrol_speed
	acceleration = combat_acceleration
	evasion_strength = combat_evasion
	standoff_distance = preferred_distance
	visual.model.scale = model_scale
	var variant_hull := SphereShape3D.new()
	variant_hull.radius = hull_radius
	$CollisionShape3D.shape = variant_hull
	if variant == Variant.HEAVY:
		territory_radius = 7
		aggression = 2.0
		dodge_frequency = 0.10
		minimum_distance = 10
		# The 7 m chamber leash must not strand a visible target outside gun range.
		attack_range = 60.0
		fire_interval = 3.2
		projectile_damage = 22
		projectile_speed = 24
		avoidance_distance = 3.6
		var cannon: Node3D = visual.model.find_child("Weapon",true,false)
		charge_glow = MeshInstance3D.new()
		var chamber := SphereMesh.new()
		chamber.radius = 0.07
		chamber.height = 0.14
		chamber.radial_segments = 12
		chamber.rings = 6
		charge_glow.mesh = chamber
		charge_glow.position = visual.model.find_child("Muzzle",true,false).position + Vector3(0,0,0.025)
		var energy := StandardMaterial3D.new()
		energy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		energy.albedo_color = Color(1,0.25,0.03)
		charge_glow.material_override = energy
		charge_glow.visible = false
		cannon.add_child(charge_glow)
	else:
		aggression = 1.8
		maneuver_min = 0.45
		maneuver_max = 0.85
		minimum_distance = 16
		retreat_only = true
		weapon_enabled = false
		dodge_frequency = 0.65
		visual.model.find_child("Weapon",true,false).visible = false
	super._ready()
	engine_audio.pitch_scale = 0.58 if variant == Variant.HEAVY else 1.55
	engine_audio.volume_db = -18 if variant == Variant.HEAVY else -24
	weapon_audio.stream = Sounds.IndustrialSounds.sound("player_fire") if variant == Variant.HEAVY else Sounds.sound("fire")
	weapon_audio.pitch_scale = 0.75 if variant == Variant.HEAVY else 1.4
	for emitter in visual._emitters:
		if emitter.optic and variant == Variant.SCOUT:
			emitter.albedo = Color(1,0.55,0.04)
			emitter.emission = Color(1,0.45,0.02)
func _physics_process(delta: float) -> void:
	if state == State.DESTROYED: return
	if variant == Variant.HEAVY and charging:
		if not has_line_of_sight() or not sees_player or global_position.distance_to(_player.global_position)>attack_range:
			charging = false
			event_audio.stop()
			_fire_time = 0.3
		else:
			charge_remaining -= delta
			if charge_remaining <= 0:
				charging = false
				event_audio.stop()
				super.fire()
	super._physics_process(delta)
	if is_instance_valid(charge_glow): charge_glow.visible = charging
	if variant == Variant.SCOUT:
		alarm_wait = maxf(0,alarm_wait-delta)
		if sees_player and detect_player() and alarm_wait <= 0:
			alarm_progress += delta
			if alarm_progress >= alarm_delay:
				broadcast_alarm()
				alarm_wait = alarm_cooldown
				alarm_progress = 0
		else: alarm_progress = 0
		if state == State.SEARCH and not sees_player: change_state(State.RETURN_TO_PATROL)
func fire() -> void:
	if variant != Variant.HEAVY or charging: return
	charging = true
	if is_instance_valid(charge_glow): charge_glow.visible = true
	charge_remaining = charge_duration
	event_audio.stream = preload("res://scripts/audio/ambient_sounds.gd").sound("startup")
	event_audio.pitch_scale = 0.8
	event_audio.play()
func broadcast_alarm() -> void:
	alarms_sent += 1
	play_event("alert")
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally == self or ally.get_script() != preload("res://scripts/enemies/security_drone.gd") or ally.health <= 0 or global_position.distance_to(ally.global_position)>alarm_radius: continue
		if not ally.get_meta("alarm_enabled",true): continue
		var ray := PhysicsRayQueryParameters3D.create(global_position,ally.global_position,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		ally.alarm_awake_until = Time.get_ticks_msec()+5000
		ally.set_physics_process(true)
		ally.last_known_position = last_known_position
		ally._threat_time = 2.5
		ally._sense_time = 0
		ally.change_state(ally.State.SEARCH)
func suspend_variant() -> void:
	charging = false
	charge_remaining = 0
	alarm_progress = 0
	if is_instance_valid(charge_glow): charge_glow.visible = false
	event_audio.stop()

func take_damage(amount: float, source: Node = null, incoming_direction: Vector3 = Vector3.ZERO) -> void:
	if variant == Variant.HEAVY:
		var attacker := -incoming_direction.normalized()
		if incoming_direction.is_zero_approx() and source is Node3D: attacker = (source.global_position-global_position).normalized()
		if attacker.dot(-global_basis.z)>cos(deg_to_rad(frontal_cone_degrees)): amount *= clampf(frontal_damage_multiplier,0,1)
	super.take_damage(amount,source,incoming_direction)
	if state == State.DESTROYED:
		charging = false
		if is_instance_valid(charge_glow): charge_glow.visible = false
		alarm_progress = 0
