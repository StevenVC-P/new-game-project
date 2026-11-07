# Map And Settlement Scale Audit

This document audits the current map and settlement scale model before adding larger-region, district, or metropolis systems. It is documentation-only. It records what the code can support today, what the long-term scale target implies, and how to keep population growth meaningful without pretending a million-person city can be simulated household by household.

## Purpose

The current playable start now begins on the regional map, shows one mostly inert neutral town, lets the player choose a valid founding site, and creates a player-controlled `Player Town` with 4 founding households.

That is a good beginning for a household-rooted settlement game, but it raises a larger design question: how does the game scale from named founding families to villages, towns, cities, and eventually a metropolis that depends on a much larger civilization network?

This audit should prevent two traps:

- treating the local city map as if it can visually and mechanically contain every future house, workshop, and person forever
- treating large population as just a bigger number while losing the household-first identity that makes the early game matter

## Current Implemented Scale

### Existing Map Layers

The code currently has two active map layers:

- `regional map`: created and drawn by `scripts/main.gd` using `RegionMapGenerator`.
- `local city map`: created by `LocalCityMapGenerator` and displayed when a controllable city is selected.

Current dimensions:

- Regional map: `80 x 50` tiles, with `TILE_SIZE = 12`.
- Local city map: `64 x 44` tiles, with `CITY_TILE_SIZE = 12`.

The regional map currently behaves more like a local valley, county, or nearby settlement region than a kingdom or civilization map. It contains terrain, a river, forests, fertile land, hills/mountains, stone/iron deposits, roads, town markers, and founding-site validation.

The local city map currently represents the playable settlement surface where houses, farms, woodcutters, toolmakers, expanded-goods buildings, roads/clearings/trees/rough terrain/water edges, walkers, overlays, and the city sidebar are drawn.

### Regional Map Generation

`scripts/world/region_map_generator.gd` currently:

- creates base grass tiles with `type`, `has_forest`, `is_fertile`, `resource`, `has_road`, and `has_ford`
- generates one river band
- generates fertile land near the river
- generates foothills and mountain pressure toward an edge
- generates forest clusters
- places stone and iron deposits
- places one neutral town through `place_cities()`
- can generate roads between cities, although with one neutral town there is no city-to-city road route yet

The neutral town is currently created as a `City` object named `Neutral Town` with `City.ROLE_NEUTRAL`.

### Founding Site Selection

`scripts/world/founding_site_helper.gd` and `scripts/main.gd` implement v0 founding-site validation.

Current valid founding tile rules:

- not outside the region
- not a river tile
- not a mountain tile
- not a forest tile
- not a resource deposit tile
- not occupied by an existing town/city marker
- not too close to the neutral town or another city, using the existing minimum city distance

The player can select a pending founding tile, clear it, and then use `Found Town` to create the player city.

### Local City Map Generation

`scripts/world/local_city_map_generator.gd` creates a local map for a `City` using the city's regional tile and `SettlementSiteProfile`.

It:

- samples nearby regional context
- chooses a settlement morphology such as `linear_riverside_build_area`, `fragmented_woodland_clearings`, `constrained_plateau_pockets`, `broad_open_site`, or `mixed_borderland_clearings`
- adds water features, fertile banks, clearings, rough patches, stone clusters, trees, and minimum buildable pockets
- returns a `64 x 44` tile local map

This is suitable for a hamlet, village, or modest town prototype. It should not be treated as a literal map of a future metropolis.

### Site Profiles

`scripts/domain/settlement_site_profile.gd` records site metadata:

- river influence
- fertility
- forest density
- roughness and mountain pressure
- stone/iron access
- trade position
- openness
- nearest feature distances
- feature directions
- tags such as `river_settlement`, `fertile_valley`, `forest_settlement`, `mining_region`, `crossroads`, `open_plains`, and `isolated`

This is metadata only today, except that it informs local-map morphology and visible site text. It is a good foundation for future regional identity, local resource access, migration attraction, culture, and industry tendencies.

### City And Household Simulation

`City` currently remains the full simulation object:

- role: `player`, `neutral`, or `debug`
- regional tile
- local map
- buildings
- households
- resources
- resource history
- soft need results
- site profile

`Player Town` is a full `City.ROLE_PLAYER` city. It ticks simulation, opens in city view, receives starting resources, receives a local map, and starts with 4 founding households.

`Neutral Town` is still a `City` object, but it is role-gated:

- visible on the regional map
- not controllable
- not ticking full simulation
- rejected by the trade menu

This is a compatibility object, not a true lightweight neutral-town marker yet.

Population is tracked directly through `Household.total_population`. `City.get_total_population()` sums active household populations. Food, shelter, clothing demand, birth pressure, household goods pressure, and many UI summaries derive from the household list.

### Current Realistic Gameplay Scale

The current gameplay realistically supports:

- founding families
- a hamlet
- a small village
- possibly a small town, depending on UI and local-map density

It does not yet support:

- hundreds of individually meaningful households without UI overload
- many fully ticking settlements
- district-level aggregation
- regional hinterland supply
- town/city-scale markets or distribution
- metropolis-scale population

The current local map and household model can probably carry early village growth. They are not enough for city or metropolis scale without abstraction.

## Current Scale Assumptions

Starting settlement:

- `Player Town` starts with 4 households.
- Each starter household has population 4.
- Starting population is therefore 16. (Since 2026-10-19 seed population is derived from family structure, so founding starts at 14: the newlywed seed is a couple of 2.)
- Starter households begin in temporary shelter.
- Houses have `HOUSE_CAPACITY = 4`.

Earlier default `City.new(...)` compatibility behavior still supports 3 starter households unless an explicit starter household count is passed.

Current map count:

- Normal regional start has one neutral town.
- The player can found one player town.
- Second player-city founding is blocked.

Trade:

- Trade is city-to-city resource transfer.
- Trade currently offers `food`, `wood`, and `tools`.
- Neutral-town trade is blocked.
- There is no many-to-one hinterland supply, market routing, or household trade.

Simulation:

- Player cities tick.
- Debug cities tick.
- Neutral cities do not tick.
- There is no model for many abstract settlements producing supply without full local maps.

## Long-Term Scale Target

The intended scale ladder should be:

1. Founding families
2. Hamlet
3. Village
4. Town
5. City
6. Metropolis / civilization hub

A 1,000,000 population city should be an endgame abstraction target, not a direct household-by-household simulation target.

That target should mean:

- a capital or civilization hub
- dense district-level population
- a vast hinterland
- regional food, fuel, construction material, and labor flows
- administrative and political power
- vulnerability from complexity and dependence

It should not mean:

- one giant local map with every house drawn
- one million individual people simulated
- 250,000 households ticking with full lifecycle and inventory logic
- a self-contained settlement that locally produces everything it needs

## Feasibility Analysis

### Feasible With Current Architecture

The current architecture can support:

- one full player settlement
- named founding families
- household-based labor, demand, shelter, and lifecycle
- small numbers of houses and production buildings
- early pressure loops around food, shelter, labor, tools, maintenance, household goods, and clothing
- one inert neutral town as world context
- simple city-to-city trade later, once a valid second controllable/simulated endpoint exists
- local-map site identity through terrain/profile metadata

This is enough for the next growth band: `Founding Hamlet -> Stable Village`.

### Infeasible If Every Household Remains Individually Simulated

At about 1,000 people, the household list might still be technically possible, but UI and meaning become harder. If one household averages 4 people, 1,000 people means about 250 households. That is already too many for direct assignment and per-household inspection as the main interface.

At 10,000 people, direct household simulation becomes a burden. About 2,500 households would need lifecycle, demand, inventory, assignment, housing, display, and event handling. The player cannot care about all of them individually.

At 100,000+ people, direct household simulation is not a viable design center. It would either be performance-heavy or meaningless because most households would be invisible data.

At 1,000,000 people, direct household simulation is the wrong model. A million-person metropolis must be district, class, profession, institution, and region-level simulation with a few named households or lineages preserved as anchors.

### Infeasible If Every Settlement Is A Full City Simulation

The current `City` object is heavy because it owns households, buildings, resources, local maps, pressure systems, lifecycle paths, and production.

That is appropriate for the player town. It is too much for:

- every farming village
- every mining camp
- every market town
- every port
- every hinterland node
- every subject city

Future regions need lightweight settlement records or tiered simulation modes:

- marker-only neutral settlement
- abstract producer settlement
- trade node
- playable/full simulation city
- district/capital aggregate

### Infeasible If Local Maps Must Contain Every Building

The current local map is a playable settlement map, not a literal city-at-all-scales map.

It can plausibly represent:

- hamlet
- village
- compact town core

It cannot represent:

- a sprawling city with thousands of houses
- multiple specialized districts
- a metropolis with suburbs, ports, markets, temples, government districts, slums, warehouses, and hinterland roads

Before city scale, the local map should probably become the urban core or district view, not the entire settlement.

### Abstraction Needed By Population Bands

Before 1,000 people:

- household overview tools
- grouped demand summaries
- automatic or priority-based assignment support
- settlement storage/logistics visibility
- housing groups or neighborhood labels

Before 10,000 people:

- neighborhoods or grouped households
- district-level demand and labor
- aggregated professions/trades
- storage zones and logistics routes
- external supply dependence
- market/admin abstractions

Before 100,000+ people:

- district simulation
- hinterland imports
- class/profession groups
- civic institutions
- transport capacity
- regional administration
- public order and legitimacy
- representative lineages rather than all households

Postponable until much later:

- realm map
- metropolis simulation
- armies and military supply
- politics/diplomacy
- money/credit/debt
- full market routing
- per-district visual maps
- immigration waves and class mobility at scale

## Why Metropolises Need Hinterlands

A metropolis should not be self-sustaining.

Large cities require:

- imported food
- fuel
- construction materials
- raw resources
- labor migration
- roads
- ports
- markets
- storage
- administrative control
- political authority
- tax or tribute systems
- specialized towns and villages

The design should make smaller places matter because they feed, supply, staff, defend, and specialize around larger hubs.

The player should eventually feel that a great city is powerful because it controls and coordinates a larger civilization network, not because its local tiles magically provide everything. Growth should increase dependency as well as prestige.

This also gives small settlements a long-term purpose:

- farming villages feed towns
- logging camps and charcoal settlements supply fuel
- mining settlements feed metal industries
- river towns and ports move goods
- market towns aggregate surplus
- religious/civic centers create legitimacy and identity
- frontier outposts extend control

## Player Investment Across Scale

The key problem is keeping population meaningful at every scale.

### Founding Families / Hamlet

The player should care because:

- households are named and few
- every labor assignment matters
- shortages are personal and visible
- shelter is fragile
- food is immediate
- family lineage and work identity are inspectable

At this scale, direct household simulation is the right tool. The player can remember families and see why a missing farm assignment or unsheltered household hurts.

### Village

The player should care because:

- households have continuity
- births, aging, succession, and new family formation create pressure
- housing shortage has visible family consequences
- family trades and preferences start to shape settlement identity
- early specialization emerges
- the village starts to have local memory

The player should still know individual families, but the UI should also summarize patterns: food security, housing pressure, available households, household goods, clothing, and succession.

### Town

The player should care because:

- neighborhoods or grouped households become meaningful
- production chains require storage and logistics
- notable families or guilds carry continuity
- civic buildings become important
- migration changes the social mix
- shortages are no longer just one missing building; they are supply chain problems

At this scale, the game should begin moving from direct household-by-household control to grouped responsibilities, priorities, and institutions.

### City

The player should care because:

- districts have identities
- professions/classes matter
- infrastructure matters
- markets/trade and administration become core systems
- public order and service access become visible
- representative households or notable lineages preserve continuity from the early game

Population should become a structured civic organism, not a single number.

### Metropolis

The player should care because:

- the city is a civilization hub
- district-level population and infrastructure define its shape
- hinterland supply is mandatory
- political/economic power grows with dependence
- prestige comes with vulnerability
- armies, civic supply, ports, roads, markets, and administration matter

At this scale, most people are abstracted. The player should still see named houses, guilds, districts, and historic institutions that descend from earlier household stories.

### What Remains Personal

The founding-family stage should remain visible through:

- notable lineages
- named family houses
- inherited trades
- old-town landmarks
- original farm/market/workshop sites
- civic records and milestones
- representative household stories

The player should not inspect every household forever. The player should recognize that early families became institutions, districts, guilds, patrons, or local myths.

### What Becomes Abstracted

As scale grows, these should become aggregate systems:

- ordinary households
- most individual jobs
- routine food consumption
- day-to-day market exchanges
- common housing demand
- district labor pools
- bulk imports and storage

The player should manage patterns and institutions while still seeing enough named continuity to feel the population is more than a number.

### Avoiding "Population Is Just A Number"

Population should create:

- demand
- labor capacity
- family continuity
- migration pressure
- housing pressure
- class/profession structure
- civic identity
- district stress
- political power
- regional dependency

Every scale should answer, "What does this population need, contribute, remember, and pressure?"

### Preserving Household-First Identity

Do not abruptly delete households from the design at higher scale. Instead:

- keep named households for early and notable families
- aggregate ordinary households into neighborhoods/districts
- let founding lineages influence guilds, offices, or district identities
- preserve household-derived demand as the conceptual root of aggregate demand
- make district summaries explain their household origins

## Continuity Mechanisms

Mechanics that can preserve connection across scale:

- founding family lineages become notable houses
- early family trades become guilds
- the original settlement core becomes `Old Town` or the civic center
- neighborhoods inherit names from founding families, early industries, sites, or events
- civic records preserve milestones such as first winter survived, first harvest surplus, first quarry, first market, first succession
- household stories become representative events at higher scale
- named elite/trade families coexist with aggregated population
- local goods and industries become city identity
- old roads and first farms remain visible or remembered
- early shortages and disasters become cultural memory

The game should not make the player care about 10,000 households. It should make the player care that the city contains districts, institutions, and histories rooted in the households they once protected.

## Possible Map Layer Model

A future map model could use three layers.

### Local Settlement Map

Purpose:

- houses
- workshops
- storage
- local roads
- farms at village scale
- immediate infrastructure
- selected district or urban core later

Current local city maps can serve this role for hamlets, villages, and early towns.

### Regional Map

Purpose:

- nearby villages
- farms
- forests
- mines
- roads
- rivers
- neutral towns
- trade routes
- local hinterland

The current regional map can likely become an early hinterland layer. It is better suited to a valley/county/local region than a kingdom.

### Realm / Civilization Map

Purpose:

- many regions
- capitals
- ports
- large-scale trade
- armies
- administration
- political boundaries
- metropolis supply networks

This layer probably needs to be separate later. It is too early to implement now.

### Open Layering Questions

Can the current regional map act as the hinterland layer?

- Yes, for early villages, town support, nearby farms, mines, roads, and neutral places.
- Probably not forever, because a metropolis needs a much larger supply network.

Should the local map represent the whole city forever?

- No. It should eventually become the old core, selected district, or local build view.

Will a realm/civilization layer be needed?

- Probably yes if the game truly reaches capitals, large ports, military supply, multi-region trade, and million-population hubs.

## Simulation Resolution By Scale

Recommended bands:

| Scale | Population Band | Suggested Simulation Resolution |
| --- | --- | --- |
| Founding hamlet | 4-10 households / 16-50 people | named households, direct family assignments |
| Village | 10-50 households / 50-250 people | household-driven with better overviews and priority tools |
| Large village / small town | 250-1,000 people | grouped households, neighborhoods, storage/logistics summaries |
| Town | 1,000-10,000 people | neighborhoods, professions, civic buildings, aggregated labor/demand |
| City | 10,000-100,000 people | districts, supply zones, markets, administration, representative lineages |
| Large city / metropolis | 100,000-1,000,000+ people | district/region-level simulation, hinterland dependency, political/economic power |

These thresholds are not final. They are design guardrails.

The important principle is that simulation resolution should drop as population rises:

- early: individual households matter directly
- middle: neighborhoods and professions emerge
- late: districts and regions carry most behavior

## Map Size And View Implications

The current regional map reads as a local region:

- one river valley
- nearby forests
- foothill/mountain edge
- stone and iron deposits
- one neutral town
- one founded player town

It does not yet read as a kingdom-scale map.

Possible future settlement count per current region:

- near-term: 1 player town plus 1 neutral town
- later: several abstract farms, hamlets, mines, logging camps, or market nodes
- much later: a handful of full or semi-full settlements, but not all ticking as full `City` objects

Local maps:

- should be active for the player city
- may be generated for important places
- should not be generated and simulated for every abstract hinterland node

Villages that feed a city could be:

- map markers with production summaries
- abstract producers attached to terrain/resource sites
- playable maps only when promoted or selected as a major settlement

At city scale, district maps are more plausible than one giant local map. The player may manage a city through:

- city overview
- district views
- regional supply view
- selected representative neighborhoods

The player should not have to pan across one enormous tile map to understand a metropolis.

## Current Architecture Risks

Key risks:

- `scripts/main.gd` is already a large central owner of map input, drawing, UI, simulation ticking, and trade orchestration.
- Every `City` as a full simulation object will not scale to many settlements.
- The neutral town is still a role-gated `City`, not a lightweight marker.
- `City._init()` still eagerly creates resources and households unless told otherwise by constructor path.
- Local maps may not scale visually or mechanically to city/metropolis size.
- Regional map may be too small or too local for kingdom-scale hinterland logic.
- Trade is currently direct city-to-city transfer, not many-to-one regional supply.
- Founding-site validation has no terrain/resource economic meaning yet.
- Households cannot remain individually simulated up to 1,000,000 population.
- UI needs scale-aware views before population grows much beyond village.
- Player investment may break if named households disappear abruptly.

These risks are manageable if the next work strengthens the early village loop before adding higher-scale maps.

## Near-Term Recommendation

Do not implement metropolis systems yet.

Do not implement a realm map yet.

Do not implement district simulation yet.

The next real gameplay target should be:

```text
Founding Hamlet -> Stable Village
```

That means making the first settlement growth band satisfying before introducing larger abstractions.

Near-term work should focus on:

- early village loop
- housing and food stability
- growth pressure
- household continuity
- early resource/industry access
- clothing/textile production if it supports soft needs cleanly
- household satisfaction records if they make family experience more visible
- eventually trade with a neutral or nearby town when there is a real reason to trade

Map scale changes should mostly wait. The current regional map can support founding, nearby site context, and early resource thinking. It does not need to become a full hinterland/realm map before the village loop is better.

## Proposed Next Sprint Options

### `settlement-growth-scale-model`

What it adds:

- A design plan for growth from founding hamlet to stable village and early town.

Why it matters:

- It defines what population growth should mean before new mechanics are added.

Feasible now:

- Yes. Planning-only and directly useful.

Too early:

- No.

### `early-village-gameplay-loop`

What it adds:

- First implementation pass for making the founded town grow into a stable village with clearer goals and pressure.

Why it matters:

- It turns founding flow into a playable loop.

Feasible now:

- Partly, but it needs a clear model first.

Too early:

- Slightly early without a growth-scale model.

### `clothing-textile-production-v0`

What it adds:

- Wool/fiber/textile/clothing production chain or a conservative first slice.

Why it matters:

- Clothing already exists as a consuming soft need, but no production chain exists.

Feasible now:

- Yes, if scoped tightly.

Too early:

- Not too early mechanically, but it may distract from the broader village loop if done first.

### `expanded-resource-access-v0`

What it adds:

- More meaningful access to local deposits, forests, fertility, or site-profile resources.

Why it matters:

- Founding-site choice needs economic meaning eventually.

Feasible now:

- Yes, but should be conservative.

Too early:

- It may be early if it requires a resource logistics overhaul.

### `regional-scale-hinterland-plan`

What it adds:

- A plan for farms, villages, mines, roads, neutral towns, and many-to-one supply networks.

Why it matters:

- It protects the metropolis design principle.

Feasible now:

- Yes as documentation.

Too early:

- Too early for implementation.

### `household-satisfaction-records-v0`

What it adds:

- Per-household satisfaction snapshots while keeping city stockpile consumption.

Why it matters:

- It preserves household investment as population grows.

Feasible now:

- Yes, because it avoids inventory and routing.

Too early:

- Not too early if kept read-only and diagnostic/player-facing.

### `map-scale-layering-plan`

What it adds:

- A formal plan for local, regional, and realm layers.

Why it matters:

- It helps avoid growing the current maps into the wrong shape.

Feasible now:

- Yes as documentation.

Too early:

- Useful later, but less urgent than settlement growth.

## Recommended Next Sprint

Recommended next sprint:

```text
docs/settlement-growth-scale-model
```

Purpose:

- define what `Founding Hamlet -> Stable Village -> Early Town` means
- identify which pressures should matter at each step
- decide how population growth should remain emotionally and mechanically meaningful
- choose the first implementation sprint after that

Likely implementation candidates after that model:

- `feature/early-village-gameplay-loop-v0`
- `feature/clothing-textile-production-v0`
- `feature/household-satisfaction-records-v0`
- `feature/expanded-resource-access-v0`

If the owner wants immediate mechanics instead of another planning branch, the safest implementation candidate is probably `feature/household-satisfaction-records-v0`, because it deepens household visibility without adding new production chains or map layers.

## Explicit Non-Goals For This Audit

This audit does not implement:

- realm map
- district system
- metropolis simulation
- new industries
- trade overhaul
- household aggregation
- new map generation
- UI overhaul
- population cap mechanics
- military or army supply
- money, credit, or debt
- politics or diplomacy

## Open Questions

- What is the desired population target for the first playable milestone?
- Should the local map represent the whole settlement through village scale, then become an urban core later?
- When should ordinary households become grouped into neighborhoods?
- What should trigger the first neighborhood or district abstraction?
- Should nearby farms/mines/logging camps be abstract regional producers or local-map buildings first?
- How should the neutral town become useful without requiring diplomacy or full economy?
- Should founding-site profile tags eventually affect migration, industry, fertility, or culture?
- What is the first mechanic that makes population above 100 feel different from population 16?
- Which named lineages should remain visible after household aggregation begins?
- How much of the late-game metropolis should be playable map versus dashboard/region simulation?

## Validation

For this audit branch:

- Run `git diff --check`.
- No Godot validation is required because this branch is documentation-only.
