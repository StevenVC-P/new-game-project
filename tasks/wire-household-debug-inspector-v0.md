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
max_lines_deleted: 20
allow_new_files: false
allow_replacements: true
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: wire household debug inspector"
---

# Goal

Wire the existing Household Settlement Debug Inspector into the running game behind a debug toggle so it can be tested in-game.

# Scope

Make the smallest practical change to `scripts/main.gd`.

Do not edit `project.godot`, `scenes/main.tscn`, domain scripts, simulation scripts, world scripts, formulas, map generation, production, trade, household behavior, or scene hierarchy.

# Required Behavior

- Instantiate the existing inspector from `scripts/ui/household_debug_inspector.gd` using `preload()` or `load()`.
- Keep the inspector hidden by default.
- Toggle visibility with `F3` using `Input.is_key_pressed(KEY_F3)`, `_input(event)`, or equivalent code that does not require editing `project.godot`.
- Call `set_city(...)` with the primary/current city if one is available.
- Show fallback labels if no city is available.
- Do not mutate simulation state.
- Do not change formulas.
- Do not redesign scene hierarchy.
- Do not create or edit scene files.

# Implementation Notes

- Prefer adding a small helper such as `_ensure_household_debug_inspector()` if it fits the existing `main.gd` style.
- Avoid repeated creation of inspector instances on every frame.
- If there is no clear primary city variable, instantiate the inspector and call `set_city(null)`.
- Keep the code easy to remove or adjust later.

# Definition of Done

- Pressing `F3` in the running game toggles the inspector.
- Inspector is hidden by default.
- Inspector is read-only.
- Validation passes.
- No gameplay behavior changes.
