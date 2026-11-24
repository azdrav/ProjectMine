extends RefCounted
const Sounds = preload("res://scripts/audio/combat_audio.gd")
static func destruction(parent: Node, point: Vector3) -> void:
	var effect := Node3D.new()
	effect.name = "DroneDestruction"
	parent.add_child(effect)
	effect.global_position = point
	var audio := AudioStreamPlayer3D.new()
	audio.stream = Sounds.sound("destroy")
	audio.volume_db = -8.0
	audio.max_distance = 45
	effect.add_child(audio)
	audio.play()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0,0.5,0.08)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22,0.25,0.27)
	for index in range(12):
		var fragment := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * (0.30 if index < 4 else 0.08)
		fragment.mesh = cube
		fragment.material_override = steel if index < 4 else material
		effect.add_child(fragment)
		var direction := Vector3(sin(index*2.4), cos(index*1.7), sin(index*3.7+1)).normalized()
		var tween := fragment.create_tween().set_parallel(true)
		tween.tween_property(fragment,"position",direction*1.5,0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment,"rotation",direction*5.0,0.55)
		tween.tween_property(fragment,"scale",Vector3.ZERO,0.55).set_delay(0.1)
	var cleanup := effect.create_tween()
	cleanup.tween_interval(0.8)
	cleanup.tween_callback(effect.queue_free)
