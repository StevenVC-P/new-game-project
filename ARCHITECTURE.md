# Architecture

This is a starting inventory for safe agent-assisted development. It describes what is present now and should be updated as systems are added or reorganized.

## Project Shape

- `project.godot`: Godot project configuration.
- `main.tscn`: Main scene configured by `project.godot`.
- `main.gd`: Main `Node2D` script. It owns the main runtime loop, drawing, input handling, UI coordination, map display, and simulation orchestration.
- `docs/`: Design and workflow documentation.
- `scripts/`: Local validation helpers.
- `tasks/`: Future task specifications for bounded agent work.

## Godot Configuration

- Config version: `5`
- Project name: `New Game Project`
- Main scene: `res://main.tscn`
- Feature tag: `4.6`
- Rendering: Forward Plus with Windows rendering device driver set to `d3d12`
- Physics: Jolt Physics
- Autoloads: none currently listed in `project.godot`

## Major Scenes

- `main.tscn`: Entry scene. It attaches `main.gd` to a `Node2D` root.

## Major Scripts

- `main.gd`: Top-level scene behavior, rendering, input, simulation update, and UI coordination.
- `city.gd`: City simulation model and settlement-level state.
- `household.gd`: Household simulation model.
- `building.gd`: Building data/model.
- `building_placement.gd`: Building placement logic.
- `building_visuals.gd`: Building rendering helpers.
- `city_building_overlay.gd`: Overlay logic for city/building display.
- `calendar.gd`: Calendar model with day, month, season, and year signals.
- `simulation_clock.gd`: Simulation timing helper.
- `region_map_generator.gd`: Regional map generation.
- `local_city_map_generator.gd`: Local city map generation.
- `settlement_site_profile.gd`: Settlement/site profile data.
- `terrain_visuals.gd`: Terrain rendering helpers.
- `map_element_visuals.gd`: Map element rendering helpers.
- `visual_style.gd`: Shared visual style values/helpers.
- `trade_menu.gd`: Trade menu UI/model helper.
- `trade_route.gd`: Trade route data/model.

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
- `main.gd` is large and central; prefer extracting new behavior into additive helper scripts instead of expanding it when practical.
- Do not rename scenes, nodes, scripts, or folders without an explicit task.
