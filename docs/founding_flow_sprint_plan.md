# Founding Flow Sprint Plan

This sprint plan prepares the proper game start / founding flow implementation. It is documentation-only. The current start creates two full simulation cities; the target v0 start is one mostly inert neutral town plus one player-founded town.

## Sprint Purpose

The current game begins on the regional map with two generated cities. Both are full `City` simulations, both can be selected and controlled, and both receive starter households and resources. That is useful for early city/trade testing, but it no longer matches the desired first-playable start.

The founding-flow sprint should make the start feel like founding the player's first town in a wider region:

- the region already contains one visible neutral town
- the player chooses a valid empty founding location
- the player creates the first player-controlled town there
- the founded town receives founding families and starting stockpiles
- the normal city-building loop begins from that player town

## Current Behavior Summary

Current implemented behavior:

- `RegionMapGenerator` creates two generated cities, `City A` and `City B`.
- Both generated cities are full `City` simulations.
- Both cities receive starter resources and 3 starter households.
- There is no city ownership, city role, player-city flag, or neutral-town model.
- Both cities tick daily through `run_simulation_day()`.
- Both cities can be opened and controlled from the regional map.
- Both cities receive local maps.
- Trade can be created between the two full cities.
- Cities start with no buildings; starter households begin in temporary shelter.

This behavior should not remain the normal player start once founding flow exists. It may remain only as a debug/dev path if still useful.

## Target V0 Behavior

Target founding flow:

1. Game opens on the regional map.
2. One neutral pre-existing town marker is visible.
3. The player selects a valid empty founding tile.
4. The player confirms founding.
5. A player-controlled city is created at the chosen tile.
6. The player city starts with 4 founding families.
7. The player enters the founded city.
8. Normal city-building begins.
9. The neutral town remains visible but mostly inert.

The player-founded city should be the only full simulation city in v0.

## Product Decisions For V0

Locked v0 decisions:

- Founding families: `4`.
- Founding households: fixed seeded setup; no family selection UI.
- Neutral town: visible and mostly inert.
- Neutral town simulation: no full household economy, lifecycle, production, need pressure, or soft-need consumption in v0.
- Player town: only full simulation city in normal play.
- Trade/diplomacy with neutral town: not in v0.
- Terrain bonuses: display-only at most; no production modifiers.
- Town naming: simple default or generated placeholder unless trivial.
- Current two-city full simulation start: keep only as debug/dev mode if useful.
- Money, prices, starting wealth, credit, and debt: not in v0.

Reason for 4 founding families:

- Current full cities start with 3 households.
- Founding flow removes the second controllable city from the normal start.
- One extra founding family gives a little more assignment flexibility while keeping food, shelter, and household responsibility pressure meaningful.

## Proposed Branch Sequence

Recommended implementation sequence:

1. `feature/city-role-model-v0`
2. `feature/regional-map-neutral-town-v0`
3. `feature/player-town-founding-location-v0`
4. `feature/founding-household-seed-v0`
5. `feature/founding-flow-ui-v0`
6. `feature/founding-flow-manual-retest-checklist-v0`

Keep each branch small enough to validate and manually inspect. `scripts/main.gd` and map generation are high-risk areas, so avoid bundling broad UI, simulation, and generator changes into one branch.

## Branch Definitions

### `feature/city-role-model-v0`

Goal:

- Add a minimal city role / ownership distinction.

Possible roles:

- `player`
- `neutral`
- `debug`

Scope:

- Add only the data/model helpers needed to distinguish player and neutral city records.
- Ensure only player cities are controllable in normal play.
- Ensure neutral town records are not accidentally treated as full player cities.
- Keep role checks simple and readable.

Non-goals:

- no diplomacy
- no trade behavior changes beyond preventing accidental neutral-town routing if needed
- no neutral economy
- no city AI
- no ownership/prosperity system

### `feature/regional-map-neutral-town-v0`

Goal:

- Replace the normal two-full-city start with one neutral town marker/data path.

Scope:

- Generate or place one neutral pre-existing town.
- Make it visible on the regional map.
- Keep the neutral town minimal.
- Do not run full city simulation for the neutral town unless the current architecture absolutely requires a temporary compatibility object.

Implementation caution:

- If a neutral town needs a lightweight data type instead of a full `City`, prefer that if it avoids simulation coupling.
- If a full `City` object is temporarily necessary, role checks must prevent it from ticking, being controlled, or creating full player-city pressure.

### `feature/player-town-founding-location-v0`

Goal:

- Let the player select a valid empty regional tile as the future player town location.

Validity rules:

- not river
- not mountain
- not forest
- not a resource tile
- not too close to the neutral town

Scope:

- Reuse existing city-placement distance logic if possible.
- Reuse existing region tile data where possible.
- Display tile/site information read-only.
- Do not add terrain bonuses.

Non-goals:

- no resource bonus calculation
- no family selection
- no caravan simulation
- no procedural town ranking UI beyond simple validity feedback

### `feature/founding-household-seed-v0`

Goal:

- Create the player city at founding time and seed it with founding households and starting resources.

Scope:

- Seed 4 founding households.
- Reuse existing starter household/resource logic where safe.
- Adjust constants or constructor paths cleanly so the founded city can differ from compatibility/debug city starts.
- Keep households fixed and deterministic.

Non-goals:

- no family selection UI
- no household inventory
- no money or starting wealth
- no new goods or industries
- no starting homes unless explicitly scoped after owner review

### `feature/founding-flow-ui-v0`

Goal:

- Add the minimal regional UI needed to guide founding.

Required UI states/text:

- select founding site
- found town
- confirm / cancel
- founded town ready

Scope:

- Make the neutral town visibly non-player or neutral.
- Show clear founding validity feedback.
- Transition into city view after founding.
- Keep the UI functional and compact.

Non-goals:

- no full UI overhaul
- no animated camera sequence
- no naming screen unless trivial
- no tutorial system

### `feature/founding-flow-manual-retest-checklist-v0`

Goal:

- Add a repeatable owner checklist for the founding-flow sprint.

Checklist should cover:

- regional map start
- neutral town visibility
- neutral town non-control / non-simulation
- founding tile validity
- founding confirm / cancel
- player city creation
- 4 founding households
- starting resources
- normal city building after founding
- Need Pressure after founding
- selected-house UI after founding
- no regression in trade menu behavior beyond intended neutral-town restrictions

## Technical Risk Areas

Likely risky files:

- `scripts/main.gd`
- `scripts/world/region_map_generator.gd`
- `scripts/world/local_city_map_generator.gd`
- `scripts/domain/city.gd`
- `scripts/ui/trade_menu.gd`
- region inspector / city hover display code in `scripts/main.gd`
- tests or validation scripts that assume two full cities

Risk notes:

- `scripts/main.gd` owns region input, city selection, city view transitions, drawing, placement, simulation day ticking, and trade route orchestration.
- `RegionMapGenerator.place_cities()` currently creates full `City` objects directly.
- `City._init()` immediately seeds resources and households, so a neutral town should avoid accidentally becoming a full simulation city.
- `run_simulation_day()` currently ticks every city in `cities`.
- Trade currently assumes selectable source and destination city indices.

## Testing Strategy

Recommended focused tests / validations:

- city role helper behavior
- neutral town is not player-controllable
- only player town gets full simulation where intended
- neutral town does not tick full household economy
- founding tile validity
- founded city has 4 households
- founded city has expected starter resources
- existing city view opens after founding
- building placement still works after founding
- existing pressure UI still works after founding
- existing selected-house UI still works after founding

Validation expectations:

- Run Godot project validation on every GDScript branch.
- Run affected focused tests on each branch.
- Add focused tests for new role/founding helpers when practical.
- Run a full owner manual retest at sprint end.

## Explicit Non-Goals

Do not include in this sprint:

- trade or diplomacy with the neutral town
- enemy or war behavior
- full neutral-town economy
- procedural economy for other towns
- family selection screen
- starting caravan simulation
- money, prices, credit, debt, or currency
- new industries
- clothing or textile production
- household inventory
- terrain production bonuses
- broad map-generation rewrite
- save/load or campaign persistence
- multi-town player management
- final UI polish or tutorialization

## Definition Of Done

The founding-flow sprint is done when:

- normal game start no longer presents two fully controllable cities
- one neutral town appears on the regional map
- player can select a valid empty founding location
- player can confirm founding
- one player town is created
- founded town has 4 founding households
- founded town has expected starting resources
- player can enter the founded town and build normally
- neutral town remains visible but does not interfere
- neutral town is not accidentally controllable as a full player city
- existing demand / soft-need UI still works after founding
- validation passes
- owner manual retest passes

## Validation

For this planning branch:

- Run `git diff --check`.
- No Godot validation is required because this branch is documentation-only.

For implementation branches:

- Run Godot project validation.
- Run affected focused tests.
- Add new tests where helper behavior becomes testable.
