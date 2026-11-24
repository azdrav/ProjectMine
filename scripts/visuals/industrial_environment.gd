extends Node3D
## Full-mine cosmetic extension. Existing physics bodies and portal cuts are read-only.
const Area = preload("res://scripts/visuals/industrial_area.gd")
const Materials = preload("res://scripts/visuals/industrial_section.gd")
@export var decoration_distance: float = 42.0
var areas: Array[Node3D] = []
var shell_batches: Dictionary = {}
var shell_source_count: int = 0
func _ready() -> void:
	add_to_group("industrial_visuals")
	_retrofit_shell()
	_batch_static_shell()
	var centers := [Vector3.ZERO,Vector3(0,0,-44),Vector3(0,34,-44),Vector3(0,44,-80)]
	var sizes := [Vector3(24,16,28),Vector3(16,16,12),Vector3(16,12,16),Vector3(20,16,16)]
	for index in range(4):
		var area = Node3D.new()
		area.set_script(Area)
		area.name=["LaunchBay","LowerShaftChamber","UpperTransferChamber","PowerGallery"][index]
		area.center=centers[index]
		area.dimensions=sizes[index]
		area.decoration_distance=decoration_distance
		area.area_index=index
		area.vertical_portal=index in [1,2]
		add_child(area)
		areas.append(area)

	for index in range(2):
		var area = Node3D.new()
		area.set_script(Area)
		area.name="VerticalServices" if index==0 else "AngledOreTransfer"
		area.corridor=true
		area.start=Vector3(0,8,-44) if index==0 else Vector3(0,34,-52)
		area.end=Vector3(0,28,-44) if index==0 else Vector3(0,44,-72)
		area.decoration_distance=decoration_distance
		area.area_index=index+1
		add_child(area)
		areas.append(area)

func _batch_static_shell() -> void:
	# Render existing boxes in spatial/material batches, leaving every physics
	# body and collision shape intact. Room-sized bounds retain local light selection.
	var centers := [Vector3.ZERO,Vector3(0,0,-26),Vector3(0,0,-44),Vector3(0,18,-44),Vector3(0,34,-44),Vector3(0,39,-62),Vector3(0,44,-80)]
	var batches: Dictionary = {}
	var materials: Dictionary = {}
	for body in get_parent().get_children():
		if not body is StaticBody3D: continue
		var zone: int = 0
		for index in range(centers.size()):
			if body.position.distance_squared_to(centers[index])<body.position.distance_squared_to(centers[zone]): zone=index
		for visual in body.get_children():
			if not visual is MeshInstance3D or not visual.mesh is BoxMesh: continue
			var material: Material=visual.material_override
			var key := str(zone)+"_"+str(material.get_instance_id())
			if not batches.has(key):
				batches[key]=[]
				materials[key]=material
			batches[key].append(body.transform*visual.transform*Transform3D(Basis.from_scale(visual.mesh.size),Vector3.ZERO))
			visual.visible=false
			shell_source_count+=1
	shell_batches=batches
	var cube := BoxMesh.new()
	cube.size=Vector3.ONE
	for key in batches:
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=cube
		multimesh.instance_count=batches[key].size()
		for index in range(multimesh.instance_count): multimesh.set_instance_transform(index,batches[key][index])
		var visual := MultiMeshInstance3D.new()
		visual.name="ShellBatch_"+key
		visual.multimesh=multimesh
		visual.material_override=materials[key]
		visual.layers=2
		visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)

func _retrofit_shell() -> void:
	for node in get_parent().get_children():
		if node is StaticBody3D:
			for visual in node.get_children():
				if not visual is MeshInstance3D or visual.layers==2: continue
				visual.layers=2
				var trim: bool = visual.mesh is BoxMesh and visual.mesh.size[visual.mesh.size.min_axis_index()]<.13
				visual.material_override=Materials.MATERIALS.dark if trim else Materials.MATERIALS.concrete
		elif node is OmniLight3D:
			# 0.4a already hid the old first-corridor lights; leave that section alone.
			if node.position.z>-38 and node.position.z< -14 and absf(node.position.y)<.1: continue
			node.light_cull_mask=3
			node.shadow_enabled=false
			node.light_color=Color(1.0,.82,.60)
			node.light_energy=1.8
			node.omni_range=18.0 if node.position==Vector3.ZERO else (14.0 if node.position.z< -70 else 12.0)
			if node.position.y>8 and node.position.y<28:
				node.visible=roundi(node.position.y/4.0)%2==0
				node.omni_range=8.5
				node.light_energy=1.3
			elif node.position.y>34 and node.position.y<44:
				var distance: float = node.position.distance_to(Vector3(0,34,-52))
				node.visible=roundi(distance/4.0)%2==0
				node.omni_range=8.5
				node.light_energy=1.3
		elif node is Label3D:
			node.modulate=Color(.78,.73,.60)
