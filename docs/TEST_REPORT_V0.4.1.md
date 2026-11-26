# SILENT BLADE v0.4.1 — verification report

## Automated/static checks performed

- `pytest -q`: **18 passed**.
- The new tests verify all three enemy profile records, distinct health/movement/attack/delay/resistance values, all three actual level spawn requests and death signal wiring.
- The new tests verify three different katana profiles with distinct damage, active duration, cooldown, knockback and visual style, as well as combo progression/reset logic and per-strike hitbox geometry.
- The new tests verify that the player passes the strike-specific impulse into the enemy damage method, the enemy divides it by resistance and enters a knockback state, enemy-specific attack damage is used by the player hit/block resolution, and death emits once before `queue_free()`.
- Existing v0.4 contracts for hold block, parry timing, guard stamina, guard break, enemy telegraph/attack/recovery and Android input release still pass.
- Project main-scene and script references, campaign JSON, and ZIP integrity are checked during packaging.

## Not run in this environment

- Godot 4.3 project import and GDScript parser.
- Headless launch of `scenes/Main.tscn`.
- Interactive combat: combo timing, AI behavior, physical displacement, parry/block regression and enemy death in a running game.
- Android export, APK installation, touch/multitouch behavior and testing on a physical device.

`godot`, `godot4`, `gdformat`, `gdlint` and `adb` were not present in the environment. The GitHub Actions workflow uses a Godot 4.3 container and can validate import/parser and a short headless launch after the repository is pushed. It does not replace physical Android playtesting.

## Delivery classification

This ZIP contains the complete editable Godot source project and static-test report. It is **not an APK**, and this build has not been presented as runtime- or device-verified.
