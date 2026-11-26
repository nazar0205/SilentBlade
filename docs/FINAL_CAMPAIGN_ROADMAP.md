# SILENT BLADE — production roadmap and release gates

## Product definition
A single-player, offline, landscape Android 2D stealth-action platformer built with Godot 4.x and GDScript. Target campaign: 20 handcrafted missions across five regions, six distinct boss encounters (within the requested 5–8 range), five functional weapons, three gameplay-affecting skill trees, secrets, optional challenges, rank scoring, replay and a complete ending.

## Non-negotiable release rule
The game is not complete because a feature is listed in data or shown in UI. A feature is complete only when it is implemented, integrated into a playable mission, tested, and its result is recorded. Do not label the game release-ready until the final APK has been installed and tested on Android hardware.

## Production phases
1. **Foundation repair:** resolve parse/runtime errors in the v0.1 project; establish stable input, scene ownership, player/enemy interfaces and test harness.
2. **Core movement:** movement, jump buffering/coyote time, crouch, dash, grapple anchor selection, rope constraint/swing and checkpoint reset.
3. **Combat and enemy AI:** weapon data model, hitboxes/hurtboxes, combo windows, enemy states, perception, investigation, alert, search and recovery.
4. **Stealth readability:** cover/grass concealment, light exposure, sound propagation, alert feedback and alternate routes.
5. **Mobile UX:** multitouch controls, safe areas, scalable layout, remappable button positions/sizes/opacity, pause/resume and lifecycle handling.
6. **Progression and persistence:** versioned local saves, mission unlocks, skill trees with real effects, inventory, rank records and corruption recovery.
7. **Vertical slice completion:** one fully art-directed mission with all core systems, tutorialization, checkpoint, secrets, scoring, audio and a clear end state.
8. **Campaign production:** build all 20 missions from reusable mechanics but unique layouts, objectives, encounter compositions and environmental art.
9. **Bosses and narrative:** six distinct boss fights, story beats, ending, post-campaign replay.
10. **Polish and release:** accessibility, balance, performance profiling, device matrix, Android export, install/run verification, license inventory and evidence report.

## Quality gates
- **G0 — project opens:** Godot editor imports the project without parse errors; main scene launches.
- **G1 — core movement:** touch controls operate the character; collision, camera and reset are stable.
- **G2 — full core loop:** stealth, combat, grapple, dash, enemy states, death, checkpoint and mission completion work in one level.
- **G3 — production vertical slice:** complete first mission with final-quality original art/audio and save/load.
- **G4 — campaign complete:** all 20 missions and all bosses are playable and completable; no placeholder mission exits.
- **G5 — release candidate:** all saves, controls, settings, resolution handling and performance checks pass.
- **G6 — Android release verified:** exported APK installs and launches on physical Android device; campaign smoke tests and save persistence pass.

## Current evidence
The supplied v0.1 archive was inspected. It contains one main scene and scripts for the player, one guard and the main scene. The current visuals are procedurally drawn placeholder shapes. The archive contains a malformed statement in `scripts/main.gd` where two statements were joined on one line; this snapshot repairs that syntax-level issue.

Godot, Godot 4, Android Debug Bridge and Gradle were not found in the current execution environment. Therefore no Godot import, gameplay run, Android export, APK installation or device test is claimed here.

## Scope discipline
The campaign manifest in `data/campaign.json` is planning data, not implemented gameplay. Mission names, boss concepts, weapons and skill trees become release features only after their corresponding mechanics, assets, level scenes and tests exist.
