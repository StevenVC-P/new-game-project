# S13: Fish and Game Stocks

Branch `feature/p2-s13-stocks` (`a9d9b93`), stacked on Phase 1. The town's fish and game regrow logistically and fall with every catch. A fisher's and hunter's yield, and what families judge a site by, follow the stock. `LAND_YIELD_FLOOR` is removed (owner, 2026-11-07), so water, woods, pasture and distant trees give down to nothing.

**Capacities were set before any comparison:** one full-reach fisher per 12 water tiles, or hunter per 40 woods tiles, takes the most the stock can sustain. Huts and lodges already share their water and woods, so a town worked to the full settles near half stock, which halves the catch but doesn't collapse. A stock emptied by heavy fishing recovers slowly from beyond the town's reach (2% a year of what's missing).

**Tests:** `wild_stocks_validation` (new), plus land, hunting, woodland and occupation tests changed for no floor. Full suite 61 of 61 on S10, which sits on S13.

## Matched sims, against P1-1

5 lands × 8 starts, ordinary, no player, year 6.

| | Towns off the ground | Median people | Hunger / cold deaths | Food-short days |
|---|---|---|---|---|
| Pooled, P1-1 → S13 | 19 → 19 | 18 → 18 | 81 / 79 → 87 / 83 | 7,432 → 7,831 |
| Shared + reserve, P1-1 → S13 | 21 → 20 | 21 → 21 | 24 / 71 → 31 / 53 | 22,898 → 23,539 |

**The cost is small:** within a town either way, with a few more hunger deaths. Today's towns don't fish or hunt hard enough to empty their water or woods within six years. The stocks matter for larger towns and longer runs. The floor's removal mostly touches towns with almost no water or woods in reach, which the floor used to keep at a quarter yield.
