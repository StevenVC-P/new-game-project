# Simulation Scale Model

Firm owner decisions on what the game simulates at each scale, and what it deliberately does not (2026-10-19). Sits under `docs/GAME_VISION.md`; builds on the bands in `docs/map_and_settlement_scale_audit.md`.

Performance numbers are measured in `docs/HOUSEHOLD_SIM_BENCHMARK.md`.

## Principle

**A living world comes from visible agents with goals, not from simulating everyone.**

Mount & Blade II: Bannerlord is the reference. Its towns are a handful of numbers plus named notables; nobody actually lives there. Its life comes from a few hundred agents moving on the map: lords, armies, caravans, bandit parties, villagers. Battles are simulated in full only when the player is present. This game follows the same principle, with deeper simulation where the player is looking: their own early settlements.

## Simulation Levels

| Level | Used for | Unit simulated | Cadence |
| --- | --- | --- | --- |
| **Full** | The player's settlements up to roughly village scale | Named households (current model) | Daily needs/production; monthly lifecycle; seasonal births |
| **Grouped** | The player's large towns and cities | Population groups (households bucketed by trade, class, culture, and life stage, with counts) plus named notable families | Monthly |
| **Summary** | AI towns and rival powers | Settlement numbers: population, prosperity, production by sector, stocks, culture profile | Monthly or seasonal |
| **Agents** | The living world map | Caravans, armies, bandit gangs, migrant groups, envoys | Daily, on the map |

Rules:

- **One rule set at scale.** When a player settlement grows past the Full threshold, it switches to the same Grouped model that AI cities use. There is no separate "player big city" simulation to maintain.
- **Continuity across the switch.** Founding and notable lineages stay named households inside the Grouped model. Ordinary households fold into groups that keep their trade, culture, and life-stage mix.
- **Culture must aggregate.** Whatever culture is, it must be representable per household (Full), as a distribution per group (Grouped), and as a profile per settlement (Summary). This constrains the culture model.
- The Full -> Grouped threshold is a tuning value set from benchmark results, not a design constant. The audit's guardrail is about 250-1,000 people (roughly 60-250 households).

## Large Cities

**Placement coarsens with scale.**

- **Hamlet and village:** the player places individual houses and workplaces (current behavior).
- **Town:** the player places neighborhoods.
- **City:** the player places districts.
- The original core the player built stays visible as the old town. Growth beyond the local map shows as district blocks, not individually drawn houses.

Rationale: a 100,000-person city would be about 25,000 houses. Placing them is neither feasible nor fun.

## Battles

**Strategic resolution.** Armies are visible agents on the world map. Battles resolve from strength, terrain, supply, morale, and leadership, and produce a readable report. There are no real-time tactical battles. That would be a second game's worth of work and is the scope cut that most protects the project.

## World Caps (provisional)

Starting targets, to be tuned from benchmarks:

- 6-12 powers
- 50-150 settlements on the world map
- 300-1,000 map agents

These are similar in scale to Bannerlord's world.

## Performance Budget

- At 10x speed the game advances 10 days per second. With about 4 ms of each frame for simulation, the whole world gets about 20-25 ms per game day.
- **Measured** (`docs/HOUSEHOLD_SIM_BENCHMARK.md`): a household's own monthly work costs about 0.8 microseconds and scales linearly. The city-level daily tick is quadratic because of repeated full scans, which caps one city at about 250 households today (9 ms per day; 500 households take 31 ms).
- The ceiling is algorithmic, not GDScript: lookup tables instead of repeated scans are the first fix, before any language change.
- Other costs that grow with scale: per-household lifecycle log strings (`ENABLE_HOUSEHOLD_LIFECYCLE_LOGS = true`) and an O(n^2) household sort (`City.sort_households_by_population_desc`).

## Architecture Guardrails

- **Keep simulation separate from rendering.** Simulation state and rules should live in domain/simulation code, not in `scripts/main.gd`, so hot paths can later move to C# or GDExtension if benchmarks require it.
- **Do not optimize on estimates.** Measure first; optimize demonstrated bottlenecks.
- **Different cadences per level.** Distant and aggregate things update less often.
- **Walkers are cosmetic.** Visible people express households; they are capped and never drive the economy.

## Explicitly Out Of Scope

- simulating every person
- simulating every household in the world daily
- placing every building in large cities
- real-time mass battles
- daily per-good simulation in distant settlements
- walkers as economic agents
