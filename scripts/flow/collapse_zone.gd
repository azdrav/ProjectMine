extends Node3D
## Predetermined sacrificial ceiling panel. Its debris never blocks the ship.
const Effects=preload("res://scripts/effects/combat_effects.gd")
var triggered := false
var plate: MeshInstance3D
var _steel: Material
func _ready() -> void:
	plate=MeshInstance3D.new()
	var mesh := BoxMesh.new();mesh.size=Vector3(1.4,.08,1.8)
	plate.mesh=mesh
	_steel=StandardMaterial3D.new();_steel.albedo_color=Color(.22,.24,.23)
	plate.material_override=_steel;plate.position=Vector3(2.8,3.4,0)
	plate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plate)
func restore(broken: bool) -> void:
	triggered=broken
	plate.rotation.z=.8 if broken else 0
	plate.position.y=2.6 if broken else 3.4
func trigger(ship: Node3D, maximum: int) -> void:
	if triggered: return
	triggered=true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(plate,"rotation:z",.8,.6)
	tween.tween_property(plate,"position:y",2.6,.6)
	Effects.destruction(get_tree().current_scene,global_position+Vector3(-2.5,2.5,0))
	var offset: Vector3=ship.global_position-global_position
	var strength:=clampf(1.0-offset.length()/24,0,1)
	ship.get_node("Camera3D/VisualOffset").add_impulse("structural_failure",.007*strength,.2,offset,true)
	# These are visual hazards, not new route-blocking gameplay geometry.
	if global_position.distance_to(ship.global_position)<8: return
	for side in [-1,1]:
		var existing := get_tree().get_nodes_in_group("escape_debris")
		if existing.size()>=maximum:
			if existing.is_empty(): return
			existing[0].remove_from_group("escape_debris")
			existing[0].queue_free()
		var body := RigidBody3D.new()
		body.add_to_group("escape_debris")
		body.collision_layer=0;body.collision_mask=1
		body.gravity_scale=.12;body.linear_damp=2;body.angular_damp=2
		body.continuous_cd=true
		var mesh := MeshInstance3D.new();mesh.mesh=plate.mesh;mesh.scale=Vector3.ONE*.28
		mesh.material_override=_steel;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
		var collider := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=Vector3(.4,.04,.5)
		collider.shape=shape;body.add_child(collider)
		get_tree().current_scene.add_child(body)
		body.global_position=global_position+Vector3(side*2.6,2.8,0)
		body.linear_velocity=Vector3(side*.4,-.6,.3)
		body.angular_velocity=Vector3(.6,.3,side*.4)
		var cleanup := body.create_tween()
		cleanup.tween_interval(8)
		cleanup.tween_property(mesh,"scale",Vector3.ZERO,1)
		cleanup.tween_callback(body.queue_free)
