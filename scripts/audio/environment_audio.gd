extends Node3D
## One listener, one fixed reverb topology, bounded per-emitter occlusion buses.
signal environmental_event(kind: String, point: Vector3)
const Sounds = preload("res://scripts/audio/ambient_sounds.gd")
const Industrial = preload("res://scripts/audio/industrial_sounds.gd")
const Zone = preload("res://scripts/audio/acoustic_zone.gd")
const WORLD: StringName = &"ExternalWorld"
const PROFILES := {
	"open":preload("res://assets/audio/profiles/open.tres"),
	"steel":preload("res://assets/audio/profiles/steel.tres"),
	"concrete":preload("res://assets/audio/profiles/concrete.tres"),
	"chamber":preload("res://assets/audio/profiles/chamber.tres"),
	"shaft":preload("res://assets/audio/profiles/shaft.tres")}
const PARAMETERS := ["room_size","damping","wet","spread","predelay_ms","predelay_feedback"]
@export var enabled: bool = true
@export var build_test_mine_zones: bool = true
@export_range(.1,4) var transition_seconds: float = .8
@export_range(0,.2) var maximum_wet: float = .18
@export_group("Occlusion")
@export var occlusion_interval: float = .35
@export_flags_3d_physics var obstacle_mask: int = 1
@export var rays_per_update: int = 3
@export var blocked_volume_db: float = -10.0
@export var blocked_cutoff_hz: float = 2400.0
@export var occlusion_fade_seconds: float = .22
@export var source_slots: int = 12
@export_group("Ambience")
@export var maximum_loops: int = 3
@export var ambience_range: float = 35.0
@export var ambience_volume_db: float = -31.0
@export var event_volume_db: float = -24.0
@export var event_interval_min: float = 14.0
@export var event_interval_max: float = 32.0
@export var random_seed: int = 0
@export var additional_event_points := PackedVector3Array([Vector3(-3,2,-24)])
var zones: Array[Node3D] = []
var sources: Array[Dictionary] = []
var loops: Array[Dictionary] = []
var target: Dictionary = {}
var current: Dictionary = {}
var ray_count: int = 0
var event_count: int = 0
var reverb: AudioEffectReverb
var _pool: Array[Dictionary] = []
var _created_buses: Array[StringName] = []
var _overflow_routes: Array[Dictionary] = []
var _weapon: AudioStreamPlayer
var _weapon_bus: StringName
var _listener: CharacterBody3D
var _event: AudioStreamPlayer3D
var _event_owner: Node3D
var _tick_wait: float = 0.0
var _event_wait: float = 0.0
var _event_busy: float = 0.0
var _native_playback: bool = false
var _cursor: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("environment_audio")
	_native_playback=DisplayServer.get_name()!="headless"
	if random_seed: _rng.seed=random_seed
	else: _rng.randomize()
	Industrial.ensure_bus()
	_new_bus(WORLD,Industrial.BUS)
	reverb=AudioEffectReverb.new()
	reverb.dry=1.0
	reverb.wet=0.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(WORLD),reverb)
	for index in range(clampi(source_slots,1,24)):
		var bus := StringName("WorldSource%02d"%index)
		_new_bus(bus,WORLD)
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz=18000
		filter.resonance=.15
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus),filter)
		_pool.append({"bus":bus,"filter":filter,"used":false})
	_listener=get_tree().get_first_node_in_group("player") as CharacterBody3D
	if is_instance_valid(_listener):
		_weapon=_listener.get_node("Audio").weapon
		_weapon_bus=_weapon.bus
		_weapon.bus=WORLD # Local discharge keeps its direct gain; no self-occlusion.
	for child in find_children("*","Node3D",true,false):
		if child.get_script()==Zone: zones.append(child)
	if build_test_mine_zones: _build_zones()
	for parameter in PARAMETERS:
		current[parameter]=PROFILES.open.get(parameter)
		reverb.set("predelay_msec" if parameter=="predelay_ms" else parameter,current[parameter])
	target=current.duplicate()
	_build_ambience()
	get_tree().node_added.connect(_candidate_added)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		for child in enemy.get_children(): _candidate_added(child)
	_event_wait=_next_interval()
	_tick()

func _new_bus(bus: StringName, send: StringName) -> void:
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus)
	AudioServer.set_bus_send(index,send)
	_created_buses.append(bus)

func add_zone(title: String, pose: Transform3D, size: Vector3, profile: Resource) -> Node3D:
	var zone = Node3D.new()
	zone.set_script(Zone)
	zone.name=title
	zone.transform=pose
	zone.dimensions=size
	zone.profile=profile
	add_child(zone)
	zones.append(zone)
	return zone

func _build_zones() -> void:
	var rooms := [[Vector3.ZERO,Vector3(24,16,28)],[Vector3(0,0,-44),Vector3(16,16,12)],[Vector3(0,34,-44),Vector3(16,12,16)],[Vector3(0,44,-80),Vector3(20,16,16)]]
	for index in range(rooms.size()): add_zone("Chamber%d"%index,Transform3D(Basis.IDENTITY,rooms[index][0]),rooms[index][1],PROFILES.chamber)
	var passages := [[Vector3(0,0,-14),Vector3(0,0,-38),"concrete"],[Vector3(0,8,-44),Vector3(0,28,-44),"shaft"],[Vector3(0,34,-52),Vector3(0,44,-72),"steel"]]
	for passage in passages:
		var direction: Vector3=(passage[1]-passage[0]).normalized()
		var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.95 else Vector3.UP
		add_zone(passage[2],Transform3D(Basis.looking_at(direction,up),(passage[0]+passage[1])*.5),Vector3(8,8,passage[0].distance_to(passage[1])),PROFILES[passage[2]])

func sample_acoustics(point: Vector3) -> Dictionary:
	var result: Dictionary = {}
	for parameter in PARAMETERS: result[parameter]=0.0
	var total: float = 0.0
	for zone in zones:
		if not is_instance_valid(zone) or not zone.profile: continue
		var weight: float=zone.weight_at(point)
		total+=weight
		for parameter in PARAMETERS: result[parameter]+=weight*zone.profile.get(parameter)
	var open_weight := maxf(0.0,1.0-total)
	for parameter in PARAMETERS:
		result[parameter]=(result[parameter]+open_weight*PROFILES.open.get(parameter))/maxf(1.0,total)
	result.wet=minf(result.wet,maximum_wet)
	return result

func register_source(owner: Node3D, players: Array) -> bool:
	_prune_sources()
	for source in sources:
		if is_instance_valid(source.owner) and source.owner==owner:
			for player in players:
				var known: bool = false
				for route in source.routes:
					if is_instance_valid(route.player) and route.player==player: known=true
				if not known: source.routes.append(_route_player(player,source.slot.bus))
			return true
	for slot in _pool:
		if slot.used: continue
		slot.used=true
		var routes: Array = []
		for player in players:
			routes.append(_route_player(player,slot.bus))
		sources.append({"owner":owner,"routes":routes,"slot":slot,"blocked":false,"gain_db":0.0,"cutoff":18000.0})
		return true
	# A bounded overflow still receives room acoustics, without per-source filtering.
	for player in players:
		var known: bool = false
		for route in _overflow_routes:
			if is_instance_valid(route.player) and route.player==player: known=true
		if not known: _overflow_routes.append({"player":player,"original_bus":player.bus})
		player.bus=WORLD
	return false

func _route_player(player: Node, bus: StringName) -> Dictionary:
	var original: StringName=player.bus
	for index in range(_overflow_routes.size()-1,-1,-1):
		if is_instance_valid(_overflow_routes[index].player) and _overflow_routes[index].player==player:
			original=_overflow_routes[index].original_bus
			_overflow_routes.remove_at(index)
	player.bus=bus
	return {"player":player,"original_bus":original}

func _candidate_added(node: Node) -> void:
	if node is AudioStreamPlayer3D: call_deferred("_register_candidate",weakref(node))

func _register_candidate(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	var owner: Node = node.get_parent()
	if not owner is Node3D or (not owner.is_in_group("enemies") and not str(owner.name).begins_with("DroneDestruction")): return
	var players: Array = []
	for child in owner.get_children():
		if child is AudioStreamPlayer3D: players.append(child)
	register_source(owner,players)

func _emitter(title: String, point: Vector3) -> AudioStreamPlayer3D:
	var owner := Node3D.new()
	owner.name=title
	add_child(owner)
	owner.position=point
	var player := AudioStreamPlayer3D.new()
	player.unit_size=7.0
	player.max_distance=0.0 # Unlimited attenuation; voice selection still bounds CPU work.
	player.max_polyphony=1
	player.max_db=ambience_volume_db # Near-field attenuation must not amplify quiet ambience.
	player.volume_db=-80.0
	owner.add_child(player)
	register_source(owner,[player])
	return player

func _build_ambience() -> void:
	var anchors := [[Vector3(10,5,0),"ventilation"],[Vector3(7,2,-46),"machinery"],[Vector3(3,18,-44),"ventilation"],[Vector3(-7,35,-42),"electrical"],[Vector3(-3,39,-62),"ventilation"],[Vector3(8,46,-82),"machinery"]]
	for anchor in anchors:
		var player := _emitter("Ambient%d"%loops.size(),anchor[0])
		player.stream=Sounds.sound(anchor[1])
		loops.append({"player":player,"base":ambience_volume_db,"gain":0.0,"target":0.0})
	_event=_emitter("SparseEvent",Vector3.ZERO)
	_event.max_db=event_volume_db
	_event_owner=_event.get_parent()
	# Prewarm all recipes; event scheduling never synthesizes PCM in flight.
	for kind in ["creak","crash","pipe","startup","malfunction"]: Sounds.sound(kind)

func _next_interval() -> float:
	return _rng.randf_range(maxf(1,event_interval_min),maxf(maxf(1,event_interval_min),event_interval_max))

func trigger_event() -> bool:
	if not enabled or not is_instance_valid(_listener) or _event_busy>0.0 or _event.playing: return false
	var candidates: Array[Vector3] = []
	for loop in loops:
		var point: Vector3=loop.player.global_position
		var distance := point.distance_to(_listener.global_position)
		if distance>8 and distance<45: candidates.append(point)
	for local_point in additional_event_points:
		var point: Vector3=to_global(local_point)
		var distance := point.distance_to(_listener.global_position)
		if distance>8 and distance<45: candidates.append(point)
	if candidates.is_empty(): return false
	var kind: String=["creak","crash","pipe","startup","malfunction"][_rng.randi_range(0,4)]
	_event_owner.global_position=candidates[_rng.randi_range(0,candidates.size()-1)]+Vector3(0,0,_rng.randf_range(-.4,.4))
	_event.stream=Sounds.sound(kind)
	_event.pitch_scale=_rng.randf_range(.93,1.05)
	_event.volume_db=event_volume_db+_rng.randf_range(-3,0)
	_event_busy=_event.stream.get_length()/_event.pitch_scale
	if _native_playback: _event.play()
	event_count+=1
	environmental_event.emit(kind,_event_owner.global_position)
	return true

func _prune_sources() -> void:
	for index in range(sources.size()-1,-1,-1):
		if not is_instance_valid(sources[index].owner):
			var slot: Dictionary=sources[index].slot
			slot.used=false
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(slot.bus),0.0)
			slot.filter.cutoff_hz=18000
			sources.remove_at(index)
	for index in range(_overflow_routes.size()-1,-1,-1):
		if not is_instance_valid(_overflow_routes[index].player): _overflow_routes.remove_at(index)

func _tick() -> void:
	_prune_sources()
	if not is_instance_valid(_listener): return
	target=sample_acoustics(_listener.global_position) if enabled else _open_settings()
	if not enabled:
		for source in sources: source.blocked=false
	var ranked := loops.duplicate()
	ranked.sort_custom(func(a: Dictionary,b: Dictionary): return a.player.global_position.distance_squared_to(_listener.global_position)<b.player.global_position.distance_squared_to(_listener.global_position))
	for loop in loops: loop.target=0.0
	for index in range(mini(maximum_loops,ranked.size())):
		if enabled:
			var distance: float=ranked[index].player.global_position.distance_to(_listener.global_position)
			ranked[index].target=clampf(ambience_range/maxf(maxf(1.0,ambience_range),distance),.12,1.0)
	var active: Array[Dictionary] = []
	for source in sources:
		for route in source.routes:
			if is_instance_valid(route.player) and route.player.playing:
				active.append(source)
				break
	for index in range(mini(maxi(0,rays_per_update),active.size())):
		var source: Dictionary=active[_cursor%active.size()]
		_cursor+=1
		var query := PhysicsRayQueryParameters3D.create(_listener.global_position,source.owner.global_position,obstacle_mask)
		var exclude: Array[RID]=[_listener.get_rid()]
		if source.owner is CollisionObject3D: exclude.append(source.owner.get_rid())
		query.exclude=exclude
		source.blocked=not get_world_3d().direct_space_state.intersect_ray(query).is_empty() if enabled else false
		if enabled: ray_count+=1

func _open_settings() -> Dictionary:
	var result: Dictionary = {}
	for parameter in PARAMETERS: result[parameter]=PROFILES.open.get(parameter)
	return result

func _physics_process(delta: float) -> void:
	_event_busy=maxf(0.0,_event_busy-delta)
	_tick_wait-=delta
	if _tick_wait<=0:
		_tick_wait=maxf(.1,occlusion_interval)
		_tick()
	_event_wait-=delta
	if _event_wait<=0:
		_event_wait=_next_interval()
		trigger_event()

func _process(delta: float) -> void:
	if not reverb: return
	var blend := 1.0-exp(-delta/maxf(.05,transition_seconds))
	for parameter in PARAMETERS:
		var next: float=lerpf(current[parameter],target[parameter],blend)
		var epsilon: float=.001 if parameter=="predelay_ms" else .00001
		if absf(next-target[parameter])<epsilon: next=target[parameter]
		if next!=current[parameter]:
			current[parameter]=next
			reverb.set("predelay_msec" if parameter=="predelay_ms" else parameter,next)
	var occlusion_blend := 1.0-exp(-delta/maxf(.05,occlusion_fade_seconds))
	for source in sources:
		var gain_target: float=blocked_volume_db if source.blocked else 0.0
		var cutoff_target: float=blocked_cutoff_hz if source.blocked else 18000.0
		var gain := lerpf(source.gain_db,gain_target,occlusion_blend)
		var cutoff := lerpf(source.cutoff,cutoff_target,occlusion_blend)
		if absf(gain-gain_target)<.005: gain=gain_target
		if absf(cutoff-cutoff_target)<1.0: cutoff=cutoff_target
		# Do not repeatedly lock the audio server for already-settled parameters.
		if gain!=source.gain_db:
			source.gain_db=gain
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(source.slot.bus),gain)
		if cutoff!=source.cutoff:
			source.cutoff=cutoff
			source.slot.filter.cutoff_hz=cutoff
	for loop in loops:
		var gain := move_toward(loop.gain,loop.target,delta/.9)
		if gain!=loop.gain:
			loop.gain=gain
			loop.player.volume_db=loop.base+linear_to_db(maxf(.0001,gain))
		if _native_playback and loop.gain>.001 and not loop.player.playing:
			loop.player.pitch_scale=_rng.randf_range(.97,1.03)
			loop.player.play()
		elif loop.gain<=.001 and loop.player.playing: loop.player.stop()

func _exit_tree() -> void:
	if is_instance_valid(_weapon): _weapon.bus=_weapon_bus
	for source in sources:
		for route in source.routes:
			if is_instance_valid(route.player): route.player.bus=route.original_bus
	for route in _overflow_routes:
		if is_instance_valid(route.player): route.player.bus=route.original_bus
	for loop in loops:
		if is_instance_valid(loop.player):
			loop.player.stop()
			loop.player.stream=null
	if is_instance_valid(_event):
		_event.stop()
		_event.stream=null
	for index in range(_created_buses.size()-1,-1,-1):
		var bus := AudioServer.get_bus_index(_created_buses[index])
		if bus>=0: AudioServer.remove_bus(bus)
