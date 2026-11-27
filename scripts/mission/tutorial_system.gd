extends Node
class_name SilentBladeTutorialSystem

signal hint_changed(text: String, hint_id: String)

const SETTINGS_PATH := "user://silent_blade_settings.cfg"
var enabled := true
var seen_hints: Dictionary = {}
var _remaining := 0.0
var _active_hint := ""

func _ready() -> void:
	_load_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_enabled(value: bool) -> void:
	enabled = value
	_save_settings()
	if not enabled:
		_remaining = 0.0
		_active_hint = ""
		hint_changed.emit("", "")

func toggle_enabled() -> bool:
	set_enabled(not enabled)
	return enabled

func show_hint(hint_id: String, text: String, duration: float = 4.8) -> bool:
	if not enabled or hint_id.is_empty() or seen_hints.has(hint_id):
		return false
	seen_hints[hint_id] = true
	_active_hint = hint_id
	_remaining = maxf(0.8, duration)
	hint_changed.emit(text, hint_id)
	return true


func complete_hint(hint_id: String) -> bool:
	if _active_hint != hint_id or hint_id.is_empty():
		return false
	_active_hint = ""
	_remaining = 0.0
	hint_changed.emit("", "")
	return true

func get_active_hint_id() -> String:
	return _active_hint

func has_seen(hint_id: String) -> bool:
	return seen_hints.has(hint_id)

func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_active_hint = ""
		hint_changed.emit("", "")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		enabled = bool(config.get_value("tutorial", "enabled", true))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("tutorial", "enabled", enabled)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Tutorial setting could not be saved: %s" % error)
