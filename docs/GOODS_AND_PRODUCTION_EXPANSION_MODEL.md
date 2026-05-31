# Goods and Production Expansion Model

This document is a planning model for broadening the city's goods and production foundation before money, obligation, city credit, debt, or currency are implemented.

The current first-playable loop remains food, shelter, household labor, production buildings, tools, maintenance, pressure/action guidance, and household/city identity. Expanded goods should deepen that loop rather than replace it with abstract finance.

## Design Goal

The game is moving from a small generic resource model toward a richer city-specific goods model. The goal is not to add goods for decoration. Each good should make settlement life, household need, production, local identity, trade, or future economic backing more legible.

Goods should answer at least one of these questions:

- What household need does this satisfy?
- What building produces it?
- What raw input does it consume?
- What pressure does shortage create?
- What city or trade identity can this support?
- What future economy role could it support?

Money and city credit should wait until the game has enough meaningful goods, needs, household traits, and production relationships for obligations to emerge from real material pressure.

## Family-Driven Demand Architecture

Families are the core economic actors. The city should aggregate demand; it should not invent demand directly.

Demand should come from four sources:

- families, through food, shelter, home life, lifecycle stage, dependents, prosperity, and status
- homes, through shelter quality, maintenance, future storage, and future home-improvement needs
- workplaces, through production inputs, tools, maintenance, and upkeep goods
- civic buildings, through future upkeep and quality-of-life effects that improve the city without necessarily producing goods

The city pressure summary should eventually add these sources together and show the resulting pressure. This keeps pressure grounded in real settlement life rather than abstract city-wide meters.

### Families, Homes, And Shelter

A family can live in a home object, but it can also be temporarily sheltered or unsheltered. Shelter state changes the family's demand profile:

- Food demand remains active even when a family is unsheltered.
- Unsheltered families create strong shelter pressure.
- Unsheltered families should create little or no soft home-life demand because they do not have a stable home context for domestic goods.
- Unsheltered families should operate workplaces weakly because housing instability should affect reliability, not create free labor.

Home-life needs include:

- food
- shelter
- household goods
- clothing
- future home-improvement goods

Food and shelter are hard survival and retention needs. Most other home-life needs should begin as quality-of-life pressure, not immediate failure states.

Household Goods Pressure v0 follows this boundary. Housed families create display-only household goods demand, while temporary or unsheltered families do not create full soft home-life demand yet. The city aggregates this family/home pressure and compares it against the `household_goods` bucket. Current satisfying goods are `carved_goods`, `tiles`, and `statues`. No household goods are consumed, no penalties are applied, and no household inventory is created in this slice.

Family Demand Status Display v0 makes this source visible on inspected homes/families. It shows food as household population pressure, household goods as a housed-home contribution, and shelter as the current residence state. This is a read-only explanation of what the family contributes to city pressure, not a household inventory or consumption system.

Unsheltered Workplace Warning v0 makes workplace instability visible without applying a mechanical penalty. Temporary or unsheltered families can still operate assigned workplaces, still consume food, and still remain valid assignments, but selected production-building information can warn that housing instability may reduce reliability later. Production output, cadence, labor capacity, assignment rules, maintenance, and demand calculations are unchanged in this slice.

Household Prosperity Status v0 is an abstract inspected-household status, not money or exact wealth. It summarizes current need conditions as struggling, stable, comfortable, or eventually prosperous. V0 derives struggling from food shortage or unstable shelter, stable from housed/no-shortage basics, and comfortable from housed/no-shortage households when household goods pressure is met. Prosperous remains future-facing until quality, variety, luxury, or home-improvement systems exist. No bonuses, penalties, consumption, savings, prices, credit, or debt are implemented.

Clothing Pressure v0 makes clothing visible as a soft family need without adding textile production. Demand is population-based and display-only. Clothing Goods Scaffold v0 adds `clothing` as a final-good stockpile key mapped to the `clothing` need bucket, so City Need Pressure can show clothing as unmet when demand exists and the stockpile is zero. Wool remains a future textile input and does not satisfy the final clothing need in this scaffold. This does not affect prosperity, consume resources, create penalties, add winter effects, or add textile production.

### Family-Operated Workplaces

Workplaces are family-operated. For now, one family can operate one workplace. This matches the current one-household responsibility model and avoids turning households into anonymous worker pools.

A workplace defines:

- production outputs
- production inputs
- tools required for operation
- maintenance and upkeep requirements
- future building quality or equipment needs

The family provides:

- labor and operation
- household preference or trade fit
- older-child support where implemented
- future prosperity, ownership, lineage, and succession context

Later, higher-status or prosperous families may be allowed to operate additional workplaces or coordinate larger operations. That is future scope and should not be implemented until the player can understand why a family has that expanded capacity.

Workplace needs include:

- production inputs
- tools
- maintenance materials
- upkeep goods

Workplace shortages should usually reduce production, but the exact consequence should depend on the missing need. Missing input goods should block or cap output. Missing tools or upkeep should reduce reliability, maintenance, or production cadence.

### Household Prosperity Without Money

Prosperity should be household-level, but not exact savings yet. Do not track money, coins, exact savings, debt, credit, or currency in this layer.

Use an abstract prosperity or status concept when the model needs richer demand:

- Struggling families have unmet basic needs or unstable shelter.
- Stable families have basics met.
- Comfortable families have basics met and household goods available.
- Prosperous families later want refined goods and home-improvement goods.

In this stage, prosperity changes the type of goods demanded, not exact quality. Quality, variety, brands, prestige, and cultural preference can come later.

### Category Demand Before Exact Goods

Goods satisfy demand by category first. Exact goods matter only as members of categories until later quality or preference systems exist.

Examples:

- A family needs food; different cities may satisfy that through generic food, wheat, bread, fish, or other edible goods.
- A household-goods need may be satisfied by pottery, carved goods, or future local domestic goods.
- A maintenance need may be satisfied by tools, wood, masonry materials, or later specialized upkeep goods depending on the building.

Different cities should be able to satisfy the same need through different local goods. Variety bonuses may come later, but are out of scope for the next implementation slices.

### Bridge To Money Later

Money, trade value, obligation, credit, and debt should emerge later from recurring demand, surplus, shortage, production reliability, household prosperity, and inter-city exchange.

Do not implement:

- prices
- wages
- household savings
- debt
- city credit
- accepted currency
- obligation ledgers

The material loop should become believable first. Money can then explain exchange and trust rather than papering over missing demand.

## Current Model

The current code tracks `food`, `wood`, and `tools` as the primary material resources.

- Farms produce generic `food`.
- Woodcutters produce `wood`.
- Toolmakers consume `wood` and produce `tools`.
- Food consumption scales from total population through `City.consume_food()`.
- Food shortage can reduce production cadence.
- Production buildings require assigned household labor and maintenance above zero.
- Maintenance uses `tools`, not labor, in the current code.
- `City.get_pressure_summary()` reports food, shelter, labor, tools, and maintenance pressure.
- The City Overview sidebar displays food, wood, tools, population, shelter, labor, selected-building details, and action hints.

Current resource expansion risk points:

- `City.make_starting_resources()` initializes resource keys.
- `City.record_resource_history()` and `City.get_resource_trends()` currently track only food, wood, and tools.
- `City.apply_building_production()` contains the current production formulas.
- `City.consume_food()` currently consumes only generic food.
- `scripts/main.gd` displays resources directly in the City Overview.
- Trade UI currently exposes food, wood, and tools.

The first expansion should add resource visibility and safe storage keys before changing production or consumption formulas.

## Target Goods List

### Food And Edible Goods

| Good | Category | Purpose | Producer | Inputs | Need Supported | Pressure / Identity Role | First-Playable Priority | Future Economy / Trade Role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `wheat` | raw edible/crop | Crop base for bread and grain stores | Farm | none initially | food backing, storehouse | grain town, surplus grain | high | trade staple, storehouse backing |
| `bread` | processed edible | More legible prepared food | Bakery | wheat | food, household rationing | food-secure city | high | redeemable food claim backing |
| `fish` | edible | Terrain-specific food source | Fishery | water access | food diversity | river/coastal food identity | medium | city-to-city food trade |

### Raw Goods

| Good | Category | Purpose | Producer | Inputs | Need Supported | Pressure / Identity Role | First-Playable Priority | Future Economy / Trade Role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `wood` | raw material | Existing construction/tool input | Woodcutter | forest/local trees | building, tools, upkeep chains | forest town, timber supply | already active | trade input, basic backing |
| `stone` | raw material | Base for durable construction | Quarry | stone deposit | construction, future infrastructure | quarry town | medium | regional construction trade |
| `clay` | raw material | Base for pottery and storage goods | Clay Pit | clay deposit | storage, household goods | clay-rich settlement | medium | trade good, storehouse support |
| `wool` | raw material | Base for clothing | Sheep Pasture | pasture/grassland | clothing, warmth, comfort | pastoral identity | medium | textile trade input |

### Finished And Processed Goods

| Good | Category | Purpose | Producer | Inputs | Need Supported | Pressure / Identity Role | First-Playable Priority | Future Economy / Trade Role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `planks` | processed material | Better construction material | Sawmill or Carpenter | wood | building expansion | timber-processing city | high | construction export |
| `stone_blocks` | processed material | Durable construction component | Mason | stone | durable housing/infrastructure | masonry identity | medium | high-value trade material |
| `tools` | finished tool | Existing maintenance and production support | Toolmaker | wood currently, later metal/planks | maintenance, production reliability | tool-poor/tool-secure city | already active | important trade good |
| `pottery` | finished household/storage good | Storage and household utility | Potter | clay | food storage, household comfort | pottery town | medium-low | trade good, storehouse support |
| `clothing` | finished household good | Household comfort and future health/weather support | Weaver/Tailor | wool | warmth, dignity, household welfare | textile town | medium-low | trade good, household acceptance |

### Wooden Tools Decision

`wooden_tools` should be deferred as a tracked resource until it has a distinct gameplay role from `tools`.

Possible future uses:

- an early/simple tool tier before metal tools
- lower-quality maintenance support
- temporary substitute for full tools
- a local stopgap when advanced tool production is unavailable

For now, adding `wooden_tools` would create a second tool key without a clear need, pressure, or production distinction. The first implementation task should leave it out and keep `tools` stable.

## Proposed Building Chains

These are design targets, not committed formulas.

- Farm: produces `wheat`; current farm may continue producing generic `food` until migration is safe.
- Bakery: consumes `wheat`, produces `bread`.
- Fishery: produces `fish`; requires river, coast, lake, or other water access.
- Woodcutter: produces `wood`.
- Sawmill/Carpenter: consumes `wood`, produces `planks`.
- Carpenter/Toolmaker: may later produce simple tools from wood or planks.
- Toolmaker: currently consumes wood and produces `tools`; later may represent general or metal tools.
- Quarry: produces `stone`.
- Mason: consumes `stone`, produces `stone_blocks`.
- Clay Pit: produces `clay`.
- Potter: consumes `clay`, produces `pottery`.
- Sheep Pasture: produces `wool`.
- Weaver/Tailor: consumes `wool`, produces `clothing`.

The first chains should be small. Wheat to bread and wood to planks are the best early candidates because they connect directly to survival, construction, and future storehouse backing.

## City Access Rules

Cities should not automatically receive every good and production chain in the long term.

Availability should eventually depend on:

- terrain and local deposits
- river, coast, lake, or other water access
- arable land
- forest
- stone or clay deposits
- pasture or grassland
- household skills, traits, preferences, or cultural knowledge
- trade inputs
- discovered or known production methods

Near-term implementation can initialize resource keys globally for safety, but gameplay access should later become city-specific.

## Food Migration Strategy

Do not delete generic `food` immediately.

Recommended migration:

1. Keep current generic food survival logic stable.
2. Add `wheat`, `bread`, and `fish` as tracked goods with display support.
3. Add one production chain at a time.
4. Later compute edible supply or food-days from multiple edible goods.
5. Decide whether wheat can be eaten directly, is less efficient than bread, or must be processed for full value.
6. Avoid spoilage until it is explicitly scoped.

The first expansion should not change `City.consume_food()` or food pressure formulas.

## Implementation Roadmap

### Phase 0: Design Doc Only

Record goods, chain direction, access rules, and migration guardrails.

### Phase 1: Expanded Goods Keys And Display

Add initialized resource keys for the planned goods and make them safely visible where appropriate. Do not change production or consumption formulas.

### Phase 2: Wheat To Bread Chain

Add or adapt building behavior so wheat and bread become a visible food chain. Keep generic food compatibility during migration.

### Phase 3: Wood To Planks Chain

Add planks as a construction/material chain. Decide whether planks are display-only first or become building-cost inputs later.

### Phase 4: Fish, Stone, Clay, And Wool Chains

Add terrain-linked goods and buildings in small slices.

### Phase 5: Household Traits And Skills Around Goods

Add household traits or skills only when they are player-facing and explainable.

### Phase 6: Migrate Generic Food Into Edible Supply

Move food pressure from a single generic `food` key toward computed edible supply/food-days when the UI and production chains are ready.

### Phase 7: Revisit Obligation And City Credit

Only revisit obligation pressure, city credit, and accepted currency after goods, needs, and household traits are broad enough to make backing and trust meaningful.

## What Is Not Acceptable

- Do not implement money, credit, debt, obligation, or currency yet.
- Do not jump directly to a full economic simulation.
- Do not delete generic `food` before migration is safe.
- Do not add meaningless goods without a need, producer, pressure, identity, or future role.
- Do not give every city every resource chain by default long-term.
- Do not add household skills or traits without player-facing explanation.
- Do not change production, food consumption, maintenance, or trade formulas as part of resource-key groundwork.
- Do not make city-level demand appear from nowhere; demand should be aggregated from families, homes, workplaces, and later civic buildings.
- Do not add exact savings, money, prices, debt, credit, or currency before recurring material demand is established.

## Open Questions

- Should prosperity be a simple household status ladder, a score, or a set of named conditions?
- When unsheltered workplace weakness becomes mechanical, should it reduce output amount, cadence, assignment eligibility, or fit quality?
- After household goods pressure, should the next soft home-life need be clothing or home improvement?
- Should tools and maintenance remain city/building-level at first, or should homes also create small upkeep demand?
- How should civic buildings emit demand without feeling like arbitrary city upkeep?
- When families can operate more than one workplace, what player-facing condition makes that feel earned and legible?
