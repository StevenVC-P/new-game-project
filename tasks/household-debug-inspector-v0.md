---
id: household-debug-inspector-v0
title: Add Household Settlement Debug Inspector v0
base_branch: develop
branch_name: feature/household-debug-inspector-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/ui/
  - scenes/debug/
required_paths:
  - scripts/ui/household_debug_inspector.gd
  - scenes/debug/household_debug_inspector_demo.tscn
blocked_paths:
  - docs/example.md
  - project.godot
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scripts/main.gd
  - scenes/main.tscn
max_files_changed: 2
max_lines_added: 300
max_lines_deleted: 50
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: add household debug inspector v0"
---

# Goal

Create a standalone read-only Household Settlement Debug Inspector v0 demo scene and script.

# Scope

Create a minimal UI/debug inspector that can display household-settlement summary information where available.

The inspector should be small and read-only. It must not change simulation formulas, household behavior, production, trade, calendar logic, or map generation.

# Preferred Implementation

Create exactly these files:

- `scripts/ui/household_debug_inspector.gd`
- `scenes/debug/household_debug_inspector_demo.tscn`

Do not wire the inspector into `scenes/main.tscn` yet. The scene may use placeholder/fallback values if live city data is not available. The purpose of this v0 is to prove the local agent can create a coherent Godot-facing UI artifact in the right location.

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
- Do not create docs/example.md

# Definition of Done

- Inspector script exists at `scripts/ui/household_debug_inspector.gd` and is read-only.
- Demo scene exists at `scenes/debug/household_debug_inspector_demo.tscn`.
- Demo scene opens independently and is not wired into the main scene.
- Validation passes.
- No simulation behavior changes.
