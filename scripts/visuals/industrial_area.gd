extends "res://scripts/visuals/industrial_section.gd"
## Reuses the 0.4a batching and materials. All dimensions are cosmetic only.
@export var decoration_distance: float = 42.0
var corridor: bool = false
var center := Vector3.ZERO
var dimensions := Vector3.ONE
var start := Vector3.ZERO
var end := Vector3.ZERO
var area_index: int = 0
var vertical_portal: bool = false
var frame := Transform3D.IDENTITY

func _ready() -> void:
	add_to_group("industrial_areas")
	if corridor: _corridor()
	else: _chamber()
	_merge_material_batches()
	_commit_batches()
	for child in get_children():
		if child is GeometryInstance3D:
			child.visibility_range_end=decoration_distance
			child.visibility_range_end_margin=3.0

func _merge_material_batches() -> void:
	var batches: Dictionary = {}
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	for key in _batches:
		var group: String = _meshes[key].get_class()+str(_materials[key].get_instance_id())
		if not batches.has(group):
			batches[group]=[]
			meshes[group]=_meshes[key]
			materials[group]=_materials[key]
		batches[group].append_array(_batches[key])
	_batches=batches
	_meshes=meshes
	_materials=materials

func _part(key: String, point: Vector3, size: Vector3, surface: String) -> void:
	_box(key,frame*point,size,MATERIALS[surface],frame.basis)

func _pipe(key: String, point: Vector3, radius: float, length: float) -> void:
	_cylinder(key,frame*point,radius,length,MATERIALS.pipe,frame.basis*Basis(Vector3.RIGHT,PI/2))

func _corridor() -> void:
	var direction := (end-start).normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.95 else Vector3.UP
	frame=Transform3D(Basis.looking_at(direction,up),start)
	var length := start.distance_to(end)
	dimensions=Vector3(8,8,length)
	# Leave 2.5m at each mitered portal so beams never extend through its cut plane.
	var distance: float = 2.7
	while distance<length-2.5:
		for side in [-1.0,1.0]:
			_part("supports",Vector3(side*3.86,0,-distance),Vector3(.16,7.8,.22),"steel")
			_part("flanges",Vector3(side*3.76,0,-distance),Vector3(.025,7.8,.34),"dark")
			_part("hazard",Vector3(side*3.74,-2.5,-distance),Vector3(.02,1.0,.32),"hazard")
		for side in [-1.0,1.0]:
			_part("supports",Vector3(0,side*3.86,-distance),Vector3(7.8,.16,.22),"steel")
			_part("seams",Vector3(side*3.97,.2,-distance-1.7),Vector3(.015,7.6,.035),"dark")
		distance+=4.8
	for y in [.8,1.25]:
		_pipe("pipes",Vector3(-3.79,y,-length/2),.09,length-5.2)
	for y in [.9,1.05,1.2]:
		_pipe("conduits",Vector3(3.85,y,-length/2),.022,length-5.2)
	_part("duct",Vector3(-.9,3.81,-length/2),Vector3(.7,.25,length-5.2),"paint")
	for x in [1.2,1.55]:
		_part("supports",Vector3(x,3.82,-length/2),Vector3(.04,.12,length-5.2),"steel")
	for rung in range(ceili((length-5.4)/.8)):
		_part("seams",Vector3(1.375,3.78,-2.7-rung*.8),Vector3(.35,.025,.04),"dark")
	for distance_to_lamp in [length*.30,length*.70]:
		_fixture(Vector3(3.78,2.7,-distance_to_lamp),area_index==1)
	_sign(Vector3(-3.96,-.5,-length*.46),"LIFT SERVICES  /  S-02" if area_index==1 else "ORE TRANSFER  /  T-03")

func _chamber() -> void:
	frame=Transform3D(Basis.IDENTITY,center)
	var half := dimensions*.5
	var z := -half.z+.8
	while z<half.z-.6:
		for side in [-1.0,1.0]:
			_part("supports",Vector3(side*(half.x-.10),0,z),Vector3(.16,dimensions.y-.35,.26),"steel")
			_part("flanges",Vector3(side*(half.x-.21),0,z),Vector3(.025,dimensions.y-.45,.4),"dark")
			_part("hazard",Vector3(side*(half.x-.24),-half.y+1.1,z),Vector3(.025,1.0,.36),"hazard")
			_part("seams",Vector3(side*(half.x-.025),0,z+1.7),Vector3(.02,dimensions.y-.5,.035),"dark")
		# Shaft chambers have an open ceiling/floor. Keep transverse beams clear.
		if not vertical_portal or absf(z)>4.7:
			_part("supports",Vector3(0,half.y-.09,z),Vector3(dimensions.x-.3,.14,.26),"steel")
		z+=4.6 if area_index%2==0 else 4.1
	for side in [-1.0,1.0]:
		for y in [.65,1.10]:
			_pipe("pipes",Vector3(side*(half.x-.19),y,-.1*area_index),.085,dimensions.z-1.2)
		_part("supports",Vector3(side*(half.x-.12),half.y-1.0,0),Vector3(.09,.35,dimensions.z-1.0),"steel")
		for rung in range(ceili((dimensions.z-1.5)/.9)):
			_part("seams",Vector3(side*(half.x-.25),half.y-1.0,-half.z+.8+rung*.9),Vector3(.30,.04,.05),"dark")
		_fixture(Vector3(side*(half.x-.2),half.y-1.7,-half.z*.45),area_index==3)
		_fixture(Vector3(side*(half.x-.2),half.y-1.7,half.z*.5),false)
		# Service panels and vents sit within 35cm of solid side walls.
		var panel_z: float = half.z*.22*side
		_part("panels",Vector3(side*(half.x-.14),-.5,panel_z),Vector3(.18,1.35,1.5),"paint")
		_part("hazard",Vector3(side*(half.x-.24),.08,panel_z),Vector3(.025,.13,1.3),"hazard")
		for slat in range(7):
			_part("seams",Vector3(side*(half.x-.25),-.9+slat*.09,panel_z),Vector3(.025,.035,1.2),"dark")
	# Recess-like concrete repair patches break up the large wall surfaces.
	for patch in range(3):
		_part("patches",Vector3(-half.x+.025,-half.y+1.8+patch*1.6,half.z*.45),Vector3(.015,1.3,2.2),"rock" if patch==area_index%3 else "concrete")
	var names := ["LAUNCH BAY  /  EQUIPMENT SERVICE","SHAFT ACCESS  /  LIFT CONTROL","UPPER TRANSFER  /  VENTILATION","POWER GALLERY  /  RESTRICTED"]
	_sign(Vector3(-half.x+.04,half.y*.30,-half.z*.35),names[area_index])

func _fixture(point: Vector3, warning: bool) -> void:
	var side: float = signf(point.x)
	var body := point
	_part("fixtures",body,Vector3(.18,.28,.85),"dark")
	var key := "warning" if warning else "lamp"
	if not _materials.has(key): _materials[key]=_emissive(Color(.55,.055,.018) if warning else Color(.9,.76,.52))
	# _box owns the material table on first use, so retain the emissive reference.
	var surface: Material=_materials[key]
	body.x-=side*.11
	_box(key,frame*body,Vector3(.025,.13,.64),surface,frame.basis)
	for offset in [-.25,0.,.25]:
		_part("supports",body+Vector3(-side*.02,0,offset),Vector3(.025,.24,.025),"steel")

func _sign(point: Vector3, text: String) -> void:
	if _overlaps_portal(frame*point,Vector3(1.8,0.25,0.03),frame.basis*Basis(Vector3.UP,PI/2)): return
	var sign := Label3D.new()
	sign.name="AreaIdentification"
	sign.text=text
	sign.font_size=24
	sign.pixel_size=.0035
	sign.outline_size=0
	sign.transform=frame*Transform3D(Basis(Vector3.UP,PI/2),point)
	sign.modulate=Color(.75,.72,.60)
	sign.layers=RENDER_LAYER
	add_child(sign)
