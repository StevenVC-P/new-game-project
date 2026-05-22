# File Organization Migration Plan

This document records the completed organization pass that moved the remaining loose Godot game files into folders while preserving behavior.

## Final Folder Structure

```text
scenes/
  main.tscn

scripts/
  main.gd
  main.gd.uid

scripts/simulation/
  calendar.gd
  calendar.gd.uid
  simulation_clock.gd
  simulation_clock.gd.uid

scripts/domain/
  building.gd
  building.gd.uid
  city.gd
  city.gd.uid
  household.gd
  household.gd.uid
  settlement_site_profile.gd
  settlement_site_profile.gd.uid
  trade_route.gd
  trade_route.gd.uid

scripts/world/
  local_city_map_generator.gd
  local_city_map_generator.gd.uid
  region_map_generator.gd
  region_map_generator.gd.uid

scripts/ui/
  building_placement.gd
  building_placement.gd.uid
  city_building_overlay.gd
  city_building_overlay.gd.uid
  trade_menu.gd
  trade_menu.gd.uid

scripts/visuals/
  building_visuals.gd
  building_visuals.gd.uid
  map_element_visuals.gd
  map_element_visuals.gd.uid
  terrain_visuals.gd
  terrain_visuals.gd.uid
  visual_style.gd
  visual_style.gd.uid
```

Repository tooling remains in `scripts/` alongside `scripts/main.gd` for now. A later cleanup can move non-game tooling into `tools/` or `dev-scripts/` if desired.

## Files Moved

Visual helpers were moved first in `574344a chore: move visual helper scripts`:

- `building_visuals.gd` -> `scripts/visuals/building_visuals.gd`
- `map_element_visuals.gd` -> `scripts/visuals/map_element_visuals.gd`
- `terrain_visuals.gd` -> `scripts/visuals/terrain_visuals.gd`
- `visual_style.gd` -> `scripts/visuals/visual_style.gd`

The remaining organization pass moved:

- `main.tscn` -> `scenes/main.tscn`
- `main.gd` -> `scripts/main.gd`
- `calendar.gd` -> `scripts/simulation/calendar.gd`
- `simulation_clock.gd` -> `scripts/simulation/simulation_clock.gd`
- `building.gd` -> `scripts/domain/building.gd`
- `city.gd` -> `scripts/domain/city.gd`
- `household.gd` -> `scripts/domain/household.gd`
- `settlement_site_profile.gd` -> `scripts/domain/settlement_site_profile.gd`
- `trade_route.gd` -> `scripts/domain/trade_route.gd`
- `region_map_generator.gd` -> `scripts/world/region_map_generator.gd`
- `local_city_map_generator.gd` -> `scripts/world/local_city_map_generator.gd`
- `building_placement.gd` -> `scripts/ui/building_placement.gd`
- `city_building_overlay.gd` -> `scripts/ui/city_building_overlay.gd`
- `trade_menu.gd` -> `scripts/ui/trade_menu.gd`

Each `.gd.uid` companion moved with its `.gd` script.

## References Updated

Required Godot references:

- `project.godot`: `run/main_scene` now points to `res://scenes/main.tscn`.
- `scenes/main.tscn`: script ExtResource now points to `res://scripts/main.gd`.

Documentation and task references were updated where they describe current file locations:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `ROADMAP.md`
- `docs/PROJECT_OWNER_QUESTIONS.md`
- `tasks/agent-runner-proof-task.md`
- `tasks/backlog/*`

Historical handoff text in `docs/CODEX_TO_LOCAL_AGENT_HANDOFF.md` was left unchanged because it records past task prompts and decisions.

## Validation

Validation command:

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

Expected result: exit code `0`.

The known Godot editor-settings save warning may appear after a successful validation pass.

Completed validation for this migration passed with exit code `0`. Godot also reported a local editor-layout navigation warning for the old `res://main.tscn` path; the committed project configuration now uses `res://scenes/main.tscn`.

## Risks

- `project.godot` and `scenes/main.tscn` were changed only because moving `main.tscn` and `main.gd` required path updates.
- Script classes are still referenced mostly through `class_name`, so script-to-script behavior should remain unchanged.
- This pass does not refactor `scripts/main.gd`; it only moves it.
- Tooling scripts and game scripts now share the top-level `scripts/` folder. This is acceptable for this pass but can be revisited later.

## Follow-Up Cleanup

Recommended next cleanup tasks:

1. Run the main scene manually in Godot and confirm runtime behavior, input, drawing, and simulation flow still work.
2. Consider moving repository tooling from `scripts/` to `tools/` or `dev-scripts/` in a separate branch.
3. Update older historical docs only if they are actively reused as current task prompts.
