extends Node3D
class_name DualRotisserieMechanism

## Dual-rotation rotisserie mechanism.
##
## A single motor drives two mechanical stages:
##   1. Main carousel rotation around the central vertical shaft (Y axis).
##   2. Spit rotation about each spit's own radial axis.
##
## The two are mechanically linked by a fixed gear ratio:
##
##     RPM_spit = RPM_main * gear_ratio
##
## Structure is prepared for independent spit control later by giving each
## SpitNode its own `target_rpm` instead of the shared one.

signal actual_main_rpm_changed(rpm: float)
signal actual_spit_rpm_changed(rpm: float)
signal chickens_changed(count: int)

@export var main_spits: Array[NodePath] = []        ## SpitNode3Ds on the carousel
@export var chicken_holders: Array[NodePath] = []   ## ChickenHolder3Ds under each spit
@export var central_shaft_path: NodePath = ""

@export var chicken_scene: PackedScene
@export var chickens_per_spit: int = 3
@export var spit_length: float = 0.6                 ## total bar length (m)

## Fixed mechanical gear ratio: spit RPM / main RPM.
@export var gear_ratio: float = 5.0

## Nominal main RPM (the PLC will command this).
@export var nominal_main_rpm: float = 2.0

## Maximum commanded main RPM.
@export var max_main_rpm: float = 3.0

## Smoothing time constant for visual RPM (seconds).
@export var rpm_smoothing_tau: float = 0.2

var running: bool = true
var commanded_main_rpm: float = 0.0
var target_main_rpm: float = 0.0
var actual_main_rpm: float = 0.0
var target_spit_rpm: float = 0.0
var actual_spit_rpm: float = 0.0

var _spit_nodes: Array[Node3D] = []
var _chicken_holders: Array[Node3D] = []
var _central_shaft: Node3D = null
var _chicken_count: int = 0


func _ready() -> void:
	_resolve_nodes()
	if _central_shaft == null:
		push_warning("DualRotisserieMechanism: central shaft not found.")
	_populate_chickens()


func _resolve_nodes() -> void:
	_spit_nodes.clear()
	for path in main_spits:
		if path.is_empty():
			continue
		var node: Node = get_node_or_null(path)
		if node is Node3D:
			_spit_nodes.append(node)

	_chicken_holders.clear()
	for path in chicken_holders:
		if path.is_empty():
			continue
		var node: Node = get_node_or_null(path)
		if node is Node3D:
			_chicken_holders.append(node)

	_central_shaft = get_node_or_null(central_shaft_path) as Node3D


func _populate_chickens() -> void:
	if chicken_scene == null:
		return
	if _chicken_holders.is_empty():
		for i in range(_spit_nodes.size()):
			var holder: Node3D = Node3D.new()
			holder.name = "ChickenHolder_%d" % (i + 1)
			_spit_nodes[i].add_child(holder)
			_chicken_holders.append(holder)

	# Margin on each side of the spit (adjustable)
	var margin: float = 0.05
	# Number of gaps between chickens (at least 1 to avoid div‑by‑zero)
	var gaps: int = max(chickens_per_spit - 1, 1)
	# Spacing between chicken centres after removing margins
	var spacing: float = (spit_length - 2.0 * margin) / float(gaps)
	# Starting X position after left margin
	var start_x: float = -spit_length * 0.5 + margin

	for h in range(_chicken_holders.size()):
		var holder: Node3D = _chicken_holders[h]
		for c in range(chickens_per_spit):
			var chicken: Node3D = chicken_scene.instantiate()
			if chicken == null:
				continue
			chicken.name = "Chicken_S%d_C%d" % [h + 1, c + 1]
			holder.add_child(chicken)
			var x: float = start_x + c * spacing
			# Small realistic variation around the spit axis.
			var base_tilt_x: float = randf_range(-0.18, 0.18)
			var yaw: float = 0.0
			var roll: float = randf_range(-0.10, 0.10)
			chicken.position = Vector3(-0.05, x, 0.0)
			chicken.rotation = Vector3(0, 0, 80)
			chicken.scale = Vector3(0.33, 0.33, 0.33)
			_chicken_count += 1
	chickens_changed.emit(_chicken_count)


func set_running(value: bool) -> void:
	running = value
	if not running:
		actual_main_rpm = 0.0
		actual_spit_rpm = 0.0
		actual_main_rpm_changed.emit(actual_main_rpm)
		actual_spit_rpm_changed.emit(actual_spit_rpm)


func set_commanded_main_rpm(rpm: float) -> void:
	commanded_main_rpm = clampf(rpm, 0.0, max_main_rpm)


func set_nominal_speed() -> void:
	set_commanded_main_rpm(nominal_main_rpm)


func step(delta: float) -> void:
	if running:
		target_main_rpm = commanded_main_rpm
	else:
		target_main_rpm = 0.0

	target_spit_rpm = target_main_rpm * gear_ratio

	# First-order smoothing toward target RPM.
	var alpha: float = clampf(delta / maxf(rpm_smoothing_tau, 0.001), 0.0, 1.0)
	actual_main_rpm = lerpf(actual_main_rpm, target_main_rpm, alpha)
	actual_spit_rpm = lerpf(actual_spit_rpm, target_spit_rpm, alpha)

	# Main rotation: around the central horizontal shaft (X axis).
	var main_omega: float = deg_to_rad(actual_main_rpm * 360.0) / 60.0
	if _central_shaft != null:
		_central_shaft.rotate_x(main_omega * delta)

	# Spit rotation: each spit rotates about its own longitudinal axis.
	# The spit bar runs along the spit's local X axis (radial from carousel center),
	# so we rotate around X to make chickens spin end-over-end on the bar.
	var spit_omega: float = deg_to_rad(actual_spit_rpm * 360.0) / 60.0
	for spit in _spit_nodes:
		spit.rotate_x(spit_omega * delta)

	actual_main_rpm_changed.emit(actual_main_rpm)
	actual_spit_rpm_changed.emit(actual_spit_rpm)
