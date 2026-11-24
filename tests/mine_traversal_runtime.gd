extends SceneTree
## Autopilot fixture uses the unchanged controller's forward input and braking.
var render_frames: int = 0
func _process(_delta: float) -> bool:
	render_frames+=1
	return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	var ship = level.get_node("Ship")
	ship.shield=10000 # Fixture survival only; both enemies retain live AI.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await create_timer(.5).timeout
	var targets := [Vector3(0,0,-44),Vector3(0,34,-44),Vector3(0,34,-52),Vector3(0,44,-72),Vector3(0,44,-80)]
	var report: Array = []
	var failed: bool = false
	for index in range(targets.size()):
		var target: Vector3=targets[index]
		var direction: Vector3=(target-ship.position).normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.98 else Vector3.UP
		ship.basis=Basis.looking_at(direction,up)*Basis(Vector3.FORWARD,.3 if index%2 else -.3)
		Input.action_press("move_forward")
		var begin := Time.get_ticks_usec()
		var begin_frame := render_frames
		var count: int = 0
		while Time.get_ticks_usec()-begin<10000000:
			await physics_frame
			count+=1
			var remaining: float=(target-ship.position).dot(direction)
			var brake_distance: float=pow(maxf(0.0,ship.velocity.dot(direction)),2)/(2*ship.deceleration)
			if remaining<brake_distance+.15: Input.action_release("move_forward")
			if not Input.is_action_pressed("move_forward") and ship.velocity.length()<.02: break
		var error: float=ship.position.distance_to(target)
		if error>1.0:
			push_error("Traversal failed near "+str(target)+"; error "+str(error))
			failed=true
		var result := {"target":str(target),"error_m":error,"physics_steps":count,"mean_fps":float(render_frames-begin_frame)*1000000/maxi(1,Time.get_ticks_usec()-begin)}
		report.append(result)
		print("TRAVERSE ",JSON.stringify(result))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/projectmine-05-traversal-%d.png"%index)
	Input.action_release("move_forward")
	var result := {"waypoints":report,"static_impacts":ship.get_node("Audio").impact_events,"shield_damage":10000-ship.shield,"enemies_remaining":level.enemies_remaining()}
	print("MINE TRAVERSAL ",JSON.stringify(result))
	var file := FileAccess.open("/tmp/projectmine-05-traversal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	level.queue_free()
	await create_timer(.2).timeout
	quit(1 if failed else 0)
