---
id: city-overview-action-hints-v0
title: Add City Overview Action Hints v0
base_branch: develop
branch_name: feature/city-overview-action-hints-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/city_pressure_hint_helper.gd
  - scripts/main.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scripts/ui/city_building_overlay.gd
required_paths:
  - scripts/ui/city_pressure_hint_helper.gd
  - scripts/main.gd
max_files_changed: 2
max_lines_added: 180
max_lines_deleted: 10
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add city overview action hints"
required_content_by_path:
  scripts/ui/city_pressure_hint_helper.gd:
    - "class_name CityPressureHintHelper"
    - "static func get_hints"
    - "food"
    - "shelter"
    - "labor"
    - "tools"
    - "maintenance"
    - "unavailable"
blocked_content_by_path:
  scripts/ui/city_pressure_hint_helper.gd:
    - "city.tick"
    - "pay_cost"
    - "add_resource"
    - "remove_resource"
    - "assign_"
    - "toggle_maintenance"
  scripts/main.gd:
    - "replace_entire_file"
    - ".tscn"
    - "city.tick"
    - "pay_cost"
    - "add_resource"
    - "remove_resource"
    - "assign_"
    - "toggle_maintenance"
preserve_content:
  - "func _ready():"
  - "func _input(event: InputEvent):"
  - "func _draw():"
  - "draw_city_sidebar"
  - "draw_pressure_row"
---

# Goal

Add a read-only Action Hints section to the City Overview sidebar.

The hints should turn existing pressure statuses into concise next-step guidance without changing any simulation behavior.

# Context

The current city loop is:

Enter city -> choose building type -> preview placement/cost/validity -> place house or production building -> inspect building -> assign available household -> advance simulation -> resources and pressures update -> City Overview/F4 diagnostics show state.

The biggest current gap is pressure-to-action guidance. The game exposes pressure states, but the player is not always told what action to take next.

# Design Guardrails

Follow:

- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`
- `ROADMAP.md`

Do not violate:

- households are not generic worker slots
- labor/resource behavior must remain read-only
- do not change formulas
- do not mutate city, household, resource, trade, production, housing, or calendar state
- do not invent mechanics not visible in code

# Expected Behavior

Create:

- `scripts/ui/city_pressure_hint_helper.gd`

Wire it into:

- `scripts/main.gd`

The helper should:

- be read-only
- expose `static func get_hints(city)` or `static func get_hints(pressure_summary, resources)`
- use existing pressure summary/resource data only
- return a small `Array[String]` of actionable hints
- never mutate city/resources/households/buildings/trade
- use honest fallbacks
- not invent mechanics not visible in code

Example hints:

- Food pressure bad: "Assign a household to food production or build another farm."
- Shelter pressure bad: "Build housing or reduce unhoused/temporary shelter pressure."
- Labor pressure bad: "Assign idle household labor to production buildings."
- Tools pressure bad: "Produce or trade for tools to support maintenance."
- Maintenance pressure bad: "Enable maintenance and ensure tools are available."

# Main Script Integration

Use targeted edit operations only:

- `insert_after`
- `insert_before`

Do not use `replace_entire_file` for `scripts/main.gd`.

Use exact anchors that exist in `scripts/main.gd`.

Suggested anchors to inspect and confirm before using:

- `func draw_city_sidebar(font: Font, font_size: int):`
- `y = draw_sidebar_section_title(font, "City Health", text_x, y)`
- `y = draw_sidebar_section_title(font, "Resources", text_x, y)`

Do not invent anchors.

Add an "Action Hints" section to the City Overview sidebar:

- Keep it short: ideally 1-3 hints.
- Draw hints under the existing pressure summary or near City Health.
- If no hints exist, show a calm fallback such as "No urgent action hints."
- Do not add input controls.
- Do not change pressure calculations.

# Definition of Done

- City Overview shows an Action Hints section in city view.
- Hints are based on existing pressure/resource state.
- Hints are read-only.
- Existing sidebar still works.
- F3/F4 debug panels still work.
- Validation passes.
- Manual test confirms hints appear and update sensibly.

# Manual Test Checklist

1. Run the game.
2. Enter city view.
3. Inspect City Overview.
4. Confirm an "Action Hints" section appears.
5. Confirm hints are short and understandable.
6. Advance time or change city state through existing actions.
7. Confirm hints remain sensible.
8. Confirm no resources/formulas/assignments change because of hints.
9. Confirm F3/F4 still toggle correctly.
10. Confirm no runtime errors appear.

# Failure Conditions

Reject the output if:

- `scripts/main.gd` is broadly replaced
- `project.godot` changes
- scenes change
- domain/simulation/world scripts change
- formulas change
- resources are mutated
- assignments are mutated
- trade routes are mutated
- `.tscn` references are added
- new input controls are added
- F3/F4 debug panels break
- runtime errors occur
