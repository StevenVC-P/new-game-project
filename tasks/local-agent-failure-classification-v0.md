---
id: local-agent-failure-classification-v0
title: Local Agent Failure Classification v0
base_branch: develop
branch_name: feature/local-agent-failure-classification-v0
edit_mode: json_file_ops
allowed_paths:
  - scripts/agent_runner.ps1
  - docs/LOCAL_AGENT_RUNNER.md
  - docs/LOCAL_AGENT_MULTI_AGENT_WORKFLOW.md
  - tasks/local-agent-failure-classification-v0.md
blocked_paths:
  - project.godot
  - scenes/
  - scripts/domain/
  - scripts/simulation/
  - scripts/world/
  - scripts/main.gd
  - scripts/ui/
  - docs/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md
required_paths:
  - scripts/agent_runner.ps1
  - docs/LOCAL_AGENT_RUNNER.md
max_files_changed: 3
max_lines_added: 260
max_lines_deleted: 80
allow_new_files: false
allow_replacements: false
allow_deletes: false
allow_renames: false
validation_command: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
commit_message: "feat: classify local agent failures"
required_content_by_path:
  scripts/agent_runner.ps1:
    - "failure_classes"
    - "primary_failure_class"
    - "recommended_next_agent"
    - "safe_to_auto_repair"
    - "task_tuning_recommended"
    - "owner_review_required"
    - "unknown_failure"
  docs/LOCAL_AGENT_RUNNER.md:
    - "Failure classification"
blocked_content:
  - "add_resource"
  - "remove_resource"
  - "apply_building_production"
  - "consume_food"
  - "city_credit"
  - "obligation"
  - "debt"
  - "currency"
  - "select_building_type"
  - "preload"
  - "texture"
  - ".tscn"
---

# Goal

Implement Local Agent Failure Classification v0 in the project-local runner.

When a local-agent run fails, classify the failure based only on runner-observed evidence and write the classification into the run report. Optionally also write:

- `docs/agent-runs/<run-id>/failure-classification.json`

This is classification/reporting only. Do not implement auto-repair, specialist-agent invocation, extra model calls, or automatic commits of failed outputs.

# Context

`docs/LOCAL_AGENT_MULTI_AGENT_WORKFLOW.md` defines the multi-agent failure-handling workflow. The first implementation phase is deterministic failure classification reporting only.

The runner now supports flexible content checks:

- `required_all_by_path`
- `required_any_by_path`
- `required_phrase_or_terms_by_path`

This task should build on that runner/reporting foundation without changing feature-task behavior.

# Failure Classes

Classify failed runs into one or more of:

- `content_check_failed`
- `blocked_content_found`
- `anchor_not_found`
- `validation_parse_error`
- `validation_runtime_error`
- `large_replacement_rejected`
- `model_api_error`
- `task_spec_conflict`
- `repeated_same_failure`
- `broad_integration_failure`
- `unknown_failure`

# Classification Fields

The classification should include:

- `failure_classes`
- `primary_failure_class`
- `evidence`
- `recommended_next_agent`
- `safe_to_auto_repair`
- `task_tuning_recommended`
- `owner_review_required`
- `recommended_action`

# Routing Expectations

- Missing required tokens -> `content_check_failed` -> Task Tuning Agent or Repair Agent.
- Blocked token present -> `blocked_content_found` -> Reviewer Agent or Task Tuning Agent.
- Insert anchor not found -> `anchor_not_found` -> Integration Context Agent.
- Godot parse errors -> `validation_parse_error` -> Repair Agent.
- Serious validation runtime/import errors -> `validation_runtime_error` -> Validation Specialist.
- Large replacement rejected -> `large_replacement_rejected` -> Task Tuning Agent / owner review.
- LM Studio/model errors -> `model_api_error` -> stop/report.
- Repeated same rejection across attempts -> `repeated_same_failure`.
- Repeated `main.gd` draw/input/state integration failure -> `broad_integration_failure`.

# Implementation Guidance

Keep the implementation deterministic and local:

- Classify from runner-observed strings, exit codes, attempt lines, validation summaries, and rejection messages.
- Do not call a model for classification.
- Do not invoke downstream specialist agents.
- Do not change retry behavior.
- Do not change validation behavior.
- Do not automatically repair.
- Do not automatically commit failed outputs.
- Successful runs should remain unaffected, or receive only a neutral/success classification if that is simpler.
- Failed runs should include a clear `Failure Classification` section in `report.md`.
- If writing `failure-classification.json`, keep it inside the current run artifact directory.
- Keep report wording concise and factual.

# Documentation

Update `docs/LOCAL_AGENT_RUNNER.md` to explain:

- what failure classification is
- when it appears in reports
- classification fields
- a few common examples
- that classification is advisory and does not trigger automatic repair or specialist agents

Update `docs/LOCAL_AGENT_MULTI_AGENT_WORKFLOW.md` only if needed to align wording with the implementation.

# Do Not

- Do not change gameplay.
- Do not edit feature scripts.
- Do not edit `scripts/main.gd`.
- Do not edit `scripts/ui/`.
- Do not edit domain, simulation, world, scene, project, money, credit, or obligation files.
- Do not run local-agent feature tasks.
- Do not implement auto-repair.
- Do not invoke specialist agents.
- Do not run extra model calls after failure.
- Do not broaden model authority over files, commits, validation, or rollback.

# Definition Of Done

- Failed runs include a failure classification section in `report.md`.
- Failed runs optionally include `failure-classification.json`.
- Successful runs remain unaffected except no classification or a neutral/success classification.
- Classification is deterministic from runner-observed errors.
- No extra model calls are made.
- No auto-repair occurs.
- Existing validation behavior is preserved.
- Docs explain the classification fields and examples.
- Validation passes.

# Validation

Run:

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

# Commit

Use:

```text
feat: classify local agent failures
```

# Final Report

Report:

- files changed
- classification logic added
- whether `failure-classification.json` was implemented
- docs updated
- validation result
- example classification for a missing required-token failure
