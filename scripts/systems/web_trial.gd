extends Node
## Browser-only startup and shortcut adapters. Native flight/gameplay is unchanged.
var _intro: CanvasLayer

func _ready() -> void:
	if not OS.has_feature("web"): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_show_start")

func _show_start() -> void:
	var descend := InputEventKey.new()
	descend.physical_keycode = KEY_Z
	InputMap.action_add_event("move_down",descend)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_intro = CanvasLayer.new()
	_intro.layer = 120
	add_child(_intro)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.025,0.03,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520,0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035,0.055,0.06)
	frame.border_color = Color(0.3,0.5,0.52)
	frame.set_border_width_all(2)
	frame.content_margin_left = 28
	frame.content_margin_right = 28
	frame.content_margin_top = 24
	frame.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",frame)
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",16)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "PROJECTMINE / WEB TRIAL"
	title.add_theme_color_override("font_color",Color(0.4,0.9,0.92))
	title.add_theme_font_size_override("font_size",26)
	rows.add_child(title)
	var help := Label.new()
	help.text = "SIGNAL LOST — desktop browser test\n\nWASD flight • Space / Z up / down • Q / E roll\nMouse aim • LMB cannons • RMB missile\nF interact • C cockpit • P sonar • L lights\nJ save • K load • Esc release mouse\n\nClick the game to capture the mouse again.\nSaves stay in this browser; allow site storage."
	help.add_theme_font_size_override("font_size",16)
	rows.add_child(help)
	for fullscreen in [false,true]:
		var start := Button.new()
		start.text = "PLAY FULLSCREEN" if fullscreen else "PLAY IN WINDOW"
		start.custom_minimum_size.y = 44
		start.pressed.connect(_start.bind(fullscreen))
		rows.add_child(start)
	var mission := get_tree().current_scene.get_node_or_null("Mission")
	if mission:
		mission.message = "Communications lost. Explore the facility. F: interact · J: save · K: load"
	if not OS.is_userfs_persistent():
		var warning := Label.new()
		warning.text = "Browser storage unavailable: saves may be lost on reload."
		warning.add_theme_color_override("font_color",Color(1,0.7,0.25))
		rows.add_child(warning)

func _start(fullscreen: bool) -> void:
	if fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_tree().paused = false
	var ship := get_tree().get_first_node_in_group("player")
	if ship: ship.capture_mouse()
	_intro.queue_free()
	_intro = null

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("web") or is_instance_valid(_intro): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode not in [KEY_J,KEY_K]: return
	var scene := get_tree().current_scene
	var mission := scene.get_node_or_null("Mission") if scene else null
	if mission:
		if event.physical_keycode == KEY_J: mission.save_game()
		else: mission.load_game()
		get_viewport().set_input_as_handled()
