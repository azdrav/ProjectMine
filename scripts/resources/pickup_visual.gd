extends Node3D
## Reusable visual-only resource prop; no collision, collection or balance logic.
@export_enum("ammo","missiles","energy","shield") var kind: String = "ammo"
var emitters: Array[StandardMaterial3D] = []
var clock := 0.0
func _ready() -> void:
	var model = load("res://assets/models/pickups/"+kind+".glb").instantiate()
	add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(i)
			if material is StandardMaterial3D and material.emission_enabled:
				var local := material.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(i,local)
				emitters.append(local)
func _process(delta: float) -> void:
	clock += delta
	for material in emitters: material.emission_energy_multiplier = 0.9+sin(clock*1.6)*0.045
