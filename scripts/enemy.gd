extends CharacterBody2D
class_name SilentBladeEnemy

signal player_spotted
signal attack_started
signal attack_resolved(result: String)
signal parried
signal died(enemy_type: String)

const TELEGRAPH_DEFAULT := 0.58
const ATTACK_ACTIVE_DEFAULT := 0.18
const RECOVERY_DEFAULT := 0.82
const STAGGER_TIME := 0.72
const KNOCKBACK_MIN_TIME := 0.18
const KNOCKBACK_MAX_TIME := 0.78

# Each named enemy is a complete runtime profile, not a cosmetic label.
const ENEMY_PROFILES := {
	"Guard": {
		"health": 65.0,
		"movement_speed": 82.0,
		"attack_damage": 18.0,
		"attack_cooldown": 1.20,
		"telegraph_time": 0.58,
		"attack_active_time": 0.18,
		"recovery_time": 0.82,
		"knockback_resistance": 1.0,
		"attack_range": 112.0,
		"aggro_range": 300.0,
		"collision_radius": 15.0,
		"collision_height": 54.0
	},
	"Scout": {
		"health": 42.0,
		"movement_speed": 145.0,
		"attack_damage": 12.0,
		"attack_cooldown": 0.72,
		"telegraph_time": 0.32,
		"attack_active_time": 0.13,
		"recovery_time": 0.48,
		"knockback_resistance": 0.55,
		"attack_range": 92.0,
		"aggro_range": 360.0,
		"collision_radius": 12.0,
		"collision_height": 48.0
	},
	"Heavy Guard": {
		"health": 145.0,
		"movement_speed": 48.0,
		"attack_damage": 32.0,
		"attack_cooldown": 1.50,
		"telegraph_time": 0.90,
		"attack_active_time": 0.24,
		"recovery_time": 1.15,
		"knockback_resistance": 2.25,
		"attack_range": 132.0,
		"aggro_range": 270.0,
		"collision_radius": 21.0,
		"collision_height": 66.0
	}
}

@export_enum("Guard", "Scout", "Heavy Guard") var enemy_type := "Guard"

var left_limit := 650.0
var right_limit := 1050.0
var direction := -1
var speed := 82.0
var alert := 0.0
var state := "PATROL"
var health := 65.0
var max_health := 65.0
var attack_damage := 18.0
var attack_cooldown_duration := 1.20
var telegraph_duration := TELEGRAPH_DEFAULT
var attack_active_duration := ATTACK_ACTIVE_DEFAULT
var recovery_duration := RECOVERY_DEFAULT
var knockback_resistance := 1.0
var attack_range := 112.0
var aggro_range := 300.0
var target: SilentBladePlayer
var phase_timer := 0.0
var attack_cooldown := 0.0
var attack_facing := -1
var attack_serial := 0
var current_attack_resolved := false
var is_dead := false
var knockback_timer := 0.0
var body_shape: CollisionShape2D
var hit_flash_timer := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_apply_enemy_profile()
	body_shape = CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = float(ENEMY_PROFILES[enemy_type]["collision_radius"])
	capsule.height = float(ENEMY_PROFILES[enemy_type]["collision_height"])
	body_shape.shape = capsule
	body_shape.position.y = -capsule.height * 0.5
	add_child(body_shape)
	queue_redraw()

func _apply_enemy_profile() -> void:
	if not ENEMY_PROFILES.has(enemy_type):
		enemy_type = "Guard"
	var profile: Dictionary = ENEMY_PROFILES[enemy_type]
	max_health = float(profile["health"])
	health = max_health
	speed = float(profile["movement_speed"])
	attack_damage = float(profile["attack_damage"])
	attack_cooldown_duration = float(profile["attack_cooldown"])
	telegraph_duration = float(profile["telegraph_time"])
	attack_active_duration = float(profile["attack_active_time"])
	recovery_duration = float(profile["recovery_time"])
	knockback_resistance = float(profile["knockback_resistance"])
	attack_range = float(profile["attack_range"])
	aggro_range = float(profile["aggro_range"])

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.y += 1200.0 * delta
		move_and_slide()
		return

	var dx := target.global_position.x - global_position.x
	var dy := absf(target.global_position.y - global_position.y)
	var facing_player := signf(dx) == direction
	var visible := facing_player and absf(dx) < aggro_range and dy < 100.0 and not target.crouching
	if visible:
		alert = minf(1.0, alert + delta * 0.75)
	else:
		alert = maxf(0.0, alert - delta * 0.22)
	if alert >= 1.0 and state in ["PATROL", "SUSPICIOUS", "ALERT"]:
		state = "ALERT"
		player_spotted.emit()
	elif alert > 0.15 and state in ["PATROL", "SUSPICIOUS", "ALERT"]:
		state = "SUSPICIOUS"
	elif state in ["PATROL", "SUSPICIOUS", "ALERT"]:
		state = "PATROL"

	match state:
		"TELEGRAPH":
			velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
			phase_timer -= delta
			if phase_timer <= 0.0:
				_begin_attack()
		"ATTACK":
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			phase_timer -= delta
			if not current_attack_resolved:
				current_attack_resolved = true
				var in_forward_arc := absf(dx) <= attack_range + 24.0 and dy < 82.0 and int(signf(dx)) == attack_facing
				if in_forward_arc:
					var result := target.receive_enemy_attack(self)
					attack_resolved.emit(result)
			if phase_timer <= 0.0 and state == "ATTACK":
				state = "RECOVERY"
				phase_timer = recovery_duration
		"RECOVERY", "STAGGER":
			velocity.x = move_toward(velocity.x, 0.0, 1150.0 * delta)
			phase_timer -= delta
			if phase_timer <= 0.0:
				state = "ALERT" if alert >= 1.0 else "PATROL"
		"KNOCKBACK":
			knockback_timer = maxf(0.0, knockback_timer - delta)
			velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
			if knockback_timer <= 0.0:
				state = "ALERT" if alert >= 1.0 else "PATROL"
		"ALERT":
			direction = 1 if dx > 0.0 else -1
			if absf(dx) <= attack_range and dy < 82.0 and attack_cooldown <= 0.0:
				_begin_telegraph()
			else:
				velocity.x = direction * speed * 1.35 if absf(dx) > attack_range * 0.78 else 0.0
		"PATROL", "SUSPICIOUS":
			velocity.x = direction * speed
			if global_position.x < left_limit:
				direction = 1
			elif global_position.x > right_limit:
				direction = -1

	velocity.y += 1200.0 * delta
	move_and_slide()
	queue_redraw()

func _begin_telegraph() -> void:
	state = "TELEGRAPH"
	phase_timer = telegraph_duration
	attack_facing = 1 if target.global_position.x > global_position.x else -1
	direction = attack_facing
	attack_cooldown = attack_cooldown_duration
	current_attack_resolved = false
	attack_serial += 1

func _begin_attack() -> void:
	state = "ATTACK"
	phase_timer = attack_active_duration
	current_attack_resolved = false
	attack_started.emit()

func interrupt_attack() -> void:
	if state != "ATTACK" and state != "TELEGRAPH":
		return
	state = "STAGGER"
	phase_timer = STAGGER_TIME
	current_attack_resolved = true
	velocity.x = 0.0
	parried.emit()

func get_attack_damage() -> float:
	return attack_damage

func receive_damage(amount: float, source_position: Vector2, knockback_force: float) -> void:
	if is_dead:
		return
	var final_damage := maxf(0.0, amount)
	if state == "STAGGER":
		final_damage *= 1.20
	health = maxf(0.0, health - final_damage)
	hit_flash_timer = 0.16
	if health <= 0.0:
		_die()
		return

	var away := global_position.x - source_position.x
	var knockback_direction := signf(away)
	if is_zero_approx(knockback_direction):
		knockback_direction = 1.0
	var knockback_force_applied := minf(maxf(0.0, knockback_force) / maxf(0.1, knockback_resistance), 520.0)
	velocity.x = knockback_direction * knockback_force_applied
	velocity.y = minf(velocity.y, -78.0)
	knockback_timer = clampf(knockback_force_applied / 760.0 + 0.08, KNOCKBACK_MIN_TIME, KNOCKBACK_MAX_TIME)
	state = "KNOCKBACK"
	phase_timer = knockback_timer
	current_attack_resolved = true
	queue_redraw()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	state = "DEAD"
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(body_shape):
		body_shape.set_deferred("disabled", true)
	died.emit(enemy_type)
	queue_free()

func _draw() -> void:
	var body_color := Color("20283a")
	var armor_color := Color("41495b")
	match enemy_type:
		"Scout":
			body_color = Color("16333a")
			armor_color = Color("31737a")
		"Heavy Guard":
			body_color = Color("321f2b")
			armor_color = Color("67404a")
	if hit_flash_timer > 0.0:
		body_color = Color("f5d5d5")
	var body_width := 26.0
	var body_top := -49.0
	var body_height := 39.0
	if enemy_type == "Scout":
		body_width = 22.0
		body_top = -45.0
		body_height = 34.0
	elif enemy_type == "Heavy Guard":
		body_width = 38.0
		body_top = -59.0
		body_height = 49.0
	draw_rect(Rect2(-body_width * 0.5, body_top, body_width, body_height), body_color)
	draw_rect(Rect2(-body_width * 0.5 - 2.0, body_top - 10.0, body_width + 4.0, 16.0), armor_color)
	draw_rect(Rect2(-body_width * 0.5, -10.0, body_width * 0.34, 10.0), Color("0d1220"))
	draw_rect(Rect2(body_width * 0.12, -10.0, body_width * 0.34, 10.0), Color("0d1220"))
	if enemy_type == "Heavy Guard":
		draw_rect(Rect2(-direction * 25.0 - 9.0, -52.0, 18.0, 47.0), Color("8c5961"))
		draw_line(Vector2(-direction * 25.0 - 9.0, -52.0), Vector2(-direction * 25.0 + 9.0, -5.0), Color("c18a72"), 3.0)
	elif enemy_type == "Scout":
		draw_line(Vector2(-5.0 * direction, -38.0), Vector2(-28.0 * direction, -27.0), Color("62c1bd"), 4.0)
	else:
		draw_rect(Rect2(-7.0, -55.0, 14.0, 3.0), Color("e4d6bd"))

	if state == "TELEGRAPH":
		draw_circle(Vector2(0, body_top - 22.0), 9.0, Color("ffc45c"))
		draw_arc(Vector2(0, -37), attack_range * 0.34, deg_to_rad(-55 if attack_facing > 0 else 195), deg_to_rad(55 if attack_facing > 0 else 305), 14, Color("ffc45c"), 4.0)
	elif state == "ATTACK":
		draw_line(Vector2(attack_facing * 8, -40), Vector2(attack_facing * (attack_range * 0.78), -49), Color("ff4d5f"), 8.0)
		draw_circle(Vector2(attack_facing * (attack_range * 0.72), -49), 7, Color("ff9b75"))
	elif state == "STAGGER":
		draw_circle(Vector2(0, body_top - 20.0), 8, Color("8bd7ff"))
	elif state == "ALERT":
		draw_circle(Vector2(0, body_top - 20.0), 5, Color("ff4054"))
	elif state == "SUSPICIOUS":
		draw_circle(Vector2(0, body_top - 20.0), 5, Color("ffc65a"))

	var cone := PackedVector2Array([Vector2(0, -53), Vector2(direction * aggro_range, -112), Vector2(direction * aggro_range, -5)])
	draw_colored_polygon(cone, Color(1.0, 0.22, 0.28, 0.10 if state == "PATROL" else 0.19))
