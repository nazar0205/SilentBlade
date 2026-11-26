from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "scripts/player.gd").read_text(encoding="utf-8")
ENEMY = (ROOT / "scripts/enemy.gd").read_text(encoding="utf-8")
MAIN = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")


def test_player_uses_one_physics_attack_area_and_per_swing_deduplication():
    assert len(re.findall(r"Area2D\.new\(\)", PLAYER)) == 1
    assert "CollisionShape2D.new()" in PLAYER
    assert "hit_ids_this_swing" in PLAYER
    assert "get_instance_id()" in PLAYER
    assert "body_entered" in PLAYER or "get_overlapping_bodies" in PLAYER


def test_player_attack_is_gated_by_facing_and_active_window():
    assert "attack_hitbox.position.x" in PLAYER
    assert "attack_hitbox.monitoring" in PLAYER
    assert "attack_active" in PLAYER


def test_enemy_attack_has_telegraph_execution_recovery_and_interrupt():
    for phase in ("TELEGRAPH", "ATTACK", "RECOVERY"):
        assert phase in ENEMY
    assert "interrupt_attack" in ENEMY
    assert "attack_started" in ENEMY
    assert "parried" in ENEMY


def test_block_is_hold_based_with_exact_parry_window_and_guard_break():
    assert re.search(r"const\s+PARRY_WINDOW\s*:=\s*0\.18", PLAYER)
    for name in ("begin_block", "end_block", "try_parry", "receive_blocked_hit"):
        assert f"func {name}(" in PLAYER
    assert "guard_stamina" in PLAYER
    assert "guard_broken" in PLAYER
    assert "guard_changed" in PLAYER


def test_touch_block_releases_on_focus_loss_and_input_reset():
    assert '"block"' in MAIN
    assert '["move_left", "move_right", "jump", "crouch", "dash", "grapple", "attack", "block"]' in MAIN
    assert '"БЛОК", "block"' in MAIN
    assert "button.button_up.connect" in MAIN


def test_guard_hud_is_signal_driven_and_displays_broken_state():
    assert "guard_bar" in MAIN
    assert "guard_changed.connect" in MAIN
    assert "guard_broken.connect" in MAIN
    assert "СТОЙКА СЛОМАНА" in MAIN


def test_main_no_longer_uses_distance_polling_for_combat_damage():
    assert "guard.hit(30.0)" not in MAIN
    assert "player.take_damage(18.0 * delta)" not in MAIN


def test_parry_opens_a_real_counterattack_bonus_window():
    assert "var current_attack_damage" in PLAYER
    assert re.search(r"counter_window_timer\s*>\s*0\.0", PLAYER)
    assert "current_attack_damage" in PLAYER
    assert "counter_window_timer = 0.0" in PLAYER


def test_enemy_execution_only_hits_target_inside_forward_attack_arc():
    assert "absf(dx) <= attack_range + 24.0" in ENEMY
    assert "int(signf(dx)) == attack_facing" in ENEMY
    assert "target.receive_enemy_attack(self)" in ENEMY

# v0.4.1 expanded combat contract: these checks intentionally validate runtime
# wiring and per-type/per-strike data, not just labels in comments or constants.

def _container_block(source: str, declaration: str, opening_char: str, closing_char: str) -> str:
    start = source.index(declaration)
    opening = source.index(opening_char, start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == opening_char:
            depth += 1
        elif source[index] == closing_char:
            depth -= 1
            if depth == 0:
                return source[opening:index + 1]
    raise AssertionError(f"Unclosed container for {declaration}")


def _dictionary_block(source: str, declaration: str) -> str:
    return _container_block(source, declaration, "{", "}")


def _array_block(source: str, declaration: str) -> str:
    return _container_block(source, declaration, "[", "]")


def test_guard_scout_and_heavy_guard_have_distinct_runtime_profiles():
    assert "const ENEMY_PROFILES" in ENEMY
    profiles = _dictionary_block(ENEMY, "const ENEMY_PROFILES")
    for kind in ("Guard", "Scout", "Heavy Guard"):
        assert f'"{kind}"' in profiles
    profile_blocks = {
        kind: re.search(r'"' + re.escape(kind) + r'": \{([^}]+)\}', profiles).group(1)
        for kind in ("Guard", "Scout", "Heavy Guard")
    }
    for stat in ("health", "movement_speed", "attack_damage", "attack_cooldown", "knockback_resistance"):
        values = [re.search(r'"' + stat + r'": ([0-9.]+)', block).group(1) for block in profile_blocks.values()]
        assert len(set(values)) == 3, f"{stat} must differ by enemy type"
    for field in (
        "health", "movement_speed", "attack_damage", "attack_cooldown",
        "telegraph_time", "attack_active_time", "recovery_time",
        "knockback_resistance",
    ):
        assert f'"{field}"' in profiles
    assert "_apply_enemy_profile()" in ENEMY
    assert "ENEMY_PROFILES[enemy_type]" in ENEMY
    for assignment in (
        'speed = float(profile["movement_speed"])',
        'attack_damage = float(profile["attack_damage"])',
        'attack_cooldown_duration = float(profile["attack_cooldown"])',
        'telegraph_duration = float(profile["telegraph_time"])',
        'recovery_duration = float(profile["recovery_time"])',
        'knockback_resistance = float(profile["knockback_resistance"])',
    ):
        assert assignment in ENEMY


def test_level_spawns_all_three_enemy_types_as_live_instances():
    assert "func _spawn_enemy(" in MAIN
    for kind in ("Guard", "Scout", "Heavy Guard"):
        assert f'"{kind}"' in MAIN
    assert "enemies.append(enemy)" in MAIN
    assert "enemy.died.connect(_on_enemy_died)" in MAIN
    assert "enemy.set_physics_process(false)" in MAIN


def test_katana_combo_has_three_distinct_strike_profiles():
    assert "const COMBO_ATTACKS" in PLAYER
    profiles = _array_block(PLAYER, "const COMBO_ATTACKS")
    assert profiles.count('"name"') == 3
    for field in ("damage", "active_time", "cooldown", "hitbox_size", "knockback", "visual_style"):
        assert profiles.count(f'"{field}"') == 3
    strike_blocks = re.findall(r'\{\s*"name": "[^"]+"(.*?)\n\t\}', profiles, re.S)
    assert len(strike_blocks) == 3
    for stat in ("damage", "active_time", "cooldown", "knockback", "visual_style"):
        values = [re.search(r'"' + stat + r'": ([^,\n]+)', block).group(1).strip() for block in strike_blocks]
        assert len(set(values)) == 3, f"{stat} must differ by combo strike"
    hitbox_sizes = re.findall(r'"hitbox_size": Vector2\(([^)]+)\)', profiles)
    assert len(hitbox_sizes) == 3 and len(set(hitbox_sizes)) == 3
    assert "current_attack_index" in PLAYER
    assert "combo_step" in PLAYER
    assert "combo_timer" in PLAYER


def test_combo_advances_only_after_each_attack_and_resets_after_link_timeout():
    assert "combo_step = (current_attack_index + 1) % COMBO_ATTACKS.size()" in PLAYER
    assert "combo_timer = COMBO_LINK_WINDOW" in PLAYER
    assert "if combo_timer <= 0.0 and not attack_active:" in PLAYER
    assert "var profile: Dictionary = COMBO_ATTACKS[current_attack_index]" in PLAYER
    assert "current_attack_index = combo_step" in PLAYER


def test_each_combo_strike_changes_hitbox_and_visual_reaction():
    assert "attack_rect.size = current_attack_hitbox_size" in PLAYER
    assert "current_attack_hitbox_offset.y" in PLAYER
    assert "absf(current_attack_hitbox_offset.x) * facing" in PLAYER
    assert "match current_attack_visual_style:" in PLAYER
    assert "visual_style" in PLAYER
    assert "body.has_method(\"receive_damage\")" in PLAYER


def test_player_damage_call_transmits_strike_specific_knockback():
    assert 'body.call("receive_damage", current_attack_damage, global_position, current_attack_knockback)' in PLAYER
    assert "func receive_damage(" in ENEMY
    assert "knockback_resistance" in ENEMY
    assert "knockback_force_applied := minf(maxf(0.0, knockback_force) / maxf(0.1, knockback_resistance), 520.0)" in ENEMY
    assert "velocity.x = knockback_direction * knockback_force_applied" in ENEMY
    assert 'state = "KNOCKBACK"' in ENEMY


def test_enemy_death_is_emitted_once_and_node_is_removed():
    assert "signal died(enemy_type: String)" in ENEMY
    assert "var is_dead := false" in ENEMY
    assert "if is_dead:" in ENEMY
    assert "died.emit(enemy_type)" in ENEMY
    assert "queue_free()" in ENEMY
    death_block = re.search(r"func _die\(\).*?(?=\nfunc )", ENEMY, re.S).group(0)
    assert death_block.count("died.emit(enemy_type)") == 1
    assert death_block.index("is_dead = true") < death_block.index("died.emit(enemy_type)") < death_block.index("queue_free()")
    assert "func hit(" not in ENEMY
    assert "defeated_enemies += 1" in MAIN


def test_old_single_guard_spawn_and_single_enemy_counter_are_removed():
    assert "var guard: SilentBladeGuard" not in MAIN
    assert "guard_was_alive" not in MAIN
    assert "_build_guard()" not in MAIN
    assert "_build_enemies()" in MAIN


def test_enemy_profile_damage_is_used_by_player_hit_and_block_resolution():
    assert "func get_attack_damage() -> float:" in ENEMY
    assert "return attack_damage" in ENEMY
    assert 'attacker.call("get_attack_damage")' in PLAYER
    assert "take_damage(incoming_damage)" in PLAYER
    assert "incoming_damage * GUARD_BREAK_DAMAGE_RATIO" in PLAYER
