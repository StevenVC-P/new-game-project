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
- `labor_capacity`
- `worker_capacity`
- `assigned_workers`
- `assigned_building_ids`

Labor is derived from total population:

- population `<= 1`: labor capacity `0`
- population `<= 3`: labor capacity `1`
- population `> 3`: labor capacity `2`

This is functional but still too worker-like for the north star. The project direction says one household should usually mean one primary responsibility, not an anonymous pool of interchangeable workers. Larger households currently gain a second labor capacity point, which should eventually be reframed as household support or effectiveness rather than a second generic worker.

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
