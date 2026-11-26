extends CharacterBody2D
class_name SilentBladePlayer

signal health_changed(value: float)
signal died
signal guard_changed(value: float, maximum: float)
signal guard_broken
signal parry_succeeded

const SPEED := 300.0
const ACCEL := 1800.0
const JUMP_VELOCITY := -520.0
const GRAVITY := 1350.0
const DASH_SPEED := 760.0
const DASH_TIME := 0.20
const DASH_COOLDOWN := 0.82
const DASH_ACCEL_TIME := 0.065
const DASH_EXIT_SPEED := 420.0
const DASH_EXIT_DURATION := 0.22
const DASH_EXIT_DRAG := 520.0
const MAX_JUMPS := 2
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.15
const JUMP_CUT_MULTIPLIER := 0.48
const JUMP_HOLD_GRAVITY_SCALE := 0.62
const JUMP_HOLD_DURATION := 0.22
const SECOND_JUMP_FLASH_TIME := 0.24
const GRAPPLE_RANGE := 430.0
const GRAPPLE_MIN_ROPE_LENGTH := 90.0
const GRAPPLE_PUMP_ACCEL := 560.0
const GRAPPLE_COLLISION_MASK := 1
const PARRY_WINDOW := 0.18
const COMBO_LINK_WINDOW := 0.85
const COMBO_ATTACKS := [
	{
		"name": "QUICK SLASH",
		"damage": 22.0,
		"active_time": 0.12,
		"cooldown": 0.27,
		"hitbox_size": Vector2(74.0, 34.0),
		"hitbox_offset": Vector2(48.0, -35.0),
		"knockback": 155.0,
		"visual_style": "QUICK"
	},
	{
		"name": "CROSS CUT",
		"damage": 31.0,
		"active_time": 0.16,
		"cooldown": 0.32,
		"hitbox_size": Vector2(88.0, 44.0),
		"hitbox_offset": Vector2(54.0, -41.0),
		"knockback": 245.0,
		"visual_style": "CROSS"
	},
	{
		"name": "HEAVY FINISHER",
		"damage": 48.0,
		"active_time": 0.23,
		"cooldown": 0.50,
		"hitbox_size": Vector2(112.0, 56.0),
		"hitbox_offset": Vector2(65.0, -40.0),
		"knockback": 430.0,
		"visual_style": "FINISHER"
	}
]
const GUARD_MAX := 100.0
const GUARD_REGEN_PER_SECOND := 24.0
const GUARD_DAMAGE_PER_HIT := 34.0
const GUARD_BREAK_DAMAGE_RATIO := 0.67
const GUARD_BREAK_TIME := 1.35
const COUNTER_WINDOW := 1.1

var health := 100.0
var facing := 1
var crouching := false
var attacking := false
var attack_timer := 0.0
var attack_cooldown := 0.0
var attack_active := false
var current_attack_damage := 22.0
var current_attack_knockback := 155.0
var current_attack_index := -1
var current_attack_name := ""
var current_attack_visual_style := "QUICK"
var current_attack_hitbox_size := Vector2(74.0, 34.0)
var current_attack_hitbox_offset := Vector2(48.0, -35.0)
var combo_step := 0
var combo_timer := 0.0
var attack_hitbox: Area2D
var attack_shape: CollisionShape2D
var attack_rect: RectangleShape2D
var hit_ids_this_swing: Dictionary = {}
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_elapsed := 0.0
var dash_direction := 1
var dash_start_velocity := 0.0
var dash_exit_timer := 0.0
var jump_count := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var jump_hold_timer := 0.0
var second_jump_flash_timer := 0.0
var grapple_point: Vector2 = Vector2.ZERO
var grappling := false
var rope_length := 0.0
var anchors: Array[Vector2] = []
var invuln := 0.0

var block_held := false
var parry_timer := 0.0
var guard_stamina := GUARD_MAX
var guard_break_timer := 0.0
var counter_window_timer := 0.0
var parry_flash_timer := 0.0
var block_flash_timer := 0.0
var guard_is_broken := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 17.0
	capsule.height = 58.0
	shape.shape = capsule
	shape.position = Vector2(0, -30)
	add_child(shape)
	_create_attack_hitbox()
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(48.0)
	guard_changed.emit(guard_stamina, GUARD_MAX)

func _create_attack_hitbox() -> void:
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 2
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	attack_hitbox.position = Vector2(48, -36)
	attack_shape = CollisionShape2D.new()
	attack_shape.name = "AttackShape"
	attack_rect = RectangleShape2D.new()
	attack_rect.size = current_attack_hitbox_size
	attack_shape.shape = attack_rect
	attack_hitbox.add_child(attack_shape)
	attack_hitbox.body_entered.connect(_on_attack_body_entered)
	add_child(attack_hitbox)

func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	second_jump_flash_timer = maxf(0.0, second_jump_flash_timer - delta)
	if combo_timer <= 0.0 and not attack_active:
		combo_step = 0
	attacking = attack_timer > 0.0
	if attack_active and attack_timer <= 0.0:
		_end_attack()
	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if dash_exit_timer > 0.0:
		dash_exit_timer = maxf(0.0, dash_exit_timer - delta)
	_update_defense(delta)
	_update_jump_timers(delta)

	if Input.is_action_just_pressed("block"):
		begin_block()
	if Input.is_action_just_released("block"):
		end_block()
	if Input.is_action_just_pressed("attack"):
		start_attack()
	if Input.is_action_just_pressed("crouch"):
		crouching = true
	if Input.is_action_just_released("crouch"):
		crouching = false
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER
		jump_hold_timer = 0.0

	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) > 0.1:
		facing = 1 if axis > 0.0 else -1
		_update_attack_facing()

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and not block_held and not guard_is_broken and health > 0.0:
		_start_dash(axis)
	if Input.is_action_just_pressed("grapple"):
		_toggle_grapple()

	_try_consume_jump_buffer()
	if dash_timer > 0.0:
		_update_dash(delta)
	else:
		if grappling:
			_apply_grapple_control(delta, axis)
		else:
			var target_speed := axis * (SPEED * (0.48 if crouching else 1.0))
			var horizontal_accel := ACCEL
			if dash_exit_timer > 0.0:
				horizontal_accel = DASH_EXIT_DRAG
			velocity.x = move_toward(velocity.x, target_speed, horizontal_accel * delta)
		if not is_on_floor() or velocity.y < 0.0:
			var gravity_scale := 1.0
			if velocity.y < 0.0 and jump_hold_timer > 0.0 and Input.is_action_pressed("jump"):
				gravity_scale = JUMP_HOLD_GRAVITY_SCALE
			velocity.y += GRAVITY * gravity_scale * delta
		else:
			jump_hold_timer = 0.0
		jump_hold_timer = maxf(0.0, jump_hold_timer - delta)

	move_and_slide()
	if grappling:
		_constrain_rope_after_motion()
		if grappling and not _has_clear_grapple_line(grapple_point):
			_detach_grapple()
	if is_on_floor() and velocity.y >= 0.0:
		jump_count = 0
		coyote_timer = COYOTE_TIME
		if jump_buffer_timer > 0.0:
			_try_consume_jump_buffer()
	queue_redraw()

func _update_jump_timers(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	if is_on_floor() and velocity.y >= 0.0:
		jump_count = 0
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

func _try_consume_jump_buffer() -> bool:
	if jump_buffer_timer <= 0.0 or block_held or dash_timer > 0.0 or guard_is_broken:
		return false
	if (is_on_floor() and velocity.y >= 0.0) or (jump_count == 0 and coyote_timer > 0.0):
		jump_count = 1
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		jump_hold_timer = JUMP_HOLD_DURATION
		if grappling:
			_detach_grapple()
		return true
	if jump_count < MAX_JUMPS and jump_count == 1:
		jump_count += 1
		velocity.y = JUMP_VELOCITY * 0.94
		jump_buffer_timer = 0.0
		jump_hold_timer = JUMP_HOLD_DURATION
		if grappling:
			_detach_grapple()
		_play_second_jump_effect()
		return true
	return false

func _play_second_jump_effect() -> void:
	second_jump_flash_timer = SECOND_JUMP_FLASH_TIME

func _start_dash(axis: float) -> void:
	dash_direction = (1 if axis > 0.1 else (-1 if axis < -0.1 else facing))
	if grappling:
		_detach_grapple()
	dash_start_velocity = velocity.x
	dash_elapsed = 0.0
	dash_timer = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	dash_exit_timer = 0.0

func _update_dash(delta: float) -> void:
	dash_elapsed += delta
	dash_timer = maxf(0.0, dash_timer - delta)
	var ramp := clampf(dash_elapsed / DASH_ACCEL_TIME, 0.0, 1.0)
	var eased_ramp := ramp * ramp * (3.0 - 2.0 * ramp)
	velocity.x = lerpf(dash_start_velocity, float(dash_direction) * DASH_SPEED, eased_ramp)
	velocity.y = move_toward(velocity.y, 0.0, GRAVITY * 1.8 * delta)
	if dash_timer <= 0.0:
		velocity.x = float(dash_direction) * DASH_EXIT_SPEED
		dash_exit_timer = DASH_EXIT_DURATION

func _update_attack_facing() -> void:
	if attack_hitbox:
		attack_hitbox.position.x = absf(current_attack_hitbox_offset.x) * facing

func start_attack() -> void:
	if attack_cooldown > 0.0 or attack_active or block_held or guard_is_broken or dash_timer > 0.0:
		return
	current_attack_index = combo_step
	var profile: Dictionary = COMBO_ATTACKS[current_attack_index]
	current_attack_name = String(profile["name"])
	current_attack_damage = float(profile["damage"])
	current_attack_knockback = float(profile["knockback"])
	current_attack_visual_style = String(profile["visual_style"])
	current_attack_hitbox_size = profile["hitbox_size"]
	current_attack_hitbox_offset = profile["hitbox_offset"]
	attack_timer = float(profile["active_time"])
	attack_cooldown = float(profile["cooldown"])
	combo_step = (current_attack_index + 1) % COMBO_ATTACKS.size()
	combo_timer = COMBO_LINK_WINDOW
	if counter_window_timer > 0.0:
		current_attack_damage *= 1.5
		counter_window_timer = 0.0
	attacking = true
	attack_active = true
	hit_ids_this_swing.clear()
	attack_rect.size = current_attack_hitbox_size
	attack_hitbox.position = Vector2(absf(current_attack_hitbox_offset.x) * facing, current_attack_hitbox_offset.y)
	attack_hitbox.set_deferred("monitoring", true)
	# Catch a target already overlapping at the instant the area becomes active.
	call_deferred("_scan_attack_overlaps")

func _scan_attack_overlaps() -> void:
	if not attack_active or not is_instance_valid(attack_hitbox):
		return
	for body in attack_hitbox.get_overlapping_bodies():
		_register_attack_target(body)

func _on_attack_body_entered(body: Node2D) -> void:
	_register_attack_target(body)

func _register_attack_target(body: Node) -> void:
	if not attack_active or not is_instance_valid(body) or not body.has_method("receive_damage"):
		return
	var target_id := body.get_instance_id()
	if hit_ids_this_swing.has(target_id):
		return
	var direction_to_target := signf(body.global_position.x - global_position.x)
	if direction_to_target == 0.0 or int(direction_to_target) != facing:
		return
	hit_ids_this_swing[target_id] = true
	body.call("receive_damage", current_attack_damage, global_position, current_attack_knockback)

func _end_attack() -> void:
	attack_active = false
	attacking = false
	attack_hitbox.set_deferred("monitoring", false)

func begin_block() -> void:
	if guard_is_broken or block_held:
		return
	block_held = true
	parry_timer = PARRY_WINDOW
	block_flash_timer = 0.0

func end_block() -> void:
	block_held = false
	parry_timer = 0.0

func _update_defense(delta: float) -> void:
	parry_timer = maxf(0.0, parry_timer - delta)
	counter_window_timer = maxf(0.0, counter_window_timer - delta)
	parry_flash_timer = maxf(0.0, parry_flash_timer - delta)
	block_flash_timer = maxf(0.0, block_flash_timer - delta)
	if guard_is_broken:
		guard_break_timer = maxf(0.0, guard_break_timer - delta)
		if guard_break_timer <= 0.0:
			guard_is_broken = false
			guard_stamina = GUARD_MAX * 0.35
			guard_changed.emit(guard_stamina, GUARD_MAX)
	elif not block_held and guard_stamina < GUARD_MAX:
		var previous := guard_stamina
		guard_stamina = minf(GUARD_MAX, guard_stamina + GUARD_REGEN_PER_SECOND * delta)
		if not is_equal_approx(previous, guard_stamina):
			guard_changed.emit(guard_stamina, GUARD_MAX)

func _faces_attacker(attacker: Node2D) -> bool:
	var side := signf(attacker.global_position.x - global_position.x)
	return side != 0.0 and int(side) == facing

func try_parry(attacker: Node2D) -> bool:
	if not block_held or parry_timer <= 0.0 or guard_is_broken or not _faces_attacker(attacker):
		return false
	if attacker.has_method("interrupt_attack"):
		attacker.interrupt_attack()
	counter_window_timer = COUNTER_WINDOW
	parry_flash_timer = 0.32
	parry_succeeded.emit()
	return true

func receive_enemy_attack(attacker: Node2D) -> String:
	var incoming_damage := 18.0
	if attacker.has_method("get_attack_damage"):
		incoming_damage = float(attacker.call("get_attack_damage"))
	if try_parry(attacker):
		return "PARRIED"
	if block_held and not guard_is_broken and _faces_attacker(attacker):
		guard_stamina = maxf(0.0, guard_stamina - GUARD_DAMAGE_PER_HIT)
		guard_changed.emit(guard_stamina, GUARD_MAX)
		block_flash_timer = 0.2
		if guard_stamina <= 0.0:
			_break_guard()
			take_damage(incoming_damage * GUARD_BREAK_DAMAGE_RATIO)
			return "GUARD_BROKEN"
		return "BLOCKED"
	take_damage(incoming_damage)
	return "HIT"

func receive_blocked_hit(_attacker: Node2D) -> void:
	# Public combat hook retained for future enemy attack types.
	pass

func _break_guard() -> void:
	guard_is_broken = true
	block_held = false
	parry_timer = 0.0
	guard_break_timer = GUARD_BREAK_TIME
	guard_broken.emit()

func release_controls() -> void:
	crouching = false
	_detach_grapple()
	dash_timer = 0.0
	dash_exit_timer = 0.0
	jump_buffer_timer = 0.0
	jump_hold_timer = 0.0
	attack_timer = 0.0
	attacking = false
	_end_attack()
	end_block()
	velocity.x = 0.0

func _toggle_grapple() -> void:
	if grappling:
		_detach_grapple()
		return
	var best := GRAPPLE_RANGE
	var chosen := Vector2.ZERO
	for point in anchors:
		var d := global_position.distance_to(point)
		if d < best and (point.x - global_position.x) * facing > -80.0:
			if _has_clear_grapple_line(point):
				best = d
				chosen = point
	if chosen != Vector2.ZERO:
		grapple_point = chosen
		# Start at the current distance. Never shorten the rope on attach or snap the player.
		rope_length = maxf(GRAPPLE_MIN_ROPE_LENGTH, best)
		grappling = true

func _has_clear_grapple_line(point: Vector2) -> bool:
	var ray_origin := global_position + Vector2(0.0, -30.0)
	var query := PhysicsRayQueryParameters2D.create(ray_origin, point, GRAPPLE_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()

func _apply_grapple_control(delta: float, axis: float) -> void:
	var offset := global_position - grapple_point
	var distance := offset.length()
	if distance < 0.001:
		return
	var radial := offset / distance
	var tangent := Vector2(-radial.y, radial.x)
	if not is_zero_approx(axis):
		if tangent.dot(Vector2(axis, 0.0)) < 0.0:
			tangent = -tangent
		velocity += tangent * (absf(axis) * GRAPPLE_PUMP_ACCEL * delta)

func _constrain_rope_after_motion() -> void:
	var offset := global_position - grapple_point
	var distance := offset.length()
	if distance <= rope_length or distance < 0.001:
		return
	var radial := offset / distance
	var excess := distance - rope_length
	# Resolve only the small post-physics excess through the body's collision solver.
	# This preserves platform/wall collisions and avoids teleporting global_position.
	move_and_collide(-radial * excess)
	var outward_speed := velocity.dot(radial)
	if outward_speed > 0.0:
		velocity -= radial * outward_speed

func _detach_grapple() -> void:
	# Intentionally leave velocity untouched so tangential momentum survives release.
	grappling = false

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
	if parry_flash_timer > 0.0:
		body_color = Color("ffd36a")
	elif block_flash_timer > 0.0:
		body_color = Color("8bbcff")
	draw_rect(Rect2(-16, -12, 13, 12), Color("171a2a"))
	draw_rect(Rect2(3, -12, 14, 12), Color("171a2a"))
	draw_rect(Rect2(-13, -49 if not crouching else -38, 27, 38 if not crouching else 27), body_color)
	draw_rect(Rect2(-11, -66 if not crouching else -55, 23, 20), Color("20263c"))
	draw_rect(Rect2(-9, -61 if not crouching else -50, 19, 8), Color("090d19"))
	draw_rect(Rect2(2 if facing > 0 else -9, -57 if not crouching else -46, 8, 3), Color("e8e9f5"))
	var scarf := PackedVector2Array([Vector2(-8 * facing, -47), Vector2(-30 * facing, -40), Vector2(-48 * facing, -27), Vector2(-26 * facing, -35)])
	draw_colored_polygon(scarf, Color("a71936"))
	draw_line(Vector2(-5 * facing, -47), Vector2(-38 * facing, -40), Color("e43b52"), 3.0)
	if second_jump_flash_timer > 0.0:
		var effect_progress := second_jump_flash_timer / SECOND_JUMP_FLASH_TIME
		var effect_alpha := clampf(effect_progress, 0.0, 1.0)
		draw_arc(Vector2(0, -28), 31.0 + (1.0 - effect_progress) * 24.0, 0.0, TAU, 24, Color(0.48, 0.88, 1.0, effect_alpha), 3.0)
		draw_line(Vector2(-22, -10), Vector2(-38, 8), Color(0.66, 0.93, 1.0, effect_alpha), 3.0)
		draw_line(Vector2(22, -10), Vector2(38, 8), Color(0.66, 0.93, 1.0, effect_alpha), 3.0)
	if attacking:
		var start := Vector2(13 * facing, -36)
		match current_attack_visual_style:
			"QUICK":
				# Strike 1: fast diagonal cut with a narrow pale trail.
				draw_line(start, Vector2(68 * facing, -68), Color("f4e7e4"), 4.0)
				draw_arc(start, 48, deg_to_rad(-72 if facing > 0 else 188), deg_to_rad(12 if facing > 0 else 282), 12, Color("dce6ff"), 3.0)
			"CROSS":
				# Strike 2: broad cross-cut, drawn as two crossing streaks.
				draw_line(Vector2(8 * facing, -64), Vector2(73 * facing, -20), Color("ffcf88"), 6.0)
				draw_line(Vector2(14 * facing, -18), Vector2(68 * facing, -66), Color("f4e7e4"), 3.0)
			"FINISHER":
				# Strike 3: heavy finisher with a wide bright arc and impact flare.
				draw_arc(Vector2(18 * facing, -38), 76, deg_to_rad(-82 if facing > 0 else 188), deg_to_rad(72 if facing > 0 else 352), 20, Color("ff6b76"), 9.0)
				draw_line(start, Vector2(100 * facing, -42), Color("fff0d0"), 8.0)
				draw_circle(Vector2(86 * facing, -42), 8.0, Color("ffd36a"))
	if block_held and not guard_is_broken:
		draw_arc(Vector2(18 * facing, -38), 43, deg_to_rad(-75 if facing > 0 else 195), deg_to_rad(75 if facing > 0 else 345), 18, Color("83baff"), 4.0)
	if grappling:
		draw_line(Vector2(0, -48), to_local(grapple_point), Color("d4d7e5"), 2.0)
