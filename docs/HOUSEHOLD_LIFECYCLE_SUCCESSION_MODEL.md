# Household Lifecycle, Family Labor, and Succession Pressure Model

This document is a design model. It does not describe current implementation unless explicitly noted. It exists to guide future household lifecycle work before deeper economy, money, obligation, or city credit systems are implemented.

## Design Vision

Households should be living family units, not worker slots. A household should have a social shape, a life stage, dependents, productive habits, and generational pressure. Its lifecycle should shape labor, production support, housing demand, family formation, succession pressure, and eventually city identity.

The first playable loop already asks the player to feed, house, assign, and maintain a small settlement. The next household layer should deepen that loop by making family continuity visible: young families create food and housing pressure, older children help the family trade, adult children want to split into new households, and old couples eventually leave houses empty.

This model should remain household-level. It should not become full individual-person simulation yet. Counters and stages are enough for the next several slices.

## Current Household Model Audit

Current code behavior centers on `Household`, `City`, and `Building`.

`Household` currently tracks:

- `id`
- `house_building_id`
- `residence_building_id`
- `housing_status`
- `preference`
- `population_capacity`
- `total_population`
- `working_adults`
- `labor_capacity`
- `worker_capacity`
- `assigned_workers`
- `assigned_building_ids`

Labor is derived from `working_adults`, a v0 compatibility bridge that preserves the previous population-threshold behavior for existing households while separating labor from total mouths to feed:

- working adults `0`: labor capacity `0`
- working adults `1`: labor capacity `1`
- working adults `2` or more: labor capacity `2`

`total_population` now means household size, food demand, and shelter pressure. `working_adults` means the adult labor source for current assignment rules. This is still functional but still too worker-like for the north star. The project direction says one household should usually mean one primary responsibility, not an anonymous pool of interchangeable workers. Larger households currently gain a second labor capacity point, which should eventually be reframed as household support or effectiveness rather than a second generic worker.

Residence currently matters because households may be housed, temporarily sheltered, or unsheltered. City housing assignment moves eligible households into empty house buildings. Household population contributes to food consumption and shelter pressure.

Assignment currently matters because production buildings need assigned workers and maintenance above zero. A building can store one assigned household id. A household tracks assigned building ids and assigned worker count. Assignment is blocked if the household has no available workers.

Preference and fit currently exist in a small form:

- Household preferences are `neutral`, `agrarian`, or `industrial`.
- Farms prefer agrarian households.
- Woodcutters, toolmakers, and expanded-goods buildings currently prefer industrial households.
- Fit can affect output through the existing production modifier.

Current gaps:

- No lifecycle stage.
- No child counters.
- No adult-child split pressure.
- No family trade distinct from broad work preference.
- No older-child production support.
- No death, removal, or empty-house lifecycle behavior.
- No succession pressure display.
- No multi-household building support.

## Lifecycle Stages

Lifecycle stages should be explicit household-level states. They should guide UI language first, then formulas later.

### newlywed

- Adults: 2.
- Young children: 0.
- Older children: 0.
- Adult children: 0.
- Labor contribution: one primary household responsibility when healthy and housed.
- Needs and food pressure: modest.
- Ability to have children: high.
- Ability to split into new families: none.
- Production implications: stable baseline production if assigned.
- Housing implications: needs one house or temporary shelter; good candidate for an empty house.

### young_family

- Adults: usually 2.
- Young children: 1 or more.
- Older children: 0 or few.
- Adult children: 0.
- Labor contribution: one primary responsibility, but pressure from young children may reduce reliability later if the model needs it.
- Needs and food pressure: rising.
- Ability to have children: still possible.
- Ability to split into new families: none.
- Production implications: no child production support yet.
- Housing implications: more population in the same house; housing capacity matters.

### established_family

- Adults: usually 2.
- Young children: some.
- Older children: some.
- Adult children: 0 or few.
- Labor contribution: one primary responsibility plus older-child support.
- Needs and food pressure: high, but partly offset by family support.
- Ability to have children: possible but lower than young_family.
- Ability to split into new families: not usually, unless adult children exist.
- Production implications: older children can support the household's assigned building.
- Housing implications: house feels full; future split pressure is approaching.

### mature_family

- Adults: 2 older adults.
- Young children: usually 0.
- Older children: some or declining.
- Adult children: 1 or more.
- Labor contribution: strong family trade continuity while adults remain capable, plus older-child support if present.
- Needs and food pressure: high if adult children remain in the house.
- Ability to have children: no or very low.
- Ability to split into new families: yes; adult children can form new households.
- Production implications: best place to surface succession pressure and inherited trade.
- Housing implications: adult children need new houses; blocked splits should increase pressure.

### old_couple

- Adults: 1 or 2 old adults.
- Young children: 0.
- Older children: 0.
- Adult children: usually 0 if succession worked, or some if blocked.
- Labor contribution: reduced or unreliable.
- Needs and food pressure: lower than a full family, but house remains occupied.
- Ability to have children: none.
- Ability to split into new families: only if adult children remain.
- Production implications: low labor, possible loss of family trade continuity if no successor formed.
- Housing implications: house stays occupied until death/removal; city may have housing bottleneck even with low labor.

### deceased / removed

- Adults: 0.
- Young children: 0.
- Older children: 0.
- Adult children: 0.
- Labor contribution: none.
- Needs and food pressure: none.
- Ability to have children: none.
- Ability to split into new families: none.
- Production implications: no production support.
- Housing implications: house becomes empty and available.

For implementation, `deceased` may be either a short-lived stage for UI/history or simply removal from active households. Archiving should be optional and future-facing.

## Child Counters

Use household-level counters rather than individual child entities:

- `young_children`
- `older_children`
- `adult_children`

These counters should be consistent with `total_population`, but they do not need individual identities.

### young_children

Young children represent dependents who consume food and occupy housing capacity but do not help production.

Mechanical meaning:

- Increase food and housing pressure through household population.
- Do not add labor.
- Do not add production support.
- Signal future growth into older children.

### older_children

Older children represent family members old enough to help with the household's work but not old enough to form independent households.

Mechanical meaning:

- Increase food and housing pressure.
- Add support to the household's assigned production building.
- Do not become separate worker units.
- Do not take separate assignments.
- Should be visible to the player as family support, not hidden productivity.

### adult_children

Adult children represent grown children who can form new households when conditions allow.

Mechanical meaning:

- Increase food and housing pressure while still in the parent household.
- Can be converted into new households.
- Can inherit or prefer a related family trade.
- Create succession pressure if housing, work, or trade opportunity is blocked.

## Family Trade / Inherited Skill

`family_trade` should be a household-level identity. It is narrower and more durable than the current broad `preference`.

Suggested initial family trades:

- `farming`
- `woodcraft`
- `stonework`
- `claywork`
- `textile`
- `food_processing`
- `toolmaking`
- `construction`

The first implementation should not be a full skill simulation. It should provide:

- a readable household trade label
- inherited production affinity for new households
- future mapping from building type to related trade

New households formed from adult children may inherit the parent household's `family_trade`, especially if the parent has been assigned to related work for a long time. They should prefer related work, but they should not automatically support the same building unless that building has capacity and the later multi-household model allows it.

## Older Children Production Support

Older children should increase the output of the building their family supports. They are not separate workers and should not fill separate job slots.

Options:

- Flat output bonus: each older child or threshold of older children adds output.
- Production cadence bonus: older children reduce skipped production ticks or improve reliability.
- Support power modifier: older children add a small `support_power` that modifies output through a single helper.

Recommended v0:

- Add a visible support line, such as "Older children are helping with production."
- Use a simple support power modifier.
- Avoid making older children separate workers.
- Apply support only to the household's assigned building.

A simple v0 formula:

- `support_power = older_children`
- `support_bonus = floor(sqrt(support_power))`
- apply `support_bonus` as occasional extra output on a slow production cadence

This is not a hard child cap. Larger families continue to create more support power, but v0 uses diminishing returns until building absorption, land, tools, worksite scale, risk, and succession pressure systems exist. The important design decision is that older children strengthen the family responsibility, not the city's generic labor pool.

## Adult Children and Succession Pressure

Adult children should become a source of pressure, opportunity, and continuity.

Adult children are ready to form a new household when:

- the parent household has enough adult children to split
- the city has or can provide housing
- there is a suitable work opportunity or at least a tolerable neutral role

Recommended v0 split threshold:

- 2 adult children form one new household.

This represents a new couple or family-like unit without simulating marriage matching. It is intentionally abstract.

Housing should be required for a clean split. If no house is available, adult children remain in the parent household and succession pressure rises. Work should influence preference and pressure but should not hard-block v0 household creation unless the player-facing system can explain it.

Succession pressure means adult children are ready to split but blocked.

Causes:

- no empty house
- no suitable work
- no related trade opportunity
- parent household overcrowding

v0 should display pressure, not punish silently. Pressure can later affect happiness, stability, productivity, migration, or obligation systems, but it should start as information.

## New Family Formation

New family formation should be a household-level transition:

- Parent household spends the adult children used to form the new household.
- New household starts as `newlywed` or young couple.
- New household inherits `family_trade` where appropriate.
- New household needs housing.
- New household prefers related work.
- New household can take neutral or poor-fit work if necessary.

This should not automatically assign the new household to the same building as the parent. If the family trade is farming and a farm has no available support slot, the household should remain available or be assigned elsewhere according to normal rules.

The player should see the opportunity:

- "Adult children are ready to start a new household."
- "No empty house is available for the next generation."
- "Family trade: Stonework."

## Multi-Household Building Support

Do not implement this in the first lifecycle slice.

Future model:

- A building has a primary household.
- A building may have optional supporting households.
- Supporting households use building support slots, not generic worker slots.
- A building's size/type determines support capacity.

Good future candidates:

- farms
- quarries
- large construction yards
- large masonry yards
- maybe textile/craft buildings later

This should be v1/v2 because it changes assignment semantics, production tuning, UI, and the meaning of household responsibility. The first lifecycle implementation should keep one household as the primary responsibility holder.

## Death and Empty Houses

The `old_couple` stage should represent low labor and occupied housing.

Future death/removal behavior:

- Old couples eventually leave the active household list.
- Their house becomes empty and available.
- Their assigned building loses its household support unless succession has already occurred.
- The household record may be archived for history, but active simulation can remove it.

This should be predictable enough to feel like generational turnover, not random punishment. The player-facing pressure should appear before the loss:

- "Old couple: low labor, home remains occupied."
- "No successor household is ready for this family trade."

## Player-Facing Language

Use concrete household language:

- "Older children are helping with production."
- "Adult children are ready to start a new household."
- "No empty house is available for the next generation."
- "Family trade: Stonework."
- "Succession pressure is rising."
- "Old couple: low labor, home remains occupied."
- "New family prefers Woodcraft."
- "Family trade continuity is weak."

Avoid hidden penalties. If lifecycle affects output, housing, or growth, the UI should explain why.

## Implementation Roadmap

1. Design doc only.
2. Add lifecycle fields to `Household`.
3. Show household stage and child counters in UI.
4. Add older children production support.
5. Add adult children and succession pressure display.
6. Add new family formation when housing is available.
7. Add old couple, death/removal, and empty house behavior.
8. Plan multi-household building support.

Suggested first implementation slice after this doc:

- Add lifecycle fields with no formula changes.
- Display stage/counters in debug or selected-household UI.
- Keep existing production, food, housing, and assignment formulas unchanged.

## Lifecycle Seeding v0

Starting households should be seeded with deterministic lifecycle variety so the village does not begin as a set of identical `established_family` households. Seeding is not lifecycle ticking: it does not age families, split adult children, create new households, free houses, or apply succession pressure.

The current starter pattern uses household index to assign a predictable sequence:

- `young_family`: young children, no older-child support yet
- `established_family`: young children plus older-child family support
- `mature_family`: older-child family support and an adult child, with no succession pressure yet
- `newlywed`: no children yet
- `old_couple`: no child counters and no death/removal behavior yet

The first three starter households currently show `young_family`, `established_family`, and `mature_family`. More households can reuse the same sequence. Family trade is seeded from broad preference: agrarian households become `farming`, industrial households become a craft trade such as `woodcraft` or `stonework`, and neutral households remain `general`.

## Lifecycle Aging And Transitions v0

Household lifecycle aging uses the calendar month boundary, not production ticks. When `Calendar.month_changed` fires, each city advances household lifecycle age once, and each household increments `age_in_stage` by 1.

Lifecycle transitions are deterministic and happen when `age_in_stage` reaches a stage threshold:

- `newlywed` -> `young_family` after 6 months; does not create new children.
- `young_family` -> `established_family` after 12 months; moves all young children to older children.
- `established_family` -> `mature_family` after 24 months; moves all older children to adult children, then moves all young children to older children.
- `mature_family` -> `old_couple` after 36 months; moves all older children to adult children, then moves all young children to older children.
- `old_couple` remains `old_couple` in this slice.

Child cohort aging is tracked separately from stage age. Every 36 months, existing child counters move up one band: older children become adult children, young children become older children, and young children reset to 0. Stage transitions that move child counters reset this child aging counter so the same cohort does not age twice in one month.

Transitions and child cohort aging move existing child counters only. They do not represent births. Future household birth rolls should add young children based on food security, housing, overcrowding, household stage, stress, grief, risk, and city stability. Old couples cannot gain new children.

Household Labor / Population Decoupling v0 separates household size from labor source before birth rolls. Young children should increase `young_children` and `total_population` when births are implemented, but they should not increase `working_adults`, `labor_capacity`, `worker_capacity`, idle labor, or assigned worker count. Older children remain production support only. Adult children remain future succession pressure and do not automatically become generic labor in this slice.

## Household Birth Rolls v0

Birth rolls happen on calendar `season_changed`, not daily, monthly, or production ticks. The roll is deterministic for v0: it is derived from household id, city index, city tile, current year, and current month so the same state produces the same outcome.

Base seasonal chances are intentionally conservative:

- `newlywed`: 15%
- `young_family`: 20%
- `established_family`: 8%
- `mature_family`: 2%
- `old_couple`: 0%

Hard blockers prevent a roll when:

- the city has food shortage
- the household is an old couple
- the household is not housed
- city population is at or above housing capacity
- the household already has 2 young children
- the household has 4 or more total child counters
- stored food is below 5 days

Small positive modifiers apply when conditions are strong:

- stored food is at least 10 days: +5%
- housing headroom is at least 2: +5%

On a successful birth, the household gains one young child, `total_population` increases by 1, and `child_age_months` resets to 0. `working_adults`, `labor_capacity`, `worker_capacity`, idle labor, and assigned worker count do not increase. Births are therefore delayed-growth rewards and immediate food/housing pressure, not free labor.

The selected-household lifecycle popup can show whether family growth is possible or blocked by food, housing, or eligibility. Succession pressure, new-family formation, old-couple death/removal, accidents, grief, risk, and individual-person simulation remain deferred.

## Adult Children Succession Pressure v0

Adult children now create visible succession pressure, but they do not leave the household yet.

The v0 rule is:

- `potential_new_families = floor(adult_children / 2)`
- `succession_pressure = potential_new_families`

This means:

- 0-1 adult children: no succession pressure
- 2-3 adult children: 1 potential future family
- 4-5 adult children: 2 potential future families

Housing is the first blocker. If a household has at least one potential future family and an empty house is available, the selected-household popup can show that a future family is ready. If no empty house is available, the popup shows that succession is blocked by housing.

This status is consumed by New Family Formation v0 when housing exists. Work and trade-opportunity matching are deferred until a later branch can explain those requirements clearly.

## New Family Formation v0

New family formation runs on the monthly household lifecycle path, after lifecycle aging, child counter transitions, and succession pressure recalculation. It does not run on production ticks.

The v0 rule is:

- at most one new family per parent household per month
- parent must have at least 2 adult children
- an empty house must exist

On success:

- the parent spends 2 adult children
- the parent `total_population` decreases by 2
- the parent `succession_pressure` recalculates
- parent `working_adults`, `labor_capacity`, and `worker_capacity` do not decrease because adult children are not part of the current labor source

The new household begins as:

- `lifecycle_stage = newlywed`
- `total_population = 2`
- `working_adults = 2`
- no young, older, or adult children
- `age_in_stage = 0`
- `child_age_months = 0`
- `family_trade` inherited from the parent, or `general` if no parent trade is set
- parent work preference inherited as the broad assignment preference

The new household occupies the first available empty house. The system does not create a house, displace any household, or assign the new household to production work. Work matching, inherited job placement, multi-household building support, marriage matching, family names, inheritance, and wealth transfer remain future systems.

## Household Lineage And Trait Inheritance v0

Households now carry simple lineage fields:

- `parent_household_id`
- `origin_household_id`
- `generation`

Starter households are founder households with no parent, their own origin id, and generation 0. A new family formed from adult children records its parent household, keeps the founder origin from the parent line, and starts at parent generation + 1.

New families inherit family work identity with deterministic variation. Most new households keep the parent `family_trade`; some receive a related trade, and rare cases fall back to `general`. Related trades are intentionally small and readable:

- farming can branch toward food processing
- woodcraft can branch toward construction or toolmaking
- stonework can branch toward construction or masonry
- claywork can branch toward construction
- food processing can branch toward farming
- toolmaking can branch toward woodcraft or stonework
- construction can branch toward woodcraft or stonework

This prepares future work succession priority without assigning the new household to work automatically. Family names, marriage matching, individual persons, inheritance or wealth transfer, and multi-household building support remain deferred.

## Old Couple Lifecycle Completion v0

Old-couple lifecycle completion runs on the monthly household lifecycle path after lifecycle aging, succession pressure recalculation, and new-family formation. It does not run on production ticks and uses a deterministic age-weighted roll rather than map RNG.

The v0 rule is:

- only `old_couple` households are eligible
- old couples younger than 12 months in stage do not roll
- 12-23 months: 5% monthly chance
- 24-35 months: 10% monthly chance
- 36-47 months: 20% monthly chance
- 48+ months: 35% monthly chance
- if adult children remain, removal is blocked

When an old-couple household completes:

- any production buildings assigned to that household are safely unassigned
- the household is removed from the active household list
- the occupied house building remains in place and becomes empty/available
- no new household is created by the removal operation itself

This is age-weighted lifecycle completion, not a fixed death date, accident, grief, inheritance, or wealth transfer. The deterministic roll is derived from household, city, age, and city tile values. Unresolved adult children block removal so the system does not erase unresolved succession pressure.

## Household Lifecycle Event Logging v0

Household lifecycle logging is diagnostic only. It is controlled by `City.ENABLE_HOUSEHOLD_LIFECYCLE_LOGS` and prints concise structured lines when enabled.

Format:

```text
[HouseholdLifecycle] City=<city_index> Household=<id> Event=<event_name> <short key=value details>
```

Logged events include monthly aging passes, per-household age updates, stage transitions, child cohort movement, seasonal birth roll blockers and outcomes, succession pressure recalculation, new-family formation attempts, blocked formation due to no empty house, parent counter/population changes, new household creation, old-couple lifecycle completion, removal blocks, house freeing, and assignment cleanup.

Birth blocker logs use specific diagnostic reason codes, such as `old_couple`, `temporary_housing`, `food_shortage`, `food_stored_below_5_days`, `housing_full`, `too_many_young_children`, or `too_many_total_children`. The selected-household UI can summarize these as shorter player-facing messages like "blocked by age", "blocked by food", "blocked by housing", or "child limit reached".

The logs are meant to make owner retesting easier. They do not alter lifecycle rules, production, assignment, housing, birth chances, succession pressure, or new-family formation behavior.

This transition slice is still conservative:

- It does not change succession pressure.
- It does not change labor capacity, worker capacity, assignment, production formulas, or housing rules outside the explicit new-family formation path.
- It does not remove old couples or free houses.
- It creates new families from adult children only through the conservative monthly formation rule when an empty house exists.

The player can verify aging, stage changes, child counter movement, succession pressure, and newly formed households through the selected-household lifecycle popup. Work matching, richer succession pressure, and old-couple death/removal remain later systems.

## What Is Not Acceptable Yet

- No individual-person simulation.
- No family trees.
- No inheritance or wealth transfer.
- No marriage matching system.
- No random death or disaster events.
- No automatic multi-household building support.
- No hidden penalties without UI explanation.
- No money, credit, debt, or obligation implementation.
- No universal resource economy that bypasses household needs.
- No broad rewrite of current assignment or production rules as part of lifecycle v0.

## Open Questions

- Should lifecycle use fixed day/month thresholds or event counters?
- Should adult children require both housing and work before splitting, or only housing in v0?
- Should `family_trade` be assigned at household creation, derived from work history, or both?
- How should household preference and family trade coexist?
- Should old couples produce no labor or reduced labor?
- Should succession pressure affect migration later?
- Should family trade continuity become a city identity metric?
- Should archived households matter for history, culture, or claims later?
