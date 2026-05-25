---
id: production-requirement-helper-v0
title: Production Requirement Helper v0
base_branch: develop
branch_name: feature/selected-production-requirements-clarity-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/production_requirement_helper.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/main.gd
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/ui/production_requirement_helper.gd
max_files_changed: 1
max_lines_added: 180
max_lines_deleted: 0
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add production requirement helper"
required_content_by_path:
  scripts/ui/production_requirement_helper.gd:
    - "class_name ProductionRequirementHelper"
    - "static func get_requirement_lines"
    - "var lines: Array[String]"
    - "Assigned labor"
    - "maintenance"
    - "inputs"
    - "Food shortage"
    - "Fit"
    - "No production requirement details."
blocked_content:
  - "add_resource"
  - "remove_resource"
  - "apply_building_production"
  - "consume_food"
  - "assign_"
  - "unassign_"
  - "toggle_maintenance"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - "InputEvent"
  - "draw_"
  - "select_building_type"
  - "preload"
  - "texture"
  - "replace_entire_file"
  - "household.has"
  - "match building.maintenance_level"
  - "match match_quality"
  - "mortart"
  - "var lines := []"
  - ".tscn"
---

# Goal

Create Production Requirement Helper v0.

This is Step A of Selected Production Requirements Clarity v0. It is a helper-only local-agent task. It should create only:

- `scripts/ui/production_requirement_helper.gd`

Do not edit `scripts/main.gd`.
Do not edit domain, simulation, world, scene, project, or money/credit/obligation files.
Do not change production formulas, assignment rules, resources, terrain access, or household skills.

# Helper Purpose

Provide read-only requirement/status lines for a selected production building.

The helper should inspect the current city/building state defensively and return short player-facing lines about:

- Assigned labor
- maintenance
- inputs
- Food shortage
- household fit
- fallback when not applicable

# Required Helper API

Create:

```gdscript
class_name ProductionRequirementHelper
```

Expose:

```gdscript
static func get_requirement_lines(city, building) -> Array[String]
```

Use a typed local array so Godot does not infer a generic `Array` return:

```gdscript
var lines: Array[String] = []
```

Use `create` for `scripts/ui/production_requirement_helper.gd`. The helper file does not exist yet. Do not use `replace_entire_file` or any replacement action unless a same-run create has already succeeded and a repair attempt is required.

# Expected Behavior

For a production building, return concise lines such as:

- `Assigned labor: missing`
- `Assigned labor: satisfied`
- `Maintenance: stable`
- `Maintenance: worn`
- `Inputs: missing wood`
- `Food shortage: production may slow`
- `Fit: good match`
- `Fit: neutral`
- `Fit: poor match`

If the building is null, not a production building, or details are unavailable, return:

- `No production requirement details.`

# Current Code Context

The current code already has these relevant concepts:

- `building.is_production_building()`
- `building.assigned_workers`
- `building.assigned_household_id`
- `building.maintenance_level`
- `building.receives_maintenance`
- `city.resources`
- `city.resources["food_shortage"]`
- `city.get_household_by_id(...)`
- household `preference`
- household `get_match_quality(building.type)`

Use these defensively. If a property or method is unavailable, return honest fallback text instead of throwing.

Important implementation details:

- `building.maintenance_level` is an integer percentage-like value from `0` to `100`, not an enum. Use threshold comparisons such as `<= 0`, `< 50`, `< 100`, and `>= 100`; do not match it against `0`, `1`, `2`, `3`.
- `household.get_match_quality(building.type)` returns strings such as `"good match"`, `"neutral"`, and `"poor match"`, not numeric enum values. Compare strings directly.
- Do not call `household.has("preference")`; households are objects, not dictionaries.
- Check `building.assigned_workers > 0` for assigned labor status. `assigned_household_id` may be `-1` for non-household neutral assignment cases, but assigned labor can still exist.
- Keep output lines player-facing and consistently capitalized, including `Assigned labor`, `Food shortage`, and `Fit`.
- Use `mortar`, not `mortart`.

# Input Checks

The helper may report known v0 input requirements for existing buildings:

- `toolmaker`: `wood`
- `stonecutter`: `stone_blocks`
- `brickworks`: `wood`
- `lime_kiln`: `stone_blocks`, `wood`
- `mortar_yard`: `lime`, `stone_blocks`
- `mason_yard`: `cut_stone`, `mortar`
- `sculptor`: `cut_stone`, `tools`
- `carver`: `wood`, `tools`
- `tileworks`: `bricks`, `wood`
- `paver_yard`: `stone_blocks`

Farm, woodcutter, and quarry have no input goods in the current production formula.

# Scope Limits

This helper is read-only.

It must not:

- mutate city state
- mutate resources
- assign or unassign households
- toggle maintenance
- call production functions
- consume food
- handle input
- draw UI
- preload textures or assets
- create scenes
- introduce money, credit, debt, currency, or obligation concepts

# Step B Context

After this helper passes validation and review, Codex/manual integration should add a small `Production Requirements` section near selected-building details in `scripts/main.gd`.

That later integration should:

- show missing labor if no household is assigned
- show labor satisfied if assigned
- show maintenance status
- show missing inputs if input goods are needed
- show household fit text if safely available
- avoid raw dictionary dumps
- preserve F3/F4, Action Hints, Household Links, Build Menu, and existing placement behavior

# Definition of Done

- `scripts/ui/production_requirement_helper.gd` exists.
- It defines `class_name ProductionRequirementHelper`.
- It exposes `static func get_requirement_lines(city, building) -> Array[String]`.
- It returns short read-only requirement/status lines.
- It handles non-production or unavailable cases with `No production requirement details.`
- It does not mutate simulation state.
- It does not edit `scripts/main.gd`.
- Validation passes.

# Manual Test Checklist

Manual runtime testing is not required for this helper-only task. After Step B integration:

1. Enter city view.
2. Select an unassigned production building.
3. Confirm missing labor is shown.
4. Assign a household.
5. Confirm labor status updates.
6. Select an input-consuming building with missing inputs.
7. Confirm input blocker is shown.
8. Confirm maintenance status is shown.
9. Confirm household fit text is sensible if available.
10. Confirm no formulas/resources/assignments change because of this UI.
11. Confirm F3/F4, Action Hints, Household Links, and Build Menu still work.
12. Confirm no runtime errors.

# Validation Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Local Agent Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\production-requirement-helper-v0.md -Model "qwen/qwen3-coder-30b" -NoCommit
```
