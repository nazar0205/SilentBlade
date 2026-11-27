extends Node
class_name SilentBladeCheckpointSystem

signal checkpoint_activated(checkpoint_id: String, position: Vector2)

var checkpoint_id := "start"
var respawn_position := Vector2(150.0, 580.0)
var alarm_enabled := true
var mission_state: Dictionary = {}
var _activated_ids: Dictionary = {"start": true}

func activate(id: String, position: Vector2, current_alarm_enabled: bool, state: Dictionary = {}) -> bool:
	if checkpoint_id == id or id.is_empty():
		return false
	checkpoint_id = id
	respawn_position = position
	alarm_enabled = current_alarm_enabled
	mission_state = state.duplicate(true)
	_activated_ids[id] = true
	checkpoint_activated.emit(checkpoint_id, respawn_position)
	return true

func get_snapshot() -> Dictionary:
	return {
		"checkpoint_id": checkpoint_id,
		"respawn_position": respawn_position,
		"alarm_enabled": alarm_enabled,
		"mission_state": mission_state.duplicate(true),
		"activated_ids": _activated_ids.keys()
	}

func restore(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	checkpoint_id = String(snapshot.get("checkpoint_id", checkpoint_id))
	respawn_position = snapshot.get("respawn_position", respawn_position)
	alarm_enabled = bool(snapshot.get("alarm_enabled", alarm_enabled))
	mission_state = snapshot.get("mission_state", {}).duplicate(true)
	_activated_ids.clear()
	for id in snapshot.get("activated_ids", [checkpoint_id]):
		_activated_ids[String(id)] = true

func reset() -> void:
	checkpoint_id = "start"
	respawn_position = Vector2(150.0, 580.0)
	alarm_enabled = true
	mission_state.clear()
	_activated_ids = {"start": true}
