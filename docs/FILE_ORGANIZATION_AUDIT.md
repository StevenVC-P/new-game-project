# File Organization Audit

This is a read-only audit. No Godot game files were moved as part of this note.

## Current Structure

The project currently keeps most game source at the repository root:

- `project.godot`: project configuration. Main scene is `res://main.tscn`; icon is `res://icon.svg`. No autoload section is present.
- `main.tscn`: only scene currently found. It has a `Node2D` root named `Main` and references `res://main.gd`.
- `main.gd`: main scene controller, input handling, map/city view orchestration, drawing, and simulation loop.
- `icon.svg` and `icon.svg.import`: project icon and generated Godot import metadata.

Current folders:

- `docs/`: project documentation and local-agent runner docs.
- `scripts/`: repository tooling, not game scripts.
- `tasks/`: local-agent task definitions.
- `.godot/` and `.godot-exe`: local machine/editor state, not source organization targets.

## Root-Level Game Scripts

- `building.gd`: `Building` data model for placed buildings, worker assignment, maintenance, and production-related metadata.
- `building_placement.gd`: `BuildingPlacement` validation helper for city-map building footprints, costs, and placement rules.
- `building_visuals.gd`: `BuildingVisuals` drawing helpers and glyph definitions for building presentation.
- `calendar.gd`: `Calendar` date, month, year, and season progression.
- `city.gd`: `City` simulation model. Large/high-risk file covering households, buildings, resources, production, consumption, housing, assignment, and pressure.
- `city_building_overlay.gd`: `CityBuildingOverlay` UI/interaction helper for building and household inspection overlays.
- `household.gd`: `Household` data model for residence, labor capacity, worker assignment, and preference.
- `local_city_map_generator.gd`: `LocalCityMapGenerator` local settlement map generation and morphology.
- `main.gd`: central runtime controller and main scene script. Very high risk to move or refactor first.
- `map_element_visuals.gd`: `MapElementVisuals` drawing helpers for map elements.
- `region_map_generator.gd`: `RegionMapGenerator` regional terrain, city placement, roads, and resources.
- `settlement_site_profile.gd`: `SettlementSiteProfile` analysis data and scoring for city-site context.
- `simulation_clock.gd`: `SimulationClock` realtime-to-days progression and speed controls.
- `terrain_visuals.gd`: `TerrainVisuals` drawing helpers and terrain motif/color behavior.
- `trade_menu.gd`: `TradeMenu` interactive trade-route UI state and input handling.
- `trade_route.gd`: `TradeRoute` data and transfer behavior.
- `visual_style.gd`: `VisualStyle` shared colors, spacing, and drawing constants.

All listed `.gd` files are currently root-level and paired with `.gd.uid` metadata files. If scripts are moved later, move each `.gd.uid` companion with its script.

## References Found

Direct `res://` references found:

- `project.godot`: `run/main_scene="res://main.tscn"`.
- `project.godot`: `config/icon="res://icon.svg"`.
- `main.tscn`: script ExtResource path `res://main.gd`.

No autoload section was found in `project.godot`.

Most script-to-script coupling appears to use `class_name` references such as `City`, `Household`, `RegionMapGenerator`, `TradeMenu`, and `VisualStyle`, rather than explicit `preload("res://...")` paths. That makes later script moves more feasible, but Godot metadata and scene references still need careful validation.

## Recommended Future Structure

A possible future structure, based on the current files:

- `scenes/`
  - `main.tscn`
- `scripts/core/`
  - `main.gd`
  - `simulation_clock.gd`
  - `calendar.gd`
- `scripts/simulation/`
  - `city.gd`
  - `household.gd`
  - `building.gd`
  - `trade_route.gd`
- `scripts/world/`
  - `region_map_generator.gd`
  - `local_city_map_generator.gd`
  - `settlement_site_profile.gd`
- `scripts/placement/`
  - `building_placement.gd`
- `scripts/ui/`
  - `trade_menu.gd`
  - `city_building_overlay.gd`
- `scripts/visuals/`
  - `visual_style.gd`
  - `terrain_visuals.gd`
  - `building_visuals.gd`
  - `map_element_visuals.gd`
- `assets/`
  - `icon.svg`

Before using `scripts/` for game code, consider moving current repository tooling to `tools/` or `dev-scripts/` in a separate cleanup. Do not mix game scripts and maintenance scripts without a naming convention.

## Move Risk

Higher-risk moves:

- `main.tscn`: referenced by `project.godot`.
- `main.gd`: referenced directly by `main.tscn` and central to runtime behavior.
- `project.godot`: should not be changed except during a targeted scene-path update.
- `city.gd`, `main.gd`, `region_map_generator.gd`, and `local_city_map_generator.gd`: large, central, and likely to surface broad breakage if moved with unrelated changes.

Lower-risk candidates for a later first move batch:

- Visual helper scripts: `visual_style.gd`, `terrain_visuals.gd`, `building_visuals.gd`, `map_element_visuals.gd`.
- Small support models: `trade_route.gd`, `calendar.gd`, `simulation_clock.gd`.

Even lower-risk files should be moved in small batches with their `.gd.uid` files and validated immediately.

## Staged Migration Plan

1. Create target folders only, with no file moves.
2. Move one low-risk batch, such as visual helper scripts plus `.gd.uid` companions.
3. Validate with:

```powershell
$env:GODOT_BIN = Get-Content .godot-exe -TotalCount 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_project.ps1
```

4. Open the project in Godot if practical and confirm class names still resolve.
5. Commit the batch if validation passes.
6. Repeat with small support models.
7. Move world-generation scripts.
8. Move simulation model scripts.
9. Move `main.gd` and `main.tscn` only in a final dedicated branch that updates `main.tscn` and `project.godot` paths together.

## References To Update Later

- Moving `main.tscn` requires updating `project.godot`.
- Moving `main.gd` requires updating the ExtResource path in `main.tscn`.
- Moving `icon.svg` requires updating `project.godot`, and Godot import metadata may regenerate.
- Moving scripts may require Godot to update or regenerate `.gd.uid` associations. Keep `.gd.uid` files paired with their scripts during moves.

## Rollback Notes

- Use one branch per move batch.
- Commit before each batch.
- If validation fails after a move batch, restore only the moved files and their `.gd.uid` companions.
- Avoid broad `git reset --hard` unless explicitly requested.
- Keep move-only commits separate from refactors or gameplay changes.

## Recommended First Move Batch

Do not execute this yet. The safest first batch later is likely:

- `visual_style.gd` and `visual_style.gd.uid`
- `terrain_visuals.gd` and `terrain_visuals.gd.uid`
- `building_visuals.gd` and `building_visuals.gd.uid`
- `map_element_visuals.gd` and `map_element_visuals.gd.uid`

Rationale: these are presentation helpers, not scene roots or project settings. The batch still needs immediate validation because `main.gd` and other scripts reference their `class_name`s.
