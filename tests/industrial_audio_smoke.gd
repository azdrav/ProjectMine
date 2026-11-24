extends SceneTree
const Sounds = preload("res://scripts/audio/industrial_sounds.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1
func step(ship: CharacterBody3D, velocity: Vector3, count: int) -> void:
	for index in range(count):
		await physics_frame
		ship.velocity=velocity
		ship.move_and_slide()
		var resolved := ship.velocity
		var pose := ship.global_transform
		ship.flight_contact_sample.emit(velocity,1.0/60)
		check(ship.velocity==resolved and ship.global_transform==pose,"Audio observer never changes physics response")
func run() -> void:
	for kind in ["player_fire","enemy_fire","shield","impact","scrape"]:
		var sound := Sounds.sound(kind)
		check(sound==Sounds.sound(kind),"PCM is cached: "+kind)
		var peak: float = 0.0
		for sample in range(sound.data.size()/2): peak=maxf(peak,absf(sound.data.decode_s16(sample*2)/32767.0))
		check(peak<=.651,"Sample headroom: "+kind)
		if kind=="scrape":
			check(sound.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Continuous loop")
			check(absf(sound.data.decode_s16(0)-sound.data.decode_s16(sound.data.size()-2))<3000,"Seamless loop boundary")
		sound.save_to_wav("/tmp/projectmine-05-"+kind+".wav")
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters=false
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	var ship: CharacterBody3D=level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled=false
	var audio = ship.get_node("Audio")
	var wall := StaticBody3D.new()
	wall.collision_layer=1
	wall.position=Vector3(205,0,0)
	var shape := BoxShape3D.new()
	shape.size=Vector3(1,40,100)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	wall.add_child(collider)
	level.add_child(wall)
	await physics_frame
	ship.position=Vector3(203.9,0,0)
	await step(ship,Vector3.RIGHT,10)
	check(audio.impact_events==0,"Gentle contact is silent")
	audio.reset_audio()
	ship.position=Vector3(203.9,0,0)
	ship.basis=Basis.from_euler(Vector3(.7,.4,1.2))
	await step(ship,Vector3(25,0,0),1)
	check(audio.impact_events==1 and audio.normal_speed>24.9,"Pitched/rolled hull impact uses incoming normal speed before resolution")
	await step(ship,Vector3.ZERO,20)
	check(audio.impact_events==1,"Resting contact does not repeat impacts")
	await step(ship,Vector3(.2,0,-8),25)
	check(audio.scrape_gain>.25 and audio.scrape_starts==1,"Sustained sliding fades in a single loop")
	check(audio.impact_events==1,"Tangential sliding does not trigger a loud normal impact")
	var gain: float=audio.scrape_gain
	await step(ship,Vector3(0,0,-8),20)
	check(audio.scrape_starts==1 and audio.scrape_gain>.25,"Exactly parallel contact retains scraping without restarts")
	await step(ship,Vector3(.2,0,-16),15)
	check(audio.scrape_gain>gain,"Faster slide increases gain")
	await step(ship,Vector3.ZERO,20)
	check(audio.scrape_gain==0 and not audio.scrape.playing,"Stopping against wall ends scrape")
	await step(ship,Vector3(.2,0,-8),20)
	check(audio.scrape_starts==2,"New slide restarts once")
	await step(ship,Vector3(-6,0,-8),20)
	check(audio.scrape_gain==0 and not audio.scrape.playing,"Separation ends scrape")
	audio.reset_audio()
	var obstacle := CharacterBody3D.new()
	obstacle.collision_layer=4
	obstacle.collision_mask=2
	obstacle.position=Vector3(304,0,0)
	var obstacle_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius=1.0
	obstacle_shape.shape=sphere
	obstacle.add_child(obstacle_shape)
	level.add_child(obstacle)
	await physics_frame
	ship.position=Vector3(302.4,0,0)
	var impacts_before: int=audio.impact_events
	await step(ship,Vector3.RIGHT*25,1)
	check(audio.impact_events==impacts_before+1,"Other physical bodies can produce a hull impact")
	check(audio._scrape_target==0,"A moving obstacle does not produce wall scraping")
	ship.take_damage(5)
	var quiet: float=audio.shield.volume_db
	ship.take_damage(5)
	check(audio.shield_events==1,"Rapid hits cannot stack loud shield sounds")
	await step(ship,Vector3.ZERO,8)
	ship.take_damage(25)
	check(audio.shield.volume_db>quiet and ship.shield==65,"Damage intensity scales audio without changing shield math")
	ship.fire()
	check(audio.weapon.stream==Sounds.sound("player_fire") and audio.weapon.max_polyphony==2,"Player fire uses cached bounded-polyphony weapon channel")
	ship.reset_ship()
	check(audio.scrape_gain==0 and not audio.scrape.playing,"Reset clears contact audio")
	print("Industrial audio: ","PASS" if failures==0 else "%d failures"%failures)
	level.queue_free()
	await create_timer(.2).timeout
	quit(0 if failures==0 else 1)
