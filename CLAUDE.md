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

# Household simulation benchmark (filter output for [BENCH]; takes several minutes)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd
```

`tests/expanded_goods_production_validation.gd` extends `RefCounted`, so it cannot be run with `--script` directly; load it from a small `SceneTree` wrapper and call `run_all()`.

## Architecture

- `scripts/main.gd` - large central scene script: map input, drawing, UI, day ticking, trade. High-risk; avoid adding new simulation logic here.
- `scripts/domain/` - simulation model: `city.gd` (resources, households, buildings, growth, lifecycle orchestration), `household.gd` (family structure, lifecycle, labor), `building.gd`.
- `scripts/simulation/` - `calendar.gd` and `simulation_clock.gd` (1 day = 1 real second at 1x).
- `scripts/world/` - regional and local map generation, founding-site helpers.
- `scripts/ui/`, `scripts/visuals/` - panels, helpers, drawing.
- Daily `City.tick()`, monthly `advance_household_lifecycle_month()`, and seasonal birth rolls are driven by calendar signals in `main.gd`.
- Performance limits and their causes are measured in `docs/HOUSEHOLD_SIM_BENCHMARK.md`.
