extends SceneTree
## Rendered test: measures the actual mixed waveform, not only scheduler variables.
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run parking_audio_runtime.gd with a real display/audio driver.")
		quit(1)
		return
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	var sensor = level.get_node("Ship/Proximity")
	var ship = level.get_node("Ship")
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "ParkingAudioTest")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus, capture)
	sensor._audio.bus = "ParkingAudioTest"
	for distance in [4.5, 3.0, 1.5, 0.7, 0.45, 0.25]:
		ship.reset_ship()
		ship.position = Vector3(0, 0, -49.23 + distance)
		sensor.clear_warnings()
		await create_timer(0.15).timeout
		capture.clear_buffer()
		var samples := PackedVector2Array()
		var finish := Time.get_ticks_msec() + 3100
		while Time.get_ticks_msec() < finish:
			await process_frame
			var available := capture.get_frames_available()
			if available > 0:
				samples.append_array(capture.get_buffer(available))
		var window := int(AudioServer.get_mix_rate() * 0.01)
		var was_active := false
		var starts: Array[float] = []
		var active_windows: int = 0
		var peak: float = 0.0
		var windows: int = 0
		for offset in range(0, samples.size() - window, window):
			var block_peak: float = 0.0
			for index in range(offset, offset + window):
				block_peak = maxf(block_peak, absf(samples[index].x))
			peak = maxf(peak, block_peak)
			var active := block_peak > 0.003
			if active and not was_active:
				starts.append(float(offset) / AudioServer.get_mix_rate())
			if active:
				active_windows += 1
			was_active = active
			windows += 1
		var valid := samples.size() > 1000 and peak < 0.99
		var measured_interval: float = 0.0
		if distance > 4.0:
			valid = valid and active_windows == 0
		elif distance < 0.4:
			valid = valid and active_windows > windows * 0.95
		else:
			valid = valid and starts.size() >= 3 and active_windows < windows * 0.8
			if starts.size() >= 3:
				measured_interval = (starts[-1] - starts[0]) / (starts.size() - 1)
				valid = valid and absf(measured_interval - sensor.beep_interval(distance)) < 0.055
		print("Mixed audio %.2fm: interval=%.3fs pulses=%d active=%d/%d peak=%.4f %s" % [distance, measured_interval, starts.size(), active_windows, windows, peak, "PASS" if valid else "FAIL"])
		if not valid:
			failures += 1
	level.queue_free()
	await create_timer(0.1).timeout
	var remaining_bus := AudioServer.get_bus_index("ParkingAudioTest")
	if remaining_bus >= 0: AudioServer.remove_bus(remaining_bus)
	print("Parking mixed audio: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
