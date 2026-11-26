extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const JoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: SilentBladePlayer
var enemies: Array[SilentBladeEnemy] = []
var camera: Camera2D
var hud: CanvasLayer
var health_bar: ProgressBar
var guard_bar: ProgressBar
var guard_label: Label
var alert_label: Label
var status_label: Label
var pause_panel: PanelContainer
var joystick: SilentBladeVirtualJoystick
var results_layer: CanvasLayer
var paused := false
var game_over := false
var mission_completed := false
var start_screen := true
var elapsed_time := 0.0
var detections := 0
var defeated_enemies := 0
var anchors: Array[Vector2] = [Vector2(520, 170), Vector2(920, 145), Vector2(1370, 180), Vector2(1770, 130)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_all_input()

func _reset_all_input() -> void:
	for action in ["move_left", "move_right", "jump", "crouch", "dash", "grapple", "attack", "block"]:
		Input.action_release(action)
	if joystick and is_instance_valid(joystick):
		joystick.cancel_input()
	if player and is_instance_valid(player):
		player.release_controls()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.canceled:
		_reset_all_input()

func _ready() -> void:
	_setup_input()
	_build_world()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_hud()
	_show_title()

func _setup_input() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"crouch": [KEY_S, KEY_DOWN],
		"dash": [KEY_SHIFT],
		"grapple": [KEY_E],
		"attack": [KEY_J, KEY_Z],
		"block": [KEY_K, KEY_X],
		"pause": [KEY_ESCAPE]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _build_world() -> void:
	_add_platform(Vector2(720, 650), Vector2(1500, 60), Color("282a3d"))
	_add_platform(Vector2(250, 485), Vector2(260, 28), Color("484050"))
	_add_platform(Vector2(610, 390), Vector2(260, 28), Color("484050"))
	_add_platform(Vector2(1010, 485), Vector2(290, 28), Color("484050"))
	_add_platform(Vector2(1410, 390), Vector2(280, 28), Color("484050"))
	_add_platform(Vector2(1810, 500), Vector2(310, 28), Color("484050"))
	_add_platform(Vector2(2230, 650), Vector2(700, 60), Color("282a3d"))

	# Decorations are anchored to the actual top surface of the nearest platform.
	var lanterns := [
		Vector2(120, 620), Vector2(370, 471), Vector2(760, 376),
		Vector2(1180, 620), Vector2(1580, 376), Vector2(1980, 486), Vector2(2380, 620)
	]
	for pos in lanterns:
		_add_lantern(pos)
	var houses := [
		Vector2(300, 471), Vector2(800, 376), Vector2(1500, 376), Vector2(2100, 486)
	]
	for pos in houses:
		_add_house(pos)
	queue_redraw()

func _add_platform(center: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([
		Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2),
		Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)
	])
	art.color = color
	body.add_child(art)
	var trim := Line2D.new()
	trim.points = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2)])
	trim.default_color = Color("c6a879")
	trim.width = 4.0
	body.add_child(trim)
	add_child(body)

func _add_lantern(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -1
	add_child(node)
	node.draw.connect(func():
		node.draw_line(Vector2(0, -68), Vector2(0, -5), Color("28253b"), 3.0)
		node.draw_rect(Rect2(-10, -36, 20, 30), Color("e99a45"))
		node.draw_rect(Rect2(-7, -33, 14, 24), Color("ffd18a"))
		node.draw_circle(Vector2(0, -21), 31, Color(1.0, 0.53, 0.18, 0.08))
	)

func _add_house(pos: Vector2) -> void:
	var node := Node2D.new()
	node.position = pos
	node.z_index = -2
	add_child(node)
	node.draw.connect(func():
		# Local y=0 is the platform surface; the building sits above it.
		node.draw_rect(Rect2(-105, -210, 210, 210), Color("171d34"))
		node.draw_colored_polygon(PackedVector2Array([
			Vector2(-130, -210), Vector2(0, -295), Vector2(130, -210)
		]), Color("101629"))
		node.draw_line(Vector2(-125, -208), Vector2(125, -208), Color("6d4b48"), 9.0)
		for wx in [-60, 0, 60]:
			node.draw_rect(Rect2(wx - 12, -165, 24, 48), Color("db8742"))
		node.draw_rect(Rect2(-18, -70, 36, 70), Color("0c1224"))
	)

func _build_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(160, 580)
	player.anchors = anchors
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.guard_changed.connect(_on_guard_changed)
	player.guard_broken.connect(_on_guard_broken)
	player.parry_succeeded.connect(_on_parry_succeeded)
	add_child(player)

func _build_enemies() -> void:
	# Three real enemy instances with different movement, combat and resistance profiles.
	_spawn_enemy("Guard", Vector2(850, 620), 720.0, 1080.0)
	_spawn_enemy("Scout", Vector2(1320, 620), 1160.0, 1430.0)
	_spawn_enemy("Heavy Guard", Vector2(2150, 620), 1940.0, 2420.0)

func _spawn_enemy(enemy_type: String, spawn_position: Vector2, patrol_left: float, patrol_right: float) -> SilentBladeEnemy:
	var enemy: SilentBladeEnemy = EnemyScript.new()
	enemy.enemy_type = enemy_type
	enemy.position = spawn_position
	enemy.left_limit = patrol_left
	enemy.right_limit = patrol_right
	enemy.direction = -1
	enemy.target = player
	enemy.player_spotted.connect(_on_player_spotted)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = 2800
	camera.limit_top = 0
	camera.limit_bottom = 720
	player.add_child(camera)
	camera.make_current()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)

	var top := HBoxContainer.new()
	top.position = Vector2(24, 18)
	top.add_theme_constant_override("separation", 12)
	hud.add_child(top)

	var name_label := Label.new()
	name_label.text = "SILENT BLADE"
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("f1e6db"))
	top.add_child(name_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(220, 20)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	top.add_child(health_bar)

	guard_bar = ProgressBar.new()
	guard_bar.position = Vector2(24, 54)
	guard_bar.custom_minimum_size = Vector2(220, 16)
	guard_bar.size = Vector2(220, 16)
	guard_bar.max_value = 100.0
	guard_bar.value = 100.0
	guard_bar.show_percentage = false
	var guard_fill := StyleBoxFlat.new()
	guard_fill.bg_color = Color("62b7c8")
	guard_fill.set_corner_radius_all(4)
	guard_bar.add_theme_stylebox_override("fill", guard_fill)
	var guard_background := StyleBoxFlat.new()
	guard_background.bg_color = Color(0.06, 0.08, 0.14, 0.9)
	guard_background.border_color = Color("8195aa")
	guard_background.set_border_width_all(1)
	guard_background.set_corner_radius_all(4)
	guard_bar.add_theme_stylebox_override("background", guard_background)
	hud.add_child(guard_bar)

	guard_label = Label.new()
	guard_label.position = Vector2(252, 51)
	guard_label.text = "СТОЙКА"
	guard_label.add_theme_font_size_override("font_size", 14)
	guard_label.add_theme_color_override("font_color", Color("a9dce4"))
	hud.add_child(guard_label)

	alert_label = Label.new()
	alert_label.position = Vector2(540, 25)
	alert_label.add_theme_font_size_override("font_size", 22)
	alert_label.add_theme_color_override("font_color", Color("ff5263"))
	hud.add_child(alert_label)

	status_label = Label.new()
	status_label.position = Vector2(25, 82)
	status_label.text = "МИССИЯ 01  •  ЗАХВАЧЕННАЯ ДЕРЕВНЯ"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("c5c9dc"))
	hud.add_child(status_label)

	_build_touch_controls()
	_build_pause_panel()

func _build_touch_controls() -> void:
	# Single analog virtual joystick; action buttons remain independent for multitouch.
	joystick = JoystickScript.new()
	joystick.position = Vector2(35, 505)
	joystick.size = Vector2(170, 170)
	joystick.axis_changed.connect(_on_joystick_axis)
	hud.add_child(joystick)

	var right_buttons := [
		["ПРЫЖОК", "jump", Vector2(1090, 520), Vector2(100, 78)],
		["БЛОК", "block", Vector2(900, 510), Vector2(82, 76)],
		["УДАР", "attack", Vector2(1190, 590), Vector2(82, 82)],
		["РЫВОК", "dash", Vector2(1000, 610), Vector2(82, 72)],
		["КРЮК", "grapple", Vector2(1090, 620), Vector2(82, 72)],
		["↓", "crouch", Vector2(900, 610), Vector2(72, 72)]
	]
	for item in right_buttons:
		var button := Button.new()
		button.text = item[0]
		button.position = item[2]
		button.size = item[3]
		_style_button(button)
		var action: String = item[1]
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
		hud.add_child(button)

	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(1200, 18)
	pause.size = Vector2(54, 48)
	_style_button(pause)
	pause.pressed.connect(_toggle_pause)
	hud.add_child(pause)

func _on_joystick_axis(value: float) -> void:
	if value < -0.12:
		Input.action_press("move_left", absf(value))
	else:
		Input.action_release("move_left")
	if value > 0.12:
		Input.action_press("move_right", value)
	else:
		Input.action_release("move_right")

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("f4e9e4"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.11, 0.18, 0.66)
	normal.border_color = Color(0.78, 0.72, 0.78, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(32)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.55, 0.12, 0.22, 0.8)
	button.add_theme_stylebox_override("pressed", pressed)

func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(470, 190)
	pause_panel.size = Vector2(340, 300)
	pause_panel.visible = false
	hud.add_child(pause_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var resume := Button.new()
	resume.text = "Продолжить"
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)

	var restart := Button.new()
	restart.text = "Перезапустить"
	restart.pressed.connect(_restart_level)
	box.add_child(restart)

func _show_title() -> void:
	player.set_physics_process(false)
	for enemy in enemies:
		enemy.set_physics_process(false)
	var title_layer := CanvasLayer.new()
	title_layer.name = "TitleScreen"
	title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(title_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(shade)

	var title := Label.new()
	title.text = "SILENT\nBLADE"
	title.position = Vector2(450, 150)
	title.size = Vector2(380, 180)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f0e7eb"))
	shade.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "THE LAST SHADOW"
	subtitle.position = Vector2(0, 175)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("d34b62"))
	shade.add_child(subtitle)

	var start := Button.new()
	start.text = "НАЧАТЬ МИССИЮ"
	start.position = Vector2(490, 450)
	start.size = Vector2(300, 64)
	start.pressed.connect(func():
		title_layer.queue_free()
		start_screen = false
		player.set_physics_process(true)
		for enemy in enemies:
			enemy.set_physics_process(true)
	)
	shade.add_child(start)

func _toggle_pause() -> void:
	if mission_completed or game_over:
		return
	paused = not paused
	get_tree().paused = paused
	pause_panel.visible = paused

func _restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_health_changed(value: float) -> void:
	health_bar.value = value

func _on_guard_changed(value: float, maximum: float) -> void:
	guard_bar.max_value = maximum
	guard_bar.value = value
	if player and player.guard_is_broken:
		return
	guard_label.text = "СТОЙКА  %d%%" % int(round(value / maximum * 100.0))
	var fill := guard_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = Color("e2a64f") if value <= maximum * 0.3 else Color("62b7c8")
	guard_bar.add_theme_stylebox_override("fill", fill)
	guard_label.add_theme_color_override("font_color", Color("ffc36a") if value <= maximum * 0.3 else Color("a9dce4"))

func _on_guard_broken() -> void:
	guard_label.text = "СТОЙКА СЛОМАНА"
	guard_label.add_theme_color_override("font_color", Color("ff6575"))
	var fill := guard_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = Color("d7475c")
	guard_bar.add_theme_stylebox_override("fill", fill)

func _on_parry_succeeded() -> void:
	status_label.text = "ПАРИРОВАНИЕ  •  КОНТРАТАКУЙ"
	status_label.add_theme_color_override("font_color", Color("ffd36a"))

func _on_player_spotted() -> void:
	if alert_label.text != "ОБНАРУЖЕН":
		detections += 1
	alert_label.text = "ОБНАРУЖЕН"

func _on_enemy_died(enemy_type: String) -> void:
	defeated_enemies += 1
	status_label.text = "%s ПОБЕЖДЁН" % enemy_type.to_upper()
	status_label.add_theme_color_override("font_color", Color("ffd36a"))

func _on_player_died() -> void:
	if game_over or mission_completed:
		return
	game_over = true
	_show_results(false)

func _process(delta: float) -> void:
	if start_screen or paused or mission_completed or game_over:
		return
	elapsed_time += delta

	if player and player.global_position.x >= 2550.0:
		_complete_mission()

func _complete_mission() -> void:
	if mission_completed or game_over:
		return
	mission_completed = true
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	_show_results(true)

func _show_results(success: bool) -> void:
	if results_layer:
		return
	get_tree().paused = true
	paused = true

	results_layer = CanvasLayer.new()
	results_layer.name = "MissionResults"
	results_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(results_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_layer.add_child(shade)

	var panel := PanelContainer.new()
	panel.position = Vector2(390, 135)
	panel.size = Vector2(500, 450)
	shade.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "МИССИЯ ВЫПОЛНЕНА" if success else "МИССИЯ ПРОВАЛЕНА"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("e9dce5") if success else Color("ff6575"))
	column.add_child(heading)

	var rank := "S" if success and elapsed_time < 150.0 and detections == 0 else ("A" if success and detections <= 1 else ("B" if success else "—"))
	var result_text := "Оценка: %s\nВремя: %s\nОбнаружения: %d\nПобеждено врагов: %d" % [
		rank, _format_time(elapsed_time), detections, defeated_enemies
	]
	var stats := Label.new()
	stats.text = result_text
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 21)
	column.add_child(stats)

	var replay := Button.new()
	replay.text = "ПОВТОРИТЬ МИССИЮ"
	replay.custom_minimum_size = Vector2(260, 52)
	replay.pressed.connect(_restart_level)
	column.add_child(replay)

	var menu := Button.new()
	menu.text = "В ГЛАВНОЕ МЕНЮ"
	menu.custom_minimum_size = Vector2(260, 48)
	menu.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	column.add_child(menu)

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not mission_completed and not game_over:
		_toggle_pause()

func _draw() -> void:
	draw_rect(Rect2(-10000, -10000, 30000, 20000), Color("09152f"))
	for i in range(18):
		var x := float(i * 190 - 40)
		draw_circle(Vector2(x, 110 + sin(float(i) * 1.8) * 35), 2.0, Color(0.75, 0.82, 1.0, 0.45))
	draw_circle(Vector2(750, 135), 72, Color("b8d4f2"))
	draw_circle(Vector2(775, 118), 68, Color("a7c5e9"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-100, 620), Vector2(180, 300), Vector2(390, 590), Vector2(690, 270), Vector2(1030, 620)
	]), Color("142444"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(850, 620), Vector2(1120, 320), Vector2(1420, 600), Vector2(1740, 260), Vector2(2150, 620)
	]), Color("101e3a"))
	for x in range(-100, 3000, 360):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 430), Vector2(x + 100, 380), Vector2(x + 200, 430),
			Vector2(x + 175, 438), Vector2(x + 100, 405), Vector2(x + 25, 438)
		]), Color("0b1224"))
	for x in [40, 610, 1320, 2050, 2580]:
		draw_line(Vector2(x - 65, 80), Vector2(x + 55, 230), Color("21182d"), 8.0)
		for j in range(9):
			draw_circle(Vector2(x + sin(float(j) * 2.2) * 55, 100 + j * 15), 7, Color("8c294a"))
	draw_rect(Rect2(2570, 430, 22, 220), Color("4b2634"))
	draw_rect(Rect2(2660, 430, 22, 220), Color("4b2634"))
	draw_rect(Rect2(2550, 410, 150, 20), Color("8d3947"))
