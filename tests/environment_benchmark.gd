extends SceneTree
## Native 1080p comparison of all functional areas. --reference disables only the 0.5 extension.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real display/GPU is required for this benchmark.")
		quit(1)
		return
	# Disable project canvas scaling so viewport pixels equal physical display pixels.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	var baseline := "--reference" in OS.get_cmdline_user_args()
	for property in level.get_property_list():
		if property.name == "extended_industrial": level.set("extended_industrial",not baseline)
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.engine_audio.stop()
	var views := {
		"launch":Transform3D(Basis.IDENTITY,Vector3(0,0,5)),
		"lower_chamber":Transform3D(Basis(Vector3.UP,-.45),Vector3(0,0,-40)),
		"vertical":Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,15,-44)),
		"upper_chamber":Transform3D(Basis.IDENTITY,Vector3(0,34,-42)),
		"incline":Transform3D(Basis(Vector3.RIGHT,atan(.5)),Vector3(0,38,-60)),
		"reactor":Transform3D(Basis(Vector3.UP,.45),Vector3(0,44,-77))}

	await process_frame
	await process_frame
	print("BENCH VIEWPORT window=",DisplayServer.window_get_size()," root=",root.size," texture=",root.get_texture().get_size()," scale=",root.content_scale_factor," 3D=",root.scaling_3d_scale)
	var results: Dictionary = {"baseline":baseline,"resolution":str(root.get_texture().get_size()),"driver":RenderingServer.get_video_adapter_name(),"vsync":"disabled","views":{}}
	for view in views:
		ship.global_transform = views[view]
		var warm_until := Time.get_ticks_msec()+800
		while Time.get_ticks_msec()<warm_until: await process_frame
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture="):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")+"-"+view+".png")
		var times: Array[float] = []
		var draw_calls: float = 0.0
		var primitives: float = 0.0
		var finish := Time.get_ticks_usec()+2000000
		var previous := Time.get_ticks_usec()
		while Time.get_ticks_usec()<finish:
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now-previous)/1000.0)
			previous = now
			draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var total: float = 0.0
		for time in times: total+=time
		times.sort()
		var result := {"fps":1000.0/(total/times.size()),"mean_ms":total/times.size(),"p95_ms":times[mini(times.size()-1,int(times.size()*0.95))],"draw_calls":draw_calls/times.size(),"primitives":primitives/times.size()}
		results.views[view] = result
		print("VISUAL BENCH ",view," ",JSON.stringify(result))
	var output := "/tmp/projectmine-environment-benchmark.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print("BENCHMARK SAVED ",output," resolution=",results.resolution)
	level.queue_free()
	await create_timer(0.15).timeout
	quit()
