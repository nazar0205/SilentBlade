extends CharacterBody2D
class_name SilentBladePlayer

signal health_changed(value: float)
signal died

const SPEED := 300.0
const ACCEL := 1800.0
const JUMP_VELOCITY := -520.0
const GRAVITY := 1350.0
const DASH_SPEED := 760.0
const DASH_TIME := 0.16
const GRAPPLE_RANGE := 430.0

var health := 100.0
var facing := 1
var crouching := false
var attacking := false
var attack_timer := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var grapple_point: Vector2 = Vector2.ZERO
var grappling := false
var rope_length := 0.0
var anchors: Array[Vector2] = []
var invuln := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 17.0
	capsule.height = 58.0
	shape.shape = capsule
	shape.position = Vector2(0, -30)
	add_child(shape)
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(48.0)

func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	attacking = attack_timer > 0.0
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.y = 0
		velocity.x = facing * DASH_SPEED
	else:
		var axis := Input.get_axis("move_left", "move_right")
		if absf(axis) > 0.1:
			facing = 1 if axis > 0 else -1
		velocity.x = move_toward(velocity.x, axis * (SPEED * (0.48 if crouching else 1.0)), ACCEL * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			if Input.is_action_just_pressed("jump"):
				velocity.y = JUMP_VELOCITY
		if Input.is_action_just_pressed("crouch"):
			crouching = true
		if Input.is_action_just_released("crouch"):
			crouching = false
		if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
			dash_timer = DASH_TIME
			dash_cooldown = 0.72
			grappling = false
	if Input.is_action_just_pressed("attack"):
		attack_timer = 0.28
	if Input.is_action_just_pressed("grapple"):
		_toggle_grapple()
	if grappling:
		_apply_rope(delta)
	move_and_slide()
	queue_redraw()


func release_controls() -> void:
	crouching = false
	grappling = false
	dash_timer = 0.0
	attack_timer = 0.0
	attacking = false
	velocity.x = 0.0

func _toggle_grapple() -> void:
	if grappling:
		grappling = false
		return
	var best := GRAPPLE_RANGE
	var chosen := Vector2.ZERO
	for point in anchors:
		var d := global_position.distance_to(point)
		if d < best and (point.x - global_position.x) * facing > -80.0:
			best = d
			chosen = point
	if chosen != Vector2.ZERO:
		grapple_point = chosen
		rope_length = maxf(95.0, best * 0.82)
		grappling = true

func _apply_rope(delta: float) -> void:
	var offset := global_position - grapple_point
	var distance := offset.length()
	if distance > GRAPPLE_RANGE + 120.0:
		grappling = false
		return
	if distance < 0.001:
		return

	var radial := offset / distance
	var outward_speed := velocity.dot(radial)
	# A rope can pull but cannot push: remove velocity that would stretch it further.
	if outward_speed > 0.0:
		velocity -= radial * outward_speed

	# Apply a small steering impulse along the rope tangent to make swing control responsive.
	var tangent := Vector2(-radial.y, radial.x)
	velocity += tangent * (float(facing) * 390.0 * delta)

	# Enforce maximum rope length after velocity integration prediction.
	if distance > rope_length:
		var corrected_position := grapple_point + radial * rope_length
		global_position = corrected_position
		var radial_component := velocity.dot(radial)
		if radial_component > 0.0:
			velocity -= radial * radial_component

func take_damage(amount: float) -> void:
	if invuln > 0.0:
		return
	health = maxf(0.0, health - amount)
	invuln = 0.7
	health_changed.emit(health)
	if health <= 0.0:
		died.emit()

func _draw() -> void:
	var body_color := Color(0.055, 0.065, 0.11)
	if invuln > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		body_color = Color(0.8, 0.8, 0.9)
	# Feet, body, head and scarf are deliberately drawn as original placeholder pixel-art shapes.
	draw_rect(Rect2(-16, -12, 13, 12), Color("171a2a"))
	draw_rect(Rect2(3, -12, 14, 12), Color("171a2a"))
	draw_rect(Rect2(-13, -49 if not crouching else -38, 27, 38 if not crouching else 27), body_color)
	draw_rect(Rect2(-11, -66 if not crouching else -55, 23, 20), Color("20263c"))
	draw_rect(Rect2(-9, -61 if not crouching else -50, 19, 8), Color("090d19"))
	draw_rect(Rect2(2 if facing > 0 else -9, -57 if not crouching else -46, 8, 3), Color("e8e9f5"))	
	# Red scarf trailing behind the movement direction.
	var scarf := PackedVector2Array([Vector2(-8 * facing, -47), Vector2(-30 * facing, -40), Vector2(-48 * facing, -27), Vector2(-26 * facing, -35)])
	draw_colored_polygon(scarf, Color("a71936"))
	draw_line(Vector2(-5 * facing, -47), Vector2(-38 * facing, -40), Color("e43b52"), 3.0)
	if attacking:
		var start := Vector2(13 * facing, -36)
		var finish := Vector2(65 * facing, -58)
		draw_arc(start, 53, deg_to_rad(-65 if facing > 0 else 195), deg_to_rad(55 if facing > 0 else 305), 16, Color("f4e7e4"), 4.0)
		draw_line(start, finish, Color("dce6ff"), 3.0)
	if grappling:
		draw_line(Vector2(0, -48), to_local(grapple_point), Color("d4d7e5"), 2.0)
