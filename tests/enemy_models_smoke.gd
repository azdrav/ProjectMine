extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	var meshes_seen := []
	for name in ["heavy_guardian","scout_drone"]:
		var enemy = load("res://scenes/enemies/"+name+".tscn").instantiate()
		enemy.position = Vector3(0,0,-4)
		level.add_child(enemy)
		enemy.set_physics_process(false)
		var model: Node3D = enemy.visual.model
		for dependency in ResourceLoader.get_dependencies("res://assets/models/enemies/"+name+".glb"):
			check(not ".png" in dependency,"Self-contained GLB without extracted texture dependencies")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/enemies/"+name+"_manifest.json"))
		check(manifest.mesh_components == 5 and manifest.triangles < 4200,"Five reusable components within existing triangle budget")
		check(manifest.vertex_radius_m < enemy.hull_radius-0.02,"New geometry fits unchanged gameplay hull with animation clearance")
		var triangles := 0
		for mesh in model.find_children("*Mesh","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				triangles += mesh.mesh.surface_get_array_index_len(surface)/3
				var material = mesh.get_active_material(surface)
				if material.albedo_texture: check(material.albedo_texture.get_width() == 512,"Shared modest industrial atlas")
		check(triangles == int(manifest.triangles),"Imported mesh matches generated source")
		var component = model.find_child("Chassis",true,false).get_child(0)
		meshes_seen.append(component.mesh)
		var muzzle = model.find_child("Muzzle",true,false)
		var p: Array = manifest.muzzle_godot
		check((model.global_transform.affine_inverse()*muzzle.global_position).is_equal_approx(Vector3(p[0],p[1],p[2])),"Flash attachment matches modeled barrel")
		var saved_transform: Transform3D = enemy.global_transform
		enemy.visual.fire_feedback()
		enemy.visual._process(.016)
		check(enemy.global_transform.is_equal_approx(saved_transform),"Visual recoil leaves physics transform unchanged")
		var wreck = load("res://scripts/effects/drone_wreckage.gd").new()
		level.add_child(wreck)
		wreck.build(model,enemy.global_position,Vector3.ZERO)
		check(wreck.bodies.size() == (5 if name == "heavy_guardian" else 4),"Destruction reuses actual visible variant components")
		for body in wreck.bodies: check(body.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Debris physics has no inherited scaling")
		enemy.queue_free()
	check(meshes_seen[0] != meshes_seen[1],"Variants use genuinely separate geometry")
	var service = load("res://assets/models/enemies/maintenance_bot.tscn").instantiate()
	level.add_child(service)
	check(not service.is_in_group("enemies") and not service is CollisionObject3D,"Service prefab adds no combat or navigation behavior")
	check(service.find_child("Weapon",true,false) != null,"Service tool assembly available for future animation")
	level.queue_free()
	await create_timer(.2).timeout
	print("Enemy models: ","PASS" if failures == 0 else str(failures)+" failures")
	quit(0 if failures == 0 else 1)
