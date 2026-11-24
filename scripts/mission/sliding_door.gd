extends Node3D
## The visible leaves and their collision shapes move together on physics ticks.
signal opened
@export var opening_duration: float = 2.4
var opening := false
var progress: float = 0.0
var powered := false
var leaves: Array[AnimatableBody3D] = []
var indicators: Array[MeshInstance3D] = []
var motor: AudioStreamPlayer3D
var _time := 0.0

func material(color: Color, lit: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if lit: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func box(parent: Node3D, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = point
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _ready() -> void:
	var steel := material(Color(0.24,0.27,0.26))
	var dark := material(Color(0.08,0.1,0.11))
	var trim := material(Color(0.45,0.48,0.46))
	var amber := material(Color(0.8,0.48,0.08))
	for side in [-1.0,1.0]:
		box(self,Vector3(side*4.22,0,0),Vector3(0.45,9.25,0.95),dark)
		var leaf := AnimatableBody3D.new()
		leaf.name = "LeftLeaf" if side < 0 else "RightLeaf"
		leaf.sync_to_physics = false
		leaf.collision_layer = 1
		leaf.collision_mask = 7
		add_child(leaf)
		leaves.append(leaf)
		var collision := CollisionShape3D.new()
		var hull := BoxShape3D.new()
		hull.size = Vector3(3.98,8.8,0.6)
		collision.shape = hull
		leaf.add_child(collision)
		box(leaf,Vector3.ZERO,hull.size,steel)
		for face in [-1.0,1.0]:
			box(leaf,Vector3(0,0,face*0.33),Vector3(3.5,7.65,0.08),dark)
			for y in [-2.65,0.0,2.65]:
				box(leaf,Vector3(0,y,face*0.40),Vector3(3.35,2.2,0.10),steel)
			box(leaf,Vector3(-side*1.88,0,face*0.4),Vector3(0.11,8.4,0.12),trim)
			for y in [-3.8,3.8]:
				for i in range(6):
					var stripe := box(leaf,Vector3(-1.4+i*0.55,y,face*0.47),Vector3(0.20,0.45,0.04),amber)
					stripe.rotation.z = -0.5
		var indicator := box(self,Vector3(side*3.85,1.7,0.53),Vector3(0.16,1.1,0.05),material(Color(1,0.2,0.05),true))
		indicators.append(indicator)
	box(self,Vector3(0,4.62,0),Vector3(8.9,0.40,0.95),trim)
	box(self,Vector3(0,-4.52,0),Vector3(8.9,0.22,0.85),dark)
	motor = AudioStreamPlayer3D.new()
	motor.stream = preload("res://scripts/audio/ambient_sounds.gd").sound("startup")
	motor.volume_db = -13
	motor.unit_size = 6
	motor.max_distance = 30
	add_child(motor)
	restore(false)

func request_open() -> void:
	if not powered or opening or progress >= 1.0: return
	opening = true
	motor.play()

func restore(is_open: bool) -> void:
	opening = false
	progress = 1.0 if is_open else 0.0
	if is_instance_valid(motor): motor.stop()
	place_leaves()
	update_indicators()

func place_leaves() -> void:
	var offset := 1.99 + 4.12*smoothstep(0.0,1.0,progress)
	leaves[0].position.x = -offset
	leaves[1].position.x = offset

func update_indicators() -> void:
	var color := Color(0.25,1,0.55) if powered else Color(1,0.18,0.04)
	if opening: color = Color(1,0.60,0.08)*(0.65+0.35*sin(_time*12))
	for indicator in indicators: indicator.material_override.albedo_color = color

func _physics_process(delta: float) -> void:
	_time += delta
	if opening:
		progress = minf(1.0,progress+delta/maxf(0.1,opening_duration))
		place_leaves()
		if progress >= 1.0:
			opening = false
			opened.emit()
	update_indicators()

func _exit_tree() -> void:
	if is_instance_valid(motor):
		motor.stop()
		motor.stream = null
