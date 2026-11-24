extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	if not condition:
		push_error(label)
		failures += 1
func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
func motion(ship: Node, displacement: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = displacement
	ship._input(event)
func mouse_button(ship: Node, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	ship._input(event)
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	await frames(4)
	var ship = level.get_node("Ship")
	var sensor = ship.get_node("Proximity")
	ship.acceleration = 0.0
	ship.deceleration = 0.0
	var center := Vector3(200, 0, 0)
	ship.position = center
	sensor.collision_mask = 4 | 2 # Include the ship layer to verify its explicit exclusion.
	for axis in sensor.DIRECTIONS.values():
		var body := StaticBody3D.new()
		body.collision_layer = 4
		body.position = center + axis * 4.5
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(12, 12, 0.2)
		collider.shape = shape
		body.basis = Basis.looking_at(axis, Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP)
		body.add_child(collider)
		level.add_child(body)
	await frames(4)
	sensor.scan(1.0)
	for direction in sensor.DIRECTIONS:
		check(absf(sensor.readings[direction].clearance - 3.83) < 0.03, "Hull clearance " + direction)
		check(sensor.readings[direction].severity == 1, "Stationary distance warning " + direction)
	sensor.collision_mask = 0
	sensor.scan(1.0)
	check(sensor.nearest_direction.is_empty() and sensor.severity == 0, "Collision mask excludes non-obstacles")
	sensor.collision_mask = 4 | 2
	# A trigger area on an obstacle layer is deliberately ignored.
	var trigger := Area3D.new()
	trigger.collision_layer = 4
	trigger.position = center
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.shape = SphereShape3D.new()
	trigger_shape.shape.radius = 1.0
	trigger.add_child(trigger_shape)
	level.add_child(trigger)
	await frames(3)
	sensor.scan(1.0)
	check(sensor.readings.FWD.clearance > 3.8, "Area triggers are not obstacles")
	ship.position = center + Vector3(0, 0, -1)
	ship.basis = Basis(Vector3.UP, PI / 2)
	await frames(3)
	sensor.scan(1.0)
	check(absf(sensor.readings.RIGHT.clearance - 2.83) < 0.03, "Sensors rotate with actual ship axes")
	ship.position = center
	ship.basis = Basis.IDENTITY
	ship.velocity = Vector3.RIGHT * 4.0
	await frames(3)
	sensor.scan(1.0)
	check(sensor.readings.RIGHT.closing_speed > 3.9, "Actual lateral closing speed")
	check(sensor.readings.RIGHT.severity > 0, "Lateral drift warns on right")
	check(sensor.readings.FWD.closing_speed < 0.01 and sensor.readings.FWD.severity == 1, "Parallel motion keeps distance warning without TTC boost")
	check(sensor.readings.LEFT.closing_speed == 0.0 and sensor.readings.LEFT.severity == 1, "Receding preserves distance warning")
	check(absf(sensor.readings.RIGHT.ttc - sensor.readings.RIGHT.clearance / 4.0) < 0.01, "TTC uses projected actual speed")
	ship.velocity = Vector3.ZERO
	ship.position = center + Vector3(3.58, 0, 0)
	await frames(4)
	sensor.scan(1.0)
	check(sensor.readings.RIGHT.severity == 3, "Critical hull proximity warns at rest")
	check(sensor.nearest_direction == "RIGHT", "Nearest relevant axis")
	check(sensor.risk(0.43, 0.0, INF, 3) == 3, "Critical distance hysteresis")
	check(sensor.risk(1.1, 0.0, INF, 3) == 2, "Stationary warning returns to beeping beyond critical hysteresis")
	check(sensor.risk(3.5, 5.0, 0.7, 0) == 1, "Warning band")
	check(sensor.risk(3.5, 10.0, 0.35, 0) == 2, "TTC escalates urgency outside 2m")
	check(sensor.risk(1.5, 0.0, INF, 0) == 2, "Stationary obstacles retain distance warning")
	var wave: AudioStreamWAV = sensor._audio.stream
	var maximum: int = 0
	for offset in range(0, wave.data.size(), 2):
		maximum = maxi(maximum, absi(wave.data.decode_s16(offset)))
	check(maximum < 6000 and maximum > 5000, "Oscillator headroom")
	check(sensor._audio.max_polyphony == 1, "Single non-overlapping audio voice")
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_P
	toggle.pressed = true
	sensor._unhandled_key_input(toggle)
	check(not sensor.enabled and sensor.severity == 0 and not sensor._audio.playing, "P disables and silences module")
	check(level.get_node("HUD/ProximityIndicator")._message.contains("DISABLED"), "Toggle status message")
	sensor._unhandled_key_input(toggle)
	check(sensor.enabled, "P re-enables module")
	# Parking mode also warns about nearby parallel tunnel sides.
	ship.position = Vector3(0, 0, -25)
	ship.velocity = Vector3(0, 0, -10)
	sensor.collision_mask = 1
	await frames(4)
	sensor.scan(1.0)
	check(sensor.severity == 1, "Centered tunnel sides produce slow parking beeps")
	ship.position = Vector3(0, 39, -62)
	ship.velocity = Vector3(0, 10, -20).normalized() * 10.0
	await frames(4)
	sensor.scan(1.0)
	check(sensor.severity > 0 and sensor.severity < 3, "Angled tunnel sides keep distance beeps without continuous tone")
	if DisplayServer.get_name() != "headless":
		sensor.clear_warnings()
		sensor.severity = 1
		sensor.nearest_clearance = 3.8
		sensor.nearest_ttc = 1.1
		sensor._beep_clock = 0.0
		sensor._process(0.01)
		var slow_interval: float = sensor._beep_clock
		sensor.clear_warnings()
		sensor.severity = 2
		sensor.nearest_clearance = 1.0
		sensor.nearest_ttc = 0.2
		sensor._beep_clock = 0.0
		sensor._process(0.01)
		check(sensor._beep_clock < slow_interval, "Higher risk increases beep cadence")
		check(sensor._beep_clock > sensor.beep_duration, "Beeps have nonoverlapping silent gaps")
		sensor.severity = 3
		sensor._process(1.0)
		check(sensor._gain == 1.0, "Critical proximity uses continuous tone")
		sensor.enabled = false
		sensor.enabled = true
		ship.reset_ship()
		ship.capture_mouse()
		motion(ship, Vector2(1000, 1000))
		await frames(2)
		check(ship.basis.is_equal_approx(Basis.IDENTITY), "Recapture discards stale first motion")
		motion(ship, Vector2(100, -50))
		await frames(2)
		var single_step: Basis = ship.basis
		check(ship.rotation.y < 0 and ship.rotation.x > 0, "Mouse rotates actual ship yaw and pitch")
		check(ship.get_node("Camera3D").basis.is_equal_approx(Basis.IDENTITY), "Camera stays attached without independent rotation")
		ship.reset_ship()
		for index in range(10):
			motion(ship, Vector2(10, -5))
		await frames(2)
		check(ship.basis.is_equal_approx(single_step), "Mouse displacement is accumulated without delta scaling")
		ship.reset_ship()
		ship.invert_mouse_y = true
		motion(ship, Vector2(0, -50))
		await frames(2)
		check(ship.rotation.x < 0, "Mouse Y inversion")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		ship._input(escape)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases mouse")
		var before: Basis = ship.basis
		motion(ship, Vector2(500, 500))
		await frames(2)
		check(ship.basis.is_equal_approx(before), "Released cursor does not rotate ship")
		mouse_button(ship, true)
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and ship._recapture_click, "Click recaptures without firing")
		mouse_button(ship, false)
		check(not ship._recapture_click, "Next click may fire")
		ship._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss releases cursor")
	else:
		print("Mouse capture checks require a display; run this script without --headless.")
	print("Proximity / mouse smoke: %s" % ("PASS" if failures == 0 else "%d failure(s)" % failures))
	level.queue_free()
	await frames(2)
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
