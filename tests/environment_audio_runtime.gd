extends SceneTree
## Audible route review and isolated acoustic tails. Fixtures never change production physics.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters=false
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var audio = level.get_node("EnvironmentAudio")
	audio.random_seed=613
	audio._rng.seed=613
	audio._event_wait=999
	if "--occlusion" in OS.get_cmdline_user_args():
		await occlusion_review(level,ship,audio)
		return
	var mute_ambience := "--tails" in OS.get_cmdline_user_args()
	if mute_ambience: audio.maximum_loops=0
	print("ACOUSTIC STAGE recorder setup ",Time.get_ticks_msec())
	await create_timer(3).timeout
	var views := [["chamber",Vector3(0,0,5)],["concrete",Vector3(0,0,-26)],["shaft",Vector3(0,18,-44)],["steel",Vector3(0,39,-62)],["open",Vector3(200,0,0)]]
	var results: Array = []
	for view in views:
		ship.position=view[1]
		audio._tick()
		await create_timer(2.4).timeout
		print("ACOUSTIC STAGE ",view[0]," shot ",Time.get_ticks_msec())
		ship.fire()
		await create_timer(.3).timeout
		print("ACOUSTIC STAGE ",view[0]," tail ",Time.get_ticks_msec())
		await create_timer(1.7).timeout
		results.append({"area":view[0],"wet":audio.current.wet,"room_size":audio.current.room_size,"damping":audio.current.damping})
	ship.position=Vector3(0,0,-26)
	if not mute_ambience:
		ship.position=Vector3(0,18,-44)
		audio._tick()
		await create_timer(1.5).timeout
		audio.trigger_event()
		print("ACOUSTIC STAGE rapid burst ",Time.get_ticks_msec())
		for index in range(16):
			ship.fire()
			await create_timer(.14).timeout
		await create_timer(2).timeout
	var result := {"profiles":results,"ray_count":audio.ray_count,"sources":audio.sources.size(),"events":audio.event_count,"ambience_muted_for_tail_test":mute_ambience}
	print("ACOUSTIC RESULT ",JSON.stringify(result))
	var path := "/tmp/projectmine-06-acoustics.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): path=arg.trim_prefix("--output=")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	level.queue_free()
	await create_timer(.3).timeout
	quit()

func occlusion_review(level: Node3D, ship: CharacterBody3D, audio: Node3D) -> void:
	audio.maximum_loops=0
	ship.position=Vector3(200,0,0)
	audio._tick()
	audio.current=audio._open_settings()
	audio.target=audio.current.duplicate()
	audio._process(1.0)
	var player: AudioStreamPlayer3D=audio._emitter("ReviewSource",Vector3(202,0,0))
	# Two fixed diagnostic tones let a stereo capture verify real filter action.
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	var bytes := PackedByteArray()
	bytes.resize(22050*2)
	for index in range(22050):
		var time := float(index)/22050
		bytes.encode_s16(index*2,roundi((sin(TAU*180*time)+sin(TAU*4200*time))*.1*32767))
	stream.data=bytes
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=22050
	player.stream=stream
	player.volume_db=-15
	player.max_db=-15
	await create_timer(3).timeout
	player.play()
	print("OCCLUSION STAGE near_right ",Time.get_ticks_msec())
	await create_timer(2).timeout
	player.get_parent().global_position=Vector3(214,0,0)
	print("OCCLUSION STAGE far_right ",Time.get_ticks_msec())
	await create_timer(2).timeout
	var wall := StaticBody3D.new()
	wall.position=Vector3(207,0,0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(1,20,20)
	collision.shape=shape
	wall.add_child(collision)
	level.add_child(wall)
	await physics_frame
	print("OCCLUSION STAGE blocked_right ",Time.get_ticks_msec())
	await create_timer(2).timeout
	wall.queue_free()
	print("OCCLUSION STAGE clear_right ",Time.get_ticks_msec())
	await create_timer(2).timeout
	player.get_parent().global_position=Vector3(198,0,0)
	print("OCCLUSION STAGE near_left ",Time.get_ticks_msec())
	await create_timer(2).timeout
	player.stop()
	level.queue_free()
	await create_timer(.3).timeout
	quit()
