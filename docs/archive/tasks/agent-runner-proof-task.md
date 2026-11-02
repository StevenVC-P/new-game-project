---
id: agent-runner-proof-task
title: Add local agent proof report
base_branch: develop
branch_name: agent/proof-runner-v0
edit_mode: json_file_ops
allowed_paths:
  - docs/
blocked_paths:
  - project.godot
  - scripts/main.gd
  - scenes/main.tscn
  - scripts/
  - scenes/
max_files_changed: 2
max_lines_added: 100
max_lines_deleted: 50
allow_new_files: true
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "test: verify local agent runner"
---

# Local Agent Runner Proof Task

## Goal

Create one harmless documentation file at `docs/AGENT_JSON_PROOF_OF_WORK.md` proving the local LLM runner can make a documentation-only change through structured JSON file operations, validation, and reporting.

## Scope

- Documentation only.
- Allowed path: `docs/`.
- Target file: `docs/AGENT_JSON_PROOF_OF_WORK.md`.
- Do not edit gameplay scripts, scenes, resources, project settings, or runner scripts.

## Acceptance Criteria

- The JSON edit manifest creates no more than two files.
- The JSON edit manifest creates `docs/AGENT_JSON_PROOF_OF_WORK.md`.
- All changed files are under `docs/`.
- No files are replaced, deleted, or renamed.
- Validation is attempted with the configured validation command.
- The final report records changed files, validation status, and commit hash if committed.
