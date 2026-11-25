extends Node3D
## Shared imported meshes, simplified wall-only hulls, bounded simulated groups.
@export var lifetime: float = 45.0
@export var maximum_groups: int = 4
@export_range(0,5) var quality: int = 5
var bodies: Array[RigidBody3D] = []
var pieces: Array[MeshInstance3D] = []
var fade_materials: Array[StandardMaterial3D] = []
var age := 0.0
var fading := false
var fade_age := 0.0
func build(model: Node3D, center: Vector3, inherited: Vector3) -> void:
	add_to_group("drone_wreckage")
	for name in ["Chassis","PropulsionLeft","PropulsionRight","Weapon","Optics"].slice(0,quality):
		var component := model.find_child(name,true,false) as Node3D
		if component == null: continue
		for original in component.get_children():
			if not original is MeshInstance3D or not original.mesh is ArrayMesh or not original.is_visible_in_tree(): continue
			var body := RigidBody3D.new()
			body.gravity_scale = 0
			body.collision_layer = 0
			body.collision_mask = 1
			body.linear_damp = 1.4
			body.angular_damp = 1.8
			body.continuous_cd = true
			var mesh := MeshInstance3D.new()
			mesh.mesh = original.mesh
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in range(mesh.mesh.get_surface_count()):
				var material: Material = original.get_active_material(surface)
				if material is StandardMaterial3D and material.emission_enabled:
					var dark := material.duplicate() as StandardMaterial3D
					dark.emission_energy_multiplier = 0.08
					mesh.set_surface_override_material(surface,dark)
			body.add_child(mesh)
			var bounds: AABB = original.mesh.get_aabb()
			var model_scale: Vector3 = original.global_basis.get_scale()
			mesh.scale = model_scale
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = bounds.size.max(Vector3.ONE*0.04)*model_scale*0.85
			collider.shape = shape
			collider.position = bounds.get_center()*model_scale
			body.add_child(collider)
			add_child(body)
			body.global_transform = Transform3D(original.global_basis.orthonormalized(),original.global_position)
			var outward := (body.global_position-center).normalized()
			if outward.length_squared()<0.1: outward = Vector3.UP
			# Bodies starting next to a wall must not inherit penetrating shapes.
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = body.global_transform*Transform3D(Basis.IDENTITY,bounds.get_center()*model_scale)
			query.collision_mask = 1
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				body.freeze = true
				body.collision_mask = 0
			body.linear_velocity = inherited*0.15
			if not body.freeze: body.apply_central_impulse(outward*body.mass*randf_range(2.0,3.8))
			body.angular_velocity = Vector3(randf_range(-2,2),randf_range(-2,2),randf_range(-2,2))
			bodies.append(body)
			pieces.append(mesh)
	var active := []
	for group in get_tree().get_nodes_in_group("drone_wreckage"):
		if not group.fading: active.append(group)
	while active.size()>maxi(1,maximum_groups): active.pop_front().retire()
func retire() -> void:
	if fading: return
	fading = true
	for piece in pieces:
		for surface in range(piece.mesh.get_surface_count()):
			var original: Material = piece.get_active_material(surface)
			if original is StandardMaterial3D:
				var fading_material := original.duplicate() as StandardMaterial3D
				fading_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				piece.set_surface_override_material(surface,fading_material)
				fade_materials.append(fading_material)
	for body in bodies:
		body.freeze = true
		body.collision_mask = 0
func _process(delta: float) -> void:
	age += delta
	if age >= lifetime: retire()
	if fading:
		fade_age += delta
		for material in fade_materials: material.albedo_color.a = 1.0-clampf(fade_age/1.5,0,1)
		if fade_age >= 1.5: queue_free()
	elif age > 6:
		for body in bodies: body.freeze = true
