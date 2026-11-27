"""Static integration contracts for Silent Blade v0.7. These do not replace Godot runtime tests."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

ENEMY = read("scripts/enemy.gd")
PLAYER = read("scripts/player.gd")
MAIN = read("scripts/main.gd")
TOUCH = read("scripts/input/touch_controls.gd")


def block(source, declaration):
    start = source.index(declaration)
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        if source[i] == "{": depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0: return source[brace:i + 1]
    raise AssertionError(f"unclosed block: {declaration}")


def test_enemy_profiles_have_distinct_vision_hearing_and_reaction_traits():
    profiles = block(ENEMY, "const ENEMY_PROFILES")
    names = ("Guard", "Scout", "Heavy Guard")
    entries = [re.search(r'"' + re.escape(n) + r'": \{([^}]+)\}', profiles).group(1) for n in names]
    fields = ("vision_range", "vision_angle", "hearing_sensitivity", "reaction_speed", "search_time", "suspicion_time", "detection_rate")
    for field in fields:
        values = [re.search(r'"' + field + r'": ([0-9.]+)', entry).group(1) for entry in entries]
        assert len(set(values)) == 3, f"{field} must differ across all enemy types"


def test_fsm_contains_all_required_states_and_transition_gate():
    for state in ("PATROL", "ALERT", "INVESTIGATE", "CHASE", "SEARCH", "RETURN", "ATTACK"):
        assert f'"{state}"' in ENEMY
    assert "SilentBladeEnemyAI" in ENEMY
    assert "can_transition" in ENEMY
    assert "func _set_ai_state(" in ENEMY


def test_vision_uses_fov_range_and_physics_line_of_sight():
    vision = read("scripts/ai/vision_system.gd")
    assert "vision_range" in vision and "vision_angle" in vision
    assert "dot(" in vision
    assert "PhysicsRayQueryParameters2D.create" in vision
    assert "intersect_ray" in vision
    assert "collider" in vision


def test_detection_meter_accumulates_and_decays_in_separate_system():
    detection = read("scripts/ai/detection_system.gd")
    assert "func update(" in detection
    assert "detection_rate" in detection
    assert "decay_rate" in detection
    assert "clampf" in detection
    assert "stage" in detection


def test_hearing_uses_event_location_not_live_player_position():
    noise = read("scripts/stealth/noise_system.gd")
    assert "signal noise_emitted" in noise
    for field in ("position", "radius", "intensity", "event_type", "source_id"):
        assert f'"{field}"' in noise
    handler = re.search(r"func on_noise_event\(.*?(?=\nfunc )", ENEMY, re.S).group(0)
    assert 'event["position"]' in handler
    assert "target.global_position" not in handler
    assert "INVESTIGATE" in handler


def test_player_emits_noise_for_running_jumping_landing_dash_attack_and_grapple():
    for event in ("FOOTSTEP", "JUMP", "LAND", "DASH", "ATTACK", "GRAPPLE"):
        assert f'"{event}"' in PLAYER
    assert "signal noise_emitted" in PLAYER
    assert "signal distraction_requested" in PLAYER


def test_distraction_is_a_physical_throwable_with_impact_noise():
    decoy = read("scripts/stealth/noise_decoy.gd")
    assert "CharacterBody2D" in decoy
    assert "move_and_slide" in decoy
    assert "emit_noise" in decoy
    assert "DECOY" in decoy
    assert "_spawn_noise_decoy" in MAIN


def test_cover_and_lighting_change_visibility_without_making_player_fully_invisible():
    zone = read("scripts/stealth/stealth_zone.gd")
    cover = read("scripts/stealth/cover_system.gd")
    stealth = read("scripts/stealth/stealth_system.gd")
    for kind in ("GRASS", "COVER", "DARK", "LIGHT"):
        assert kind in zone
    assert "get_concealment_multiplier" in cover
    assert "get_visibility_multiplier" in stealth
    assert re.search(r"clampf\([^\n]*0\.18", stealth)


def test_level_instantiates_grass_dark_light_and_physical_cover():
    level = read("scripts/mission/mission_level.gd")
    for marker in ("_build_stealth_environment", "_add_stealth_zone", "_add_cover_obstacle", '"GRASS"', '"DARK"', '"LIGHT"'):
        assert marker in level
    assert "CollisionShape2D.new()" in level


def test_noise_and_stealth_systems_are_wired_into_player_and_enemies():
    assert "SilentBladeNoiseSystem" in MAIN
    assert "SilentBladeStealthSystem" in MAIN
    assert "noise_emitted.connect" in MAIN
    assert "noise_system = noise_system" in MAIN
    assert "stealth_system = stealth_system" in MAIN
    assert "noise_emitted.connect" in ENEMY or "noise_system.noise_emitted.connect" in ENEMY


def test_state_and_detection_feedback_is_visible_on_hud_and_enemy_sprite():
    assert "detection_bar" in MAIN
    assert "stealth_status_label" in MAIN
    assert "detection_changed" in ENEMY
    assert "ai_state_changed" in ENEMY
    assert "detection_meter" in ENEMY


def test_android_distraction_button_preserves_existing_multitouch_routing():
    assert '"action": "distract"' in TOUCH
    assert '"distract": [KEY_G]' in MAIN
    assert "_held_by" in TOUCH and "_fingers" in TOUCH
    assert "touch.canceled" in TOUCH
    assert "release_all()" in TOUCH


def test_existing_combat_movement_and_touch_systems_remain_referenced():
    for token in ("COMBO_ATTACKS", "attack_hitbox", "begin_block", "try_parry", "guard_stamina", "_apply_grapple_control", "_update_dash", "_try_consume_jump_buffer"):
        assert token in PLAYER
    for token in ("_on_enemy_died", "_build_camera", "_show_results", "mission_level.enemy_spawns"):
        assert token in MAIN
    mission_data = read("data/missions/mission_01.json")
    for enemy_type in ("Guard", "Scout", "Heavy Guard"):
        assert enemy_type in mission_data
    assert "gameplay_smoke_test.gd" in read(".github/workflows/godot-validation.yml")


def test_enemy_attack_recovery_is_not_cancelled_before_its_timer_expires():
    attack_update = re.search(r"func _update_attack_state\(.*?(?=\nfunc )", ENEMY, re.S).group(0)
    recovery = attack_update.split('"RECOVERY":', 1)[1]
    assert "if phase_timer <= 0.0:" in recovery
    assert re.search(r"if phase_timer <= 0\.0:[\s\S]*?else:\n\t\t\t\t\t_begin_search", recovery), "SEARCH should begin only after recovery timer expires"


def test_repeated_footsteps_do_not_keep_resetting_the_alert_reaction_delay():
    handler = re.search(r"func on_noise_event\(.*?(?=\nfunc )", ENEMY, re.S).group(0)
    assert 'if state not in ["ALERT", "INVESTIGATE"]:' in handler
    assert 'var reaction_delay := 0.28 / maxf(0.35, reaction_speed)' in handler
    assert 'state_timer = minf(state_timer, reaction_delay)' in handler


def test_touch_layout_adds_each_action_button_only_once():
    touch = read("scripts/input/touch_controls.gd")
    relayout = re.search(r"func _relayout\(\).*?(?=\nfunc )", touch, re.S).group(0)
    assert relayout.count("_buttons.append(button)") == 1


def test_player_attack_draw_has_one_local_start_declaration():
    draw = PLAYER.split("func _draw()", 1)[1]
    assert draw.count("var start := Vector2(13 * facing, -36)") == 1


def test_hud_aggregates_active_enemy_states_instead_of_last_signal_only():
    assert "_get_aggregate_enemy_state" in MAIN
    assert "highest_state = enemy.state" in MAIN
    assert "enemy_state_label.text = _enemy_state_text(_get_aggregate_enemy_state())" in MAIN


def test_falling_landing_and_object_interactions_have_explicit_noise_events():
    assert '"FALL"' in PLAYER
    assert '"LAND"' in PLAYER
    assert 'func notify_interaction_noise(' in PLAYER
    assert '"INTERACTION"' in PLAYER


def test_cover_obstacles_do_not_block_enemy_patrol_corridors():
    # Patrol bounds are Guard 720-1080, Scout 1160-1430, Heavy Guard 1940-2420.
    level = read("scripts/mission/mission_level.gd")
    assert '_add_cover_obstacle(Vector2(870, 605)' in level
    assert '_add_cover_obstacle(Vector2(1560, 605)' in level


def test_ai_search_and_return_use_distinct_search_and_patrol_origins():
    assert 'var search_center_position := Vector2.ZERO' in ENEMY
    assert 'search_center_position = search_origin' in ENEMY
    assert 'home_x = global_position.x' in ENEMY
    assert 'clampf(home_x, left_limit, right_limit)' in ENEMY


def test_player_status_distinguishes_cover_from_normal_visibility():
    stealth = read("scripts/stealth/stealth_system.gd")
    assert 'if exposure < 0.55:' in stealth
    assert 'В ТЕНИ / УКРЫТИИ' in stealth


def test_hud_shows_combat_interrupt_states_without_hiding_other_ai_states():
    assert '"STAGGER": 2, "KNOCKBACK": 2' in MAIN
    assert '"STAGGER": return "ВРАГ ОГЛУШЁН"' in MAIN
    assert '"KNOCKBACK": return "ВРАГ ОТБРОШЕН"' in MAIN


def test_lost_sight_grace_timer_counts_each_physics_delta_once():
    perception = re.search(r"func _update_perception\(.*?(?=\nfunc )", ENEMY, re.S).group(0)
    timer_helper = re.search(r"func _advance_lost_sight_timer\(.*?(?=\nfunc )", ENEMY, re.S).group(0)
    assert "_advance_lost_sight_timer(delta)" in perception
    assert "_advance_lost_sight_timer(sample_delta if was_visible else delta)" in perception
    assert timer_helper.count("lost_sight_timer += delta") == 1
    assert "lost_sight_timer += sample_delta" not in perception
