extends Node3D
## Analytic oriented box, deliberately not a physics Area3D/collider.
@export var profile: Resource
@export var dimensions := Vector3(8,8,20)
@export_range(.1,10) var blend_margin: float = 1.5
@export_range(.1,4) var weight_scale: float = 1.0
func weight_at(point: Vector3) -> float:
	var offset := to_local(point).abs()-dimensions*.5
	var distance := offset.max(Vector3.ZERO).length()+minf(maxf(offset.x,maxf(offset.y,offset.z)),0.0)
	return (1.0-smoothstep(-blend_margin,blend_margin,distance))*weight_scale
