"""v0.8 integration contracts. Runtime behavior is additionally covered by Godot test scripts."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_main_builds_the_mission_from_data_and_spawns_all_configured_enemies():
    main = read("scripts/main.gd")
    assert main.count("func _build_enemies(") == 1
    assert main.count("func _spawn_enemy(") == 1
    assert "mission_level.build(stealth_system)" in main
    assert "for spawn in mission_level.enemy_spawns" in main
    assert "mission_level.world_width" in main


def test_main_routes_interaction_to_objective_alarm_secret_and_evacuation_systems():
    main = read("scripts/main.gd")
    for token in ("_build_interaction_system(", "interaction_system.register_interactable", "_on_interactable_used(", "disable_alarm(", "collect_item(", "finish_mission(true)", "mission_ready_for_evacuation"):
        assert token in main


def test_evacuation_requires_document_and_disabled_signal_but_archive_is_independent():
    data = json.loads(read("data/missions/mission_01.json"))
    objectives = {entry["id"]: entry for entry in data["objectives"]}
    assert objectives["retrieve_orders"].get("requires") == ["enter_village"]
    assert set(objectives["evacuate"].get("requires", [])) == {"retrieve_orders", "disable_signal"}
    level = read("scripts/mission/mission_level.gd")
    assert '"mission_ready_for_evacuation"' in level


def test_death_uses_checkpoint_restore_without_resetting_mission_progress():
    main = read("scripts/main.gd")
    assert "func _respawn_at_checkpoint(" in main
    assert "checkpoint_system.get_snapshot()" in main
    assert "mission_manager.snapshot_persistent_state()" in main
    # Run state remains live through death; checkpoint snapshots retain a rollback point,
    # but restoring the snapshot here would erase post-checkpoint counters/collected IDs.
    assert "mission_manager.restore_progress_state(" not in main
    assert "_apply_persistent_world_state(" in main
    assert "MissionManager keeps all collected IDs and run statistics across death" in main
    assert "func kill()" in read("scripts/player.gd")


def test_tutorial_toggle_is_persistent_and_hints_are_triggered_by_zone_progress():
    assert (ROOT / "scripts/mission/tutorial_system.gd").is_file()
    tutorial = read("scripts/mission/tutorial_system.gd")
    for token in ("ConfigFile", "set_enabled(", "show_hint(", "hint_changed", "user://"):
        assert token in tutorial
    main = read("scripts/main.gd")
    assert "tutorial_system.show_hint(" in main
    assert "toggle_enabled(" in main
    assert "ОБУЧЕНИЕ: ВКЛ" in main and "ОБУЧЕНИЕ: ВЫКЛ" in main


def test_results_screen_exposes_retry_continue_and_menu_actions():
    main = read("scripts/main.gd")
    for token in ("ПОВТОРИТЬ МИССИЮ", "ПРОДОЛЖИТЬ", "В МЕНЮ", "_show_campaign_transition(", "_restart_level("):
        assert token in main
    assert '"optional_completed"' in read("scripts/mission/mission_manager.gd")


def test_context_interaction_button_is_dynamic_and_uses_independent_touch_ownership():
    touch = read("scripts/input/touch_controls.gd")
    assert '"action": "interact"' in touch
    assert "set_interaction_prompt(" in touch
    assert "interaction_prompt.is_empty()" in touch
    assert "_held_by[action] = finger" in touch
    assert "touch.canceled" in touch


def test_viewport_expands_for_16_9_and_19_5_9_without_vertical_cropping():
    config = read("project.godot")
    assert 'window/stretch/aspect="expand"' in config
    assert 'window/handheld/orientation=0' in config


def test_fullscreen_panels_center_against_the_actual_expanded_viewport():
    main = read("scripts/main.gd")
    assert "func _get_screen_size() -> Vector2:" in main
    assert "return get_viewport_rect().size" in main
    for function in ("_build_pause_panel", "_show_title", "_show_results", "_show_campaign_transition"):
        body = main.split(f"func {function}(", 1)[1].split("\nfunc ", 1)[0]
        assert "_get_screen_size()" in body, function


def test_mission_failure_signal_opens_the_failure_results_flow_without_breaking_checkpoints():
    main = read("scripts/main.gd")
    assert "mission_manager.mission_failed.connect(_on_mission_failed)" in main
    assert "func _fail_mission(reason: String) -> void:" in main
    assert "func _on_mission_failed(results: Dictionary) -> void:" in main
    handler = main.split("func _on_mission_failed(", 1)[1].split("\nfunc ", 1)[0]
    assert "_show_results(false)" in handler
    assert "finish_mission(false, reason)" in main
