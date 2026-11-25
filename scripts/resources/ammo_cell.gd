extends Node3D
var pickup_id := ""
var amount := 25
var resource_kind := "ammo"
var salvage_direction := Vector3.ZERO
var collected := false
var _time := 0.0
var visual: Node3D
func _ready() -> void:
	var path := "res://assets/models/pickups/"+("missiles" if resource_kind == "missiles" else "ammo")+".tscn"
	visual = load(path).instantiate()
	add_child(visual)
func _process(delta: float) -> void:
	_time += delta
	visual.rotation.y += delta*0.18
	visual.position = salvage_direction*0.07*sin(clampf(_time/0.8,0,1)*PI)+Vector3.UP*sin(_time*1.4)*0.035
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
