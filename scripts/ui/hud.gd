extends CanvasLayer
@export var ship_path: NodePath
@export var show_fps: bool = true
@onready var ship = get_node(ship_path)
var _damage_flash: ColorRect
var _hit_time: float = 0.0
var _lamp_status: Label
var _lamp_message_time: float = 0.0
var _fps_label: Label
var _frame_time: float = 0.0
var _frames: int = 0
var dashboard: Control
var _cockpit_layout := false
var _help_text := ""
@onready var status: Label = $Status

func _ready() -> void:
	dashboard = Control.new()
	dashboard.name = "CockpitDashboard"
	dashboard.set_script(preload("res://scripts/ui/cockpit_dashboard.gd"))
	add_child(dashboard)
	_help_text = $Help.text
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(1.0,0.08,0.02,0.0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -240
	_fps_label.offset_right = -24
	_fps_label.offset_top = 188
	_fps_label.offset_bottom = 212
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size",14)
	_fps_label.modulate = Color(.7,.8,.8)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)
	_lamp_status=Label.new()
	_lamp_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lamp_status.offset_left=-280
	_lamp_status.offset_right=-24
	_lamp_status.offset_top=214
	_lamp_status.offset_bottom=238
	_lamp_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_lamp_status.add_theme_font_size_override("font_size",13)
	_lamp_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_lamp_status)
	ship.get_node("Headlights").toggled.connect(func(active: bool):
		_lamp_status.text="HEADLIGHTS "+("ON" if active else "OFF")
		_lamp_message_time=1.5)
	ship.damaged.connect(_on_damage)
	ship.hit_confirmed.connect(func(): _hit_time = 0.15)

func _on_damage(_amount: float) -> void:
	_damage_flash.color=Color(.10,.45,.8,clampf(_amount/25.0*0.12,0.02,0.12))

func _process(delta: float) -> void:
	_lamp_message_time=maxf(0.0,_lamp_message_time-delta)
	_lamp_status.visible=_lamp_message_time>0.0
	_fps_label.visible = show_fps
	_frame_time += delta
	_frames += 1
	if _frame_time >= 0.5:
		_fps_label.text = "FPS %d  /  %.1f ms" % [roundi(_frames/_frame_time),1000.0*_frame_time/_frames]
		_frame_time = 0.0
		_frames = 0
	_damage_flash.color.a = move_toward(_damage_flash.color.a,0.0,delta*0.9)
	_hit_time = maxf(0.0,_hit_time-delta)
	var feedback = ship.get_node("Camera3D/VisualOffset")
	var view: Camera3D = feedback.render_camera
	if view.is_current() and not view.is_position_behind(feedback.aim_point):
		var screen_point := view.unproject_position(feedback.aim_point)
		$Crosshair.position = screen_point-$Crosshair.size*0.5
	$Crosshair.text = "×" if _hit_time > 0.0 else "+"
	$Crosshair.modulate = Color(1.0,0.8,0.2) if _hit_time > 0.0 else Color.WHITE
	var cockpit: bool = ship.get_node("Camera3D/WeaponEffects").cockpit_enabled
	$ProximityIndicator.visible = not cockpit
	if cockpit != _cockpit_layout:
		_cockpit_layout = cockpit
		apply_cockpit_layout(cockpit)
	status.text = "PROJECTMINE 1.1   /   SIGNAL LOST\n\nSPEED   %05.1f m/s%s" % [ship.get_real_velocity().length(), "  BOOST" if ship.boosting else ""]
	if not cockpit: status.text += "\nAMMO %03d/%03d%s  /  MISSILES %02d/%02d" % [ship.ammo,ship.max_ammo," LOW" if ship.ammo <= ship.low_ammo_threshold else "",ship.missiles,ship.max_missiles]
	if not cockpit: status.text += "\nSHIELD  %03d %%\nENERGY  %03d %%" % [ship.shield,ship.energy]
	var comfort = get_node("/root/FeedbackSettings")
	$Help.visible = not cockpit or (comfort.notice_time <= 0.0 and ship.shield > 0.0)
	if comfort.notice_time > 0.0:
		status.text += "\nCAMERA SHAKE %d %%  /  [ ] adjust • F6 toggle" % roundi(comfort.intensity*100)
	if ship.boost_exhausted:
		status.text += "\nBOOST: release Shift to rearm"

	if shield_disabled():
		status.text += "\n\nSHIP DISABLED — R: restart encounter"
	elif get_tree().current_scene.get("spawn_encounters"):
		var count: int = get_tree().current_scene.enemies_remaining()
		status.text += ("   /   HOSTILES %d" if cockpit else "\nHOSTILES  %d") % count
		if count == 0: status.text += " / SECTOR CLEAR" if cockpit else "\nSECTOR CLEAR — R: restart encounter"

func shield_disabled() -> bool:
	return ship.shield <= 0.0

func apply_cockpit_layout(active: bool) -> void:
	$ProximityIndicator.offset_top = 20.0
	$ProximityIndicator.offset_bottom = 150.0
	$ProximityIndicator.queue_redraw()
	$Help.anchor_top = 0.0 if active else 1.0
	$Help.anchor_bottom = $Help.anchor_top
	$Help.offset_top = 118.0 if active else -76.0
	$Help.offset_bottom = 150.0 if active else -18.0
	$Help.text = "WASD / Space / Ctrl flight  •  Mouse aim  •  Q / E roll  •  Shift boost\nLMB cannons / RMB missile / V emitter  •  F interact  •  F5/F9 save/load  •  C cockpit  •  P sonar  •  L lights" if active else _help_text
	$Help.add_theme_font_size_override("font_size",12 if active else 14)
	if get_tree().current_scene.has_node("Mission"):
		var objective = get_tree().current_scene.get_node("Mission").hud
		objective.anchor_top = 0.0 if active else 1.0
		objective.anchor_bottom = objective.anchor_top
		objective.offset_top = 170.0 if active else -175.0
		objective.offset_bottom = 250.0 if active else -80.0
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.offset_right = minf(900,get_viewport().get_visible_rect().size.x-30)
