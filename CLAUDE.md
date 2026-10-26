# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A household-rooted civilization sandbox: founding families on a frontier grow into lineages, Houses, and settlements, with culture and economics building on each other. Identity and status live in `project.md`.

**Read `AGENTS.md` first.** It holds the binding working rules: branch from `develop`, never work on or merge to `main` without review, high-risk files, and validation. This file adds commands and pointers, not a second rule set.

## Design Sources

Design decisions are owner-confirmed and authoritative. Check them before changing gameplay:

- `docs/GAME_VISION.md` - objectives, pace, experience; wins over any other doc on conflict
- `docs/IMPLEMENTATION_ROADMAP.md` - milestones to the first playable village, with the formula changes each milestone is authorized to make
- System models: `docs/ECONOMY_MODEL.md`, `docs/SIMULATION_SCALE_MODEL.md`, `docs/HOUSES_AND_LINEAGE_MODEL.md`, `docs/CULTURE_AND_VALUES_MODEL.md`, `docs/WARFARE_AND_CONFLICT_MODEL.md`, `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md`
- `docs/household_simulation_philosophy.md` and `docs/PROJECT_OWNER_QUESTIONS.md` - the household-first rules

## Tech Stack

Godot 4.6 (Forward Plus, Jolt Physics), GDScript only. No external dependencies.

## Commands

The Godot executable path is in the local, untracked `.godot-exe` file.

```powershell
# Validate (headless import pass; the pre-commit gate)
$env:GODOT_BIN = (Get-Content .godot-exe).Trim(); .\scripts\validate_project.ps1

# Run one test (tests extend SceneTree and quit with a non-zero code on failure)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/founding_city_validation.gd

# Opening check: can 20 different towns get off the ground in two years? (filter for [OPEN])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/opening_check.gd

# Map luck: 48 towns on real generated maps and sites (filter for [MAP])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/map_luck_check.gd

# Multi-year settlement run, yearly report (filter output for [SIM])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/settlement_growth_run.gd

# Household simulation benchmark (filter output for [BENCH]; takes several minutes)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd

# World map: data checks, and the hand-off into the regional/founding flow
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_flow_validation.gd

# World map screenshots for visual review (needs a window, so no --headless)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/world_map_capture.gd -- <output_dir>

# Regional map: data checks (world-driven generation, unchanged original maps, decoration follows data, founding)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/region_map_validation.gd

# Regional map screenshots: showcases with [PERF] render times, and the real enter/found/return flow (needs a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_map_capture.gd -- <output_dir>
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_flow_capture.gd -- <output_dir>
```

`scenes/region_map_demo.tscn` shows the regional map showcases on their own (keys 1-6, G for a grown town).

`tests/expanded_goods_production_validation.gd` extends `RefCounted`, so it cannot be run with `--script` directly; load it from a small `SceneTree` wrapper and call `run_all()`.

## Architecture

- `scripts/main.gd` - large central scene script: map input, drawing, UI, day ticking, trade. High-risk; avoid adding new simulation logic here.
- `scripts/domain/` - simulation model: `city.gd` (resources, households, buildings, growth, lifecycle orchestration), `household.gd` (family structure, lifecycle, labor), `building.gd`.
- `scripts/simulation/` - `calendar.gd` and `simulation_clock.gd` (1 day = 1 real second at 1x).
- `scripts/world/` - regional and local map generation, founding-site helpers, and the world map's data (`world_map_data.gd`), authored planet (`fixed_world_definition.gd`), and builder (`world_field_builder.gd`).
- `scripts/visuals/world_map/` and `shaders/world_terrain.gdshader` - the world atlas renderer; the game opens on it (`VIEW_WORLD` in `main.gd`). Design, decisions, and remaining integration work: `docs/WORLD_MAP.md`.
- `scripts/world/region_geography.gd`, `scripts/visuals/region_map/`, and `shaders/region_terrain.gdshader` - the regional map: world geography steers `region_map_generator.gd` (whose original path must stay byte-identical; `tests/region_map_validation.gd` checks fingerprints), and `RegionMapView` draws the miniature landscape under `main.gd`'s panels. Decoration must never show what the tile data does not hold. Details: `docs/REGIONAL_MAP.md`.
- `scripts/ui/`, `scripts/visuals/` - panels, helpers, drawing.
- Daily `City.tick()`, monthly `advance_household_lifecycle_month()`, and seasonal birth rolls are driven by calendar signals in `main.gd`.
- Performance limits and their causes are measured in `docs/HOUSEHOLD_SIM_BENCHMARK.md`.
- Every economy number (starting stock, outputs, upkeep, construction costs) lives in `scripts/domain/economy_balance.gd`.
