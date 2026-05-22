---
id: household-debug-inspector-v0
title: Add Household Settlement Debug Inspector v0
base_branch: develop
branch_name: feature/household-debug-inspector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/
  - scenes/
  - docs/
blocked_paths:
  - project.godot
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scripts/main.gd
max_files_changed: 3
max_lines_added: 300
max_lines_deleted: 50
allow_new_files: true
allow_replacements: true
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household debug inspector v0"
---

# Goal

Add a small read-only Household Settlement Debug Inspector v0.

# Scope

Create a minimal UI/debug inspector that can display household-settlement summary information where available.

The inspector should be small and read-only. It must not change simulation formulas, household behavior, production, trade, calendar logic, or map generation.

# Preferred Implementation

Prefer adding a new script under scripts/ui/.

If scene wiring is required, limit scene edits to the minimum necessary.

# Display Fields

Show available values only. Use fallback text if a value is not accessible.

Desired fields:
- household count
- total population
- housing capacity or pressure
- food amount or food pressure
- assigned responsibilities or labor coverage
- basic resources if already accessible

# Forbidden

- Do not edit scripts/domain/
- Do not edit scripts/simulation/
- Do not edit scripts/world/
- Do not edit formulas
- Do not change household labor semantics
- Do not modify project.godot
- Do not redesign scenes/main.tscn
- Do not rename nodes/classes/files

# Definition of Done

- Inspector exists and is read-only.
- It is visible or clearly documented how to view it.
- Validation passes.
- No simulation behavior changes.
