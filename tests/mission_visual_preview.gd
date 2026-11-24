extends SceneTree
## Real Compatibility screenshots of authored geometry, for visual inspection.
func _initialize() -> void: call_deferred("run")
func capture(camera: Camera3D, point: Vector3, target: Vector3, path: String) -> void:
	camera.position = point
	camera.look_at(target)
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	level.get_node("HUD").visible = false
	var camera := Camera3D.new()
	camera.fov = 55
	level.add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await capture(camera,Vector3(-4.2,0.4,-40.2),Vector3(-5,0.1,-44),"/tmp/projectmine_terminal.png")
	await capture(camera,Vector3(0,39,-62),Vector3(0,44,-72),"/tmp/projectmine_door_closed.png")
	var door = level.get_node("Mission").door
	level.get_node("Mission").generator_active = true
	level.get_node("Mission").apply_power()
	level.get_node("Mission/DoorSign").text = "SECTOR B / OPENING"
	door.request_open()
	await create_timer(1.2).timeout
	await capture(camera,Vector3(0,39,-62),Vector3(0,44,-72),"/tmp/projectmine_door_opening.png")
	level.queue_free()
	await create_timer(0.2).timeout
	quit()
