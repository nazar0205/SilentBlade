extends Node
class_name SilentBladeMissionManager

signal objective_changed(current: Dictionary, completed_count: int, total_count: int)
signal stats_changed(stats: Dictionary)
signal mission_completed(results: Dictionary)
signal mission_failed(results: Dictionary)

const ObjectiveManagerScript = preload("res://scripts/mission/objective_manager.gd")
const MissionResultsScript = preload("res://scripts/mission/mission_results.gd")

var mission_config: Dictionary = {}
var objective_manager: SilentBladeObjectiveManager
var optional_objectives: Array[Dictionary] = []
var secret_definitions: Array[Dictionary] = []
var collected_item_ids: Dictionary = {}
var world_flags: Dictionary = {}
var elapsed_time := 0.0
var detections := 0
var alarms := 0
var secrets_found := 0
var neutralized := 0
var documents_collected := 0
var mission_started := false
var is_finished := false
var is_success := false
var failure_reason := ""

func _ready() -> void:
	objective_manager = ObjectiveManagerScript.new()
	objective_manager.progress_changed.connect(_on_objective_progress)

func start_mission(config: Dictionary) -> void:
	mission_config = config.duplicate(true)
	if objective_manager == null:
		objective_manager = ObjectiveManagerScript.new()
		objective_manager.progress_changed.connect(_on_objective_progress)
	objective_manager.configure(mission_config.get("objectives", []))
	optional_objectives.clear()
	for entry in mission_config.get("optional_objectives", []):
		if entry is Dictionary:
			optional_objectives.append(entry.duplicate(true))
	secret_definitions.clear()
	for entry in mission_config.get("secrets", []):
		if entry is Dictionary:
			secret_definitions.append(entry.duplicate(true))
	collected_item_ids.clear()
	world_flags.clear()
	elapsed_time = 0.0
	detections = 0
	alarms = 0
	secrets_found = 0
	neutralized = 0
	documents_collected = 0
	mission_started = false
	is_finished = false
	is_success = false
	failure_reason = ""

func begin_clock() -> void:
	mission_started = true

func tick(delta: float) -> void:
	if mission_started and not is_finished:
		elapsed_time += maxf(0.0, delta)

func complete_objective(objective_id: String) -> bool:
	if is_finished or objective_manager == null:
		return false
	return objective_manager.complete(objective_id)

func is_objective_completed(objective_id: String) -> bool:
	return objective_manager != null and objective_manager.is_completed(objective_id)

func collect_item(item_id: String, item_kind: String) -> bool:
	if is_finished or item_id.is_empty() or collected_item_ids.has(item_id):
		return false
	collected_item_ids[item_id] = item_kind
	if item_kind == "SECRET" or item_kind == "CACHE":
		secrets_found += 1
	elif item_kind == "DOCUMENT":
		documents_collected += 1
		if item_id != "archive_orders":
			secrets_found += 1
	stats_changed.emit(get_stats())
	return true

func has_collected(item_id: String) -> bool:
	return collected_item_ids.has(item_id)

func set_world_flag(flag_id: String, value: bool = true) -> void:
	world_flags[flag_id] = value
	stats_changed.emit(get_stats())

func has_world_flag(flag_id: String) -> bool:
	return bool(world_flags.get(flag_id, false))

func record_detection() -> void:
	detections += 1
	stats_changed.emit(get_stats())

func record_alarm() -> void:
	alarms += 1
	stats_changed.emit(get_stats())

func record_neutralization() -> void:
	neutralized += 1
	stats_changed.emit(get_stats())

func get_optional_results() -> Array[Dictionary]:
	return MissionResultsScript.optional_objectives(get_stats())

func get_stats() -> Dictionary:
	var extra_documents := 0
	for secret in secret_definitions:
		if String(secret.get("kind", "")) == "DOCUMENT":
			extra_documents += 1
	return {
		"elapsed_time": elapsed_time,
		"documents_total": 1 + extra_documents,
		"detections": detections,
		"alarms": alarms,
		"secrets_found": secrets_found,
		"secrets_total": secret_definitions.size(),
		"documents_collected": documents_collected,
		"neutralized": neutralized,
		"collected_ids": collected_item_ids.keys(),
		"completed_objectives": objective_manager.get_completed_ids() if objective_manager else []
	}

func get_results(success: bool) -> Dictionary:
	var stats := get_stats()
	stats["success"] = success
	var rank := MissionResultsScript.evaluate(stats)
	var optional_done := MissionResultsScript.optional_objectives(stats)
	var time_seconds := int(elapsed_time)
	var results := {
		"mission_title": String(mission_config.get("title", "MISSION 01")),
		"success": success,
		"rank": rank,
		"elapsed_time": elapsed_time,
		"time_text": "%02d:%02d" % [time_seconds / 60, time_seconds % 60],
		"detections": detections,
		"alarms": alarms,
		"secrets_found": secrets_found,
		"secrets_total": secret_definitions.size(),
		"documents_collected": documents_collected,
		"neutralized": neutralized,
		"optional_completed": optional_done,
		"optional_total": optional_objectives.size(),
		"completed_objectives": objective_manager.get_completed_ids() if objective_manager else []
	}
	return results

func finish_mission(success: bool, reason: String = "") -> Dictionary:
	if is_finished:
		return get_results(is_success)
	is_finished = true
	is_success = success
	failure_reason = reason
	var results := get_results(success)
	if success:
		mission_completed.emit(results)
	else:
		mission_failed.emit(results)
	return results

func restore_persistent_state(completed_ids: Array, collected_ids: Dictionary, flags: Dictionary, saved_stats: Dictionary) -> void:
	if objective_manager:
		objective_manager.restore_completed(completed_ids)
	collected_item_ids = collected_ids.duplicate(true)
	world_flags = flags.duplicate(true)
	secrets_found = int(saved_stats.get("secrets_found", 0))
	documents_collected = int(saved_stats.get("documents_collected", 0))
	detections = int(saved_stats.get("detections", detections))
	alarms = int(saved_stats.get("alarms", alarms))
	neutralized = int(saved_stats.get("neutralized", neutralized))
	elapsed_time = float(saved_stats.get("elapsed_time", elapsed_time))
	stats_changed.emit(get_stats())

func restore_progress_state(snapshot: Dictionary) -> void:
	if objective_manager:
		objective_manager.restore_completed(snapshot.get("completed_objectives", []))
	collected_item_ids = snapshot.get("collected_item_ids", {}).duplicate(true)
	world_flags = snapshot.get("world_flags", {}).duplicate(true)
	# Death never rewinds mission time, detection count, alarm count or neutralization statistics.
	stats_changed.emit(get_stats())

func snapshot_persistent_state() -> Dictionary:
	return {
		"completed_objectives": objective_manager.get_completed_ids() if objective_manager else [],
		"collected_item_ids": collected_item_ids.duplicate(true),
		"world_flags": world_flags.duplicate(true),
		"stats": get_stats()
	}

func _on_objective_progress(current: Dictionary, completed_count: int, total_count: int) -> void:
	objective_changed.emit(current, completed_count, total_count)
