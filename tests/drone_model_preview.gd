extends SceneTree
## Native Compatibility-renderer asset review in the actual industrial corridor.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real display is required for the model preview.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled = false
	ship.position=Vector3(0.75,0.80,-29.6)
	ship.basis=Basis.looking_at(Vector3(0,0.05,-26)-ship.position,Vector3.UP)
	ship.camera.fov=48
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.engine_audio.stop()
	var drone = get_nodes_in_group("enemies")[0]
	drone.position=Vector3(0,0,-26)
	drone.basis=Basis.IDENTITY
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var output := "/tmp/projectmine-drone-godot.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("DRONE PREVIEW ",output)
	drone.shots_fired += 1
	drone.visual.hit()
	await create_timer(.025).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.trim_suffix(".png")+"-feedback.png")
	level.queue_free()
	await create_timer(.15).timeout
	quit()
