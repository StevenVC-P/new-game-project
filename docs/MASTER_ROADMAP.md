# Master Roadmap

*Proposed 2026-11-07. Not approved, and nothing in it authorizes a build.* This doc sets the order of three planning threads, grouped into major phases. After each phase the owner playtests to check the direction before more is built. Each sprint still runs the usual cycle: propose, the owner approves, build on a branch, run matched sims, report, and the owner merges.

Sources (all unmerged):
- **Economic Foundations:** `docs/ECONOMIC_FOUNDATIONS_ROADMAP.md` and `docs/economic_foundations/PLANNING_BRIEF.md` on `feature/ef-s5d-wood-margin`. S1a–S9 are built.
- **Map scale:** `docs/MAP_SCALE_ARCHITECTURE.md` on `docs/map-scale-architecture`. The proving tests are done.
- **Scale Brief 1:** the population, settlement, culture and fragility design (E14/E15). It is design analysis only and isn't in the repo yet. Phase 0 writes its direction into the docs.

## Why this order

- **Consolidate first.** The EF chain is 13 sprints deep and unmerged, and every later thread branches from `develop`.
- **The truthful world comes before anything that reads land.** The per-tile land-use record is the keystone for soil (S12), satellites, Summary and districts. S5's `add_clay_and_limestone` already needs position-pure treatment.
- **Behaviour-neutral instruments come before behaviour changes.** These are the Stage C foundations, E13 V0 and the X experiments. Each one's gate is identical gameplay logs.
- **Village depth comes before aggregation, written to the scale guardrails.** Track C gives cultural selection real trade-offs, and it is playable. Its rules must not assume one record means one family, goods go through `TownLedger`, and statistics keep distributions.
- **Grouped simulation comes before multiple settlements, and Summary before regional value.** E13 V4 and regional trade need Summary. Large cities need weighted records.

## Phases

### Phase 0: Consolidate and decide
- The owner decides the EF items: S5d and its margin, reserve-last ordering, and draw limits.
- The owner merges the EF chain into `develop`.
- Scale Stage A: vision text and the guardrails. Supersede `SIMULATION_SCALE_MODEL.md`, `HOUSES_AND_LINEAGE_MODEL.md`, `map_and_settlement_scale_audit.md`, and the "one player settlement" line in `HANDOFF.md`.
- The owner accepts or changes the map direction (one world state, separate views) and sets the arable-land floor.
- **Checkpoint 0:** play the merged village. Do the compacts feel different? Are cold sites dangerous but fair?

### Phase 1: Truthful world and instruments (about 4–6 sprints)
- Map stage 0: position-pure land, including clay and limestone. Add the per-tile land-use record, and have regional chunks read it, so felled woods show.
- Stage C foundations: a demographic record with a labour table, a culture observer, lookups, a stored town heart and stable settlement IDs. Gate: logs identical.
- E13 V0, observe only. The owner plays this before V1.
- S19 scale check, which replaces the stale `HOUSEHOLD_SIM_BENCHMARK.md`.
- X1 (current limits and map fill) and X4 (standalone cultural transmission). The map proving tests largely answer X2, so record that and close it.
- **Checkpoint 1:** Does the regional map tell the truth about the town? Do V0's readings match what feels scarce?

### Phase 2: The land's year (about 6–7 sprints)
- E13 V1 town reference, then V2 value in work decisions. V2 also targets the limit that nothing prompts a family to take up missing work.
- S10 food kinds → S11 farming year → S12 soil (on the land-use record) → S13 fish and game → S14 livestock and draft.
- Every report records food per worker, because yield sets the real population ceiling.
- **Checkpoint 2:** Do villages diverge by climate and by player policy, and is the economy still readable?

### Phase 3: Culture, lineage and tools (about 5–6 sprints)
- Stage D: value-driven persistence in place of flat 80% inheritance, wealth inheritance and estate division, and regional cultural profiles.
- S18 rescoped, so lifetime change stays below generational change. Prominent families replace Houses in the model docs.
- Track D: S15 iron, S16 tool tiers chosen by values, S17 wood species.
- X3 Keystone Loss. It measures and never adjusts.
- **Checkpoint 3:** over several generations, do family cultures persist, drift and differ believably? Does losing a key family or supplier hurt for real reasons?

### Phase 4: Grouped simulation (about 4–5 sprints, highest risk)
- Monthly forms of daily production and consumption, validated against the daily ones.
- E14-P1 weighted records in the harness. Gate: weight 1 reproduces households exactly, and conservation is exact.
- E14-P2 mixed towns. Gate: no jump when families fold, and ensemble distributions match, including value pairs.
- E13 V3 household valuation, serving households and weighted groups alike.
- **Checkpoint 4:** a town of a few hundred families, grouped and ungrouped side by side. Does it still feel like families, and what does a tick cost?

### Phase 5: A living region (about 6–8 sprints)
- Packed sectors, plus extendable land and housing, for growth past 64x44.
- A community record shared by towns, districts, satellites and Summary settlements. Neutral towns start ticking.
- Supplier records and cascades between settlements, then E13 V4 regional valuation.
- Road networks; satellites as family-owned economic and cultural nodes; conserved immigration and regional roamers.
- E14-P3 prominent families and discrete economic units. Gate: the keystone test matches the full simulation.
- **Checkpoint 5:** Do satellites and neighbours create real dependencies and emigration? Can a Summary town become managed without an invented history?

### Phase 6: The large city and the long climb (6+ sprints)
- E14-P4 with E15 districts that form organically. Grouped and Patterned representation levels.
- City opening time: save, thread or build by sector. Far-view legibility: design and art.
- Player tools at scale: the player marks land use and builds infrastructure, and can found distant towns.
- Budget sweep and a minimum-hardware measurement.
- **Checkpoint 6:** a long playthrough toward hundreds of thousands. Is pacing on track for 60–80 hours, with natural limits?

## Owner decisions by phase

| Before | Decisions |
|---|---|
| Phase 0 | EF decisions 1–3; map direction; arable-land floor |
| Phase 1 | E13 V0 build; X1/X4 pass criteria; weighted households as E14's core |
| Phase 2 | V1/V2 timing after playing V0 |
| Phase 3 | How intact value combinations stay (after X4); Houses → prominent families; lifetime value change; estate division; length of the climb |
| Phase 4 | Record budget and slots for rare combinations |
| Phase 5 | Satellite ownership over time; what a satellite is; rival acquisition, or defer it explicitly |
| Phase 6 | Core or metropolitan million; minimum hardware; acceptable opening wait; Patterned close-up; player tools |

**Open ordering choice.** Track C (Phase 2) comes before grouped simulation, so play value arrives early, but Phase 4 has more household loops to port (117 today). The alternative is to move E14-P1 ahead of Track C: less porting, but playable depth arrives about a phase later. Recommended: keep the order above and enforce the guardrails in Track C reviews.
