extends Node3D
var pickup_id := ""
var amount := 25
var resource_kind := "ammo"
var collected := false
var _time := 0.0
var visual: MeshInstance3D
func _ready() -> void:
	visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5,0.35,0.7)
	visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85,0.35,0.08) if resource_kind == "missiles" else Color(0.12,0.65,0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.9,0.25,0.02) if resource_kind == "missiles" else Color(0.10,0.8,0.3)
	visual.material_override = mat
	add_child(visual)
	var label := Label3D.new()
	label.text = ("MISSILES / +%d" if resource_kind == "missiles" else "CANNON AMMUNITION / +%d") % amount
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 0.7
	label.font_size = 24
	label.pixel_size = 0.008
	add_child(label)
func _process(delta: float) -> void:
	_time += delta
	visual.rotation.y += delta*0.6
	visual.position.y = sin(_time*1.7)*0.12
	var ship = get_tree().get_first_node_in_group("player")
	if not collected and is_instance_valid(ship) and ship.shield > 0 and ship.position.distance_to(global_position)<1.8 and (ship.missiles < ship.max_missiles if resource_kind == "missiles" else ship.ammo < ship.max_ammo):
		if ship.global_position.distance_to(global_position) > 0.01:
			var ray := PhysicsRayQueryParameters3D.create(global_position,ship.global_position,1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
		collected = true
		if resource_kind == "missiles": ship.missiles = mini(ship.max_missiles,ship.missiles+amount)
		else: ship.ammo = mini(ship.max_ammo,ship.ammo+amount)
		get_parent().collected[pickup_id] = true
		get_parent().resource_message(("MISSILES +%d" if resource_kind == "missiles" else "AMMUNITION +%d") % amount,global_position)
		queue_free()
