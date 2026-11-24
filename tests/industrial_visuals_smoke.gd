extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		failures += 1
func physics_signature(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is CollisionShape3D:
		var shape: Shape3D = node.shape
		var geometry := ""
		if shape is SphereShape3D: geometry=str(shape.radius)
		elif shape is BoxShape3D: geometry=str(shape.size)
		elif shape is ConvexPolygonShape3D: geometry=str(shape.points)
		var body: CollisionObject3D = node.get_parent()
		result.append(str(node.global_transform)+shape.get_class()+geometry+str(body.collision_layer)+str(body.collision_mask))
	for child in node.get_children(): result.append_array(physics_signature(child))
	return result
func has_physics(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is RayCast3D: return true
	for child in node.get_children():
		if has_physics(child): return true
	return false
func run() -> void:
	var scene = load("res://scenes/levels/test_mine.tscn")
	var baseline = scene.instantiate()
	baseline.spawn_encounters = false
	baseline.industrial_upgrade = false
	root.add_child(baseline)
	current_scene = baseline
	await physics_frame
	var signature := physics_signature(baseline)
	baseline.queue_free()
	await physics_frame
	await physics_frame
	var upgraded = scene.instantiate()
	upgraded.spawn_encounters = false
	upgraded.industrial_upgrade = true
	root.add_child(upgraded)
	current_scene = upgraded
	await physics_frame
	await physics_frame
	check(signature == physics_signature(upgraded),"All original collider transforms, dimensions and layers remain identical")
	var section = upgraded.get_node("IndustrialSection")
	check(not has_physics(section),"Industrial decoration contains no collision objects, shapes or sensors")
	var batches: int = 0
	var lights: int = 0
	# Existing sphere camera centers can move out to +/-3.45m inside an 8m corridor.
	var camera_volume := AABB(Vector3(-3.45,-3.45,-37.5),Vector3(6.9,6.9,23))
	for child in section.get_children():
		if child is MultiMeshInstance3D:
			batches += 1
			var bounds: AABB = child.multimesh.mesh.get_aabb()
			for index in range(child.multimesh.instance_count):
				var instance: Transform3D = section._batches[str(child.name).trim_prefix("Batch_")][index]
				check(not camera_volume.intersects(instance*bounds),"Decorative instance stays outside the camera's navigable volume: "+child.name)
		elif child is OmniLight3D:
			lights += 1
			check(not child.shadow_enabled,"No real-time shadow maps on maintenance fixtures")
	check(batches <= 12 and section.decoration_instances > 200,"Repeated details are batched")
	check(lights == 3,"Only three additional shadowless fixture lights")
	var environment = upgraded.get_node("IndustrialEnvironment")
	check(not has_physics(environment),"Full-mine extension contains no physics nodes")
	check(environment.areas.size()==6,"Four chambers, vertical shaft and angled passage upgraded")
	var source_bounds: Array[AABB] = []
	for body in upgraded.get_children():
		if body is StaticBody3D:
			for visual in body.get_children():
				if visual is MeshInstance3D and visual.mesh is BoxMesh:
					check(not visual.visible,"Original shell visuals are replaced only for rendering")
					source_bounds.append(visual.global_transform*visual.mesh.get_aabb())
	var shell_count: int = 0
	for transforms in environment.shell_batches.values():
		for pose in transforms:
			var bounds: AABB=environment.global_transform*pose*AABB(-Vector3.ONE*.5,Vector3.ONE)
			var found: int = -1
			for index in range(source_bounds.size()):
				if source_bounds[index].is_equal_approx(bounds):
					found=index
					break
			check(found>=0,"Batched shell keeps exact original visual bounds")
			if found>=0: source_bounds.remove_at(found)
			shell_count+=1
	check(source_bounds.is_empty() and shell_count==environment.shell_source_count,"No missing or duplicated shell boxes")
	print("Static shell: %d unchanged boxes / %d spatial-material batches"%[shell_count,environment.shell_batches.size()])
	var extended_instances: int = 0
	var extended_batches: int = 0
	for area in environment.areas:
		var protected: AABB
		if area.corridor:
			protected=AABB(Vector3(-3.45,-3.45,-area.dimensions.z+2.5),Vector3(6.9,6.9,area.dimensions.z-5))
		else:
			protected=AABB(-area.dimensions*.5+Vector3.ONE*.55,area.dimensions-Vector3.ONE*1.1)
		for child in area.get_children():
			check(not child is Light3D,"Extension reuses existing lights rather than adding more")
			if child is MultiMeshInstance3D:
				extended_batches+=1
				var bounds: AABB=child.multimesh.mesh.get_aabb()
				for index in range(child.multimesh.instance_count):
					var local_pose: Transform3D=area.frame.affine_inverse()*area._batches[str(child.name).trim_prefix("Batch_")][index]
					check(not protected.intersects(local_pose*bounds),"New decoration stays outside navigable camera volume: "+area.name+"/"+child.name+" "+str(local_pose*bounds))
		extended_instances+=area.decoration_instances
	check(extended_batches<=60 and extended_instances>500,"Full mine uses bounded material batches")
	print("Extended environment: %d decorations / %d batches; original physics signature preserved"%[extended_instances,extended_batches])
	await create_timer(0.55).timeout
	check(upgraded.get_node("HUD")._fps_label.text.begins_with("FPS"),"FPS counter is active")
	print("Industrial visuals: %s | %d decorations, %d batches, %d lights; collision signature unchanged" % ["PASS" if failures == 0 else "%d failures" % failures,section.decoration_instances,batches,lights])
	upgraded.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
