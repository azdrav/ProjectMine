extends "res://scripts/flow/escape_transport.gd"
## Isolated visual stage far from gameplay; never moves the real ship body.
var skiff: Node3D
var camera: Camera3D
func build_cinematic() -> void:
	position=Vector3(1000,0,0)
	var rock := StandardMaterial3D.new();rock.albedo_color=Color(.20,.18,.15)
	asteroid(Vector3(0,-1,12),Vector3(18,14,20),rock)
	asteroid(Vector3(-22,8,26),Vector3(9,12,8),rock)
	stars(Vector3.ZERO)
	var steel := StandardMaterial3D.new();steel.albedo_color=Color(.2,.25,.27)
	var orange := StandardMaterial3D.new();orange.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;orange.albedo_color=Color(1,.35,.04)
	box(Vector3(0,0,2),Vector3(4.5,3,.7),steel)
	for x in [-2.2,2.2]: box(Vector3(x,0,1.5),Vector3(.14,2.8,.14),orange)
	for i in range(4): box(Vector3(-3+i*2,-1.8,2),Vector3(.3,.7,.4),orange)
	skiff=Node3D.new();add_child(skiff)
	var hull := MeshInstance3D.new();var mesh := SphereMesh.new();mesh.radial_segments=12;mesh.rings=6
	hull.mesh=mesh;hull.scale=Vector3(1.6,.8,2.4);hull.material_override=steel;skiff.add_child(hull)
	for side in [-1,1]:
		var gun := MeshInstance3D.new();var barrel := CylinderMesh.new();barrel.top_radius=.1;barrel.bottom_radius=.14;barrel.height=1.8;barrel.radial_segments=8
		gun.mesh=barrel;gun.rotation.x=PI/2;gun.position=Vector3(side*.9,-.05,-.4);gun.material_override=steel;skiff.add_child(gun)
		var exhaust := MeshInstance3D.new();exhaust.mesh=mesh;exhaust.scale=Vector3(.18,.18,.7);exhaust.position=Vector3(side*.5,0,1.3);exhaust.material_override=orange;skiff.add_child(exhaust)
	var light := OmniLight3D.new();light.position=Vector3(4,6,-5);light.light_color=Color(.6,.75,1);light.light_energy=4;light.omni_range=40;add_child(light)
	camera=Camera3D.new();add_child(camera)
	camera.position=Vector3(9,4,-12);camera.look_at(global_position+Vector3(0,0,-2));camera.current=true

	var key := DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-25,0)
	key.light_color=Color(.7,.8,.9);key.light_energy=1.7;add_child(key)
	var crash := AudioStreamPlayer.new()
	crash.stream=preload("res://scripts/audio/combat_audio.gd").sound("destroy")
	crash.volume_db=-17;add_child(crash)
	var sequence:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sequence.tween_interval(.4)
	sequence.tween_callback(func():
		preload("res://scripts/effects/combat_effects.gd").destruction(self,global_position+Vector3(-1,0,1))
		crash.play())
	sequence.tween_interval(.8)
	sequence.tween_callback(func(): preload("res://scripts/effects/combat_effects.gd").destruction(self,global_position+Vector3(2,-1,2)))
