extends RefCounted
const VFX = preload("res://scripts/effects/energy_vfx.gd")
const Sounds = preload("res://scripts/audio/combat_audio.gd")
static func destruction(parent: Node, point: Vector3) -> void:
	var active := parent.get_tree().get_nodes_in_group("industrial_explosions")
	if active.size() >= 6: active[0].queue_free()
	var effect := Node3D.new()
	effect.name = "DroneDestruction"
	parent.add_child(effect)
	effect.add_to_group("industrial_explosions")
	effect.global_position = point
	var audio := AudioStreamPlayer3D.new()
	audio.stream = Sounds.sound("destroy")
	if AudioServer.get_bus_index("ExplosionFX") < 0:
		var send := Sounds.IndustrialSounds.ensure_bus()
		AudioServer.add_bus()
		var index := AudioServer.bus_count-1
		AudioServer.set_bus_name(index,"ExplosionFX")
		AudioServer.set_bus_send(index,send)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.6
		reverb.wet = 0.14
		AudioServer.add_bus_effect(index,reverb)
	audio.bus = "ExplosionFX"
	audio.volume_db = -8.0
	audio.max_distance = 45
	effect.add_child(audio)
	audio.play()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0,0.62,0.12)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22,0.25,0.27)
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 1.44
	flash.mesh = sphere
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var white := material.duplicate() as StandardMaterial3D
	white.albedo_color = Color(1,0.94,0.76)
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = white
	effect.add_child(flash)
	# Soft additive halo reads as hot light on Compatibility without a real-time lamp.
	var halo := VFX.flash("enemy",2.8)
	halo.name = "ExplosionGlow"
	var halo_material := halo.material_override.duplicate() as ShaderMaterial
	halo_material.set_shader_parameter("energy_color",Color(1,0.36,0.035))
	halo_material.set_shader_parameter("core_color",Color(1,0.92,0.7))
	halo_material.set_shader_parameter("brightness",1.5)
	halo.material_override = halo_material
	effect.add_child(halo)
	var halo_fade := halo.create_tween()
	halo_fade.tween_property(halo_material,"shader_parameter/brightness",0.0,0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	halo_fade.tween_callback(halo.queue_free)
	var burst := flash.create_tween()
	burst.tween_property(white,"albedo_color:a",0.0,0.12)
	burst.tween_callback(flash.queue_free)
	for index in range(6):
		var fragment := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.09
		fragment.mesh = cube
		fragment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fragment.material_override = material
		effect.add_child(fragment)
		var direction := Vector3(sin(index*2.4), cos(index*1.7), sin(index*3.7+1)).normalized()
		var tween := fragment.create_tween().set_parallel(true)
		tween.tween_property(fragment,"position",direction*1.5,0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment,"rotation",direction*5.0,0.55)
		tween.tween_property(fragment,"scale",Vector3.ZERO,0.55).set_delay(0.1)
	for i in range(3):
		var vapor := MeshInstance3D.new()
		vapor.mesh = sphere
		vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vapor.scale = Vector3.ONE*0.6
		vapor.position = Vector3(sin(i*2.4),cos(i*1.7),0)*0.2
		var gray := StandardMaterial3D.new()
		gray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gray.albedo_color = Color(1.0,0.35,0.045,0.32)
		gray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vapor.material_override = gray
		effect.add_child(vapor)
		var fade := vapor.create_tween().set_parallel(true)
		fade.tween_property(vapor,"scale",Vector3.ONE*1.7,0.65)
		fade.tween_property(gray,"albedo_color",Color(0.18,0.20,0.22,0.0),0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var cleanup := effect.create_tween()
	cleanup.tween_interval(0.8)
	cleanup.tween_callback(effect.queue_free)
