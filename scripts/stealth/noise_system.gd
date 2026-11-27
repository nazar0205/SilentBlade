extends Node2D
class_name SilentBladeNoiseSystem

signal noise_emitted(event: Dictionary)

const EVENT_LIFETIME := 4.5
const VISUAL_LIFETIME := 0.72
const MAX_EVENTS := 24
var active_events: Array[Dictionary] = []
var _next_event_id := 1
var _prune_timer := 0.0

func emit_noise(world_position: Vector2, radius: float, intensity: float, event_type: String, source_id: int = -1) -> void:
	var event := {
		"id": _next_event_id,
		"position": world_position,
		"radius": maxf(0.0, radius),
		"intensity": clampf(intensity, 0.0, 1.0),
		"event_type": event_type,
		"source_id": source_id,
		"age": 0.0
	}
	_next_event_id += 1
	active_events.append(event)
	while active_events.size() > MAX_EVENTS:
		active_events.pop_front()
	noise_emitted.emit(event.duplicate())
	queue_redraw()

func _process(delta: float) -> void:
	_prune_timer -= delta
	var has_visual := false
	for event in active_events:
		event["age"] = float(event["age"]) + delta
		if float(event["age"]) <= VISUAL_LIFETIME:
			has_visual = true
	if _prune_timer <= 0.0:
		_prune_timer = 0.5
		for index in range(active_events.size() - 1, -1, -1):
			if float(active_events[index]["age"]) > EVENT_LIFETIME:
				active_events.remove_at(index)
	if has_visual:
		queue_redraw()

func _draw() -> void:
	for event in active_events:
		var age := float(event["age"])
		if age > VISUAL_LIFETIME:
			continue
		var progress := age / VISUAL_LIFETIME
		var radius := 12.0 + progress * minf(80.0, float(event["radius"]) * 0.18)
		var alpha := (1.0 - progress) * 0.5
		draw_arc(event["position"], radius, 0.0, TAU, 28, Color(0.95, 0.78, 0.42, alpha), 2.0)
