extends Node3D
## Independent sensor/audio module; queries run after the parent's flight step.
signal toggled(active: bool)

const DIRECTIONS := {"FWD": Vector3.FORWARD, "BACK": Vector3.BACK, "LEFT": Vector3.LEFT, "RIGHT": Vector3.RIGHT, "UP": Vector3.UP, "DOWN": Vector3.DOWN}
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			clear_warnings()
			toggled.emit(enabled)
@export_group("Detection")
@export_range(0.1, 50.0) var detection_distance: float = 4.0
@export_flags_3d_physics var collision_mask: int = 1
## Additional hull allowance; the SphereShape3D/BoxShape3D is measured automatically.
@export_range(0.0, 2.0) var hull_margin: float = 0.02
@export_range(5.0, 60.0) var scan_rate: float = 30.0
@export_group("Risk thresholds")
@export var warning_range: float = 4.0
@export var urgent_range: float = 2.0
@export var rapid_range: float = 1.0
@export var critical_range: float = 0.4
@export var minimum_closing_speed: float = 0.25
@export var warning_ttc: float = 1.2
@export var urgent_ttc: float = 0.5
@export var distance_hysteresis: float = 0.05
@export var sensor_switch_margin: float = 0.15
@export var ttc_hysteresis: float = 0.15
@export var release_delay: float = 0.18
@export_group("Audio")
@export_range(-60.0, 0.0) var audio_volume_db: float = -12.0
@export_range(200.0, 2000.0) var tone_frequency: float = 880.0
@export var slow_beep_interval: float = 1.2
@export var medium_beep_interval: float = 0.7
@export var rapid_beep_interval: float = 0.3
@export var fast_beep_interval: float = 0.1
## Maximum fractional shortening from TTC; distance always supplies the base cadence.
@export_range(0.0, 0.75) var ttc_cadence_boost: float = 0.35
@export var beep_duration: float = 0.065

var readings: Dictionary = {}
var severity: int = 0
var nearest_direction: String = ""
var nearest_clearance: float = INF
var nearest_ttc: float = INF
var rays: Dictionary = {}
var _release_timers: Dictionary = {}
var _scan_time: float = 0.0
var _beep_clock: float = 0.0
var _scheduled_interval: float = 0.0
var _tone_remaining: float = 0.0
var _gap_remaining: float = 0.0
var _gain: float = 0.0
var _audio: AudioStreamPlayer
@onready var ship: CharacterBody3D = get_parent() as CharacterBody3D
@onready var hull: CollisionShape3D = ship.get_node("CollisionShape3D")

func _ready() -> void:
	process_physics_priority = 10
	for direction in DIRECTIONS:
		var ray := RayCast3D.new()
		ray.name = direction
		ray.enabled = false # Manually refreshed at scan_rate, rather than twice per step.
		ray.collide_with_areas = false
		ray.add_exception(ship)
		add_child(ray)
		rays[direction] = ray
		_release_timers[direction] = 0.0
	_setup_audio()
	clear_warnings()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P:
		enabled = not enabled
		get_viewport().set_input_as_handled()

func clear_warnings() -> void:
	severity = 0
	nearest_direction = ""
	nearest_clearance = INF
	nearest_ttc = INF
	for direction in DIRECTIONS:
		readings[direction] = {"clearance": INF, "closing_speed": 0.0, "ttc": INF, "severity": 0}
		_release_timers[direction] = 0.0
	_beep_clock = 0.0
	_scheduled_interval = 0.0
	_tone_remaining = 0.0
	_gap_remaining = 0.0
	_gain = 0.0
	if _audio:
		_audio.stop()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_scan_time += delta
	if _scan_time >= 1.0 / maxf(scan_rate, 1.0):
		scan(_scan_time)
		_scan_time = 0.0

func hull_extent(direction: Vector3) -> float:
	# Shape is expressed in the ship's local coordinate system.
	var local_direction := hull.basis.orthonormalized().inverse() * direction
	var extent: float = 0.55
	if hull.shape is SphereShape3D:
		extent = hull.shape.radius * hull.scale.abs()[hull.scale.abs().max_axis_index()]
	elif hull.shape is BoxShape3D:
		extent = local_direction.abs().dot(hull.shape.size * hull.scale.abs() * 0.5)
	return maxf(0.0, hull.position.dot(direction) + extent + hull_margin)

func risk(clearance: float, closing: float, ttc: float, previous: int) -> int:
	var range_margin := distance_hysteresis if previous > 0 else 0.0
	if clearance > minf(warning_range, detection_distance) + range_margin:
		return 0
	var critical_margin := distance_hysteresis if previous == 3 else 0.0
	if clearance <= critical_range + critical_margin:
		return 3
	var urgent_margin := distance_hysteresis if previous >= 2 else 0.0
	var time_margin := ttc_hysteresis if previous >= 2 else 0.0
	if clearance <= urgent_range + urgent_margin or (closing > minimum_closing_speed and ttc <= urgent_ttc + time_margin):
		return 2
	return 1 # Parking warnings remain active while stationary, parallel or receding.

func beep_interval(clearance: float, ttc: float = INF, closing: float = 0.0) -> float:
	# Continuous interpolation at every band boundary, in seconds between onsets.
	var interval: float
	if clearance >= urgent_range:
		interval = lerpf(medium_beep_interval, slow_beep_interval, clampf((clearance - urgent_range) / maxf(warning_range - urgent_range, 0.001), 0.0, 1.0))
	elif clearance >= rapid_range:
		interval = lerpf(rapid_beep_interval, medium_beep_interval, clampf((clearance - rapid_range) / maxf(urgent_range - rapid_range, 0.001), 0.0, 1.0))
	else:
		interval = lerpf(fast_beep_interval, rapid_beep_interval, clampf((clearance - critical_range) / maxf(rapid_range - critical_range, 0.001), 0.0, 1.0))
	if closing > minimum_closing_speed:
		var urgency := 1.0 - clampf(ttc / maxf(warning_ttc, 0.001), 0.0, 1.0)
		interval *= 1.0 - urgency * ttc_cadence_boost
	return maxf(0.06, clampf(interval, maxf(0.06, fast_beep_interval), maxf(slow_beep_interval, fast_beep_interval)))

func pulse_duration(interval: float) -> float:
	# Keep at least 35 ms of silence, even with an excessively long configured pulse.
	return clampf(beep_duration, 0.01, maxf(0.01, interval - 0.035))

func scan(delta: float) -> void:
	var previous_nearest := nearest_direction
	severity = 0
	nearest_direction = ""
	nearest_clearance = INF
	nearest_ttc = INF
	var actual_velocity := ship.get_real_velocity()
	for direction in DIRECTIONS:
		var ray: RayCast3D = rays[direction]
		var axis: Vector3 = DIRECTIONS[direction]
		var extent := hull_extent(axis)
		ray.collision_mask = collision_mask
		ray.target_position = axis * (extent + maxf(detection_distance, 0.1) + distance_hysteresis)
		ray.force_raycast_update()
		var clearance: float = INF
		var closing: float = 0.0
		var ttc: float = INF
		if ray.is_colliding():
			clearance = maxf(0.0, ray.global_position.distance_to(ray.get_collision_point()) - extent)
			# Wall-normal projection rejects parallel motion, including on angled surfaces.
			closing = maxf(0.0, -actual_velocity.dot(ray.get_collision_normal()))
			if closing > 0.0:
				var normal: Vector3 = ray.get_collision_normal()
				var local_normal: Vector3 = (global_basis.inverse() * -normal).normalized()
				var normal_clearance := maxf(0.0, (ray.get_collision_point() - ray.global_position).dot(-normal) - hull_extent(local_normal))
				ttc = normal_clearance / closing
		var previous: int = readings[direction].severity
		var next := risk(clearance, closing, ttc, previous)
		if next < previous:
			_release_timers[direction] += delta
			if _release_timers[direction] < release_delay and is_finite(clearance):
				next = previous
		else:
			_release_timers[direction] = 0.0
		readings[direction] = {"clearance": clearance, "closing_speed": closing, "ttc": ttc, "severity": next}
		severity = maxi(severity, next)
		if next > 0 and clearance < nearest_clearance:
			nearest_direction = direction
			nearest_clearance = clearance
			nearest_ttc = ttc

	# Retain the selected axis through small ties, as well as stabilizing severity.
	if readings.has(previous_nearest):
		var retained: Dictionary = readings[previous_nearest]
		if retained.severity > 0 and retained.clearance <= nearest_clearance + sensor_switch_margin:
			nearest_direction = previous_nearest
			nearest_clearance = retained.clearance
			nearest_ttc = retained.ttc

func _setup_audio() -> void:
	# One seamless, quiet PCM oscillator. A gain envelope gates beeps without clicks.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var cycles := maxi(1, roundi(tone_frequency / 10.0))
	var sample_count := 2205
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	for sample in range(sample_count):
		pcm.encode_s16(sample * 2, roundi(sin(TAU * cycles * sample / sample_count) * 0.18 * 32767.0))
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_count
	_audio = AudioStreamPlayer.new()
	_audio.stream = stream
	_audio.max_polyphony = 1
	_audio.volume_db = -80.0
	add_child(_audio)

func _process(delta: float) -> void:
	update_audio(delta, DisplayServer.window_is_focused())

func update_audio(delta: float, has_focus: bool) -> void:
	var active := enabled and severity > 0 and has_focus
	if active and not _audio.playing:
		_audio.volume_db = -80.0
		_audio.play()
	_beep_clock = maxf(-0.05, _beep_clock - delta)
	var was_pulsing := _tone_remaining > 0.0
	_tone_remaining = maxf(0.0, _tone_remaining - delta)
	_gap_remaining = 0.025 if was_pulsing and _tone_remaining <= 0.0 else maxf(0.0, _gap_remaining - delta)
	if active and severity < 3:
		var closing: float = readings.get(nearest_direction, {}).get("closing_speed", 0.0)
		var interval := beep_interval(nearest_clearance, nearest_ttc, closing)
		if _scheduled_interval > 0.0:
			# Preserve elapsed time, but react immediately as the wall gets closer.
			_beep_clock = maxf(-0.05, _beep_clock + interval - _scheduled_interval)
		_scheduled_interval = interval
		if _beep_clock <= 0.0 and _tone_remaining <= 0.0 and _gap_remaining <= 0.0:
			# Carry small frame-time overshoot to keep the average cadence accurate.
			_beep_clock = interval + minf(0.0, _beep_clock)
			_tone_remaining = pulse_duration(interval)
	var sounding := active and (severity == 3 or _tone_remaining > 0.0)
	_gain = move_toward(_gain, 1.0 if sounding else 0.0, delta / 0.012)
	_audio.volume_db = clampf(audio_volume_db, -60.0, 0.0) + linear_to_db(maxf(0.0001, _gain))
	if not active and _gain <= 0.0:
		_audio.stop()
		_beep_clock = 0.0
		_scheduled_interval = 0.0
		_tone_remaining = 0.0
		_gap_remaining = 0.0

func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
