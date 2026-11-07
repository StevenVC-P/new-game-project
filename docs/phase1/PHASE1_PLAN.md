# Phase 1: Truthful World and Instruments

Plan for master roadmap Phase 1 (`docs/MASTER_ROADMAP.md`). The owner authorized it through completion on 2026-11-07, and later that day through Phase 3, with these terms:
- **E13:** V1 and V2 are built on a review of V0's logs against what is actually scarce in matched towns. The owner plays V0 later and may roll V1–V2 back.
- **Phase 3's evidence decisions** (how intact value combinations stay, inheritance and estate division, lifetime value change) are decided from X4 and matched sims. The alternatives stay behind switches, and each choice is reported with its evidence.
- **S13** removes `LAND_YIELD_FLOOR`. Yield follows the stock and the land in reach, down to zero.
- **Merging:** each sprint merges into `develop` once its tests, saves and determinism pass and its matched-sim report is written. `main` waits for the owner's review. Each sprint has its own branch from `develop`, its pass criteria are fixed here before it runs, and nothing merges without the owner's review. "Report in full" means results are recorded whatever they show, with no survival or performance target to hit.

| # | Sprint | What it delivers | Pass criteria (fixed before running) |
|---|---|---|---|
| P1-1 | **Land from position, without guarantees** (`feature/p1-land`) | Town land is a pure function of global position: shares become noise thresholds, climate blends per regional tile, clay sees past the map's edge, and limestone is a whole regional deposit. Founding clears the heart and nothing else, so `ensure_floors` is gone | Windows of any size and place agree on every land field (0 differences). Founding changes only the heart and the copses by it. Full suite passes, and the regional fingerprint is unchanged. Saved games keep their land. Matched sims against Phase 0's pooled and shared-with-reserve runs, reported in full |
| P1-2 | **Land-use record** | A compact record per regional tile of what happened on the land: built, streets, farmland, cleared woods, roads. Towns write it and the regional map reads it, so felled woods show | Play is unchanged (identical logs with the record on). The record's totals match the town's own tiles. It survives a save. Size per tile and cost per day are measured |
| P1-3 | **Stage C foundations** | A demographic record with a labour table (industry, then occupation), a culture observer (value spreads and pair counts), lookups, a stored town heart, and stable settlement IDs | Gameplay logs identical to before, day for day, on matched towns. Saves and determinism hold |
| P1-4 | **E13 V0, observe only** | The proposal's observer: monthly raw inputs by good and household, logged on a switch, so formula variants can run over saved logs | Play unchanged (identical logs with the observer on). Logs cover every good and household. The owner plays it before V1 |
| P1-5 | **S19 scale check and the scale benchmark** | Tick cost at 100+ households on today's code, replacing the stale `HOUSEHOLD_SIM_BENCHMARK.md`. Synthetic family records at 1 and 10 million inhabitants, concentrated and distributed: memory, monthly update, save size, land record, rendering, and record growth through splits and merges | Measurements recorded in full. Anything that grows faster than linearly with population is called out as a possible dead end |
| P1-6 | **X1 and X4** | X1: how far today's game goes (households, map fill, where it breaks). X4: a standalone model of how fast values spread and whether combinations survive under the approved transmission terms | Each reports in full. X4 reports value-pair survival over 40–70 generations |

Order: P1-1 first, since P1-2 records the land it makes. P1-3 and P1-4 share the observer pattern. P1-5 and P1-6 measure what exists.

**Checkpoint 1 (owner):** Does the regional map tell the truth about the town? Do V0's readings match what feels scarce? What does land without floors look like? Does the benchmark show a dead end at 10 million?
