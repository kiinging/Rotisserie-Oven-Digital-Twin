extends Node3D
class_name OvenDoor

## Front glass door for the rotisserie oven.
##
## The door is parented as a Node3D. To get realistic hinge behaviour the door
## itself should be a child Node3D whose origin sits at the hinge edge. This
## script rotates that child around the Y axis between a closed angle and an
## open angle.

signal closed_changed(is_closed: bool)

@export var door_pivot_path: NodePath
@export var open_angle_deg: float = -75.0
@export var close_angle_deg: float = 0.0
@export var animation_duration: float = 0.6

var is_closed: bool = true
var _target_angle_deg: float = 0.0
var _current_angle_deg: float = 0.0
var _animation_time: float = 0.0
var _animation_active: bool = false
var _pivot: Node3D = null


func _ready() -> void:
	_pivot = get_node_or_null(door_pivot_path) as Node3D
	if _pivot == null:
		# Fallback: rotate self. Author the scene so that the door pivot is
		# the inner child and the door mesh is offset from it.
		_pivot = self
	_apply_angle(close_angle_deg)


func set_closed(value: bool) -> void:
	if value == is_closed and not _animation_active:
		return
	is_closed = value
	_target_angle_deg = close_angle_deg if value else open_angle_deg
	_animation_time = 0.0
	_animation_active = true
	closed_changed.emit(is_closed)


func toggle() -> void:
	set_closed(not is_closed)


func step(delta: float) -> void:
	if not _animation_active:
		return
	_animation_time += delta
	var t: float = clampf(_animation_time / maxf(animation_duration, 0.001), 0.0, 1.0)
	# Smooth ease-in/out via t*t*(3-2t) for nicer feel.
	var s: float = t * t * (3.0 - 2.0 * t)
	_current_angle_deg = lerpf(_current_angle_deg, _target_angle_deg, s)
	_apply_angle(_current_angle_deg)
	if t >= 1.0:
		_current_angle_deg = _target_angle_deg
		_apply_angle(_current_angle_deg)
		_animation_active = false


func _apply_angle(angle_deg: float) -> void:
	_pivot.rotation.y = deg_to_rad(angle_deg)