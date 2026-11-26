# SILENT BLADE — development build v0.5

Godot 4.3 2D side-scrolling stealth-action project, Android landscape target. This release extends the existing v0.4.1 project in place.

## Controls

- Desktop: A/D or arrows move; Space/W/Up jump (tap for a short jump, hold for higher); second press in air performs the double jump; S/Down crouch.
- Shift dash; E grapple (tap to attach, tap again to release); J/Z katana; hold K/X to block/parry; Esc pause.
- Android: left analog virtual joystick; right-side action buttons. The independent jump button supports hold/release height control and repeat taps for double jump. Joystick and action buttons retain separate touch ownership for multitouch.

## v0.5 advanced movement

- Two-stage jump: ground/coyote jump plus one airborne jump, with landing reset and separate second-jump visual response.
- Coyote time: 0.12 s. Jump buffer: 0.15 s. Short jump on release; holding jump lowers gravity for the early rise.
- Physical grapple swing: tangent acceleration, preserved momentum, no attach snap, collision-aware rope constraint using `move_and_collide()`, and a physics ray query that blocks attachment through world geometry. A blocked line detaches without deleting velocity.
- Dash with a smooth acceleration ramp, 0.20 s duration, 0.82 s cooldown and 0.22 s momentum exit window. Dash detaches grapple while retaining current motion and is unavailable during guard break.
- Android canceled touches and application/window focus loss share a full input release path.

See [docs/V0.5_ADVANCED_MOVEMENT.md](docs/V0.5_ADVANCED_MOVEMENT.md) for implementation details and movement parameters.

## Preserved v0.4.1 systems

- Three-hit combo profiles and shared physics attack hitbox.
- Guard, Scout and Heavy Guard enemy profiles, knockback, damage and one-shot death handling.
- Hold-to-block, 0.18-second parry window, guard stamina, guard break and counterattack bonus.
- Enemy telegraph → execution → recovery phases.
- Camera, HUD, virtual joystick, title screen, pause panel, mission results and replay.
- Godot 4 scene format, GL Compatibility renderer and Android landscape orientation.

## Run and validate

Open this folder in Godot 4.3 and run the project (F6/F5), or execute:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 120
godot --path .
```

Run the static contract suite with:

```bash
python -m pytest -q
```

The current environment has no Godot executable, export templates, ADB, Android device or Git remote. The latest local static suite reports 32 passed. No Godot import/parser, headless runtime, in-game physics, Android multitouch or APK export is claimed. `.github/workflows/godot-validation.yml` contains both the Python contract job and Godot 4.3 import/headless-smoke job; push the project to a GitHub repository to trigger it.

## Scope and assets

This remains a development source build, not the final campaign and not an APK. Several visuals are procedural placeholders. No third-party artwork, music, fonts or commercial game assets are included.
