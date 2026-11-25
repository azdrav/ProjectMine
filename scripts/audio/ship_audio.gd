extends Node
## Read-only contact observer. It never changes velocity, transforms or damage.
const Sounds = preload("res://scripts/audio/industrial_sounds.gd")
@export var enabled: bool = true
@export_group("Weapon and shield")
@export_range(-40,0) var weapon_volume_db: float = -9.0
@export_range(-40,0) var shield_volume_db: float = -10.0
@export var full_shield_damage: float = 25.0
@export var shield_cooldown: float = .09
@export_group("Hull impact")
@export var impact_threshold: float = 2.5
@export var full_impact_speed: float = 25.0
@export var impact_cooldown: float = .20
@export_range(-40,0) var impact_volume_db: float = -9.0
@export_group("Scraping")
@export var scrape_start_speed: float = 1.5
@export var scrape_stop_speed: float = .8
@export var full_scrape_speed: float = 20.0
@export var sustained_contact_time: float = .055
@export var contact_slop: float = .025
@export var scrape_fade_in: float = .12
@export var scrape_fade_out: float = .16
@export_range(-40,0) var scrape_volume_db: float = -15.0
var emergency: AudioStreamPlayer
var weapon: AudioStreamPlayer
var shield: AudioStreamPlayer
var impact: AudioStreamPlayer
var scrape: AudioStreamPlayer
var weapon_events: int = 0
var impact_events: int = 0
var shield_events: int = 0
var scrape_starts: int = 0
var normal_speed: float = 0.0
var tangent_speed: float = 0.0
var scrape_gain: float = 0.0
var _impact_wait: float = 0.0
var _shield_wait: float = 0.0
var _contact_normal := Vector3.ZERO
var _contact_time: float = 0.0
var _since_sample: float = 1.0
var _scrape_target: float = 0.0
var _probe := KinematicCollision3D.new()
@onready var ship: CharacterBody3D = get_parent()

func _ready() -> void:
	emergency=_channel("EmergencyEmitter","enemy_fire",1)
	weapon=_channel("PlayerWeapon","player_fire",3)
	shield=_channel("ShieldImpact","shield",1)
	impact=_channel("HullImpact","impact",1)
	scrape=_channel("HullScrape","scrape",1)
	ship.weapon_fired.connect(_fire)
	ship.damaged.connect(_damage)
	ship.flight_contact_sample.connect(observe_contacts)
	ship.flight_reset.connect(reset_audio)

func _channel(title: String, kind: String, voices: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name=title
	player.stream=Sounds.player_cannon() if kind == "player_fire" else Sounds.sound(kind)
	player.bus=Sounds.ensure_bus()
	player.max_polyphony=voices
	player.volume_db=-80.0
	add_child(player)
	return player

func _fire() -> void:
	if not enabled: return
	weapon.volume_db=weapon_volume_db
	weapon.play()
	weapon_events += 1

func emergency_fire() -> void:
	if not enabled: return
	emergency.volume_db = -20
	emergency.play()

func _damage(amount: float) -> void:
	if not enabled or _shield_wait>0.0: return
	var severity := clampf(amount/maxf(1.0,full_shield_damage),0.0,1.0)
	shield.volume_db=shield_volume_db+linear_to_db(lerpf(.30,1.0,severity))
	shield.pitch_scale=lerpf(1.12,.88,severity)
	shield.play()
	shield_events+=1
	_shield_wait=maxf(.02,shield_cooldown)

func observe_contacts(incoming: Vector3, delta: float) -> void:
	_since_sample=0.0
	normal_speed=0.0
	tangent_speed=0.0
	var contact := Vector3.ZERO
	var wall_closing: float = -1.0
	for index in range(ship.get_slide_collision_count()):
		var collision := ship.get_slide_collision(index)
		for hit in range(collision.get_collision_count()):
			var normal := collision.get_normal(hit)
			var closing := maxf(0.0,-incoming.dot(normal))
			normal_speed=maxf(normal_speed,closing)
			# A robot can receive a hull bump too; sustained scraping is wall-only.
			if collision.get_collider(hit) is StaticBody3D and closing>wall_closing:
				contact=normal
				wall_closing=closing
	# A perfectly parallel move may produce no slide collision this frame. A tiny
	# test of the real hull retains only an already-established wall contact.
	if contact==Vector3.ZERO and _contact_normal!=Vector3.ZERO:
		if ship.test_move(ship.global_transform,-_contact_normal*maxf(.001,contact_slop),_probe,.001):
			for hit in range(_probe.get_collision_count()):
				if _probe.get_collider(hit) is StaticBody3D:
					contact=_probe.get_normal(hit)
					break
	if enabled and normal_speed>impact_threshold and _impact_wait<=0.0:
		var severity := clampf((normal_speed-impact_threshold)/maxf(1.0,full_impact_speed-impact_threshold),0,1)
		impact.volume_db=impact_volume_db+linear_to_db(lerpf(.15,1.0,severity))
		impact.pitch_scale=lerpf(1.15,.8,severity)
		impact.play()
		impact_events+=1
		_impact_wait=maxf(.02,impact_cooldown)
	_contact_normal=contact
	if contact!=Vector3.ZERO:
		tangent_speed=ship.get_real_velocity().slide(contact).length()
		_contact_time+=delta
	else:
		_contact_time=0.0
	var threshold := scrape_stop_speed if _scrape_target>0.0 else scrape_start_speed
	if enabled and _contact_time>=sustained_contact_time and tangent_speed>threshold:
		_scrape_target=clampf(tangent_speed/maxf(1.0,full_scrape_speed),.05,1.0)
	else: _scrape_target=0.0

func _physics_process(delta: float) -> void:
	_impact_wait=maxf(0.0,_impact_wait-delta)
	_shield_wait=maxf(0.0,_shield_wait-delta)
	_since_sample+=delta
	if not enabled or ship.shield<=0.0 or _since_sample>.08: _scrape_target=0.0
	var fade := scrape_fade_in if _scrape_target>scrape_gain else scrape_fade_out
	scrape_gain=move_toward(scrape_gain,_scrape_target,delta/maxf(.01,fade))
	if scrape_gain>.001:
		scrape.volume_db=scrape_volume_db+linear_to_db(scrape_gain)
		scrape.pitch_scale=move_toward(scrape.pitch_scale,lerpf(.8,1.3,_scrape_target),delta*2.0)
		if not scrape.playing:
			scrape.play()
			scrape_starts+=1
	elif scrape.playing: scrape.stop()

func reset_audio() -> void:
	_contact_normal=Vector3.ZERO
	_contact_time=0.0
	_scrape_target=0.0
	scrape_gain=0.0
	_impact_wait=0.0
	_shield_wait=0.0
	for player in [weapon,shield,impact,scrape,emergency]: player.stop()

func _exit_tree() -> void:
	for player in [weapon,shield,impact,scrape,emergency]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
