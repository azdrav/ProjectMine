extends Node3D
## One bounded burst, six procedural spark ribbons and a small energy flash.
var normal := Vector3.UP
var team: String = "player"
var kind: String = "wall"
var flash_mesh: Mesh
var flash_material: Material
var spark_material: Material
var age: float = 0.0
var duration: float = 0.26
var _flash: MeshInstance3D
var _sparks: MeshInstance3D
var _mesh: ImmediateMesh
var _velocities: Array[Vector3] = []
func _ready() -> void:
	add_to_group("combat_vfx")
	_flash=MeshInstance3D.new()
	_flash.name="ImpactFlash"
	_flash.scale=Vector3.ONE*.1
	_flash.mesh=flash_mesh
	_flash.material_override=flash_material
	_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash)
	_mesh=ImmediateMesh.new()
	_sparks=MeshInstance3D.new()
	_sparks.mesh=_mesh
	_sparks.material_override=spark_material
	_sparks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)
	var tangent := normal.cross(Vector3.UP).normalized() if absf(normal.dot(Vector3.UP))<.95 else normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent)
	for index in range(6):
		var angle := index*2.399
		_velocities.append((normal*.7+tangent*cos(angle)+bitangent*sin(angle)).normalized()*(1.5+index*.18))
	if kind == "shield": duration=.18
func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	var fade := 1.0-age/duration
	# Keep point-blank flashes small; never envelop the camera.
	_flash.scale=Vector3.ONE*(.10+.10*sin(clampf(age/.12,0,1)*PI))*fade
	_flash.visible=age<.16
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(_velocities.size()):
		var head := _velocities[index]*age
		if kind == "electrical": head += normal*sin(age*90+index)*.025
		var direction := _velocities[index].normalized()
		var tail := head-direction*(.06+.09*fade)
		var width := direction.cross(normal).normalized()*.012*fade
		var vertices := [head-width,head+width,tail+width,tail-width]
		var uvs := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for vertex in [0,1,2,0,2,3]:
			_mesh.surface_set_color(Color(1,1,1,fade))
			_mesh.surface_set_uv(uvs[vertex])
			_mesh.surface_add_vertex(vertices[vertex])
	_mesh.surface_end()
