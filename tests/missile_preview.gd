extends SceneTree
class Pilot extends "res://scripts/player/ship.gd":
	func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var level = load("res://scenes/levels/deep_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.get_node("Ship").set_script(Pilot)
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	ship.position = Vector3(0,0,-26)
	ship.get_node("Proximity").enabled = false
	var drone = load("res://scenes/enemies/security_drone.tscn").instantiate()
	drone.position = Vector3(0,0,-44)
	level.add_child(drone)
	drone.set_physics_process(false)
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine11-lock.png")
	ship.get_node("MissileSystem").launch()
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/projectmine11-launch.png")
	level.queue_free()
	await create_timer(0.4).timeout
	quit()
