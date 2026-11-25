extends SceneTree
const Slots=preload("res://scripts/flow/save_slots.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1;push_error(text)
func frames(n: int) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	Slots.directory="user://test13_flow";Slots.legacy_path="user://test13_legacy.json"
	for p in [Slots.manual(1),Slots.manual(2),Slots.manual(3),Slots.checkpoint(),Slots.legacy_path]: DirAccess.remove_absolute(p)
	var flow=root.get_node("GameFlow")
	await flow.to_main()
	check(flow.screen==flow.Screen.MAIN_MENU,"Main menu is initial flow")
	var continue_button=flow.rows.find_children("*","Button",false,false)[1]
	check(continue_button.disabled,"Continue disabled with no valid save")
	await flow.new_game()
	var level=current_scene
	var m=level.get_node("Mission");var ship=level.get_node("Ship")
	level.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	check(m.objective==0 and ship.ammo==120 and ship.missiles==5 and ship.shield==100,"New Game resets mission and resources")
	check(Slots.resumable(Slots.checkpoint()),"Arrival automatic checkpoint exists")
	for slot in range(1,4):
		ship.ammo=120-slot
		check(m.save_game(Slots.manual(slot)),"Manual slot writes")
		check(Slots.read(Slots.manual(slot)).ammo==120-slot,"Slots remain independent")
	var projectile=load("res://scenes/weapons/laser.tscn").instantiate()
	level.add_child(projectile);projectile.position=Vector3(0,0,0);projectile.launch_velocity=Vector3(0,0,-20)
	m.door.powered=true;m.door.request_open()
	var monitored=get_nodes_in_group("enemies")[0]
	monitored.detection_range=0;monitored.set_physics_process(true)
	await frames(3)
	var ai_time: float=monitored._state_time
	var position: Vector3=projectile.position
	var age: float=projectile.age
	var elapsed: float=m.elapsed
	var door_progress: float=m.door.progress
	flow.pause_game()
	await create_timer(.25,true).timeout
	check(paused and projectile.position==position and projectile.age==age,"Pause freezes projectiles and timers")
	check(monitored._state_time==ai_time,"Pause freezes active AI state timers")
	check(m.elapsed==elapsed and m.door.progress==door_progress,"Pause freezes mission time and door motion")
	flow.show_options()
	check(paused and flow.screen==flow.Screen.OPTIONS,"Options do not unpause gameplay")
	flow._back();flow.resume_game()
	await frames(3)
	check(not paused and m.elapsed>elapsed,"Resume restores simulation")
	ship.take_damage(999)
	await process_frame;await process_frame
	check(paused and flow.screen==flow.Screen.DEAD,"Shield zero enters Mission Failed")
	for button in flow.rows.find_children("*","Button",false,false): check(not button.text.contains("Resume"),"No Resume after death")
	await flow.load_path(Slots.checkpoint())
	check(current_scene.get_node("Ship").shield==100 and current_scene.get_node("Mission").objective==0,"Retry checkpoint restores a playable ship")
	check(not paused and flow.screen==flow.Screen.GAME,"Checkpoint retry resumes gameplay")
	var file:=FileAccess.open(Slots.manual(3),FileAccess.WRITE);file.store_string('{"version":4}');file.close()
	check(not Slots.resumable(Slots.manual(3)),"Corrupt slot is unavailable")
	await flow.to_main()
	continue_button=flow.rows.find_children("*","Button",false,false)[1]
	check(not continue_button.disabled,"Continue enabled for remaining valid saves")
	await flow.new_game()
	check(current_scene.get_node("Mission").objective==0 and current_scene.get_node("Ship").ammo==120,"Second New Game does not inherit old mission state")
	await flow.load_path(Slots.manual(1))
	check(current_scene.get_node("Ship").ammo==119 and flow._has_current_checkpoint(),"Loading another run establishes its own safe checkpoint")
	var original_pose: Transform3D=current_scene.get_node("Ship").global_transform
	flow.complete({"time":123,"destroyed":4,"shield":76})
	await create_timer(3.2,true).timeout
	check(paused and flow.screen==flow.Screen.COMPLETE,"Completion cinematic ends in paused result screen")
	check(current_scene.get_node("Ship").global_transform.is_equal_approx(original_pose),"Departure animation never moves the actual ship")
	await flow.to_main()
	check(not paused and flow.screen==flow.Screen.MAIN_MENU,"Completion returns cleanly to main menu")
	for p in [Slots.manual(1),Slots.manual(2),Slots.manual(3),Slots.checkpoint(),Slots.legacy_path]: DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(Slots.directory)
	print("Game flow: ","PASS" if failures==0 else str(failures)+" failures")
	quit(0 if failures==0 else 1)
