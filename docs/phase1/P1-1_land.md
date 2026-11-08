# P1-1: Land From Position, Without Guarantees

Branch `feature/p1-land` (`2230650`). Town land is a pure function of global position, and founding clears the town's heart and nothing more: `ensure_floors` is gone (owner, 2026-11-07).

## Pass criteria (from `PHASE1_PLAN.md`)

| Criterion | Result |
|---|---|
| Windows agree on every land field | 0 differences in 56,320 tiles compared: sites 2 and 8 regional tiles apart, and 64×44 maps inside 160×120 maps (`town_map_validation`) |
| Founding changes only the heart and nearby copses | Holds on all 24 probed sites |
| Full suite; regional fingerprint unchanged | 57 of 57 pass (`region_map_validation` includes the fingerprint) |
| Saved games keep their land | Town maps are saved whole. The save tests pass, and the owner's autosave replays unchanged |
| Matched sims reported in full | Below |

## What changes on the land

- Farmland at the 24 probed sites now ranges from 112 to 1,381 tiles, with no floor. The old generator forced at least 18 fertile, 180 buildable and 90 wooded tiles into every town.
- Limestone is now a whole regional deposit (2,213 of 4,883 stone tiles at the world's settlements), not chosen by scan order.
- Clay sees the bank past the map's edge, so a town's clay no longer depends on where its window was cut.

## Matched sims: pooled, against Phase 0

5 lands × 8 starts, ordinary, no player, year 6. `P0-pooled` (`72d8554`) against `P1L-pooled` (`2230650`). Medians, with ranges in brackets.

| Land | Towns off the ground | People | Food-short days | Hunger / cold deaths |
|---|---|---|---|---|
| Balanced | 6 → 5 | 32 → 31 | 140 → 131 | 13 / 19 → 15 / 11 |
| Fertile valley | 4 → 5 | 39 → 26 | 226 → 173 | 18 / 3 → 19 / 8 |
| Forested | 4 → 5 | 22 → 27 | 308 → 206 | 18 / 6 → 14 / 10 |
| Marginal | 4 → **2** | 22 → **0** | 141 → 193 | 9 / 32 → 15 / 24 |
| Rocky highland | 2 → 2 | 0 → 0 | 247 → 208 | 17 / 0 → 18 / 26 |
| **All** | **20 → 19** | | | |

- **Marginal land is where the floors mattered.** Without the 18 guaranteed fertile tiles it lost half its successful towns and its median town. That is the decision working as intended: a poor site stays poor.
- **Forested land does better** (shortage days 308 → 206, first-year shortage 127 → 60). The old floors cleared woods near the heart to make room. Now the land is what it is, and families farm what open land there is.
- Fertile valleys keep their successes but have fewer people at the median. Rocky highland is unchanged.
- Differences of 1–4 towns are within this design's noise, so marginal's change is the clear signal.

**Map luck** (stand-in player, sensible opening) is unchanged: 48 of 48 on the original regional maps, 40 of 42 on the continuous map.

## Shared compact with a reserve

`P0-shared-commons` against `P1L-shared-commons`, on the same settings.

| Land | Towns off the ground | People | Hunger / cold deaths |
|---|---|---|---|
| Balanced | 5 → 4 | 23 → 29 | 11 / 2 → 5 / **29** |
| Fertile valley | 7 → 5 | 29 → 24 | 1 / 5 → 2 / 6 |
| Forested | 3 → 5 | 21 → 28 | 2 / 6 → 5 / 5 |
| Marginal | 3 → 4 | 19 → 20 | 1 / 17 → 5 / 19 |
| Rocky highland | 2 → 3 | 7 → 9 | 8 / 4 → 7 / 12 |
| **All** | **20 → 21** | | **23 / 34 → 24 / 71** |

- **Towns off the ground hold** (20 → 21), and forested towns' food shortage days fall by more than two thirds (748 → 214).
- **Cold deaths double** (34 → 71), mostly on balanced land (2 → 29). The old floor guaranteed 90 wooded tiles in every town. Without it some balanced sites have little wood near the heart, and their hearths went short far more often (median days 22 → 141). That is land as it is, not a defect. A player who reads a site with few woods, or plans its fuel, has a reason to.
- Fertile valleys lose two successful towns. Their farmland is now what the land gives, so some have less.
