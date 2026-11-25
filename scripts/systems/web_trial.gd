extends Node
## Browser keyboard adapters; the shared main menu now supplies click-to-start.
func _ready() -> void:
	if not OS.has_feature("web"): return
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_level_added)
func _level_added(node: Node) -> void:
	if node is CharacterBody3D and node.is_in_group("player"): call_deferred("_bind_vertical")
func _bind_vertical() -> void:
	if not InputMap.has_action("move_down"): return
	var key:=InputEventKey.new();key.physical_keycode=KEY_Z
	if not InputMap.action_has_event("move_down",key): InputMap.action_add_event("move_down",key)
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("web"): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	var flow=get_node("/root/GameFlow")
	match event.physical_keycode:
		KEY_J: flow.quick_save()
		KEY_K: flow.quick_load()
		_: return
	get_viewport().set_input_as_handled()
