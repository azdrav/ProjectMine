extends Node3D
## Small inspection bay; no AI, collision simulation or duplicate full mine.
var robot: Node3D
var time := 0.0
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color(.025,.04,.05)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color(.3,.4,.48)
	settings.ambient_light_energy=.5
	environment.environment=settings
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position=Vector3(0,1,7)
	camera.look_at(Vector3(0,0,0))
	camera.current=true
	var light := OmniLight3D.new()
	light.position=Vector3(3,2,2)
	light.light_color=Color(.35,.65,.75)
	light.light_energy=3
	light.omni_range=12
	add_child(light)
	for i in range(7):
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size=Vector3(.15,6,.3)
		beam.mesh=mesh
		beam.position=Vector3(-6+i*2,-.5,-2)
		var material := StandardMaterial3D.new()
		material.albedo_color=Color(.10,.13,.14)
		beam.material_override=material
		add_child(beam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-30,-35,0)
	key.light_color=Color(.7,.8,.9);key.light_energy=1.1
	add_child(key)
	for side in [-1,1]:
		var strip := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=Vector3(.08,3,.08)
		strip.mesh=mesh;strip.position=Vector3(side*6,1,-1)
		var amber := StandardMaterial3D.new();amber.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;amber.albedo_color=Color(1,.45,.08)
		strip.material_override=amber;add_child(strip)
	robot=preload("res://assets/models/enemies/maintenance_bot.glb").instantiate()
	robot.position=Vector3(6.0,0,0)
	robot.scale=Vector3.ONE*2.3
	robot.rotation.y=PI-.4
	add_child(robot)
	var audio := AudioStreamPlayer.new()
	audio.stream=preload("res://scripts/audio/ambient_sounds.gd").sound("machinery")
	audio.volume_db=-31
	add_child(audio)
	if DisplayServer.get_name()!="headless": audio.play()
	get_node("/root/GameFlow").show_main()
func _process(delta: float) -> void:
	time+=delta
	robot.position.y=sin(time*.6)*.06
