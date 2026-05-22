# Roadmap

This roadmap is intentionally lightweight. Replace placeholders with scoped tasks as the project direction becomes clearer.

## Core Loop

- First playable loop: grow and stabilize a small settlement by placing/expanding housing, creating production responsibilities, assigning households, managing food/housing/resource pressure, and using trade or expansion to relieve shortages.
- First pressure sources: food shortage, housing shortage, maintenance/resource shortage, and not enough households to cover responsibilities.
- The player should feel that the settlement is strained by household stability and responsibility coverage, not by anonymous worker points.

## Player

- Prototype player role: directly assign households to responsibilities for legibility.
- Later player role: set priorities and incentives while households express preferences, fit, and partial autonomy.
- Visible walkers should represent household activity, not individually simulated economic citizens.

## World/Levels

- Near-term focus: one settlement should clearly show households -> assignments -> production/consumption -> growth/shortage.
- Regions should matter after the city/household loop is stable.
- TODO: Identify needed demo/test scenes for world systems.

## UI

- TODO: Inventory current UI flows.
- UI should make households, city population, food pressure, housing pressure, responsibility coverage, and basic production legible.

## Enemies/NPCs

- TODO: Decide whether NPCs, agents, factions, or adversaries are in scope.

## Inventory/Items

- First milestone resources: food, wood, stone or building material, housing capacity, maintenance/upkeep, and possibly wealth/goods later.
- Do not overbuild the economy before the household assignment loop is clear.

## Save/Load

- TODO: Choose save format and persistence scope.
- TODO: Add validation for save/load compatibility when implemented.

## Audio/Visual Polish

- TODO: Track visual consistency, readability, animation, and audio needs.

## Technical Debt

- `main.gd` should not be modularized casually. Delay broad modularization until the core loop is clarified.
- TODO: Track validation, test scenes, and tooling gaps.
