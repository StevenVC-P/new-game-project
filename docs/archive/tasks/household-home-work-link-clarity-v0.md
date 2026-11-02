---
id: household-home-work-link-clarity-v0
title: Household Home/Work Link Clarity v0
base_branch: develop
branch_name: feature/household-home-work-link-clarity-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/household_home_work_link_helper.gd
  - scripts/main.gd
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/ui/household_home_work_link_helper.gd
  - scripts/main.gd
max_files_changed: 2
max_lines_added: 220
max_lines_deleted: 10
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household home work link clarity"
required_content_by_path:
  scripts/ui/household_home_work_link_helper.gd:
    - "class_name HouseholdHomeWorkLinkHelper"
    - "static func"
    - "household"
    - "home"
    - "residence"
    - "assigned"
    - "production"
    - "Household "
    - "No household link details."
  scripts/main.gd:
    - "Household Links"
blocked_content_by_path:
  scripts/ui/household_home_work_link_helper.gd:
    - "assign_"
    - "unassign_"
    - "toggle_maintenance"
    - "add_resource"
    - "remove_resource"
    - "pay_cost"
    - "city_credit"
    - "obligation"
    - "debt"
    - "currency"
  scripts/main.gd:
    - "replace_entire_file"
    - ".tscn"
    - "assign_"
    - "unassign_"
    - "toggle_maintenance"
    - "add_resource"
    - "remove_resource"
    - "pay_cost"
preserve_content:
  - "func _ready():"
  - "func _input(event: InputEvent):"
  - "func _draw():"
  - "draw_city_sidebar"
  - "draw_selected_object_summary"
  - "CityPressureHintHelper"
  - "SelectedBuildingActionHintHelper"
---

# Goal

Add read-only Household Home/Work Link Clarity v0.

This feature should make household identity visible through relationships:

- home -> household -> supported/assigned production buildings
- production building -> assigned household -> home/residence

# Scope

v0 is text/sidebar clarity only.

Do not draw visual lines yet.
Do not generate family names yet.
Do not add controls.
Do not mutate simulation state.
Do not implement money, credit, debt, or obligation mechanics.

# Expected Behavior

When selecting a house:

- show resident household if known
- show empty residence if no household is assigned
- show household population/preference/labor capacity if safely available
- show assigned/supported production buildings if any are safely discoverable

When selecting a production building:

- show assigned household if known
- show that household's residence/home if safely available
- show generic household labels such as Household 1 / Household 2
- show fallback text if no link details exist

# Helper

Create:

- `scripts/ui/household_home_work_link_helper.gd`

The helper should be read-only and defensive.

It should expose static helper functions that return short `Array[String]` output for sidebar display.

It must not:

- assign or unassign households
- toggle maintenance
- change resources
- pay costs
- change production
- touch money/credit/obligation concepts

# Main Integration

Add a small "Household Links" section near selected object/building details in the City Overview/sidebar.

Use targeted `insert_after` / `insert_before` only.
Do not use `replace_entire_file`.
Keep the section short and readable.
Do not use raw dictionary dumps.

# Definition of Done

- Selecting a house shows resident household/home link details or an empty/fallback message.
- Selecting a production building shows assigned household and home/residence if known.
- Generic household labels are acceptable.
- No family-name generation.
- No visual lines yet.
- No simulation mutation.
- Existing build/assignment controls still work.
- F3/F4 still work.
- Validation passes.

# Manual Test Checklist

1. Run the game.
2. Enter city view.
3. Select a house.
4. Confirm the sidebar shows "Household Links".
5. Confirm it shows resident household or empty residence.
6. Confirm it lists supported/assigned production buildings if any are available.
7. Select a production building.
8. Confirm it shows assigned household and home/residence if known.
9. Confirm no assignment, formula, resource, maintenance, or housing state changes.
10. Confirm F3/F4 still work.
11. Confirm no runtime errors appear.
