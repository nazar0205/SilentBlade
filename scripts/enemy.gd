extends CharacterBody2D
class_name SilentBladeGuard

signal player_spotted
var left_limit := 650.0
var right_limit := 1050.0
var direction := -1
var speed := 72.0
var alert := 0.0
var state := "PATROL"
var health := 55.0
var target: SilentBladePlayer

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 15
	capsule.height = 54
	shape.shape = capsule
	shape.position.y = -27
	add_child(shape)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dx := target.global_position.x - global_position.x
	var dy := absf(target.global_position.y - global_position.y)
	var facing_player := signf(dx) == direction
	var visible := facing_player and absf(dx) < 300.0 and dy < 100.0 and not target.crouching
	if visible:
		alert = minf(1.0, alert + delta * 0.75)
	else:
		alert = maxf(0.0, alert - delta * 0.22)
	if alert >= 1.0:
		state = "ALERT"
		player_spotted.emit()
	elif alert > 0.15:
		state = "SUSPICIOUS"
	else:
		state = "PATROL"
	if state == "ALERT":
		direction = 1 if dx > 0 else -1
		velocity.x = direction * 110.0
	else:
		velocity.x = direction * speed
		if global_position.x < left_limit:
			direction = 1
		elif global_position.x > right_limit:
			direction = -1
	velocity.y += 1200.0 * delta
	move_and_slide()
	queue_redraw()

func hit(damage: float) -> void:
	health -= damage
	if health <= 0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-13, -49, 26, 39), Color("171827"))
	draw_rect(Rect2(-15, -59, 30, 16), Color("292c3b"))
	draw_rect(Rect2(-13, -62, 26, 5), Color("0b1020"))
	draw_rect(Rect2(-7, -55, 14, 3), Color("e4d6bd"))
	draw_rect(Rect2(-15, -10, 12, 10), Color("0d1220"))
	draw_rect(Rect2(3, -10, 12, 10), Color("0d1220"))
	if state == "ALERT":
		draw_circle(Vector2(0, -75), 5, Color("ff4054"))
	elif state == "SUSPICIOUS":
		draw_circle(Vector2(0, -75), 5, Color("ffc65a"))
	# Vision cone: visual warning only; AI uses the same direction/range checks.
	var cone := PackedVector2Array([Vector2(0, -53), Vector2(direction * 285, -112), Vector2(direction * 285, -5)])
	draw_colored_polygon(cone, Color(1.0, 0.22, 0.28, 0.11 if state == "PATROL" else 0.22))
