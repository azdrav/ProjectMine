extends Node3D
## Runtime-only wire meshes: no physics bodies, layers or sensor interactions.
var enabled: bool = false
var _overlay: Node3D
var _player_wire: MeshInstance3D
var _player_shape: CollisionShape3D
var _status: Label

func _ready() -> void:
	_overlay = Node3D.new()
	_overlay.name = "CollisionWireframes"
	_overlay.visible = false
	add_child(_overlay)
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -470
	_status.offset_right = -24
	_status.offset_top = 162
	_status.offset_bottom = 188
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color(0.5, 0.8, 0.85)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_status)
	_refresh_status()
	set_process(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and _overlay.get_child_count() == 0:
		_build_wires(get_tree().current_scene)
	_overlay.visible = enabled
	set_process(enabled)
	if enabled:
		_process(0.0)
	_refresh_status()

func _refresh_status() -> void:
	_status.text = "F3 collision debug: " + ("ON  |  green: hull  /  cyan: level" if enabled else "OFF")

func _build_wires(node: Node) -> void:
	if node == self:
		return
	if node is CollisionShape3D and not node.disabled and node.shape:
		var owner_body := node.get_parent()
		if owner_body is StaticBody3D or owner_body.is_in_group("player"):
			var player := owner_body.is_in_group("player")
			var wire := MeshInstance3D.new()
			wire.mesh = _wire_mesh(node.shape)
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test = true
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.3, 1.0, 0.35, 1.0) if player else Color(0.1, 0.8, 1.0, 0.55)
			wire.material_override = material
			wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_overlay.add_child(wire)
			wire.global_transform = node.global_transform
			if player:
				_player_wire = wire
				_player_shape = node
	for child in node.get_children():
		_build_wires(child)

func _process(_delta: float) -> void:
	if is_instance_valid(_player_wire) and is_instance_valid(_player_shape):
		_player_wire.global_transform = _player_shape.global_transform

func _wire_mesh(shape: Shape3D) -> ImmediateMesh:
	# Shape debug meshes can contain filled triangles; render edges explicitly.
	var source := shape.get_debug_mesh()
	var wire := ImmediateMesh.new()
	var edges: Dictionary = {}
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for index in range(vertices.size()): indices.append(index)
		var primitive := source.surface_get_primitive_type(surface)
		var stride := 3 if primitive == Mesh.PRIMITIVE_TRIANGLES else 2
		for index in range(0, indices.size()-stride+1, stride):
			var pairs := [[0,1],[1,2],[2,0]] if stride == 3 else [[0,1]]
			for pair in pairs:
				var a := vertices[indices[index+pair[0]]]
				var b := vertices[indices[index+pair[1]]]
				var a_key := str(a)
				var b_key := str(b)
				var key := a_key+":"+b_key if a_key < b_key else b_key+":"+a_key
				edges[key] = [a,b]
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in edges.values():
		wire.surface_add_vertex(edge[0])
		wire.surface_add_vertex(edge[1])
	wire.surface_end()
	return wire
