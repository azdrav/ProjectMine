extends Resource
## Reusable listening-space settings. Dry gain is always one, independent of wetness.
@export var label: String = "Open"
@export_range(0,1) var room_size: float = .1
@export_range(0,1) var damping: float = .8
@export_range(0,.2) var wet: float = 0.0
@export_range(0,1) var spread: float = .5
@export_range(0,100) var predelay_ms: float = 12.0
@export_range(0,.3) var predelay_feedback: float = 0.0
