extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const TouchControlsScript = preload("res://scripts/input/touch_controls.gd")
const NoiseSystemScript = preload("res://scripts/stealth/noise_system.gd")
const StealthSystemScript = preload("res://scripts/stealth/stealth_system.gd")
const StealthZoneScript = preload("res://scripts/stealth/stealth_zone.gd")
const NoiseDecoyScript = preload("res://scripts/stealth/noise_decoy.gd")
const MissionLevelScript = preload("res://scripts/mission/mission_level.gd")
const MissionManagerScript = preload("res://scripts/mission/mission_manager.gd")
const InteractionSystemScript = preload("res://scripts/mission/interaction_system.gd")
const AlarmSystemScript = preload("res://scripts/mission/alarm_system.gd")
const CheckpointSystemScript = preload("res://scripts/mission/checkpoint_system.gd")
const TutorialSystemScript = preload("res://scripts/mission/tutorial_system.gd")
const NightAmbience = preload("res://assets/audio/night_ambience.wav")
const WoodStepSound = preload("res://assets/audio/wood_step.wav")
const GrassStepSound = preload("res://assets/audio/grass_step.wav")
const InteractionSound = preload("res://assets/audio/interaction.wav")
const DocumentPickupSound = preload("res://assets/audio/document_pickup.wav")
const AlarmSignalSound = preload("res://assets/audio/alarm_signal.wav")

var player: SilentBladePlayer
var enemies: Array[SilentBladeEnemy] = []
var mission_level: SilentBladeMissionLevel
var mission_manager: SilentBladeMissionManager
var interaction_system: SilentBladeInteractionSystem
var alarm_system: SilentBladeAlarmSystem
var checkpoint_system: SilentBladeCheckpointSystem
var tutorial_system: SilentBladeTutorialSystem
var camera: Camera2D
var hud: CanvasLayer
var health_bar: ProgressBar
var guard_bar: ProgressBar
var guard_label: Label
var alert_label: Label
var status_label: Label
var pause_panel: PanelContainer
var touch_controls: Control
var noise_system: SilentBladeNoiseSystem
var stealth_system: SilentBladeStealthSystem
var detection_bar: ProgressBar
var stealth_status_label: Label
var enemy_state_label: Label
var objective_label: Label
var alarm_mode_label: Label
var tutorial_hint_label: Label
var interaction_hint_label: Label
var tutorial_toggle_button: Button
var ambience_player: AudioStreamPlayer
var effects_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var results_data: Dictionary = {}
var respawn_timer := 0.0
var _tutorial_entries: Array = []
var _mission_interaction_busy := false
var respawning := false
var tutorial_trigger_index := 0
var stealth_ui_timer := 0.0
var results_layer: CanvasLayer
var paused := false
var game_over := false
var mission_completed := false
var start_screen := true
var elapsed_time := 0.0
var detections := 0
var defeated_enemies := 0
const FALL_LIMIT_Y := 900.0
var anchors: Array[Vector2] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset_all_input()

func _reset_all_input() -> void:
	if touch_controls and is_instance_valid(touch_controls):
		touch_controls.call("release_all")
	for action in ["move_left", "move_right", "jump", "crouch", "dash", "grapple", "attack", "block", "interact"]:
		Input.action_release(action)
	Input.action_release("distract")
	if player and is_instance_valid(player):
		player.release_controls()

func _ready() -> void:
	_setup_input()
	_build_audio()
	_build_stealth_systems()
	_build_mission_systems()
	_build_world()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_hud()
	_build_interaction_system()
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
		"distract": [KEY_G],
		"interact": [KEY_F],
		"pause": [KEY_ESCAPE]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		for keycode in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


func _build_audio() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "MissionNightAmbience"
	var ambience := NightAmbience.duplicate() as AudioStreamWAV
	if ambience:
		ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience.loop_begin = 0
		ambience.loop_end = int(ambience.data.size() / 2)
		ambience_player.stream = ambience
	ambience_player.volume_db = -19.0
	add_child(ambience_player)
	effects_player = AudioStreamPlayer.new()
	effects_player.name = "MissionEffects"
	effects_player.volume_db = -8.0
	add_child(effects_player)
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "FootstepEffects"
	footstep_player.volume_db = -13.0
	add_child(footstep_player)

func _play_mission_effect(stream: AudioStream, volume_db: float = -8.0) -> void:
	if stream == null or not is_instance_valid(effects_player):
		return
	effects_player.stop()
	effects_player.stream = stream
	effects_player.volume_db = volume_db
	effects_player.play()

func _play_footstep(is_grass: bool, sneaking: bool = false) -> void:
	if not is_instance_valid(footstep_player) or footstep_player.playing:
		return
	footstep_player.stream = GrassStepSound if is_grass else WoodStepSound
	footstep_player.volume_db = -18.0 if sneaking else -13.0
	footstep_player.play()

func _is_player_in_grass() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(stealth_system):
		return false
	for zone in stealth_system.zones:
		if is_instance_valid(zone) and zone.zone_type == "GRASS" and zone.overlaps_body(player):
			return true
	return false

func _build_stealth_systems() -> void:
	noise_system = NoiseSystemScript.new()
	noise_system.name = "NoiseSystem"
	noise_system.z_index = 8
	add_child(noise_system)
	stealth_system = StealthSystemScript.new()
	stealth_system.name = "StealthSystem"
	add_child(stealth_system)

func _build_mission_systems() -> void:
	mission_manager = MissionManagerScript.new()
	mission_manager.name = "MissionManager"
	add_child(mission_manager)
	var mission_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/mission_01.json"))
	if mission_data is Dictionary:
		mission_manager.start_mission(mission_data)
		_tutorial_entries = mission_data.get("tutorial", [])
	else:
		push_error("Mission 01 configuration could not be loaded")
	mission_manager.objective_changed.connect(_on_objective_changed)
	mission_manager.stats_changed.connect(_on_mission_stats_changed)
	mission_manager.mission_failed.connect(_on_mission_failed)
	alarm_system = AlarmSystemScript.new()
	alarm_system.name = "AlarmSystem"
	alarm_system.configure(noise_system, Vector2(3210, 610))
	alarm_system.alarm_triggered.connect(_on_alarm_triggered)
	alarm_system.mode_changed.connect(_on_alarm_mode_changed)
	alarm_system.alarm_disabled.connect(_on_alarm_disabled)
	add_child(alarm_system)
	checkpoint_system = CheckpointSystemScript.new()
	checkpoint_system.name = "CheckpointSystem"
	add_child(checkpoint_system)
	checkpoint_system.activate("start", Vector2(150, 580), true, mission_manager.snapshot_persistent_state())
	tutorial_system = TutorialSystemScript.new()
	tutorial_system.name = "TutorialSystem"
	tutorial_system.hint_changed.connect(_on_tutorial_hint_changed)
	add_child(tutorial_system)

func _build_world() -> void:
	mission_level = MissionLevelScript.new()
	mission_level.name = "Mission01_TheShadowOfTheVillage"
	add_child(mission_level)
	mission_level.build(stealth_system)
	anchors = mission_level.grapple_anchors.duplicate()

func _build_enemies() -> void:
	for spawn in mission_level.enemy_spawns:
		var spawn_position := Vector2(float(spawn.get("x", 0.0)), float(spawn.get("y", 620.0)))
		_spawn_enemy(String(spawn.get("type", "Guard")), spawn_position, float(spawn.get("left", spawn.get("x", 0.0) - 140.0)), float(spawn.get("right", spawn.get("x", 0.0) + 140.0)))

func _spawn_enemy(enemy_type: String, spawn_position: Vector2, patrol_left: float, patrol_right: float) -> SilentBladeEnemy:
	var enemy: SilentBladeEnemy = EnemyScript.new()
	enemy.enemy_type = enemy_type
	enemy.position = spawn_position
	enemy.left_limit = patrol_left
	enemy.right_limit = patrol_right
	enemy.direction = -1
	enemy.target = player
	enemy.noise_system = noise_system
	enemy.stealth_system = stealth_system
	enemy.player_spotted.connect(_on_player_spotted)
	enemy.detection_changed.connect(_on_enemy_detection_changed)
	enemy.ai_state_changed.connect(_on_enemy_state_changed)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func _build_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(160, 580)
	player.anchors = anchors
	player.noise_emitted.connect(_on_player_noise)
	player.distraction_requested.connect(_spawn_noise_decoy)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.guard_changed.connect(_on_guard_changed)
	player.guard_broken.connect(_on_guard_broken)
	player.parry_succeeded.connect(_on_parry_succeeded)
	add_child(player)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(mission_level.world_width)
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
	alert_label.position = Vector2(540, 17)
	alert_label.add_theme_font_size_override("font_size", 22)
	alert_label.add_theme_color_override("font_color", Color("ff5263"))
	hud.add_child(alert_label)

	detection_bar = ProgressBar.new()
	detection_bar.position = Vector2(540, 49)
	detection_bar.custom_minimum_size = Vector2(220, 14)
	detection_bar.size = Vector2(220, 14)
	detection_bar.max_value = 1.0
	detection_bar.value = 0.0
	detection_bar.show_percentage = false
	detection_bar.visible = false
	var detection_fill := StyleBoxFlat.new()
	detection_fill.bg_color = Color("ffb64d")
	detection_fill.set_corner_radius_all(4)
	detection_bar.add_theme_stylebox_override("fill", detection_fill)
	var detection_bg := StyleBoxFlat.new()
	detection_bg.bg_color = Color(0.04, 0.05, 0.09, 0.82)
	detection_bg.set_corner_radius_all(4)
	detection_bar.add_theme_stylebox_override("background", detection_bg)
	hud.add_child(detection_bar)

	stealth_status_label = Label.new()
	stealth_status_label.position = Vector2(25, 104)
	stealth_status_label.text = "ЗАМЕТНОСТ: НОРМА"
	stealth_status_label.add_theme_font_size_override("font_size", 14)
	stealth_status_label.add_theme_color_override("font_color", Color("c5c9dc"))
	hud.add_child(stealth_status_label)

	enemy_state_label = Label.new()
	enemy_state_label.position = Vector2(540, 72)
	enemy_state_label.text = ""
	enemy_state_label.add_theme_font_size_override("font_size", 14)
	enemy_state_label.add_theme_color_override("font_color", Color("ffc45c"))
	hud.add_child(enemy_state_label)

	status_label = Label.new()
	status_label.position = Vector2(25, 82)
	status_label.text = "МИССИЯ 01  •  ЗАХВАЧЕННАЯ ДЕРЕВНЯ"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("c5c9dc"))
	hud.add_child(status_label)

	objective_label = Label.new()
	objective_label.position = Vector2(25, 124)
	objective_label.size = Vector2(410, 42)
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("f0dfc6"))
	hud.add_child(objective_label)

	alarm_mode_label = Label.new()
	alarm_mode_label.position = Vector2(540, 101)
	alarm_mode_label.size = Vector2(280, 26)
	alarm_mode_label.add_theme_font_size_override("font_size", 14)
	alarm_mode_label.add_theme_color_override("font_color", Color("9dc9ae"))
	hud.add_child(alarm_mode_label)

	tutorial_hint_label = Label.new()
	tutorial_hint_label.position = Vector2(340, 168)
	tutorial_hint_label.size = Vector2(600, 52)
	tutorial_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_hint_label.add_theme_font_size_override("font_size", 16)
	tutorial_hint_label.add_theme_color_override("font_color", Color("fff0d6"))
	hud.add_child(tutorial_hint_label)

	interaction_hint_label = Label.new()
	interaction_hint_label.position = Vector2(420, 222)
	interaction_hint_label.size = Vector2(440, 26)
	interaction_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint_label.add_theme_font_size_override("font_size", 15)
	interaction_hint_label.add_theme_color_override("font_color", Color("f2cb86"))
	hud.add_child(interaction_hint_label)

	_build_touch_controls()
	_build_pause_panel()
	_on_guard_changed(player.guard_stamina, SilentBladePlayer.GUARD_MAX)

func _build_touch_controls() -> void:
	# One raw-touch layer owns the stick, all action buttons and the pause button. Every finger is
	# tracked by its own index, so holding the stick never blocks jump/attack/dash/block/grapple.
	var layer = TouchControlsScript.new()
	layer.name = "TouchControls"
	layer.debug_overlay = OS.is_debug_build()
	layer.set_enabled(false)  # enabled when the mission actually starts
	layer.connect("pause_pressed", _toggle_pause)
	touch_controls = layer
	hud.add_child(layer)

func _build_interaction_system() -> void:
	interaction_system = InteractionSystemScript.new()
	interaction_system.name = "InteractionSystem"
	interaction_system.configure(player, mission_manager, touch_controls)
	interaction_system.target_changed.connect(_on_interaction_target_changed)
	interaction_system.interaction_completed.connect(_on_interactable_used)
	interaction_system.interaction_blocked.connect(_on_interaction_blocked)
	add_child(interaction_system)
	for prop in mission_level.interactables:
		interaction_system.register_interactable(prop)
	_on_objective_changed(mission_manager.objective_manager.current_objective(), mission_manager.objective_manager.completed_ids.size(), mission_manager.objective_manager.objectives.size())
	_on_alarm_mode_changed(alarm_system.mode)

func _get_screen_size() -> Vector2:
	return get_viewport_rect().size

func _build_pause_panel() -> void:
	var screen_size := _get_screen_size()
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2((screen_size.x - 340.0) * 0.5, (screen_size.y - 300.0) * 0.5)
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
	var screen_size := _get_screen_size()
	player.set_physics_process(false)
	for enemy in enemies:
		enemy.set_physics_process(false)
	var title_layer := CanvasLayer.new()
	title_layer.name = "MissionBriefing"
	title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(title_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(shade)
	var title := Label.new()
	title.text = "MISSION 01\nTHE SHADOW OF THE VILLAGE"
	title.position = Vector2((screen_size.x - 740.0) * 0.5, 100)
	title.size = Vector2(740, 145)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("f0e7eb"))
	shade.add_child(title)
	var story := Label.new()
	story.text = "Рэн должен проникнуть в деревню Куроганэ, отключить сигнальный механизм,\nзабрать военные планы из архива и покинуть территорию.\n\nУлица, крыши и скрытый проход ведут к одной цели. Выбирай маршрут сам."
	story.position = Vector2((screen_size.x - 790.0) * 0.5, 260)
	story.size = Vector2(790, 118)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 19)
	story.add_theme_color_override("font_color", Color("c9cbd7"))
	shade.add_child(story)
	var tutorial_toggle := Button.new()
	tutorial_toggle_button = tutorial_toggle
	tutorial_toggle.text = "ОБУЧЕНИЕ: ВКЛ" if tutorial_system.enabled else "ОБУЧЕНИЕ: ВЫКЛ"
	tutorial_toggle.position = Vector2((screen_size.x - 190.0) * 0.5, 410)
	tutorial_toggle.size = Vector2(190, 42)
	tutorial_toggle.pressed.connect(func():
		var is_enabled := tutorial_system.toggle_enabled()
		tutorial_toggle.text = "ОБУЧЕНИЕ: ВКЛ" if is_enabled else "ОБУЧЕНИЕ: ВЫКЛ"
	)
	shade.add_child(tutorial_toggle)
	var start := Button.new()
	start.text = "НАЧАТЬ ПРОНИКНОВЕНИЕ"
	start.position = Vector2((screen_size.x - 370.0) * 0.5, 480)
	start.size = Vector2(370, 64)
	start.pressed.connect(func():
		title_layer.queue_free()
		if ambience_player and not ambience_player.playing:
			ambience_player.play()
		start_screen = false
		mission_manager.begin_clock()
		if touch_controls:
			touch_controls.call("set_enabled", true)
		player.set_physics_process(true)
		for enemy in enemies:
			enemy.set_physics_process(true)
		_tutorial_at_index(0)
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

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_objective_changed(current: Dictionary, completed_count: int, total_count: int) -> void:
	if objective_label == null:
		return
	if current.is_empty():
		objective_label.text = "ЦЕЛИ ВЫПОЛНЕНЫ  •  ДОБЕРИСЬ ДО ЭВАКУАЦИИ"
	else:
		objective_label.text = "ЦЕЛЬ %d/%d  •  %s" % [completed_count + 1, total_count, String(current.get("title", ""))]

func _on_mission_stats_changed(_stats: Dictionary) -> void:
	pass

func _on_alarm_mode_changed(mode: String) -> void:
	if alarm_mode_label == null:
		return
	match mode:
		"GLOBAL_ALARM":
			alarm_mode_label.text = "ТРЕВОГА • УСИЛЕННЫЙ ПОИСК"
			alarm_mode_label.add_theme_color_override("font_color", Color("ff6575"))
		"LOCAL_ALERT":
			alarm_mode_label.text = "ЛОКАЛЬНОЕ ПОДОЗРЕНИЕ"
			alarm_mode_label.add_theme_color_override("font_color", Color("ffc45c"))
		_:
			alarm_mode_label.text = "СИГНАЛ: ОТКЛЮЧЁН" if not alarm_system.alarm_device_enabled else "СИГНАЛ: СПОКОЙНО"
			alarm_mode_label.add_theme_color_override("font_color", Color("83c98c"))

func _on_alarm_triggered(_source_position: Vector2, _count: int) -> void:
	_play_mission_effect(AlarmSignalSound, -12.0)
	mission_manager.record_alarm()
	status_label.text = "СИГНАЛИЗАЦИЯ АКТИВИРОВАНА • ОХРАНА ПОЛУЧИЛА СИГНАЛ"
	status_label.add_theme_color_override("font_color", Color("ff6575"))

func _on_alarm_disabled() -> void:
	mission_manager.set_world_flag("signal_disabled")
	mission_manager.complete_objective("disable_signal")
	_refresh_evacuation_flag()
	status_label.text = "СИГНАЛИЗАЦИЯ ОТКЛЮЧЕНА"
	status_label.add_theme_color_override("font_color", Color("83c98c"))

func _on_tutorial_hint_changed(text: String, _hint_id: String) -> void:
	if tutorial_hint_label:
		tutorial_hint_label.text = text

func _tutorial_at_index(index: int) -> void:
	if index < 0 or index >= _tutorial_entries.size():
		return
	var entry: Dictionary = _tutorial_entries[index]
	tutorial_system.show_hint(String(entry.get("id", "")), String(entry.get("text", "")))


func _update_tutorial_completion() -> void:
	if not is_instance_valid(tutorial_system) or not is_instance_valid(player):
		return
	var hint_id := tutorial_system.get_active_hint_id()
	var completed := false
	match hint_id:
		"move":
			completed = absf(Input.get_axis("move_left", "move_right")) > 0.12 or Input.is_action_just_pressed("jump")
		"grass":
			completed = player.crouching and _is_player_in_grass()
		"roofs":
			completed = player.grappling or (player.global_position.x >= 1050.0 and player.global_position.y < 530.0)
		"decoy":
			completed = player.distraction_cooldown > 0.0
		"alarm":
			completed = mission_manager.has_world_flag("signal_disabled")
		"interact":
			completed = mission_manager.has_world_flag("door_village_gate_open") or mission_manager.has_world_flag("signal_disabled") or mission_manager.has_world_flag("orders_collected") or mission_manager.has_collected("hidden_cache")
	if completed:
		tutorial_system.complete_hint(hint_id)

func _on_interaction_target_changed(target: SilentBladeMissionInteractable) -> void:
	if not interaction_hint_label:
		return
	if is_instance_valid(target):
		interaction_hint_label.text = "F / ДЕЙСТВИЕ  •  %s" % target.get_prompt(mission_manager)
	else:
		interaction_hint_label.text = ""

func _on_interaction_blocked(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ffc45c"))

func _on_interactable_used(prop: SilentBladeMissionInteractable) -> void:
	if _mission_interaction_busy or not is_instance_valid(prop):
		return
	_mission_interaction_busy = true
	match prop.kind:
		"door":
			_play_mission_effect(InteractionSound, -11.0)
			mission_manager.set_world_flag("door_%s_open" % prop.object_id)
			status_label.text = "ПУТЬ ОТКРЫТ"
			status_label.add_theme_color_override("font_color", Color("d7c29b"))
		"alarm":
			_play_mission_effect(InteractionSound, -10.0)
			alarm_system.disable_alarm()
		"archive":
			if mission_manager.collect_item(prop.object_id, "DOCUMENT"):
				_play_mission_effect(DocumentPickupSound, -7.0)
				mission_manager.set_world_flag("orders_collected")
				mission_manager.complete_objective("retrieve_orders")
				_refresh_evacuation_flag()
				status_label.text = "ПОЛУЧЕН ДОКУМЕНТ • ВОЕННЫЕ ПЛАНЫ КУРОГАНЭ"
				status_label.add_theme_color_override("font_color", Color("ffd36a"))
		"cache":
			if mission_manager.collect_item(prop.object_id, "CACHE"):
				_play_mission_effect(DocumentPickupSound, -8.0)
				status_label.text = "НАЙДЕН СЕКРЕТНЫЙ ТАЙНИК"
				status_label.add_theme_color_override("font_color", Color("ffd36a"))
				mission_manager.set_world_flag(prop.object_id + "_collected")
		"document":
			if mission_manager.collect_item(prop.object_id, "DOCUMENT"):
				_play_mission_effect(DocumentPickupSound, -8.0)
				status_label.text = "НАЙДЕН ДОПОЛНИТЕЛЬНЫЙ ДОКУМЕНТ"
				status_label.add_theme_color_override("font_color", Color("ffd36a"))
		"checkpoint":
			_play_mission_effect(InteractionSound, -11.0)
			var snapshot := mission_manager.snapshot_persistent_state()
			var checkpoint_pos := Vector2(prop.global_position.x, 580.0)
			if checkpoint_system.activate(prop.object_id, checkpoint_pos, alarm_system.alarm_device_enabled, snapshot):
				status_label.text = "КОНТРОЛЬНАЯ ТОЧКА АКТИВИРОВАНА"
				status_label.add_theme_color_override("font_color", Color("83c98c"))
		"evacuation":
			if mission_manager.has_world_flag("mission_ready_for_evacuation"):
				_play_mission_effect(DocumentPickupSound, -9.0)
				mission_manager.complete_objective("evacuate")
				_complete_mission()
	_mission_interaction_busy = false
	if interaction_system:
		interaction_system.call_deferred("_refresh_target")

func _refresh_evacuation_flag() -> void:
	var ready := mission_manager.has_world_flag("orders_collected") and mission_manager.has_world_flag("signal_disabled")
	mission_manager.set_world_flag("mission_ready_for_evacuation", ready)

func _on_health_changed(value: float) -> void:
	health_bar.value = value

func _on_guard_changed(value: float, maximum: float) -> void:
	if guard_bar == null or guard_label == null:
		return  # emitted from player._ready() before the HUD is built
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
	if guard_bar == null or guard_label == null:
		return
	guard_label.text = "СТОЙКА СЛОМАНА"
	guard_label.add_theme_color_override("font_color", Color("ff6575"))
	var fill := guard_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = Color("d7475c")
	guard_bar.add_theme_stylebox_override("fill", fill)

func _on_parry_succeeded() -> void:
	status_label.text = "ПАРИРОВАНИЕ  •  КОНТРАТАКУЙ"
	status_label.add_theme_color_override("font_color", Color("ffd36a"))

func _on_player_noise(world_position: Vector2, radius: float, intensity: float, event_type: String, source_id: int) -> void:
	if is_instance_valid(noise_system):
		noise_system.emit_noise(world_position, radius, intensity, event_type, source_id)
	if event_type == "SNEAK_STEP":
		_play_footstep(_is_player_in_grass(), true)
	elif event_type == "FOOTSTEP":
		_play_footstep(_is_player_in_grass())
	elif event_type in ["LAND", "FALL"]:
		_play_footstep(_is_player_in_grass())

func _spawn_noise_decoy(origin: Vector2, throw_direction: int) -> void:
	if not is_instance_valid(noise_system) or game_over or mission_completed:
		return
	var decoy: SilentBladeNoiseDecoy = NoiseDecoyScript.new()
	decoy.noise_system = noise_system
	decoy.position = origin
	decoy.velocity = Vector2(float(throw_direction) * 390.0, -225.0)
	add_child(decoy)

func _on_enemy_detection_changed(_value: float, _stage: String) -> void:
	# The central HUD aggregates all enemies in _process; this signal keeps updates event-driven.
	stealth_ui_timer = 0.0

func _on_enemy_state_changed(_state_name: String) -> void:
	# State display is aggregated across every enemy on the next HUD tick, not overwritten
	# by whichever enemy happened to emit a signal last.
	stealth_ui_timer = 0.0

func _get_aggregate_enemy_state() -> String:
	var priorities := {
		"PATROL": 0, "RETURN": 1, "STAGGER": 2, "KNOCKBACK": 2,
		"ALERT": 3, "INVESTIGATE": 4, "SEARCH": 5, "CHASE": 6, "ATTACK": 7
	}
	var selected_state := "PATROL"
	var selected_priority := -1
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var priority := int(priorities.get(enemy.state, 0))
		if priority > selected_priority:
			selected_priority = priority
			selected_state = enemy.state
	return selected_state

func _enemy_state_text(state_name: String) -> String:
	match state_name:
		"ALERT": return "ПОДОЗРЕНИЕ"
		"INVESTIGATE": return "РАССЛЕДОВАНИЕ"
		"CHASE", "ATTACK": return "ОБНАРУЖЕН / ПОГОНЯ"
		"SEARCH": return "ПОИСК В РАЙОНЕ"
		"RETURN": return "ВОЗВРАТ К ПАТРУЛЮ"
		"STAGGER": return "ВРАГ ОГЛУШЁН"
		"KNOCKBACK": return "ВРАГ ОТБРОШЕН"
		_: return ""

func _on_player_spotted() -> void:
	detections += 1
	mission_manager.record_detection()
	alarm_system.raise_local_alert(player.global_position)
	alert_label.text = "ОБНАРУЖЕН"
	if player.global_position.x >= 2250.0 and player.global_position.x <= 3650.0:
		alarm_system.raise_global_alarm(player.global_position)

func _on_enemy_died(enemy_type: String) -> void:
	defeated_enemies += 1
	mission_manager.record_neutralization()
	status_label.text = "%s НЕЙТРАЛИЗОВАН" % enemy_type.to_upper()
	status_label.add_theme_color_override("font_color", Color("ffd36a"))

func _on_player_died() -> void:
	if respawning or mission_completed:
		return
	respawning = true
	respawn_timer = 0.65
	player.set_physics_process(false)
	player.release_controls()
	player.velocity = Vector2.ZERO
	if touch_controls:
		touch_controls.call("set_enabled", false)
		touch_controls.call("release_all")
	status_label.text = "РЭН ПОТЕРЯЛ СОЗНАНИЕ • ВОЗВРАТ К КОНТРОЛЬНОЙ ТОЧКЕ"
	status_label.add_theme_color_override("font_color", Color("ff6575"))

func _process(delta: float) -> void:
	if respawning:
		respawn_timer = maxf(0.0, respawn_timer - delta)
		if respawn_timer <= 0.0:
			_respawn_at_checkpoint()
		return
	if start_screen or paused or mission_completed or game_over:
		return
	mission_manager.tick(delta)
	elapsed_time = mission_manager.elapsed_time
	if Input.is_action_just_pressed("interact") and interaction_system:
		interaction_system.interact()
	if player and player.global_position.x >= 1000.0 and not mission_manager.is_objective_completed("enter_village"):
		mission_manager.complete_objective("enter_village")
	while tutorial_trigger_index < _tutorial_entries.size():
		var entry: Dictionary = _tutorial_entries[tutorial_trigger_index]
		if player.global_position.x < float(entry.get("x", INF)):
			break
		_tutorial_at_index(tutorial_trigger_index)
		tutorial_trigger_index += 1
	_update_tutorial_completion()
	stealth_ui_timer -= delta
	if stealth_ui_timer <= 0.0:
		stealth_ui_timer = 0.12
		var maximum_detection := 0.0
		var highest_state := "PATROL"
		var any_enemy_chasing := false
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_dead:
				continue
			if enemy.state in ["CHASE", "ATTACK"]:
				any_enemy_chasing = true
			if enemy.detection_meter > maximum_detection:
				maximum_detection = enemy.detection_meter
				highest_state = enemy.state
		if detection_bar:
			detection_bar.value = maximum_detection
			detection_bar.visible = maximum_detection > 0.015
		if enemy_state_label:
			enemy_state_label.text = _enemy_state_text(_get_aggregate_enemy_state())
		if alert_label:
			if any_enemy_chasing or highest_state in ["CHASE", "ATTACK"]:
				alert_label.text = "ОБНАРУЖЕН"
			elif maximum_detection > 0.08:
				alert_label.text = "ПОДОЗРЕНИЕ"
			else:
				alert_label.text = ""
		if stealth_status_label and is_instance_valid(stealth_system) and player:
			stealth_status_label.text = String(stealth_system.call("get_player_status", player))
			var exposure := float(stealth_system.call("get_visibility_multiplier", player))
			stealth_status_label.add_theme_color_override("font_color", Color("83c98c") if exposure < 0.55 else (Color("ffc45c") if exposure > 1.10 else Color("c5c9dc")))
	if player and player.global_position.y > FALL_LIMIT_Y:
		player.kill()

func _fail_mission(reason: String) -> void:
	if mission_completed or game_over:
		return
	if player:
		player.set_physics_process(false)
		player.release_controls()
		player.velocity = Vector2.ZERO
	if touch_controls:
		touch_controls.call("set_enabled", false)
	results_data = mission_manager.finish_mission(false, reason)
	if results_layer == null:
		_show_results(false)

func _on_mission_failed(results: Dictionary) -> void:
	if mission_completed:
		return
	game_over = true
	mission_completed = false
	if player:
		player.set_physics_process(false)
		player.release_controls()
		player.velocity = Vector2.ZERO
	if touch_controls:
		touch_controls.call("set_enabled", false)
	results_data = results.duplicate(true)
	_show_results(false)

func _complete_mission() -> void:
	if mission_completed or game_over:
		return
	mission_completed = true
	if player:
		player.set_physics_process(false)
		player.release_controls()
		player.velocity = Vector2.ZERO
	results_data = mission_manager.finish_mission(true)
	_show_results(true)

func _respawn_at_checkpoint() -> void:
	respawning = false
	var snapshot := checkpoint_system.get_snapshot()
	# MissionManager keeps all collected IDs and run statistics across death.
	# The checkpoint supplies the respawn position and alarm-device state only.
	var restore_alarm := bool(snapshot.get("alarm_enabled", true)) and not mission_manager.has_world_flag("signal_disabled")
	alarm_system.restore_enabled(restore_alarm)
	player.global_position = snapshot.get("respawn_position", Vector2(150, 580))
	player.velocity = Vector2.ZERO
	player.health = 100.0
	player.invuln = 1.8
	player.guard_stamina = SilentBladePlayer.GUARD_MAX
	player.guard_is_broken = false
	player.guard_break_timer = 0.0
	player.jump_count = 0
	player.coyote_timer = 0.12
	player.jump_buffer_timer = 0.0
	player.dash_cooldown = 0.0
	player.combo_step = 0
	player.combo_timer = 0.0
	player.end_block()
	player.release_controls()
	player.health_changed.emit(player.health)
	player.guard_changed.emit(player.guard_stamina, SilentBladePlayer.GUARD_MAX)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	_build_enemies()
	_apply_persistent_world_state()
	player.set_physics_process(true)
	for enemy in enemies:
		enemy.set_physics_process(true)
	if touch_controls:
		touch_controls.call("set_enabled", true)
	status_label.text = "КОНТРОЛЬНАЯ ТОЧКА • ПРОГРЕСС СОХРАНЁН"
	status_label.add_theme_color_override("font_color", Color("83c98c"))

func _apply_persistent_world_state() -> void:
	for prop in mission_level.interactables:
		if not is_instance_valid(prop):
			continue
		if prop.kind == "door" and mission_manager.has_world_flag("door_%s_open" % prop.object_id):
			prop.set_open(true)
		if mission_manager.has_collected(prop.object_id) or (prop.kind == "alarm" and mission_manager.has_world_flag("signal_disabled")):
			prop.set_consumed(true)
	_refresh_evacuation_flag()

func _show_results(success: bool) -> void:
	var screen_size := _get_screen_size()
	if results_layer:
		return
	if touch_controls:
		touch_controls.call("set_enabled", false)
	get_tree().paused = true
	paused = true
	if results_data.is_empty():
		results_data = mission_manager.get_results(success)
	results_layer = CanvasLayer.new()
	results_layer.name = "MissionResults"
	results_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(results_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2((screen_size.x - 620.0) * 0.5, maxf(12.0, (screen_size.y - 624.0) * 0.5))
	panel.size = Vector2(620, 624)
	shade.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.add_theme_constant_override("margin_left", 16)
	column.add_theme_constant_override("margin_right", 16)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "МИССИЯ ВЫПОЛНЕНА" if success else "МИССИЯ ПРОВАЛЕНА"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("e9dce5") if success else Color("ff6575"))
	column.add_child(heading)
	var rank := Label.new()
	rank.text = String(results_data.get("rank", "D"))
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.add_theme_font_size_override("font_size", 64)
	rank.add_theme_color_override("font_color", Color("ffd36a"))
	column.add_child(rank)
	var details := "Время: %s\nОбнаружения: %d    Тревоги: %d\nСекреты: %d/%d    Документы: %d\nНейтрализовано противников: %d" % [
		String(results_data.get("time_text", "00:00")),
		int(results_data.get("detections", 0)), int(results_data.get("alarms", 0)),
		int(results_data.get("secrets_found", 0)), int(results_data.get("secrets_total", 0)),
		int(results_data.get("documents_collected", 0)), int(results_data.get("neutralized", 0))
	]
	var stats := Label.new()
	stats.text = details
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 17)
	column.add_child(stats)
	var optional := Label.new()
	var lines := PackedStringArray(["ДОПОЛНИТЕЛЬНЫЕ ЗАДАНИЯ"])
	for task in results_data.get("optional_completed", []):
		var marker := "✓" if bool(task.get("completed", false)) else "—"
		lines.append("%s %s" % [marker, String(task.get("title", task.get("id", "")))])
	optional.text = "\n".join(lines)
	optional.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	optional.add_theme_font_size_override("font_size", 14)
	column.add_child(optional)
	var rubric := Label.new()
	rubric.text = "РАНГИ: S ≤ 07:00 • без обнаружений/тревог, все секреты, без нейтрализаций\nA ≤ 11:00 • без обнаружений, до 1 тревоги, ≥1 секрет\nB ≤ 16:00 • до 2 обнаружений и 2 тревог • C — прочее успешное прохождение • D — провал"
	rubric.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rubric.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rubric.add_theme_font_size_override("font_size", 11)
	rubric.add_theme_color_override("font_color", Color("b8bac8"))
	column.add_child(rubric)
	var retry := Button.new()
	retry.text = "ПОВТОРИТЬ МИССИЮ"
	retry.custom_minimum_size = Vector2(320, 46)
	retry.pressed.connect(_restart_level)
	column.add_child(retry)
	var continue_button := Button.new()
	continue_button.text = "ПРОДОЛЖИТЬ"
	continue_button.custom_minimum_size = Vector2(320, 42)
	continue_button.pressed.connect(_show_campaign_transition)
	column.add_child(continue_button)
	var menu := Button.new()
	menu.text = "В МЕНЮ"
	menu.custom_minimum_size = Vector2(320, 42)
	menu.pressed.connect(_return_to_menu)
	column.add_child(menu)

func _show_campaign_transition() -> void:
	var screen_size := _get_screen_size()
	if results_layer:
		results_layer.queue_free()
	results_layer = CanvasLayer.new()
	results_layer.name = "CampaignTransition"
	results_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(results_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_layer.add_child(shade)
	var message := Label.new()
	message.text = "MISSION 01 ЗАВЕРШЕНА\n\nMISSION 02 — LANTERN WATCH\n\nСледующая глава не входит в версию 0.8.\nТекущий результат сохранён до выхода из этой сцены."
	message.position = Vector2((screen_size.x - 720.0) * 0.5, (screen_size.y - 250.0) * 0.5 - 45.0)
	message.size = Vector2(720, 250)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 24)
	shade.add_child(message)
	var back := Button.new()
	back.text = "ВЕРНУТЬСЯ К РЕЗУЛЬТАТАМ"
	back.position = Vector2((screen_size.x - 360.0) * 0.5, (screen_size.y - 54.0) * 0.5 + 110.0)
	back.size = Vector2(360, 54)
	back.pressed.connect(func():
		results_layer.queue_free()
		results_layer = null
		get_tree().paused = true
		_show_results(true)
	)
	shade.add_child(back)

func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not mission_completed and not game_over:
		_toggle_pause()


