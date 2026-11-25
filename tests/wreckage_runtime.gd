extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.position = Vector3(0,0,-26)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(6):
		var enemy = load("res://scenes/enemies/security_drone.tscn").instantiate()
		enemy.position = Vector3(-1.5 if i%2==0 else 1.5,0,-34-i*1.6)
		level.add_child(enemy)
		enemy.set_physics_process(false)
	await create_timer(0.6).timeout
	for enemy in get_nodes_in_group("enemies"): enemy.take_damage(999,ship)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine112-wreckage.png")
	var times: Array[float] = []
	var end := Time.get_ticks_usec()+6000000
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_usec()<end:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-previous)/1000.0)
		previous = now
	var sum := 0.0
	for time in times: sum += time
	times.sort()
	var bodies := 0
	for group in get_nodes_in_group("drone_wreckage"): bodies += group.bodies.size()
	var report := {"mean_fps":1000*times.size()/sum,"p95_ms":times[int(times.size()*0.95)],"groups":get_nodes_in_group("drone_wreckage").size(),"bodies":bodies,"gpu":RenderingServer.get_video_adapter_name(),"resolution":str(root.size)}
	var file := FileAccess.open("/tmp/projectmine112-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("WRECKAGE RUNTIME ",report)
	level.queue_free()
	await create_timer(0.4).timeout
	quit()
