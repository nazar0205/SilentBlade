from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_original_mission_audio_assets_are_present_and_nonempty():
    expected = (
        "night_ambience.wav",
        "wood_step.wav",
        "grass_step.wav",
        "interaction.wav",
        "document_pickup.wav",
        "alarm_signal.wav",
    )
    for name in expected:
        path = ROOT / "assets/audio" / name
        assert path.is_file()
        assert path.stat().st_size > 1000


def test_night_ambience_is_looped_and_starts_when_mission_begins():
    main = read("scripts/main.gd")
    assert "func _build_audio(" in main
    assert "AudioStreamWAV.LOOP_FORWARD" in main
    assert "ambience_player.play()" in main
    assert "night_ambience.wav" in main


def test_player_noise_events_play_surface_appropriate_footsteps():
    main = read("scripts/main.gd")
    body = main.split("func _on_player_noise(", 1)[1].split("\nfunc ", 1)[0]
    assert 'event_type == "SNEAK_STEP"' in body
    assert 'event_type == "FOOTSTEP"' in body
    assert "_play_footstep(_is_player_in_grass(), true)" in body
    assert "_play_footstep(_is_player_in_grass())" in body
    assert "GrassStepSound if is_grass else WoodStepSound" in main
    assert "volume_db = -18.0 if sneaking else -13.0" in main


def test_interaction_pickup_and_alarm_events_have_audible_feedback():
    main = read("scripts/main.gd")
    assert 'const InteractionSound = preload("res://assets/audio/interaction.wav")' in main
    assert 'const DocumentPickupSound = preload("res://assets/audio/document_pickup.wav")' in main
    assert 'const AlarmSignalSound = preload("res://assets/audio/alarm_signal.wav")' in main
    assert '_play_mission_effect(DocumentPickupSound' in main
    assert '_play_mission_effect(InteractionSound' in main
    assert '_play_mission_effect(AlarmSignalSound' in main


def test_tutorial_hints_can_be_dismissed_by_the_corresponding_action():
    tutorial = read("scripts/mission/tutorial_system.gd")
    main = read("scripts/main.gd")
    assert "func complete_hint(" in tutorial
    assert "func get_active_hint_id(" in tutorial
    assert "_update_tutorial_completion()" in main
    for hint_id in ("move", "grass", "roofs", "decoy", "alarm", "interact"):
        assert f'"{hint_id}"' in main
    mission = __import__("json").loads(read("data/missions/mission_01.json"))
    assert mission["tutorial"][0]["x"] <= mission["spawn"]["x"]
