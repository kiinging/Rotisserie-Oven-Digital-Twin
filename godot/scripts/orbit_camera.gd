extends Camera3D
class_name OrbitCamera

## Free orbit camera control.
##
## * Left mouse drag  -> orbit (yaw / pitch)
## * Right mouse drag -> pan
## * Mouse wheel       -> zoom (dolly)
## * 1/3/7 keys        -> jump to front / side / top view
##
## The camera pivots around `target` (Vector3) and stores its current spherical
## coordinates in `yaw`, `pitch`, `distance`.

@export var target: Vector3 = Vector3(0, 0, 0)
@export var min_distance: float = 1.0
@export var max_distance: float = 30.0
@export var orbit_speed: float = 0.005
@export var pan_speed: float = 0.0025
@export var zoom_speed: float = 1.0

var yaw: float = 0.0
var pitch: float = 0.0
var distance: float = 8.0


func _ready() -> void:
	# Initialise from the camera's current transform relative to `target`.
	var offset_v: Vector3 = global_position - target
	distance = max(min_distance, offset_v.length())
	if distance > 0.0001:
		var n: Vector3 = offset_v / distance
		pitch = asin(clampf(n.y, -1.0, 1.0))
		yaw = atan2(n.x, n.z)
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance - zoom_speed, min_distance, max_distance)
				_apply_transform()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance + zoom_speed, min_distance, max_distance)
				_apply_transform()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mm: InputEventMouseMotion = event
			yaw -= mm.relative.x * orbit_speed
			pitch -= mm.relative.y * orbit_speed
			pitch = clampf(pitch, -1.4, 1.4)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var mm2: InputEventMouseMotion = event
			var right: Vector3 = -global_transform.basis.x
			var up: Vector3 = global_transform.basis.y
			target += -(right * mm2.relative.x + up * mm2.relative.y) * pan_speed * distance
			_apply_transform()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_view(0.0, deg_to_rad(15.0), 8.0)   # front
			KEY_3:
				_set_view(deg_to_rad(90.0), deg_to_rad(15.0), 8.0)  # side
			KEY_7:
				_set_view(0.0, deg_to_rad(89.0), 8.0)   # top


func _set_view(new_yaw: float, new_pitch: float, new_distance: float) -> void:
	yaw = new_yaw
	pitch = new_pitch
	distance = clampf(new_distance, min_distance, max_distance)
	_apply_transform()


func _apply_transform() -> void:
	var cy: float = cos(pitch)
	var offset: Vector3 = Vector3(
		distance * cy * sin(yaw),
		distance * sin(pitch),
		distance * cy * cos(yaw)
	)
	global_position = target + offset
	look_at(target, Vector3.UP)