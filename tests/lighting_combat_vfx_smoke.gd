extends SceneTree
const VFX = preload("res://scripts/effects/energy_vfx.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		push_error(description)
		failures += 1
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func run() -> void:
	var level = load("res://scenes/levels/test_mine.tscn").instantiate()
	level.spawn_encounters=false
	level.signal_lost = false
	root.add_child(level)
	current_scene=level
	await frames(3)
	var ship = level.get_node("Ship")
	ship.set_physics_process(false)
	var lamps = ship.get_node("Headlights")
	check(lamps.lights.size()==2,"Two headlights")
	for pose in [Transform3D(Basis.IDENTITY,Vector3(0,0,-26)),Transform3D(Basis.from_euler(Vector3(PI/2,0,.7)),Vector3(0,17,-44))]:
		ship.global_transform=pose
		for light in lamps.lights:
			check((-light.global_basis.z).is_equal_approx(-ship.global_basis.z),"Headlight follows pitched/rolled ship")
			check(not light.shadow_enabled and is_equal_approx(light.spot_range,18.0),"Shadowless 18m range")
			check(light.light_color.r>light.light_color.b,"Warm white color")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_L
	key.pressed=true
	lamps._unhandled_key_input(key)
	check(not lamps.enabled and not lamps.lights[0].visible and not lamps.lights[1].visible,"L switches both lamps off")
	check(level.get_node("HUD")._lamp_status.text=="HEADLIGHTS OFF","Toggle status feedback")
	key.echo=true
	lamps._unhandled_key_input(key)
	check(not lamps.enabled,"Key repeat does not flicker")
	key.echo=false
	lamps._unhandled_key_input(key)
	lamps.intensity=2.0
	check(lamps.lights[0].light_energy==2.0,"Exported light settings update both lamps")
	ship.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,0,-20))
	ship.velocity=Vector3(10,0,0)
	ship.get_node("Camera3D/WeaponEffects").set_cockpit_enabled(false)
	ship.fire()
	await frames(2)
	var projectiles := get_nodes_in_group("combat_projectiles")
	check(projectiles.size()==1,"One projectile per shot")
	var laser = projectiles[0]
	check(laser.launch_velocity.is_equal_approx(Vector3(10,0,-100)),"Existing projectile speed plus inherited velocity preserved")
	var beam: MeshInstance3D=laser.get_node("Beam")
	check((-beam.global_basis.z.normalized()).is_equal_approx(laser.launch_velocity.normalized()),"Trail follows actual collision sweep, including lateral velocity")
	check(laser.visible_trail_length<=laser.traveled and laser.visible_trail_length<=2.0,"Trail never extends ahead of sweep or behind spawn")
	check(beam.global_position.is_equal_approx(laser.global_position),"Visual head matches physics position")
	var muzzle = ship.get_node("Camera3D/WeaponEffects")
	muzzle.fire()
	muzzle._process(.016)
	check(muzzle._flashes[ship.last_fired_cannon].visible and not muzzle._flashes[1-ship.last_fired_cannon].visible,"Only the selected cannon flashes")
	muzzle._process(.1)
	check(not muzzle._flashes[0].visible and not muzzle._flashes[1].visible,"Muzzle flash expires promptly")
	check(VFX.material("player",false)==VFX.material("player",false),"Effects share cached resources")
	check(VFX.color("player")!=VFX.color("enemy"),"Faction colors differ")
	laser.queue_free()
	await frames(2)
	for kind in ["wall","electrical","shield"]:
		var effect = VFX.impact(level,Vector3(0,0,-22),Vector3.BACK,"player",kind)
		check(effect!=null and effect.kind==kind,"Impact kind: "+kind)
		check(effect._velocities.size()==6,"Bounded six-spark burst")
		check(effect.find_children("*","Light3D",true,false).is_empty(),"No impact dynamic lights")
	for index in range(40): VFX.impact(level,Vector3(0,0,-22),Vector3.BACK,"enemy","wall")
	check(get_nodes_in_group("combat_vfx").size()==VFX.MAX_BURSTS,"Burst cap prevents effect accumulation")
	ship.take_damage(10)
	check(ship.shield==90,"Shield damage unchanged")
	var overlay: ColorRect=level.get_node("HUD")._damage_flash
	check(overlay.color.b>overlay.color.r and overlay.color.a<=.12,"Subtle cyan shield feedback")
	await create_timer(.4).timeout
	check(get_nodes_in_group("combat_vfx").is_empty(),"All effects clean up")
	check(overlay.color.a==0.0,"Shield overlay clears")
	print("Lighting/combat VFX: ","PASS" if failures==0 else "%d failures"%failures)
	level.queue_free()
	await create_timer(.15).timeout
	quit(0 if failures==0 else 1)
