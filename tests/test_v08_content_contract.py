from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_rank_contract_uses_time_as_well_as_stealth_and_objectives():
    src = read("scripts/mission/mission_results.gd")
    assert "S_TIME_LIMIT := 420.0" in src
    assert "A_TIME_LIMIT := 660.0" in src
    assert "B_TIME_LIMIT := 960.0" in src
    assert "elapsed_time" in src


def test_mission_level_has_five_zones_multiple_routes_and_distinctive_interactables():
    data = json.loads(read("data/missions/mission_01.json"))
    assert [zone["id"] for zone in data["zones"]] == ["A", "B", "C", "D", "E"]
    assert all(len(zone["route_types"]) >= 2 for zone in data["zones"])
    level = read("scripts/mission/mission_level.gd")
    for method in ("_build_parallax", "_build_geometry", "_build_dressing", "_build_stealth_environment", "_build_interactables"):
        assert f"func {method}(" in level
    for kind in ("village_gate", "hidden_passage", "signal_console", "archive_orders", "evacuation_exit"):
        assert kind in level


def test_version_and_android_export_preset_are_updated_to_v08():
    preset = read("export_presets.cfg")
    assert "version/code=8" in preset
    assert 'version/name="0.8.0"' in preset
    project = read("project.godot")
    assert 'config/features=PackedStringArray("4.3", "GL Compatibility")' in project
    assert 'window/handheld/orientation=0' in project


def test_mission_audio_assets_and_v08_docs_are_in_the_project():
    for name in ("night_ambience.wav", "wood_step.wav", "grass_step.wav", "interaction.wav", "document_pickup.wav", "alarm_signal.wav"):
        assert (ROOT / "assets/audio" / name).is_file()
    assert (ROOT / "docs/V0.8_FIRST_COMPLETE_MISSION.md").is_file()
    assert (ROOT / "docs/TEST_REPORT_V0.8.md").is_file()


def test_godot_43_workflow_runs_the_mission_runtime_contract_test():
    test_script = read("tests/godot/mission_systems_test.gd")
    assert '"archive objective may complete before signal is disabled"' in test_script
    workflow = read(".github/workflows/godot-validation.yml")
    assert "tests/godot/mission_systems_test.gd" in workflow
    assert "godot-mission.log" in workflow
