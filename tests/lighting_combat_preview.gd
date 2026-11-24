extends SceneTree
## Native-renderer review; poses and paused AI apply only to this inspection fixture.
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled=false
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.engine_audio.stop()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var lamps=ship.get_node("Headlights")
	for view in ["horizontal","vertical"]:
		ship.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,0,-24)) if view=="horizontal" else Transform3D(Basis.from_euler(Vector3(PI/2,0,.35)),Vector3(0,20,-44))
		for enabled in [false,true]:
			lamps.enabled=enabled
			await create_timer(.4).timeout
			await capture("/tmp/projectmine-04c-"+view+("-on" if enabled else "-off")+".png")
	ship.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,0,-24))
	var drone = get_nodes_in_group("enemies")[0]
	drone.position=Vector3(0,0,-34)
	drone.basis=Basis(Vector3.UP,PI)
	await create_timer(.4).timeout
	drone.fire()
	await create_timer(.08).timeout
	await capture("/tmp/projectmine-04c-enemy.png")
	ship.fire()
	await physics_frame
	await capture("/tmp/projectmine-04c-weapons.png")
	await create_timer(.085).timeout
	await capture("/tmp/projectmine-04c-impact.png")
	var observer := Camera3D.new()
	level.add_child(observer)
	observer.position=Vector3(3,1,-30)
	observer.fov=110
	observer.look_at(Vector3(0,0,-30))
	observer.current=true
	for projectile in get_nodes_in_group("combat_projectiles"): projectile.queue_free()
	await process_frame
	ship.fire()
	drone.fire()
	# Freeze a real 40ms swept step for a reliable side-on trail inspection.
	for projectile in get_nodes_in_group("combat_projectiles"):
		projectile.set_physics_process(false)
		projectile._physics_process(.04)
	await capture("/tmp/projectmine-04c-trails.png")
	level.queue_free()
	await create_timer(.15).timeout
	quit()
