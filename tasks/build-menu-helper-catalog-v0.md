---
id: build-menu-helper-catalog-v0
title: Build Menu Helper Catalog v0
base_branch: develop
branch_name: feature/build-menu-selector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/build_menu_helper.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/main.gd
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - docs/
required_paths:
  - scripts/ui/build_menu_helper.gd
max_files_changed: 1
max_lines_added: 160
max_lines_deleted: 0
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add build menu helper catalog"
required_content_by_path:
  scripts/ui/build_menu_helper.gd:
    - "class_name BuildMenuHelper"
    - "static func get_building_catalog"
    - "static func get_display_name"
    - "static func get_category"
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
blocked_content:
  - "preload"
  - "texture"
  - "placeholder.png"
  - "InputEvent"
  - "draw_"
  - "select_building_type"
  - "add_resource"
  - "remove_resource"
  - "apply_building_production"
  - "consume_food"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - ".tscn"
  - "replace_entire_file"
---

# Goal

Create the read-only Build Menu Helper Catalog v0.

This task is the local-agent-safe helper-only split from the combined Build Menu / Building Selector v0 task. It must create only:

- `scripts/ui/build_menu_helper.gd`

Do not edit `scripts/main.gd`.
Do not add input handling.
Do not draw UI.
Do not create textures, assets, scenes, or docs.

# Expected Behavior

The helper exposes a simple read-only catalog for currently placeable buildings.

Each catalog entry should include:

- `id`
- `display_name`
- `category`
- optional `hotkey`
- optional `sort_order`

The helper should expose:

- `static func get_building_catalog() -> Array[Dictionary]`
- `static func get_display_name(building_id: String) -> String`
- `static func get_category(building_id: String) -> String`

# Building List

Include these building ids and readable names:

- `house` -> `House`
- `farm` -> `Farm`
- `woodcutter` -> `Woodcutter`
- `toolmaker` -> `Toolmaker`
- `quarry` -> `Quarry`
- `stonecutter` -> `Stonecutter`
- `brickworks` -> `Brickworks`
- `lime_kiln` -> `Lime Kiln`
- `mortar_yard` -> `Mortar Yard`
- `mason_yard` -> `Mason Yard`
- `sculptor` -> `Sculptor`
- `carver` -> `Carver`
- `tileworks` -> `Tileworks`
- `paver_yard` -> `Paver Yard`

Suggested categories:

- `Housing`
- `Food`
- `Wood/Tools`
- `Stone/Construction`
- `Craft`

# Scope Limits

This helper is data-only.

It must not:

- mutate game state
- select buildings
- handle input
- draw UI
- preload textures
- reference assets
- change production formulas
- change resources
- change domain/simulation/world logic
- introduce money, credit, debt, currency, or obligation concepts

# Definition of Done

- `scripts/ui/build_menu_helper.gd` exists.
- It defines `class_name BuildMenuHelper`.
- It returns all currently placeable buildings in a read-only catalog.
- Display-name and category lookup helpers work defensively.
- No `scripts/main.gd` changes.
- No docs changes.
- No asset or scene references.
- Validation passes.

# Manual Test Checklist

Manual runtime testing is not required for this helper-only task, but after later integration:

1. Enter city view.
2. Open the build menu.
3. Confirm all catalog buildings appear with readable names.
4. Confirm selecting still uses the existing placement path.

# Validation Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Local Agent Command

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\build-menu-helper-catalog-v0.md -Model "qwen/qwen3-coder-30b" -NoCommit -Resume
```
