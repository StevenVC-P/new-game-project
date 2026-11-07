# P1-3: Stage C Foundations

Branch `feature/p1-foundations`, stacked on P1-2. These are behaviour-neutral pieces that later phases read.

| Piece | Where | What it does |
|---|---|---|
| Stored town heart | `City.global_site` | The town's global regional tile. `main.gd` sets it where neutral towns are placed and where the player founds (continuous map only). A save from before this fills it in on load from the saved neighbourhood (`GameState.restore`). It saves automatically, like any domain field |
| Stable settlement IDs | `City.settlement_id_for`, `get_settlement_id` | The key of the heart's tile on the planet, wrapped at the date line. Two settlements never share a tile, and nothing extra is stored |
| Demographic record | `TownDemographics` | The labour table (industry, then occupation, from the holding a household works), life stages, and `group()` by industry, occupation or life stage |
| Culture observer | `CultureObserver` | Households per value, per pair of values held together, and per whole combination (most held first) |

**Lookups.** `TownDemographics.group()` is the shared way to reach households by labour or life stage. The Phase 1–3 rule is that new household systems use it, or a decision that takes a profile and a context, instead of adding their own loop. Phase 4's weighted records will be indexed by the same groups.

## Results (pass criteria from `PHASE1_PLAN.md`)

| Criterion | Result |
|---|---|
| Gameplay identical | A town observed every day for two years ends identical to one left alone (the whole saved state compared) |
| Counts | The labour table and life stages count every household and person. Grouping holds every household once. No value pair is held by more households than either of its values |
| Saves and determinism | The heart survives a save. The save, founding, world-flow and founded-town regression tests pass |

The land-use record now uses the stored heart where a town has one.
