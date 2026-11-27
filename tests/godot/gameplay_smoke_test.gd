extends SceneTree
## Headless gameplay + multitouch test. Run:
##   godot --headless --path . -s tests/godot/gameplay_smoke_test.gd
## Exit code 0 = all checks passed, 1 = at least one failed (details are printed as "FAIL: ...").
## It injects real InputEventScreenTouch / InputEventScreenDrag events, so it exercises
## scripts/input/touch_controls.gd inside the engine. It does NOT replace a test on a physical phone.

var _failures := 0
var _main: Node
var _player: Node
var _touch: Control

func _initialize() -> void:
	_run()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _touch_event(index: int, pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)

func _drag_event(index: int, pos: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.relative = relative
	Input.parse_input_event(event)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _run() -> void:
	# The injected touches must not be duplicated into an emulated mouse finger.
	Input.emulate_mouse_from_touch = false
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_check(packed != null, "Main.tscn loads")
	_main = packed.instantiate()
	root.add_child(_main)
	await _wait(0.3)
	_player = _main.get("player")
	_touch = _main.get("touch_controls")
	_check(_player != null, "player was built")
	_check(_touch != null, "touch controls were built")
	_check(_main.get("guard_bar") != null, "HUD was built (guard bar exists)")
	if _player == null or _touch == null:
		quit(1)
		return

	_check(not _touch.get("enabled"), "touch layer is disabled on the title screen")
	var start := _find_button(_main, "НАЧАТЬ ПРОНИКНОВЕНИЕ")
	_check(start != null, "title screen has the start button")
	if start != null:
		start.pressed.emit()
	await _wait(0.8)
	_check(_touch.get("enabled"), "touch layer is enabled after mission start")
	_check(_player.is_on_floor(), "player stands on the floor")

	# --- finger 0: stick to the right -------------------------------------------------
	var stick_start: Vector2 = _touch.call("get_stick_start_point")
	var radius: float = _touch.call("get_stick_radius")
	_touch_event(0, stick_start, true)
	_drag_event(0, stick_start + Vector2(radius, 0.0), Vector2(radius, 0.0))
	await _wait(0.25)
	_check(Input.is_action_pressed("move_right"), "stick finger holds move_right")
	_check(_player.velocity.x > 100.0, "player moves right")

	# --- finger 1: jump while the stick is held ---------------------------------------
	var jump_pos: Vector2 = _touch.call("get_button_center", "jump")
	_touch_event(1, jump_pos, true)
	await _wait(0.05)
	_check(Input.is_action_pressed("move_right"), "move_right still held while jump is pressed")
	_check(_player.get("jump_count") == 1, "jump registered while moving")
	_touch_event(1, jump_pos, false)
	await _wait(0.05)
	_check(Input.is_action_pressed("move_right"), "releasing the jump finger does not release the stick")
	# A second press before landing must use exactly one air jump, not be ignored or repeated.
	_touch_event(1, jump_pos, true)
	await _wait(0.05)
	_check(_player.get("jump_count") == 2, "second jump registers once in mid-air")
	_check(float(_player.get("second_jump_flash_timer")) > 0.0, "second jump has its own visual reaction")
	_touch_event(1, jump_pos, false)
	await _wait(1.0)
	_check(_player.get("jump_count") == 0, "jump count resets after landing")

	# --- finger 2: attack while the stick is held --------------------------------------
	var attack_pos: Vector2 = _touch.call("get_button_center", "attack")
	_touch_event(2, attack_pos, true)
	await _wait(0.05)
	_check(_player.get("combo_step") == 1, "attack registered while moving")
	_check(Input.is_action_pressed("move_right"), "move_right still held during attack")
	_touch_event(2, attack_pos, false)

	# --- two buttons at once on top of the stick: block + dash -------------------------
	var block_pos: Vector2 = _touch.call("get_button_center", "block")
	var dash_pos: Vector2 = _touch.call("get_button_center", "dash")
	_touch_event(3, block_pos, true)
	await _wait(0.05)
	_check(_player.get("block_held"), "block is held by its own finger")
	_touch_event(4, dash_pos, true)
	await _wait(0.05)
	_check(Input.is_action_pressed("block"), "block still held after a 5th finger touches dash")
	_check(Input.is_action_pressed("move_right"), "stick still held with 3 fingers down")
	_touch_event(4, dash_pos, false)
	await _wait(0.05)
	_touch_event(3, block_pos, false)
	await _wait(0.1)
	_check(not _player.get("block_held"), "block released with its finger")
	_check(Input.is_action_pressed("move_right"), "stick still held after both button fingers lifted")

	# --- grapple button holds independently ---------------------------------------------
	var grapple_pos: Vector2 = _touch.call("get_button_center", "grapple")
	_touch_event(5, grapple_pos, true)
	await _wait(0.05)
	_check(Input.is_action_pressed("grapple"), "grapple button is held by its finger")
	_touch_event(5, grapple_pos, false)

	# --- distraction action is independent from the still-held movement finger ----------
	var distract_pos: Vector2 = _touch.call("get_button_center", "distract")
	_check(distract_pos != Vector2.INF, "touch layout exposes a dedicated distraction button")
	_touch_event(8, distract_pos, true)
	await _wait(0.05)
	_check(Input.is_action_pressed("move_right"), "movement remains held while distraction is pressed")
	_check(Input.is_action_pressed("distract"), "distraction action is held by its own finger")
	_check(float(_player.get("distraction_cooldown")) > 0.0, "distraction button triggers the decoy cooldown")
	_touch_event(8, distract_pos, false)
	await _wait(0.05)
	_check(not Input.is_action_pressed("distract"), "distraction action releases with its finger")

	# --- cancelled touch releases a held block without disturbing the joystick ------------
	var cancel_block_pos: Vector2 = _touch.call("get_button_center", "block")
	_touch_event(9, cancel_block_pos, true)
	await _wait(0.05)
	_check(_player.get("block_held"), "block starts before a cancelled touch")
	_touch_event(9, cancel_block_pos, false, true)
	await _wait(0.05)
	_check(not _player.get("block_held"), "cancelled touch releases the held block")
	_check(Input.is_action_pressed("move_right"), "cancelled button touch does not release the stick finger")


	# --- context interaction button appears only when an object can be used ----------------
	_touch.call("set_interaction_prompt", "ОТКРЫТЬ")
	var interact_pos: Vector2 = _touch.call("get_button_center", "interact")
	_check(interact_pos != Vector2.INF, "context interaction button appears when prompted")
	_touch_event(10, interact_pos, true)
	await _wait(0.05)
	_check(Input.is_action_pressed("interact"), "interaction button produces the interact action")
	_touch_event(10, interact_pos, false)
	_check(not Input.is_action_pressed("interact"), "interaction action releases with its finger")
	_touch.call("set_interaction_prompt", "")

	# --- lifting the stick finger releases movement only --------------------------------
	_touch_event(0, stick_start, false)
	await _wait(0.1)
	_check(not Input.is_action_pressed("move_right"), "lifting the stick releases move_right")

	# --- a short tap must not be swallowed ------------------------------------------------
	await _wait(0.8)
	var before: int = _player.get("jump_count")
	_touch_event(6, jump_pos, true)
	_touch_event(6, jump_pos, false)
	await _wait(0.1)
	_check(_player.get("jump_count") > before or _player.velocity.y < 0.0, "a same-frame tap still produces a jump")

	# --- cancel / focus loss -------------------------------------------------------------
	_touch_event(7, stick_start, true)
	_drag_event(7, stick_start + Vector2(radius, 0.0), Vector2(radius, 0.0))
	await _wait(0.1)
	_check(Input.is_action_pressed("move_right"), "stick works again after earlier fingers")
	_touch.call("release_all")
	_check(not Input.is_action_pressed("move_right"), "release_all() clears held input")

	# --- kill plane / checkpoint recovery -------------------------------------------------
	_player.global_position = Vector2(1600.0, 1000.0)
	await _wait(1.5)
	_check(not _main.get("game_over"), "falling out of the world respawns instead of ending the mission")
	_check(not _main.get("respawning"), "checkpoint recovery finishes")
	_check(absf(float(_player.global_position.x) - 150.0) < 8.0, "player returns to the start checkpoint")
	_check(absf(float(_player.get("health")) - 100.0) < 0.01, "checkpoint restores player health")
	_check(_touch.get("enabled"), "touch controls are re-enabled after checkpoint recovery")

	# Completing the current vertical slice opens a real results screen with connected actions.
	_main.call("_complete_mission")
	await _wait(0.1)
	_check(_main.get("results_layer") != null, "mission completion opens the results layer")
	for button_text in ["ПОВТОРИТЬ МИССИЮ", "ПРОДОЛЖИТЬ", "В МЕНЮ"]:
		var result_button := _find_button(_main, button_text)
		_check(result_button != null, "results screen exposes: " + button_text)
		if result_button != null:
			_check(result_button.pressed.get_connections().size() > 0, "results action is connected: " + button_text)

	print("RESULT: ", "FAILED (%d)" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)
