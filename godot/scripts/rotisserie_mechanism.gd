extends Node3D
class_name RotisserieMechanism

## Visual + mechanical rotisserie simulation.
##
## Three spits are mechanically linked to a single motor drive. Each spit is
## rotated by the same angular velocity, scaled from the commanded RPM.
##
## Structure is intentionally prepared for independent spit control: the array
## `spits` holds per-spit state but currently all spits share `angular_velocity`.
## Independent control can be added later by giving each spit its own target
## RPM in `target_rpm_by_spit` instead of the shared `target_rpm`.

signal actual_rpm_changed(rpm: float)
signal chickens_changed(count: int)

## Spits in drive order (front -> back or top -> bottom). Each entry must be a
## Node3D whose local X axis is the rotation axis.
@export var spits: Array[NodePath] = []

## Optional Node3D under each spit that already holds the chicken mesh instances.
## If empty, the mechanism will instance chickens from `chicken_scene` itself.
@export var chicken_holders: Array[NodePath] = []

@export var chicken_scene: PackedScene
@export var chickens_per_spit: int = 5

## Visual length (m) of each spit, used to lay out chickens along X.
@export var spit_length: float = 2.4

## Maximum nominal rotisserie RPM. The PLC will command RPM, but visually we
## scale to rad/s for `rotate_x()`.
@export var max_commanded_rpm: float = 6.0

## Nominal cooking RPM used for the initial `target_rpm` value.
@export var nominal_cooking_rpm: float = 4.0

## Smoothing time constant for visual RPM (seconds). Keeps the rotation smooth.
@export var rpm_smoothing_tau: float = 0.25

var running: bool = true
var commanded_rpm: float = 0.0
var target_rpm: float = 0.0
var actual_rpm: float = 0.0
var angular_velocity: float = 0.0     # rad/s about the local X axis

var _spit_nodes: Array[Node3D] = []
var _chicken_holders: Array[Node3D] = []
var _chicken_count: int = 0


func _ready() -> void:
	_resolve_nodes()
	if _spit_nodes.is_empty():
		push_warning("RotisserieMechanism: no spits assigned.")
	_populate_chickens()


func _resolve_nodes() -> void:
	_spit_nodes.clear()
	for path in spits:
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


func _populate_chickens() -> void:
	if chicken_scene == null:
		return
	if _chicken_holders.is_empty():
		# Create one holder per spit if none were pre-authored.
		for i in range(_spit_nodes.size()):
			var holder: Node3D = Node3D.new()
			holder.name = "ChickenHolder_%d" % (i + 1)
			_spit_nodes[i].add_child(holder)
			_chicken_holders.append(holder)

	var spacing: float = spit_length / float(maxi(chickens_per_spit, 1) + 1)
	var start_x: float = -spit_length * 0.5 + spacing

	for h in range(_chicken_holders.size()):
		var holder: Node3D = _chicken_holders[h]
		for c in range(chickens_per_spit):
			var chicken: Node3D = chicken_scene.instantiate()
			if chicken == null:
				continue
			chicken.name = "Chicken_S%d_C%d" % [h + 1, c + 1]
			holder.add_child(chicken)
			var x: float = start_x + c * spacing
			# Small realistic variation around the spit. The base glb already
			# orients the chicken along X, so we just add a tiny tilt around
			# the X axis plus a small yaw so chickens are not all identical.
			var base_tilt_x: float = randf_range(-0.18, 0.18)
			var yaw: float = randf_range(-0.25, 0.25)
			var roll: float = randf_range(-0.10, 0.10)
			chicken.position = Vector3(x, 0.0, 0.0)
			chicken.rotation = Vector3(base_tilt_x, yaw, roll)
			_chicken_count += 1
	chickens_changed.emit(_chicken_count)


func set_running(value: bool) -> void:
	running = value
	if not running:
		actual_rpm = 0.0
		angular_velocity = 0.0
		actual_rpm_changed.emit(actual_rpm)


func set_commanded_rpm(rpm: float) -> void:
	commanded_rpm = clampf(rpm, 0.0, max_commanded_rpm)
	target_rpm = commanded_rpm if running else 0.0


func set_nominal_speed() -> void:
	set_commanded_rpm(nominal_cooking_rpm)


func step(delta: float) -> void:
	if running:
		target_rpm = commanded_rpm
	else:
		target_rpm = 0.0

	# First-order smoothing toward target RPM.
	var alpha: float = clampf(delta / maxf(rpm_smoothing_tau, 0.001), 0.0, 1.0)
	actual_rpm = lerpf(actual_rpm, target_rpm, alpha)
	angular_velocity = deg_to_rad(actual_rpm * 360.0) / 60.0

	for spit in _spit_nodes:
		spit.rotate_x(angular_velocity * delta)

	actual_rpm_changed.emit(actual_rpm)