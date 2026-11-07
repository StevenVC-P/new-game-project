# S9c: Reserve Rules as Experiments

Three possible changes to how the common table's reserve answers families in danger, each run on its own and none adopted. Branch `experiment/ef-reserve-rules` (`a384a47`), off S5d's code (`044e567`). Each rule is a city meta switch, off by default. With all three off, the suite passes 57/57 and play is S5d's.

## Owner's terms

Reserves are protected in ordinary times. A family gets limited emergency help only after its own resources and ordinary alternatives prove insufficient. The simulation never silently overrides the player's reserve policy. Evaluate each change separately from the wood correction. No survival tuning.

## The three rules (`TownCommons.feed_from_table`)

- **Order (`reserve_last`).** Today, a family in danger draws on the reserve before its larder, its neighbours and the market. With this rule the reserve comes last.
- **Limit (`reserve_limit`).** Holds a family's daily draw from the reserve to `RESERVE_DRAW_SHARE` (0.5) of its need. That share is a first reading, not a measurement.
- **30-day danger (`reserve_30_days`).** Danger counts the hungry days in the last 30 days, not only this calendar month, so a family short since the 20th isn't turned away on the 1st.

## Results

Shared and private compacts with a 30-day reserve, grants to families in need. 5 lands × 8 starts, ordinary, no player, 6 years, run in `../ngg-ef-runs8`. Baselines are `S5d-shared-commons` and `S5d-private-commons`. Tables are in `S9c_summary_y6.md`. "ok" means `off_the_ground`. R-all (all three together) is shown for comparison only.

| Year 6, over 40 towns | Towns ok (balanced, fertile, forested, marginal, rocky) | Moved up / down vs baseline | Hunger deaths | Towns with more / fewer hunger deaths | Cold deaths | Departed | Household short days |
|---|---|---|---|---|---|---|---|
| Shared, baseline | 18 (5 5 4 3 1) | | 67 | | 35 | 202 | 43,577 |
| Order | 20 (5 7 3 3 2) | 7 / 5 | 23 | 3 / 16 | 34 | 163 | 31,218 |
| Limit | 15 (4 5 3 2 1) | 4 / 7 | 107 | 23 / 8 | 30 | 247 | 40,514 |
| 30-day | 17 (6 4 3 3 1) | 2 / 3 | 48 | 5 / 9 | 39 | 194 | 39,157 |
| All three | 17 (4 5 5 2 1) | 5 / 6 | 106 | 22 / 8 | 29 | 238 | 39,841 |
| Private, baseline | 4 (0 3 1 0 0) | | 31 | | 33 | 202 | 31,406 |
| Order | 8 (4 3 0 1 0) | 7 / 3 | 28 | 6 / 7 | 26 | 184 | 30,444 |
| Limit | 3 (1 1 1 0 0) | 2 / 3 | 81 | 27 / 3 | 17 | 238 | 36,991 |
| 30-day | 8 (3 3 2 0 0) | 6 / 2 | 32 | 6 / 4 | 29 | 192 | 31,786 |
| All three | 5 (2 2 1 0 0) | 4 / 3 | 80 | 28 / 4 | 16 | 238 | 35,847 |

| Year 6, over 40 towns | Food sold at market | Food given by neighbours |
|---|---|---|
| Shared: baseline, order, limit, 30-day | 5,941, 8,428, 4,635, 4,515 | 13,050, 12,482, 21,597, 13,259 |
| Private: baseline, order, limit, 30-day | 19,911, 16,212, 13,095, 17,008 | 59,578, 73,724, 53,367, 57,530 |

### What each rule does

- **Order.** Under shared, hunger deaths fall from 67 to 23, with fewer in 16 towns and more in 3. Under private they hold (31 to 28). Families sell and ask before they touch the reserve, so it lasts longer for the days when nothing else answers. Under shared, more food is sold. Under private, more is given by neighbours. Towns ok rise (18 to 20, 4 to 8), but 12 and 10 towns change places either way, so towns ok alone isn't strong evidence. This rule matches the owner's principle most closely, and its effect on hunger is the clearest result here.
- **Limit.** Hunger deaths rise under both arrangements (67 to 107, 31 to 81), in most towns (23 and 27 of 40). More families leave. Cold deaths fall, likely because fewer people are left to freeze, and this wasn't traced. Holding a family in danger to half its need in this build means that family is short of food. The owner's principle of "limited" help has a real cost here, set by the 0.5 share, and that share hasn't been tested at other values.
- **30-day danger.** The smallest effect: towns ok within churn (17, 8), hunger slightly down under shared (48) and level under private. It does what it says without moving results much.
- **All three.** Looks like the limit: the limit's harm outweighs the order's gain.

### Limits of this evidence

- One seed set per land and one reserve setting (30 days, grants in need). Pooled and communal weren't run, since their tables work differently.
- Paired churn of 5 to 12 towns per rule means towns ok differences of 1 to 4 are within noise. Hunger deaths and short days are the steadier signals.
- No town was traced, so the mechanisms above come from what the code does and the totals, not from watched families.

## For the owner

- **Decide:** whether to adopt the order rule. It's the only one that clearly reduces harm, and it fits your rule that own resources and ordinary alternatives come first.
- **Decide:** whether help should be limited at all, and if so at what share. 0.5 costs lives. A trace and a second share (for example 0.75) would show the tradeoff.
- **Optional:** the 30-day rule is harmless and fairer at month ends, but it's not needed for results.
- Nothing here is adopted or merged.
