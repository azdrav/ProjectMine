extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	root.add_child(level)
	current_scene = level
	await frames(4)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	var weapons = ship.get_node("Camera3D/WeaponEffects")
	var presentation = ship.get_node("CockpitPresentation")
	var feedback = ship.get_node("Camera3D/VisualOffset")
	var hud = level.get_node("HUD")
	var dashboard = hud.dashboard
	check(weapons.cockpit_enabled and dashboard.visible,"Cockpit enabled with native instruments")
	check(not hud.get_node("ProximityIndicator").visible and not hud.status.text.contains("SHIELD"),"Cockpit avoids duplicate shield/energy/proximity HUD")
	check(level.get_node("Mission").hud.anchor_top == 0.0,"Objectives move above lower cockpit")
	ship.shield = 23
	ship.energy = 61
	dashboard.update_instruments()
	check(dashboard.shield_bar.value == 23 and dashboard.energy_bar.value == 61 and dashboard.shield_value.text.contains("023"),"Native instruments read live resources")
	check(dashboard.warning.text.contains("SHIELD LOW"),"Low shield warning uses actual shield")
	ship.position = Vector3(3,0,-26)
	await frames(3)
	var sensor = ship.get_node("Proximity")
	sensor.scan(1.0)
	dashboard.update_instruments()
	check(dashboard.scope.sensor == sensor and sensor.readings.RIGHT.severity > 0,"Central scope reads real six-axis sonar")
	var pose: Transform3D = ship.global_transform
	var velocity: Vector3 = ship.velocity
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	weapons._unhandled_key_input(key)
	hud._process(0.0)
	dashboard._process(0.0)
	presentation._sync()
	check(not weapons.cockpit_enabled and not presentation.image.visible and not dashboard.visible,"C hides complete 3D/2D cockpit")
	check(hud.get_node("ProximityIndicator").visible and hud.status.text.contains("SHIELD") and hud.status.text.contains("ENERGY"),"Off mode restores original resource HUD")
	check(level.get_node("Mission").hud.anchor_top == 1.0,"Off mode restores objective placement")
	key.echo = true
	weapons._unhandled_key_input(key)
	check(not weapons.cockpit_enabled,"Held C does not flicker")
	key.echo = false
	weapons._unhandled_key_input(key)
	check(ship.global_transform == pose and ship.velocity == velocity,"Toggle never affects flight state")
	var triangles := 0
	var materials := {}
	for mesh in weapons.model.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh is ArrayMesh: continue
		for surface in range(mesh.mesh.get_surface_count()):
			triangles += mesh.mesh.surface_get_array_index_len(surface)/3
			var material: Material = mesh.get_active_material(surface)
			materials[material.get_instance_id()] = true
			if material is StandardMaterial3D and material.albedo_texture: check(material.albedo_texture.get_width() <= 512,"Modest cockpit atlas")
	check(triangles < 16000 and materials.size() <= 3,"Batched optimized 3D assets and shared materials")
	check(weapons.model.find_children("*","CollisionObject3D",true,false).is_empty(),"Visual cockpit adds no physics geometry")
	check(presentation.viewport.world_3d == ship.get_world_3d() and presentation.camera.cull_mask == 1<<19,"Transparent cockpit pass excludes level geometry")
	check((feedback.render_camera.cull_mask & (1<<19)) == 0,"Main camera does not double-render cockpit")
	ship.position = Vector3(100,0,0)
	ship.shield = 100
	for euler in [Vector3.ZERO,Vector3(PI/2,0,0),Vector3(0,PI,PI),Vector3(0.7,0.4,1.2)]:
		ship.basis = Basis.from_euler(euler)
		weapons.reset_feedback()
		var index: int = (ship.last_fired_cannon+1)%2
		var muzzle: Vector3 = weapons.muzzle_world(index)
		ship.fire()
		var laser = get_nodes_in_group("combat_projectiles")[-1]
		check(laser.use_visual_muzzle and laser.visual_muzzle.distance_to(muzzle) < 0.001,"Cosmetic launch starts at selected GLB muzzle in every orientation")
		check(laser.global_transform.is_equal_approx(ship.camera.global_transform) and laser.launch_velocity.is_equal_approx(-ship.global_basis.z*100+ship.velocity),"Muzzle rendering leaves collision trajectory unchanged")
		check(weapons._flashes[index].get_parent() == weapons.muzzles[index],"Muzzle flash follows recoiling barrel attachment")
		laser.free()
	# Cosmetic launch converges to the unchanged swept projectile; never changes damage physics.
	ship.basis = Basis.IDENTITY
	ship.velocity = Vector3.ZERO
	weapons.reset_feedback()
	ship.fire()
	var tracer = get_nodes_in_group("combat_projectiles")[-1]
	tracer.set_physics_process(false)
	tracer._physics_process(0.016)
	check(tracer.global_position.distance_to(ship.position+Vector3(0,0,-1.6)) < 0.001,"First projectile physics sweep remains central")
	check(tracer.get_node("Beam").global_position.distance_to(tracer.global_position) > 0.01,"Initial tracer visually bridges from cannon attachment")
	for i in range(5): tracer._physics_process(0.016)
	check(tracer.get_node("Beam").global_position.distance_to(tracer.global_position) < 0.001,"Tracer converges to actual aim line after launch")
	tracer.free()
	ship.take_damage(10,null,Vector3.LEFT)
	check(dashboard._flicker > 0.0 and feedback.channels.has("shield"),"Damage retains shield shake and brief dashboard flicker")
	await frames(25)
	check(dashboard._flicker == 0.0,"Damage flicker settles")
	print("Industrial cockpit: %s | %d triangles / %d materials" % ["PASS" if failures == 0 else str(failures)+" failures",triangles,materials.size()])
	level.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)
