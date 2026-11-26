extends Control
class_name SilentBladeVirtualJoystick

signal axis_changed(value: float)

@export var dead_zone := 0.18
@export var knob_radius := 30.0

var axis_value := 0.0
var _active_touch := -1
var _mouse_active := false
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _radius := 66.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5
	_knob = _center
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		if _active_touch == -1 and not _mouse_active:
			_knob = _center
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch == -1 and Rect2(Vector2.ZERO, size).has_point(event.position):
			_active_touch = event.index
			_update_axis(event.position)
			accept_event()
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			_reset_axis()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch:
		_update_axis(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
			_mouse_active = true
			_update_axis(event.position)
			accept_event()
		elif not event.pressed and _mouse_active:
			_mouse_active = false
			_reset_axis()
			accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_axis(event.position)
		accept_event()

func _update_axis(local_position: Vector2) -> void:
	var delta := local_position - _center
	var clamped := Vector2(clampf(delta.x, -_radius, _radius), clampf(delta.y, -_radius, _radius))
	_knob = _center + clamped
	var next_axis := clamped.x / _radius
	if absf(next_axis) < dead_zone:
		next_axis = 0.0
	if not is_equal_approx(next_axis, axis_value):
		axis_value = next_axis
		axis_changed.emit(axis_value)
	queue_redraw()

func cancel_input() -> void:
	_active_touch = -1
	_mouse_active = false
	_reset_axis()

func _reset_axis() -> void:
	_knob = _center
	if not is_zero_approx(axis_value):
		axis_value = 0.0
		axis_changed.emit(0.0)
	queue_redraw()

func _draw() -> void:
	draw_circle(_center, _radius, Color(0.035, 0.045, 0.085, 0.48))
	draw_arc(_center, _radius, 0.0, TAU, 48, Color(0.78, 0.76, 0.84, 0.68), 3.0)
	draw_circle(_knob, knob_radius, Color(0.55, 0.57, 0.68, 0.72))
	draw_arc(_knob, knob_radius, 0.0, TAU, 32, Color(0.94, 0.91, 0.95, 0.85), 2.0)
