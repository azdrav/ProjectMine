extends SceneTree
## Render-only fixture for the ending: no save files, player body or mission mutation.
var samples: Array[float]=[]
var measuring:=false
var draws:=0.0
func _initialize() -> void: call_deferred("run")
func _process(delta: float) -> bool:
	if measuring:
		samples.append(delta*1000)
		draws+=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return false
func run() -> void:
	var stage:=Node3D.new();stage.set_script(load("res://scripts/flow/escape_cinematic.gd"))
	stage.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(stage);stage.build_cinematic()
	assert(stage.skiff.find_children("*","CollisionObject3D",true,false).is_empty())
	assert(stage.skiff.position==Vector3(0,0,-5.8))
	for mesh in stage.skiff.find_children("*","MeshInstance3D",true,false):
		assert(mesh.global_position.distance_to(stage.skiff.global_position)<8,"Ship assemblies stay attached in the translated cinematic stage")
	var rock=stage.get_node("CrateredAsteroid")
	var arrays: Array=rock.mesh.surface_get_arrays(0)
	var outward:=0
	for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
		if arrays[Mesh.ARRAY_VERTEX][i].dot(arrays[Mesh.ARRAY_NORMAL][i])>0: outward+=1
	assert(outward>arrays[Mesh.ARRAY_VERTEX].size()*.95,"Rock normals face outward rather than rendering an inside-out shell")
	if DisplayServer.get_name()=="headless":
		await process_frame
		stage.queue_free();await process_frame
		print("Cinematic visual construction: PASS");quit();return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	await create_timer(.2).timeout
	var tween:=stage.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(stage.skiff,"position",Vector3(0,1,-19),3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	measuring=true
	for index in range(3):
		await create_timer(.85).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/cinematic_refined_%d.png"%index)
	measuring=false
	var total:=0.0
	for ms in samples: total+=ms
	samples.sort()
	var report={"gpu":RenderingServer.get_video_adapter_name(),"mean_fps":samples.size()*1000/total,"p95_ms":samples[int(samples.size()*.95)],"draw_calls":draws/samples.size(),"resolution":"1280x720","fixture":"Isolated ending shot, not gameplay benchmark"}
	var file:=FileAccess.open("res://docs/performance/cinematic_refined.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("CINEMATIC ",JSON.stringify(report));quit()
