extends Node3D
## Ship-local lights: no camera-only aiming, physics queries or shadow maps.
signal toggled(active: bool)
@export var enabled: bool = true:
	set(value):
		enabled=value
		if is_node_ready(): _apply()
@export_range(0.0,8.0) var intensity: float = 3.0:
	set(value):
		intensity=value
		if is_node_ready(): _apply()
@export_range(5.0,30.0) var light_range: float = 18.0:
	set(value):
		light_range=value
		if is_node_ready(): _apply()
@export var color: Color = Color(1.0,0.90,0.74):
	set(value):
		color=value
		if is_node_ready(): _apply()
@export_range(20.0,60.0) var beam_angle: float = 42.0:
	set(value):
		beam_angle=value
		if is_node_ready(): _apply()
var lights: Array[SpotLight3D] = []
func _ready() -> void:
	for side in [-1.0,1.0]:
		var light := SpotLight3D.new()
		light.name="Left" if side < 0 else "Right"
		light.position=Vector3(side*.22,-.10,-.25)
		light.shadow_enabled=false
		light.spot_attenuation=0.5
		light.spot_angle_attenuation=1.5
		add_child(light)
		lights.append(light)
	_apply()
func _apply() -> void:
	for light in lights:
		light.visible=enabled
		light.light_energy=intensity
		light.light_color=color
		light.spot_range=light_range
		light.spot_angle=beam_angle
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_L:
		enabled=not enabled
		toggled.emit(enabled)
		get_viewport().set_input_as_handled()
