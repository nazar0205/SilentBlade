# SILENT BLADE — development build v0.3

Godot 4.x 2D side-scrolling stealth-action project, Android landscape target.

## v0.3 fixes
- Set `window/handheld/orientation=0` for landscape.
- Grapple rope constraint is now evaluated on every player physics tick while attached.
- Replaced separate left/right touch buttons with a virtual analog joystick that emits a continuous horizontal axis and supports multitouch alongside action buttons.
- Re-anchored houses and lanterns to platform-top world coordinates; houses are drawn upward from their base.
- Replaced the goal text mutation with a mission-results overlay showing success/failure, rank, elapsed time, detections and defeated enemies; replay reloads the mission.
- Kept the project on Godot 4 scene format and typed GDScript patterns.

## Controls
- Desktop development: A/D or arrows move; Space/W/Up jump; S/Down crouch.
- Shift dash; E grapple; J/Z katana; Esc pause.
- Android: left analog virtual joystick; right-side action buttons. The joystick and buttons are separate Controls, so simultaneous touch is supported.

## Run and validate
Open this folder in Godot 4.3+ and run the project (F6/F5), or execute:

```bash
godot --headless --path . --editor --quit
godot --path .
```

The current execution environment did not contain Godot, Godot 4, ADB or Gradle. Therefore the v0.3 scripts were edited and statically inspected, but no Godot import/parse, runtime gameplay test, Android export, APK install or physical-device multitouch test is claimed.

## Scope
This remains a development build. It is not the final campaign or an Android APK. The art remains procedural placeholder art; full sprite animation, campaign levels, bosses, progression and persistent saves are not yet complete.

## Asset provenance
No third-party artwork, music, fonts or commercial game assets are included. Current visuals are procedurally drawn in GDScript.


## v0.3.1 technical stabilization
- Strongly typed the enemy target as `SilentBladePlayer`.
- Added input release on application/window focus loss.
- Added a virtual joystick cancellation method.
- Added GitHub Actions validation for Godot 4.3 import/parser and main-scene smoke launch.
- See `docs/V0.3.1_STABILIZATION.md` for exact scope and verification limits.
