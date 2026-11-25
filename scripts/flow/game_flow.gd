extends CanvasLayer
## The only always-processing gameplay owner: menus run while the world is paused.
const Slots = preload("res://scripts/flow/save_slots.gd")
const LEVEL := "res://scenes/levels/deep_mine.tscn"
const MAIN := "res://scenes/flow/main_menu.tscn"
enum Screen { GAME, MAIN_MENU, PAUSE, SAVE, LOAD, OPTIONS, DEAD, COMPLETE, LOADING, READY }
var screen: Screen = Screen.GAME
var session_active := false
var panel: Control
var rows: VBoxContainer
var notice: Label
var loading := false
var last_load := ""
var _return_screen: Screen = Screen.MAIN_MENU
var _cinema: Node3D
var _cinema_tween: Tween
func _ready() -> void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load("user://options.cfg")==OK:
		AudioServer.set_bus_volume_linear(0,clampf(float(settings.get_value("audio","volume",.8)),0,1))
func mission() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Mission") if scene else null
func _panel(title: String, subtitle: String="") -> void:
	if is_instance_valid(panel): remove_child(panel);panel.queue_free()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	panel=Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade := ColorRect.new()
	shade.color=Color(.005,.012,.016,.55 if screen==Screen.MAIN_MENU else .87)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size=Vector2(620,0)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.045,.05,.96)
	style.border_color=Color(.25,.46,.49)
	style.set_border_width_all(2)
	style.content_margin_left=30;style.content_margin_right=30
	style.content_margin_top=24;style.content_margin_bottom=24
	frame.add_theme_stylebox_override("panel",style)
	center.add_child(frame)
	rows=VBoxContainer.new()
	rows.add_theme_constant_override("separation",10)
	frame.add_child(rows)
	var label := Label.new()
	label.text=title
	label.add_theme_font_size_override("font_size",28)
	label.add_theme_color_override("font_color",Color(.45,.92,.93))
	rows.add_child(label)
	if subtitle!="":
		var detail := Label.new()
		detail.text=subtitle
		detail.add_theme_font_size_override("font_size",15)
		rows.add_child(detail)
	notice=Label.new()
	notice.add_theme_color_override("font_color",Color(1,.65,.2))
	rows.add_child(notice)
func _button(text: String, action: Callable, enabled: bool=true) -> Button:
	var button := Button.new()
	button.text=text
	button.custom_minimum_size.y=39
	button.disabled=not enabled
	button.pressed.connect(action)
	rows.add_child(button)
	return button
func show_main() -> void:
	session_active=false
	screen=Screen.MAIN_MENU
	get_tree().paused=false
	_panel("PROJECTMINE — SIGNAL LOST","INDUSTRIAL FLIGHT / ESCAPE PROTOCOL")
	_button("New Game",new_game)
	_button("Continue",func(): load_path(Slots.latest()),Slots.latest()!="")
	_button("Load Game",func(): show_slots(false))
	_button("Options",show_options)
	var quit_button := _button("Quit" if not OS.has_feature("web") else "Quit — close browser tab",func(): get_tree().quit(),not OS.has_feature("web"))
	quit_button.tooltip_text="Close the browser tab to quit" if OS.has_feature("web") else ""
func _input(event: InputEvent) -> void:
	if not session_active or loading: return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_ESCAPE or (OS.has_feature("web") and event.physical_keycode==KEY_M)):
		if screen==Screen.GAME: pause_game()
		elif screen==Screen.PAUSE: resume_game()
		elif screen in [Screen.SAVE,Screen.LOAD,Screen.OPTIONS]: _back()
		get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	if session_active and screen==Screen.GAME:
		var m := mission()
		if m and m.ship.shield<=0: fail("Your ship has been disabled.")
func pause_game() -> void:
	var m := mission()
	if not m or m.ship.shield<=0:
		fail("Your ship has been disabled.")
		return
	get_tree().paused=true
	screen=Screen.PAUSE
	_panel("FLIGHT SUSPENDED","The ship, drones and evacuation clock are paused.")
	_button("Resume Game",resume_game)
	_button("Save Game",func(): show_slots(true))
	_button("Load Game",func(): show_slots(false))
	_button("Options",show_options)
	_button("Main Menu",to_main)
func resume_game() -> void:
	if not mission() or mission().ship.shield<=0: fail("Your ship has been disabled.");return
	if is_instance_valid(panel): panel.queue_free();panel=null
	screen=Screen.GAME
	get_tree().paused=false
	mission().ship.capture_mouse()
func show_slots(saving: bool) -> void:
	if screen not in [Screen.SAVE,Screen.LOAD]: _return_screen=screen
	screen=Screen.SAVE if saving else Screen.LOAD
	_panel("SAVE GAME" if saving else "LOAD GAME","Three manual slots • automatic checkpoint • legacy saves")
	for i in range(1,4):
		var path := Slots.manual(i)
		_button("Slot %d — %s"%[i,Slots.description(path)],_save_slot.bind(i) if saving else load_path.bind(path),saving or Slots.resumable(path))
	if not saving:
		_button("Checkpoint — "+Slots.description(Slots.checkpoint()),load_path.bind(Slots.checkpoint()),Slots.resumable(Slots.checkpoint()))
		if Slots.resumable(Slots.legacy_path): _button("Legacy save — "+Slots.description(Slots.legacy_path),load_path.bind(Slots.legacy_path))
	_button("Back",_back)
func _save_slot(slot: int) -> void:
	if not mission() or mission().ship.shield<=0: return
	var ok: bool=mission().save_game(Slots.manual(slot))
	show_slots(true)
	notice.text="Slot %d saved."%slot if ok else "Could not save. Check storage availability."
func quick_save() -> void:
	if session_active and screen==Screen.GAME and mission(): mission().save_game(Slots.manual(1))
func quick_load() -> void:
	if not session_active or screen!=Screen.GAME: return
	var path := Slots.manual(1) if Slots.resumable(Slots.manual(1)) else Slots.latest()
	if path!="": load_path(path)
func show_options() -> void:
	_return_screen=screen
	screen=Screen.OPTIONS
	_panel("SHIP OPTIONS","Volume and camera feedback persist between sessions.")
	var volume := HSlider.new()
	volume.max_value=100;volume.step=1
	volume.value=AudioServer.get_bus_volume_linear(0)*100
	var volume_label := Label.new()
	volume_label.text="Master volume: %d%%"%volume.value
	rows.add_child(volume_label);rows.add_child(volume)
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_linear(0,value/100)
		volume_label.text="Master volume: %d%%"%value
		var config := ConfigFile.new()
		config.set_value("audio","volume",value/100)
		config.save("user://options.cfg"))
	var shake := HSlider.new()
	shake.max_value=100;shake.step=1
	shake.value=get_node("/root/FeedbackSettings").intensity*100
	var shake_label := Label.new()
	shake_label.text="Camera feedback: %d%%"%shake.value
	rows.add_child(shake_label);rows.add_child(shake)
	shake.value_changed.connect(func(value: float):
		get_node("/root/FeedbackSettings").set_intensity(value/100)
		shake_label.text="Camera feedback: %d%%"%value)
	_button("Toggle Fullscreen",func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	_button("Back",_back)
func _back() -> void:
	match _return_screen:
		Screen.MAIN_MENU: show_main()
		Screen.DEAD: fail("Your ship has been disabled.")
		_: pause_game()
func new_game() -> void:
	await _open_level("")
func load_path(path: String) -> void:
	if loading or not Slots.resumable(path):
		if is_instance_valid(notice): notice.text="Save unavailable or invalid."
		return
	await _open_level(path)
func _open_level(path: String) -> void:
	if loading: return
	loading=true;session_active=false;screen=Screen.LOADING
	get_tree().paused=true
	_panel("PREPARING FLIGHT", "Loading mining facility…")
	var error := get_tree().change_scene_to_file(LEVEL)
	if error!=OK:
		loading=false
		show_main();notice.text="Could not load the mining facility."
		return
	await get_tree().scene_changed
	var m := mission()
	if path!="" and not m.load_game(path):
		loading=false
		await to_main()
		notice.text="Save rejected; the file has not been changed."
		return
	last_load=path
	session_active=true;loading=false
	if path=="": checkpoint("Arrival")
	elif not _has_current_checkpoint() and (m.objective<6 or m.get_parent().get_node("EscapeProtocol").remaining>=60): checkpoint("Loaded game")
	if m.objective==7:
		complete({"time":m.elapsed,"destroyed":m.destroyed.size(),"shield":m.ship.shield})
		return
	if OS.has_feature("web"):
		screen=Screen.READY
		_panel("READY TO LAUNCH","Click to enable mouse capture and audio.\nSpace / Z vertical flight • J save / K load")
		_button("Enter Cockpit",resume_game)
	else: resume_game()
func checkpoint(label: String="") -> bool:
	if not session_active or not mission() or mission().ship.shield<=0: return false
	var previous: String=mission().message
	var ok: bool=mission().save_game(Slots.checkpoint())
	mission().message=previous+("  [Checkpoint: "+label+"]" if ok and label!="" else "")
	return ok
func _has_current_checkpoint() -> bool:
	var data := Slots.read(Slots.checkpoint())
	return mission()!=null and not data.is_empty() and data.shield>0 and data.get("run_id","")==mission().run_id
func fail(reason: String) -> void:
	if not session_active: return
	screen=Screen.DEAD
	get_tree().paused=true
	_panel("MISSION FAILED",reason)
	_button("Retry Checkpoint",load_path.bind(Slots.checkpoint()),_has_current_checkpoint())
	_button("Load Game",func(): show_slots(false))
	_button("Main Menu",to_main)
func to_main() -> void:
	if is_instance_valid(_cinema): _cinema.queue_free();_cinema=null
	if _cinema_tween and _cinema_tween.is_running(): _cinema_tween.kill()
	session_active=false;loading=false
	get_tree().paused=false
	get_tree().change_scene_to_file(MAIN)
	await get_tree().scene_changed
func complete(stats: Dictionary) -> void:
	if not session_active or screen==Screen.COMPLETE: return
	screen=Screen.COMPLETE
	get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(panel): panel.queue_free();panel=null
	var scene := get_tree().current_scene
	for overlay in scene.find_children("*","CanvasLayer",true,false): overlay.hide()
	var cockpit=scene.get_node("Ship/Camera3D/WeaponEffects")
	cockpit.set_cockpit_enabled(false)
	_cinema=Node3D.new();_cinema.set_script(preload("res://scripts/flow/escape_cinematic.gd"))
	_cinema.process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_cinema)
	_cinema.build_cinematic()
	_cinema_tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cinema_tween.tween_property(_cinema.skiff,"position",Vector3(0,1,-19),3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cinema_tween.tween_callback(_completion_screen.bind(stats))
func _completion_screen(stats: Dictionary) -> void:
	var seconds:=int(stats.time)
	_panel("MISSION COMPLETE","Evacuation confirmed. You escaped the collapsing mine.\n\nCompletion time: %02d:%02d\nEnemies destroyed: %d\nRemaining shield: %d%%"%[seconds/60,seconds%60,int(stats.destroyed),int(stats.shield)])
	_button("Return to Main Menu",to_main)
