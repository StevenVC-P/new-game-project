---
id: city-pressure-debug-panel-v0
title: Add City Pressure Debug Panel v0
base_branch: develop
branch_name: feature/city-pressure-debug-panel-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/city_pressure_debug_panel.gd
  - scripts/main.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
required_paths:
  - scripts/ui/city_pressure_debug_panel.gd
  - scripts/main.gd
max_files_changed: 2
max_lines_added: 220
max_lines_deleted: 10
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add city pressure debug panel"
required_content_by_path:
  scripts/ui/city_pressure_debug_panel.gd:
    - "extends Control"
    - "func set_city"
    - "func update_from_city"
    - "get_pressure_summary"
    - "food"
    - "shelter"
    - "labor"
    - "tools"
    - "maintenance"
    - "unavailable"
blocked_content_by_path:
  scripts/ui/city_pressure_debug_panel.gd:
    - "city.tick"
    - "pay_cost"
    - "add_resource"
    - "remove_resource"
  scripts/main.gd:
    - "replace_entire_file"
    - ".tscn"
    - "household_debug_inspector.tscn"
    - "city_pressure_debug_panel.tscn"
preserve_content:
  - "func _ready():"
  - "func _input(event: InputEvent):"
  - "func _draw():"
  - "_ensure_household_debug_inspector"
  - "draw_city_sidebar"
---

# Goal

Add a read-only City Pressure Debug Panel v0.

The panel should make current city pressure/resource state visible in city/local view without changing any simulation behavior.

# Design Guardrails

Follow:
- docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md

Do not violate:
- households are not generic worker slots
- labor/resource behavior must remain read-only
- do not change formulas
- do not mutate city, household, resource, trade, production, housing, or calendar state

# Expected Behavior

Create:
- scripts/ui/city_pressure_debug_panel.gd

Wire it into:
- scripts/main.gd

The panel should:
- extend Control
- create UI elements programmatically
- be hidden by default
- be available only in city/local view
- toggle with F4
- display food, shelter, labor, tools, and maintenance pressure where available
- use city.get_pressure_summary() when available
- read city.resources defensively where needed
- show "unavailable" for missing data
- avoid guessing or inventing mechanics

# Main Script Wiring

Use targeted edit operations only:
- insert_after
- insert_before

Do not use replace_entire_file for scripts/main.gd.

Use exact anchors that exist in scripts/main.gd.

Suggested anchors to inspect and confirm before using:
- func _ready():
- func _input(event: InputEvent):
- func _draw():

Do not invent anchors.

F4 handling should use:
- event is InputEventKey
- event.pressed
- not event.echo
- event.keycode == KEY_F4

The panel should hide or refuse to open outside city view.

# Definition of Done

- Panel script exists.
- Main script can toggle it with F4 in city view.
- It does not appear on regional map.
- It reads pressure/resource state defensively.
- It mutates no simulation state.
- Validation passes.
- Feature output should be reviewed before commit.

# Manual Test Steps

1. Run the game.
2. Enter city/local view.
3. Press F4.
4. Confirm the City Pressure Debug Panel appears.
5. Confirm it shows food, shelter, labor, tools, and maintenance pressure or honest fallback labels.
6. Press F4 again.
7. Confirm the panel hides.
8. Return to regional view.
9. Press F4.
10. Confirm the panel does not appear or hides.
11. Confirm no runtime errors appear in the console.

# Failure Conditions

Reject the output if:
- scripts/main.gd is broadly replaced
- project.godot changes
- scenes change
- domain/simulation/world scripts change
- formulas change
- resources are mutated
- .tscn inspector/panel references are added
- F4 toggles every frame while held
- panel appears on regional map
- runtime errors occur
