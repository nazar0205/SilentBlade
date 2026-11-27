extends Area2D
class_name SilentBladeMissionInteractable

signal interacted(interactable: SilentBladeMissionInteractable)
signal interaction_blocked(message: String)

var object_id := ""
var kind := "prop"
var prompt := "ДЕЙСТВИЕ"
var locked_prompt := "ЗАКРЫТО"
var requires_flag := ""
var one_shot := false
var consumed := false
var is_open := false
var door_body: StaticBody2D
var _door_shape: CollisionShape2D
var _pulse := 0.0

func configure(id: String, object_kind: String, action_prompt: String, is_one_shot: bool = false, needs_flag: String = "", locked_text: String = "ЗАКРЫТО") -> void:
	object_id = id
	kind = object_kind
	prompt = action_prompt
	one_shot = is_one_shot
	requires_flag = needs_flag
	locked_prompt = locked_text

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var trigger := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 82.0
	trigger.shape = circle
	add_child(trigger)
	if kind == "door":
		door_body = StaticBody2D.new()
		door_body.name = "DoorCollision"
		door_body.collision_layer = 1
		door_body.collision_mask = 1
		door_body.position = Vector2(0.0, -54.0)
		var barrier_shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(42.0, 112.0)
		barrier_shape.shape = rectangle
		door_body.add_child(barrier_shape)
		add_child(door_body)
		_door_shape = barrier_shape
	queue_redraw()

func is_available(manager: SilentBladeMissionManager) -> bool:
	if consumed:
		return false
	if not requires_flag.is_empty() and (not is_instance_valid(manager) or not manager.has_world_flag(requires_flag)):
		return false
	return true

func get_prompt(manager: SilentBladeMissionManager) -> String:
	if not requires_flag.is_empty() and (not is_instance_valid(manager) or not manager.has_world_flag(requires_flag)):
		return locked_prompt
	if kind == "door" and is_open:
		return "ОТКРЫТО"
	return prompt

func interact(player: SilentBladePlayer, manager: SilentBladeMissionManager) -> bool:
	if consumed:
		return false
	if not is_available(manager):
		interaction_blocked.emit(locked_prompt)
		return false
	if kind == "door":
		if is_open:
			return false
		set_open(true)
	elif one_shot:
		set_consumed(true)
	# Interactive actions are audible to nearby guards. Valuable/small objects are quieter
	# than a sliding door or alarm console, but none of them reveals the actor's live position.
	if is_instance_valid(player) and player.has_method("notify_interaction_noise"):
		var radius := 150.0
		var intensity := 0.34
		match kind:
			"door":
				radius = 235.0
				intensity = 0.58
			"alarm":
				radius = 285.0
				intensity = 0.62
			"archive", "document":
				radius = 110.0
				intensity = 0.22
			"cache":
				radius = 135.0
				intensity = 0.28
			"checkpoint":
				radius = 95.0
				intensity = 0.18
			"evacuation":
				radius = 180.0
				intensity = 0.36
		player.notify_interaction_noise("INTERACTION", radius, intensity)
	interacted.emit(self)
	return true

func set_open(value: bool) -> void:
	is_open = value
	if is_instance_valid(_door_shape):
		_door_shape.set_deferred("disabled", is_open)
	queue_redraw()

func set_consumed(value: bool) -> void:
	consumed = value
	visible = not consumed
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	if kind in ["archive", "secret", "checkpoint", "evacuation", "alarm"] and not consumed:
		queue_redraw()

func _draw() -> void:
	if consumed:
		return
	match kind:
		"door":
			if is_open:
				draw_rect(Rect2(-18, -105, 36, 105), Color(0.08, 0.07, 0.09, 0.32))
				draw_arc(Vector2(0, -5), 34, PI, TAU, 18, Color("d5b17c"), 3.0)
			else:
				draw_rect(Rect2(-21, -108, 42, 108), Color("422d32"))
				for y in [-88.0, -58.0, -28.0]:
					draw_line(Vector2(-17, y), Vector2(17, y), Color("a77b5a"), 3.0)
				draw_circle(Vector2(12, -52), 3.0, Color("e5bd73"))
		"alarm":
			draw_rect(Rect2(-24, -58, 48, 58), Color("292a36"))
			draw_rect(Rect2(-18, -49, 36, 25), Color("873b4b"))
			draw_circle(Vector2(0, -37), 7.0, Color("f45a62", 0.65 + 0.35 * absf(sin(_pulse * 3.0))))
			draw_line(Vector2(0, -24), Vector2(0, -12), Color("d8b78b"), 3.0)
		"archive":
			draw_rect(Rect2(-34, -44, 68, 44), Color("4a3030"))
			draw_rect(Rect2(-27, -38, 54, 30), Color("c4a16b"))
			draw_rect(Rect2(-12, -34, 24, 21), Color("f1dfb4"))
			draw_circle(Vector2(0, -63), 25.0 + sin(_pulse * 2.0) * 3.0, Color(0.9, 0.66, 0.31, 0.09))
		"secret":
			draw_rect(Rect2(-22, -35, 44, 35), Color("5c463a"))
			draw_rect(Rect2(-16, -30, 32, 23), Color("d6b779"))
			draw_circle(Vector2(0, -44), 17.0, Color(0.95, 0.78, 0.38, 0.08))
		"checkpoint":
			draw_rect(Rect2(-23, -55, 46, 55), Color("322b3a"))
			draw_colored_polygon(PackedVector2Array([Vector2(-18, -42), Vector2(0, -64), Vector2(18, -42)]), Color("ad5367"))
			draw_circle(Vector2(0, -35), 9.0, Color("7ac4bf", 0.7 + 0.25 * sin(_pulse * 2.0)))
		"evacuation":
			draw_arc(Vector2(0, -44), 31.0 + sin(_pulse * 2.3) * 4.0, 0.0, TAU, 28, Color("7ac4bf", 0.85), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-8, -52), Vector2(16, -44), Vector2(-8, -36)]), Color("d1eee2"))
		"cache":
			draw_rect(Rect2(-20, -28, 40, 28), Color("5a3c2f"))
			draw_line(Vector2(-16, -22), Vector2(16, -22), Color("d9ad69"), 4.0)
		"document":
			draw_rect(Rect2(-18, -30, 36, 28), Color("e1d4ac"))
			draw_line(Vector2(-11, -22), Vector2(11, -22), Color("735b4d"), 2.0)
			draw_line(Vector2(-11, -14), Vector2(8, -14), Color("735b4d"), 2.0)

