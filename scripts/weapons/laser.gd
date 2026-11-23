extends Node3D
@export var lifetime: float = 2.0
var launch_velocity := Vector3.ZERO
var age: float = 0.0

func _physics_process(delta: float) -> void:
	var destination := global_position + launch_velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impact(hit.position, hit.normal)
		queue_free()
		return
	global_position = destination
	age += delta
	if age >= lifetime:
		queue_free()

func impact(point: Vector3, normal: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.4, 1.0, 0.85)
	flash.material_override = material
	get_tree().current_scene.add_child(flash)
	flash.global_position = point + normal * 0.06
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.0, 0.10)
	tween.tween_property(flash, "scale", Vector3.ZERO, 0.08)
	tween.tween_callback(flash.queue_free)
