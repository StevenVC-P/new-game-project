---
id: agent-runner-proof-task
title: Add local agent proof report
base_branch: develop
branch_name: agent/proof-runner-v0
allowed_paths:
  - docs/
blocked_paths:
  - project.godot
  - main.gd
  - main.tscn
  - scripts/
  - scenes/
max_files_changed: 2
max_lines_added: 100
max_lines_deleted: 50
allow_new_files: true
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "test: verify local agent runner"
---

# Local Agent Runner Proof Task

## Goal

Create or update a harmless documentation file proving the local LLM runner can make a documentation-only change through patch application, validation, and reporting.

## Scope

- Documentation only.
- Allowed path: `docs/`.
- Do not edit gameplay scripts, scenes, resources, project settings, or runner scripts.

## Acceptance Criteria

- The patch changes no more than two files.
- All changed files are under `docs/`.
- No files are deleted or renamed.
- Validation is attempted with the configured validation command.
- The final report records changed files, validation status, and commit hash if committed.
