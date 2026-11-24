extends SceneTree
const Sounds = preload("res://scripts/audio/ambient_sounds.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures+=1
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func run() -> void:
	var bus_count := AudioServer.bus_count
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled=false
	var audio = level.get_node("EnvironmentAudio")
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	await frames(5)
	check(audio.zones.size()==7,"Seven zones cover the fixed mine")
	var chamber: Dictionary=audio.sample_acoustics(Vector3.ZERO)
	var concrete: Dictionary=audio.sample_acoustics(Vector3(0,0,-26))
	var shaft: Dictionary=audio.sample_acoustics(Vector3(0,18,-44))
	var steel: Dictionary=audio.sample_acoustics(Vector3(0,39,-62))
	check(chamber.wet>concrete.wet and shaft.room_size>chamber.room_size,"Room profiles differ meaningfully")
	check(steel.damping<concrete.damping,"Steel reflections less damped than concrete")
	check(audio.sample_acoustics(Vector3(200,0,0)).wet==0,"Exterior fallback is dry")
	var previous: float=audio.sample_acoustics(Vector3(0,0,-12)).wet
	for step in range(81):
		var wet: float=audio.sample_acoustics(Vector3(0,0,-12-step*.05)).wet
		check(absf(wet-previous)<.004,"Spatial boundary weights change smoothly")
		previous=wet
	audio.current=concrete.duplicate()
	audio.target=shaft.duplicate()
	audio._process(.016)
	check(audio.current.wet>concrete.wet and audio.current.wet<shaft.wet,"Temporal interpolation is gradual")
	check(audio.reverb.dry==1.0 and audio.reverb.wet<=audio.maximum_wet,"Direct component and wet ceiling preserved")
	check(ship.get_node("Audio").weapon.bus==audio.WORLD,"Player discharge receives room acoustics")
	for player in [ship.get_node("Audio").impact,ship.get_node("Audio").scrape,ship.get_node("Audio").shield]:
		check(player.bus==&"IndustrialFX","Internal audio stays direct")
	check(ship.get_node("Proximity")._audio.bus==&"Master","Sonar routing is untouched")
	for enemy in get_nodes_in_group("enemies"):
		check(str(enemy.weapon_audio.bus).begins_with("WorldSource"),"Enemy audio routes through external source bus")
	# One real source, an actual static wall, player and source explicitly excluded.
	var emitter: AudioStreamPlayer3D=audio.loops[0].player
	emitter.get_parent().global_position=Vector3(210,0,0)
	ship.position=Vector3(200,0,0)
	emitter.play()
	var wall := StaticBody3D.new()
	wall.position=Vector3(205,0,0)
	wall.collision_layer=1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(1,20,20)
	collider.shape=shape
	wall.add_child(collider)
	level.add_child(wall)
	await frames(2)
	audio.rays_per_update=24
	var before: int=audio.ray_count
	audio._tick()
	check(audio.ray_count-before<=audio.sources.size(),"Ray work is bounded to active source owners")
	var source: Dictionary = {}
	for item in audio.sources:
		if item.owner==emitter.get_parent(): source=item
	check(not source.is_empty() and source.blocked,"Wall occlusion detected")
	for index in range(20): audio._process(.05)
	check(source.gain_db< -8 and source.gain_db> -30,"Occlusion muffles without silencing")
	check(source.slot.filter.cutoff_hz<4000,"Per-source low-pass filtering")
	wall.queue_free()
	await frames(2)
	emitter.play()
	audio._tick()
	check(not source.blocked,"Separation from wall clears occlusion")
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.position=Vector3(200,0,10)
	audio.obstacle_mask=7
	await frames(2)
	enemy.weapon_audio.play()
	audio._tick()
	for item in audio.sources:
		if item.owner==enemy: check(not item.blocked,"Player and source bodies are excluded even with their layers enabled")
	audio.obstacle_mask=1
	ship.position=Vector3.ZERO
	emitter.get_parent().global_position=Vector3(10,5,0)
	audio._event_wait=999
	var enemy_count: int=get_nodes_in_group("enemies").size()
	check(audio.trigger_event(),"Sparse event can use an existing nearby anchor")
	check(not audio.trigger_event(),"Only one atmospheric event plays at a time")
	check(get_nodes_in_group("enemies").size()==enemy_count and ship.shield==100,"Events do not spawn enemies or cause damage")
	audio._event.stop()
	audio._event_busy=0
	var events_before: int=audio.event_count
	audio._event_wait=.001
	await frames(2)
	check(audio.event_count==events_before+1,"Timer schedules atmospheric events")
	check(audio._event_wait>audio.event_interval_min-.1 and audio._event_wait<=audio.event_interval_max,"Intervals stay in configured random range")
	audio._event.stop()
	audio.enabled=false
	audio._event_wait=.001
	audio._tick()
	events_before=audio.event_count
	await frames(2)
	check(audio.event_count==events_before,"Disabled atmosphere does not schedule playback")
	audio.enabled=true
	for loop in audio.loops:
		check(loop.player.max_polyphony==1 and loop.player.max_distance==0,"Bounded positional sources")
		check(loop.player.max_db<=audio.ambience_volume_db,"Near-field ambience has a loudness cap")
	for kind in ["ventilation","machinery","electrical","creak","crash","pipe","startup","malfunction"]:
		var stream := Sounds.sound(kind)
		check(stream==Sounds.sound(kind),"Ambience PCM is cached: "+kind)
		var peak: int=0
		for index in range(stream.data.size()/2): peak=maxi(peak,absi(stream.data.decode_s16(index*2)))
		check(peak<12000,"Quiet normalized source headroom: "+kind)
		if kind in ["ventilation","machinery","electrical"]:
			check(absi(stream.data.decode_s16(0)-stream.data.decode_s16(stream.data.size()-2))<1500,"Seamless loop: "+kind)
	var slots: int=audio.sources.size()
	for index in range(3):
		level.reset_encounter()
		await frames(4)
		audio._tick()
	check(audio.sources.size()==slots,"Encounter restart reuses slots without source growth")
	check(audio.sources.size()<=audio.source_slots,"Fixed occlusion bus budget")
	var custom_owner := Node3D.new()
	level.add_child(custom_owner)
	var first := AudioStreamPlayer3D.new()
	var second := AudioStreamPlayer3D.new()
	custom_owner.add_child(first)
	custom_owner.add_child(second)
	check(audio.register_source(custom_owner,[first]),"Custom emitter registration")
	check(audio.register_source(custom_owner,[first,second]),"Additional streams share the existing owner slot")
	check(first.bus==second.bus and audio.sources.size()==slots+1,"Owner grouping does not allocate per-stream buses")
	custom_owner.queue_free()
	await frames(2)
	audio._tick()
	check(audio.sources.size()==slots,"Custom emitter teardown releases its slot")
	print("Environment audio: ","PASS" if failures==0 else "%d failures"%failures,"; sources=",audio.sources.size()," buses=",AudioServer.bus_count)
	level.queue_free()
	await create_timer(.25).timeout
	check(AudioServer.bus_count==maxi(bus_count,2),"Owned buses are removed on teardown; shared IndustrialFX remains")
	quit(0 if failures==0 else 1)
