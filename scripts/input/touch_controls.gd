extends Control
class_name SilentBladeTouchControls
## Unified Android multitouch layer: analog stick, action buttons and the pause button.
##
## Why this exists: up to v0.5 the action buttons were Button controls. In Godot 4 a Button only
## reacts to mouse events, and Android touches are converted to mouse events for ONE finger
## only (the first one that is down). While the joystick finger was down, every other finger was
## invisible to the buttons, so jump/attack/dash/block/grapple did not work while moving.
##
## This node reads InputEventScreenTouch / InputEventScreenDrag directly in _input(). Every
## finger (event.index) gets exactly one owner when it goes down (a button, the stick or pause)
## and keeps it until it lifts or is cancelled, so fingers can never reset each other.
## The owners drive the ordinary Input actions, so player.gd keeps polling Input as before.

signal pause_pressed

@export var button_scale := 1.0:
	set(value):
		button_scale = clampf(value, 0.6, 1.6)
		if is_node_ready():
			_relayout()
@export var button_opacity := 1.0:
	set(value):
		button_opacity = clampf(value, 0.2, 1.0)
		queue_redraw()
@export var stick_sensitivity := 1.0
@export var stick_floating := true
@export var stick_follows_thumb := true
@export var debug_overlay := false

const MOUSE_POINTER_ID := -100
const BASE_SIZE := Vector2(1280.0, 720.0)
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const STICK_ZONE_RATIO := 0.46
const STICK_RADIUS := 104.0
const STICK_KNOB_RADIUS := 44.0
const STICK_DEADZONE := 0.20
const STICK_EDGE_MARGIN := 18.0
const HIT_PADDING := 14.0
const PAUSE_RADIUS := 30.0
const PAUSE_HIT_RADIUS := 46.0

# offset = distance of the button centre from the bottom-right corner (x to the left, y upwards)
# in the 1280x720 design space. Everything is scaled with the real viewport size at runtime.
const BUTTON_DEFS := [
	{"action": "attack", "label": "УДАР", "glyph": "", "offset": Vector2(124.0, 124.0), "radius": 66.0},
	{"action": "jump", "label": "ПРЫЖОК", "glyph": "", "offset": Vector2(124.0, 262.0), "radius": 58.0},
	{"action": "dash", "label": "РЫВОК", "glyph": "", "offset": Vector2(256.0, 110.0), "radius": 52.0},
	{"action": "grapple", "label": "КРЮК", "glyph": "", "offset": Vector2(256.0, 232.0), "radius": 52.0},
	{"action": "block", "label": "БЛОК", "glyph": "", "offset": Vector2(370.0, 120.0), "radius": 48.0},
	{"action": "crouch", "label": "", "glyph": "crouch", "offset": Vector2(370.0, 240.0), "radius": 46.0},
	{"action": "distract", "label": "ШУМ", "glyph": "", "offset": Vector2(465.0, 345.0), "radius": 38.0},
	{"action": "interact", "label": "ДЕЙСТВИЕ", "glyph": "", "offset": Vector2(545.0, 255.0), "radius": 48.0, "context": true}
]

var enabled := true
var stick_axis := 0.0
var interaction_prompt := ""

var _ui_scale := 1.0
var _buttons: Array[Dictionary] = []
var _pause_center := Vector2.ZERO
var _stick_home := Vector2.ZERO
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _stick_finger := -1
var _fingers: Dictionary = {}          # finger index -> {"kind": "button"|"stick"|"pause", ...}
var _all_touches: Dictionary = {}      # every finger currently down (owned or not), diagnostics only
var _held_by: Dictionary = {}          # action -> finger index that is holding it
var _press_frame: Dictionary = {}      # action -> physics frame counter at the moment of press
var _pending_release: Dictionary = {}  # actions released by the finger but not yet seen by physics
var _left_down := false
var _right_down := false
var _mouse_fallback := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# This node never takes part in GUI mouse routing: it reads raw touches in _input().
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Desktop/editor testing: with no touch screen the left mouse button acts as one finger.
	_mouse_fallback = not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile")
	_relayout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		release_all()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release_all()

func set_interaction_prompt(value: String) -> void:
	var normalized := value.strip_edges()
	if interaction_prompt == normalized:
		return
	interaction_prompt = normalized
	_relayout()

func _interaction_button_label() -> String:
	if interaction_prompt.contains("ОТКЛЮЧИТЬ"):
		return "ОТКЛЮЧИТЬ"
	if interaction_prompt.contains("ЗАБРАТЬ") or interaction_prompt.contains("ТАЙНИК") or interaction_prompt.contains("ЗАПИСКА"):
		return "ВЗЯТЬ"
	if interaction_prompt.contains("ЭВАКУАЦИЯ"):
		return "УЙТИ"
	if interaction_prompt.contains("ОТКРЫТЬ"):
		return "ОТКРЫТЬ"
	return "ДЕЙСТВИЕ"

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		release_all()
	queue_redraw()

func release_all() -> void:
	var had_input := _has_live_input()
	_fingers.clear()
	_all_touches.clear()
	for action in _held_by.keys():
		Input.action_release(action)
	_held_by.clear()
	for action in _pending_release.keys():
		Input.action_release(action)
	_pending_release.clear()
	_reset_stick()
	if had_input:
		queue_redraw()

func _has_live_input() -> bool:
	return not _fingers.is_empty() or not _held_by.is_empty() or not _pending_release.is_empty() or _left_down or _right_down

func _is_active() -> bool:
	return enabled and is_inside_tree() and is_visible_in_tree() and not get_tree().paused

# ---------------------------------------------------------------- read-only API

func get_button_center(action: String) -> Vector2:
	for button in _buttons:
		if String(button["action"]) == action:
			var center: Vector2 = button["center"]
			return center
	return Vector2.INF

func get_button_radius(action: String) -> float:
	for button in _buttons:
		if String(button["action"]) == action:
			return float(button["radius"])
	return 0.0

func get_button_actions() -> PackedStringArray:
	var actions := PackedStringArray()
	for button in _buttons:
		actions.append(String(button["action"]))
	return actions

func get_pause_center() -> Vector2:
	return _pause_center

func get_stick_start_point() -> Vector2:
	# A point that is inside the stick zone and clear of every button.
	var view := _view_size()
	return Vector2(view.x * 0.2, view.y * 0.72)

func get_stick_radius() -> float:
	return STICK_RADIUS * _ui_scale

func is_stick_active() -> bool:
	return _stick_finger != -1

func is_action_held(action: String) -> bool:
	return _held_by.has(action)

func _view_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return BASE_SIZE

func _relayout() -> void:
	var view := _view_size()
	_ui_scale = clampf(minf(view.x / BASE_SIZE.x, view.y / BASE_SIZE.y), 0.7, 1.6) * button_scale
	_buttons.clear()
	for entry in BUTTON_DEFS:
		var item: Dictionary = entry
		if bool(item.get("context", false)) and interaction_prompt.is_empty():
			continue
		var offset: Vector2 = item["offset"]
		var label := _interaction_button_label() if String(item["action"]) == "interact" else String(item["label"])
		var button := {
			"action": item["action"],
			"label": label,
			"glyph": item["glyph"],
			"radius": float(item["radius"]) * _ui_scale,
			"center": Vector2(view.x - offset.x * _ui_scale, view.y - offset.y * _ui_scale)
		}
		_buttons.append(button)
	_pause_center = Vector2(view.x - 54.0 * _ui_scale, 54.0 * _ui_scale)
	_stick_home = Vector2(160.0 * _ui_scale, view.y - 152.0 * _ui_scale)
	if _stick_finger == -1:
		_stick_origin = _stick_home
		_stick_knob = _stick_home
	queue_redraw()

# ---------------------------------------------------------------- raw touch routing

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not touch.canceled:
			_all_touches[touch.index] = true
		else:
			_all_touches.erase(touch.index)
		if debug_overlay:
			queue_redraw()
	if not _is_active():
		if _has_live_input():
			release_all()
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		# A finger index that is still mapped means we missed its release: drop the stale owner first.
		_end_touch(touch.index)
		if touch.pressed and not touch.canceled:
			_begin_touch(touch.index, _to_local(touch.position))
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_move_touch(drag.index, _to_local(drag.position))
	elif _mouse_fallback and event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_LEFT:
			_end_touch(MOUSE_POINTER_ID)
			if click.pressed:
				_begin_touch(MOUSE_POINTER_ID, _to_local(click.position))
	elif _mouse_fallback and event is InputEventMouseMotion and _fingers.has(MOUSE_POINTER_ID):
		var motion: InputEventMouseMotion = event
		_move_touch(MOUSE_POINTER_ID, _to_local(motion.position))

func _to_local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin_touch(finger: int, point: Vector2) -> void:
	var index := _button_index_at(point)
	if index >= 0:
		var action: String = _buttons[index]["action"]
		if _held_by.has(action):
			return
		_fingers[finger] = {"kind": "button", "action": action}
		_held_by[action] = finger
		_press(action)
	elif point.distance_to(_pause_center) <= PAUSE_HIT_RADIUS * _ui_scale:
		_fingers[finger] = {"kind": "pause"}
		pause_pressed.emit()
	elif _stick_finger == -1 and point.x <= _view_size().x * STICK_ZONE_RATIO:
		_stick_finger = finger
		_fingers[finger] = {"kind": "stick"}
		_stick_origin = _clamp_stick_origin(point) if stick_floating else _stick_home
		_update_stick(point)
	queue_redraw()

func _move_touch(finger: int, point: Vector2) -> void:
	if finger != _stick_finger:
		return
	_update_stick(point)
	queue_redraw()

func _end_touch(finger: int) -> void:
	if not _fingers.has(finger):
		return
	var info: Dictionary = _fingers[finger]
	_fingers.erase(finger)
	var kind: String = info["kind"]
	if kind == "button":
		var action: String = info["action"]
		_held_by.erase(action)
		_release(action)
	elif kind == "stick":
		_reset_stick()
	queue_redraw()

func _button_index_at(point: Vector2) -> int:
	var best := -1
	var best_score := 1.0e9
	for i in _buttons.size():
		var button: Dictionary = _buttons[i]
		var center: Vector2 = button["center"]
		var reach := float(button["radius"]) + HIT_PADDING * _ui_scale
		var distance := point.distance_to(center)
		if distance <= reach:
			# Overlapping padded areas: the button whose centre is relatively closest wins.
			var score := distance / reach
			if score < best_score:
				best_score = score
				best = i
	return best

# ---------------------------------------------------------------- analog stick

func _clamp_stick_origin(point: Vector2) -> Vector2:
	var view := _view_size()
	var reach := (STICK_RADIUS + STICK_EDGE_MARGIN) * _ui_scale
	var min_y := view.y * 0.3
	return Vector2(
		clampf(point.x, reach, maxf(reach, view.x * STICK_ZONE_RATIO)),
		clampf(point.y, min_y, maxf(min_y, view.y - reach))
	)

func _update_stick(point: Vector2) -> void:
	var radius := STICK_RADIUS * _ui_scale
	var offset := point - _stick_origin
	if offset.length() > radius:
		if stick_follows_thumb:
			# The base slides after the thumb so reversing direction never needs a long swipe back.
			_stick_origin += offset.normalized() * (offset.length() - radius)
			offset = point - _stick_origin
		offset = offset.limit_length(radius)
	_stick_knob = _stick_origin + offset
	var x := clampf(offset.x / radius, -1.0, 1.0)
	var magnitude := absf(x)
	var axis := 0.0
	if magnitude > STICK_DEADZONE:
		var scaled := (magnitude - STICK_DEADZONE) / (1.0 - STICK_DEADZONE) * stick_sensitivity
		axis = signf(x) * minf(1.0, scaled)
	_set_move_axis(axis)

func _reset_stick() -> void:
	_stick_finger = -1
	_stick_origin = _stick_home
	_stick_knob = _stick_home
	_set_move_axis(0.0)

func _set_move_axis(axis: float) -> void:
	stick_axis = axis
	if axis < 0.0:
		Input.action_press(MOVE_LEFT, -axis)
		_left_down = true
		if _right_down:
			Input.action_release(MOVE_RIGHT)
			_right_down = false
	elif axis > 0.0:
		Input.action_press(MOVE_RIGHT, axis)
		_right_down = true
		if _left_down:
			Input.action_release(MOVE_LEFT)
			_left_down = false
	else:
		if _left_down:
			Input.action_release(MOVE_LEFT)
			_left_down = false
		if _right_down:
			Input.action_release(MOVE_RIGHT)
			_right_down = false

# ---------------------------------------------------------------- action press / release

func _press(action: String) -> void:
	_pending_release.erase(action)
	_press_frame[action] = Engine.get_physics_frames()
	Input.action_press(action)

func _release(action: String) -> void:
	# player.gd polls is_action_just_pressed() inside _physics_process. A very short tap (or a frame
	# hitch) can deliver press and release between two physics ticks, which would swallow the
	# press. Keep the action down until at least one physics tick has run since the press.
	if Engine.get_physics_frames() > int(_press_frame.get(action, -1)):
		Input.action_release(action)
	else:
		_pending_release[action] = true

func _process(_delta: float) -> void:
	if _pending_release.is_empty():
		return
	var frames := Engine.get_physics_frames()
	for action in _pending_release.keys():
		if frames > int(_press_frame.get(action, -1)):
			Input.action_release(action)
			_pending_release.erase(action)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := maxi(12, roundi(17.0 * _ui_scale))
	_draw_stick()
	for button in _buttons:
		_draw_button(button, font, font_size)
	_draw_pause()
	if debug_overlay:
		_draw_debug(font)

func _draw_stick() -> void:
	var active := _stick_finger != -1
	var radius := STICK_RADIUS * _ui_scale
	var knob_radius := STICK_KNOB_RADIUS * _ui_scale
	var base_alpha := (0.55 if active else 0.38) * button_opacity
	var ring_alpha := (0.85 if active else 0.55) * button_opacity
	draw_circle(_stick_origin, radius, Color(0.035, 0.045, 0.085, base_alpha))
	draw_arc(_stick_origin, radius, 0.0, TAU, 56, Color(0.78, 0.76, 0.84, ring_alpha), 3.0 * _ui_scale)
	draw_circle(_stick_knob, knob_radius, Color(0.55, 0.57, 0.68, (0.85 if active else 0.6) * button_opacity))
	draw_arc(_stick_knob, knob_radius, 0.0, TAU, 40, Color(0.94, 0.91, 0.95, 0.9 * button_opacity), 2.0 * _ui_scale)

func _draw_button(button: Dictionary, font: Font, font_size: int) -> void:
	var center: Vector2 = button["center"]
	var radius: float = button["radius"]
	var action: String = button["action"]
	var fill := Color(0.09, 0.11, 0.18, 0.60 * button_opacity)
	var ring := Color(0.78, 0.72, 0.78, 0.75 * button_opacity)
	if _held_by.has(action):
		fill = Color(0.55, 0.12, 0.22, 0.85 * button_opacity)
		ring = Color(1.0, 0.82, 0.86, 0.95 * button_opacity)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, ring, 3.0 * _ui_scale)
	var label: String = button["label"]
	var glyph: String = button["glyph"]
	if glyph == "crouch":
		var s := 15.0 * _ui_scale
		var chevron := PackedVector2Array([
			center + Vector2(-s, -s * 0.5), center + Vector2(0.0, s * 0.6), center + Vector2(s, -s * 0.5)
		])
		draw_polyline(chevron, Color("f4e9e4"), 5.0 * _ui_scale)
	elif label != "":
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, center + Vector2(-text_size.x * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f4e9e4"))

func _draw_pause() -> void:
	var radius := PAUSE_RADIUS * _ui_scale
	draw_circle(_pause_center, radius, Color(0.09, 0.11, 0.18, 0.55 * button_opacity))
	draw_arc(_pause_center, radius, 0.0, TAU, 32, Color(0.78, 0.72, 0.78, 0.7 * button_opacity), 2.0 * _ui_scale)
	var bar := Vector2(5.0, 18.0) * _ui_scale
	var gap := 9.0 * _ui_scale
	draw_rect(Rect2(_pause_center + Vector2(-gap - bar.x * 0.5, -bar.y * 0.5), bar), Color("f4e9e4"))
	draw_rect(Rect2(_pause_center + Vector2(gap - bar.x * 0.5, -bar.y * 0.5), bar), Color("f4e9e4"))

func _draw_debug(font: Font) -> void:
	var held := PackedStringArray()
	for action in _held_by.keys():
		held.append(String(action))
	var text := "пальцев: %d (учтено %d) | стик: %.2f | кнопки: %s" % [
		_all_touches.size(), _fingers.size(), stick_axis, ", ".join(held)
	]
	draw_string(font, Vector2(24.0, size.y * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 1.0, 0.6, 0.95))
