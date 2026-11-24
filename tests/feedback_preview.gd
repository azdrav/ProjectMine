extends SceneTree
## Display-backed cockpit review. Does not write the user's comfort setting.
class PreviewShip extends "res://scripts/player/ship.gd":
	func _ready() -> void:
		pass # This screenshot fixture does not capture the desktop pointer.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	level.get_node("Ship").set_script(PreviewShip)
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.get_node("Proximity").enabled = false
	ship.position = Vector3(0,0,-22)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.get_node("FeedbackSettings").intensity = 0.55
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine08-cockpit.png")
	ship.fire()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine08-recoil.png")
	ship.take_damage(20,null,Vector3.RIGHT)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine08-shield.png")
	level.queue_free()
	await create_timer(0.2).timeout
	quit()
