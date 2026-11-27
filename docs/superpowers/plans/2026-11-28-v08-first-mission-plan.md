# SILENT BLADE v0.8 — First Complete Mission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Turn the existing v0.7 stealth-action prototype into one complete, replayable mission with connected objectives, interactions, alarm, checkpoints, tutorial, secrets and graded extraction.

**Architecture:** Keep `Main.tscn` and the dynamic level construction pattern. Move mission-specific geometry and dressing into `MissionLevelBuilder`; add focused mission modules; keep existing Player/Enemy/AI/Stealth scripts as authorities for their mechanics. `main.gd` wires signals, HUD and lifecycle only.

**Tech Stack:** Godot 4.3, GDScript, JSON mission data, Python/pytest static contracts, Godot headless scripts in CI.

**Spec:** `docs/superpowers/specs/2026-11-28-v08-first-mission-design.md`

## Global Constraints
- Keep Godot 4.3, GDScript, Android landscape, GL Compatibility.
- Preserve `scenes/Main.tscn` and existing v0.7 movement/combat/AI/stealth/touch APIs.
- Do not create any campaign mission beyond Mission 01.
- Do not add dynamic shadow rendering or heavy mobile effects.
- Continue to distinguish static tests from Godot runtime tests.

## Review Focus
- Death immediately after collecting the document must not duplicate it or roll back already-earned objective progress.
- A global alarm must notify enemies through the existing NoiseSystem and must not leak live player coordinates.
- The context interaction button must not overlap or steal an already-owned touch and must release on cancellation/focus loss.
- Evacuation must stay locked until the archive document is actually collected.
- The 19.5:9 viewport must not crop the player, objective panel or interaction controls.

---

### Task 1: Mission data, objectives and results

**Files:**
- Create: `data/missions/mission_01.json`
- Create: `scripts/mission/objective_manager.gd`
- Create: `scripts/mission/mission_results.gd`
- Create: `scripts/mission/mission_manager.gd`
- Test: `tests/test_mission_contract.py`

**Interfaces:**
- `MissionManager.start_mission(config: Dictionary) -> void`
- `MissionManager.complete_objective(objective_id: String) -> bool`
- `MissionManager.collect_item(item_id: String, item_kind: String) -> bool`
- `MissionManager.record_detection()`, `record_alarm()`, `record_neutralization()`
- `MissionManager.get_results(success: bool) -> Dictionary`
- `ObjectiveManager.current_objective() -> Dictionary`, `complete(id) -> bool`
- `MissionResults.evaluate(stats: Dictionary) -> String`

- [ ] Write failing data and contract tests for 4 primary objectives, 3 optional objectives, 2 secrets, ordering, deduplication and grade thresholds.
- [ ] Run `python -m pytest tests/test_mission_contract.py -q` and confirm expected failures.
- [ ] Implement mission JSON and the three scripts.
- [ ] Run the focused tests and full suite.

### Task 2: Interactions, alarm and checkpoint systems

**Files:**
- Create: `scripts/mission/mission_interactable.gd`
- Create: `scripts/mission/interaction_system.gd`
- Create: `scripts/mission/alarm_system.gd`
- Create: `scripts/mission/checkpoint_system.gd`
- Test: `tests/test_interaction_alarm_checkpoint_contract.py`

**Interfaces:**
- Interactables emit `interacted(interactable)` and expose `interact(player)`, `set_open(value)` and `set_consumed(value)`.
- `InteractionSystem.register_interactable(node)`, `interact()`, `get_current_prompt()`.
- `AlarmSystem.raise_local_alert(pos)`, `raise_global_alarm(pos)`, `disable_alarm()`, `restore_enabled(value)`.
- `CheckpointSystem.activate(id, pos, alarm_enabled)`, `get_snapshot()`, `reset()`.

- [ ] Write failing tests for eligibility, one-shot collection, door state, alarm idempotence, event location and checkpoint snapshot.
- [ ] Run focused tests and confirm failures.
- [ ] Implement modules; route global alarm through `NoiseSystem.emit_noise`.
- [ ] Run focused tests and full suite.

### Task 3: Mission level builder and multi-route map

**Files:**
- Create: `scripts/mission/mission_level.gd`
- Modify: `scripts/main.gd`
- Test: `tests/test_mission_level_contract.py`

**Interfaces:**
- `MissionLevel.build(stealth_system: SilentBladeStealthSystem) -> void`
- Read-only `enemy_spawns: Array[Dictionary]`, `grapple_anchors: Array[Vector2]`, `interactables: Array[SilentBladeMissionInteractable]`.

- [ ] Write failing tests for five named zones, multiple route types, spawn descriptor count/type, interactable ID uniqueness and all mission objective sites.
- [ ] Run focused tests and confirm failures.
- [ ] Implement the 5-zone level with ground/roof/secret routes, physical cover, stealth zones, scenery, landmarks and interactive props.
- [ ] Move world background drawing into the level builder and expand camera limits to the mission end.
- [ ] Run focused tests and full suite.

### Task 4: Touch interaction, tutorials and mission HUD/results integration

**Files:**
- Create: `scripts/mission/tutorial_system.gd`
- Modify: `scripts/input/touch_controls.gd`
- Modify: `scripts/main.gd`
- Modify: `project.godot`
- Test: `tests/test_mission_ui_contract.py`

- [ ] Write failing tests for dynamic context button, interaction action mapping, tutorial toggle, objective HUD, result buttons and wide aspect mode.
- [ ] Run focused tests and confirm failures.
- [ ] Implement UI wiring, context prompt, contextual tutorial, mission briefing, results/continue/menu screens and `expand` aspect handling.
- [ ] Run focused tests and full suite.

### Task 5: Checkpoint respawn and regression integration

**Files:**
- Modify: `scripts/player.gd` (only if a respawn reset API is necessary)
- Modify: `scripts/enemy.gd` (only if a mission alarm entry point is necessary; prefer existing hearing API)
- Modify: `scripts/main.gd`
- Create: `tests/godot/mission_systems_test.gd`
- Modify: `.github/workflows/godot-validation.yml`
- Modify: `.github/workflows/android-build.yml` (version name/code only if needed)
- Test: all Python tests and Godot scripts

- [ ] Add regression tests for checkpoint persistence, no duplicate collectibles, alarm restore, evacuation lock and combat/AI/touch contracts.
- [ ] Add Godot runtime tests for objective sequence, alarm broadcast, interaction deduplication, result ranks, and checkpoint snapshot.
- [ ] Implement respawn/rebuild of enemies from builder descriptors while retaining mission progress.
- [ ] Run all Python tests; run Godot headless commands if Godot exists. Do not label unrun Godot tests as passed.

### Task 6: Documentation, packaging and final review

**Files:**
- Modify: `README.md`
- Create: `docs/V0.8_FIRST_MISSION.md`
- Create: `docs/TEST_REPORT_V0.8.md`
- Create: `docs/CHANGELOG_V0.8.md`
- Create final ZIP.

- [ ] Document controls, objective sequence, mission routes, checkpoints, grade rubric, architecture, known limitations and verification evidence.
- [ ] Run `python -m pytest -q` from a fresh extraction of the final ZIP.
- [ ] Run `unzip -t` and compute SHA-256.
- [ ] Perform a separate source review for Critical/Important issues; fix any Critical/Important finding with a failing test first.
