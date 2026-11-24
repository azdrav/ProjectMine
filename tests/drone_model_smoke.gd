extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		failures += 1
func no_physics_or_lights(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is Light3D or node is Camera3D: return false
	for child in node.get_children():
		if not no_physics_or_lights(child): return false
	return true
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	for dependency in ResourceLoader.get_dependencies("res://assets/models/enemies/industrial_drone.glb"):
		check(not ".png" in dependency,"Godot model import has no extracted PNG dependencies")
	var scene = load("res://scenes/enemies/security_drone.tscn")
	var first = scene.instantiate()
	var second = scene.instantiate()
	second.position = Vector3(4,0,0)
	level.add_child(first)
	level.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var visual = first.get_node("Visual")
	var other = second.get_node("Visual")
	var model: Node3D = visual.model
	check(no_physics_or_lights(model),"Model has no imported studio lights/cameras or extra colliders")
	check(first.get_node("CollisionShape3D").shape is SphereShape3D and is_equal_approx(first.get_node("CollisionShape3D").shape.radius,0.70),"Original sphere collision radius remains 0.70m")
	check(first.collision_layer == 4 and first.collision_mask == 7,"Enemy collision masks unchanged")
	var meshes := model.find_children("*Mesh","MeshInstance3D",true,false)
	check(meshes.size() == 5,"Five separate rigid component meshes")
	var triangles: int = 0
	var bounds := AABB()
	var initialized := false
	var mapped_materials: int = 0
	for node in meshes:
		var mesh: Mesh = node.mesh
		var box: AABB = (first.global_transform.affine_inverse()*node.global_transform)*mesh.get_aabb()
		bounds = bounds.merge(box) if initialized else box
		initialized = true
		for surface in range(mesh.get_surface_count()):
			triangles += mesh.surface_get_array_index_len(surface)/3
			var material: Material = node.get_active_material(surface)
			if material is StandardMaterial3D and material.albedo_texture:
				mapped_materials += 1
				check(material.albedo_texture.get_width() == 512,"Small embedded albedo atlas imported")
				check(material.roughness_texture != null and material.metallic_texture != null,"glTF metallic/roughness maps imported")
	check(triangles == 4134,"Expected exported triangle count")
	check(bounds.size.is_equal_approx(Vector3(1.46,0.8521895,1.1547488)),"Godot model dimensions match Blender manifest")
	check(model.transform.is_equal_approx(Transform3D.IDENTITY),"Imported origin, scale and orientation require no corrective transform")
	var muzzle: Node3D = model.find_child("Muzzle",true,false)
	var axis: Node3D = model.find_child("OpticalAxis",true,false)
	check((first.global_transform.affine_inverse()*muzzle.global_position).is_equal_approx(Vector3(.235,-.18,-.68)),"Muzzle attachment is forward -Z at correct scale")
	check((first.global_transform.affine_inverse()*axis.global_position).z < -.50,"Optical sensor faces forward")
	check(visual._emitters.size() == 3,"One red and two blue emitter surfaces imported")
	var red: Dictionary = {}
	var other_red: Dictionary = {}
	for emitter in visual._emitters:
		if emitter.optic: red=emitter
	for emitter in other._emitters:
		if emitter.optic: other_red=emitter
	check(not red.is_empty() and not other_red.is_empty(),"Optical emitter can be identified")
	check(red.material != other_red.material,"Feedback materials are local to each robot")
	var body_before: Transform3D = first.global_transform
	visual.hit()
	first.shots_fired += 1
	visual._process(0.016)
	check(visual._flash.visible and visual._weapon.position.z > visual._weapon_rest.z,"Shot counter triggers muzzle flash and recoil without changing AI")
	check(red.material.emission != other_red.material.emission,"Taking damage only flashes the damaged drone")
	check(visual._left.rotation != visual._left_rest,"Subtle propulsion animation")
	check(first.global_transform.is_equal_approx(body_before),"Hover/recoil/gimbals leave physics transform untouched")
	visual._process(0.3)
	check(not visual._flash.visible and red.material.emission == red.emission,"Visual feedback resets")
	check(mapped_materials == 5,"All five components share textured PBR surfaces")
	print("Drone model: %s | %d triangles, bounds %s, 5 components, 3 local emitters" % ["PASS" if failures == 0 else "%d failures" % failures,triangles,bounds.size])
	level.queue_free()
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
