extends Node3D
## Translation-only visual camera mount. Aim camera and collision body stay untouched.
@export var ship_path: NodePath = NodePath("../..")
@export_group("Comfort limits")
@export_range(0.0,1.0) var intensity: float = 1.0
@export var damping: float = 32.0
@export var maximum_displacement: float = 0.035
@export_group("Weapon recoil")
@export var recoil_intensity: float = 0.012
@export var recoil_duration: float = 0.075
@export var recoil_recovery: float = 0.19
@export_group("Shield impacts")
@export var hit_intensity: float = 0.022
@export var hit_duration: float = 0.24
@export var full_hit_damage: float = 25.0
@export_group("Hull impacts")
@export var collision_intensity: float = 0.030
@export var collision_duration: float = 0.22
@export var impact_threshold: float = 2.5
@export var full_impact_speed: float = 25.0
@export var collision_cooldown: float = 0.18
@export_group("Scraping")
@export var scrape_intensity: float = 0.0015
@export var scrape_start_speed: float = 1.5
@export var full_scrape_speed: float = 20.0
@export var contact_slop: float = 0.025
var channels: Dictionary = {}
var scrape_gain: float = 0.0
var impact_events := 0
var normal_speed := 0.0
var _scrape_target := 0.0
var _contact_normal := Vector3.ZERO
var _contact_time := 0.0
var _sample_age := 1.0
var _impact_wait := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _probe := KinematicCollision3D.new()
var aim_point := Vector3.ZERO
@onready var ship: CharacterBody3D = get_node(ship_path)
@onready var aim_camera: Camera3D = get_parent()
@onready var render_camera: Camera3D = $RenderCamera
@onready var settings = get_node("/root/FeedbackSettings")
func _ready() -> void:
	process_priority = -10
	_rng.randomize()
	ship.weapon_fired.connect(weapon_impulse)
	ship.impact_feedback.connect(hit_impulse)
	ship.flight_contact_sample.connect(observe_contacts)
	ship.flight_reset.connect(reset_feedback)
	settings.changed.connect(_setting_changed)
	update_aim_point()

func _setting_changed(value: float) -> void:
	if value <= 0.0: reset_feedback()

func add_impulse(channel: String, amplitude: float, duration: float, direction: Vector3, world: bool) -> void:
	if settings.intensity <= 0.0 or intensity <= 0.0 or amplitude <= 0.0: return
	# Each channel replaces its previous impulse, rather than summing rapid hits.
	channels[channel] = {"amplitude":minf(amplitude,maxf(0.0,maximum_displacement)),"duration":maxf(0.01,duration),"age":0.0,"direction":direction.normalized(),"world":world,"phase":_rng.randf()*TAU}
func weapon_impulse() -> void:
	add_impulse("weapon",recoil_intensity,recoil_duration+recoil_recovery,Vector3.BACK,false)
func hit_impulse(amount: float, incoming: Vector3) -> void:
	var direction := incoming if not incoming.is_zero_approx() else ship.global_basis.z
	add_impulse("shield",hit_intensity*clampf(amount/maxf(1.0,full_hit_damage),0,1),hit_duration,direction,true)

func observe_contacts(incoming: Vector3, delta: float) -> void:
	_sample_age = 0.0
	normal_speed = 0.0
	var contact := Vector3.ZERO
	for index in range(ship.get_slide_collision_count()):
		var collision := ship.get_slide_collision(index)
		for hit in range(collision.get_collision_count()):
			if not collision.get_collider(hit) is StaticBody3D: continue
			var normal := collision.get_normal(hit)
			var closing := maxf(0.0,-incoming.dot(normal))
			if contact.is_zero_approx() or closing > normal_speed: contact = normal
			normal_speed = maxf(normal_speed,closing)
	if contact.is_zero_approx() and not _contact_normal.is_zero_approx():
		if ship.test_move(ship.global_transform,-_contact_normal*maxf(0.001,contact_slop),_probe,0.001):
			for hit in range(_probe.get_collision_count()):
				if _probe.get_collider(hit) is StaticBody3D:
					contact = _probe.get_normal(hit)
					break
	if normal_speed > impact_threshold and _impact_wait <= 0.0:
		var strength := clampf((normal_speed-impact_threshold)/maxf(1.0,full_impact_speed-impact_threshold),0,1)
		add_impulse("wall",collision_intensity*strength,collision_duration,contact,true)
		impact_events += 1
		_impact_wait = maxf(0.02,collision_cooldown)
	_contact_normal = contact
	_contact_time = _contact_time+delta if not contact.is_zero_approx() else 0.0
	var tangent := ship.get_real_velocity().slide(contact).length() if not contact.is_zero_approx() else 0.0
	_scrape_target = clampf(tangent/maxf(1.0,full_scrape_speed),0,1) if _contact_time >= 0.055 and tangent > scrape_start_speed else 0.0

func _physics_process(delta: float) -> void:
	_sample_age += delta
	_impact_wait = maxf(0.0,_impact_wait-delta)
	if _sample_age > 0.08 or ship.shield <= 0.0: _scrape_target = 0.0
	update_aim_point()

func update_aim_point() -> void:
	# Same origin, inherited velocity and collision mask as an actual player shot.
	var origin := aim_camera.global_position
	var direction: Vector3 = (-aim_camera.global_basis.z*ship.laser_speed+ship.velocity).normalized()
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*200.0,5)
	var hit := ship.get_world_3d().direct_space_state.intersect_ray(query)
	aim_point = hit.position if not hit.is_empty() else origin+direction*200.0

func _process(delta: float) -> void:
	advance(delta)
	# Keep editor FOV/near-plane changes compatible with the existing aim camera.
	render_camera.fov = aim_camera.fov
	render_camera.near = aim_camera.near
	render_camera.far = aim_camera.far

func advance(delta: float) -> void:
	_time += delta
	var scale_factor: float = clampf(settings.intensity*intensity,0,1)
	if scale_factor <= 0.0:
		reset_feedback()
		return
	scrape_gain = lerpf(scrape_gain,_scrape_target,1.0-exp(-40.0*delta))
	if scrape_gain < 0.001: scrape_gain = 0.0
	var desired := Vector3.ZERO
	for key in channels.keys():
		var impulse: Dictionary = channels[key]
		impulse.age += delta
		var t: float = impulse.age/impulse.duration
		if t >= 1.0:
			channels.erase(key)
			continue
		if key == "weapon":
			var envelope := cannon_envelope(impulse.age,recoil_duration,recoil_recovery)
			desired += Vector3.BACK*impulse.amplitude*envelope
			continue
		var direction: Vector3 = ship.global_basis.inverse()*impulse.direction if impulse.world else impulse.direction
		var wave := Vector3(sin(t*23.0+impulse.phase),sin(t*31.0+impulse.phase*1.7),sin(t*19.0))
		var envelope := (1.0-t)*(1.0-t)
		desired += (direction*0.7+wave*0.3)*impulse.amplitude*envelope
	desired += Vector3(sin(_time*67),sin(_time*83+0.8),sin(_time*59)*0.3)*scrape_gain*scrape_intensity
	desired = desired.limit_length(maxf(0.0,maximum_displacement))*scale_factor
	position = position.lerp(desired,1.0-exp(-maxf(0.1,damping)*delta)).limit_length(maxf(0.0,maximum_displacement)*scale_factor)
	if channels.is_empty() and scrape_gain == 0.0 and position.length() < 0.00001: position = Vector3.ZERO
	# No angular shake: the view axis always stays parallel to the true aim axis.
	rotation = Vector3.ZERO

static func cannon_envelope(age: float, impulse: float, recovery: float) -> float:
	# Fast mechanical compression, a short loaded hold, then a smooth spring return.
	var attack := minf(0.012,maxf(0.001,impulse)*0.25)
	if age < attack: return sin(clampf(age/attack,0,1)*PI/2)
	if age < impulse: return lerpf(1.0,0.85,(age-attack)/maxf(0.001,impulse-attack))
	return 0.85*(1.0-smoothstep(0.0,1.0,(age-impulse)/maxf(0.001,recovery)))

func reset_feedback() -> void:
	channels.clear()
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scrape_gain = 0.0
	_scrape_target = 0.0
	_contact_normal = Vector3.ZERO
	_contact_time = 0.0
	_impact_wait = 0.0
