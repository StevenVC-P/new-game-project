# S5c: Wood Within Reach

A correction to S5b, found by the S9 rerun (`S9b_rerun.md`). Branch `feature/ef-s5c-reachable-wood`, off the S9 tip. Nothing goes to develop or main until the owner has reviewed this.

## Owner's decisions (2026-11-06)

- **Reachable-wood correction approved.** A family recognizes wood it owns, community wood open to it, and wood it can legitimately obtain through existing exchange. Another family's private wood is not freely accessible. No new market valuation or occupational incentive.
- **Trace balanced 5 and marginal 0 first.** Decide whether they are defects or legitimate family decisions. Don't tune their survival.
- **Reserve changes deferred.** Once this is verified, present the effects of order, limit and the 30-day danger rule, each separately.
- **Fuel requests: design direction approved, not built.** Eventually through the existing mutual-help system: voluntary, moved by values, relationships, resources and the giver's own needs.

## Town traces (private compact, same founders, read-only)

Tool: `tests/sim/town_trace.gd`. Before S5b is the merged S9 build with `--meta=no_wood_plenty`; both replays reproduce their logged runs exactly (end people 29 and 82; 28 and 7).

### Marginal 0: 82 people before, 7 after

Identical through day 269. Then:

| Day | With S5b | Before S5b |
|---|---|---|
| 299 | 162 wood reads plenty 0.42; 60 days left in the year | Same stock, no such reading |
| 300 | The town's only woodcutter (family 1) looks again on `wood_beyond_winter` and takes up herding, its calling, margin 3.41 | Stays |
| 359 | 124 wood reads plenty 1.00: one day left in the year | Family 3 turns to wood when its hearth goes cold |
| 570 | The next woodcutter (family 3) leaves for toolmaking, its calling, at plenty 0.47 with 169 wood | Woodcutters in work |
| 1380 | A third leaves for herding, at plenty 0.14 with 74 wood | Two woodcutters, one toolmaker |

By year 3: 312 wood cut against 1,849, fuel-short days 120 against 21, tools at 0 against 102, market units 137 against 252. Food and families follow: 7,716 food made against 9,910.

### Balanced 5: 29 people ok before, 28 not ok after

The land needs no heating here, so the winter's need is about zero.

| Day | With S5b | Before S5b |
|---|---|---|
| 1 | The 45 starting wood reads plenty 0.45. Family 1's woodcutter score falls 2.51 → 1.16 and it farms | Family 1 cuts wood |
| 15 | Family 5 cuts wood, at a score of −0.12 and against its calling | |
| 150 | Tools have run out; family 5 leaves for toolmaking, margin 3.73. No one cuts wood | |
| 180–1,430 | Wood sits at 15–19 for more than three years, read as plenty 0.15–0.19. Tools stuck at 9, wood cut stuck at 71, nothing built | Wood and tools keep rising |

By year 3: 1,080 short days against 465, 14 people against 24, 6 homes against 8. Hearths never run short: this town's decline runs through tools and building, not cold. Before S5b it did oversupply, ending with 7,964 wood: no one here burns or buys it (market units 0).

### Verdict

The families' choices themselves are legitimate: each leaves for a calling or an urgent need, and the reasons are honest to them. What's wrong is what S5b told them. These are **additional S5b defects**:

1. **The horizon stops at the year's end.** Need is counted to day 360, then jumps to a full year. Late in winter almost nothing is "needed", and next winter isn't anticipated. The owner asked for anticipated seasonal demand.
2. **Small stocks read as plenty.** `WOOD_PLENTY_FLOOR` only scales the result: any wood above need gives plenty above 0. My statement in `S9b_rerun.md` that starting stock is "below plenty's floor" was wrong; it reads 0.45.
3. **Need counts only what is already under way.** Fuel, working workshops and committed building. Where those are zero, so is need, though a new town will want tools and homes.
4. **The urgent review fires at any plenty above 0**, so a town's only woodcutter looks again over 15 wood.

**Limit of the occupation-choice system, older than S5b:** once no one cut wood in balanced 5, nothing prompted any family to look again for more than three years, though "no one cuts wood" and "wood is short" both stood in the weighing. It only showed because S5b removed the woodcutter.

Reachable wood doesn't address these: both towns are lost in the `X-reach` experiment too.

**Not fixed here:** the correction was approved narrowly. Proposal for the owner, no survival target:
- count need through the end of the next winter, so the horizon never collapses;
- count as plenty only what lies beyond a real margin, not any wood above need;
- hold the urgent review to real plenty.

## Correction

- **`FamilyInitiative.get_reachable_wood(city, household)`:** pooled, the store. Under a compact: its own share, the community's wood, and `TownMarket.get_obtainable`.
- **`TownMarket.get_obtainable`:** what the family could buy on a market day as things stand, the least of its want, what others would bring and what its spare food pays for at the last price. Nothing trades; no new valuation.
- **Uses:** plenty (wood work, side work, the urgent review), a cold hearth's weight, the town's coming cold as a family sees it, and "wood is short".
- **Left as is:** `get_activity_risk`, a town-level reading with no family in it. Need stays the town's: only the supply side changed. A family's own pile counts as the owner specified, so a woodcutter sitting on unsold wood still reads plenty.
- **Test:** `tests/winter_fuel_validation.gd`, `test_reachable_wood`.

## Results

Build `1b8f286`, run in `../ngg-ef-runs7`. Labels `S5c-pooled`, `-communal`, `-shared`, `-private`, `-shared-commons`, `-private-commons`; 5 lands × 8 starts, ordinary, no player, 6 years. Suite: 57/57. Tables: `S5c_summary_y6.md`. "ok" is `off_the_ground`.

**Pooled is unaffected:** `S5c-pooled` equals `G` in all 80 town snapshots on the fields compared, as it must.

Towns ok at year 6, of 40 (before S5b → S5b → S5c), and S5c by land:

| Arrangement | Total | Balanced | Fertile | Forested | Marginal | Rocky |
|---|---|---|---|---|---|---|
| Pooled | 21 → 18 → 18 | 6 | 5 | 3 | 2 | 2 |
| Communal | 20 → 17 → 18 | 6 | 5 | 3 | 2 | 2 |
| Shared | 20 → 19 → 22 | 5 | 7 | 6 | 3 | 1 |
| Shared + reserve | 16 → 14 → 15 | 4 | 5 | 3 | 2 | 1 |
| Private | 15 → 9 → 9 | 3 | 4 | 2 | 0 | 0 |
| Private + reserve | 3 → 1 → 7 | 0 | 3 | 2 | 2 | 0 |

Totals over the 40 towns at year 6:

| Arrangement | Cold deaths | Fuel-short days | Hunger deaths | Wood in store per town | Woodcutter families |
|---|---|---|---|---|---|
| Communal | 41 → 39 → 38 | 3344 → 3738 → 3815 | 73 → 78 → 76 | 1061 → 553 → 531 | 38 → 26 → 28 |
| Shared | 26 → 53 → 46 | 4491 → 6693 → 6293 | 64 → 68 → 72 | 1627 → 957 → 1120 | 45 → 34 → 36 |
| Shared + reserve | 43 → 58 → 35 | 5795 → 7181 → 6078 | 63 → 48 → 63 | 1384 → 877 → 922 | 38 → 24 → 19 |
| Private | 25 → 46 → 34 | 5900 → 8766 → 7756 | 42 → 45 → 45 | 1886 → 887 → 832 | 39 → 19 → 24 |
| Private + reserve | 29 → 43 → 34 | 6598 → 9118 → 8054 | 34 → 41 → 40 | 2113 → 1115 → 1385 | 37 → 22 → 22 |

- **The correction does what it was approved to do.** Cold deaths and fuel-short days fall under shared and private. Most of S5b's added cold is gone, not all.
- **It recovers less than the community-only experiment** (`X-reach`: private 25 cold deaths, 6979 short days; shared 34, 4960). That is expected: a family now also counts its own pile and what it could buy, as the owner specified.
- **Towns ok moves, but read it with care.** Private + reserve rises 1 → 7 and shared 19 → 22. Shared's change is seven towns moving, five up and two down; single towns swing between near-identical builds (`S9b_rerun.md`). No survival rate was aimed at.
- **Private stays at 9.** Marginal 0 and balanced 5 are still lost (18 and 27 people), as the trace predicted. Those are the further defects above, not reach.
