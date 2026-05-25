---
id: build-menu-selector-v0
title: Build Menu / Building Selector v0
base_branch: develop
branch_name: feature/build-menu-selector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/main.gd
  - scripts/ui/build_menu_helper.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/city.gd
  - scripts/domain/household.gd
  - scripts/domain/building.gd
  - scripts/simulation/
  - scripts/world/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/main.gd
  - scripts/ui/build_menu_helper.gd
max_files_changed: 2
max_lines_added: 260
max_lines_deleted: 40
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add build menu selector"
required_content_by_path:
  scripts/ui/build_menu_helper.gd:
    - "class_name BuildMenuHelper"
    - "static func"
    - "House"
    - "Farm"
    - "Woodcutter"
    - "Toolmaker"
    - "Quarry"
    - "Stonecutter"
    - "Brickworks"
    - "Lime Kiln"
    - "Mortar Yard"
    - "Mason Yard"
    - "Sculptor"
    - "Carver"
    - "Tileworks"
    - "Paver Yard"
  scripts/main.gd:
    - "BuildMenuHelper"
    - "build_menu"
    - "draw_build_menu"
blocked_content:
  - "apply_building_production"
  - "consume_food"
  - "add_resource"
  - "remove_resource"
  - "pay_cost"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - "credit"
  - "credits"
  - "cost_label"
  - "replace_entire_file"
  - ".tscn"
preserve_content:
  - "func _ready():"
  - "func _input(event: InputEvent):"
  - "func _draw():"
  - "draw_city_sidebar"
  - "select_building_type"
  - "CityPressureHintHelper"
  - "SelectedBuildingActionHintHelper"
  - "HouseholdHomeWorkLinkHelper"
---

# Goal

Add a scalable Build Menu / Building Selector v0.

The current hotkey list is too cramped for expanded goods buildings. v0 should add a visible, toggleable build menu/list while preserving existing hotkeys as shortcuts.

The visible menu title should be exactly:

- `Build Menu`

# Expected Behavior

- The player can open/use the build menu in city view.
- The menu lists all currently placeable building types.
- The menu groups buildings by simple category if practical.
- Selecting a menu entry updates the selected build type through the existing selection path.
- Existing hotkeys still work.
- The selected build label displays readable names.
- Placement behavior remains unchanged.
- No production/resource/access/formula changes.

# Building List

Include:

- `house`
- `farm`
- `woodcutter`
- `toolmaker`
- `quarry`
- `stonecutter`
- `brickworks`
- `lime_kiln`
- `mortar_yard`
- `mason_yard`
- `sculptor`
- `carver`
- `tileworks`
- `paver_yard`

# Implementation Guidance

Prefer a helper catalog:

- `scripts/ui/build_menu_helper.gd`

The helper should provide read-only building menu data:

- id
- readable name
- category
- optional sort order

Do not hardcode cost text in the helper. Costs must come from the existing `building_placement.get_building_cost(...)` and `building_placement.get_cost_text(...)` path in `scripts/main.gd`.

Main integration should be minimal:

- draw/open the menu
- handle selection
- call existing `select_building_type(...)`
- preserve hotkeys
- avoid broad `main.gd` rewrites

Use existing `main.gd` symbols and patterns:

- `selected_building_type`
- `is_placing_building`
- `city_action_options`
- `draw_city_action_option(...)`
- `draw_sidebar_section_title(...)`
- `draw_sidebar_line(...)`
- `draw_sidebar_label_value(...)`
- `building_placement.get_building_cost(...)`
- `building_placement.get_cost_text(...)`

Use the existing `draw_string(...)` signature shown in `docs/MAIN_GD_INTEGRATION_MAP.md` and `docs/CITY_SIDEBAR_INTEGRATION_MAP.md`.

Suggested safe state naming:

- `var is_build_menu_open: bool = false`
- `func draw_build_menu(...)`
- `func try_handle_build_menu_click(...)`

Declare new state near the existing top-level UI state variables. Do not initialize new top-level state inside `_ready()`.

Use targeted `insert_after` / `insert_before` operations only for `scripts/main.gd`.
Do not use `replace_entire_file`.

Use `create` only for `scripts/ui/build_menu_helper.gd`.
Use `insert_after` / `insert_before` only for `scripts/main.gd`.
Do not create or edit existing docs in this task.

# Definition of Done

- Build menu displays all currently placeable building types.
- Player can select buildings from the menu.
- Existing hotkeys still work.
- Selected building label updates correctly.
- Placement behavior remains unchanged.
- Existing buildings still work.
- Expanded goods buildings remain placeable.
- No production/resource formula changes.
- Validation passes.
- Manual runtime test passes.

# Manual Test Checklist

1. Enter city view.
2. Open the build menu.
3. Select House, Farm, Woodcutter, Toolmaker.
4. Select several expanded goods buildings.
5. Confirm selected building label and cost update.
6. Place buildings on valid terrain.
7. Confirm existing hotkeys still work.
8. Confirm right click/Esc clearing still works.
9. Confirm F3/F4 still work.
10. Confirm no runtime errors.

# Validation Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Local Agent Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\build-menu-selector-v0.md -Model "qwen/qwen3-coder-30b" -NoCommit
```
