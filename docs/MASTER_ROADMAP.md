# Master Roadmap

*Structure and sequencing approved by the owner on 2026-11-07, as planning only.* This approval authorizes no implementation, merge or push. Each sprint still runs the usual cycle: propose, the owner approves, build on a branch, run matched sims, the owner reviews, and the owner merges. The doc orders three planning threads into six phases, and the owner playtests after each phase before the next is built.

Sources (all unmerged):
- **Economic Foundations:** `docs/ECONOMIC_FOUNDATIONS_ROADMAP.md` and `docs/economic_foundations/` on `feature/ef-s5d-wood-margin` (S1a–S9 built). The reserve experiments are on `experiment/ef-reserve-rules`.
- **Map scale:** `docs/MAP_SCALE_ARCHITECTURE.md` on `docs/map-scale-architecture`.
- **Scale Brief 1:** the population, settlement, culture and fragility design (E14/E15), recorded outside the repo. Phase 0 writes its direction into the docs.

## Settled decisions (owner, 2026-11-07)

Don't reopen these without a concrete technical or gameplay contradiction.

1. **Order.** Track C comes before grouped families. E14-P1 does not move ahead of it. A compelling village comes before optimizing systems whose gameplay value isn't yet established.
2. **Map.** Continuous land in sectors (the report's Option C), with the ×4 scale kept provisionally, subject to the proving tests. Requirements:
   - one geographic truth;
   - town and regional maps may look different but agree on geography, footprints, roads, resources and land changes;
   - settlements expand without rectangular bounds;
   - reach and influence grow from roads, travel and real activity;
   - seamless scrolling between settlements is not required.
3. **Generation.** World generation follows terrain, climate, geography and resources, and guarantees nothing. Some sites are excellent; others are marginal, very hard or unsuitable. Generation never injects resources or fertile land, never equalizes starts, and never stops a founding in a poor place. Later scouting and assessment tools reveal conditions and never change them. Difficulty comes from geography and economics.
4. **Callings and food security.** Food security strongly influences specialization. Callings, inherited values and present or expected demand still count. There is no fixed six-month food-security gate. Families can still make culturally motivated choices that harm them economically. S5b's term against wood no one needs stays: wood held beyond the coming winter counts against wood work. Player reserves are respected and never silently overridden to save a town. The S5d and reserve numbers are **not** approved: see Phase 0.
5. **Grouped families.** Weighted households are the basis of scaling.
   - Labour is the primary grouping, subdivided further as needed.
   - Groups keep their cultural combinations and the spread of them.
   - Values pass through inheritance, circumstance, choice, reproductive success and cultural influence, not a flat inheritance share.
   - Prominent families emerge from influence and from the people or interests they represent.
   - Founding families, historically important lineages and irreplaceable suppliers may stay individual.
   - Aggregation goes by replaceability, not by size or fame.
   - The aim is to keep the cultural and economic simulation at scale, not to replace it with statistics.
   - Thresholds wait until Phase 4.
6. **Scale target.** The architecture must support **1–10 million people in the world's demographics**. A lightweight benchmark starts in Phase 1 and repeats every phase. Core or metropolitan million stays undecided, and neither reading may become an architectural dead end.
7. **Deferred until evidence exists:**
   - inheritance and estate-division mechanics;
   - aggregation budgets and rare-combination thresholds;
   - satellite ownership and regional settlement mechanics;
   - rival acquisition;
   - how a million-person city is represented;
   - minimum hardware and acceptable loading times.

## Rules for every phase

- **Built for weighting from the start (Phases 1–3).** A new household system works through a shared interface rather than its own loop over households:
  - a decision takes a profile and a context;
  - goods go through `TownLedger`;
  - statistics keep distributions;
  - no rule assumes one record is one family.

  Each sprint review counts direct household loops against today's 117. A rise needs a reason in the report.
- **Scale benchmark each phase.** Re-run the Phase 1 benchmark with the systems built so far, and record memory, update cost per game month, save size and render cost.
- **Village review each sprint**, as now: complexity, divergence by land and by player policy, and success and failure from player choices.
- **Owner principles:** household autonomy, indirect player influence, real cultural consequences, economic scarcity.

## Why this order

- **Consolidate first.** The EF chain is 13 sprints deep and unmerged, and every later thread branches from `develop`.
- **Get the land right before anything reads it.** The per-tile land-use record is the keystone for soil, satellites, Summary and districts. Position-pure land and Decision C both change the same generator.
- **Build measuring tools before behaviour changes.** These are the foundations, E13 V0, the experiments and the benchmark.
- **Village depth before aggregation**, written to the rules above.
- **Grouped families before multiple settlements, and Summary before regional value.** E13 V4 and regional trade need Summary.

## Phases

### Phase 0: Consolidate and decide

Open decisions, with evidence and recommendations: see "Phase 0 decisions" below.

Phase 0 is complete only when all five of these are done:
1. The S5d and reserve decisions are resolved, and any adopted reserve rule is carried from the experiment branch onto the chain.
2. Full regression: the whole test suite, `validate_project.ps1`, save loading and determinism.
3. Matched sims on the consolidated chain against the `develop` baseline B0 and the recorded S5d tables, with criteria fixed before the run.
4. A consolidated integration review: one report across S1a–S9 that covers interactions, tick cost, the docs to update, and known limits.
5. Owner playtest of the integrated village.

Approving the roadmap does not authorize the merge. Only the owner merges.

Also in this phase:
- Scale Stage A: vision text and guardrails. Retire `SIMULATION_SCALE_MODEL.md`, `HOUSES_AND_LINEAGE_MODEL.md`, `map_and_settlement_scale_audit.md`, and "one player settlement" in `HANDOFF.md`.
- Write decisions 2 and 3 above into `GAME_VISION.md`.

**Checkpoint 0:** play the merged village. Do the compacts feel different, and are cold sites dangerous but fair?

### Phase 1: Truthful world and instruments (about 4–6 sprints)
- **Map stage 0:** position-pure land, including `add_clay_and_limestone`. Add the per-tile land-use record, and have regional chunks read it so felled woods show.
- **Generation without guarantees:** remove `LocalCityMapGenerator.ensure_floors`. Today it forces 180 buildable, 18 fertile and 90 wooded tiles into every town by clearing rock, making land arable and adding copses. This changes behaviour, so it gets matched sims, and `town_map_validation`'s floor checks change. Saved games keep their land.
- **Stage C foundations:** a demographic record with a labour table, a culture observer, lookups, a stored town heart and stable settlement IDs. Gate: logs identical.
- **E13 V0**, observe only, for the owner to play.
- **S19 scale check**, replacing the stale `HOUSEHOLD_SIM_BENCHMARK.md`.
- **Scale benchmark (first run).** Synthetic populations of 1 and 10 million as weighted records, with plausible labour and value spreads. Measure:
  - memory per record and in total;
  - a monthly update over all records;
  - save size;
  - the world area's land-use record and touched sectors;
  - rendering a 1 million city and a regional view with many settlements;
  - growth behaviour when records split and merge.

  It needs no unfinished gameplay. The owner sets pass criteria before it runs.
- **Experiments:** X1 (current limits and map fill) and X4 (cultural transmission). Record that the map proving tests answered X2.
- **Checkpoint 1:** Does the regional map tell the truth about the town? Do V0's readings match what feels scarce? What does the land look like without floors? Does the benchmark show a dead end at 10 million?

### Phase 2: The land's year (about 6–7 sprints)
- **E13 V1** town reference, then **V2** value in work decisions. V2 also targets the problem that nothing prompts a family to take up missing work. It reads food security from value and demand, and replaces the fixed half-year cutoff (`FamilyInitiative.SECURE_FOOD_DAYS`), in line with decision 4.
- **S10** food kinds → **S11** farming year → **S12** soil (on the land-use record) → **S13** fish and game → **S14** livestock and draft.
- **S13 also reviews `EconomyBalance.LAND_YIELD_FLOOR`.** It currently gives fishers, hunters and herders a quarter of a full yield with no water, woods or pasture in reach. That is a rescue floor, which decision 3 and depleting stocks both rule out.
- Every report records food per worker, because yield sets the real ceiling.
- **Checkpoint 2:** Do villages diverge by climate and by player policy, and is the economy still readable?

### Phase 3: Culture, lineage and tools (about 5–6 sprints)
- **Stage D:**
  - value persistence driven by inheritance, circumstance, choice, reproductive success and influence;
  - wealth inheritance;
  - regional cultural profiles;
  - exact inheritance and estate-division mechanics decided here, on evidence from X4 and Phase 2.
- **S18** rescoped. Prominent families replace Houses in the model docs.
- **Track D:** S15 iron, S16 tool tiers chosen by values, S17 wood species.
- **X3 Keystone Loss.** It measures and never adjusts.
- **Checkpoint 3:** over several generations, do family cultures persist, drift and differ believably? Does losing a key family or supplier hurt for real reasons?

### Phase 4: Grouped families (about 4–5 sprints, highest risk)
- Monthly forms of daily production and consumption, validated against the daily ones.
- **E14-P1** weighted records in the harness. Gate: weight 1 reproduces households exactly, and conservation is exact.
- **E14-P2** mixed towns, grouped by labour first. Gate: no jump when families fold, and the spread of values and value pairs matches.
- Replaceability decides who stays individual: founding families, important lineages and irreplaceable suppliers may. Staying individual changes representation only and never the outcome, so no one gets protection or a bonus.
- Aggregation budgets and rare-combination thresholds are decided here, from evidence.
- **E13 V3** household valuation, serving households and groups alike.
- **Checkpoint 4:** a town of a few hundred families, grouped and ungrouped side by side. Does it still feel like families, and what does a tick cost?

### Phase 5: A living region (about 6–8 sprints)
- Packed sectors, plus land and housing that extend organically past 64×44, with no rectangular bound.
- A community record shared by towns, districts, satellites and Summary settlements. Neutral towns start ticking.
- Supplier records and cascades between settlements, then **E13 V4** regional valuation.
- Roads, with reach and influence that follow travel and activity. Satellites and conserved immigration. Satellite ownership and regional mechanics are decided here, from evidence.
- **E14-P3** prominent families and discrete economic units. Gate: the keystone test matches the full simulation.
- **Checkpoint 5:** Do satellites and neighbours create real dependencies and emigration? Can a Summary town become managed without an invented history?

### Phase 6: The large city and the long climb (6+ sprints)
- **E14-P4** with E15 districts that form organically. Grouped and Patterned representation levels.
- Opening time and far-view legibility. Hardware and load-time targets are set here, from measurements.
- Player tools at scale: mark land use and build infrastructure, and found distant towns. Scouting and assessment tools show land as it is.
- Budget sweep. The benchmark at 1–10 million now runs with the full systems.
- **Checkpoint 6:** a long playthrough. Is pacing on track for 60–80 hours, are the limits natural, and does the world hold millions?

## Phase 0 decisions

Evidence: `S5d_wood_margin.md` and `S9c_reserve_rules.md`. Runs cover 40 towns (5 lands × 8 starts), ordinary difficulty, no player, year 6. Differences of 1–4 towns ok are within noise, so hunger and cold deaths are the steadier signals.

| # | Decision | Options | Evidence | Recommendation |
|---|---|---|---|---|
| 1 | S5d wood need and margin | (a) Keep: need runs to the end of the next winter, margin of half the need again with at least 100, urgent review at plenty 0.5. (b) Revert to S5c. (c) Other margin values, untested | Against S5c, towns ok rise in all six arrangements (shared 22 → 24, private 9 → 12). Stored wood stays 14–43% below pre-S5b. Private stays below pre-S5b (12 vs 15). Pooled cold deaths return to 60, mostly from one town that outgrew its wood | (a), keeping the values chosen before any results |
| 2 | Reserve order | Reserve last, after the larder, neighbours and the market; or keep the current order (reserve first) | Hunger deaths: shared 67 → 23 (fewer in 16 towns, more in 3), private 31 → 28 | Adopt reserve-last. The current order spends the player's reserve before a family's own means |
| 3 | Limit on emergency draws | None; 0.5 of need; another share, untested | 0.5 raises hunger deaths to 107 (shared) and 81 (private), more in most towns | No limit now. If the owner wants limited help, test 0.75 with one trace before deciding |
| 4 | 30-day danger window | Adopt or leave | Little effect: shared hunger 67 → 48, private level | Optional. Adopting it is fair at month ends and low-risk |
| 5 | Phase 0 pass criteria | Set before the run | — | Suite, validation, saves and determinism pass. The consolidated chain reproduces the recorded S5d tables with the chosen rules off. With them on, results are reported in full, with no target to hit |

Known limits that don't block Phase 0:
- A town with no one toolmaking or cutting wood can stay that way. This probably still loses marginal 0, and it is to be traced in Phase 2 with V2.
- Private compacts recover less than the others.

## Owner decisions by phase

| Before | Decisions |
|---|---|
| Phase 0 | The table above |
| Phase 1 | Authorize E13 V0; pass criteria for X1, X4 and the scale benchmark; weighted households as E14's core (direction approved; confirm as the build basis) |
| Phase 2 | V1/V2 timing after playing V0; `LAND_YIELD_FLOOR` in S13 |
| Phase 3 | How intact value combinations stay (after X4); inheritance and estate division; lifetime value change; length of the climb |
| Phase 4 | Aggregation budgets and rare-combination thresholds |
| Phase 5 | Satellite ownership and regional mechanics; rival acquisition, or defer it again |
| Phase 6 | How a million-person city is represented; minimum hardware; acceptable opening wait; Patterned close-up |
