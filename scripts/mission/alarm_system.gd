extends Node
class_name SilentBladeAlarmSystem

signal mode_changed(mode: String)
signal alarm_triggered(source_position: Vector2, count: int)
signal alarm_disabled

var noise_system: SilentBladeNoiseSystem
var alarm_device_enabled := true
var global_alarm_active := false
var mode := "CALM"
var alarm_count := 0
var local_alert_timer := 0.0
var signal_source_position := Vector2.ZERO

func configure(noise: SilentBladeNoiseSystem, signal_position: Vector2) -> void:
	noise_system = noise
	signal_source_position = signal_position

func raise_local_alert(source_position: Vector2) -> void:
	if global_alarm_active:
		return
	local_alert_timer = maxf(local_alert_timer, 3.0)
	_set_mode("LOCAL_ALERT")

func raise_global_alarm(source_position: Vector2) -> bool:
	if not alarm_device_enabled or global_alarm_active:
		return false
	global_alarm_active = true
	alarm_count += 1
	_set_mode("GLOBAL_ALARM")
	# One fixed event at the alarm device; enemies hear it through their existing NoiseSystem listener.
	if is_instance_valid(noise_system):
		noise_system.emit_noise(signal_source_position if signal_source_position != Vector2.ZERO else source_position, 6200.0, 1.0, "GLOBAL_ALARM", -1)
	alarm_triggered.emit(source_position, alarm_count)
	return true

func disable_alarm() -> bool:
	if not alarm_device_enabled:
		return false
	alarm_device_enabled = false
	global_alarm_active = false
	local_alert_timer = maxf(local_alert_timer, 2.0)
	_set_mode("LOCAL_ALERT")
	alarm_disabled.emit()
	return true

func restore_enabled(value: bool) -> void:
	alarm_device_enabled = value
	global_alarm_active = false
	local_alert_timer = 0.0
	_set_mode("CALM")

func _process(delta: float) -> void:
	if mode == "LOCAL_ALERT" and local_alert_timer > 0.0:
		local_alert_timer = maxf(0.0, local_alert_timer - delta)
		if local_alert_timer <= 0.0:
			_set_mode("CALM")

func _set_mode(next_mode: String) -> void:
	if mode == next_mode:
		return
	mode = next_mode
	mode_changed.emit(mode)
