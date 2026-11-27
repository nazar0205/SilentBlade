"""Static contracts for v0.6. They read file text; they do not run Godot or the game."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
MAIN, PLAYER, ENEMY = read("scripts/main.gd"), read("scripts/player.gd"), read("scripts/enemy.gd")
PROJECT, PRESETS = read("project.godot"), read("export_presets.cfg")
APK_WF, VAL_WF = read(".github/workflows/android-build.yml"), read(".github/workflows/godot-validation.yml")


def test_guard_signal_fired_from_player_ready_cannot_touch_a_missing_hud():
    block = re.search(r"func _on_guard_changed\(.*?(?=\nfunc )", MAIN, re.S).group(0)
    assert "guard_bar == null" in block.split("guard_bar.max_value")[0]
    assert "SilentBladePlayer.GUARD_MAX" in MAIN


def test_world_has_a_fall_limit_for_player_and_enemies():
    assert "player.kill()" in MAIN and "func kill()" in PLAYER
    assert "FALL_LIMIT_Y" in ENEMY


def test_enemy_vision_variable_does_not_shadow_canvasitem_visible():
    assert "var visible" not in ENEMY


def test_player_keeps_an_air_jump_after_walking_off_a_ledge():
    assert "jump_count = 1" in PLAYER.split("func _update_jump_timers")[1].split("func _try_consume_jump_buffer")[0]


def test_input_map_is_not_duplicated_after_scene_reload():
    assert "action_erase_events" in MAIN


def test_project_is_ready_for_android_export():
    assert "import_etc2_astc=true" in PROJECT
    assert 'config/icon="res://icon.svg"' in PROJECT and (ROOT / "icon.svg").exists()
    assert "window/handheld/orientation=0" in PROJECT


def test_export_preset_is_arm64_only_and_not_gradle():
    assert 'platform="Android"' in PRESETS
    assert "architectures/arm64-v8a=true" in PRESETS
    for arch in ("armeabi-v7a", "x86", "x86_64"):
        assert f"architectures/{arch}=false" in PRESETS
    assert "gradle_build/use_gradle_build=false" in PRESETS


def test_android_workflow_uses_godot_4_3_builds_verifies_and_uploads_the_apk():
    assert 'GODOT_VERSION: "4.3"' in APK_WF
    assert "--export-debug \"Android\"" in APK_WF
    assert "lib/arm64-v8a/libgodot_android.so" in APK_WF
    assert "apksigner" in APK_WF and "verify" in APK_WF
    assert "actions/upload-artifact@v4" in APK_WF
    assert re.search(r"build/SilentBlade-debug\.apk.*?if-no-files-found: error", APK_WF, re.S)


def test_validation_workflow_fails_on_script_errors_and_runs_the_in_engine_test():
    assert "SCRIPT ERROR" in VAL_WF and "Parse Error" in VAL_WF
    assert "tests/godot/gameplay_smoke_test.gd" in VAL_WF
    assert (ROOT / "tests/godot/gameplay_smoke_test.gd").exists()


def test_in_engine_test_covers_simultaneous_fingers():
    t = read("tests/godot/gameplay_smoke_test.gd")
    for token in ("InputEventScreenTouch", "InputEventScreenDrag", "move_right", "block_held",
                  "jump_count", "release_all", "emulate_mouse_from_touch = false"):
        assert token in t
