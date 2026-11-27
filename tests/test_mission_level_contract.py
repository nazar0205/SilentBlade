"""Data/layout contracts for the playable Mission 01 level builder."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")

def test_mission_level_builder_builds_from_data_and_returns_spawn_descriptors():
    src = read("scripts/mission/mission_level.gd")
    for token in ("func build(", "enemy_spawns", "grapple_anchors", "interactables", "mission_01.json", "SilentBladeStealthZone"):
        assert token in src

def test_level_builds_all_five_zones_and_multi_route_layout():
    data = json.loads(read("data/missions/mission_01.json"))
    zones = data["zones"]
    assert len(zones) == 5
    assert all(len(zone["route_types"]) >= 2 for zone in zones)
    assert data["world_width"] >= 6000
    assert zones[0]["from"] == 0 and zones[-1]["to"] == data["world_width"]

def test_level_has_enough_mixed_enemy_spawns_for_a_mission_not_a_test_arena():
    data = json.loads(read("data/missions/mission_01.json"))
    spawns = data["enemy_spawns"]
    assert len(spawns) >= 7
    assert {entry["type"] for entry in spawns} == {"Guard", "Scout", "Heavy Guard"}
    assert len({entry["id"] for entry in spawns}) == len(spawns)

def test_level_interactables_cover_objects_checkpoints_secrets_and_extract():
    src = read("scripts/mission/mission_level.gd")
    for object_id in ("village_gate", "signal_console", "archive_orders", "hidden_cache", "field_report", "evacuation_exit", "village_checkpoint", "archive_checkpoint"):
        assert object_id in src
    assert "MissionInteractableScript.new()" in src
    assert "register_interactable" not in src  # interaction system owns registration

def test_builder_contains_physical_routes_and_stealth_zones_not_only_decoration():
    src = read("scripts/mission/mission_level.gd")
    assert "StaticBody2D.new()" in src and "CollisionShape2D.new()" in src
    for kind in ('"GRASS"', '"COVER"', '"DARK"', '"LIGHT"'):
        assert kind in src
    assert "add_stealth_zone" in src or "_add_stealth_zone" in src

def test_main_uses_level_builder_and_spawns_enemies_from_mission_data():
    src = read("scripts/main.gd")
    assert "MissionLevelScript" in src
    assert "mission_level.enemy_spawns" in src
    assert "mission_level.grapple_anchors" in src
    assert "_build_world()" in src
