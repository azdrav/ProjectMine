extends Node3D
## Decorative retrofit of the existing horizontal corridor. No collision/AI nodes.
const MATERIALS := {
	"concrete":preload("res://assets/materials/industrial/concrete.tres"),
	"rock":preload("res://assets/materials/industrial/rock.tres"),
	"steel":preload("res://assets/materials/industrial/steel.tres"),
	"dark":preload("res://assets/materials/industrial/dark_steel.tres"),
	"paint":preload("res://assets/materials/industrial/paint.tres"),
	"pipe":preload("res://assets/materials/industrial/pipe.tres"),
	"hazard":preload("res://assets/materials/industrial/hazard.tres")}
@export var retrofit_existing_shell: bool = true
const RENDER_LAYER: int = 2
var _batches: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var decoration_instances: int = 0

func _ready() -> void:
	add_to_group("industrial_visuals")
	if retrofit_existing_shell: _retrofit_existing_surfaces()
	_build_supports()
	_build_services()
	_build_fixtures()
	_build_panels()
	_commit_batches()

func _retrofit_existing_surfaces() -> void:
	for node in get_parent().get_children():
		if node is StaticBody3D:
			var point: Vector3 = node.position
			# Four existing collision slabs and five luminous guide trims; shape untouched.
			if point.z < -14.0 and point.z > -38.0 and absf(point.y) < 5.0:
				for child in node.get_children():
					if child is MeshInstance3D:
						child.layers = RENDER_LAYER
						child.material_override = MATERIALS.dark if absf(point.x)>3.8 and absf(point.y)<0.1 and child.mesh.size.x<0.1 else (MATERIALS.steel if absf(point.y)>4.0 else MATERIALS.concrete)
		elif node is OmniLight3D:
			# Keep the legacy blue room lighting out of the new section's render layer.
			node.light_cull_mask = 1
			if node.position.z < -14.0 and node.position.z > -38.0 and absf(node.position.y)<0.1:
				node.visible = false
		elif node is Label3D and node.position.z > -15.0 and node.position.z < -13.0:
			node.modulate = Color(0.80,0.76,0.62)

func _overlaps_portal(point: Vector3, size: Vector3, rotation: Basis) -> bool:
	var ancestor: Node = get_parent()
	while is_instance_valid(ancestor):
		var portals: Variant = ancestor.get("decoration_portals")
		if portals is Array:
			for portal in portals:
				var inverse: Transform3D = portal.pose.affine_inverse()
				var local: Vector3 = inverse*point
				var axes: Basis = inverse.basis*rotation
				var extent := axes.x.abs()*size.x*0.5+axes.y.abs()*size.y*0.5+axes.z.abs()*size.z*0.5
				var bounds: Vector3 = portal.half+extent
				if absf(local.x)<bounds.x and absf(local.y)<bounds.y and absf(local.z)<bounds.z: return true
			return false
		ancestor = ancestor.get_parent()
	return false

func _box(key: String, point: Vector3, size: Vector3, material: Material, rotation: Basis = Basis.IDENTITY) -> void:
	if _overlaps_portal(point,size,rotation): return
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_meshes[key] = mesh
		_materials[key] = material
		_batches[key] = []
	_batches[key].append(Transform3D(rotation * Basis.from_scale(size),point))
	decoration_instances += 1

func _cylinder(key: String, point: Vector3, radius: float, length: float, material: Material, rotation: Basis) -> void:
	if _overlaps_portal(point,Vector3(radius*2,length,radius*2),rotation): return
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1
		mesh.bottom_radius = 1
		mesh.height = 1
		mesh.radial_segments = 10
		mesh.rings = 1
		_meshes[key] = mesh
		_materials[key] = material
		_batches[key] = []
	_batches[key].append(Transform3D(rotation * Basis.from_scale(Vector3(radius,length,radius)),point))
	decoration_instances += 1

func _build_supports() -> void:
	for z in [-14.25,-18.0,-22.0,-26.0,-30.0,-34.0,-37.75]:
		for side in [-1.0,1.0]:
			# Shallow flanges and webs stay against the wall, outside the flight center.
			_box("steel",Vector3(side*3.89,0,z),Vector3(.18,7.8,.28),MATERIALS.steel)
			_box("steel",Vector3(side*3.80,0,z),Vector3(.035,7.8,.40),MATERIALS.steel)
			_box("dark",Vector3(side*3.78,-3.60,z),Vector3(.08,.72,.58),MATERIALS.dark)
			for y in [-3.72,3.72]:
				_box("steel",Vector3(side*3.64,y,z),Vector3(.58,.18,.4),MATERIALS.steel)
			for y in [-3.25,-2.9,2.9,3.25]:
				_cylinder("bolts",Vector3(side*3.755,y,z),.045,.025,MATERIALS.dark,Basis(Vector3.FORWARD,PI/2))
		_box("steel",Vector3(0,3.86,z),Vector3(7.8,.18,.28),MATERIALS.steel)
		_box("steel",Vector3(0,3.76,z),Vector3(7.8,.035,.4),MATERIALS.steel)
		_box("dark",Vector3(0,-3.95,z),Vector3(7.8,.04,.28),MATERIALS.dark)
	for side in [-1.0,1.0]:
		_box("steel",Vector3(side*3.92,-3.6,-26),Vector3(.14,.8,23.5),MATERIALS.steel)
		_box("steel",Vector3(side*3.92,3.7,-26),Vector3(.14,.28,23.5),MATERIALS.steel)
	# Yellow/black keep-clear edging at both portals, not luminous flight stripes.
	for z in [-14.18,-37.82]:
		for side in [-1.0,1.0]:
			_box("hazard",Vector3(side*3.77,-2.5,z),Vector3(.04,2.0,.44),MATERIALS.hazard)
		_box("hazard",Vector3(0,3.65,z),Vector3(7.45,.12,.44),MATERIALS.hazard)

func _build_services() -> void:
	var along_tunnel := Basis(Vector3.RIGHT,PI/2)
	for y in [1.55,2.10]:
		_cylinder("pipes",Vector3(-3.73,y,-26),.13,23.6,MATERIALS.pipe,along_tunnel)
		for z in [-16.,-20.,-24.,-28.,-32.,-36.]:
			_cylinder("flanges",Vector3(-3.73,y,z),.18,.08,MATERIALS.steel,along_tunnel)
			_box("steel",Vector3(-3.91,y,z),Vector3(.12,.44,.12),MATERIALS.steel)
	for y in [1.56,1.71,1.86]:
		_cylinder("conduits",Vector3(3.81,y,-26),.025,23.6,MATERIALS.dark,along_tunnel)
	# Cable ladder, a slim duct and rectangular clamped joints.
	for x in [1.20,1.66]:
		_box("steel",Vector3(x,3.78,-26),Vector3(.05,.13,23.6),MATERIALS.steel)
	for index in range(40):
		_box("dark",Vector3(1.43,3.75,-14.35-index*.59),Vector3(.46,.035,.045),MATERIALS.dark)
	for x in [1.32,1.43,1.54]:
		_cylinder("cables",Vector3(x,3.84,-26),.022,23.6,MATERIALS.dark,along_tunnel)
	_box("paint",Vector3(-1.1,3.70,-26),Vector3(.85,.45,23.6),MATERIALS.paint)
	for z in [-16.,-20.,-24.,-28.,-32.,-36.]:
		_box("steel",Vector3(-1.1,3.70,z),Vector3(.92,.50,.055),MATERIALS.steel)
		_box("steel",Vector3(3.86,1.71,z),Vector3(.12,.55,.10),MATERIALS.steel)

func _emissive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _build_fixtures() -> void:
	var warm := _emissive(Color(1.0,.81,.51))
	var red := _emissive(Color(.55,.035,.012))
	for z in [-18.,-26.,-34.]:
		for side in [-1.0,1.0]:
			_box("dark",Vector3(side*3.74,2.85,z),Vector3(.24,.30,1.0),MATERIALS.dark)
			_box("lamp",Vector3(side*3.60,2.85,z),Vector3(.04,.13,.74),warm)
			for offset in [-.34,0.,.34]:
				_box("steel",Vector3(side*3.57,2.85,z+offset),Vector3(.025,.25,.025),MATERIALS.steel)
		var light := OmniLight3D.new()
		light.name = "WarmMaintenanceLight"
		light.position = Vector3(0,1.8,z)
		light.light_color = Color(1.0,.78,.51)
		light.light_energy = 2.2
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.light_cull_mask = 3
		add_child(light)
	for side in [-1.0,1.0]:
		_box("dark",Vector3(side*3.72,.3,-37.6),Vector3(.18,.30,.20),MATERIALS.dark)
		_box("red",Vector3(side*3.60,.3,-37.6),Vector3(.05,.14,.12),red)

func _build_panels() -> void:
	# Panel seams, patch plates and vent slats. No unique texture per panel.
	for side in [-1.0,1.0]:
		for z in [-16.,-24.,-28.,-36.]:
			_box("dark",Vector3(side*3.975,0,z),Vector3(.025,7.1,.035),MATERIALS.dark)
			_box("dark",Vector3(side*3.975,-.7,z),Vector3(.025,.035,3.6),MATERIALS.dark)
		for z in [-20.,-32.]:
			_rock_patch(side,z)
	_box("paint",Vector3(3.82,-.15,-23),Vector3(.22,1.25,.85),MATERIALS.paint)
	_box("dark",Vector3(3.69,-.15,-23),Vector3(.035,1.05,.65),MATERIALS.dark)
	_box("hazard",Vector3(3.665,.28,-23),Vector3(.015,.12,.60),MATERIALS.hazard)
	for index in range(7):
		_box("steel",Vector3(3.66,-.4+index*.075,-23),Vector3(.025,.025,.5),MATERIALS.steel)
	_box("paint",Vector3(-3.96,.20,-27.5),Vector3(.025,.5,2.25),MATERIALS.paint)
	var plate := Label3D.new()
	plate.text = "VENTILATION  /  M-04\nAUTHORIZED MAINTENANCE ONLY"
	plate.font_size = 24
	plate.pixel_size = .0025
	plate.outline_size = 0
	plate.position = Vector3(-3.935,.20,-27.5)
	plate.rotation.y = PI/2
	plate.modulate = Color(.70,.67,.56)
	plate.no_depth_test = false
	plate.layers = RENDER_LAYER
	add_child(plate)

func _rock_patch(side: float, z: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed = int(absf(z)*47+side*13)
	var points: Array[Vector3] = []
	for row in range(6):
		for column in range(5):
			points.append(Vector3(side*(3.96-random.randf_range(0.0,.075)),-3.1+row*1.24,z-1.76+column*.88))
	for row in range(5):
		for column in range(4):
			var a := row*5+column
			for triangle in [[a,a+1,a+6],[a,a+6,a+5]]:
				var first: Vector3 = points[triangle[0]]
				var second: Vector3 = points[triangle[1]]
				var third: Vector3 = points[triangle[2]]
				var outward := (second-first).cross(third-first).normalized()
				if outward.x*side>0.0: outward=-outward
				if (second-first).cross(third-first).dot(outward)>0.0:
					var swap := second
					second=third
					third=swap
				for vertex in [first,second,third]:
					surface.set_normal(outward)
					surface.add_vertex(vertex)
	var mesh := MeshInstance3D.new()
	mesh.name = "ExposedRock"
	mesh.mesh = surface.commit()
	mesh.material_override = MATERIALS.rock
	mesh.layers = RENDER_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _commit_batches() -> void:
	for key in _batches:
		var instances: Array = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _meshes[key]
		multimesh.instance_count = instances.size()
		for index in range(instances.size()): multimesh.set_instance_transform(index,instances[index])
		var batch := MultiMeshInstance3D.new()
		batch.name = "Batch_"+key
		batch.multimesh = multimesh
		batch.material_override = _materials[key]
		batch.layers = RENDER_LAYER
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
