# SILENT BLADE v0.7 — Test & Verification Report

## Changes verified statically

The final review also corrected early exit from enemy attack recovery, prevented repeated footsteps from restarting ALERT delay, corrected the lost-sight timer so it is not double-counted, moved a cover crate outside the Scout patrol lane, and aggregated enemy HUD state by priority.

- Python contract suite: **70 passed** (fresh full-suite run after the final source changes).
- Existing v0.6 combat/movement/multitouch contracts remain in the suite.
- Additional stealth tests cover: three differentiated perception profiles; required FSM states; FOV/range/physics ray; meter accumulation/decay; event data and fixed sound location; noise source coverage; decoy physics; cover/light exposure; non-zero visibility floor; level zone/obstacle construction; player/enemy signal wiring; HUD feedback; distraction touch button; attack recovery timer; repeated-noise alert timer; cover placement outside patrol corridors; and separate investigation/search/patrol origins.
- `project.godot` remains a Godot 4.3 GL Compatibility project with 1280×720 landscape viewport and existing `scenes/Main.tscn`.
- CI YAML and shell steps were parsed/validated locally; campaign JSON and scene/script references were checked.
- Final source archive integrity and a fresh test run from its extracted copy are checked by the release packaging step (reported in the delivery summary).

## Godot runtime status

**Not run in this environment.** No Godot/Godot 4 executable or container runtime was installed, and no project Git remote was configured to dispatch the GitHub Actions workflow. Therefore the following remain unverified:

- Godot 4.3 GDScript parse/import and class registration;
- headless launch of `Main.tscn`;
- `tests/godot/gameplay_smoke_test.gd`;
- `tests/godot/stealth_ai_test.gd` (added in this update);
- physics ray obstruction against all actual level collision geometry;
- Area2D cover overlap and stealth-zone behavior in a running scene;
- enemy state transitions, attack phases and distraction event under live simulation;
- actual Android touch cancellation/multitouch and performance.

The workflow `.github/workflows/godot-validation.yml` now includes Godot 4.3 import, 120-frame main scene smoke, existing gameplay/multitouch test and the new stealth AI behavior test. A green CI result has **not** been observed, because the workflow was not dispatched.

## Android APK

No APK was exported. The existing Android export preset/workflow is retained, but export templates and a connected GitHub Actions runner/device were not available here. The output is a complete Godot source project, not an installable APK.

## Known limitations

- AI navigation follows horizontal patrol/search coordinates only; no automated platform-to-platform jumps or NavigationServer pathfinding.
- Sound propagation uses distance/intensity and does not attenuate behind walls.
- Light/dark gameplay uses cheap exposure zones and procedural visuals, not dynamic Light2D shadow casting.
- `notify_interaction_noise()` is the integration hook for future interactable props; no full interaction/inventory system is added.
- Runtime behavior and Android device compatibility must be verified in Godot 4.3 and on a real device before treating this as release-ready.
