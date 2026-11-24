extends SceneTree
var failures: int = 0
const ROUTE: Array[Vector3] = [Vector3(0,0,5),Vector3(0,0,-44),Vector3(0,34,-44),Vector3(0,34,-52),Vector3(0,44,-72),Vector3(0,44,-80)]
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		if failures < 15: push_error(description)
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters = false
	level.signal_lost = false
	root.add_child(level)
	current_scene = level
	# Audio is exercised separately; keep this accelerated physics test silent.
	level.get_node("Ship/Proximity").enabled = false
	await frames(3)
	var ship: CharacterBody3D = level.get_node("Ship")
	var hull: CollisionShape3D = ship.get_node("CollisionShape3D")
	ship.set_physics_process(false)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var original: Shape3D = hull.shape
	var proposed := BoxShape3D.new()
	proposed.size = Vector3(2.4,1.5,3.2)
	var orientations: Array[Basis] = [Basis.IDENTITY,Basis(Vector3.FORWARD,PI/4),Basis(Vector3.RIGHT,PI/4),Basis.from_euler(Vector3(.7,.5,1.0))]
	var clearance_samples: int = 0
	# Validate the proposed dimensions independently; do not enlarge the live hull.
	for shape in [original,proposed]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		for orientation in orientations:
			for index in range(ROUTE.size()-1):
				var count := ceili(ROUTE[index].distance_to(ROUTE[index+1])/.2)
				for sample in range(count+1):
					query.transform = Transform3D(orientation, ROUTE[index].lerp(ROUTE[index+1],float(sample)/count))
					check(space.intersect_shape(query).is_empty(), "Route obstruction: %s" % query.transform)
					clearance_samples += 1
	# Every ray from these interior route samples must eventually meet the enclosure.
	var enclosure_rays: int = 0
	for index in range(ROUTE.size()-1):
		var count := ceili(ROUTE[index].distance_to(ROUTE[index+1])/2.0)
		for sample in range(count+1):
			var origin := ROUTE[index].lerp(ROUTE[index+1],float(sample)/count)
			for x in [-1,0,1]:
				for y in [-1,0,1]:
					for z in [-1,0,1]:
						if x == 0 and y == 0 and z == 0: continue
						var direction := Vector3(x,y,z).normalized()
						check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*250,1)).is_empty(), "Open boundary ray at %s toward %s" % [origin,direction])
						enclosure_rays += 1
	# Dense checks across both formerly open miter joints, including side corners.
	for x in [-3.9,-3.0,0.0,3.0,3.9]:
		for step in range(41):
			var offset := -2.0 + step * .1
			for seam in [Vector3(x,34,-52+offset),Vector3(x,44,-72+offset)]:
				for axis in [Vector3.UP,Vector3.DOWN]:
					check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(seam,seam+axis*200,1)).is_empty(), "Joint hole at %s" % seam)
	# Move actual physics bodies at cruise/boost speed, including the original escape.
	var targets := [
		[Vector3(0,32,-52.9),Vector3.DOWN],
		[Vector3(0,46,-71.1),Vector3.UP],
		[Vector3(0,0,-25),Vector3.RIGHT],
		[Vector3(0,18,-44),Vector3.BACK],
		[Vector3(0,39,-62),Vector3.RIGHT],
		[Vector3(0,39,-62),Vector3(0,-2,-1).normalized()],
		[Vector3(0,0,-44),Vector3.FORWARD]]
	var motion_cases: int = 0
	for speed in [18.0,39.6]:
		for orientation in orientations:
			for target in targets:
				ship.global_transform = Transform3D(orientation,target[0])
				for frame in range(35):
					ship.velocity = target[1]*speed
					ship.move_and_slide()
					await physics_frame
				check(ship.position.distance_to(target[0]) < 9.0, "Escaped at %.1fm/s from %s; ended %s" % [speed,target[0],ship.position])
				motion_cases += 1
	# Check the same sweep paths with the proposed box; controls remain untouched.
	hull.shape = proposed
	await frames(2)
	for speed in [18.0,39.6]:
		for orientation in orientations:
			ship.global_transform = Transform3D(orientation,Vector3(0,39,-62))
			for frame in range(30):
				ship.velocity = Vector3.RIGHT * speed
				ship.move_and_slide()
				await physics_frame
			check(ship.position.x < 3.0, "Proposed rolled/pitched hull passed through tunnel wall")
	hull.shape = original
	check(ship.collision_layer == 2 and ship.collision_mask == 5, "Player layers/mask")
	for child in level.get_children():
		if child is StaticBody3D:
			check(child.collision_layer == 1, "Obstacle layer")
	var debug = level.get_node("CollisionDebug")
	debug.set_enabled(true)
	check(debug._overlay.visible and debug._overlay.get_child_count() == 76, "Debug covers player and all 75 wall/trim bodies")
	check(debug._player_wire.mesh != null, "Debug shows actual player collider")
	for wire in debug._overlay.get_children():
		check(wire.mesh is ImmediateMesh and wire.mesh.get_surface_count() > 0, "Every collider has explicit wire edges")
	debug.set_enabled(false)
	check(not debug._overlay.visible and not debug.is_processing(), "Debug toggle disables overlay and updates")
	print("Collision geometry: %s | %d clearance samples, %d enclosure rays, %d cruise/boost cases" % ["PASS" if failures == 0 else "%d FAILURES" % failures,clearance_samples,enclosure_rays,motion_cases])
	level.queue_free()
	await create_timer(.1).timeout
	quit(0 if failures == 0 else 1)
