# SILENT BLADE v0.8 — TEST REPORT

## Environment

- Target: Godot 4.3, GDScript, Android landscape.
- Local authoring container: Python/pytest available; Godot 4.x, Android SDK/ADB, Docker/Podman and a configured Git remote unavailable.
- Therefore this report distinguishes static source tests from Godot runtime checks. No APK or on-device test is claimed.

## Python test suite

Run:

```bash
python -m pytest -q
```

Final fresh run: **113 passed**. These tests verify mission JSON, prerequisites, unique collection IDs, result rules (including the all-documents optional challenge), viewport-centered overlays, mission-failure results wiring, level/interactable wiring, touch control integration, WAV assets, and regression contracts from v0.4.1–v0.7. They read code/configuration and are not a substitute for running the game.

## Godot tests added (not locally executed)

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 120
godot --headless --path . -s tests/godot/gameplay_smoke_test.gd
godot --headless --path . -s tests/godot/stealth_ai_test.gd
godot --headless --path . -s tests/godot/mission_systems_test.gd
```

- `gameplay_smoke_test.gd` now checks the v0.8 title control, double jump, second-jump effect, context interaction touch, multitouch independence and checkpoint respawn instead of the obsolete v0.7 game-over expectation.
- `stealth_ai_test.gd` is retained for v0.7 vision/hearing/FSM regression.
- `mission_systems_test.gd` exercises objective ordering, extraction gating, unique collection, S/A/B/C/D grade examples, checkpoint snapshot/restore, alarm broadcast location/idempotency, interactive object gating/noise, and the actual data-driven mission level's spawns/interactables/stealth zones.

The workflow `.github/workflows/godot-validation.yml` invokes all three scripts after the Godot 4.3 project import and main-scene smoke launch. Workflow execution has not been performed from this environment; there is no configured remote to dispatch it.

## Android export

`export_presets.cfg` is updated to version code 8 / version name 0.8.0. `.github/workflows/android-build.yml` remains configured to download Godot 4.3, install Android build dependencies and export a debug arm64-v8a APK. No Android export was run locally and no APK is bundled.

## Known unverified items

- GDScript parser/import and scene instantiation in the real Godot 4.3 engine.
- Physical collision feel and route playability across the complete 6,200 px map.
- Alarm reaction timing and all stealth routes in a live play session.
- Audio loudness/mix on phone speakers/headphones.
- 16:9 and 19.5:9 visual layout on actual devices.
- Android touch cancellation/focus behavior on physical hardware.
- APK build, installation and performance profiling.

## Known limitations

- Enemy locomotion is still horizontal patrol/search behavior; no cross-platform navigation or autonomous vertical traversal.
- Dynamic real-time shadows are replaced by low-cost DARK/LIGHT stealth zones.
- Sound is distance/intensity based and has no wall occlusion.
- Checkpoints persist within the current run, not across application restarts.
- Mission 02 is only a campaign handoff panel and is not included in v0.8.
