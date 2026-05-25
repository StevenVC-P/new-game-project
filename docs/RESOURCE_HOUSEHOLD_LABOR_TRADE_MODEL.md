# Resource, Household, Labor, and Trade Model

This document records the current code behavior for resources, households, labor, buildings, production, housing, food, maintenance, and trade. It separates observed implementation from design intent so future changes do not accidentally flatten the household-first simulation into generic worker-slot logic.

## Observed Behavior

The current model is centered on `City`, `Household`, `Building`, and `TradeRoute`.

- `City` owns households, buildings, resources, resource history, production ticks, pressure summaries, and city-to-city resource transfer helpers.
- `Household` owns population, labor capacity, residence status, work preference, assigned workers, and assigned building ids.
- `Building` owns type, footprint, worker assignment, household assignment, maintenance state, and whether it can produce.
- `TradeRoute` transfers one resource type from a source city to a destination city when active and affordable.

The implementation already treats households as named simulation units rather than anonymous worker slots, but some code-level labor values are still more permissive than the north-star design.

## Current Resource Model

`City.make_starting_resources()` currently creates these resource keys:

- `food`
- `wood`
- `tools`
- `house_shelter_capacity`
- `temporary_shelter_capacity`
- `housing_capacity`
- `housed_population`
- `temporary_sheltered_population`
- `sheltered_population`
- `unsheltered_population`
- `total_population`
- `household_count`
- `total_labor_capacity`
- `assigned_workers`
- `idle_workers`
- `food_consumption_rate`
- `food_shortage`
- `production_tick_count`
- `food_surplus_ticks`
- `external_population_pool`
- `maintenance_grace_ticks`

The primary material resources are `food`, `wood`, and `tools`. Other keys are derived or state-tracking values used for shelter, population, labor, food pressure, growth, production timing, and maintenance grace.

### Expanded Goods Keys

`City.make_starting_resources()` also initializes these expanded-goods resource keys:

- `stone_blocks`
- `cut_stone`
- `bricks`
- `masonry`
- `lime`
- `mortar`
- `statues`
- `carved_goods`
- `tiles`
- `paving_stones`

Basic v1 building production now exists for these keys. Household demand, UI display, trade pricing, prosperity effects, and settlement access rules for these goods are not implemented yet.

Expanded-goods building types are recognized by the placement helper for size/cost validation and by the selected-building overlay for readable labels. The main city build selector still needs a separate integration pass before every expanded-goods building can be selected from the visible build controls.

`City.record_resource_history()` tracks recent `food`, `wood`, and `tools` values. `City.get_resource_trends()` uses that history to estimate per-tick trends for pressure summaries.

## Household-First Labor Semantics

Observed code behavior in `Household.update_labor_capacity()` is:

- population `<= 1`: labor capacity `0`
- population `<= 3`: labor capacity `1`
- population `> 3`: labor capacity `2`

`worker_capacity` is then set to the same value as `labor_capacity`. The city sums household labor through `City.get_total_labor_capacity()` and writes the result into `resources["total_labor_capacity"]`.

Households can be assigned to buildings through `City.assign_household_by_id_to_building()`. Assignment is blocked if the household has no available workers. Buildings store both `assigned_workers` and `assigned_household_id`, while households track assigned building ids and assigned worker count.

Design tension: the project north star says one household should usually mean one primary responsibility, not a generic worker slot. The current code allows larger households to have labor capacity `2`, so future design decisions should decide whether that is intended, temporary, or should be reframed as household capability rather than two anonymous workers.

## Production

Production runs during `City.tick()` after shelter counts, maintenance grace, worker counts, and food consumption are updated.

Observed production behavior:

- Houses do not produce.
- Production buildings require assigned workers and maintenance above zero.
- Farms add `food`.
- Woodcutters add `wood`.
- Toolmakers consume `wood` and add `tools`.
- Quarries add `stone_blocks`.
- Stonecutters consume `stone_blocks` and add `cut_stone`.
- Brickworks consume `wood` and add `bricks`.
- Lime kilns consume `stone_blocks` and `wood` and add `lime`.
- Mortar yards consume `lime` and `stone_blocks` and add `mortar`.
- Mason yards consume `cut_stone` and `mortar` and add `masonry`.
- Sculptors consume `cut_stone` and `tools` and add `statues`.
- Carvers consume `wood` and `tools` and add `carved_goods`.
- Tileworks consume `bricks` and `wood` and add `tiles`.
- Paver yards consume `stone_blocks` and add `paving_stones`.
- Food shortage can skip production on alternating ticks through `should_skip_for_food_shortage()`.
- Maintenance level affects production frequency and can reduce output to zero.
- Household work preference can modify output up or down through `apply_worker_preference_output_modifier()`.

Current base outputs are:

- farm: `2`
- woodcutter: `2`
- toolmaker: `1`
- expanded-goods buildings: `1`

Toolmakers require `2` wood per tool output. If not enough wood exists, tool output is capped by available wood.

Expanded-goods buildings cap or skip output when required inputs are unavailable. Resource values should not go negative.

## Food, Housing, and Maintenance Pressure

Food consumption is population based. `City.consume_food()` calculates consumption as `ceil(total_population / FOOD_PER_POPULATION_DIVISOR)` and stores it in `resources["food_consumption_rate"]`. If food is insufficient, food is reduced to zero and `resources["food_shortage"]` becomes `true`.

Population can grow from the external population pool after sustained food surplus, available housing capacity, and no shortage. Growth either adds one person to an existing eligible household or creates a new neutral household.

Housing behavior currently includes:

- House buildings with fixed `HOUSE_CAPACITY`.
- Temporary shelter capacity from starting resources.
- Household residence states: housed, temporary, and unsheltered.
- Automatic assignment of eligible households to empty house buildings.
- Shelter resource values such as housed, temporary sheltered, sheltered, and unsheltered population.
- `City.get_shelter_pressure()` summarizes stable, temporary shelter, or housing shortage states.

Maintenance behavior is tool based, not labor consuming in the current code. After the maintenance grace period:

- Production buildings advance a maintenance timer.
- If maintenance is enabled and enough tools exist, tools are consumed and `maintenance_level` improves.
- If tools are unavailable or maintenance is disabled, `maintenance_level` degrades.
- Lower maintenance reduces production frequency; zero maintenance prevents production.
- `City.get_maintenance_pressure()` and `City.get_tool_pressure()` expose maintenance/tool risk.

## Trade

Current trade is city-to-city, not household-to-household.

`TradeRoute` stores:

- `source_city_id`
- `destination_city_id`
- `resource_type`
- `amount_per_tick`
- `active`

On each transfer tick, the route checks whether it is active, has a positive amount, and whether the source city can transfer the requested resource. If so, it removes the resource from the source city and adds it to the destination city.

`TradeMenu` is a UI/helper object for creating trade routes. It lets the player select source city, destination city, resource type, and amount per tick. It currently offers `food`, `wood`, and `tools` as selectable trade resources.

## Design Intent

The project direction preserves households as the core social and economic unit. Households should remain family-like entities with population, housing needs, responsibility, preference, and future continuity. Labor should be derived from household state and capability, not from an anonymous pool of interchangeable workers.

The intended first playable loop is survival and growth:

- feed the settlement
- provide housing
- assign household responsibility
- maintain production buildings
- manage pressure from food, shelter, labor, tools, and maintenance
- use trade as a support system between settlements

Future design ideas such as seasons, values, prosperity, health, traits, household maturity, dependents, fertility, and richer assignment fit should be treated as future systems unless current code implements them.

## Open Questions

- Should larger households keep labor capacity `2`, or should the design enforce one primary responsibility per household more strictly?
- Should labor capacity represent number of workers, household bandwidth, or effectiveness?
- How should household maturity affect fertility, dependents, succession, and new household formation?
- How should values influence real outcomes rather than remaining placeholders or design notes?
- Should future trade include household-level or market-level behavior, or remain city-to-city for the first playable loop?
- How should seasonal effects influence production, food pressure, and labor availability?
- Should maintenance remain tools-only, or eventually involve labor, skill, building quality, or prosperity?
