extends RefCounted
## Shared geometry/materials; no per-shot shaders, textures or real-time lights.
const SHADER = preload("res://assets/materials/combat/energy.gdshader")
const Burst = preload("res://scripts/effects/energy_impact.gd")
const MAX_BURSTS: int = 24
static var _materials: Dictionary = {}
static var _streak: Mesh
static var _quad: QuadMesh
static func color(team: String) -> Color:
	return Color(1.0,0.16,0.025) if team == "enemy" else Color(0.08,0.68,1.0)
static func material(team: String, billboard: bool) -> ShaderMaterial:
	var key := team+str(billboard)
	if not _materials.has(key):
		var result := ShaderMaterial.new()
		result.shader = SHADER
		result.set_shader_parameter("energy_color",color(team))
		result.set_shader_parameter("core_color",Color(1.0,.55,.10) if team=="enemy" else Color(.85,.96,1.0))
		result.set_shader_parameter("billboard",billboard)
		_materials[key]=result
	return _materials[key]
static func quad() -> QuadMesh:
	if not _quad:
		_quad=QuadMesh.new()
		_quad.size=Vector2.ONE
	return _quad
static func streak() -> Mesh:
	if not _streak:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for axis in [Vector3.RIGHT,Vector3.UP]:
			# Crossed tapered ribbons remain visible when viewed from either side.
			var vertices := [-axis*.5,axis*.5,axis*.5+Vector3.BACK,-axis*.5+Vector3.BACK]
			var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
			for index in [0,1,2,0,2,3]:
				surface.set_uv(uv[index]);surface.add_vertex(vertices[index])
		_streak=surface.commit()
	return _streak
static func flash(team: String, size: float) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh=quad()
	result.material_override=material(team,true)
	result.scale=Vector3.ONE*size
	result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result
static func impact(parent: Node, point: Vector3, normal: Vector3, team: String, kind: String) -> Node3D:
	if parent.get_tree().get_nodes_in_group("combat_vfx").size() >= MAX_BURSTS: return null
	var effect := Node3D.new()
	effect.set_script(Burst)
	effect.name="EnergyImpact"
	effect.set("normal",normal)
	effect.set("team",team)
	effect.set("kind",kind)
	effect.set("flash_mesh",quad())
	effect.set("flash_material",material(team,true))
	effect.set("spark_material",material(team,false))
	parent.add_child(effect)
	effect.global_position=point+normal*.025
	return effect
