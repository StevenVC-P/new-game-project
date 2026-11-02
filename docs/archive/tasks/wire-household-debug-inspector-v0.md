---
id: wire-household-debug-inspector-v0
title: Wire Household Settlement Debug Inspector v0
base_branch: develop
branch_name: feature/wire-household-debug-inspector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/main.gd
  - scripts/ui/household_debug_inspector.gd
  - docs/
required_paths:
  - scripts/main.gd
blocked_paths:
  - project.godot
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scenes/main.tscn
max_files_changed: 2
max_lines_added: 120
max_lines_deleted: 10
max_replaced_file_lines: 120
max_deleted_lines_ratio: 0.05
allow_large_replacements: false
allow_new_files: false
allow_replacements: false
allow_deletes: false
allow_renames: false
preserve_content:
  - "extends Node2D"
  - "func _ready"
  - "func _process"
  - "func _input"
  - "func _draw"
  - "var cities"
  - "var selected_city_index"
blocked_content:
  - "func _ensure_city_info_panel()"
  - "func _input(event):"
  - "household_debug_inspector.tscn"
  - "res://scripts/ui/household_debug_inspector.tscn"
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: wire household debug inspector"
---

# Goal

Wire the existing Household Settlement Debug Inspector into the running game behind a debug toggle so it can be tested in-game.

# Scope

Make the smallest practical change to `scripts/main.gd`.

Do not edit `project.godot`, `scenes/main.tscn`, domain scripts, simulation scripts, world scripts, formulas, map generation, production, trade, household behavior, or scene hierarchy.

Do not replace the whole `scripts/main.gd` file. Use targeted JSON edit operations such as `insert_after` or `insert_before`. Preserve the existing main script structure, constants, map generation, input handling, drawing, simulation, and city state.

# Exact Insertion Anchors

Use only anchors that appear exactly in `scripts/main.gd`. Do not invent anchors.

Confirmed anchors:

- `var selected_city_index: int = -1`
- `func _ready():`
- `func _input(event: InputEvent):`
- `func _draw():`

Recommended targeted edits:

- Insert the inspector variable after `var selected_city_index: int = -1`.
- Insert initialization inside `_ready()` immediately after `func _ready():` or after an existing first setup line in `_ready()`.
- Insert F3 key handling inside `_input(event: InputEvent):` immediately after the function signature.
- Insert helper methods before `func _draw():`.

Forbidden anchors:

- Do not use `func _ensure_city_info_panel()`. It does not exist.
- Do not use `func _input(event):`. The real signature is `func _input(event: InputEvent):`.

# Required Behavior

- Instantiate the existing inspector from `scripts/ui/household_debug_inspector.gd` using `preload()` or `load()`.
- Load the script path exactly as `res://scripts/ui/household_debug_inspector.gd`.
- Do not load or reference `household_debug_inspector.tscn`; no scene exists for this inspector.
- Keep the inspector hidden by default.
- Toggle visibility with `F3` using `Input.is_key_pressed(KEY_F3)`, `_input(event)`, or equivalent code that does not require editing `project.godot`.
- Use F3 edge handling with `event is InputEventKey`, `event.pressed`, `not event.echo`, and `event.keycode == KEY_F3`.
- Toggle once per key press, not every frame while the key is held.
- Call `set_city(...)` with the primary/current city if one is available.
- Show fallback labels if no city is available.
- Do not mutate simulation state.
- Do not change formulas.
- Do not redesign scene hierarchy.
- Do not create or edit scene files.

# Implementation Notes

- Prefer adding a small helper such as `_ensure_household_debug_inspector()` if it fits the existing `main.gd` style.
- Prefer adding a small constant and one variable near the existing constants/state variables, plus a small helper near existing input/helper methods.
- Prefer calling the helper from existing `_ready()` and handling F3 inside the existing `_input(event)` method.
- Instantiate the inspector script as a `Control` by loading/preloading `res://scripts/ui/household_debug_inspector.gd` and calling `.new()`.
- Add the inspector to an appropriate existing UI/root node, or to the main node if no better UI parent is obvious.
- Keep the inspector hidden by default.
- Avoid repeated creation of inspector instances on every frame.
- If there is no clear primary city variable, instantiate the inspector and call `set_city(null)`.
- If `selected_city_index` points at a valid city, pass `cities[selected_city_index]`; otherwise fall back to the first city if available, otherwise `null`.
- Keep the code easy to remove or adjust later.

# Definition of Done

- Pressing `F3` in the running game toggles the inspector.
- Inspector is hidden by default.
- Inspector is read-only.
- Validation passes.
- No gameplay behavior changes.
