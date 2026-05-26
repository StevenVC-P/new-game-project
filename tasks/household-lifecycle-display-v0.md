---
id: household-lifecycle-display-v0
title: Household Lifecycle Display v0
base_branch: develop
branch_name: feature/household-lifecycle-display-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/household_lifecycle_display_helper.gd
blocked_paths:
  - scripts/main.gd
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scenes/
  - project.godot
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/ui/household_lifecycle_display_helper.gd
max_files_changed: 1
max_lines_added: 160
max_lines_deleted: 0
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household lifecycle display helper"
required_content_by_path:
  scripts/ui/household_lifecycle_display_helper.gd:
    - "class_name HouseholdLifecycleDisplayHelper"
    - "static func get_lifecycle_lines"
    - "lifecycle_stage"
    - "young_children"
    - "older_children"
    - "adult_children"
    - "family_trade"
    - "succession_pressure"
    - "age_in_stage"
    - "No household lifecycle details."
required_phrase_or_terms_by_path:
  scripts/ui/household_lifecycle_display_helper.gd:
    - "Stage => stage|lifecycle"
    - "Children => young|older|adult"
    - "Family trade => family|trade"
    - "Succession => succession|pressure"
blocked_content:
  - "add_resource"
  - "remove_resource"
  - "apply_building_production"
  - "consume_food"
  - "assign_"
  - "unassign_"
  - "queue_free"
  - "erase("
  - "remove_at"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - "InputEvent"
  - "draw_"
  - "preload"
  - "texture"
  - ".tscn"
  - "replace_entire_file"
---

# Goal

Create the helper-only Step A for Household Lifecycle Display v0.

Household lifecycle state should become visible before it changes gameplay. This task should create a read-only display helper only. It must not integrate the helper into UI yet.

# Context

`docs/HOUSEHOLD_LIFECYCLE_SUCCESSION_MODEL.md` defines the household lifecycle model.

Household Lifecycle Fields v0 adds persistent household-level fields:

- `lifecycle_stage`
- `young_children`
- `older_children`
- `adult_children`
- `family_trade`
- `succession_pressure`
- `age_in_stage`

This display task should make those fields easy to show in a later selected-household or selected-house overlay without changing formulas, ticking, assignment, production, family formation, or death behavior.

# Workflow

Use the helper/integration split.

Step A, this task:

- local-agent helper-only draft with `-NoCommit`
- create `scripts/ui/household_lifecycle_display_helper.gd`
- no UI integration
- no `scripts/main.gd`
- no domain changes

Step B, later task:

- Codex/manual integration into the selected house/household information UI
- preferred display location is the selected house/building overlay if it already shows resident household information
- household debug inspector is acceptable if useful
- avoid crowding the City Overview sidebar unless there is no better location

# Allowed Files

- `scripts/ui/household_lifecycle_display_helper.gd`

# Blocked Files

- `scripts/main.gd`
- `scripts/domain/`
- `scripts/simulation/`
- `scripts/world/`
- `scenes/`
- `project.godot`
- `docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md`

# Helper Requirements

Create:

- `class_name HouseholdLifecycleDisplayHelper`
- `static func get_lifecycle_lines(household) -> Array[String]`

The helper should return concise player-facing lines such as:

- `Stage: Established family`
- `Children: 1 young, 2 older, 0 adult`
- `Family trade: General`
- `Succession: No pressure`
- `Age in stage: 0`

Fallback:

- `No household lifecycle details.`

# Implementation Guidance

- Read-only only.
- Use defensive null checks.
- Safely handle missing lifecycle fields.
- Return `Array[String]`.
- Keep labels short and player-facing.
- Use simple label formatting; no UI drawing.
- No mutation.
- No lifecycle ticking.
- No family splitting.
- No death/removal behavior.
- No production bonuses.
- No assignment changes.
- No city, resource, or formula changes.
- No money, credit, debt, or obligation concepts.

# Do Not

- Do not edit `scripts/main.gd`.
- Do not edit `scripts/domain/`.
- Do not edit existing UI files.
- Do not create scenes or assets.
- Do not use textures, preloads, or Control nodes.
- Do not add input handling.
- Do not add drawing code.
- Do not call assignment, production, resource, or lifecycle mutation methods.

# Definition Of Done

- Helper returns readable lines for lifecycle fields.
- Helper safely handles null or missing household data.
- Validation passes.
- No UI integration yet.
- No lifecycle ticking yet.
- No family splitting yet.
- No death behavior yet.
- No production bonus behavior yet.

# Manual Review Checklist

- Confirm helper defines `HouseholdLifecycleDisplayHelper`.
- Confirm `get_lifecycle_lines(household)` returns `Array[String]`.
- Confirm it references all lifecycle fields.
- Confirm null/missing household fallback is safe.
- Confirm no mutation or gameplay logic exists.
- Confirm no input, draw, texture, scene, or preload code exists.

# Validation

Run:

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Local-Agent Command

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\household-lifecycle-display-v0.md -NoCommit
```

# Final Report

Report:

- helper file created
- fields displayed
- fallback behavior
- validation result
- whether ready for Codex/manual UI integration
