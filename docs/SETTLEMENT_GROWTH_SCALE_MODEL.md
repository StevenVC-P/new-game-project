# Settlement Growth Scale Model

This document defines what `Founding Hamlet -> Stable Village -> Early Town` means, which pressures should matter at each step, and which implementation sprint should come first. It is planning-only. It follows `docs/map_and_settlement_scale_audit.md`, which recommended this model before any new growth mechanics.

Thresholds and pacing numbers here are provisional design guardrails, not tuned values. Items marked **Owner decision** need an explicit product call before implementation.

## Design Principle

A settlement grows up by becoming a stable society of families, not by reaching a population number.

Stage progress should be measured mainly in:

- household count and household continuity (second-generation families, succession)
- stability held over time (food buffer, shelter, responsibility coverage)
- earned milestones (first harvest surplus, first winter survived, first locally formed family)

Raw population should inform stages but should not be the gate. A town of 40 people in 10 stable, multi-generation households is more of a village than 60 people crowded into temporary shelter.

## Current Growth Mechanics

What the code does today (`scripts/domain/city.gd`, `scripts/domain/household.gd`):

| Mechanic | Cadence | Rule |
| --- | --- | --- |
| Simulation day | 1 real second at 1x | `SimulationClock.DEFAULT_DAY_SECONDS_AT_1X = 1.0`; 1 year = 360 days = 6 min at 1x, 36 s at 10x |
| Migration | daily check | after `FOOD_SURPLUS_TICKS_FOR_GROWTH = 8` surplus days with housing headroom, +1 person from `external_population_pool` (starts at 20, never refills) |
| Births | each season | per-household roll; base chance by lifecycle stage (15/20/8/2), +5 for 10+ food days, +5 for housing headroom, capped at 30; blocked by food, housing, child limits, old age |
| Aging | each month | lifecycle stages newlywed (6 mo) -> young family (12) -> established (24) -> mature (36) -> old couple; child cohorts age every 36 months |
| New family formation | each month | a household with 2+ adult children spends 2 of them to form a newlywed household, if an empty house exists |
| Old couple completion | each month | old couples with no adult children roll for removal after 12 months in stage; house is freed; work succession prefers descendants |
| Housing | continuous | one household per house; `HOUSE_CAPACITY = 4` people per house counts toward `housing_capacity` |

Founding starts with 4 households of population 4 (16 people) in temporary shelter, seeded across lifecycle stages.

## Findings That Shape The Model

These gaps appear when growth is traced through the current code. They are the main reason growth needs a model before more mechanics.

1. **Migration adds people, not households.** `add_population_from_external_pool()` adds one person to an under-capacity household, or creates a 1-person neutral household in temporary shelter. Migrant households fill up one person at a time and carry no children, lineage, or lifecycle shape, so they never produce new families. This conflicts with the household-first direction.
2. **Migration has a hard ceiling.** The pool of 20 never refills. Once it is spent, growth comes only from births and family formation.
3. **Natural household growth is slow.** The earliest locally formed family requires a parent with 2 adult children. From the starter seeds that is roughly year 3 (about 18 minutes at 1x). Estimated from code reading; not yet verified by a timed run.
4. **The likely growth curve stalls near the village threshold.** 4 founders + about 5 migrant households (20 pool / 4 per household) = about 9 households in the first year, then slow natural growth. The point where systems run out is the point where "village" should begin.
5. **Housing counts people and households differently.** A house holds one household but contributes 4 people of capacity. Families can grow to about 6 (2 adults + up to 4 children), so a fully housed settlement can still read as "housing full" and block births.
6. **The starter newlywed seed has population 4 but no children.** Its population and child fields disagree. Small, but it matters if stages read family structure.
7. **Nothing tells the player they have grown.** There is no stage, milestone, or progress concept. Growth is visible only as numbers rising.

Findings 1, 2, and 5 change formulas in high-risk files and are product-design changes per `docs/household_simulation_philosophy.md`. They are listed here for decision, not fixed.

## Stage Definitions

### Stage 0 - Founding Camp

Entry: the town is founded.

- Shape: 4 founding households in temporary shelter.
- Player job: get every family housed, assign farm/wood responsibilities, avoid the first food shortage.
- Dominant pressures: shelter, food, responsibility coverage.
- Simulation resolution: named households, direct assignment.
- Exit to Hamlet: every household is housed and food is not in shortage.
- Milestone record: "Every family housed."

### Stage 1 - Hamlet

Entry: all founding households housed.

- Shape: about 4-9 households, about 16-40 people.
- Player job: build a food buffer, keep tools and maintenance up, absorb the first newcomers, survive the first winter.
- Dominant pressures: food buffer, tools/maintenance, housing for newcomers, coverage as households age.
- Growth sources: migration (primary), births.
- Simulation resolution: named households, direct assignment.
- Exit to Village (all required, provisional):
  - 10+ households
  - at least one locally formed household (generation 1+)
  - one full season with no food shortage and no unsheltered households
  - first winter survived
- Milestone records: "First harvest surplus", "First winter survived", "First new family formed".

### Stage 2 - Village

Entry: Hamlet exit conditions met.

- Shape: about 10-30 households, about 40-150 people.
- Player job: keep a multi-generation settlement stable; house new families; keep family trades continuing through succession; meet household goods and clothing needs.
- Dominant pressures: housing for newly formed families, succession and work continuity, building materials, household goods, clothing.
- Growth sources: births and family formation become the main source; migration tied to settlement attractiveness.
- Simulation resolution: still named households, but the player should no longer need to hand-assign every family. This is where population first feels different: overviews, coverage summaries, and priorities matter more than individual clicks.
- New systems that belong here: clothing/textile production, first trade reason with the neutral town, household satisfaction records.
- Exit to Early Town (provisional):
  - 30+ households
  - several second-generation households across at least two family trades
  - soft-need (household goods, clothing) satisfaction sustained for a year
- Milestone records: "First succession", "First family trade carried on", "First trade with a neighbor".

### Stage 3 - Early Town (direction only)

Defined here only so village work points the right way. No implementation in this model.

- Shape: about 30-60+ households, about 150-300 people.
- Expected shift: grouped households or neighborhoods, storage/logistics summaries, priority tools replacing direct assignment, notable lineages.
- Matches the audit's "large village / small town" band.

## Growth Sources

### Natural Growth

Births, aging, and family formation already exist and are the right long-term engine. They are slow by design: a family takes years to produce a new household. That slowness is the emotional core of the village stage. Families the player protected in the hamlet become the parents of the village.

### Migration

Recommended direction: **migration brings families, not heads.**

- Migrants should arrive as whole households (newlywed or young family, 2-5 people) with lifecycle, preference, and family trade set, the same shape as founding households.
- Arrival should be driven by settlement attractiveness built from pressures that already exist: food days stored, housing headroom, soft-need satisfaction, absence of shortages.
- The source should be regional rather than an invisible fixed counter. Simplest version: a slowly refilling regional migrant pool. Later: the neutral town or regional sites supply migrants.
- Migration should be strongest in the Hamlet and taper in the Village, so the village grows mainly from its own families.

**Owner decision:** should migration be reworked to whole households, and should the pool refill?

## Housing And Stage Pressure

The house is a family home, so housing pressure should be measured in households first:

- primary signal: households without a house, and families waiting to form (adult children ready but no empty house)
- secondary signal: crowding when a family exceeds its house's comfortable size, as a later stability or satisfaction effect rather than a hard birth block

**Owner decision:** should births stay blocked by city-wide population vs. capacity, or move to household-level housing (has a house, house not overcrowded)?

## Pacing Targets

At 1x (6 minutes per game year), provisional:

| Stage | Target game time | Real time at 1x |
| --- | --- | --- |
| Founding Camp | first season | about 1-2 min |
| Hamlet | years 1-3 | about 6-18 min |
| Village | years 3-10 | about 18-60 min |
| Early Town | year 10+ | beyond first playable |

The first playable milestone should be able to reach Village in one session. Under current rules that is roughly possible near year 3, but growth likely stalls soon after because migration ends. A timed headless run would confirm this before any tuning.

## Player-Facing Stage Display

The player should always be able to answer "what is my settlement, and what would make it grow?" Suggested City Overview addition:

```text
Hamlet - 7 households, 31 people
Toward Village:
  [x] First winter survived
  [ ] 10 households (7)
  [ ] A family formed here (0)
  [ ] One stable season (food ok, all sheltered)
```

Stage titles should not drop back once earned; they are history. Current stability can still drop and be shown as pressure. **Owner decision:** confirm that stages never regress.

## Recommended Implementation Order

1. **`feature/settlement-stage-status-v0`** - recommended first.
   - Computes the current stage and progress checklist from existing state (household count, generation, shelter, food shortage, calendar) and records milestones.
   - Shows it in the City Overview.
   - No formula changes. Read-only plus a milestone record. Low risk.
   - Gives the first playable a visible goal immediately, and gives every later sprint a way to show its effect.
2. **`feature/household-migration-v0`**
   - Whole-household migrants driven by attractiveness, with a refilling regional pool.
   - High-risk (`city.gd` growth formulas). Needs the owner decision above.
   - Fixes findings 1-2 and the post-hamlet stall.
3. **`feature/household-satisfaction-records-v0`**
   - Per-household satisfaction snapshots; feeds the village exit condition and attractiveness.
4. **`feature/clothing-textile-production-v0`**
   - Gives the clothing soft need a production answer in the village stage.
5. **Neutral-town trade reason** - after the village has real surplus or shortages to trade.

Housing-in-households (finding 5) and the newlywed seed mismatch (finding 6) can be small fixes inside sprint 2 or their own `fix/` branch once decided.

## Owner Decisions Needed

1. Are the stage names and exit conditions acceptable (Founding Camp, Hamlet, Village, Early Town)?
2. Should migration bring whole households, and should its pool refill?
3. Should birth blocking move from city-wide population capacity to household-level housing?
4. Do stage titles never regress?
5. What is the first playable's target: reach Village, or hold Village for some number of years?

## Explicit Non-Goals

This model does not implement or redesign:

- neighborhoods, districts, or household aggregation
- realm or larger region maps
- money, credit, markets, or a trade overhaul
- labor capacity (the `working_adults` -> labor capacity 0/1/2 bridge in `HOUSEHOLD_LIFECYCLE_SUCCESSION_MODEL.md` stays as is)
- politics, diplomacy, or military

## Validation

Documentation-only branch:

- Run `git diff --check`.
- No Godot validation required; no scripts changed.
