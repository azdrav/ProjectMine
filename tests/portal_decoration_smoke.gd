extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	level.spawn_encounters = false
	root.add_child(level)
	current_scene = level
	await physics_frame
	var examined := 0
	for area in get_nodes_in_group("industrial_areas"):
		for batch in area.get_children():
			if not batch is MultiMeshInstance3D: continue
			var mesh_bounds: AABB = batch.multimesh.mesh.get_aabb()
			for i in range(batch.multimesh.instance_count):
				var pose: Transform3D = batch.multimesh.get_instance_transform(i)
				examined += 1
				if area._overlaps_portal(pose*mesh_bounds.get_center(),mesh_bounds.size,pose.basis):
					push_error("Cosmetic geometry crosses authored doorway: "+str(pose.origin))
					failures += 1
	print("Portal decoration: %s / %d instances" % ["PASS" if failures == 0 else str(failures)+" failures",examined])
	level.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)
