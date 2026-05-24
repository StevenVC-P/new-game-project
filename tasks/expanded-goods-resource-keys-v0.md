---
id: expanded-goods-resource-keys-v0
title: Expanded Goods Resource Keys v0
base_branch: develop
branch_name: feature/expanded-goods-resource-keys-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/domain/city.gd
  - scripts/main.gd
  - docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/building.gd
  - scripts/domain/household.gd
  - scripts/simulation/
  - scripts/world/
  - scripts/ui/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/domain/city.gd
  - scripts/main.gd
max_files_changed: 3
max_lines_added: 140
max_lines_deleted: 10
allow_new_files: false
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add expanded goods resource keys"
required_content_by_path:
  scripts/domain/city.gd:
    - '"wheat"'
    - '"bread"'
    - '"fish"'
    - '"stone"'
    - '"stone_blocks"'
    - '"planks"'
    - '"clay"'
    - '"pottery"'
    - '"wool"'
    - '"clothing"'
  scripts/main.gd:
    - "Wheat"
    - "Bread"
    - "Fish"
    - "Stone"
    - "Planks"
    - "Clay"
    - "Pottery"
    - "Wool"
    - "Clothing"
blocked_content_by_path:
  scripts/domain/city.gd:
    - "city_credit"
    - "obligation"
    - "debt"
    - "currency"
    - "wooden_tools"
  scripts/main.gd:
    - "replace_entire_file"
    - ".tscn"
    - "city_credit"
    - "obligation"
    - "debt"
    - "currency"
    - "wooden_tools"
preserve_content:
  - "func make_starting_resources() -> Dictionary:"
  - "func consume_food():"
  - "func apply_building_production(building: Building):"
  - "func update_building_maintenance(building: Building):"
  - "func record_resource_history():"
  - "func get_resource_trends() -> Dictionary:"
  - "func draw_city_sidebar(font: Font, font_size: int):"
  - "CityPressureHintHelper"
  - "SelectedBuildingActionHintHelper"
  - "HouseholdHomeWorkLinkHelper"
---

# Goal

Add expanded goods resource-key groundwork without changing gameplay formulas or production behavior.

This is a conservative first implementation slice for:

- docs/GOODS_AND_PRODUCTION_EXPANSION_MODEL.md
- docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md
- docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md

# Scope

Add initialized resource keys and read-only visibility for expanded goods.

Required new resource keys:

- `wheat`
- `bread`
- `fish`
- `stone`
- `stone_blocks`
- `planks`
- `clay`
- `pottery`
- `wool`
- `clothing`

Do not add `wooden_tools` in this task. It is deferred until it has a distinct gameplay role from `tools`.

# Design Guardrails

Do not implement:

- money
- city credit
- debt
- obligation pressure
- currency
- new production buildings
- resource access gating
- food migration
- edible-supply calculations
- household skills or traits

Do not change:

- current generic `food` survival logic
- farm/woodcutter/toolmaker production formulas
- toolmaker wood input
- maintenance/tool behavior
- pressure formulas
- assignment behavior
- trade behavior

# Expected Behavior

`scripts/domain/city.gd` should safely initialize the new resource keys, likely in `make_starting_resources()`, with starting values of `0`.

`scripts/main.gd` should make the expanded goods visible in the existing City Overview resource display if it can be done safely and compactly.

Keep existing food, wood, and tools display intact.

The new goods are storage/display groundwork only. They should not affect:

- food consumption
- food pressure
- production output
- maintenance
- tools pressure
- trade
- household labor
- building placement

# Main Script Guidance

Use targeted `insert_after` or `insert_before` operations only.

Do not use `replace_entire_file` for `scripts/main.gd`.

Use exact anchors from:

- docs/MAIN_GD_INTEGRATION_MAP.md
- docs/CITY_SIDEBAR_INTEGRATION_MAP.md

Likely safe area:

- the existing `Resources` section in `draw_city_sidebar(font, font_size)`

Keep display compact. If space is tight, group goods into short lines such as:

- `Grain: wheat / bread`
- `Food+: fish`
- `Materials: stone / planks / clay`
- `Goods: pottery / wool / clothing`

Do not create a new control, scene, or UI file.

# Documentation Guidance

If updating `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`, clearly separate observed behavior from future design:

- observed after this task: expanded keys exist and display as groundwork
- not yet implemented: production chains, consumption migration, access gating, money/credit/obligation

# Definition of Done

- New goods exist as initialized city resource keys.
- Current `food`, `wood`, and `tools` behavior remains unchanged.
- Current food consumption remains based on generic `food`.
- Current farm, woodcutter, and toolmaker formulas remain unchanged.
- New goods are visible or safely readable without runtime errors.
- No money, credit, debt, obligation, or currency mechanics are added.
- Validation passes.

# Manual Test Checklist

1. Run the game.
2. Enter city view.
3. Confirm existing food, wood, and tools display still works.
4. Confirm expanded goods are visible or safely initialized.
5. Place and assign current production buildings.
6. Advance simulation.
7. Confirm generic food consumption still works as before.
8. Confirm farms, woodcutters, toolmakers, maintenance, F3, F4, action hints, selected building hints, and household links still work.
9. Confirm no runtime errors appear.

# Failure Conditions

Reject the output if:

- generic food consumption changes
- production formulas change
- maintenance/tool behavior changes
- money, credit, debt, obligation, or currency appears
- `wooden_tools` is added
- project files or scenes change
- domain files other than `scripts/domain/city.gd` change
- UI/debug helper files change
- `scripts/main.gd` is broadly replaced
