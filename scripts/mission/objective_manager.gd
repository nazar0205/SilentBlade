extends RefCounted
class_name SilentBladeObjectiveManager

signal progress_changed(current: Dictionary, completed_count: int, total_count: int)
signal objective_completed(objective_id: String)

var objectives: Array[Dictionary] = []
var completed_ids: Dictionary = {}

func configure(entries: Array) -> void:
	objectives.clear()
	completed_ids.clear()
	for entry in entries:
		if entry is Dictionary and not String(entry.get("id", "")).is_empty():
			objectives.append(entry.duplicate(true))
	_emit_progress()

func current_objective() -> Dictionary:
	for entry in objectives:
		var id := String(entry.get("id", ""))
		if not completed_ids.has(id) and _requirements_met(entry):
			return entry
	return {}

func complete(objective_id: String) -> bool:
	if completed_ids.has(objective_id):
		return false
	var target: Dictionary = {}
	for entry in objectives:
		if String(entry.get("id", "")) == objective_id:
			target = entry
			break
	if target.is_empty() or not _requirements_met(target):
		return false
	completed_ids[objective_id] = true
	objective_completed.emit(objective_id)
	_emit_progress()
	return true

func _requirements_met(entry: Dictionary) -> bool:
	for requirement in entry.get("requires", []):
		if not completed_ids.has(String(requirement)):
			return false
	return true

func is_completed(objective_id: String) -> bool:
	return completed_ids.has(objective_id)

func get_completed_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in completed_ids.keys():
		ids.append(String(key))
	return ids

func restore_completed(ids: Array) -> void:
	completed_ids.clear()
	for item in ids:
		var id := String(item)
		if _contains_objective(id):
			completed_ids[id] = true
	_emit_progress()

func get_progress() -> Dictionary:
	return {"completed": completed_ids.size(), "total": objectives.size(), "current": current_objective()}

func _contains_objective(objective_id: String) -> bool:
	for entry in objectives:
		if String(entry.get("id", "")) == objective_id:
			return true
	return false

func _emit_progress() -> void:
	progress_changed.emit(current_objective(), completed_ids.size(), objectives.size())
