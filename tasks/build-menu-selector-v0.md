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
  - "func draw_city_sidebar():"
  - "# Draw sidebar content here"
  - "func _draw():\n\t# Draw the city view"
  - "func try_handle_city_action_option_click(mouse_pos: Vector2):"
  - "var selected_building_type: String = \"\""
  - "var is_placing_building: bool = false"
  - "texture = preload"
  - "placeholder.png"
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

Superseded for local-agent use.

Do not rerun this combined task as-is. Repeated local-agent runs failed on `scripts/main.gd` draw/input integration despite verified anchors. Use `tasks/build-menu-helper-catalog-v0.md` for the local-agent helper/catalog step, then do `scripts/main.gd` integration with Codex/manual repair.

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

# Verified Project Context

Use these exact real project symbols and anchors from `scripts/main.gd`. Do not invent placeholder versions.

Current build-selection state exists as:

```gdscript
var city_action_options: Array[Dictionary] = []
```

```gdscript
var selected_building_type: String = BUILDING_HOUSE
var is_placing_building: bool = true
```

Safe top-level state insertion anchor:

```gdscript
var selected_building_type: String = BUILDING_HOUSE
var is_placing_building: bool = true
```

Insert new build menu state after that anchor, for example:

```gdscript
var is_build_menu_open: bool = false
```

The actual city sidebar signature is:

```gdscript
func draw_city_sidebar(font: Font, font_size: int):
```

The actual city view draw flow contains:

```gdscript
draw_city_buildings()
draw_city_walkers()
draw_building_preview()
draw_building_overlay(font, font_size)
draw_top_bar()
```

Safe draw-call insertion anchor:

```gdscript
draw_building_overlay(font, font_size)
```

Insert the build menu draw call after that line and before `draw_top_bar()`.

The actual city mouse click flow contains:

```gdscript
elif current_view == VIEW_CITY:
	if try_handle_city_action_click(local_mouse_pos):
		queue_redraw()
```

Safe click-handler insertion anchor:

```gdscript
elif current_view == VIEW_CITY:
```

Insert build-menu click handling immediately inside that branch, before `try_handle_city_action_click(local_mouse_pos)`.

The actual keyboard input block contains:

```gdscript
elif event is InputEventKey:
	var key_event: InputEventKey = event as InputEventKey
	if handle_simulation_speed_key_event(key_event):
```

Safe keyboard-toggle insertion anchor:

```gdscript
elif event is InputEventKey:
	var key_event: InputEventKey = event as InputEventKey
```

Insert the `KEY_B` city-view build-menu toggle after that anchor and before existing hotkey handlers.

The existing building selection path is:

```gdscript
func select_building_type(building_type: String):
	selected_building_type = building_type
	is_placing_building = true
	clear_selected_household()
```

Build-menu selection must call `select_building_type(building_id)`.

The existing city action option pattern is:

```gdscript
func draw_city_action_option(font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color) -> float:
```

Use that pattern if storing clickable build-menu option rectangles in `city_action_options`, or create a separate `build_menu_action_options: Array[Dictionary]` top-level state if needed.

Correct raw draw string signature:

```gdscript
draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
```

Safe function insertion anchors:

```gdscript
func apply_time_control_action(action: String):
```

Insert `try_handle_build_menu_click(...)` before that function.

```gdscript
func draw_sidebar_section_title(font: Font, text: String, x: float, y: float) -> float:
```

Insert `draw_build_menu(...)` before that function.

# Forbidden Fake Anchors And Symbols

Do not use or anchor to any of these fake/stub snippets:

- `func draw_city_sidebar():`
- `# Draw sidebar content here`
- `pass`
- `var selected_building_type: String = ""`
- `var is_placing_building: bool = false`
- `var is_build_menu_open: bool = false` as part of a fake pre-existing block
- `func _draw():` followed by `# Draw the city view`
- `func try_handle_city_action_option_click(mouse_pos: Vector2):`
- placeholder `_input(event: InputEvent)` blocks
- any anchor text that is not copied from the current `scripts/main.gd`

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

This remains acceptable for local-agent drafting only because the task now provides verified anchors. If another run invents fake anchors or placeholder functions, stop and use Codex/manual integration for `scripts/main.gd` while keeping the helper catalog concept.

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
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\build-menu-selector-v0.md -Model "qwen/qwen3-coder-30b" -NoCommit -Resume
```
