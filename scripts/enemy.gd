extends CharacterBody2D
class_name SilentBladeEnemy

signal player_spotted
signal attack_started
signal attack_resolved(result: String)
signal parried
signal died(enemy_type: String)
signal ai_state_changed(state_name: String)
signal detection_changed(value: float, stage: String)

const VisionSystemScript = preload("res://scripts/ai/vision_system.gd")
const DetectionSystemScript = preload("res://scripts/ai/detection_system.gd")
const EnemyAIScript = preload("res://scripts/ai/enemy_ai.gd")
const TELEGRAPH_DEFAULT := 0.58
const ATTACK_ACTIVE_DEFAULT := 0.18
const RECOVERY_DEFAULT := 0.82
const STAGGER_TIME := 0.72
const KNOCKBACK_MIN_TIME := 0.18
const KNOCKBACK_MAX_TIME := 0.78
const FALL_LIMIT_Y := 1200.0
const VISION_COLLISION_MASK := 1
const LOST_SIGHT_GRACE := 0.82
const NOISE_MIN_STRENGTH := 0.055

# Combat and stealth traits are all runtime profile data; every archetype has a different
# perception/response model in addition to its original combat profile.
const ENEMY_PROFILES := {
	"Guard": {
		"health": 65.0, "movement_speed": 82.0, "attack_damage": 18.0,
		"attack_cooldown": 1.20, "telegraph_time": 0.58, "attack_active_time": 0.18,
		"recovery_time": 0.82, "knockback_resistance": 1.0, "attack_range": 112.0,
		"aggro_range": 300.0, "collision_radius": 15.0, "collision_height": 54.0,
		"vision_range": 430.0, "vision_angle": 82.0, "hearing_sensitivity": 1.0,
		"reaction_speed": 0.72, "search_time": 3.2, "suspicion_time": 1.8,
		"detection_rate": 0.68, "vision_interval": 0.14, "chase_multiplier": 1.32,
		"investigate_multiplier": 0.92, "search_radius": 86.0
	},
	"Scout": {
		"health": 42.0, "movement_speed": 145.0, "attack_damage": 12.0,
		"attack_cooldown": 0.72, "telegraph_time": 0.32, "attack_active_time": 0.13,
		"recovery_time": 0.48, "knockback_resistance": 0.55, "attack_range": 92.0,
		"aggro_range": 360.0, "collision_radius": 12.0, "collision_height": 48.0,
		"vision_range": 520.0, "vision_angle": 108.0, "hearing_sensitivity": 1.32,
		"reaction_speed": 1.18, "search_time": 2.6, "suspicion_time": 1.15,
		"detection_rate": 0.92, "vision_interval": 0.10, "chase_multiplier": 1.48,
		"investigate_multiplier": 1.12, "search_radius": 118.0
	},
	"Heavy Guard": {
		"health": 145.0, "movement_speed": 48.0, "attack_damage": 32.0,
		"attack_cooldown": 1.50, "telegraph_time": 0.90, "attack_active_time": 0.24,
		"recovery_time": 1.15, "knockback_resistance": 2.25, "attack_range": 132.0,
		"aggro_range": 270.0, "collision_radius": 21.0, "collision_height": 66.0,
		"vision_range": 370.0, "vision_angle": 72.0, "hearing_sensitivity": 0.78,
		"reaction_speed": 0.48, "search_time": 4.4, "suspicion_time": 2.5,
		"detection_rate": 0.48, "vision_interval": 0.18, "chase_multiplier": 1.18,
		"investigate_multiplier": 0.78, "search_radius": 72.0
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
var vision_range := 430.0
var vision_angle := 82.0
var hearing_sensitivity := 1.0
var reaction_speed := 0.72
var search_duration := 3.2
var suspicion_duration := 1.8
var detection_rate := 0.68
var vision_interval := 0.14
var chase_multiplier := 1.32
var investigate_multiplier := 0.92
var search_radius := 86.0
var target: SilentBladePlayer
var noise_system: SilentBladeNoiseSystem
var stealth_system: SilentBladeStealthSystem
var phase_timer := 0.0
var attack_phase := ""
var attack_cooldown := 0.0
var attack_facing := -1
var attack_serial := 0
var current_attack_resolved := false
var is_dead := false
var knockback_timer := 0.0
var body_shape: CollisionShape2D
var hit_flash_timer := 0.0
var detection_meter := 0.0
var detection_stage := "HIDDEN"
var is_player_visible := false
var last_known_player_position := Vector2.ZERO
var has_last_known_position := false
var investigate_position := Vector2.ZERO
var has_investigation_position := false
var search_center_position := Vector2.ZERO
var home_x := 0.0
var state_timer := 0.0
var search_timer := 0.0
var lost_sight_timer := 0.0
var vision_accumulator := 0.0
var search_direction := 1
var search_turn_timer := 0.0
var last_noise_type := ""
var _vision_system: SilentBladeVisionSystem
var _detection_system: SilentBladeDetectionSystem
var _ai_controller: SilentBladeEnemyAI

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	home_x = global_position.x
	_apply_enemy_profile()
	_vision_system = VisionSystemScript.new()
	_detection_system = DetectionSystemScript.new()
	_ai_controller = EnemyAIScript.new()
	body_shape = CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = float(ENEMY_PROFILES[enemy_type]["collision_radius"])
	capsule.height = float(ENEMY_PROFILES[enemy_type]["collision_height"])
	body_shape.shape = capsule
	body_shape.position.y = -capsule.height * 0.5
	add_child(body_shape)
	if is_instance_valid(noise_system) and noise_system.has_signal("noise_emitted"):
		noise_system.noise_emitted.connect(on_noise_event)
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
	vision_range = float(profile["vision_range"])
	vision_angle = float(profile["vision_angle"])
	hearing_sensitivity = float(profile["hearing_sensitivity"])
	reaction_speed = float(profile["reaction_speed"])
	search_duration = float(profile["search_time"])
	suspicion_duration = float(profile["suspicion_time"])
	detection_rate = float(profile["detection_rate"])
	vision_interval = float(profile["vision_interval"])
	chase_multiplier = float(profile["chase_multiplier"])
	investigate_multiplier = float(profile["investigate_multiplier"])
	search_radius = float(profile["search_radius"])

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if global_position.y > FALL_LIMIT_Y:
		is_dead = true
		queue_free()
		return
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_update_perception(delta)

	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.y += 1200.0 * delta
		move_and_slide()
		return

	var dx := target.global_position.x - global_position.x
	var dy := absf(target.global_position.y - global_position.y)
	match state:
		"PATROL":
			velocity.x = direction * speed
			if global_position.x < left_limit:
				direction = 1
			elif global_position.x > right_limit:
				direction = -1
		"ALERT":
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			var look_point: Vector2 = target.global_position if is_player_visible else investigate_position
			direction = 1 if look_point.x >= global_position.x else -1
			state_timer -= delta
			if state_timer <= 0.0:
				_set_ai_state("INVESTIGATE")
				state_timer = suspicion_duration
		"INVESTIGATE":
			var investigate_dx := investigate_position.x - global_position.x
			if absf(investigate_dx) > 26.0:
				direction = 1 if investigate_dx > 0.0 else -1
				velocity.x = direction * speed * investigate_multiplier
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
				_begin_search(investigate_position)
		"CHASE":
			var chase_point := target.global_position if is_player_visible else last_known_player_position
			var chase_dx := chase_point.x - global_position.x
			if absf(chase_dx) <= attack_range and dy < 82.0 and is_player_visible and attack_cooldown <= 0.0:
				_begin_telegraph()
			else:
				direction = 1 if chase_dx >= 0.0 else -1
				velocity.x = direction * speed * chase_multiplier if absf(chase_dx) > attack_range * 0.78 else move_toward(velocity.x, 0.0, 1000.0 * delta)
		"SEARCH":
			search_timer = maxf(0.0, search_timer - delta)
			var search_center := search_center_position
			var offset := global_position.x - search_center.x
			search_turn_timer -= delta
			if absf(offset) > search_radius:
				search_direction = -int(signf(offset))
				search_turn_timer = 0.45
			elif search_turn_timer <= 0.0:
				search_direction = -search_direction
				search_turn_timer = 0.55
			direction = search_direction
			velocity.x = direction * speed * 0.62
			if search_timer <= 0.0:
				_set_ai_state("RETURN")
		"RETURN":
			var return_x := clampf(home_x, left_limit, right_limit)
			var return_dx := return_x - global_position.x
			if absf(return_dx) <= 22.0:
				velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
				direction = -1 if absf(direction) < 0.1 else direction
				_set_ai_state("PATROL")
			else:
				direction = 1 if return_dx > 0.0 else -1
				velocity.x = direction * speed * 0.9
		"ATTACK":
			_update_attack_state(delta, dx, dy)
		"STAGGER":
			velocity.x = move_toward(velocity.x, 0.0, 1150.0 * delta)
			phase_timer -= delta
			if phase_timer <= 0.0:
				_resume_after_stun()
		"KNOCKBACK":
			knockback_timer = maxf(0.0, knockback_timer - delta)
			velocity.x = move_toward(velocity.x, 0.0, 760.0 * delta)
			if knockback_timer <= 0.0:
				_resume_after_stun()

	velocity.y += 1200.0 * delta
	move_and_slide()
	queue_redraw()

func _update_perception(delta: float) -> void:
	vision_accumulator += delta
	if vision_accumulator < vision_interval:
		if state in ["CHASE", "ATTACK"] and not is_player_visible:
			_advance_lost_sight_timer(delta)
		return
	var sample_delta := vision_accumulator
	vision_accumulator = 0.0
	var was_visible := is_player_visible
	var vision: Dictionary = _vision_system.evaluate(self, target, direction, vision_range, vision_angle, VISION_COLLISION_MASK)
	is_player_visible = bool(vision["visible"])
	var exposure := 1.0
	if is_player_visible and is_instance_valid(stealth_system):
		exposure = float(stealth_system.call("get_visibility_multiplier", target))
	var previous_stage := detection_stage
	var update: Dictionary = _detection_system.update(is_player_visible, exposure, sample_delta, detection_rate, 0.30)
	detection_meter = float(update["meter"])
	detection_stage = String(update["stage"])
	alert = detection_meter
	if is_player_visible:
		last_known_player_position = target.global_position
		has_last_known_position = true
		lost_sight_timer = 0.0
		if detection_meter > 0.05 and state in ["PATROL", "RETURN"]:
			investigate_position = target.global_position
			has_investigation_position = true
			_set_ai_state("ALERT")
			state_timer = suspicion_duration / maxf(0.35, reaction_speed)
		if detection_meter >= 0.999 and state != "CHASE" and state != "ATTACK":
			_set_ai_state("CHASE")
			player_spotted.emit()
	else:
		if state in ["CHASE", "ATTACK"]:
			# If this is the first negative sample, account for the full sample interval;
			# otherwise earlier non-sample frames have already advanced the timer.
			_advance_lost_sight_timer(sample_delta if was_visible else delta)
	if previous_stage != detection_stage or sample_delta > 0.0:
		detection_changed.emit(detection_meter, detection_stage)

func _advance_lost_sight_timer(delta: float) -> void:
	lost_sight_timer += delta
	if lost_sight_timer >= LOST_SIGHT_GRACE and state == "CHASE":
		_begin_search(last_known_player_position)

func on_noise_event(event: Dictionary) -> void:
	if is_dead or state == "ATTACK":
		return
	if state == "CHASE" and is_player_visible:
		return
	if not event.has("position") or not event.has("radius") or not event.has("intensity"):
		return
	var event_position: Vector2 = event["position"]
	var event_radius := float(event["radius"])
	var event_intensity := float(event["intensity"])
	var distance := global_position.distance_to(event_position)
	var hearing_range := event_radius * clampf(hearing_sensitivity, 0.5, 1.5)
	if hearing_range <= 0.0 or distance > hearing_range:
		return
	var strength := event_intensity * hearing_sensitivity * (1.0 - distance / hearing_range)
	if strength < NOISE_MIN_STRENGTH:
		return
	# A sound gives only its emission position. It never updates the player's live location.
	# ALERT advances to INVESTIGATE after the profile-specific reaction delay.
	investigate_position = event_position
	has_investigation_position = true
	last_noise_type = String(event.get("event_type", "UNKNOWN"))
	_detection_system.add_suspicion(minf(0.38, strength * 0.42))
	detection_meter = float(_detection_system.meter)
	detection_stage = String(_detection_system.stage)
	var reaction_delay := 0.28 / maxf(0.35, reaction_speed)
	if state not in ["ALERT", "INVESTIGATE"]:
		_set_ai_state("ALERT")
		state_timer = reaction_delay
	elif state == "ALERT":
		# Further nearby sounds may refine the destination, but cannot keep resetting the timer.
		state_timer = minf(state_timer, reaction_delay)
	detection_changed.emit(detection_meter, detection_stage)

func _set_ai_state(next_state: String) -> bool:
	if state == next_state:
		return true
	if not _ai_controller.can_transition(state, next_state):
		return false
	state = next_state
	if next_state == "SEARCH":
		search_timer = search_duration
	elif next_state == "RETURN":
		search_timer = 0.0
	ai_state_changed.emit(state)
	queue_redraw()
	return true

func _begin_search(search_origin: Vector2) -> void:
	# Search the actual last visual/noise location without falsely labelling a sound source as the player.
	search_center_position = search_origin
	investigate_position = search_origin
	_set_ai_state("SEARCH")
	search_timer = search_duration
	search_direction = direction
	search_turn_timer = 0.45

func _resume_after_stun() -> void:
	if is_player_visible and detection_meter >= 0.35:
		_set_ai_state("CHASE")
	elif has_last_known_position:
		_begin_search(last_known_player_position)
	elif has_investigation_position:
		_begin_search(investigate_position)
	else:
		_set_ai_state("PATROL")

func _update_attack_state(delta: float, dx: float, dy: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
	phase_timer -= delta
	match attack_phase:
		"TELEGRAPH":
			if phase_timer <= 0.0:
				_begin_attack()
		"EXECUTE":
			if not current_attack_resolved:
				current_attack_resolved = true
				var in_forward_arc := absf(dx) <= attack_range + 24.0 and dy < 82.0 and int(signf(dx)) == attack_facing
				if in_forward_arc and _has_attack_line_of_sight():
					var result := target.receive_enemy_attack(self)
					attack_resolved.emit(result)
			if phase_timer <= 0.0:
				attack_phase = "RECOVERY"
				phase_timer = recovery_duration
		"RECOVERY":
			if phase_timer <= 0.0:
				attack_phase = ""
				if is_player_visible or detection_meter >= 0.35:
					_set_ai_state("CHASE")
				else:
					_begin_search(last_known_player_position if has_last_known_position else investigate_position)

func _has_attack_line_of_sight() -> bool:
	var result: Dictionary = _vision_system.evaluate(self, target, attack_facing, attack_range + 28.0, 110.0, VISION_COLLISION_MASK)
	return bool(result["visible"])

func _begin_telegraph() -> void:
	_set_ai_state("ATTACK")
	attack_phase = "TELEGRAPH"
	phase_timer = telegraph_duration
	attack_facing = 1 if target.global_position.x > global_position.x else -1
	direction = attack_facing
	attack_cooldown = attack_cooldown_duration
	current_attack_resolved = false
	attack_serial += 1

func _begin_attack() -> void:
	attack_phase = "EXECUTE"
	phase_timer = attack_active_duration
	current_attack_resolved = false
	attack_started.emit()

func interrupt_attack() -> void:
	if state != "ATTACK":
		return
	attack_phase = ""
	_set_ai_state("STAGGER")
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
	attack_phase = ""
	if not _set_ai_state("KNOCKBACK"):
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

	var state_color := Color("8bbd8a")
	match state:
		"ALERT": state_color = Color("ffc45c")
		"INVESTIGATE": state_color = Color("f1a94b")
		"CHASE", "ATTACK": state_color = Color("ff4054")
		"SEARCH": state_color = Color("c18bff")
		"RETURN": state_color = Color("80b6d8")
		"STAGGER": state_color = Color("8bd7ff")
	draw_circle(Vector2(0, body_top - 21.0), 6.0, state_color)
	if detection_meter > 0.01:
		draw_rect(Rect2(-22.0, body_top - 36.0, 44.0, 5.0), Color(0.05, 0.06, 0.09, 0.8))
		draw_rect(Rect2(-22.0, body_top - 36.0, 44.0 * detection_meter, 5.0), Color("ff5c63" if detection_meter > 0.75 else "ffc45c"))
	if state == "ATTACK":
		if attack_phase == "TELEGRAPH":
			draw_arc(Vector2(0, -37), attack_range * 0.34, deg_to_rad(-55 if attack_facing > 0 else 195), deg_to_rad(55 if attack_facing > 0 else 305), 14, Color("ffc45c"), 4.0)
		elif attack_phase == "EXECUTE":
			draw_line(Vector2(attack_facing * 8, -40), Vector2(attack_facing * (attack_range * 0.78), -49), Color("ff4d5f"), 8.0)
	var cone := PackedVector2Array([Vector2(0.0, -47.0)])
	var half_fov := deg_to_rad(vision_angle * 0.5)
	for slice in range(13):
		var ratio := float(slice) / 12.0
		var angle := lerpf(-half_fov, half_fov, ratio)
		var ray_direction := Vector2(cos(angle) * direction, sin(angle))
		cone.append(Vector2(0.0, -47.0) + ray_direction * vision_range)
	var cone_alpha := 0.07 if state == "PATROL" else 0.12
	draw_colored_polygon(cone, Color(1.0, 0.22, 0.28, cone_alpha))
