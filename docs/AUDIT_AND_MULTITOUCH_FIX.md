> **Correction (v0.5.2).** The v0.5.1 text below described the multitouch fix as done, but the ZIP that was
> audited still contained the old code: `main.gd` built `Button` nodes plus `virtual_joystick.gd`, and
> `scripts/input/touch_controls.gd` was never instantiated. The fix was actually applied in v0.5.2:
> `main.gd` now builds `SilentBladeTouchControls`, `virtual_joystick.gd` is deleted, the "any cancelled touch
> resets everything" handler is removed, and the layer is enabled on mission start / disabled on results.
> Static contract tests: 36 passed. Still NOT verified: Godot parse/import, headless run, any real device.

# SILENT BLADE — audit of the v0.5 source and multitouch fix (v0.5.1)

## 1. Architecture map (what is actually in the repository)

| File | Role | State |
|---|---|---|
| `scenes/Main.tscn` | One node, runs `scripts/main.gd` | works as a single demo scene |
| `scripts/main.gd` (~490 lines) | Builds the whole level, HUD, pause, title, results in code | monolith: world, UI, mission logic mixed together |
| `scripts/player.gd` (532) | Movement, double jump, coyote/buffer, dash, grapple, 3-hit combo, block/parry | implemented |
| `scripts/enemy.gd` (308) | 3 profiles (Guard / Scout / Heavy Guard), telegraph → attack → recovery, simple vision | implemented, but see "gaps" |
| `scripts/input/touch_controls.gd` (424) | Raw-touch layer: stick + 6 buttons + pause | existed in the ZIP but was **not used by anything** |
| `scripts/virtual_joystick.gd` | Old `Control` joystick | removed in v0.5.1 |
| `data/campaign.json` | 5 regions / 20 mission titles | data only, no levels behind it |
| `tests/*.py` | Python source-contract tests | static only |

## 2. Implemented vs. missing (against the technical specification)

Implemented in code: movement, double jump, coyote 0.12 s, jump buffer 0.15 s, variable jump height, dash (0.20 s / 0.82 s), physical grapple with line-of-sight ray, 3-hit combo with per-swing hit dedup, block, 0.18 s parry, guard stamina and break, counter window, 3 enemy profiles, title / pause / results screens.

Not implemented (do not exist in the repo): saves, settings, mission select, skill tree, weapon select, more than one level, bosses, ranged / elite / commander enemies, hearing / noise, search-and-return AI states, sprites and animations, audio, secrets, checkpoints, S/A/B/C rating with rewards (only a crude S/A/B), 4 of the 5 regions.

Enemy vision gaps that matter for stealth: the check is `facing && |dx| < aggro_range && |dy| < 100 && !crouching` — **no line-of-sight ray**, so enemies see through walls. States are `PATROL / SUSPICIOUS / ALERT` plus combat states; there is no `SEARCH` or `RETURN`.

## 3. Root cause of the critical multitouch bug

`main.gd` created the action buttons as Godot `Button` nodes and drove `Input.action_press/release` from `button_down/button_up`. A `Button` only reacts to **mouse** events. On Android, touches are converted to mouse events for a single finger only (the first one that is down). While the thumb is on the stick, the second finger produces no mouse event, so no button sees it. This matches the reported behaviour (jump/attack dead while moving).

`scripts/input/touch_controls.gd` already contained the right design, but `main.gd` never instantiated it and the tests still asserted the old `Button` code.

## 4. What changed in v0.5.1

- `main.gd`: builds `TouchControlsScript` instead of the joystick + `Button`s; pause comes from `pause_pressed`; the layer is disabled on the title screen and enabled on mission start; focus loss calls `touch_controls.release_all()` plus `player.release_controls()`.
- `main.gd`: removed the global "any cancelled touch resets all input" handler. A cancelled finger is now ended per finger inside the touch layer, so it cannot drop the other fingers.
- `scripts/virtual_joystick.gd`: deleted (replaced).
- Debug builds (`OS.is_debug_build()`) draw a live line mid-screen: `пальцев: N (учтено M) | стик: x | кнопки: ...` — use it to confirm multitouch on the phone.
- Tests: 3 old tests that asserted the `Button` implementation were replaced by 8 contract tests for the touch layer. Total 37.

Touch-layer rules (unchanged from the existing file): each finger index gets exactly one owner on touch-down (button / stick / pause) and keeps it until lift or cancel; releasing a finger releases only its own action; a tap is kept down until at least one physics tick has seen it, so very short taps are not swallowed by `is_action_just_pressed`.

## 5. Verification status — read this

Checked: Python source-contract tests, 37 passed (run through a plain runner; pytest could not be installed offline). Brace/indent sanity of the edited `.gd` files.

**Not checked:** Godot parse/import, headless run, the scene running at all, physics feel, **multitouch on a real Android device**, APK export. The sandbox used for this change has no network, so no Godot binary could be obtained. Treat the fix as "written and statically verified, awaiting a CI run and a phone test".

Device test (debug APK): hold the stick right and, without lifting it, tap jump, attack, dash, block and grapple; lift each finger separately; switch apps and return. The overlay line should show the finger count and held buttons changing independently.

## 6. Known risks to look at first on the first Godot run

- `class_name SilentBladeTouchControls` is resolved from the global class cache; it is generated by the CI import step (`godot --headless --editor --quit`).
- Stick zone is the left 46% of the screen (floating stick); if it feels too large, change `STICK_ZONE_RATIO`.
- Touch coordinates are converted with `get_global_transform_with_canvas()`; with `stretch/mode=canvas_items` this should equal design-space coordinates, but it has not been run.
- The repository ZIP has no APK export workflow and no `export_presets.cfg`; the APK build mentioned for v0.5 lives outside this archive.

## 7. Suggested next steps (not started)

1. Push v0.5.1, read the Godot import/smoke log from CI, fix any parse errors.
2. Phone test with the overlay; tune stick zone / button sizes.
3. Add a line-of-sight ray to enemy vision and a `SEARCH` → `RETURN` state pair (stealth foundation).
4. Split `main.gd` (world / HUD / mission) before adding more levels.
