extends CanvasLayer
@export var ship_path: NodePath
@onready var ship = get_node(ship_path)
@onready var status: Label = $Status

func _process(_delta: float) -> void:
	status.text = "PROJECTMINE   /   FLIGHT TEST\n\nSPEED   %05.1f m/s%s\nSHIELD  %03d %%\nENERGY  %03d %%" % [ship.get_real_velocity().length(), "  BOOST" if ship.boosting else "", ship.shield, ship.energy]
	if ship.boost_exhausted:
		status.text += "\nBOOST: release Shift to rearm"
