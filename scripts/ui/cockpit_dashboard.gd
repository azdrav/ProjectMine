extends Control
## Native UI instruments. Rings are six-axis sonar clearances, never enemy tracking.
class SegmentBar extends ProgressBar:
	func _draw() -> void:
		for i in range(1,16):
			var x := size.x*i/16.0
			draw_line(Vector2(x,1),Vector2(x,size.y-1),Color(0.015,0.04,0.045),2)
class SonarScope extends Control:
	var sensor: Node
	func _draw() -> void:
		var center := size*Vector2(0.5,0.48)
		var radius := minf(size.x*0.34,size.y*0.33)
		var cyan := Color(0.12,0.52,0.53)
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.04,0.044))
		for fraction in [0.33,0.66,1.0]: draw_arc(center,radius*fraction,0,TAU,48,Color(cyan,0.45),1,true)
		draw_line(center-Vector2(radius,0),center+Vector2(radius,0),Color(cyan,0.35))
		draw_line(center-Vector2(0,radius),center+Vector2(0,radius),Color(cyan,0.35))
		var positions := {"FWD":Vector2(0,-1),"BACK":Vector2(0,1),"LEFT":Vector2(-1,0),"RIGHT":Vector2(1,0),"UP":Vector2(-0.7,-0.7),"DOWN":Vector2(0.7,0.7)}
		if not is_instance_valid(sensor): return
		for axis in positions:
			var reading: Dictionary = sensor.readings.get(axis,{})
			var severity: int = reading.get("severity",0) if sensor.enabled else 0
			var color := Color(1,0.22,0.07) if severity >= 2 else Color(1,0.68,0.12) if severity == 1 else cyan
			var direction: Vector2 = positions[axis]
			var point: Vector2 = center+direction*radius
			draw_line(center+direction*radius*0.78,point,color,3 if severity > 0 else 1,true)
			draw_string(ThemeDB.fallback_font,point+direction*8+Vector2(-3,3),str(axis).left(1),HORIZONTAL_ALIGNMENT_LEFT,-1,9,color)
			if severity > 0:
				var clearance: float = reading.get("clearance",sensor.detection_distance)
				draw_circle(center+direction*radius*clampf(clearance/maxf(0.1,sensor.detection_distance),0.15,1.0),3,color)
		var summary := "CLEAR / 6 AXES" if sensor.enabled else "SONAR OFF / P"
		if sensor.enabled and not sensor.nearest_direction.is_empty(): summary = "%s  %.1f m" % [sensor.nearest_direction,sensor.nearest_clearance]
		draw_string(ThemeDB.fallback_font,Vector2(8,size.y-7),summary,HORIZONTAL_ALIGNMENT_CENTER,size.x-16,12,Color(0.4,0.9,0.85))
var ammo_label: Label
var shield_value: Label
var energy_value: Label
var shield_bar: ProgressBar
var energy_bar: ProgressBar
var scope: SonarScope
var warning: Label
var fire_led: ColorRect
var shield_led: ColorRect
var _flicker := 0.0
var _firing := 0.0
var _clock := 0.0
var _refresh := 0.0
var row: HBoxContainer
@onready var ship = get_parent().ship
@onready var weapons = ship.get_node("Camera3D/WeaponEffects")
func panel(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
func instrument(title: String, color: Color) -> Array:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",panel(Color(0.025,0.055,0.06),Color(0.25,0.29,0.28)))
	var column := VBoxContainer.new()
	frame.add_child(column)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",15)
	column.add_child(name_label)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size",28)
	value.modulate = color.lightened(0.4)
	column.add_child(value)
	var bar := SegmentBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background",panel(Color(0.015,0.03,0.035),Color(0.06,0.12,0.12)))
	bar.add_theme_stylebox_override("fill",panel(color,color))
	column.add_child(bar)
	row.add_child(frame)
	return [value,bar]
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_label = Label.new()
	ammo_label.add_theme_font_size_override("font_size",16)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ammo_label)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	add_child(row)
	var shield := instrument("SHIELD / DEFENSE",Color(0.12,0.69,0.78))
	shield_value = shield[0]
	shield_bar = shield[1]
	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_stylebox_override("panel",panel(Color(0.035,0.055,0.055),Color(0.33,0.37,0.34)))
	var column := VBoxContainer.new()
	center.add_child(column)
	var title := Label.new()
	title.text = "PROXIMITY / LOCAL HULL"
	title.add_theme_font_size_override("font_size",11)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	scope = SonarScope.new()
	scope.sensor = ship.get_node("Proximity")
	scope.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scope)
	row.add_child(center)
	var energy := instrument("ENERGY / RESERVE",Color(0.27,0.85,0.22))
	energy_value = energy[0]
	energy_bar = energy[1]
	warning = Label.new()
	warning.add_theme_font_size_override("font_size",11)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(warning)
	fire_led = ColorRect.new()
	fire_led.size = Vector2(28,5)
	add_child(fire_led)
	shield_led = ColorRect.new()
	shield_led.size = Vector2(28,5)
	add_child(shield_led)
	ignore_mouse(self)
	ship.damaged.connect(func(_amount: float): _flicker = 0.16)
	ship.weapon_fired.connect(func(): _firing = 0.12)
	update_instruments()
func ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_mouse(child)
func update_instruments() -> void:
	ammo_label.text = "CANNON AMMO %03d / %03d%s   |   MISSILES %02d / %02d" % [ship.ammo,ship.max_ammo," — LOW" if ship.ammo <= ship.low_ammo_threshold else "",ship.missiles,ship.max_missiles]
	ammo_label.modulate = Color(1,0.4,0.10) if ship.ammo <= ship.low_ammo_threshold else Color(0.85,0.92,0.84)
	shield_value.text = "%03d %%" % roundi(ship.shield)
	energy_value.text = "%03d %%" % roundi(ship.energy)
	shield_bar.value = ship.shield
	energy_bar.value = ship.energy
	warning.text = "V: EMITTER   •   "+("SHIELD CRITICAL" if ship.shield <= 10 else "SHIELD LOW" if ship.shield <= 25 else "ENERGY LOW" if ship.energy <= 10 else "WEAPON DISCHARGE" if _firing > 0 else "C / COCKPIT  •  P / SONAR")
	warning.modulate = Color(1,0.3,0.10) if ship.shield <= 25 else Color(0.65,0.72,0.67)
	shield_led.color = Color(1,0.2,0.04)*(0.65+0.35*sin(_clock*8)) if ship.shield <= 25 else Color(0.15,0.5,0.38)
	fire_led.color = Color(1,0.55,0.08) if _firing > 0 else Color(0.23,0.15,0.08)
	scope.queue_redraw()
func _process(delta: float) -> void:
	visible = weapons.cockpit_enabled
	_clock += delta
	_flicker = maxf(0.0,_flicker-delta)
	_firing = maxf(0.0,_firing-delta)
	modulate = Color(1,1,1,0.92+0.08*sin(_clock*94)) if _flicker > 0 else Color.WHITE
	var area := get_viewport_rect().size
	var width := minf(820,area.x*0.72)
	var height := minf(154,area.y*0.22)
	row.position = Vector2((area.x-width)/2,area.y-height+5)
	row.size = Vector2(width,height-25)
	ammo_label.position = row.position-Vector2(0,37)
	ammo_label.size.x = width
	warning.position = Vector2(row.position.x,area.y-19)
	warning.size.x = width
	fire_led.position = row.position+Vector2(width-36,-9)
	shield_led.position = row.position+Vector2(8,-9)
	_refresh += delta
	if _refresh >= 0.04:
		_refresh = 0.0
		update_instruments()
		queue_redraw()
func _draw() -> void:
	if not is_instance_valid(row): return
	var r := Rect2(row.position-Vector2(18,13),row.size+Vector2(36,39))
	var points := PackedVector2Array([r.position+Vector2(16,0),Vector2(r.end.x-16,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	draw_colored_polygon(points,Color(0.13,0.145,0.14))
	draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color(0.46,0.43,0.34),3,true)
	for i in range(9):
		var x := r.position.x+24+i*(r.size.x-48)/8
		for y in [r.position.y+6,r.end.y-5]:
			draw_circle(Vector2(x,y),3.5,Color(0.07,0.075,0.07))
			draw_circle(Vector2(x-0.5,y-0.5),1.8,Color(0.47,0.46,0.40))
	draw_line(Vector2(r.get_center().x-42,r.position.y+4),Vector2(r.get_center().x+42,r.position.y+4),Color(1,0.37,0.04),3,true)
