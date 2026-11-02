# Architecture

This is a starting inventory for safe agent-assisted development. It describes what is present now and should be updated as systems are added or reorganized.

## Project Shape

- `project.godot`: Godot project configuration.
- `scenes/main.tscn`: Main scene configured by `project.godot`.
- `scripts/main.gd`: Main `Node2D` script. It owns the main runtime loop, drawing, input handling, UI coordination, map display, and simulation orchestration.
- `docs/`: Design and workflow documentation.
- `scripts/`: Game scripts plus local validation/agent runner helpers.
- `tasks/`: Future task specifications for bounded agent work.

## Godot Configuration

- Config version: `5`
- Project name: `New Game Project`
- Main scene: `res://scenes/main.tscn`
- Feature tag: `4.6`
- Rendering: Forward Plus with Windows rendering device driver set to `d3d12`
- Physics: Jolt Physics
- Autoloads: none currently listed in `project.godot`

## Major Scenes

- `scenes/main.tscn`: Entry scene. It attaches `scripts/main.gd` to a `Node2D` root.

## Major Scripts

- `scripts/main.gd`: Top-level scene behavior, rendering, input, simulation update, and UI coordination.
- `scripts/domain/city.gd`: City simulation model and settlement-level state.
- `scripts/domain/household.gd`: Household simulation model.
- `scripts/domain/building.gd`: Building data/model.
- `scripts/ui/building_placement.gd`: Building placement logic.
- `scripts/visuals/building_visuals.gd`: Building rendering helpers.
- `scripts/ui/city_building_overlay.gd`: Overlay logic for city/building display.
- `scripts/simulation/calendar.gd`: Calendar model with day, month, season, and year signals.
- `scripts/simulation/simulation_clock.gd`: Simulation timing helper.
- `scripts/world/region_map_generator.gd`: Regional map generation.
- `scripts/world/local_city_map_generator.gd`: Local city map generation.
- `scripts/domain/settlement_site_profile.gd`: Settlement/site profile data.
- `scripts/visuals/terrain_visuals.gd`: Terrain rendering helpers.
- `scripts/visuals/map_element_visuals.gd`: Map element rendering helpers.
- `scripts/visuals/visual_style.gd`: Shared visual style values/helpers.
- `scripts/ui/trade_menu.gd`: Trade menu UI/model helper.
- `scripts/domain/trade_route.gd`: Trade route data/model.
- `scripts/world/world_map_data.gd`, `fixed_world_definition.gd`, `world_field_builder.gd`: World map data model, the hand-authored planet, and the builder that turns one into the other.
- `scripts/visuals/world_map/`: World atlas view (camera, input, selection) and its drawing layers; `shaders/world_terrain.gdshader` draws terrain and borders.
- `scripts/ui/world_map_panel.gd`: World atlas HUD.
- `scripts/world/regional_terrain.gd`, `regional_chunk_generator.gd`, `regional_chunk.gd`: The whole planet at regional scale, generated in chunks from the world on worker threads.
- `scripts/visuals/region_map/`: Regional map view (camera, chunk streaming, layers) drawing the planet as a miniature landscape; `shaders/region_terrain.gdshader` draws the ground. `shaders/natural_palette.gdshaderinc` holds the colors both map shaders share.

## World Map

The game opens on the world atlas (`VIEW_WORLD` in `scripts/main.gd`), which runs on its own `CanvasLayer`. Zooming in past its closest view, or entering a region, opens the regional map at the same place and scale. Details: `docs/WORLD_MAP.md`.

## Regional Map

One continuous, true-scale map of the planet, streamed in chunks by `RegionMapView` on a `CanvasLayer` below `main.gd`'s panels. `main.gd` keeps the rules and runs them on a 160x100-tile neighbourhood of it. Details: `docs/REGIONAL_MAP.md`.

## Known Systems

- Regional map generation and display.
- Local city map generation and display.
- City, household, building, and trade simulation data.
- Calendar and simulation clock progression.
- Visual helper classes for terrain, buildings, map elements, and style.
- Trade route and trade menu interactions.

## Agent Notes

- There are no autoloads at the time of this inventory.
- Most supporting scripts are `RefCounted` classes with `class_name`.
- `scripts/main.gd` is large and central; prefer extracting new behavior into additive helper scripts instead of expanding it when practical.
- Do not rename scenes, nodes, scripts, or folders without an explicit task.
