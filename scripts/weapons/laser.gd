extends Node3D
@export var lifetime: float = 2.0
@export var damage: float = 20.0
var team: String = "player"
var shooter: Node3D

const VFX = preload("res://scripts/effects/energy_vfx.gd")
var _head: MeshInstance3D
var traveled: float = 0.0
var visible_trail_length: float = 0.0
@export var trail_seconds: float = 0.020
@export var maximum_trail: float = 2.0
func _ready() -> void:
	add_to_group("combat_projectiles")
	$Beam.mesh=VFX.streak()
	$Beam.material_override=VFX.material(team,false)
	$Beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Beam.visible=false
	_head=VFX.flash(team,.14)
	_head.name="EnergyHead"
	_head.visible=false
	add_child(_head)
var launch_velocity := Vector3.ZERO
var age: float = 0.0
# Cosmetic launch bridge only. Collision sweep, damage and flight stay central.
var visual_muzzle := Vector3.ZERO
var use_visual_muzzle := false
var _visual_checked := false
var _previous_visual := Vector3.ZERO
var _launch_origin := Vector3.ZERO

func _physics_process(delta: float) -> void:
	var destination := global_position + launch_velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 3 if team == "enemy" else 5)
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Node = hit.collider
		var hostile := target.is_in_group("player") if team == "enemy" else target.is_in_group("enemies")
		if hostile and target.has_method("take_damage"):
			if team == "enemy": target.take_damage(damage,shooter,launch_velocity.normalized())
			else: target.take_damage(damage,shooter)
			if team == "player" and is_instance_valid(shooter) and shooter.has_signal("hit_confirmed"):
				shooter.hit_confirmed.emit()
		impact(hit.position, hit.normal,"electrical" if hostile and team=="player" else ("shield" if hostile else "wall"))
		queue_free()
		return
	if use_visual_muzzle and not _visual_checked:
		_visual_checked = true
		_launch_origin = global_position
		var obstruction := PhysicsRayQueryParameters3D.create(global_position,visual_muzzle,1)
		if not get_world_3d().direct_space_state.intersect_ray(obstruction).is_empty(): use_visual_muzzle = false
		_previous_visual = visual_muzzle
	traveled += global_position.distance_to(destination)
	global_position = destination
	var visual_head := global_position
	if use_visual_muzzle:
		visual_head = visual_muzzle.lerp(global_position,smoothstep(0.0,0.065,age+delta))
	visible_trail_length=minf(traveled,minf(maximum_trail,launch_velocity.length()*trail_seconds))
	var bridge_clear := true
	if launch_velocity.length_squared()>0.001:
		# The inherited ship velocity can skew the sweep away from camera -Z.
		# Draw only behind the successful sweep, never ahead of the collision ray.
		var axis := launch_velocity.normalized()
		if use_visual_muzzle and age < 0.065:
			visible_trail_length = minf(visible_trail_length,visual_head.distance_to(_previous_visual))
			axis = (visual_head-_previous_visual).normalized() if visual_head.distance_to(_previous_visual)>0.001 else axis
			if visual_head.distance_to(_previous_visual)>0.001:
				var visual_query := PhysicsRayQueryParameters3D.create(_previous_visual,visual_head,1)
				bridge_clear = get_world_3d().direct_space_state.intersect_ray(visual_query).is_empty()
		_previous_visual = visual_head
		var up := Vector3.FORWARD if absf(axis.dot(Vector3.UP))>.98 else Vector3.UP
		$Beam.global_basis=Basis.looking_at(axis,up) * Basis.from_scale(Vector3(.12,.12,visible_trail_length))
		$Beam.global_position=visual_head
		$Beam.visible=bridge_clear and (not use_visual_muzzle or traveled >= visual_muzzle.distance_to(_launch_origin))
		_head.global_position = visual_head
		_head.visible=$Beam.visible
	age += delta
	if age >= lifetime:
		queue_free()

func impact(point: Vector3, normal: Vector3, kind: String = "wall") -> void:
	VFX.impact(get_tree().current_scene,point,normal,team,kind)
