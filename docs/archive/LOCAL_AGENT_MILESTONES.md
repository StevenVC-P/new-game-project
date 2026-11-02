# Local Agent Milestones

This file records completed local-agent-assisted milestones and what they taught us about the workflow.

## City Pressure Debug Panel v0

- Date: 2026-05-23
- Branch: `feature/city-pressure-debug-panel-v0`
- Final commit: `cd82409 feat: add city pressure debug panel`
- Model: `qwen/qwen3-coder-30b`
- Runner mode: JSON file operations with `-NoCommit` during implementation attempts
- Files changed:
  - `scripts/ui/city_pressure_debug_panel.gd`
  - `scripts/ui/city_pressure_debug_panel.gd.uid`
  - `scripts/main.gd`
- Validation result: passed on `develop`
- Manual test result: passed after Codex repair and visual/runtime retesting

Final behavior:

- F4 toggles the City Pressure Diagnostics panel in city view.
- The panel is hidden or unavailable outside city view and the regional map.
- The panel shows formatted food, shelter, labor, tools, and maintenance pressure diagnostics.
- The panel shows compact source values that explain the pressure data behind the City Overview sidebar.
- The panel is read-only and does not mutate city, household, resource, trade, production, housing, calendar, or formula state.

What worked:

- Qwen3 Coder 30B can produce useful bounded UI drafts when the runner constrains paths, operations, and expected content.
- Path-specific content checks fixed the multi-file task issue where UI-script tokens were incorrectly applied to `scripts/main.gd`.
- Targeted `insert_after` and `insert_before` edits avoided destructive `scripts/main.gd` replacement.
- Runner progress logging made long local-model runs understandable enough to monitor.
- Enhanced Godot validation caught parse/log errors even when Godot exited 0.
- Codex review/repair turned a mechanically valid local-agent draft into a runtime-tested feature.

Failure modes encountered:

- Global content checks were too broad for multi-file tasks.
- The local model initially invented invalid `scripts/main.gd` state names such as `current_city`.
- The local model initially used invalid view checks such as `current_view == "city"` instead of existing constants.
- The local model produced Godot 3-style UI properties such as `rect_position`.
- Godot import validation did not catch every `_ready()` runtime UI error.
- UI layout issues, including clipping, required manual visual testing.
- `scripts/main.gd` remains a risky integration surface and should receive only tiny anchored edits.

Next workflow improvement recommendations:

- Add a runtime UI smoke-test harness for debug panels and lightweight Control scripts.
- Create a debug panel manager or debug UI extension point so future panels do not require repeated direct `scripts/main.gd` edits.
- Prefer new standalone scripts plus tiny anchored integrations for local-agent feature tasks.
- Keep Codex review and repair for integration tasks, especially anything touching `scripts/main.gd`.
- Keep using `qwen/qwen3-coder-30b` for bounded implementation drafts with `-NoCommit`, required paths, path-specific content checks, preserve checks, and manual runtime testing.
