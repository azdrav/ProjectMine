extends SceneTree
## Art inspection only: studio lighting is never instantiated in gameplay.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1600,900)
	var studio := Node3D.new()
	root.add_child(studio)
	current_scene = studio
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.025,0.035,0.045)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65,0.72,0.8)
	settings.ambient_light_energy = 0.85
	environment.environment = settings
	studio.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = 2.2
	studio.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25,160,0)
	fill.light_color = Color(0.45,0.65,0.85)
	fill.light_energy = 1.1
	studio.add_child(fill)
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.position = Vector3(1.2,3,-10)
	camera.look_at(Vector3(0,0,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	camera.current = true
	var names := ["heavy_guardian","industrial_drone","maintenance_bot","scout_drone"]
	var titles := ["HEAVY GUARDIAN","SECURITY DRONE","MAINTENANCE BOT","SCOUT"]
	var scales := [Vector3.ONE*1.8,Vector3.ONE,Vector3.ONE,Vector3(.62,.45,.62)]
	for i in range(4):
		var model = load("res://assets/models/enemies/"+names[i]+".glb").instantiate()
		studio.add_child(model)
		# Camera looks toward +Z: screen left is world +X.
		model.position.x = 3.6-i*2.4
		model.scale = scales[i]
		model.rotation.y = -0.25
		var label := Label3D.new()
		label.text = titles[i]
		label.font_size = 32
		label.pixel_size = 0.0035
		label.position = Vector3(model.position.x,-1.4,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(.65,.85,.87)
		studio.add_child(label)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/enemy_models_reference.png")
	studio.queue_free()
	await process_frame
	quit()
