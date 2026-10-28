# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A household-rooted civilization sandbox: founding families on a frontier grow into lineages, Houses, and settlements, with culture and economics building on each other. Identity and status live in `project.md`.

**Read `AGENTS.md` first.** It holds the binding working rules: branch from `develop`, never work on or merge to `main` without review, high-risk files, and validation. Current status, open owner decisions, and gotchas: `docs/HANDOFF.md`.

## Design Sources

Owner-confirmed and authoritative; check before changing gameplay. `docs/GAME_VISION.md` wins on conflict. Current plan: `docs/FIRST_STAGE_LOOP.md` (six milestones, terms for working with less owner input). Also `docs/IMPLEMENTATION_ROADMAP.md`, the system models (`docs/*_MODEL.md`), `docs/household_simulation_philosophy.md`, and `docs/PROJECT_OWNER_QUESTIONS.md`.

## Tech Stack

Godot 4.6 (Forward Plus, Jolt Physics), GDScript only. No external dependencies.

## Commands

The Godot executable path is in the local, untracked `.godot-exe` file. Every test, balance check, and screenshot script: `docs/TESTING.md`.

```powershell
# Validate (headless import pass; the pre-commit gate)
$env:GODOT_BIN = (Get-Content .godot-exe).Trim(); .\scripts\validate_project.ps1

# Run one test (tests extend SceneTree and quit with a non-zero code on failure)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/founding_city_validation.gd
```

Balance checks live in `tests/sim/` (opening, map luck, town building, planning, site variety). Write their output to a file: piping Godot's household log stalls it on Windows.

## Architecture

Details: `docs/ARCHITECTURE.md`.

- `scripts/app.gd` (main scene) runs menus and saves; `scripts/main.gd` is the game: input, UI, day ticking. `main.gd` is high-risk: no new simulation logic there, and a click that switches views must call `get_viewport().set_input_as_handled()`.
- `scripts/domain/` is the simulation (`city.gd`, `household.gd`, `building.gd`, and the town systems on `City`). Every economy number lives in `economy_balance.gd`.
- Saves (`scripts/persistence/`, `docs/SAVED_GAMES.md`): domain fields save automatically; new object-valued fields, caches, and new `main.gd` state need a line in `GameState`.
- Building goes through one pipeline for player and families; nothing is placed finished in play (`City.add_building` is what a finished project calls). `docs/TOWN_BUILDING_MODEL.md`.
- Determinism: generated worlds per seed, town maps per site (no game RNG), and regional tiles a pure function of global position. The original `region_map_generator.gd` must stay byte-identical (fingerprint test). Call `RegionalTerrain.wait_for_tasks()` before quitting a script that streamed chunks.
- Never draw the town in `main.gd`'s `_draw`; the town map has its own view (`docs/TOWN_MAP.md`).
