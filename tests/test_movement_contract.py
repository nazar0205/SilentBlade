from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "scripts/player.gd").read_text(encoding="utf-8")
MAIN = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
JOYSTICK = (ROOT / "scripts/virtual_joystick.gd").read_text(encoding="utf-8")


def test_jump_system_has_two_charges_and_bounded_coyote_and_buffer_windows():
    assert re.search(r"const\s+MAX_JUMPS\s*:=\s*2", PLAYER)
    assert re.search(r"const\s+COYOTE_TIME\s*:=\s*0\.12", PLAYER)
    assert re.search(r"const\s+JUMP_BUFFER_TIME\s*:=\s*0\.15", PLAYER)
    assert "jump_count" in PLAYER
    assert "coyote_timer" in PLAYER
    assert "jump_buffer_timer" in PLAYER
    assert "func _try_consume_jump_buffer(" in PLAYER


def test_double_jump_resets_only_on_ground_and_has_its_own_feedback():
    assert re.search(r"jump_count\s*=\s*0", PLAYER)
    assert "second_jump_flash_timer" in PLAYER
    assert 'func _play_second_jump_effect()' in PLAYER
    assert "_play_second_jump_effect()" in PLAYER
    assert "jump_count < MAX_JUMPS" in PLAYER


def test_jump_height_responds_to_release_and_hold_without_retriggering():
    assert "Input.is_action_just_released(\"jump\")" in PLAYER
    assert "JUMP_CUT_MULTIPLIER" in PLAYER
    assert "JUMP_HOLD_GRAVITY_SCALE" in PLAYER
    assert "jump_hold_timer" in PLAYER
    assert "if not is_on_floor() or velocity.y < 0.0:" in PLAYER
    assert "(is_on_floor() and velocity.y >= 0.0) or (jump_count == 0 and coyote_timer > 0.0)" in PLAYER


def test_jump_buffer_is_consumed_after_landing_and_coyote_expires():
    assert "jump_buffer_timer = JUMP_BUFFER_TIME" in PLAYER
    assert "coyote_timer = COYOTE_TIME" in PLAYER
    assert "coyote_timer = maxf(0.0, coyote_timer - delta)" in PLAYER
    assert "jump_buffer_timer = 0.0" in PLAYER
    assert PLAYER.count("is_on_floor() and velocity.y >= 0.0") == 3


def test_grapple_keeps_selected_anchor_but_checks_line_of_sight():
    assert "func _has_clear_grapple_line(" in PLAYER
    assert "PhysicsRayQueryParameters2D.create" in PLAYER
    assert "intersect_ray" in PLAYER
    assert "GRAPPLE_COLLISION_MASK" in PLAYER
    assert "if _has_clear_grapple_line(point):" in PLAYER


def test_grapple_uses_tangent_control_and_collision_aware_rope_constraint():
    assert "GRAPPLE_PUMP_ACCEL" in PLAYER
    assert "tangent" in PLAYER
    assert "func _constrain_rope_after_motion(" in PLAYER
    assert "move_and_collide" in PLAYER
    assert "rope_length = maxf(GRAPPLE_MIN_ROPE_LENGTH, best)" in PLAYER
    assert "global_position = corrected_position" not in PLAYER
    assert "rope_length = maxf(GRAPPLE_MIN_ROPE_LENGTH, best)" in PLAYER
    assert "best * 0.82" not in PLAYER


def test_grapple_detach_preserves_velocity_and_blocked_line_detaches():
    assert "func _detach_grapple(" in PLAYER
    assert re.search(r"func _detach_grapple\(\).*?grappling\s*=\s*false", PLAYER, re.S)
    assert "velocity = Vector2.ZERO" not in re.search(r"func _detach_grapple\(\).*?(?=\nfunc )", PLAYER, re.S).group(0)
    assert "not _has_clear_grapple_line(grapple_point)" in PLAYER
    assert "_detach_grapple()" in PLAYER


def test_dash_has_smooth_ramp_inertia_cooldown_and_guard_break_gate():
    for value in ("DASH_COOLDOWN", "DASH_EXIT_SPEED", "DASH_ACCEL_TIME"):
        assert value in PLAYER
    assert "func _start_dash(" in PLAYER
    assert "func _update_dash(" in PLAYER
    assert "dash_cooldown <= 0.0" in PLAYER
    assert "not guard_is_broken" in PLAYER
    assert "dash_exit_timer" in PLAYER
    assert "dash_direction" in PLAYER


def test_dash_detaches_grapple_without_position_snap_and_keeps_exit_momentum():
    dash_block = re.search(r"func _start_dash\(.*?(?=\nfunc )", PLAYER, re.S).group(0)
    assert "_detach_grapple()" in dash_block
    assert "velocity.x" in dash_block
    assert "DASH_EXIT_SPEED" in PLAYER


def test_android_touch_cancel_releases_all_actions_and_resets_player_transients():
    assert "event is InputEventScreenTouch and event.canceled" in MAIN
    assert "NOTIFICATION_APPLICATION_FOCUS_OUT" in MAIN
    assert "NOTIFICATION_WM_WINDOW_FOCUS_OUT" in MAIN
    assert "_reset_all_input()" in MAIN
    reset_block = re.search(r"func _reset_all_input\(\).*?(?=\nfunc )", MAIN, re.S).group(0)
    for action in ("jump", "grapple", "dash", "attack", "block", "move_left", "move_right"):
        assert f'"{action}"' in reset_block
    assert "joystick.cancel_input()" in reset_block
    assert "player.release_controls()" in reset_block


def test_touch_controls_keep_independent_buttons_for_multitouch_and_jump_hold():
    assert '["ПРЫЖОК", "jump"' in MAIN
    assert "button.button_down.connect" in MAIN
    assert "button.button_up.connect" in MAIN
    assert "joystick.axis_changed.connect(_on_joystick_axis)" in MAIN


def test_virtual_joystick_releases_axis_when_touch_is_cancelled_or_focus_lost():
    assert "func cancel_input()" in JOYSTICK
    assert "_reset_axis()" in JOYSTICK
    assert "axis_changed.emit(0.0)" in JOYSTICK


def test_existing_combat_hud_camera_and_mission_systems_remain_wired():
    for token in (
        "COMBO_ATTACKS", "attack_hitbox", "receive_enemy_attack", "begin_block",
        "try_parry", "guard_stamina", "guard_changed", "guard_broken",
    ):
        assert token in PLAYER
    for token in (
        "_build_camera()", "_build_hud()", "_build_enemies()", "_show_title()",
        "_show_results(", "_on_enemy_died", "guard_changed.connect", "parry_succeeded.connect",
    ):
        assert token in MAIN


def test_project_remains_godot_4_3_android_landscape_and_existing_main_scene():
    config = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert '"4.3"' in config
    assert 'run/main_scene="res://scenes/Main.tscn"' in config
    assert "window/handheld/orientation=0" in config
    assert 'path="res://scripts/main.gd"' in (ROOT / "scenes/Main.tscn").read_text(encoding="utf-8")
