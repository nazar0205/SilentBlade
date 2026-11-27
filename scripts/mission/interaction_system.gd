extends Node
class_name SilentBladeInteractionSystem

signal target_changed(target: SilentBladeMissionInteractable)
signal interaction_completed(interactable: SilentBladeMissionInteractable)
signal interaction_blocked(message: String)

var player: SilentBladePlayer
var mission_manager: SilentBladeMissionManager
var touch_controls: Control
var interaction_range := 106.0
var current_target: SilentBladeMissionInteractable
var _registered: Array[SilentBladeMissionInteractable] = []
var _refresh_timer := 0.0

func configure(actor: SilentBladePlayer, manager: SilentBladeMissionManager, controls: Control) -> void:
	player = actor
	mission_manager = manager
	touch_controls = controls

func register_interactable(prop: SilentBladeMissionInteractable) -> void:
	if not is_instance_valid(prop) or _registered.has(prop):
		return
	_registered.append(prop)
	prop.interacted.connect(_on_interacted)
	prop.interaction_blocked.connect(_on_interaction_blocked)

func unregister_all() -> void:
	_registered.clear()
	_set_target(null)

func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.10
	_refresh_target()

func _refresh_target() -> void:
	if not is_instance_valid(player):
		_set_target(null)
		return
	var nearest: SilentBladeMissionInteractable
	var nearest_distance := interaction_range
	for index in range(_registered.size() - 1, -1, -1):
		var prop := _registered[index]
		if not is_instance_valid(prop):
			_registered.remove_at(index)
			continue
		if not prop.visible or prop.consumed:
			continue
		if prop.kind == "door" and prop.is_open:
			continue
		var distance := player.global_position.distance_to(prop.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = prop
	_set_target(nearest)

func _set_target(next_target: SilentBladeMissionInteractable) -> void:
	if current_target != next_target:
		current_target = next_target
		target_changed.emit(current_target)
	if is_instance_valid(touch_controls) and touch_controls.has_method("set_interaction_prompt"):
		var prompt := current_target.get_prompt(mission_manager) if is_instance_valid(current_target) else ""
		touch_controls.call("set_interaction_prompt", prompt)

func get_current_prompt() -> String:
	if not is_instance_valid(current_target):
		return ""
	return current_target.get_prompt(mission_manager)

func interact() -> bool:
	if not is_instance_valid(current_target) or not is_instance_valid(player):
		return false
	var succeeded := current_target.interact(player, mission_manager)
	if succeeded:
		_refresh_target()
	return succeeded

func _on_interacted(prop: SilentBladeMissionInteractable) -> void:
	interaction_completed.emit(prop)

func _on_interaction_blocked(message: String) -> void:
	interaction_blocked.emit(message)
