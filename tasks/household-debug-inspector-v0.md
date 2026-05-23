---
id: household-debug-inspector-v0
title: Add Household Settlement Debug Inspector v0
base_branch: develop
branch_name: feature/household-debug-inspector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/
required_paths:
  - scripts/ui/household_debug_inspector.gd
blocked_paths:
  - scenes/
  - docs/example.md
  - project.godot
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scripts/main.gd
  - scenes/main.tscn
max_files_changed: 1
max_lines_added: 250
max_lines_deleted: 50
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household debug inspector v0"
---

# Goal

Create a standalone reusable Control script for a future Household Settlement Debug Inspector.

# Scope

Create exactly this file:

- `scripts/ui/household_debug_inspector.gd`

Do not create scene files yet. Do not wire the inspector into `scenes/main.tscn` yet.

The inspector should be small, read-only, and defensive. It must not change simulation formulas, household behavior, production, trade, calendar logic, or map generation.

# Required Implementation Shape

- Extend `Control`.
- Create UI elements programmatically in `_ready()`.
- Expose a method such as `set_city(city)` or `update_from_city(city)`.
- Read available city/household data defensively.
- Use fallback labels when values are not accessible.
- Remain read-only.
- Do not require scene wiring.
- Do not create `.tscn` files.

# Display Fields

Show available values only. Use fallback text if a value is not accessible.

Desired fields:
- household count
- total population
- housing capacity or pressure
- food amount or food pressure
- assigned responsibilities or labor coverage
- basic resources if already accessible

# Forbidden

- Do not create scene files.
- Do not edit `scenes/`.
- Do not edit `scripts/domain/`.
- Do not edit `scripts/simulation/`.
- Do not edit `scripts/world/`.
- Do not edit formulas.
- Do not change household labor semantics.
- Do not modify `project.godot`.
- Do not redesign `scenes/main.tscn`.
- Do not rename nodes/classes/files.
- Do not create `docs/example.md`.

# Definition of Done

- Inspector script exists at `scripts/ui/household_debug_inspector.gd`.
- Inspector is read-only.
- Inspector can be instantiated later as a `Control` script.
- Validation passes.
- No simulation behavior changes.
