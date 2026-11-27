# SILENT BLADE v0.8 — First Complete Mission Design

## Intent
Build one complete, replayable vertical-slice mission — **MISSION 01: THE SHADOW OF THE VILLAGE** — inside the existing Godot 4.3 project. The player infiltrates a Japanese village, disables its signal mechanism, retrieves war plans from an archive, and escapes. The mission should demonstrate traversal, stealth, combat, multiple routes, interactions, checkpoints, secrets, and a scored ending.

## Goals
- Replace the small v0.7 demonstration strip with a connected five-zone mission (outer perimeter, residential quarter, guarded courtyard, archive, evacuation).
- Provide a ground route, rooftop/grapple route, and concealed side route through a compact but substantial horizontal level.
- Add ordered primary objectives, optional challenges, secrets, and mission metrics.
- Make doors, signal console, archive documents, caches, checkpoints, and evacuation point usable through one proximity-based interaction system.
- Integrate global alarm with the existing NoiseSystem and EnemyAI hearing; do not create a second detection system.
- Preserve existing player movement, combat, enemy perception, stealth zones, touch routing, camera, pause, and title flow.
- Respawn at the most recent checkpoint without duplicating collected objects or erasing mission stats.
- Deliver a results screen with transparent S/A/B/C/D grading and real retry/continue/menu actions.
- Provide short contextual tutorial prompts and a persistent tutorial toggle.

## Non-goals
- Do not build the other 19 campaign missions.
- Do not replace existing enemy vision/hearing or player combat implementations.
- Do not add an inventory, save-slot UI, or complex dialogue system.
- Do not add heavy dynamic lighting or shader-heavy post-processing.
- Do not claim Android APK readiness without an actual export and device test.

## Constraints
- Godot 4.3, GDScript, GL Compatibility, Android landscape.
- Keep `scenes/Main.tscn` as the entry point and the existing dynamic construction pattern.
- Maintain all existing input actions and independent per-finger ownership.
- Reuse `SilentBladeNoiseSystem`, `SilentBladeStealthSystem`, `SilentBladeEnemy`, and `SilentBladePlayer` interfaces.
- Keep the mission data-driven where practical (`data/missions/mission_01.json`).

## Approaches considered
1. **Keep all mission code in `main.gd`.** Lowest initial refactor cost, but it expands an already large orchestration script and tangles objectives, checkpointing, interactions, and level layout.
2. **Add modular mission systems and a mission-level builder while retaining dynamic construction. (Selected.)** A builder owns platforms, routes, cover, stealth zones, visual dressing, enemy spawn descriptors and interactables. Small managers own objectives, interactions, alarm, checkpoints, tutorial and results. `main.gd` wires signals and updates HUD. This preserves the existing entry scene and existing actor scripts while separating ownership cleanly.
3. **Replace the dynamic world with a hand-authored packed scene hierarchy.** Potentially better for future level editing, but too much scene migration for a single mission addition and increases regression risk against the current code-generated level.

## Architecture
- `MissionLevelBuilder` creates the five-zone level, platform/roof routes, scenery, stealth zones, cover obstacles, spawn descriptors, grapple anchors, and `MissionInteractable` instances.
- `MissionManager` loads mission JSON, owns timer and persistent mission statistics, advances objectives, deduplicates collected item IDs, and emits objective/stat/result signals.
- `InteractionSystem` selects the nearest eligible interactable, exposes a context prompt, and dispatches one action on `interact` input.
- `MissionInteractable` owns the local prompt, one-shot semantics and door collision state; it emits an interaction signal and leaves mission decisions to the manager/orchestrator.
- `AlarmSystem` owns alarm mode and broadcasts the signal event through the current NoiseSystem; enemies respond through the existing `on_noise_event` path.
- `CheckpointSystem` owns last checkpoint position and alarm snapshot. On death, `main.gd` restores player state and rebuilds enemies from the builder spawn descriptors; mission statistics and collected IDs live in `MissionManager` and persist.
- `TutorialSystem` owns timed contextual hints and the persistent on/off setting.
- `MissionResults` evaluates grade from explicit stats and thresholds.
- `touch_controls.gd` gains one context-only interaction button. It uses the existing per-finger routing and releases through existing cancellation/focus-loss paths.

## Primary objective sequence
1. Enter the village.
2. Disable the signal mechanism.
3. Retrieve the war-plan document from the archive.
4. Reach and activate evacuation.

The alarm objective is a mission goal, but retrieving the archive remains possible while the alarm is active. Evacuation is locked until the archive document is collected.

## Optional objectives and secrets
- Complete with zero detections.
- Neutralize no enemies.
- Find the hidden cache and the field report (two optional discoveries).
- The archive document is the primary mission item and is not counted as a secret.

## Alarm behavior
- Enemy detection creates a local alert.
- If the signal mechanism is still active and a guard spots the player in the guarded courtyard, the system raises a global alarm once and emits a high-radius `GLOBAL_ALARM` event at the signal tower.
- Every enemy learns the event through NoiseSystem and investigates its fixed source location. No enemy receives a continuously updated player location from the alarm.
- Interacting with the signal console disables future global broadcasts; already-alerted enemies finish their current chase/search and return through their existing FSM.

## Checkpoint behavior
- Initial checkpoint at mission start; two later checkpoint shrines on the main route.
- Checkpoint stores player respawn position and alarm-enabled state. MissionManager separately preserves completed objective IDs, collected item IDs, detections, alarms, secrets and neutralizations.
- Death respawns the player with restored health/invulnerability and rebuilds the enemy roster from spawn descriptors. Collected objects and opened doors are re-applied from persistent mission state, preventing duplicate rewards.

## Results and grade rubric
- **S:** successful evacuation, zero detections, zero alarms, all secrets, zero neutralizations.
- **A:** successful evacuation, zero detections, at most one alarm, at least one secret.
- **B:** successful evacuation, at most two detections and at most two alarms.
- **C:** successful evacuation with any other non-perfect result.
- **D:** mission failure. (Checkpointed death does not fail the mission.)

Results display elapsed time, detections, alarm activations, secrets, optional challenges and neutralized enemies. Retry reloads the mission, Continue opens an honest campaign transition panel noting that Mission 02 is not part of this release, and Menu returns to the briefing/title screen.

## Visual and mobile decisions
- Use the existing procedural art direction but add deliberate village silhouettes, tiled roof profiles, lantern pools, bamboo clusters, layered hills, moon, low-cost fog strips and subtle falling leaves. No unlicensed third-party assets.
- Use lightweight procedural drawing/particles and stealth zones rather than dynamic shadow casting.
- Keep 1280x720 design coordinates and use stretch `expand` so 16:9 and 19.5:9 viewports expose extra horizontal space without vertical cropping. The touch layer computes positions from actual viewport size.
- Add only one context interaction button, visible only when a usable object is nearby.

## Open implementation choices
- Exact prop coordinates and route shapes are builder choices, subject to the five-zone progression and at least three viable approaches into/through the central compound.
- The mission remains one scene for now; builder and manager modules keep future extraction possible.
