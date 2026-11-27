"""v0.8 interaction/alarm/checkpoint source contracts; not Godot runtime tests."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

def test_interactable_supports_one_shot_consumption_and_reopenable_doors():
    src = read("scripts/mission/mission_interactable.gd")
    for token in ("signal interacted", "func interact(", "func set_open(", "func set_consumed(", "requires_flag", "door_body"):
        assert token in src
    assert 'kind == "door"' in src

def test_interaction_system_selects_nearest_and_exposes_context_prompt():
    src = read("scripts/mission/interaction_system.gd")
    for token in ("register_interactable(", "current_target", "get_current_prompt(", "func interact(", "distance_to", "set_interaction_prompt"):
        assert token in src
    assert "interaction_range" in src

def test_interaction_rejects_locked_exit_until_archive_flag_is_set():
    src = read("scripts/mission/mission_interactable.gd")
    assert "requires_flag" in src and "has_world_flag" in src
    body = re.search(r"func interact\(.*?(?=\nfunc )", src, re.S).group(0)
    assert "is_available" in body and "return false" in body

def test_alarm_broadcast_uses_noise_system_fixed_signal_position():
    src = read("scripts/mission/alarm_system.gd")
    assert "raise_global_alarm(" in src and "disable_alarm(" in src
    assert "emit_noise" in src and '"GLOBAL_ALARM"' in src
    assert "global_alarm_active" in src and "alarm_device_enabled" in src
    assert "alarm_triggered" in src

def test_alarm_is_idempotent_and_can_be_restored_from_checkpoint():
    src = read("scripts/mission/alarm_system.gd")
    body = re.search(r"func raise_global_alarm\(.*?(?=\nfunc )", src, re.S).group(0)
    assert "global_alarm_active" in body and "return false" in body
    assert "func restore_enabled(" in src

def test_checkpoint_snapshot_stores_position_alarm_and_idempotent_identity():
    src = read("scripts/mission/checkpoint_system.gd")
    for token in ("func activate(", "func get_snapshot(", "checkpoint_id", "respawn_position", "alarm_enabled", "checkpoint_activated"):
        assert token in src
    assert "if checkpoint_id == id" in src


def test_checkpoint_persists_mission_state_alongside_alarm_and_position():
    src = read("scripts/mission/checkpoint_system.gd")
    assert src.count("var mission_state: Dictionary") == 1
    assert '"mission_state": mission_state.duplicate(true)' in src
    assert "func activate(" in src


def test_interaction_system_does_not_keep_open_doors_as_stale_targets():
    src = read("scripts/mission/interaction_system.gd")
    assert 'if prop.kind == "door" and prop.is_open:' in src


def test_successful_interactions_emit_a_noise_event_at_the_interaction_point():
    src = read("scripts/mission/mission_interactable.gd")
    body = re.search(r"func interact\(.*?(?=\nfunc )", src, re.S).group(0)
    assert 'player.notify_interaction_noise(' in body
    assert '"INTERACTION"' in body
    assert "if one_shot" in body
