---
id: household-debug-inspector-v0
title: Add Household Settlement Debug Inspector v0
base_branch: develop
branch_name: feature/household-settlement-debug-inspector
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/
required_paths:
  - scripts/ui/household_debug_inspector.gd
required_content:
  - "extends Control"
  - "var root_box"
  - "var title_label"
  - "var household_label"
  - "var population_label"
  - "var housing_label"
  - "var food_label"
  - "var responsibility_label"
  - "var resource_label"
  - "func set_city"
  - "func update_from_city"
  - "func _safe_get"
  - "func _format_value"
blocked_content:
  - "typeid ="
  - "get_household_data()"
  - "{"
  - "} if "
  - " pass"
  - "hasattr"
  - "getattr"
  - "None"
  - " is null"
  - "len("
  - "dict("
min_lines:
  scripts/ui/household_debug_inspector.gd: 80
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
- Define at least these variables:
  - `var root_box: VBoxContainer`
  - `var title_label: Label`
  - `var household_label: Label`
  - `var population_label: Label`
  - `var housing_label: Label`
  - `var food_label: Label`
  - `var responsibility_label: Label`
  - `var resource_label: Label`
- Create UI elements programmatically in `_ready()`.
- Add a visible title label with exactly this text: `Household Settlement Debug Inspector`.
- Add visible fallback text labels:
  - `Households: unavailable`
  - `Population: unavailable`
  - `Housing: unavailable`
  - `Food: unavailable`
  - `Responsibilities: unavailable`
  - `Resources: unavailable`
- Implement `set_city(city)` by storing the city reference and calling `update_from_city(city)`.
- Implement `update_from_city(city)` with defensive reads only.
- Read available city/household data defensively and show fallback values when data is missing.
- Use `var current_city = null` to store the current city reference.
- Include `func _safe_get(target, property_name, fallback = "unavailable")` for defensive property or dictionary access.
- Include `func _format_value(value, fallback = "unavailable")` and use `str(value)` for formatting.
- Use GDScript string concatenation with `+`, not Python-style interpolation or brace expressions.
- If reading a method result, check `target.has_method(method_name)` before calling the method.
- If reading a property, first check that the target is not null and that the property exists or can be read safely.
- Do not call invented city methods unless each call is guarded by `has_method`.
- Do not use undeclared top-level assignments.
- Remain read-only.
- Never mutate city or household state.
- Do not require scene wiring.
- Do not create `.tscn` files.
- Contain no pass-only method bodies.
- Contain no placeholder "TODO only" implementation.
- Contain at least 80 lines of meaningful GDScript while staying under `max_lines_added`.

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
- Do not return empty methods or only `pass` statements.
- Do not return a script that creates no visible UI labels.
- Do not return a script that fails to update label text from city data or fallback values.
- Do not use `typeid =`.
- Do not call `get_household_data()`.
- Do not use Python-style `{value if condition else fallback}` string expressions.
- Do not use placeholder-only methods.

# Definition of Done

- Inspector script exists at `scripts/ui/household_debug_inspector.gd`.
- Inspector is read-only.
- Inspector can be instantiated later as a `Control` script.
- Inspector creates visible UI labels programmatically.
- Inspector updates labels from city data where possible and fallback values otherwise.
- Empty methods or pass-only stubs do not satisfy this task.
- Validation passes.
- No simulation behavior changes.
