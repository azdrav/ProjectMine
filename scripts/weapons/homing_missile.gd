extends Node3D
const Effects = preload("res://scripts/effects/combat_effects.gd")
var target: Node3D
var shooter: CharacterBody3D
var direction := Vector3.FORWARD
@export var max_speed: float = 30.0
@export var acceleration: float = 20.0
@export var turn_rate_degrees: float = 110.0
var speed := 8.0
var damage := 60.0
var age := 0.0
var lost_time := 0.0
var cast: ShapeCast3D
var trail: MeshInstance3D
func _ready() -> void:
	add_to_group("combat_projectiles")
	add_to_group("guided_missiles")
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.085
	mesh.height = 0.45
	mesh.radial_segments = 10
	body.mesh = mesh
	body.rotation.x = PI/2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33,0.34,0.29)
	body.material_override = material
	add_child(body)
	trail = MeshInstance3D.new()
	var exhaust := CylinderMesh.new()
	exhaust.top_radius = 0.055
	exhaust.bottom_radius = 0.015
	exhaust.height = 0.6
	exhaust.radial_segments = 6
	trail.mesh = exhaust
	trail.rotation.x = PI/2
	trail.position.z = 0.43
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1,0.35,0.04)
	trail.material_override = glow
	add_child(trail)
	cast = ShapeCast3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.10
	cast.shape = shape
	cast.collision_mask = 5
	cast.enabled = false
	if is_instance_valid(shooter): cast.add_exception(shooter)
	add_child(cast)
func _physics_process(delta: float) -> void:
	age += delta
	if age > 5.0:
		queue_free()
		return
	if is_instance_valid(target) and target.get("health") != null and target.health > 0:
		var offset := target.global_position-global_position
		if offset.length_squared() > 0.001:
			var desired := offset.normalized()
			var angle := direction.angle_to(desired)
			if angle > 0.0001: direction = direction.slerp(desired,minf(1.0,deg_to_rad(turn_rate_degrees)*delta/angle)).normalized()
	else:
		lost_time += delta
		if lost_time > 0.8:
			queue_free()
			return
	speed = move_toward(speed,max_speed,acceleration*delta)
	var movement := direction*speed*delta
	cast.target_position = global_basis.inverse()*movement
	cast.force_shapecast_update()
	if cast.is_colliding():
		var victim = cast.get_collider(0)
		var point := cast.get_collision_point(0)
		var destroyed := false
		if is_instance_valid(victim) and victim.is_in_group("enemies"):
			victim.take_damage(damage,shooter)
			destroyed = victim.health <= 0
			if is_instance_valid(shooter): shooter.hit_confirmed.emit()
		if not destroyed: Effects.destruction(get_tree().current_scene,point)
		if is_instance_valid(shooter) and shooter.global_position.distance_to(point)<12:
			shooter.get_node("Camera3D/VisualOffset").add_impulse("missile",0.006,0.18,(shooter.global_position-point).normalized(),true)
		queue_free()
		return
	global_position += movement
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP))>0.98 else Vector3.UP
	global_basis = Basis.looking_at(direction,up)
	trail.scale.y = 0.8+0.15*sin(age*59)
