extends Node3D
## Scripted progression, bounded effects and an always-passable evacuation route.
signal escaped
signal failed
@export_range(10,3600) var evacuation_duration: float = 240.0
@export_range(0,12) var maximum_debris: int = 6
enum Phase { DORMANT, ACTIVE, COMPLETED, FAILED }
const ROUTE := [Vector3(0,34,-46),Vector3(56,34,-44),Vector3(88,34,-44),Vector3(118,34,-44),Vector3(118,70,-44),Vector3(118,70,-100)]
const ZONES := [Vector3(0,42,-68),Vector3(40,34,-44),Vector3(76,34,-44),Vector3(108,34,-44),Vector3(118,56,-44),Vector3(118,70,-78)]
const HINTS := ["CRITICAL STRUCTURAL FAILURE — return down the incline, then follow EVAC / AUX / SERVICE markings.","Follow the upper AUX gallery east.","Continue through SERVICE to emergency lift E-04.","Emergency interlock released — east to the lift.","Ascend the evacuation shaft.","Enter the windowed transport bridge.","Evacuation gate ahead — keep moving."]
var phase: Phase=Phase.DORMANT
var remaining := 240.0
var stage := 0
var zones: Array[Node3D] = []
var deadlines: Array[float] = []
var transport: Node3D
var countdown: Label
var alarm: AudioStreamPlayer3D
var _lights: Array[Dictionary] = []
var _pulse := 0.0
var _previous := Vector3.ZERO
var _last_phase := Phase.DORMANT
func _ready() -> void:
	remaining=evacuation_duration
	transport=Node3D.new();transport.set_script(preload("res://scripts/flow/escape_transport.gd"))
	transport.name="TransportConnector";add_child(transport);transport.build(get_parent())
	for p in ZONES:
		var zone := Node3D.new();zone.set_script(preload("res://scripts/flow/collapse_zone.gd"))
		zone.position=p;add_child(zone);zones.append(zone);deadlines.append(INF)
	countdown=Label.new()
	countdown.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	countdown.anchor_left=.5;countdown.anchor_right=.5
	countdown.offset_left=-190;countdown.offset_right=190
	countdown.offset_top=65;countdown.offset_bottom=135
	countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown.add_theme_font_size_override("font_size",21)
	countdown.modulate=Color(1,.35,.12)
	countdown.mouse_filter=Control.MOUSE_FILTER_IGNORE
	get_parent().get_node("HUD").add_child(countdown)
	countdown.hide()
	alarm=AudioStreamPlayer3D.new();alarm.name="EvacuationAlarm"
	alarm.volume_db=-24;alarm.max_distance=12;alarm.unit_size=5
	alarm.bus=preload("res://scripts/audio/environment_audio.gd").WORLD if get_tree().get_first_node_in_group("environment_audio") else preload("res://scripts/audio/industrial_sounds.gd").ensure_bus()
	alarm.stream=_alarm_sound()
	get_parent().get_node("Ship").add_child(alarm)
	for light in get_parent().find_children("*","OmniLight3D",true,false):
		if get_parent().get_node("Ship").is_ancestor_of(light) or light.get_meta("independent_power",false): continue
		_lights.append({"node":light,"color":light.light_color,"energy":light.light_energy})
func _alarm_sound() -> AudioStreamWAV:
	var bytes := PackedByteArray();bytes.resize(22050*2*2)
	for i in range(22050*2):
		var t:=float(i)/22050
		var envelope:=pow(maxf(0,sin(PI*fmod(t,1.0))),2)
		bytes.encode_s16(i*2,int((sin(TAU*(380 if t<1 else 290)*t)*.19+sin(TAU*95*t)*.05)*envelope*32767))
	var sound:=AudioStreamWAV.new();sound.format=AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate=22050;sound.data=bytes;sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_end=44100
	return sound
func begin() -> void:
	if phase!=Phase.DORMANT: return
	phase=Phase.ACTIVE;remaining=evacuation_duration;stage=0
	_previous=get_parent().get_node("Ship").global_position
	transport.set_open(true,true)
	get_parent().get_node("Mission").message=navigation_hint()
	_set_emergency(true)
	if DisplayServer.get_name()!="headless": alarm.play()
	countdown.show()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.velocity=Vector3.ZERO
		enemy.engine_audio.stop()
		if enemy.has_method("suspend_variant"): enemy.suspend_variant()
	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		if projectile.get("team")=="enemy": projectile.queue_free()
func navigation_hint() -> String:
	return HINTS[clampi(stage,0,HINTS.size()-1)]
func _set_emergency(active: bool) -> void:
	for entry in _lights:
		if is_instance_valid(entry.node):
			entry.node.light_color=Color(1,.09,.035) if active else entry.color
			entry.node.light_energy=entry.energy*.7 if active else entry.energy
func export_state() -> Dictionary:
	var broken := []
	for i in range(zones.size()):
		if zones[i].triggered: broken.append(i)
	return {"phase":phase,"remaining":remaining,"duration":evacuation_duration,"stage":stage,"zones":broken}
func restore(data: Dictionary) -> void:
	alarm.stop()
	for piece in get_tree().get_nodes_in_group("escape_debris"): piece.queue_free()
	for effect in get_tree().get_nodes_in_group("industrial_explosions"): effect.queue_free()
	phase=int(data.phase);remaining=float(data.remaining)
	evacuation_duration=float(data.duration);stage=int(data.stage)
	for i in range(zones.size()):
		zones[i].restore(data.zones.any(func(id): return int(id)==i))
		deadlines[i]=0 if i<stage else INF
	transport.set_open(phase!=Phase.DORMANT)
	_set_emergency(phase==Phase.ACTIVE)
	if phase==Phase.DORMANT: get_parent().get_node("Mission").apply_power()
	countdown.visible=phase==Phase.ACTIVE
	_previous=get_parent().get_node("Ship").global_position
	if phase==Phase.ACTIVE and DisplayServer.get_name()!="headless": alarm.play()
func _physics_process(delta: float) -> void:
	if phase!=Phase.ACTIVE: return
	var ship: Node3D=get_parent().get_node("Ship")
	if ship.shield<=0: return
	remaining=maxf(0,remaining-delta)
	var seconds:=ceili(remaining)
	countdown.text="ESCAPE PROTOCOL\nEVACUATE  %02d:%02d"%[seconds/60,seconds%60]
	if remaining<=0:
		phase=Phase.FAILED;alarm.stop();failed.emit()
		ship.take_damage(ship.shield)
		get_node("/root/GameFlow").fail("Evacuation time expired. Structural integrity lost.")
		return
	while stage<ROUTE.size() and Geometry3D.get_closest_point_to_segment(ROUTE[stage],_previous,ship.global_position).distance_to(ROUTE[stage])<7:
		deadlines[stage]=evacuation_duration-remaining+1.2
		stage+=1
		get_parent().get_node("Mission").message=navigation_hint()
	_previous=ship.global_position
	var elapsed:=evacuation_duration-remaining
	for i in range(zones.size()):
		if i<stage and not zones[i].triggered and (elapsed>=deadlines[i] or elapsed>(i+1)*30) and zones[i].global_position.distance_to(ship.global_position)>10:
			zones[i].trigger(ship,maximum_debris)
	_pulse+=delta
	if _pulse>.35:
		_pulse=0
		countdown.modulate=Color(1,.25,.08) if remaining<30 else Color(1,.55,.2)
	if stage==ROUTE.size() and ship.global_position.distance_to(Vector3(118,70,-126))<5:
		phase=Phase.COMPLETED;alarm.stop();countdown.hide()
		var mission=get_parent().get_node("Mission")
		mission.objective=7;mission.message="EVACUATION CONFIRMED — SIGNAL LOST COMPLETE"
		escaped.emit()
		get_node("/root/GameFlow").checkpoint("Evacuation complete")
		get_node("/root/GameFlow").complete({"time":mission.elapsed,"destroyed":mission.destroyed.size(),"shield":ship.shield})
