extends Node
## One comfort setting for every visual feedback channel; independent of game saves.
signal changed(value: float)
const PATH := "user://feedback_settings.cfg"
var intensity: float = 0.55:
	set(value):
		intensity = clampf(value,0.0,1.0) if is_finite(value) else 0.55
		if intensity > 0.0: _last_enabled = intensity
		changed.emit(intensity)
var _last_enabled := 0.55
var notice_time := 0.0
func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		var saved: Variant = config.get_value("comfort","camera_shake",0.55)
		if saved is float or saved is int: intensity = float(saved)
func set_intensity(value: float, persist: bool = true) -> void:
	intensity = value
	notice_time = 2.5
	if persist:
		var config := ConfigFile.new()
		config.set_value("comfort","camera_shake",intensity)
		if config.save(PATH) != OK: push_warning("Camera comfort setting could not be saved.")
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F6: set_intensity(0.0 if intensity > 0.0 else _last_enabled)
		KEY_BRACKETLEFT: set_intensity(intensity-0.1)
		KEY_BRACKETRIGHT: set_intensity(intensity+0.1)
		_: return
	get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	notice_time = maxf(0.0,notice_time-delta)
