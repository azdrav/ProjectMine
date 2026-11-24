extends SceneTree
class PreviewShip extends "res://scripts/player/ship.gd":
	func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	var level = load("res://scenes/levels/deep_mine.tscn" if "--deep-mine" in OS.get_cmdline_user_args() else "res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.get_node("Ship").set_script(PreviewShip)
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.position = Vector3(56,1,7) if "--deep-mine" in OS.get_cmdline_user_args() else Vector3(0,0,-26)
	ship.get_node("Proximity").audio_volume_db = -60
	ship.shield = 90
	await capture("/tmp/projectmine09-cockpit.png")
	ship.get_node("Camera3D/WeaponEffects").set_cockpit_enabled(false)
	await capture("/tmp/projectmine09-cockpit-off.png")
	ship.get_node("Camera3D/WeaponEffects").set_cockpit_enabled(true)
	ship.shield = 18
	ship.energy = 37
	ship.position.x = 3
	DisplayServer.window_set_size(Vector2i(1280,800))
	root.size = Vector2i(1280,800)
	await capture("/tmp/projectmine09-laptop.png")
	level.queue_free()
	await create_timer(0.3).timeout
	quit()
