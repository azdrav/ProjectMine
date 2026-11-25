extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for kind in ["ammo","missiles","energy","shield"]:
		var visual = load("res://assets/models/pickups/"+kind+".tscn").instantiate()
		root.add_child(visual)
		var count := 0
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB = mesh.global_transform*mesh.get_aabb()
			for i in range(8):
				if bounds.get_endpoint(i).length()+0.035 > 0.6: failures += 1
			for surface in range(mesh.mesh.get_surface_count()): count += mesh.mesh.surface_get_array_index_len(surface)/3
		if count <= 0 or count > 6000: failures += 1
		if not visual.find_children("*","CollisionObject3D",true,false).is_empty(): failures += 1
		if not visual.find_children("*","Light3D",true,false).is_empty(): failures += 1
		if not visual.find_children("*","Label3D",true,false).is_empty(): failures += 1
		print(kind," triangles: ",count)
		visual.queue_free()
	await create_timer(0.2).timeout
	print("Resource models: ","PASS" if failures == 0 else str(failures)+" failures")
	quit(0 if failures == 0 else 1)
