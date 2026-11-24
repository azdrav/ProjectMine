extends Node3D
const VFX = preload("res://scripts/effects/energy_vfx.gd")
const CockpitModel = preload("res://assets/models/cockpit/industrial_cockpit.glb")
signal cockpit_toggled(active: bool)
@export var cockpit_enabled: bool = true
var muzzles: Array[Node3D] = []
var model: Node3D
const Feedback = preload("res://scripts/effects/cockpit_feedback.gd")
@export_group("Cannon mechanics")
@export var barrel_recoil: float = 0.075
@export var recoil_duration: float = 0.075
@export var recovery_duration: float = 0.20
@export var housing_vibration: float = 0.0025
@export var bracket_reaction: float = 0.0015
@export_group("Visual cockpit only")
@export var cockpit_impulse: float = 0.024
@export var cockpit_vibration: float = 0.002
@export var maximum_cockpit_displacement: float = 0.030
@export var maximum_rotation_degrees: float = 0.25
var _flashes: Array[MeshInstance3D] = []
var barrels: Array[Node3D] = []
var housings: Array[Node3D] = []
var brackets: Array[Node3D] = []
var shot_ages := PackedFloat64Array([10.0,10.0])
var _cockpit_age := 10.0
var _side := -1.0
var _cockpit_offset := Vector3.ZERO
var _cockpit_angles := Vector3.ZERO
var _rest: Array[Vector3] = []
var _housing_rest: Array[Vector3] = []
var _bracket_rest: Array[Vector3] = []
@onready var ship = get_parent().get_parent()
@onready var mount: Node3D = get_parent().get_node("VisualOffset")
@onready var settings = get_node("/root/FeedbackSettings")
func _ready() -> void:
	process_priority = -5
	model = CockpitModel.instantiate()
	add_child(model)
	for side in ["Left","Right"]:
		var barrel := model.find_child(side+"Barrel",true,false) as Node3D
		var housing := model.find_child(side+"Housing",true,false) as Node3D
		var bracket := model.find_child(side+"Mount",true,false) as Node3D
		barrels.append(barrel)
		housings.append(housing)
		brackets.append(bracket)
		_rest.append(barrel.position)
		_housing_rest.append(housing.position)
		_bracket_rest.append(bracket.position)
		var muzzle := model.find_child("Muzzle"+side,true,false) as Node3D
		muzzles.append(muzzle)
		var flash := VFX.flash("player",.065)
		flash.visible = false
		muzzle.add_child(flash)
		_flashes.append(flash)
	set_visual_layer(self)
	visible = cockpit_enabled
	ship.weapon_fired.connect(fire)
	ship.flight_reset.connect(reset_feedback)
	settings.changed.connect(func(value: float):
		if value <= 0.0: clear_motion())
func set_visual_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = 1 << 19
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): set_visual_layer(child)

func set_cockpit_enabled(active: bool) -> void:
	cockpit_enabled = active
	visible = active
	cockpit_toggled.emit(active)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_C:
		set_cockpit_enabled(not cockpit_enabled)
		get_viewport().set_input_as_handled()

func muzzle_world(index: int) -> Vector3:
	return muzzles[clampi(index,0,1)].global_position

func fire() -> void:
	var index: int = maxi(0,ship.last_fired_cannon)%2
	shot_ages[index] = 0.0
	_cockpit_age = 0.0
	_side = -1.0 if index == 0 else 1.0
	# Start on the shot signal, not on a second input check or timer callback.
	apply_visuals()
func clear_motion() -> void:
	_cockpit_age = 10.0
	_cockpit_offset = Vector3.ZERO
	_cockpit_angles = Vector3.ZERO
	transform = Transform3D.IDENTITY
	for i in range(2):
		barrels[i].position = _rest[i]
		housings[i].position = _housing_rest[i]
		housings[i].rotation = Vector3.ZERO
		brackets[i].position = _bracket_rest[i]
		brackets[i].rotation = Vector3.ZERO
func reset_feedback() -> void:
	shot_ages = PackedFloat64Array([10.0,10.0])
	clear_motion()
	for flash in _flashes: flash.visible = false
func _process(delta: float) -> void:
	_cockpit_age += delta
	for i in range(2): shot_ages[i] += delta
	apply_visuals(delta)
func apply_visuals(delta: float = 0.0) -> void:
	var strength: float = settings.intensity
	var envelope := Feedback.cannon_envelope(_cockpit_age,recoil_duration,recovery_duration)
	var vibration := sin(_cockpit_age*155.0)*exp(-_cockpit_age*25.0) if _cockpit_age < recoil_duration+recovery_duration else 0.0
	var offset := Vector3(vibration*_side,vibration*0.7,0)*cockpit_vibration+Vector3.BACK*envelope*cockpit_impulse
	var angles := Vector3(envelope*0.06,vibration*0.08,_side*vibration*0.16)*PI/180.0
	angles = angles.limit_length(deg_to_rad(clampf(maximum_rotation_degrees,0.0,0.5)))*strength
	if delta > 0.0:
		_cockpit_offset = _cockpit_offset.lerp(offset.limit_length(maxf(0.0,maximum_cockpit_displacement))*strength,1.0-exp(-48.0*delta))
		_cockpit_angles = _cockpit_angles.lerp(angles,1.0-exp(-38.0*delta))
	if strength <= 0.0:
		_cockpit_offset = Vector3.ZERO
		_cockpit_angles = Vector3.ZERO
	if envelope == 0.0 and _cockpit_offset.length() < 0.00001: _cockpit_offset = Vector3.ZERO
	if envelope == 0.0 and _cockpit_angles.length() < 0.00001: _cockpit_angles = Vector3.ZERO
	transform = mount.transform*Transform3D(Basis.from_euler(_cockpit_angles),_cockpit_offset)
	for i in range(2):
		var age: float = shot_ages[i]
		var recoil := Feedback.cannon_envelope(age,recoil_duration,recovery_duration)
		var mechanical := sin(age*175.0)*exp(-age*28.0) if age < recoil_duration+recovery_duration else 0.0
		barrels[i].position = _rest[i]+Vector3.BACK*maxf(0.0,barrel_recoil)*recoil*strength
		housings[i].position = _housing_rest[i]+Vector3(0,mechanical*housing_vibration,0)*strength
		housings[i].rotation = Vector3(mechanical*0.002,0,mechanical*0.001)*strength
		brackets[i].position = _bracket_rest[i]+Vector3.BACK*recoil*bracket_reaction*strength
		brackets[i].rotation.x = -recoil*0.002*strength
		_flashes[i].visible = age < 0.045
		_flashes[i].scale = Vector3.ONE*(0.035+0.03*clampf(1.0-age/0.045,0,1))
