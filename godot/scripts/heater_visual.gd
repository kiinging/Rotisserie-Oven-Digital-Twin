extends Node
class_name HeaterVisual

## Drives the visual appearance of one or more heater elements + lights based on
## a single 0–100% heater command.

@export var heater_meshes: Array[NodePath] = []
@export var heater_lights: Array[NodePath] = []
@export var min_glow_color: Color = Color("#4A1F0F")
@export var max_glow_color: Color = Color("#FF6600")
@export var emission_color: Color = Color("#FF2000")
@export var max_emission_energy: float = 5.0
@export var max_light_energy: float = 2.0

var heater_output: float = 0.0
var _meshes: Array[Node3D] = []
var _lights: Array[Light3D] = []


func _ready() -> void:
	_resolve_nodes()


func _resolve_nodes() -> void:
	_meshes.clear()
	for path in heater_meshes:
		var node: Node = get_node_or_null(path)
		if node is Node3D:
			_meshes.append(node)
	_lights.clear()
	for path in heater_lights:
		var node: Node = get_node_or_null(path)
		if node is Light3D:
			_lights.append(node)


func set_heater_output(value: float) -> void:
	heater_output = clampf(value, 0.0, 1.0)


func apply() -> void:
	var glow: Color = min_glow_color.lerp(max_glow_color, heater_output)
	var emission_energy: float = heater_output * max_emission_energy
	var light_energy: float = heater_output * max_light_energy

	for node in _meshes:
		var mat: StandardMaterial3D = null
		if node is MeshInstance3D:
			mat = node.material_override as StandardMaterial3D
			if mat == null:
				mat = StandardMaterial3D.new()
				node.material_override = mat
		elif node is CSGShape3D:
			mat = node.material as StandardMaterial3D
			if mat == null:
				mat = StandardMaterial3D.new()
				node.material = mat
		if mat == null:
			continue
		mat.albedo_color = glow
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = emission_energy

	for light in _lights:
		light.light_energy = light_energy