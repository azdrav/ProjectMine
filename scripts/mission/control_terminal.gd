extends StaticBody3D
## Low-cost 3D console: no viewport textures or per-frame screen rendering.
var terminal_id := ""
var title := ""
var readout: Label3D
var status_strip: MeshInstance3D
var _status := ""

func surface(color: Color, lit: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if lit: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func part(label: String, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	mesh.material_override = mat
	add_child(mesh)
	return mesh

func text_at(value: String, point: Vector3, font: int, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = point
	label.font_size = font
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	add_child(label)
	return label

func _ready() -> void:
	var steel := surface(Color(0.17,0.20,0.21))
	var dark := surface(Color(0.035,0.05,0.055))
	var trim := surface(Color(0.38,0.41,0.40))
	var amber := surface(Color(0.85,0.48,0.09))
	part("Cabinet",Vector3.ZERO,Vector3(1.65,1.8,0.65),steel)
	part("ScreenBezel",Vector3(0,0.26,0.37),Vector3(1.46,1.05,0.14),dark)
	part("Display",Vector3(0,0.26,0.45),Vector3(1.26,0.84,0.025),surface(Color(0.01,0.075,0.085),true))
	part("KeyTray",Vector3(0,-0.48,0.45),Vector3(1.45,0.23,0.30),trim)
	for row in range(2):
		for column in range(7):
			part("Key",Vector3(-0.48+column*0.13,-0.43+row*0.065,0.615),Vector3(0.09,0.04,0.025),dark)
	for side in [-1.0,1.0]:
		part("ProtectionRail",Vector3(side*0.87,0,0.2),Vector3(0.10,2.0,0.12),trim)
		for y in [-0.78,0.78]:
			part("Fastener",Vector3(side*0.73,y,0.34),Vector3(0.07,0.07,0.025),trim)
	for i in range(5):
		part("Vent",Vector3(-0.42+i*0.16,-0.75,0.34),Vector3(0.10,0.13,0.025),dark)
	part("WarningPlate",Vector3(0.58,-0.73,0.35),Vector3(0.22,0.18,0.025),amber)
	status_strip = part("StatusStrip",Vector3(0,0.91,0.35),Vector3(1.38,0.045,0.035),surface(Color(1,0.5,0.1),true))
	text_at(title,Vector3(0,1.2,0.35),26,0.006,Color(0.7,0.86,0.85))
	text_at("PM / "+terminal_id.to_upper()+"   •   [F]",Vector3(0,0.59,0.48),22,0.0024,Color(0.45,0.75,0.75))
	readout = text_at("",Vector3(0,0.23,0.48),28,0.003,Color(0.45,0.95,0.84))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.85,2.0,0.95)
	collision.shape = shape
	collision.position.z = 0.12
	add_child(collision)

func set_status(value: String, active: bool) -> void:
	if value == _status: return
	_status = value
	readout.text = value
	readout.modulate = Color(0.45,0.95,0.75) if active else Color(1,0.65,0.26)
	status_strip.material_override.albedo_color = readout.modulate
