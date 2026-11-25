extends "res://scripts/flow/escape_transport.gd"
## Self-contained visual stage; the real ship, camera and physics stay untouched.
const Models=preload("res://scripts/flow/cinematic_models.gd")
var skiff: Node3D
var camera: Camera3D
var _visual_time:=0.0
func build_cinematic() -> void:
	position=Vector3(1000,0,0)
	Models.rock(self,Vector3(0,0,17),Vector3(23,18,22),13017,true)
	Models.rock(self,Vector3(-38,19,49),Vector3(10,8,12),13022)
	Models.portal(self)
	stars(Vector3.ZERO)
	skiff=Models.craft(self)
	skiff.position=Vector3(0,0,-5.8)
	skiff.scale=Vector3.ONE*1.2
	# Own space environment: no mine fog or interior ambient tint in this shot.
	var space:=Environment.new()
	space.background_mode=Environment.BG_COLOR;space.background_color=Color(.002,.004,.009)
	space.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	space.ambient_light_color=Color(.27,.35,.47);space.ambient_light_energy=.55
	space.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	camera=Camera3D.new();add_child(camera)
	camera.environment=space
	camera.position=Vector3(14,7,-25);camera.fov=62
	camera.look_at(global_position+Vector3(0,0,-1));camera.current=true
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-32,-145,0)
	key.light_color=Color(1,.88,.73);key.light_energy=2.2
	key.shadow_enabled=true;key.directional_shadow_max_distance=75
	key.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	key.shadow_normal_bias=.5
	add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-15,30,0)
	rim.light_color=Color(.35,.52,.82);rim.light_energy=1.1;add_child(rim)
	var fill:=OmniLight3D.new();fill.position=Vector3(0,1,-8);fill.omni_range=18
	fill.light_color=Color(.5,.7,.9);fill.light_energy=2;add_child(fill)
	var crash:=AudioStreamPlayer.new()
	crash.stream=preload("res://scripts/audio/combat_audio.gd").sound("destroy")
	crash.volume_db=-17;add_child(crash)
	var sequence:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sequence.tween_interval(.4)
	sequence.tween_callback(func():
		preload("res://scripts/effects/combat_effects.gd").destruction(self,global_position+Vector3(-3,1,-4))
		crash.play())
	sequence.tween_interval(.8)
	sequence.tween_callback(func(): preload("res://scripts/effects/combat_effects.gd").destruction(self,global_position+Vector3(3,-2,-3)))
func _process(delta: float) -> void:
	if not is_instance_valid(skiff): return
	_visual_time+=delta
	# Restrained visual bank; trajectory continues to be owned by GameFlow's tween.
	skiff.rotation.z=sin(minf(_visual_time/3,1)*PI)*-.07
	for exhaust in skiff.find_children("Exhaust*","MeshInstance3D",false,false):
		exhaust.scale.z=1+.06*sin(_visual_time*37)
