extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var level=load("res://scenes/levels/deep_mine.tscn").instantiate()
	level.spawn_encounters=false
	root.add_child(level);current_scene=level
	await frames(3)
	level.set_physics_process(false)
	var ship=level.get_node("Ship");ship.set_physics_process(false)
	ship.position=Vector3(200,0,0);ship.basis=Basis.IDENTITY;ship.velocity=Vector3.ZERO
	var marker=level.get_node("HUD/TargetBracket")
	var feedback=ship.get_node("Camera3D/VisualOffset")
	feedback.reset_feedback()
	var drone=load("res://scenes/enemies/security_drone.tscn").instantiate()
	drone.position=Vector3(200,0,-18);level.add_child(drone);drone.set_physics_process(false)
	var other=load("res://scenes/enemies/security_drone.tscn").instantiate()
	other.position=Vector3(202.8,0,-17);level.add_child(other);other.set_physics_process(false)
	await frames(4)
	check(marker.target==null,"No permanent enemy tracking before firing")
	var ammo: int=ship.ammo
	ship.fire()
	for projectile in get_nodes_in_group("combat_projectiles"): projectile.queue_free()
	await frames(3)
	check(ship.ammo==ammo-1 and marker.target==drone,"An actual cannon shot selects only the closest contact to cannon aim")
	marker._process(0)
	check(marker.screen_rect.has_area(),"Target produces a projected bounding rectangle")
	check(marker.screen_rect.has_point(marker._view.unproject_position(drone.global_position)),"Box encloses the moving contact")
	check(marker.aim_screen_position().is_equal_approx(marker._view.unproject_position(feedback.aim_point)),"Selection uses the actual cannon crosshair, independent of missile label offset")
	drone.position.x=204;other.position.x=200
	await frames(8)
	check(marker.target==other,"Nearest-to-reticle selection updates between moving enemies")
	# A solid panel blocks the centered contact; no through-wall tracking.
	var cover:=StaticBody3D.new();cover.position=Vector3(200,0,-8)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,5,.25)
	shape.shape=box;cover.add_child(shape);level.add_child(cover)
	await frames(8)
	check(not marker.visible_contact(other) and marker.target!=other,"Wall occlusion removes target")
	cover.free();await frames(2)
	marker.note_shot();await frames(3)
	other.health=0;await frames(8)
	check(marker.target!=other,"Destroyed contact cannot retain a box")
	other.health=other.max_health
	for pose in [Vector3(PI/2,0,.4),Vector3(-PI/2,0,0),Vector3(.7,.3,1.6),Vector3(0,PI,PI)]:
		ship.basis=Basis.from_euler(pose)
		drone.position=ship.position-ship.global_basis.z*18
		other.position=ship.position+ship.global_basis.z*18
		await frames(2);feedback.update_aim_point();marker.note_shot();await frames(2)
		check(marker.target==drone and marker.projected_bounds().has_area(),"Full 6DoF target selection and bounds")
	ship.basis=Basis.IDENTITY
	drone.position=Vector3(200,0,-marker.maximum_distance-2)
	other.position=Vector3(200,0,18)
	await frames(2);marker.note_shot();await frames(2)
	check(marker.target==null,"Behind-camera and out-of-range contacts are excluded")
	drone.position=Vector3(200,0,-18)
	await frames(2);marker.note_shot();await frames(2)
	var before: Transform3D=ship.global_transform;var velocity: Vector3=ship.velocity
	marker.acquire();marker._process(0)
	check(ship.global_transform==before and ship.velocity==velocity,"Readout never modifies ship physics")
	await frames(60)
	check(marker.target==null and marker.screen_rect==Rect2(),"Tracking fades after firing stops")
	marker.note_shot();await frames(2);ship.flight_reset.emit()
	check(marker.target==null and marker._remaining==0,"Restart/load clears transient tracking")
	drone.position=Vector3(220,0,-18)
	for path in ["heavy_guardian","scout_drone"]:
		var variant=load("res://scenes/enemies/"+path+".tscn").instantiate()
		variant.position=Vector3(200,0,-20);level.add_child(variant);variant.set_physics_process(false)
		await frames(3);feedback.update_aim_point();marker.note_shot();await frames(3)
		check(marker.target==variant and marker.projected_bounds().has_area(),"Variant models receive correctly projected bounds: "+path)
		var missiles=ship.get_node("MissileSystem")
		var locked=missiles.target;var progress: float=missiles.progress
		marker.acquire()
		check(missiles.target==locked and missiles.progress==progress,"Cannon sensor does not change missile targeting")
		variant.free();marker.clear()
	print("Cannon target bracket: ","PASS" if failures==0 else str(failures)+" failures")
	if DisplayServer.get_name()!="headless" and failures==0:
		ship.position=Vector3(0,0,5);ship.basis=Basis.IDENTITY
		drone.position=Vector3(0,0,-8);other.hide()
		await frames(2);feedback.reset_feedback();feedback.update_aim_point();marker.note_shot();await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/cannon_target_bracket.png")
	quit(0 if failures==0 else 1)
