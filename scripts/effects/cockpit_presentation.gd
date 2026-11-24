extends CanvasLayer
## Transparent foreground pass: cockpit has no collision and cannot be cut by walls.
@export_range(0.5,1.0) var render_scale: float = 1.0
const LAYER := 1 << 19
var viewport: SubViewport
var camera: Camera3D
var image: TextureRect
@onready var ship = get_parent()
@onready var weapons = ship.get_node("Camera3D/WeaponEffects")
@onready var view: Camera3D = ship.get_node("Camera3D/VisualOffset/RenderCamera")
func _ready() -> void:
	layer = -1
	process_priority = -4
	view.cull_mask &= ~LAYER
	viewport = SubViewport.new()
	viewport.name = "CockpitViewport"
	viewport.transparent_bg = true
	viewport.world_3d = ship.get_world_3d()
	viewport.audio_listener_enable_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if DisplayServer.get_name() == "headless" else SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	camera = Camera3D.new()
	camera.cull_mask = LAYER
	camera.near = 0.04
	camera.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.73,0.78,0.84)
	env.ambient_light_energy = 0.85
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38,0.43,0.52)
	sky_material.sky_horizon_color = Color(0.65,0.62,0.53)
	sky_material.ground_bottom_color = Color(0.10,0.12,0.15)
	sky_material.ground_horizon_color = Color(0.42,0.38,0.30)
	sky.sky_material = sky_material
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	camera.environment = env
	viewport.add_child(camera)
	var key := OmniLight3D.new()
	key.position = Vector3(0,0.25,-0.3)
	key.omni_range = 3.0
	key.light_energy = 1.5
	key.light_color = Color(1.0,0.90,0.78)
	key.light_cull_mask = LAYER
	key.layers = LAYER
	key.shadow_enabled = false
	ship.get_node("Camera3D/WeaponEffects").add_child(key)
	image = TextureRect.new()
	image.name = "CockpitComposite"
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = viewport.get_texture()
	add_child(image)
	_sync()
func _process(_delta: float) -> void: _sync()
func _sync() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	viewport.size = Vector2i(maxi(1,int(dimensions.x*render_scale)),maxi(1,int(dimensions.y*render_scale)))
	image.size = dimensions
	camera.global_transform = view.global_transform
	camera.fov = view.fov
	camera.keep_aspect = view.keep_aspect
	image.visible = weapons.cockpit_enabled and view.is_current()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if image.visible and DisplayServer.get_name() != "headless" else SubViewport.UPDATE_DISABLED
