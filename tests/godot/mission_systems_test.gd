extends SceneTree
## Mission 01 runtime contract test. Run with:
##   godot --headless --path . -s tests/godot/mission_systems_test.gd

const MissionManagerScript = preload("res://scripts/mission/mission_manager.gd")
const MissionResultsScript = preload("res://scripts/mission/mission_results.gd")
const CheckpointScript = preload("res://scripts/mission/checkpoint_system.gd")
const AlarmScript = preload("res://scripts/mission/alarm_system.gd")
const NoiseScript = preload("res://scripts/stealth/noise_system.gd")
const InteractableScript = preload("res://scripts/mission/mission_interactable.gd")
const PlayerScript = preload("res://scripts/player.gd")
const StealthScript = preload("res://scripts/stealth/stealth_system.gd")
const MissionLevelScript = preload("res://scripts/mission/mission_level.gd")

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1

func _run() -> void:
	var config_value = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/mission_01.json"))
	_check(config_value is Dictionary, "Mission 01 data parses")
	if not config_value is Dictionary:
		quit(1)
		return
	var config: Dictionary = config_value

	# Objectives are prerequisites, not a brittle single index: archive can be collected before alarm off.
	var manager: SilentBladeMissionManager = MissionManagerScript.new()
	root.add_child(manager)
	manager.start_mission(config)
	_check(manager.complete_objective("enter_village"), "entry objective completes")
	_check(manager.complete_objective("retrieve_orders"), "archive objective may complete before signal is disabled")
	_check(not manager.complete_objective("evacuate"), "evacuation remains locked while the signal is active")
	_check(manager.complete_objective("disable_signal"), "signal objective completes")
	_check(manager.complete_objective("evacuate"), "evacuation unlocks after both required objectives")
	_check(manager.collect_item("archive_orders", "DOCUMENT"), "archive document is collected once")
	_check(not manager.collect_item("archive_orders", "DOCUMENT"), "duplicate archive document is rejected")

	# Results rubric uses literal scenarios with known expected ranks.
	_check(MissionResultsScript.evaluate({"success": true, "elapsed_time": 400.0, "detections": 0, "alarms": 0, "secrets_found": 2, "secrets_total": 2, "neutralized": 0}) == "S", "perfect extraction awards S")
	_check(MissionResultsScript.evaluate({"success": true, "elapsed_time": 600.0, "detections": 0, "alarms": 1, "secrets_found": 1, "secrets_total": 2, "neutralized": 0}) == "A", "clean route with one alarm awards A")
	_check(MissionResultsScript.evaluate({"success": true, "elapsed_time": 900.0, "detections": 2, "alarms": 2, "secrets_found": 0, "secrets_total": 2, "neutralized": 2}) == "B", "limited detection and alarm awards B")
	_check(MissionResultsScript.evaluate({"success": true, "elapsed_time": 1000.0, "detections": 3, "alarms": 2, "secrets_found": 0, "secrets_total": 2, "neutralized": 2}) == "C", "rough extraction awards C")
	_check(MissionResultsScript.evaluate({"success": false, "detections": 0, "alarms": 0}) == "D", "failed mission awards D")
	var optional := MissionResultsScript.optional_objectives({"detections": 1, "neutralized": 0, "secrets_found": 1, "secrets_total": 2})
	_check(optional.size() == 4 and not optional[0]["completed"] and optional[1]["completed"] and not optional[2]["completed"] and not optional[3]["completed"], "optional challenges report their actual completion states")
	var all_documents := MissionResultsScript.optional_objectives({"documents_collected": 2, "documents_total": 2})
	_check(all_documents[3]["completed"], "all documents optional challenge requires both unique documents")
	var failed_manager: SilentBladeMissionManager = MissionManagerScript.new()
	root.add_child(failed_manager)
	failed_manager.start_mission(config)
	var failure_signal_results: Array[Dictionary] = []
	failed_manager.mission_failed.connect(func(result: Dictionary): failure_signal_results.append(result))
	var failed_result: Dictionary = failed_manager.finish_mission(false, "test failure")
	_check(failed_result.get("rank") == "D" and failure_signal_results.size() == 1, "mission failure emits results and grade D")

	# Checkpoint snapshots retain position, alarm state and the progress payload.
	var checkpoint: SilentBladeCheckpointSystem = CheckpointScript.new()
	root.add_child(checkpoint)
	var state := manager.snapshot_persistent_state()
	_check(checkpoint.activate("archive_checkpoint", Vector2(3940, 580), false, state), "checkpoint activates")
	var snapshot: Dictionary = checkpoint.get_snapshot()
	_check(snapshot["respawn_position"] == Vector2(3940, 580), "checkpoint stores respawn position")
	_check(not snapshot["alarm_enabled"], "checkpoint stores disabled alarm state")
	_check(snapshot["mission_state"]["collected_item_ids"].has("archive_orders"), "checkpoint stores collected item IDs")
	checkpoint.reset()
	checkpoint.restore(snapshot)
	_check(checkpoint.checkpoint_id == "archive_checkpoint", "checkpoint snapshot restores its identity")

	# Global alarm reaches the existing noise bus at the fixed alarm location, not the player's location.
	var noise: SilentBladeNoiseSystem = NoiseScript.new()
	root.add_child(noise)
	var alarm: SilentBladeAlarmSystem = AlarmScript.new()
	alarm.configure(noise, Vector2(3210, 610))
	root.add_child(alarm)
	_check(alarm.raise_global_alarm(Vector2(800, 400)), "alarm can be raised once")
	_check(noise.active_events.size() == 1, "alarm broadcasts one noise event")
	if not noise.active_events.is_empty():
		_check(noise.active_events.back()["position"] == Vector2(3210, 610), "alarm event originates from the alarm device")
	_check(not alarm.raise_global_alarm(Vector2(900, 400)), "alarm broadcast is idempotent while active")
	_check(alarm.disable_alarm(), "alarm can be disabled")
	_check(not alarm.alarm_device_enabled, "alarm device remains disabled")

	# Physical interactable enforces the evacuation gate and one-shot collection.
	var actor: SilentBladePlayer = PlayerScript.new()
	root.add_child(actor)
	var interaction_events: Array[Dictionary] = []
	actor.noise_emitted.connect(func(_position: Vector2, radius: float, intensity: float, event_type: String, source_id: int):
		interaction_events.append({"radius": radius, "intensity": intensity, "event_type": event_type, "source_id": source_id})
	)
	var prop: SilentBladeMissionInteractable = InteractableScript.new()
	prop.configure("test_evac", "evacuation", "ЭВАКУАЦИЯ", true, "ready", "ЗАБЕРИТЕ ДОКУМЕНТ")
	root.add_child(prop)
	var interact_manager: SilentBladeMissionManager = MissionManagerScript.new()
	root.add_child(interact_manager)
	interact_manager.start_mission(config)
	_check(not prop.interact(actor, interact_manager), "locked evacuation interaction is rejected")
	interact_manager.set_world_flag("ready")
	_check(prop.interact(actor, interact_manager), "evacuation interaction succeeds after prerequisites")
	_check(interaction_events.size() == 1 and interaction_events[0]["event_type"] == "INTERACTION", "successful interaction emits a noise event")
	_check(not prop.interact(actor, interact_manager), "one-shot interactable cannot be collected twice")

	# Build the real data-driven level: it must expose multiple routes and all mission objects.
	var stealth: SilentBladeStealthSystem = StealthScript.new()
	root.add_child(stealth)
	var level: SilentBladeMissionLevel = MissionLevelScript.new()
	root.add_child(level)
	level.build(stealth)
	_check(level.world_width >= 6000.0, "mission level has full-width world bounds")
	_check(level.enemy_spawns.size() >= 8, "mission level returns all configured enemy spawn descriptors")
	_check(level.interactables.size() >= 10, "mission level creates the mission interactables")
	_check(stealth.zones.size() >= 20, "mission level registers gameplay stealth zones")

	print("RESULT: ", "FAILED (%d)" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)
