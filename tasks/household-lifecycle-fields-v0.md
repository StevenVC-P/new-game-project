---
id: household-lifecycle-fields-v0
title: Household Lifecycle Fields v0
base_branch: develop
branch_name: feature/household-lifecycle-fields-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/domain/household.gd
  - docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md
blocked_paths:
  - scripts/main.gd
  - scripts/ui/
  - scripts/domain/city.gd
  - scripts/domain/building.gd
  - scripts/simulation/
  - scripts/world/
  - scenes/
  - project.godot
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/domain/household.gd
max_files_changed: 2
max_lines_added: 120
max_lines_deleted: 20
allow_new_files: false
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household lifecycle fields"
required_content_by_path:
  scripts/domain/household.gd:
    - "lifecycle_stage"
    - "young_children"
    - "older_children"
    - "adult_children"
    - "family_trade"
    - "succession_pressure"
    - "age_in_stage"
preserve_content:
  - "func update_labor_capacity():"
  - "func assign_to_building"
  - "func unassign_from_building"
  - "func get_match_quality"
  - "labor_capacity"
  - "worker_capacity"
blocked_content:
  - "add_resource"
  - "remove_resource"
  - "apply_building_production"
  - "consume_food"
  - "queue_free"
  - "erase("
  - "remove_at"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - "new_family"
  - "create_household"
  - "split"
  - "death"
  - "deceased"
  - "tick"
  - ".tscn"
---

# Goal

Add conservative household-level lifecycle data fields only.

This is the first implementation slice from `docs/HOUSEHOLD_LIFECYCLE_SUCCESSION_MODEL.md`. It should prepare household records for future lifecycle display and later behavior without changing gameplay formulas or simulation outcomes yet.

# Scope

Allowed files:

- `scripts/domain/household.gd`
- `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md`

Required file:

- `scripts/domain/household.gd`

Do not edit:

- `scripts/main.gd`
- `scripts/ui/`
- `scripts/domain/city.gd`
- `scripts/domain/building.gd`
- `scripts/simulation/`
- `scripts/world/`
- `scenes/`
- `project.godot`
- `docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md`

# Required Fields

Add these household-level fields with safe defaults:

- `lifecycle_stage`
- `young_children`
- `older_children`
- `adult_children`
- `family_trade`
- `succession_pressure`
- `age_in_stage`

Suggested conservative defaults:

- `lifecycle_stage = "established_family"` or another current-equivalent safe default
- child counters = `0`
- `family_trade = "general"` unless mapping from existing `preference` is simple and safe
- `succession_pressure = 0`
- `age_in_stage = 0`

# Optional Read-Only Helpers

Simple read-only helper methods are acceptable if they stay small:

- `get_lifecycle_stage_label()`
- `get_child_summary()`
- `get_family_trade_label()`
- `has_succession_pressure()`

Helpers must not mutate state or change formulas.

# Requirements

- Preserve existing population behavior.
- Preserve existing `labor_capacity` behavior.
- Preserve existing `worker_capacity` behavior.
- Preserve existing assignment behavior.
- Preserve existing `preference` and fit behavior.
- Do not change production output.
- Do not change household creation or removal.
- Do not change city ticking.
- Do not change housing assignment.
- Do not create new families.
- Do not age households yet.
- Do not free houses yet.
- Do not add lifecycle production bonuses.
- Do not add multi-household building support.
- Do not implement money, credit, debt, or obligation.

# Documentation

Update `docs/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md` only if needed to state that lifecycle fields now exist as data-only scaffolding.

If documentation is updated, keep it factual:

- lifecycle fields exist on households
- v0 does not change labor, population, production, housing, or family formation behavior
- lifecycle ticking, succession pressure effects, production support, death, and new-family formation are future work

# Definition Of Done

- Household instances have lifecycle fields with safe defaults.
- Existing game behavior remains unchanged.
- Validation passes.
- No UI yet.
- No lifecycle ticking yet.
- No family splitting yet.
- No death behavior yet.
- No production bonus behavior yet.

# Validation

Run:

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Local-Agent Command

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\agent_runner.ps1 -Task .\tasks\household-lifecycle-fields-v0.md -NoCommit
```

# Final Report

Report:

- files changed
- fields added
- whether docs were updated
- validation result
- whether behavior was kept unchanged
