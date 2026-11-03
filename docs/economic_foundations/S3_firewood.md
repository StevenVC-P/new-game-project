# S3: Winter Fuel (and the review that reopened it)

## Implementation

- **Objective:** wood's main sink, and a reason forests matter to survival (owner D5).
- **Built (`accb93d`):** `TownFuel`: hearths burn wood from the common store by the season's cold at the site, by people and by shelter; cold hearths cost working days and hardship. Design and numbers: roadmap, S3 card.
- **Reopened after its first comparison** (this report): survival first wasn't holding for cold. Fix described below, committed on top of the stack.

## Verification

- `tests/winter_fuel_validation.gd` (seasons and climate, people and shelter, real burning, cold hearths, fuel in wood use, warnings, saves; and since the fix, cold drawing families to wood work and starting reviews).
- **First comparison** (`S3b-as-S3`, the S3b build with deaths switched off, 8 starts, 6 years; `S2_S3_S3b_summary_y6.md`): no invariant failed, but the outcomes were a defect, not hardship:

| Year 6, ordinary | S2 (fuel off): ok / people | S3: ok / people | S3: cold days |
|---|---|---|---|
| Fertile valley | 6 / 62 | 3 / 16 | 174 |
| Forested | 7 / 46 | 6 / 26 | 132 |
| Balanced | 8 / 33 | 5 / 24 | 126 |
| Marginal | 6 / 41 | 2 / 0 | 232 |
| Rocky highland | 7 / 57 | 2 / 0 | 126 |

  With S3b's deaths on, **forest towns lost 41 people to cold beside their own woods** (hunger was low there: 30 days).

## What the review found (traced: `tests/sim/fuel_trace.gd`, forested start 1)

A cool forest site (temperature 0.41: heating in spring, autumn and winter) with one hand gatherer's camp for two years and every hearth cold every winter. Three causes, all against survival first (mandate §3: families "should not knowingly ignore an available means of survival"):

1. **Cold started no review and gave wood work no survival pull.** Hunger has both (`get_hardship`, the hungry trigger); cold had neither. Families were never moved off fishing and farming.
2. **The toolmaker took the wood before the hearths:** the day's wood came in during production and the toolmaker used it at once (1,400 wood in two years), leaving the next day's hearths the remainder. Tools outranked warmth.
3. **Families barely gathered firewood**: two of six, at 10–20% of their day; a cold hearth counted only as a modest "own need" in side work, where hunger counts as survival.

## The fix (owner's design kept: deficits are weighed as hardship, not as an essential shortage)

- **`FamilyInitiative.get_cold_hardship`:** the danger of cold, as `get_hardship` is for hunger: the family's own cold days, or the town's wood in store and coming against what its hearths and workshops will use over the coming 120 days. Callings yield to whichever danger is greater; **wood work gets the survival pull** (`SURVIVAL_WEIGHT × level × trees in reach`).
- **`OccupationReview`:** a family cold for two months running looks at its work at once (trigger `cold`, urgent like hunger).
- **Side work:** the danger of cold draws a family to gather firewood with hunger's weight (`HouseholdEconomy.COLD_SURVIVAL_WEIGHT` 4.0).
- **Hearths first among workshops:** while hearths burn, a workshop using wood takes only what lies beyond 5 days of the hearths' need (`TownFuel.get_reserve`). Builders are **not** held back: a first version that held them too kept the town from improving its gatherer's camp into a woodcutter, a trap of its own (traced: less wood cut, more cold).

**Traced after the fix**, the same town: the first winter still goes cold (66 cold days; one child dies) because families answer the cold when it comes rather than ahead of it, a slow response the design allows; by the second winter four of six families gather firewood at 20–30% of their day, **no hearth goes cold again**, and the wood store rises to 481.

## Consequences

- S3's, S3b's, S4's and S5's first comparisons were all made with this defect and are set aside. They are re-run on the fixed build.
- The S2 comparison (fuel off) stands.

## Next steps

Re-run: the fixed build ordinary and stressed, with deaths and fuel switched off in turn to isolate each, and the review players.
