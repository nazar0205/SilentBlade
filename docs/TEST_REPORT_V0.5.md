# SILENT BLADE v0.5 — Test report

## Environment

- Project target: Godot 4.3, GDScript, Android landscape.
- Available here: Python 3 / pytest.
- Not available here: Godot executable, Godot 4.3 export templates, Android Debug Bridge, Android device, Git working copy/remote.

## Static test results

Command run from the project root:

```bash
pytest -q
```

Result: **32 passed** (18 existing v0.4.1 combat contract checks + 14 new movement contract checks).

The movement checks cover:

1. Ground/air jump limit and two charges.
2. Separate second-jump feedback.
3. Jump release cut and hold-gravity behavior.
4. 0.12-second coyote time and 0.15-second jump buffer, including buffered landing takeoff.
5. Grapple line-of-sight query before attaching.
6. Tangential swing acceleration and collision-aware rope-length constraint.
7. Velocity-preserving grapple detach and blocked-line detach.
8. Dash ramp, duration, cooldown and guard-break gate.
9. Dash detachment from grapple and retained exit momentum.
10. Full Android touch-cancel input reset.
11. Independent on-screen controls for joystick + held jump/button multitouch.
12. Virtual joystick cancellation and existing v0.4.1 combat/HUD/camera/mission wiring.

These are source-contract tests. They confirm required implementation paths are present and connected but are **not Godot runtime/physics tests**.

## Godot / GitHub Actions status

Godot 4.3 is not installed in this environment. An attempt to retrieve the official Linux binary failed because this environment cannot resolve external download hosts. The project contains a GitHub Actions workflow with Godot 4.3 import/parser and headless scene smoke commands; a Python static-contract job was added. The workflow could not be dispatched from this local ZIP because the workspace has no Git repository/remote configured and no repository identity was supplied.

Therefore none of the following is claimed as tested:

- Godot 4.3 script parsing/import.
- Main scene headless launch.
- Runtime normal jump, double jump, landing reset, coyote, jump-buffer timing or short/high jump trajectory.
- Actual pendulum motion, max-rope enforcement under varied collision contacts, wall/platform obstruction behavior or detachment trajectory.
- Dash movement and collision behavior in a running scene.
- Android multitouch/cancellation/focus-loss on a physical device.
- Android export/APK installation.

## Known verification risks

- Grapple obstruction currently tests collision layer 1, matching the project's current `StaticBody2D` platforms. New solid geometry on another layer must be added to the ray mask.
- The rope-length correction uses a short `move_and_collide()` after `move_and_slide()`. The source avoids direct position teleportation, but feel and corner cases must be playtested in Godot.
- Jump height, swing pumping and dash exit momentum have not been tuned against actual device frame rate/physics ticks.

## Files changed for v0.5

- `scripts/player.gd`
- `scripts/main.gd`
- `tests/test_movement_contract.py`
- `.github/workflows/godot-validation.yml`
- `README.md`
- `docs/V0.5_ADVANCED_MOVEMENT.md`
- `docs/TEST_REPORT_V0.5.md`
