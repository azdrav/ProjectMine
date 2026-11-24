extends Control
## Small independent cockpit panel. All six axes remain visible; only risks light up.
@export var sensor_path: NodePath
var _message: String = ""
var _message_time: float = 0.0
var _refresh_time: float = 0.0
@onready var sensor = get_node_or_null(sensor_path)
const CELLS := ["UP", "FWD", "DOWN", "LEFT", "BACK", "RIGHT"]
const COLORS := [Color(0.34, 0.48, 0.54), Color(1.0, 0.84, 0.3), Color(1.0, 0.48, 0.16), Color(1.0, 0.20, 0.20)]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(sensor):
		sensor.toggled.connect(_on_toggled)

func _on_toggled(active: bool) -> void:
	_message = "PROXIMITY " + ("ENABLED" if active else "DISABLED")
	_message_time = 2.0
	queue_redraw()

func _process(delta: float) -> void:
	_message_time = maxf(0.0, _message_time - delta)
	_refresh_time += delta
	if _refresh_time >= 0.05:
		_refresh_time = 0.0
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(sensor):
		return
	var font := ThemeDB.fallback_font
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(12, 22), "PROXIMITY  /  P " + ("ON" if sensor.enabled else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.85, 0.9))
	for index in range(CELLS.size()):
		var direction: String = CELLS[index]
		var reading: Dictionary = sensor.readings.get(direction, {})
		var severity: int = reading.get("severity", 0) if sensor.enabled else 0
		var color: Color = COLORS[clampi(severity, 0, 3)]
		var origin := Vector2(12 + (index % 3) * 82, 34 + (index / 3) * 30)
		var nearest: bool = direction == sensor.nearest_direction and sensor.enabled
		draw_rect(Rect2(origin, Vector2(76, 25)), Color(color, 0.10 if severity > 0 else 0.025))
		draw_rect(Rect2(origin, Vector2(76, 25)), color, false, 2.0 if nearest else 1.0)
		draw_string(font, origin + Vector2(5, 17), direction, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	var summary := "CLEAR" if sensor.enabled else "OFF"
	if sensor.enabled and not sensor.nearest_direction.is_empty():
		summary = "%s  %.1f m" % [sensor.nearest_direction, sensor.nearest_clearance]
		if is_finite(sensor.nearest_ttc):
			summary += "  /  %.1f s" % sensor.nearest_ttc
	if _message_time > 0.0:
		summary = _message
	draw_string(font, Vector2(12, 119), summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLORS[sensor.severity] if sensor.enabled else COLORS[0])

func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.015, 0.035, 0.055, 0.78)
	panel.set_corner_radius_all(4)
	return panel
