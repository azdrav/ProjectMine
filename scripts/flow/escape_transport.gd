extends Node3D
## One enclosed connector between asteroids, never an open-space flight mode.
var gate: Node3D
var emergency_door: Node3D
var strips: Array[MeshInstance3D] = []
var _lit: StandardMaterial3D
func box(point: Vector3, size: Vector3, mat: Material, solid: bool=false) -> MeshInstance3D:
	var parent: Node3D=self
	if solid:
		var body := StaticBody3D.new()
		body.position=point
		add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new();shape.size=size
		collision.shape=shape;body.add_child(collision)
		parent=body
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new();cube.size=size
	mesh.mesh=cube;mesh.material_override=mat
	if not solid: mesh.position=point
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
func add_sign(point: Vector3, text: String, rotation_y: float=0) -> void:
	var label := Label3D.new()
	label.text=text;label.position=point;label.rotation.y=rotation_y
	label.font_size=32;label.pixel_size=.012
	label.modulate=Color(.7,1,.8)
	add_child(label)
func build(level: Node3D) -> void:
	level.tunnel(Vector3(96,34,-44),Vector3(112,34,-44),8)
	level.room(Vector3(118,34,-44),Vector3(12,12,12),{"left":Vector2(8,8),"top":Vector2(8,8)},"EVAC LIFT / ASCEND")
	level.tunnel(Vector3(118,40,-44),Vector3(118,64,-44),8)
	level.room(Vector3(118,70,-44),Vector3(12,12,12),{"bottom":Vector2(8,8),"back":Vector2(8,8)},"ASTEROID TRANSFER / EVACUATION")
	level.room(Vector3(118,70,-106),Vector3(16,12,16),{"front":Vector2(8,8),"back":Vector2(8,8)},"EVAC GATE / KEEP MOVING")
	level.tunnel(Vector3(118,70,-114),Vector3(118,70,-134),8)
	var steel: Material=level.material(Color(.13,.17,.19))
	var glass := StandardMaterial3D.new()
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color=Color(.15,.35,.43,.055)
	glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit=level.material(Color(.15,.65,.52),true)
	for y in [65.8,74.2]: box(Vector3(118,y,-74),Vector3(8.8,.4,48.4),steel,true)
	for side in [-1.0,1.0]:
		box(Vector3(118+side*4.2,70,-74),Vector3(.4,8,48.4),glass,true)
		for y in [66.4,73.6]: box(Vector3(118+side*4, y,-74),Vector3(.45,1,48.4),steel)
	for i in range(9):
		var z: float=-50-i*6
		for side in [-1.0,1.0]:
			box(Vector3(118+side*3.9,70,z),Vector3(.3,8,.28),steel)
			strips.append(box(Vector3(118+side*3.65,72.1,z),Vector3(.10,.7,.10),_lit))
		box(Vector3(118,73.8,z),Vector3(8,.25,.28),steel)
		if i in [2,4,6]:
			var side: float=-1 if i==4 else 1
			box(Vector3(118+side*3.25,69.2+(i%3),z),Vector3(1.1,1.5,1),steel,true)
	for x in [8.0,20.0,32.0,44.0,56.0,68.0,80.0,92.0,104.0]:
		strips.append(box(Vector3(x,34.8,-40.15),Vector3(.65,.09,.09),_lit))
	var door_script=preload("res://scripts/mission/sliding_door.gd")
	emergency_door=Node3D.new();emergency_door.set_script(door_script)
	emergency_door.name="EmergencyInterlock";emergency_door.position=Vector3(96,34,-44)
	emergency_door.rotation.y=PI/2;add_child(emergency_door)
	gate=Node3D.new();gate.set_script(door_script)
	gate.name="EvacuationGate";gate.position=Vector3(118,70,-111)
	add_child(gate)
	for point in [Vector3(0,36,-49),Vector3(53,36,-44),Vector3(88,36,-46),Vector3(118,36,-46)]:
		add_sign(point,"EVAC E-04  → AUX / SERVICE" if point.x<88 else "EVAC E-04  ↑ TRANSFER LIFT")
	add_sign(Vector3(118,72,-97.5),"E-04 / EVACUATION GATE")
	stars(Vector3(118,70,-74))
	asteroid(Vector3(146,73,-110),Vector3(12,9,15),level.material(Color(.4,.36,.32)))
	for i in range(4):
		box(Vector3(133,71+i*1.3,-106),Vector3(2,.7,4),steel)
		box(Vector3(131.9,71+i*1.3,-108),Vector3(.08,.18,1.6),_lit)
	var exterior := OmniLight3D.new()
	exterior.position=Vector3(134,80,-102);exterior.omni_range=24
	exterior.light_color=Color(.55,.65,.8);exterior.light_energy=3
	exterior.set_meta("independent_power",true)
	add_child(exterior)
	var light := OmniLight3D.new()
	light.position=Vector3(118,71,-74);light.light_color=Color(.3,.55,.75)
	light.omni_range=27;light.light_energy=1.4;add_child(light)
	if level.environmental_audio:
		var manager:=get_tree().get_first_node_in_group("environment_audio")
		if manager:
			manager.add_zone("Evacuation shaft",Transform3D(Basis.IDENTITY,Vector3(118,52,-44)),Vector3(8,24,8),preload("res://assets/audio/profiles/shaft.tres"))
			manager.add_zone("Asteroid transport",Transform3D(Basis.IDENTITY,Vector3(118,70,-74)),Vector3(8,8,48),preload("res://assets/audio/profiles/steel.tres"))
			manager.add_zone("Evacuation airlock",Transform3D(Basis.IDENTITY,Vector3(118,70,-106)),Vector3(16,12,16),preload("res://assets/audio/profiles/chamber.tres"))
		var audio := AudioStreamPlayer3D.new()
		audio.position=Vector3(118,70,-74)
		audio.stream=preload("res://scripts/audio/ambient_sounds.gd").sound("electrical")
		audio.volume_db=-28;audio.max_distance=40;audio.unit_size=8
		if manager: audio.bus=preload("res://scripts/audio/environment_audio.gd").WORLD
		add_child(audio)
		if DisplayServer.get_name()!="headless": audio.play()

func set_open(open: bool, animate: bool=false) -> void:
	for door in [emergency_door,gate]:
		door.powered=open
		if open and animate: door.request_open()
		else: door.restore(open)
	_lit.albedo_color=Color(1,.15,.04) if open else Color(.15,.65,.52)
func asteroid(point: Vector3, size: Vector3, mat: Material) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new();mesh.radial_segments=16;mesh.rings=8
	rock.mesh=mesh;rock.scale=size;rock.position=point;rock.material_override=mat
	rock.rotation=Vector3(.3,.8,.2);add_child(rock)
func stars(center: Vector3) -> void:
	var points := MultiMeshInstance3D.new()
	var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	var mesh := SphereMesh.new();mesh.radius=.12;mesh.height=.24;mesh.radial_segments=6;mesh.rings=3
	multi.mesh=mesh;multi.instance_count=160
	var rng := RandomNumberGenerator.new();rng.seed=13001
	for i in range(160):
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.6,2)),center+direction*rng.randf_range(90,170)))
	points.multimesh=multi
	var white := StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color(.7,.8,.9)
	points.material_override=white;points.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(points)
