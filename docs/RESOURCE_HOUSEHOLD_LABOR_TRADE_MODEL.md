# Resource, Household, Labor, and Trade Model

This document records the current code behavior for resources, households, labor, buildings, production, housing, food, maintenance, and trade. It separates observed implementation from design intent so future changes do not accidentally flatten the household-first simulation into generic worker-slot logic.

## Observed Behavior

The current model is centered on `City`, `Household`, `Building`, and `TradeRoute`.

- `City` owns households, buildings, resources, resource history, production ticks, pressure summaries, and city-to-city resource transfer helpers.
- `Household` owns population, working adult count, labor capacity, residence status, work preference, assigned workers, and assigned building ids.
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

Expanded-goods building types are recognized by the placement helper for size/cost validation, by the selected-building overlay for readable labels, and by the visible city build controls for placement selection.

`City.record_resource_history()` tracks recent `food`, `wood`, and `tools` values. `City.get_resource_trends()` uses that history to estimate per-tick trends for pressure summaries.

## Household-First Labor Semantics

Observed code behavior in `Household.update_labor_capacity()` is now based on `working_adults`, not raw `total_population`:

- working adults `0`: labor capacity `0`
- working adults `1`: labor capacity `1`
- working adults `2` or more: labor capacity `2`

`worker_capacity` is then set to the same value as `labor_capacity`. The city sums household labor through `City.get_total_labor_capacity()` and writes the result into `resources["total_labor_capacity"]`.

`working_adults` is a v0 compatibility bridge. Existing households initialize it from the old effective population thresholds so current labor capacity remains stable. `total_population` remains the source of household size, food demand, and shelter pressure. Future births should increase `young_children` and `total_population`, but not `working_adults`, `labor_capacity`, `worker_capacity`, idle labor, or assigned worker count.

Households can be assigned to buildings through `City.assign_household_by_id_to_building()`. Assignment is blocked if the household has no available workers. Buildings store both `assigned_workers` and `assigned_household_id`, while households track assigned building ids and assigned worker count.

Design tension: the project north star says one household should usually mean one primary responsibility, not a generic worker slot. The current code allows larger households to have labor capacity `2`, so future design decisions should decide whether that is intended, temporary, or should be reframed as household capability rather than two anonymous workers.

Older-child production support is represented as household support power, not additional workers. `older_children` do not increase `labor_capacity`, `worker_capacity`, idle labor, assigned worker count, or the number of buildings a household can support. When a household is assigned to a producing building, older children can add a small periodic output bonus using conservative diminishing returns:

- `support_power = older_children`
- `support_bonus = floor(sqrt(support_power))`
- the bonus applies only on periodic production ticks after normal labor, food shortage, maintenance, and fit checks

This v0 rule is intentionally simple. Larger families matter, but building-specific labor absorption, land or worksite scale, tools, supervision risk, adult-child succession pressure, and multi-household support are later systems.

Starter households are seeded deterministically with varied lifecycle stages and child counters. This makes household state visible in normal play without adding lifecycle ticking. Seeding does not change population totals, labor capacity, assignment rules, family splitting, death, or housing behavior.

Household lifecycle transitions v0 advance on the calendar `month_changed` signal. `age_in_stage` increments monthly, and deterministic thresholds can move households from newlywed to young family, established family, mature family, and old couple. Child cohort aging uses a separate `child_age_months` counter: every 36 months, all older children become adult children and all young children become older children. Stage transitions that move child counters reset the child aging counter. Transitions do not create new children; future birth rolls should add young children based on family and city conditions such as food security, housing, overcrowding, household stage, stress, grief, risk, and city stability. This does not change labor, assignments, housing, production formulas, succession pressure, family formation, or death/removal behavior.

Adult children are also not automatic generic labor in this v0 model. They remain part of household population and future succession pressure until a later branch defines new-family formation or explicit adult-child labor behavior.

Household birth rolls v0 run on the calendar `season_changed` signal. The roll is deterministic and derived from stable city, household, and calendar values, not map-generation RNG state. Eligible stage base chances are `newlywed` 15%, `young_family` 20%, `established_family` 8%, `mature_family` 2%, and `old_couple` 0%.

Birth rolls are blocked by food shortage, non-housed households, full housing capacity, old couples, at least 2 young children, at least 4 total child counters, or fewer than 5 days of stored food. Stable conditions add small bonuses: at least 10 days of food adds 5%, and housing headroom of at least 2 adds 5%.

On success, the household gains one `young_children`, `total_population` increases by 1, and `child_age_months` resets to 0. `working_adults`, `labor_capacity`, `worker_capacity`, idle labor, assigned worker count, and household count do not increase. Births therefore create real dependents and pressure first; older-child support and adult-child succession remain delayed lifecycle outcomes.

Adult children succession pressure v0 is visible but non-operative. Each pair of adult children represents one potential future family:

- `potential_new_families = floor(adult_children / 2)`
- `succession_pressure = potential_new_families`

The selected-household popup can show no pressure, a future family ready, or succession blocked because no empty house is available.

New Family Formation v0 consumes this status on the monthly household lifecycle path. If a parent household has at least 2 adult children and an empty house exists, one new household can form from that parent that month. The parent loses 2 adult children and 2 total population, then recalculates succession pressure. Parent `working_adults`, `labor_capacity`, and `worker_capacity` do not decrease because adult children are not part of current labor capacity.

The new household starts as a housed `newlywed` household with `total_population = 2`, `working_adults = 2`, no child counters, age counters reset to 0, broad preference inherited from the parent, and `family_trade` inherited from the parent or set to `general`. It occupies the first empty house, but it is not automatically assigned to production work. Work-opportunity matching, family names, marriage matching, wealth transfer, penalties, and multi-household building support are deferred.

Old Couple Lifecycle Completion v0 runs on the monthly lifecycle path after new-family formation. An `old_couple` household can complete its lifecycle only if no adult children remain. If adult children remain, removal is blocked and logged. Eligible old couples use a deterministic age-weighted monthly roll: 0% before 12 months in stage, 5% from 12-23 months, 10% from 24-35 months, 20% from 36-47 months, and 35% from 48+ months. When completion happens, assigned production buildings are unassigned, the household is removed from the active household list, and its house building remains available for later housing assignment. This does not create a new household, delete the house, run accident/risk/grief logic, or transfer inheritance.

Household lifecycle event logging v0 is controlled by `City.ENABLE_HOUSEHOLD_LIFECYCLE_LOGS`. When enabled, it prints structured diagnostic lines such as:

```text
[HouseholdLifecycle] City=0 Household=2 Event=MonthAged age_in_stage=7 child_age_months=7
[HouseholdLifecycle] City=0 Household=2 Event=BirthBlocked reason=temporary_housing
[HouseholdLifecycle] City=0 Household=3 Event=NewFamilyFormed child_household=7 house=12 parent_adult_children=0
[HouseholdLifecycle] City=0 Household=4 Event=OldCoupleMortalityRoll roll=18 chance=20 age_in_stage=36
[HouseholdLifecycle] City=0 Household=4 Event=HouseFreed house=12
```

Birth blocker reasons are intentionally specific for diagnostics: examples include `old_couple`, `temporary_housing`, `not_housed`, `food_shortage`, `food_stored_below_5_days`, `housing_full`, `too_many_young_children`, and `too_many_total_children`. The UI maps these to shorter readable messages such as blocked by age, food, housing, or child limit.

These logs are for retesting and debugging only. They do not change simulation state or add lifecycle rules.

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

Population can grow from the external population pool after sustained food surplus, available housing capacity, and no shortage. Growth either adds one person to an existing eligible household or creates a new neutral household. Existing external population growth represents adult arrival for compatibility and may update `working_adults`; future household births should add dependent young children without increasing `working_adults`.

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
