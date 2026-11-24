extends Node3D
const VFX = preload("res://scripts/effects/energy_vfx.gd")
## Imported rigid components; animation and feedback never move the collision body.
var _time: float = 0.0
var _hit_time: float = 0.0
var _fire_time: float = 0.0
var _last_shot_count: int = 0
var _left: Node3D
var _right: Node3D
var _weapon: Node3D
var _left_rest := Vector3.ZERO
var _right_rest := Vector3.ZERO
var _weapon_rest := Vector3.ZERO
var _flash: MeshInstance3D
var _emitters: Array[Dictionary] = []
@onready var model: Node3D = $Model
@onready var actor: Node = get_parent()

func _ready() -> void:
	_left = model.find_child("PropulsionLeft",true,false) as Node3D
	_right = model.find_child("PropulsionRight",true,false) as Node3D
	_weapon = model.find_child("Weapon",true,false) as Node3D
	var muzzle := model.find_child("Muzzle",true,false) as Node3D
	if not _left or not _right or not _weapon or not muzzle:
		push_error("Industrial drone GLB is missing its rigid-component attachment nodes.")
		set_process(false)
		return
	_left_rest = _left.rotation
	_right_rest = _right.rotation
	_weapon_rest = _weapon.position
	_localize_emission(model)
	_flash = VFX.flash("enemy",0.09)
	_flash.name="MuzzleFlash"
	_flash.visible=false
	muzzle.add_child(_flash)
	var shot_count: Variant = actor.get("shots_fired")
	_last_shot_count = shot_count if shot_count is int else 0

func _localize_emission(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D and original.emission_enabled:
				# Do not flash/pulse the material shared by every imported robot.
				var material := original.duplicate() as StandardMaterial3D
				node.set_surface_override_material(surface,material)
				_emitters.append({"material":material,"albedo":material.albedo_color,"emission":material.emission,"energy":material.emission_energy_multiplier,"optic":original.resource_name.contains("Optic")})
	for child in node.get_children(): _localize_emission(child)

func hit() -> void:
	_hit_time = 0.15

func fire_feedback() -> void:
	_fire_time = 0.10

func _process(delta: float) -> void:
	_time += delta
	_hit_time = maxf(0.0,_hit_time-delta)
	_fire_time = maxf(0.0,_fire_time-delta)
	var shot_count: Variant = actor.get("shots_fired")
	if shot_count is int and shot_count != _last_shot_count:
		_last_shot_count = shot_count
		fire_feedback()
	# Keep the original hover amplitude; only the rendered hierarchy is animated.
	position.y = sin(_time*2.2)*0.035
	_left.rotation = _left_rest + Vector3(sin(_time*2.0)*0.018,0,sin(_time*1.4)*0.008)
	_right.rotation = _right_rest + Vector3(sin(_time*2.0+0.7)*0.018,0,-sin(_time*1.4)*0.008)
	_weapon.position = _weapon_rest + Vector3(0,0,0.022*_fire_time/0.10)
	_flash.visible = _fire_time > 0.055
	_flash.scale = Vector3.ONE * (0.05+_fire_time*0.4)
	for emitter in _emitters:
		var material: StandardMaterial3D = emitter.material
		if emitter.optic:
			material.albedo_color = Color(1.0,0.35,0.16) if _hit_time>0 else Color(1.0,0.08,0.02) if actor.state in [actor.State.ALERT,actor.State.APPROACH,actor.State.ATTACK] else emitter.albedo
			material.emission = Color(1.0,0.35,0.16) if _hit_time>0 else Color(1.0,0.08,0.02) if actor.state in [actor.State.ALERT,actor.State.APPROACH,actor.State.ATTACK] else emitter.emission
			material.emission_energy_multiplier = emitter.energy*(3.0 if _hit_time>0 else 2.5 if actor.state in [actor.State.ALERT,actor.State.APPROACH,actor.State.ATTACK] else 1.0)
		else:
			material.emission_energy_multiplier = emitter.energy*(1.0+sin(_time*4.0)*0.06)
