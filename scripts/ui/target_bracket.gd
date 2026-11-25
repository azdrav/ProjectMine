extends Control
## Passive cannon sensor readout. Never adjusts aim, projectiles or missile locks.
@export var maximum_distance: float = 70.0
@export var acquisition_cone_degrees: float = 12.0
@export var linger_seconds: float = 0.85
@export var scan_interval: float = 0.10
var ship
var target: Node3D
var screen_rect:=Rect2()
var _remaining:=0.0
var _scan_wait:=0.0
var _hit_flash:=0.0
var _local_bounds:=AABB()
var _view: Camera3D
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view=ship.get_node("Camera3D/VisualOffset/RenderCamera")
	ship.weapon_fired.connect(note_shot)
	ship.hit_confirmed.connect(func(): _hit_flash=.13)
	ship.flight_reset.connect(clear)
func note_shot() -> void:
	_remaining=linger_seconds
	_scan_wait=0
func clear() -> void:
	target=null;screen_rect=Rect2();_remaining=0;_scan_wait=0;_hit_flash=0
	queue_redraw()
func _physics_process(delta: float) -> void:
	_remaining=maxf(0,_remaining-delta)
	_hit_flash=maxf(0,_hit_flash-delta)
	if ship.shield<=0 or _remaining<=0:
		target=null
		return
	_scan_wait-=delta
	if _scan_wait<=0:
		_scan_wait=maxf(.03,scan_interval)
		acquire()
func aim_screen_position() -> Vector2:
	# Exactly the HUD's cannon aim point, including inherited ship velocity and shake projection.
	var feedback=ship.get_node("Camera3D/VisualOffset")
	return _view.unproject_position(feedback.aim_point)
func visible_contact(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or enemy.get("health")==null or enemy.health<=0 or not enemy.is_visible_in_tree(): return false
	var offset: Vector3=enemy.global_position-ship.camera.global_position
	if offset.length()<.05 or offset.length()>maximum_distance or _view.is_position_behind(enemy.global_position): return false
	var direction: Vector3=(-ship.camera.global_basis.z*ship.laser_speed+ship.velocity).normalized()
	if offset.normalized().dot(direction)<cos(deg_to_rad(acquisition_cone_degrees)): return false
	var ray:=PhysicsRayQueryParameters3D.create(ship.camera.global_position,enemy.global_position,5)
	var hit: Dictionary=ship.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider==enemy
func acquire() -> void:
	var nearest: Node3D
	var best:=INF
	var aim:=aim_screen_position()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not visible_contact(enemy): continue
		var distance:=_view.unproject_position(enemy.global_position).distance_squared_to(aim)
		if distance<best:
			best=distance;nearest=enemy
	target=nearest
	if is_instance_valid(target): _local_bounds=model_bounds(target)
func model_bounds(enemy: Node3D) -> AABB:
	var visual:=enemy.get_node_or_null("Visual")
	var bounds:=AABB();var found:=false
	if visual:
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh or not mesh.is_visible_in_tree(): continue
			# World to actor coordinates includes variant scale and component transforms.
			var local_box: AABB=(enemy.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
			bounds=bounds.merge(local_box) if found else local_box
			found=true
	return bounds if found else AABB(Vector3.ONE*-.7,Vector3.ONE*1.4)
func projected_bounds() -> Rect2:
	if not is_instance_valid(target) or target.health<=0: return Rect2()
	var rect:=Rect2();var first:=true
	for i in range(8):
		var point: Vector3=target.to_global(_local_bounds.get_endpoint(i))
		# Do not project corners behind the camera into a huge, inverted box.
		if _view.is_position_behind(point): return Rect2()
		var p:=_view.unproject_position(point)
		if first: rect=Rect2(p,Vector2.ZERO);first=false
		else: rect=rect.expand(p)
	return rect.grow(7).intersection(get_viewport_rect().grow(-4))
func _process(_delta: float) -> void:
	screen_rect=projected_bounds() if _remaining>0 and ship.shield>0 and _view.is_current() else Rect2()
	queue_redraw()
func _draw() -> void:
	if not screen_rect.has_area(): return
	var alpha:=clampf(_remaining/.18,0,1)
	var color:=Color(1,.68,.22,.9*alpha) if _hit_flash>0 else Color(.32,.88,.83,.8*alpha)
	var weak:=color;weak.a*=.16
	draw_rect(screen_rect,weak,false,1)
	var length:=minf(17,minf(screen_rect.size.x,screen_rect.size.y)*.25)
	for side in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
		var corner: Vector2=screen_rect.position+screen_rect.size*side
		draw_line(corner,corner+Vector2(length*(1-2*side.x),0),color,1.5,true)
		draw_line(corner,corner+Vector2(0,length*(1-2*side.y)),color,1.5,true)
