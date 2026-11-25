extends SceneTree
class Pilot extends "res://scripts/player/ship.gd":
	func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	level.get_node("Ship").set_script(Pilot)
	root.add_child(level)
	current_scene = level
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.position = Vector3(0,0,6)
	ship.get_node("Proximity").enabled = false
	for i in range(3):
		var enemy = load(["res://scenes/enemies/scout_drone.tscn","res://scenes/enemies/security_drone.tscn","res://scenes/enemies/heavy_guardian.tscn"][i]).instantiate()
		enemy.position = Vector3(-3+i*3,0,-3)
		enemy.rotation.y = PI
		level.add_child(enemy)
		enemy.set_physics_process(false)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine12-variants.png")
	level.queue_free()
	await create_timer(0.4).timeout
	quit()
