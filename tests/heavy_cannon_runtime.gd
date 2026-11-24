extends SceneTree
## Capture the real final mix during production-cadence cannon firing and ambience.
class TestShip extends "res://scripts/player/ship.gd":
	func _ready() -> void: pass
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A real display and audio driver are required for final-mix capture.")
		quit(1)
		return
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	level.get_node("Ship").set_script(TestShip)
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled = false
	ship.position = Vector3(0,0,-22)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 5.0
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	await create_timer(0.5).timeout
	capture.clear_buffer()
	for i in range(12):
		ship.fire()
		check(ship.last_fired_cannon == i%2,"Live cannon alternation follows actual shot events")
		check(ship.get_node("Camera3D/WeaponEffects")._flashes[i%2].visible,"Muzzle flash begins synchronously with live fire")
		await create_timer(ship.laser_interval).timeout
	await create_timer(0.4).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var sum := 0.0
	for value in samples:
		peak = maxf(peak,maxf(absf(value.x),absf(value.y)))
		sum += (value.x*value.x+value.y*value.y)*0.5
	var rms := sqrt(sum/maxi(1,samples.size()))
	check(samples.size() > 10000 and peak > 0.01,"Live final mix contains audible cannon output")
	check(peak < 0.8 and rms < 0.25,"Rapid fire plus ambience retains final-mix headroom")
	check(ship.get_node("Audio").weapon_events == 12,"No extra audio events or independent firing timer")
	var data := PackedByteArray()
	data.resize(samples.size()*4)
	for i in range(samples.size()):
		data.encode_s16(i*4,roundi(clampf(samples[i].x,-1,1)*32767))
		data.encode_s16(i*4+2,roundi(clampf(samples[i].y,-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = data
	wav.save_to_wav("/tmp/projectmine081-cannon-mix.wav")
	print("CANNON MIX ",JSON.stringify({"samples":samples.size(),"peak":peak,"rms":rms,"shots":12,"audio_driver":AudioServer.get_driver_name(),"capture":"/tmp/projectmine081-cannon-mix.wav"}))
	AudioServer.remove_bus_effect(0,slot)
	level.queue_free()
	await create_timer(0.3).timeout
	print("Heavy cannon runtime: %s" % ("PASS" if failures == 0 else str(failures)+" failures"))
	quit(0 if failures == 0 else 1)
