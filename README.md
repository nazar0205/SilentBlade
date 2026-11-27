# SILENT BLADE v0.8 — FIRST COMPLETE MISSION

Godot 4.3 · GDScript · 2D stealth-action platformer · Android landscape

**MISSION 01 — THE SHADOW OF THE VILLAGE** is the first complete vertical slice. It extends the uploaded v0.7 project in place; the player, combat, stealth, enemy AI, input layer and main scene architecture are retained.

## Mission

Рэн infiltrates the night village controlled by warlord Kurogane, disables its signal mechanism, retrieves the military plans from the archive and escapes through the extraction point.

The 6,200-pixel level has five connected areas:

- **A — Outer perimeter:** first patrol, grass, dark zones and a low-ground approach.
- **B — Residential quarter:** houses, lanterns, roof platforms, street patrols and a hidden cache.
- **C — Guarded courtyard:** Scout and Heavy Guard, watchtower, alarm console and signal-locked passage.
- **D — Archive:** guarded archive, roof access, side door, field report and mission document.
- **E — Evacuation:** lower route and a connected roof route to the extraction point.

The player can use the ground route, traverse roofs with the grapple, use the hidden passage after disabling the signal, distract guards, or fight through. The main document and signal objectives can be completed in either order; extraction requires both.

## Controls

- **Desktop:** A/D or arrows move; Space/W/Up jump (tap for a short jump, hold for higher); second press in air performs the double jump; S/Down crouch.
- **Shift:** dash; **E:** grapple (tap to attach, tap again to release); **J/Z:** katana; **hold K/X:** block/parry; **G:** distraction; **F:** contextual interaction; **Esc:** pause.
- **Android:** left analog virtual joystick; independent action buttons. The contextual `ДЕЙСТВИЕ` button appears only near usable objects. Each finger has an independent owner, so movement and interactions/combat actions can be combined.

## Mission systems

- `MissionManager` owns objectives, world flags, unique collection IDs, counters and mission completion/failure. Scripted failure rules call `_fail_mission(reason)` and open the D-grade results screen; ordinary player death uses checkpoints and is not an automatic mission failure.
- `ObjectiveManager` enforces prerequisite-based objective progression. The archive can be collected before the alarm is disabled; evacuation remains locked until both are complete.
- `InteractionSystem` selects the nearest available object and exposes a contextual touch prompt. Doors have physical collision until opened; one-shot items are deduplicated by stable IDs.
- `AlarmSystem` drives CALM / LOCAL_ALERT / GLOBAL_ALARM. The signal broadcasts one noise event from the device location into the existing v0.7 `NoiseSystem`; guards respond through their existing AI, not a second detection implementation.
- `CheckpointSystem` stores position, alarm-device state and a progress snapshot. On death, the current run's collected IDs/objectives/stats remain live, world objects are reconciled from those IDs/flags, and enemies are recreated at their configured patrol spawns. Time and performance counters are not rewound.
- `TutorialSystem` has a persistent enable/disable setting. Short hints can disappear on the corresponding action or by timeout.
- `MissionResults` scores S/A/B/C/D and lists all optional objectives. S/A/B use explicit time thresholds plus stealth/objective conditions; C is other successful completion; D is mission failure.
- Optional challenges: finish without detection (`ghost_run`), without neutralizations (`no_kills`), find both secrets (`all_secrets`) and collect both documents (`all_documents`). All are independent from extraction requirements.

## Sound and visuals

The mission uses the project's procedural night-village art direction: moonlit parallax silhouettes, Japanese-style houses, roofs, lanterns, bamboo, watchtower, archive facade, low-cost fog and falling leaves. Six original generated PCM WAV assets provide a looped night ambience, wood/grass footsteps, interaction feedback, document pickup and alarm signal. No third-party artwork/audio is included.

## Run and validate

Open the project folder in **Godot 4.3** and run `scenes/Main.tscn` (F6/F5). Headless commands:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 120
godot --headless --path . -s tests/godot/gameplay_smoke_test.gd
godot --headless --path . -s tests/godot/stealth_ai_test.gd
godot --headless --path . -s tests/godot/mission_systems_test.gd
python -m pytest -q
```

The GitHub Actions workflow contains Python static contracts, Godot 4.3 import/scene smoke tests, multitouch/gameplay tests, AI/stealth tests and mission-system tests. A separate workflow is configured to build a debug Android arm64 APK.

**Verification limitation for this delivery:** the authoring environment did not have Godot 4.3, Android SDK/ADB, Docker/Podman or a configured Git remote. Python tests and archive checks can run locally here; Godot headless tests and Android export are included in CI but were not executed in this environment. No APK is bundled.

## Known scope limits

- Enemy patrol/search movement remains horizontal and uses placed patrol bounds; there is no cross-platform navmesh/pathfinding or autonomous enemy jumping.
- Light/dark are low-cost stealth exposure zones, not dynamic `Light2D` shadow casting.
- Sound is radius/intensity based and is not attenuated by walls.
- Checkpoints are run-session checkpoints, not persistent disk save slots. Unique item IDs and world flags prevent duplication during death/respawn within the active run.
- `ПРОДОЛЖИТЬ` displays an honest campaign handoff; Mission 02 is not included in v0.8.
- The level is a vertical slice, not the complete multi-mission campaign.

## Asset provenance

No third-party artwork, music, fonts or commercial assets are included. Level art and VFX are procedural GDScript drawing; the WAV sound effects and ambience are original synthesized assets generated for this mission.
