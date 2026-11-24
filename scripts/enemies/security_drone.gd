extends CharacterBody3D
const Sounds = preload("res://scripts/audio/combat_audio.gd")
const Effects = preload("res://scripts/effects/combat_effects.gd")
const Laser = preload("res://scenes/weapons/laser.tscn")
enum State { PATROL, ALERT, APPROACH, ATTACK, SEARCH, RETURN_TO_PATROL, DESTROYED }
@export_group("Hull and navigation")
@export_range(0.0,1.0) var ammo_drop_probability: float = 0.7
@export var ammo_drop_min: int = 15
@export var ammo_drop_max: int = 35
@export var max_health: float = 60.0
@export var patrol_offsets := PackedVector3Array([Vector3.ZERO,Vector3(0,1,-3),Vector3(-3,-1,-1)])
@export var move_speed: float = 1.8
@export var acceleration: float = 5.0
@export var turn_speed: float = 3.0
@export var aggression: float = 2.0
@export_range(0.0,1.0) var dodge_frequency: float = 0.35
@export var minimum_distance: float = 5.0
@export var avoidance_distance: float = 2.4
@export var encounter_id: String = ""
var _rng := RandomNumberGenerator.new()
var _maneuver_time: float = 0.0
var _maneuver := Vector3.ZERO
var _pause: float = 0.0
var _dodge: float = 0.0
var _threat_time: float = 0.0
@export_group("Detection")
@export var detection_range: float = 60.0
@export_range(1.0,360.0) var field_of_view: float = 140.0
@export var detection_interval: float = 0.12
@export var alert_delay: float = 0.4
@export var search_duration: float = 4.0
@export_group("Weapon")
@export var attack_range: float = 48.0
@export var standoff_distance: float = 9.0
@export var fire_interval: float = 1.25
@export var projectile_speed: float = 32.0
@export var projectile_damage: float = 10.0
@export_group("Diagnostics")
@export var debug_visible: bool = false
var state: State = State.PATROL
var health: float
var sees_player: bool = false
var last_known_position := Vector3.ZERO
var shots_fired: int = 0
var _home := Vector3.ZERO
var _return_trail := PackedVector3Array()
var _patrol_index: int = 0
var _state_time: float = 0.0
var _sense_time: float = 0.0
var _fire_time: float = 0.0
var _player: CharacterBody3D
@onready var visual = $Visual
@onready var debug_label: Label3D = $DebugLabel
@onready var engine_audio: AudioStreamPlayer3D = $EngineAudio
@onready var event_audio: AudioStreamPlayer3D = $EventAudio
@onready var weapon_audio: AudioStreamPlayer3D = $WeaponAudio
func _ready() -> void:
	weapon_audio.stream = Sounds.sound("fire")
	weapon_audio.bus = Sounds.IndustrialSounds.ensure_bus()
	_rng.randomize()
	health = max_health
	_home = global_position
	_return_trail.append(_home)
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	engine_audio.stream = Sounds.sound("engine")
	if DisplayServer.get_name() != "headless": engine_audio.play()
	# Offset scans so multiple robots do not query in lockstep.
	_sense_time = float(get_instance_id()%10)*0.02
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		debug_visible = not debug_visible
func _physics_process(delta: float) -> void:
	if state == State.DESTROYED: return
	_state_time += delta
	_threat_time = maxf(0.0,_threat_time-delta)
	_fire_time = maxf(0.0,_fire_time-delta)
	_sense_time -= delta
	if _sense_time <= 0.0:
		_sense_time = maxf(0.05,detection_interval)
		sees_player = detect_player()
		if sees_player:
			last_known_position = _player.global_position
			if state in [State.PATROL,State.SEARCH,State.RETURN_TO_PATROL]: change_state(State.ALERT)
		elif state in [State.ALERT,State.APPROACH,State.ATTACK]: change_state(State.SEARCH)
	if state == State.PATROL:
		_return_trail = PackedVector3Array([_home,global_position])
	elif state != State.RETURN_TO_PATROL and (_return_trail.is_empty() or global_position.distance_to(_return_trail[-1]) > 1.5):
		# Breadcrumb waypoints retrace actual collision-safe travel through shafts/corners.
		if _return_trail.size() < 256: _return_trail.append(global_position)
	_maneuver_time -= delta
	_dodge = maxf(0.0,_dodge-delta)
	if _maneuver_time <= 0.0:
		_maneuver_time = _rng.randf_range(0.9,2.0)
		_maneuver = Vector3(_rng.randf_range(0.65,1.0)*(-1.0 if _rng.randf()<0.5 else 1.0),_rng.randf_range(-0.6,0.6),0)
	var target := global_position
	var combat_motion := Vector3.ZERO
	match state:
		State.PATROL:
			if not patrol_offsets.is_empty():
				_patrol_index %= patrol_offsets.size()
				target = _home + patrol_offsets[_patrol_index]
				if global_position.distance_to(target) < 0.35 and _pause <= 0.0:
					_pause = _rng.randf_range(0.6,1.6)
					_patrol_index = (_patrol_index+1)%patrol_offsets.size()
					target = _home+patrol_offsets[_patrol_index]
			if _pause > 0.0:
				_pause -= delta
				target = global_position
				face(global_position + Vector3(sin(_state_time)*2,0,-4),delta)
			else: face(target,delta)
		State.ALERT:
			face(last_known_position,delta)
			if _state_time >= alert_delay and sees_player: change_state(State.APPROACH)
		State.APPROACH, State.ATTACK:
			face(last_known_position,delta)
			if is_instance_valid(_player) and sees_player:
				var distance := global_position.distance_to(_player.global_position)
				if state == State.APPROACH and distance <= attack_range: change_state(State.ATTACK)
				elif state == State.ATTACK and distance > attack_range: change_state(State.APPROACH)
				var toward := (_player.global_position-global_position).normalized()
				var radial := clampf((distance-standoff_distance)*0.4,-1.0,1.0)
				if distance < minimum_distance: radial = -1.0
				var side := toward.cross(Vector3.UP)
				if side.length_squared() < 0.01: side = Vector3.RIGHT
				side = side.normalized()
				var up := side.cross(toward).normalized()
				var lateral := (side*_maneuver.x + up*_maneuver.y)*sin(_state_time*1.7)
				# Probe both directions: evasion contracts before entering a narrow passage.
				var clearance := minf(probe(side),probe(-side))
				lateral *= clampf((clearance-0.9)/maxf(0.1,avoidance_distance-0.9),0.0,1.0)
				combat_motion = (toward*radial + lateral*(1.5 if _dodge>0 else 0.9))*move_speed*aggression
				if _dodge > 0.0: combat_motion -= toward*move_speed*0.5
				var aim := (_player.global_position-global_position).normalized()
				if distance <= attack_range and -global_basis.z.dot(aim) > 0.96 and _fire_time <= 0.0 and has_line_of_sight(): fire()
		State.SEARCH:
			face(last_known_position,delta)
			target = last_known_position
			if _state_time >= search_duration or global_position.distance_to(target) < 0.6:
				change_state(State.RETURN_TO_PATROL)
		State.RETURN_TO_PATROL:
			if not _return_trail.is_empty() and global_position.distance_to(_return_trail[-1]) < 0.6:
				_return_trail.remove_at(_return_trail.size()-1)
			target = _return_trail[-1] if not _return_trail.is_empty() else _home
			face(target,delta)
			if global_position.distance_to(_home) < 0.7: change_state(State.PATROL)
	var desired := (target-global_position).normalized()*move_speed if global_position.distance_to(target)>0.25 else Vector3.ZERO
	if state in [State.APPROACH,State.ATTACK]: desired = combat_motion
	desired = avoid_obstacles(desired)
	velocity = velocity.move_toward(desired,acceleration*delta)
	move_and_slide()
	debug_label.visible = debug_visible
	if debug_visible: debug_label.text = "%s  HP %.0f/%.0f\nLOS %s  /  %.1f m" % [State.keys()[state],health,max_health,"YES" if sees_player else "NO",global_position.distance_to(_player.global_position) if is_instance_valid(_player) else 0.0]
func probe(direction: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position,global_position+direction*avoidance_distance,5)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return global_position.distance_to(hit.position) if not hit.is_empty() else avoidance_distance

func avoid_obstacles(desired: Vector3) -> Vector3:
	var result := desired
	for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		var distance := probe(axis)
		if distance < avoidance_distance:
			var into := result.dot(axis)
			if into > 0: result -= axis*into*(1.0-clampf((distance-0.85)/avoidance_distance,0,1))
			result -= axis*maxf(0.0,1.25-distance)*move_speed
	return result.limit_length(move_speed*maxf(1.0,aggression))

func face(point: Vector3, delta: float) -> void:
	var direction := point-global_position
	if direction.length_squared()<0.001: return
	var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP))>0.98 else Vector3.UP
	var target := Basis.looking_at(direction,up)
	basis = Basis(Quaternion(basis).slerp(Quaternion(target),clampf(turn_speed*delta,0,1))).orthonormalized()
func detect_player() -> bool:
	if not is_instance_valid(_player) or _player.shield <= 0.0: return false
	var offset := _player.global_position-global_position
	if offset.length()>detection_range: return false
	if _threat_time <= 0.0 and offset.length()>0.01 and -global_basis.z.dot(offset.normalized()) < cos(deg_to_rad(field_of_view*0.5)): return false
	return has_line_of_sight()
func has_line_of_sight() -> bool:
	if not is_instance_valid(_player): return false
	var query := PhysicsRayQueryParameters3D.create(global_position,_player.global_position,3)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player
func change_state(next: State) -> void:
	if state == next or state == State.DESTROYED: return
	state = next
	_state_time = 0.0
	if state == State.PATROL: _pause = 0.0
	if state == State.ALERT: play_event("alert")
func fire() -> void:
	var projectile = Laser.instantiate()
	projectile.team = "enemy"
	projectile.damage = projectile_damage
	projectile.shooter = self
	projectile.launch_velocity = (_player.global_position-global_position).normalized()*projectile_speed
	projectile.lifetime = 3.0
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = global_transform
	_fire_time = maxf(fire_interval,0.1)
	shots_fired += 1
	weapon_audio.play()
func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DESTROYED: return
	health = maxf(0.0,health-maxf(0.0,amount))
	if _rng.randf() < dodge_frequency: _dodge = 0.8
	visual.hit()
	play_event("hit")
	if health <= 0.0:
		if get_tree().current_scene.has_node("Mission"):
			get_tree().current_scene.get_node("Mission").destroyed[encounter_id] = true
		if get_tree().current_scene.has_method("drone_destroyed"): get_tree().current_scene.drone_destroyed(self)
		change_state(State.DESTROYED)
		sees_player = false
		debug_label.text = "DESTROYED  HP 0"
		collision_layer = 0
		collision_mask = 0
		$CollisionShape3D.set_deferred("disabled",true)
		engine_audio.stop()
		Effects.destruction(get_tree().current_scene,global_position)
		set_physics_process(false)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(visual,"scale",Vector3.ZERO,0.45)
		tween.tween_property(visual,"rotation:z",2.0,0.45)
		tween.chain().tween_callback(queue_free)
	elif is_instance_valid(source) and source.is_in_group("player"):
		_threat_time = 2.5
		_sense_time = 0.0
		last_known_position = source.global_position
		if state in [State.PATROL,State.SEARCH,State.RETURN_TO_PATROL]: change_state(State.ALERT)
func play_event(kind: String) -> void:
	event_audio.stream = Sounds.sound(kind)
	event_audio.play()
func _exit_tree() -> void:
	for audio in [engine_audio,event_audio,weapon_audio]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null
