"""v0.8 source contracts; these tests do not substitute for a Godot runtime run."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

def test_mission_data_defines_the_requested_story_and_five_zones():
    data = json.loads(read("data/missions/mission_01.json"))
    assert data["id"] == "mission_01_shadow_of_the_village"
    assert data["title"] == "MISSION 01 — THE SHADOW OF THE VILLAGE"
    assert [z["id"] for z in data["zones"]] == ["A", "B", "C", "D", "E"]
    assert all(z.get("route_types") for z in data["zones"])

def test_primary_objectives_are_ordered_and_evacuation_is_last():
    data = json.loads(read("data/missions/mission_01.json"))
    ids = [o["id"] for o in data["objectives"]]
    assert ids == ["enter_village", "disable_signal", "retrieve_orders", "evacuate"]
    objectives = {entry["id"]: entry for entry in data["objectives"]}
    assert objectives["retrieve_orders"]["requires"] == ["enter_village"]
    assert set(objectives["evacuate"]["requires"]) == {"retrieve_orders", "disable_signal"}

def test_optional_challenges_and_secrets_are_distinct_from_primary_objectives():
    data = json.loads(read("data/missions/mission_01.json"))
    optional = {o["id"] for o in data["optional_objectives"]}
    secrets = {s["id"] for s in data["secrets"]}
    assert optional == {"ghost_run", "no_kills", "all_secrets", "all_documents"}
    assert secrets == {"hidden_cache", "field_report"}
    assert not optional.intersection({o["id"] for o in data["objectives"]})

def test_mission_manager_owns_progress_stats_and_deduplicates_items():
    src = read("scripts/mission/mission_manager.gd")
    for token in ("complete_objective(", "collect_item(", "record_detection(", "record_alarm(", "record_neutralization(", "get_results(", "collected_item_ids"):
        assert token in src
    assert "objective_completed" in src and "mission_completed" in src

def test_objective_manager_allows_independent_archive_goal_but_gates_evacuation():
    src = read("scripts/mission/objective_manager.gd")
    assert "current_objective" in src
    assert "completed_ids" in src
    assert "func complete(" in src
    body = re.search(r"func complete\(.*?(?=\nfunc )", src, re.S).group(0)
    assert "_requirements_met" in body and "return false" in body

def test_result_rubric_is_transparent_and_has_all_five_grades():
    src = read("scripts/mission/mission_results.gd")
    for grade in ("S", "A", "B", "C", "D"):
        assert f'"{grade}"' in src
    assert "detections" in src and "alarms" in src and "secrets_found" in src
    assert "neutralized" in src
    assert "func evaluate(" in src


def test_optional_objectives_report_completed_and_incomplete_statuses():
    src = read("scripts/mission/mission_results.gd")
    for key in ("ghost_run", "no_kills", "all_secrets", "all_documents", "completed"):
        assert key in src
    assert "return [" in src


def test_collect_all_documents_is_a_distinct_optional_challenge():
    data = json.loads(read("data/missions/mission_01.json"))
    optional_ids = {entry["id"] for entry in data["optional_objectives"]}
    assert "all_documents" in optional_ids
    results = read("scripts/mission/mission_results.gd")
    assert '"id": "all_documents"' in results
    assert 'documents_collected' in results
