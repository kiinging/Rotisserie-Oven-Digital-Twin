extends Node3D
class_name CirculationFan

@export var fan_blades_path: NodePath
@export var fan_light_path: NodePath

var running: bool = true
var _blades: Node3D = null
var _light: Light3D = null

func _ready() -> void:
	_blades = get_node_or_null(fan_blades_path) as Node3D
	_light = get_node_or_null(fan_light_path) as Light3D

func set_running(value: bool) -> void:
	running = value

func step(delta: float) -> void:
	if _blades != null and running:
		_blades.rotate_x(deg_to_rad(1200.0) * delta)
	if _light != null:
		_light.light_energy = 1.5 if running else 0.0
