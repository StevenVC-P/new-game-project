# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A household-rooted civilization sandbox: founding families on a frontier grow into lineages, Houses, and settlements, with culture and economics building on each other. Identity and status live in `project.md`.

**Read `AGENTS.md` first.** It holds the binding working rules: branch from `develop`, never work on or merge to `main` without review, high-risk files, and validation. This file adds commands and pointers, not a second rule set. Current status, open owner decisions, and gotchas: `docs/HANDOFF.md`.

## Design Sources

Design decisions are owner-confirmed and authoritative. Check them before changing gameplay:

- `docs/GAME_VISION.md` - objectives, pace, experience; wins over any other doc on conflict
- `docs/FIRST_STAGE_LOOP.md` - the owner-approved plan for a town's first stage (2026-10-27): the principle, planning that pays off, geography, the way to trade, six milestones, and the terms for working with less owner input
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

# Map luck: 48 towns on real generated maps and sites (filter for [MAP]); add "-- --world-seed=N" to play a generated planet
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/map_luck_check.gd

# Terrain costs, woodcutters clearing marked woods, and yearly forest expansion (filter for [WOOD])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_woodland_validation.gd

# Town building: construction, travel, and families building homes on plots, on 20 real town maps
# (write to a file, then filter for [BUILD]; piping Godot's household log stalls it on Windows)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/town_building_check.gd > building.log

# Multi-year settlement run, yearly report (filter output for [SIM])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/settlement_growth_run.gd

# Household simulation benchmark (filter output for [BENCH]; takes several minutes)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd

# Saved games: a town saved, loaded, and played on stays identical to the original; menus; the save store
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/save_game_validation.gd

# Start and in-game menu screenshots (needs a window; uses its own save folder)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/menu_capture.gd -- <output_dir>

# World map: data checks, and the hand-off into the regional/founding flow
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_flow_validation.gd

# Generated planets: design rules on seeds 1-6 (filter for [GEN]; pass other seeds after "--" for a sweep)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_generator_validation.gd

# World map screenshots for visual review (needs a window, so no --headless); add "seed=N" for a generated planet
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/world_map_capture.gd -- <output_dir>

# Continuous regional map: seamless chunks (also across the date line), determinism, matches the world, view coordinates ([PERF] lines)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/regional_terrain_validation.gd

# Regional map: unchanged original maps (fingerprints), bounded-mode decoration, clicking the landscape founds a town
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/region_map_validation.gd

# Regional map screenshots: showcases near and far, border, date line, [PERF] render and panning times; and the real
# atlas zoom-in / found / cross a border / zoom-out flow (both need a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_map_capture.gd -- <output_dir>
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_flow_capture.gd -- <output_dir>

# Town map: generator (determinism, follows the region, floors) and the view in the real flow (fit, coordinates, click/drag/wheel)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_map_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_map_view_validation.gd

# What town maps hold over 160 real sites, and generation time (filter for [TOWN]); the survey's thresholds come from it
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/town_map_probe.gd

# Town map screenshots: showcase sites, a grown town, every building type, the real game ([PERF] lines; needs a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/town_map_capture.gd -- <output_dir>
```

`scenes/region_map_demo.tscn` opens the continuous regional map on the showcase regions (keys 1-6, G for a grown town).

`tests/expanded_goods_production_validation.gd` extends `RefCounted`, so it cannot be run with `--script` directly; load it from a small `SceneTree` wrapper and call `run_all()`.

## Architecture

- `scripts/app.gd` (`scenes/app.tscn`, the project's main scene) - start menu, in-game menu, saving and loading; it runs `scenes/main.tscn` as the game. Tests create `main.gd` directly. Saves: `scripts/persistence/` (`GameState` decides what is saved; domain fields are saved automatically, but new object-valued fields, caches, and new `main.gd` state need a line there). Design: `docs/SAVED_GAMES.md`.
- `scripts/main.gd` - large central scene script: map input, drawing, UI, day ticking, trade. High-risk; avoid adding new simulation logic here. A click that switches views must call `get_viewport().set_input_as_handled()`, or the newly shown view receives the same click.
- `scripts/domain/` - simulation model: `city.gd` (resources, households, buildings, growth, lifecycle orchestration), `household.gd` (family structure, lifecycle, labor), `building.gd`.
- `scripts/simulation/` - `calendar.gd` and `simulation_clock.gd` (1 day = 1 real second at 1x).
- `scripts/world/` - regional and local map generation, founding-site helpers, and the world map's data (`world_map_data.gd`), generator (`world_generator.gd`, `world_name_generator.gd`), authored planet (`fixed_world_definition.gd`), and builder (`world_field_builder.gd`). The game plays on a planet generated from a new seed each run (`-- --world-seed=N` on the command line replays one); tests that look places up by name set `main.use_authored_world`. Generated worlds must stay deterministic per seed.
- `scripts/visuals/world_map/` and `shaders/world_terrain.gdshader` - the world atlas renderer; the game opens on it (`VIEW_WORLD` in `main.gd`). Design, decisions, and remaining integration work: `docs/WORLD_MAP.md`.
- `scripts/world/regional_terrain.gd` (+ `regional_chunk_generator.gd`), `scripts/visuals/region_map/`, and `shaders/region_terrain.gdshader` - the regional map: the whole planet at true scale (1 tile = 1.2 world units), generated in 60x60 chunks on worker threads; every tile must stay a pure function of its global position, or chunks stop joining. `main.gd` runs its rules on a 160x100 neighbourhood (`extract_window`), and `RegionMapView` streams the landscape under `main.gd`'s panels. The original `region_map_generator.gd` path must stay byte-identical (`tests/region_map_validation.gd` checks fingerprints). Decoration must never show what the tile data does not hold. Call `RegionalTerrain.wait_for_tasks()` before quitting a script that streamed chunks, or Godot hangs on exit. Details: `docs/REGIONAL_MAP.md`.
- `scripts/world/local_city_map_generator.gd`, `scripts/visuals/town_map/`, and `shaders/town_terrain.gdshader` - the town map: the regional land around the site magnified 4x (64x44 town tiles = 16x11 regional tiles), drawn in the regional map's style under a pan and zoom camera on its own canvas layer under `main.gd`'s panels. `main.gd` keeps the rules and routes town-map clicks through `TownMapView` (`map_clicked`); never draw the town in `main.gd`'s `_draw`. Town maps must stay deterministic per site (no game RNG). Painters shared with the regional map: `scripts/visuals/landscape_painter.gd`, `building_painter.gd`. Details: `docs/TOWN_MAP.md`.
- `scripts/ui/`, `scripts/visuals/` - panels, helpers, drawing.
- Daily `City.tick()`, monthly `advance_household_lifecycle_month()`, and seasonal birth rolls are driven by calendar signals in `main.gd`.
- Performance limits and their causes are measured in `docs/HOUSEHOLD_SIM_BENCHMARK.md`.
- Every economy number (starting stock, outputs, upkeep, construction costs and work, travel) lives in `scripts/domain/economy_balance.gd`.
- Building goes through one pipeline for the player and for families: `TownConstruction` (`city.construction`: requests, queue, builders, completion), `TownLogistics` (`city.logistics`: stores, routes on the town map through tiles and along the lines between them, the share of a workplace's day lost to travel, trails and paths worn where families walk, and trampled and fenced fields), and `TownWoodland` (`city.woodland`: woods marked for clearing, woodcutters felling them (and the nearest trees, slowly, when nothing is marked), and woods spreading through each growing season onto open land nothing holds), `TownFarmland` (`city.farmland`: land marked to till, tilled into farmland by the fields' families), `TownErrands` (`city.errands`: families' trips from home to the store, water, woods, and kin, wearing paths), and `FamilyDevelopment` (families building homes on residential plots, weekly). Nothing is placed finished in play: `City.add_building` is what a finished project calls. Design and judgment calls: `docs/TOWN_BUILDING_MODEL.md`.
- `TownLand` (`city.land`) is what the land in reach gives and threatens: fishers' and hunters' catch, the seasons' yield on fields, high water, wolves. Design and the milestone plan for the first stage: `docs/FIRST_STAGE_LOOP.md`.
