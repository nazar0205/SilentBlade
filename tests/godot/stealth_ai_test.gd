extends SceneTree
## Godot-side behavior test for AI/stealth modules. Run with:
## godot --headless --path . -s tests/godot/stealth_ai_test.gd

const VisionScript = preload("res://scripts/ai/vision_system.gd")
const DetectionScript = preload("res://scripts/ai/detection_system.gd")
const EnemyAIScript = preload("res://scripts/ai/enemy_ai.gd")
const NoiseScript = preload("res://scripts/stealth/noise_system.gd")
const StealthScript = preload("res://scripts/stealth/stealth_system.gd")
const ZoneScript = preload("res://scripts/stealth/stealth_zone.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const DecoyScript = preload("res://scripts/stealth/noise_decoy.gd")

var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_failures += 1

func _add_shape(body: CollisionObject2D, shape_resource: Shape2D, offset: Vector2 = Vector2.ZERO) -> void:
	var shape := CollisionShape2D.new()
	shape.shape = shape_resource
	shape.position = offset
	body.add_child(shape)

func _run() -> void:
	var detection = DetectionScript.new()
	var d1: Dictionary = detection.update(true, 1.0, 0.5, 0.8, 0.3)
	_check(absf(float(d1["meter"]) - 0.4) < 0.001, "detection meter accumulates with clear line of sight")
	var d2: Dictionary = detection.update(false, 1.0, 0.5, 0.8, 0.3)
	_check(absf(float(d2["meter"]) - 0.25) < 0.001, "detection meter decays after line of sight is lost")
	_check(detection.stage == "SUSPICIOUS", "partial detection stays in suspicious stage")

	var ai = EnemyAIScript.new()
	_check(ai.can_transition("PATROL", "ALERT"), "PATROL transitions to ALERT")
	_check(ai.can_transition("ALERT", "INVESTIGATE"), "ALERT transitions to INVESTIGATE")
	_check(ai.can_transition("INVESTIGATE", "SEARCH"), "INVESTIGATE transitions to SEARCH")
	_check(ai.can_transition("CHASE", "SEARCH"), "CHASE transitions to SEARCH")
	_check(ai.can_transition("SEARCH", "RETURN"), "SEARCH transitions to RETURN")
	_check(ai.can_transition("RETURN", "PATROL"), "RETURN transitions to PATROL")
	_check(not ai.can_transition("PATROL", "RETURN"), "invalid state transition is rejected")

	var world := Node2D.new()
	world.name = "StealthTestWorld"
	root.add_child(world)

	var noise = NoiseScript.new()
	world.add_child(noise)
	var received: Array[Dictionary] = []
	noise.noise_emitted.connect(func(event: Dictionary): received.append(event))
	noise.emit_noise(Vector2(80.0, 160.0), 240.0, 0.8, "TEST_EVENT", 7)
	_check(received.size() == 1, "noise system broadcasts an event")
	_check(received.size() == 1 and received[0]["position"] == Vector2(80.0, 160.0), "noise event preserves the source position")
	_check(received.size() == 1 and received[0]["event_type"] == "TEST_EVENT", "noise event preserves its event type")

	var observer := CharacterBody2D.new()
	observer.position = Vector2(0.0, 0.0)
	observer.collision_layer = 2
	observer.collision_mask = 0
	world.add_child(observer)
	var target := PlayerScript.new()
	target.position = Vector2(220.0, 0.0)
	target.set_physics_process(false)
	world.add_child(target)
	await physics_frame
	await physics_frame
	var vision = VisionScript.new()
	var clear_result: Dictionary = vision.evaluate(observer, target, 1, 440.0, 100.0, 1)
	_check(bool(clear_result["visible"]), "vision detects a target inside range and forward field of view")

	var wall := StaticBody2D.new()
	wall.position = Vector2(110.0, -38.0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(22.0, 150.0)
	_add_shape(wall, wall_shape)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	var blocked_result: Dictionary = vision.evaluate(observer, target, 1, 440.0, 100.0, 1)
	_check(not bool(blocked_result["visible"]) and bool(blocked_result["blocked"]), "opaque wall blocks enemy vision")
	wall.queue_free()
	await physics_frame

	var stealth = StealthScript.new()
	world.add_child(stealth)
	var grass = ZoneScript.new()
	grass.zone_type = "GRASS"
	grass.zone_size = Vector2(260.0, 120.0)
	grass.position = target.position
	var grass_shape := RectangleShape2D.new()
	grass_shape.size = grass.zone_size
	_add_shape(grass, grass_shape)
	world.add_child(grass)
	stealth.register_zone(grass)
	target.crouching = true
	await physics_frame
	await physics_frame
	var concealed_exposure := stealth.get_visibility_multiplier(target)
	_check(concealed_exposure < 0.55, "crouching in grass reduces visual exposure")
	_check(concealed_exposure >= 0.18, "cover never makes the player completely invisible")

	var listener := EnemyScript.new()
	listener.enemy_type = "Scout"
	listener.position = Vector2(60.0, 0.0)
	listener.target = target
	listener.noise_system = noise
	listener.stealth_system = stealth
	world.add_child(listener)
	await physics_frame
	listener.set_physics_process(false)
	_check(is_equal_approx(listener.vision_range, 520.0) and is_equal_approx(listener.hearing_sensitivity, 1.32), "Scout loads its enhanced vision and hearing profile")
	var guard_profile := EnemyScript.new()
	guard_profile.enemy_type = "Guard"
	world.add_child(guard_profile)
	await physics_frame
	guard_profile.set_physics_process(false)
	var heavy_profile := EnemyScript.new()
	heavy_profile.enemy_type = "Heavy Guard"
	world.add_child(heavy_profile)
	await physics_frame
	heavy_profile.set_physics_process(false)
	_check(guard_profile.vision_range == 430.0 and heavy_profile.vision_range == 370.0, "Guard and Heavy Guard load different vision ranges")
	var player_position_before_noise := target.global_position
	listener.on_noise_event({"position": Vector2(90.0, 0.0), "radius": 300.0, "intensity": 0.9, "event_type": "DECOY", "source_id": 77})
	_check(listener.state == "ALERT", "heard noise changes the enemy to ALERT")
	_check(listener.investigate_position == Vector2(90.0, 0.0), "enemy investigates the emitted noise location")
	_check(target.global_position == player_position_before_noise, "noise does not rewrite or track the player's live position")
	listener.state_timer = 0.05
	listener.on_noise_event({"position": Vector2(104.0, 0.0), "radius": 300.0, "intensity": 0.9, "event_type": "FOOTSTEP", "source_id": 78})
	_check(listener.state == "ALERT" and listener.state_timer <= 0.05, "repeated footsteps do not reset the alert reaction delay")
	listener._set_ai_state("INVESTIGATE")
	listener.on_noise_event({"position": Vector2(120.0, 0.0), "radius": 300.0, "intensity": 0.9, "event_type": "DECOY", "source_id": 79})
	_check(listener.state == "INVESTIGATE" and listener.investigate_position == Vector2(120.0, 0.0), "new sound refines an active investigation without restarting ALERT")
	listener._begin_search(Vector2(120.0, 0.0))
	_check(listener.state == "SEARCH", "investigation reaches SEARCH at its destination")
	listener._set_ai_state("RETURN")
	listener._set_ai_state("PATROL")
	_check(listener.state == "PATROL", "completed search returns the enemy to patrol")
	listener._set_ai_state("CHASE")
	listener._begin_search(Vector2(130.0, 0.0))
	_check(listener.state == "SEARCH", "lost visual pursuit transitions from CHASE to SEARCH")
	listener.state = "CHASE"
	listener.is_player_visible = false
	listener.lost_sight_timer = 0.0
	listener.vision_accumulator = 0.0
	listener._update_perception(0.05)
	listener._update_perception(0.05)
	_check(absf(listener.lost_sight_timer - 0.10) < 0.001, "lost-sight grace timer advances once per physics delta")

	var recovery_enemy := EnemyScript.new()
	world.add_child(recovery_enemy)
	await physics_frame
	recovery_enemy.set_physics_process(false)
	recovery_enemy.state = "ATTACK"
	recovery_enemy.attack_phase = "RECOVERY"
	recovery_enemy.phase_timer = 0.50
	recovery_enemy._update_attack_state(0.10, 0.0, 0.0)
	_check(recovery_enemy.state == "ATTACK" and recovery_enemy.attack_phase == "RECOVERY" and absf(recovery_enemy.phase_timer - 0.40) < 0.001, "enemy attack recovery remains active until its timer expires")

	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(420.0, 220.0)
	floor_body.collision_layer = 1
	_add_shape(floor_body, RectangleShape2D.new())
	(floor_body.get_child(0).shape as RectangleShape2D).size = Vector2(180.0, 18.0)
	world.add_child(floor_body)
	var decoy := DecoyScript.new()
	decoy.noise_system = noise
	decoy.position = Vector2(420.0, 120.0)
	decoy.velocity = Vector2(0.0, 0.0)
	world.add_child(decoy)
	for _frame in range(40):
		await physics_frame
	var decoy_event_seen := false
	for received_event in received:
		if String(received_event.get("event_type", "")) == "DECOY":
			decoy_event_seen = true
	_check(decoy_event_seen, "thrown distraction emits a noise event on impact")

	print("RESULT: ", "FAILED (%d)" % _failures if _failures > 0 else "ALL PASSED")
	world.queue_free()
	quit(1 if _failures > 0 else 0)
