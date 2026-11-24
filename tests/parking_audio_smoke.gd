extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		failures += 1
func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	await frames(4)
	var ship = level.get_node("Ship")
	var sensor = ship.get_node("Proximity")
	# Real collider measurements at rest; these must not depend on closing speed.
	for distance in [4.5, 3.0, 1.5, 0.7, 0.25]:
		ship.reset_ship()
		sensor.clear_warnings()
		ship.position = Vector3(0, 0, -49.23 + distance)
		await frames(4)
		sensor.scan(1.0)
		if distance > 4.0:
			check(sensor.severity == 0, "Outside 4m is silent")
		else:
			check(sensor.nearest_direction == "FWD", "Nearest forward obstacle at %.2fm" % distance)
			check(absf(sensor.nearest_clearance - distance) < 0.025, "Hull clearance %.2fm" % distance)
			check(sensor.severity > 0 and is_inf(sensor.nearest_ttc), "Stationary parking warning %.2fm" % distance)
			check((sensor.severity == 3) == (distance < 0.4), "Continuous only below critical %.2fm" % distance)
	var samples := {4.0: 1.2, 3.0: 0.95, 2.0: 0.7, 1.5: 0.5, 1.0: 0.3, 0.7: 0.2, 0.4: 0.1}
	for distance in samples:
		var interval: float = sensor.beep_interval(distance)
		check(absf(interval - samples[distance]) < 0.001, "Interpolated cadence at %.2fm" % distance)
		check(sensor.pulse_duration(interval) < interval - 0.03, "Separate pulse at %.2fm" % distance)
	for boundary in [1.0, 2.0]:
		check(absf(sensor.beep_interval(boundary - 0.001) - sensor.beep_interval(boundary + 0.001)) < 0.002, "Smooth boundary %.1fm" % boundary)
	check(sensor.beep_interval(3.0, 0.2, 10.0) < sensor.beep_interval(3.0), "Rapid approach increases urgency")
	check(sensor.beep_interval(3.0, INF, 0.0) == sensor.beep_interval(3.0), "Stopping restores distance cadence, not silence")
	check(sensor.risk(0.43, 0.0, INF, 3) == 3 and sensor.risk(0.46, 0.0, INF, 3) == 2, "Continuous-tone release hysteresis")
	check(sensor.risk(4.03, 0.0, INF, 1) == 1 and sensor.risk(4.06, 0.0, INF, 1) == 0, "Range release hysteresis")
	# Test the real envelope/scheduler with deterministic frame steps, even headlessly.
	sensor.set_process(false)
	sensor.set_physics_process(false)
	sensor.clear_warnings()
	sensor.severity = 1
	sensor.nearest_direction = "FWD"
	sensor.nearest_clearance = 3.0
	sensor.nearest_ttc = INF
	for distance in [3.0, 1.5, 0.7, 0.25]:
		sensor.clear_warnings()
		sensor.severity = sensor.risk(distance, 0.0, INF, 0)
		sensor.nearest_direction = "FWD"
		sensor.nearest_clearance = distance
		var starts: Array[float] = []
		var silent_frames: int = 0
		var previous_pulse: float = 0.0
		for frame in range(360):
			sensor.update_audio(1.0 / 120.0, true)
			if sensor._tone_remaining > previous_pulse:
				starts.append(float(frame) / 120.0)
			if sensor._gain == 0.0:
				silent_frames += 1
			previous_pulse = sensor._tone_remaining
		if distance < 0.4:
			check(silent_frames == 0, "Continuous at stationary %.2fm" % distance)
		else:
			check(starts.size() >= 3 and silent_frames > 0, "Audible separated pulses at stationary %.2fm" % distance)
			for index in range(1, starts.size()):
				check(absf(starts[index] - starts[index - 1] - sensor.beep_interval(distance)) < 0.02, "Scheduled interval %.2fm" % distance)
	# Faster approach must shorten an already scheduled slow interval immediately.
	sensor.clear_warnings()
	sensor.severity = 1
	sensor.nearest_direction = "FWD"
	sensor.nearest_clearance = 3.0
	sensor.update_audio(0.01, true)
	for frame in range(20):
		sensor.update_audio(0.01, true)
	sensor.nearest_clearance = 0.7
	sensor.update_audio(0.01, true)
	check(sensor._tone_remaining > 0.0, "Cadence responds without waiting for old slow deadline")
	sensor.enabled = false
	check(not sensor._audio.playing, "Toggle stops parking audio")
	for interval in [1.2, 0.7, 0.3, 0.1]:
		sensor.beep_duration = 2.0
		check(sensor.pulse_duration(interval) <= interval - 0.034, "Oversized pulse still retains gap")
	print("Parking audio smoke: %s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	level.queue_free()
	await frames(2)
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
