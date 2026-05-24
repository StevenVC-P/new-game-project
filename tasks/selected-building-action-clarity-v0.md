---
id: selected-building-action-clarity-v0
title: Selected Building Action Clarity v0
base_branch: develop
branch_name: feature/selected-building-action-clarity-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/selected_building_action_hint_helper.gd
  - scripts/main.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/ui/selected_building_action_hint_helper.gd
  - scripts/main.gd
max_files_changed: 2
max_lines_added: 200
max_lines_deleted: 10
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add selected building action clarity"
required_content_by_path:
  scripts/ui/selected_building_action_hint_helper.gd:
    - "class_name SelectedBuildingActionHintHelper"
    - "static func get_hints"
    - "assigned"
    - "unassigned"
    - "maintenance"
    - "tools"
    - "household"
    - "production"
    - "No selected building action hints."
blocked_content_by_path:
  scripts/ui/selected_building_action_hint_helper.gd:
    - "city.tick"
    - "pay_cost"
    - "add_resource"
    - "remove_resource"
    - "assign_"
    - "unassign_"
    - "toggle_maintenance"
    - "city_credit"
    - "obligation"
    - "debt"
    - "currency"
  scripts/main.gd:
    - "replace_entire_file"
    - ".tscn"
    - "city.tick"
    - "pay_cost"
    - "add_resource"
    - "remove_resource"
    - "assign_"
    - "unassign_"
    - "toggle_maintenance"
    - "city_credit"
    - "obligation"
    - "debt"
    - "currency"
preserve_content:
  - "func _ready():"
  - "func _input(event: InputEvent):"
  - "func _draw():"
  - "draw_city_sidebar"
  - "draw_pressure_row"
  - "selected_building"
  - "CityPressureHintHelper"
---

# Goal

Improve the player-facing selected building and assignment loop.

The player should better understand:

- what building is selected
- whether it is production, housing, or another type
- whether it has assigned household labor
- whether labor is idle, assigned, missing, or mismatched
- whether maintenance is enabled or disabled where relevant
- whether tools or maintenance may block or weaken production
- what next action makes sense

# Context

The Money, Obligation, and City Credit model is future-facing doctrine only. Do not implement money, debt, city credit, obligation ledgers, currency, or related mechanics.

Current first-playable focus remains:

- food
- shelter
- household labor
- responsibility assignment
- tools
- maintenance
- production buildings
- pressure/action guidance

# Design Guardrails

Follow:

- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`
- `ROADMAP.md`

Do not violate:

- households are not generic worker slots
- labor/resource behavior must remain read-only for this task
- do not change formulas
- do not mutate city, household, resource, trade, production, housing, maintenance, or calendar state
- do not add money, credit, debt, obligation, or currency mechanics
- do not invent mechanics not visible in code

# Expected Behavior

Create:

- `scripts/ui/selected_building_action_hint_helper.gd`

Wire it into:

- `scripts/main.gd`

The helper should:

- be read-only
- preferably `extends RefCounted`
- expose `static func get_hints(...)`
- inspect building and city state defensively
- return a small `Array[String]` of concise player-facing hints
- return no more than 1-3 useful hints
- include a calm fallback such as `"No selected building action hints."`
- mention or handle assigned, unassigned, maintenance, tools, household, and production states
- never mutate city/resources/households/buildings/trade
- never assign or unassign households
- never toggle maintenance
- never change formulas

Example hints:

- "Assign an idle household to start production."
- "This building has assigned labor."
- "Maintenance is disabled; production may degrade when tools are needed."
- "Tools are low; maintenance may become unreliable."
- "No selected building action hints."

# Main Script Integration

Use targeted edit operations only:

- `insert_after`
- `insert_before`

Do not use `replace_entire_file` for `scripts/main.gd`.

Use exact anchors that exist in `scripts/main.gd`.

Suggested anchors to inspect and confirm before using:

- `func draw_selected_object_summary(font: Font, font_size: int, city: City, x: float, y: float) -> float:`
- `if building.is_house():`
- `else:`
- `return y`

Do not invent anchors.

Add a small "Selected Building Hints" or "Building Action Hints" section near the selected object/building details in the City Overview sidebar.

Keep it short:

- 1-3 hints max
- readable text
- no raw dictionary dumps
- no debug-only jargon
- no new input controls
- no changed pressure or production calculations

# Current Code Surface To Reuse

Use existing state and helpers where available:

- `city_building_overlay.inspected_building_index`
- `city.buildings`
- `building.is_house()`
- `building.is_production_building()`
- `building.assigned_workers`
- `building.assigned_household_id`
- `building.receives_maintenance`
- `building.maintenance_level`
- `city.resources`
- `city.get_household_by_id(...)`
- `city.get_available_neutral_workers()`
- `city.get_available_workers_from_household(...)` only if already safely available and useful
- existing sidebar helpers such as `draw_sidebar_section_title(...)`, `draw_sidebar_line(...)`, and `draw_sidebar_label_value(...)`

Avoid modifying existing assignment or maintenance controls.

# Definition of Done

- Selecting a production building shows short action hints.
- Unstaffed production buildings suggest assignment if appropriate.
- Staffed buildings indicate assigned labor.
- Maintenance/tool concerns are surfaced if visible from current state.
- Housing selections do not show misleading production hints.
- No simulation state changes.
- Existing build/assignment controls still work.
- F3/F4 debug panels still work.
- Validation passes.

# Manual Test Checklist

1. Run the game.
2. Enter city view.
3. Place or select a production building.
4. Confirm a "Selected Building Hints" or similar section appears.
5. Select an unstaffed production building and confirm assignment guidance appears.
6. Assign a household using existing controls.
7. Confirm the hints update or remain sensible.
8. Toggle maintenance using existing controls if available.
9. Confirm maintenance/tool hinting remains sensible.
10. Confirm no resources, formulas, or assignments changed because of hints.
11. Confirm F3/F4 still work.
12. Confirm no runtime errors appear.

# Failure Conditions

Reject the output if:

- `scripts/main.gd` is broadly replaced
- `project.godot` changes
- scenes change
- domain/simulation/world scripts change
- formulas change
- resources are mutated
- assignments are mutated
- maintenance is toggled by the helper
- money, credit, debt, obligation, or currency mechanics are added
- `.tscn` references are added
- new input controls are added
- F3/F4 debug panels break
- runtime errors occur
