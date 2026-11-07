# S5d: Reading Wood Plenty Honestly

Further corrections to S5b, found by tracing balanced 5 and marginal 0 (`S5c_reachable_wood.md`). Branch `feature/ef-s5d-wood-margin`, off S5c. Nothing goes to develop or main until the owner has reviewed this.

## Owner's decision (2026-11-06)

Approved without a review of S5c first: all three wood fixes, with the margin left to this sprint to choose and record. No survival tuning. The owner reviews the results afterwards.

## Changes

- **Horizon (`FamilyInitiative.get_wood_need`).** Need now runs through the end of the next winter not yet begun. Once winter starts, the following winter is the one to prepare for, so need never collapses to a few days.
- **Margin (`get_wood_margin`).** Wood counts as spare only beyond need plus a margin: half the need again, and never less than `WOOD_PLENTY_FLOOR` (100).
- **Urgent review (`OccupationReview.WOOD_PLENTY_TRIGGER`, 0.5).** A woodcutter looks again at once only at plenty of 0.5 or more. A little spare still weighs in its yearly look.

### Why this margin

Chosen before any comparison ran, from what a town wants, not from results:
- **Half the need again:** a cushion against a town's need being larger than forecast, since the need reads today's families and today's work. It is a judgment, not a measurement. E13's forecast is what should test it.
- **At least 100 wood:** about a home and a workplace for each of six founding families (6 × (6 + about 8) = 84). This answers the third traced defect: need counts only what is already under way, so a young town's next building isn't in it. It reuses the existing `WOOD_PLENTY_FLOOR` rather than adding a number.
- **Review at 0.5:** halfway to full plenty, so one family's urgent look needs a clear surplus. Also a judgment.

### Left as is

The town-level `get_activity_risk`; plenty's weights; the need's own terms (`get_use`); and the older limit that nothing prompts families to look at their work again once no one cuts wood. A rule test changed deliberately: "the same store is spare with only the winter's end left" described the defect and now asserts the opposite.

## Results

Build `044e567`, run in `../ngg-ef-runs7`. Labels `S5d-pooled`, `-communal`, `-shared`, `-private`, `-shared-commons`, `-private-commons`; 5 lands × 8 starts, ordinary, no player, 6 years. Suite: 57/57. Tables: `S5d_summary_y6.md`. "ok" is `off_the_ground`. Compared with the build before S5b, then S5b, S5c and S5d.

| Year 6, towns ok of 40 | Before S5b | S5b | S5c | S5d | S5d by land: balanced, fertile, forested, marginal, rocky |
|---|---|---|---|---|---|
| Pooled | 21 | 18 | 18 | 20 | 6 4 4 4 2 |
| Communal | 20 | 17 | 18 | 19 | 6 4 4 3 2 |
| Shared | 20 | 19 | 22 | 24 | 6 7 6 4 1 |
| Shared + reserve | 16 | 14 | 15 | 18 | 5 5 4 3 1 |
| Private | 15 | 9 | 9 | 12 | 5 4 3 0 0 |
| Private + reserve | 3 | 1 | 7 | 4 | 0 3 1 0 0 |

| Year 6, over 40 towns | Cold deaths (before → S5b → S5c → S5d) | Fuel-short days | Hunger deaths | Wood per town |
|---|---|---|---|---|
| Pooled | 61 → 43 → 43 → 60 | 3774 → 3683 → 3683 → 3514 | 75 → 89 → 89 → 75 | 894 → 560 → 560 → 666 |
| Communal | 41 → 39 → 38 → 41 | 3344 → 3738 → 3815 → 3414 | 73 → 78 → 76 → 70 | 1061 → 553 → 531 → 728 |
| Shared | 26 → 53 → 46 → 21 | 4491 → 6693 → 6293 → 4359 | 64 → 68 → 72 → 60 | 1627 → 957 → 1120 → 1404 |
| Shared + reserve | 43 → 58 → 35 → 35 | 5795 → 7181 → 6078 → 5017 | 63 → 48 → 63 → 67 | 1384 → 877 → 922 → 1170 |
| Private | 25 → 46 → 34 → 26 | 5900 → 8766 → 7756 → 6698 | 42 → 45 → 45 → 42 | 1886 → 887 → 832 → 1083 |
| Private + reserve | 29 → 43 → 34 → 33 | 6598 → 9118 → 8054 → 7242 | 34 → 41 → 40 → 31 | 2113 → 1115 → 1385 → 1500 |

- **The harm S5b added under compacts is largely gone.** Shared and private are back near their pre-S5b cold deaths and hunger deaths, and fuel-short days fall.
- **The oversupply S5b set out to reduce stays reduced.** Wood in store per town stays 18–43% below the pre-S5b build under every arrangement.
- **Private doesn't fully recover:** 12 towns ok against 15 before S5b, with more fuel-short days. Shared is now above its earlier 20.
- **Pooled cold deaths return to 60.** That is one town: balanced 2, a 59-person town that outgrew its wood, identical to the pre-S5b build. S5b's lower figure was that town's chance, not a lasting gain.
- **Private + reserve falls 7 → 4,** five towns down and one up. It stays the worst arrangement, and swings of this size between near-identical builds aren't strong evidence alone.

### The traced towns, private

| Town | Before S5b | S5b | S5c | S5d |
|---|---|---|---|---|
| Balanced 5: ok, people, wood cut | yes, 29, 10,687 | no, 28, 338 | no, 27, 239 | **yes, 21, 2,813** |
| Marginal 0: ok, people, wood cut | yes, 82, 9,036 | no, 7, 420 | no, 18, 816 | no, 13, 663 |

- **Balanced 5 recovers:** wood is cut from the start and tools hold.
- **Marginal 0 stays lost, and it isn't the wood reading this time.** The false plenty readings are gone: the town's first woodcutter stays, and wood is cut until it leaves or dies. Then its wood passes to the community, 344 wood reads 0.94 plenty against a small town's need, and no one cuts for years. Tools reach 0 by year 2 after the toolmaker turned to farming on day 180. That reading is honest: the wood is there. The older limit stands behind it: nothing prompts a family to take up tools or wood again in a town without them. Not corrected.
- Before S5b this town's success came with 9,036 wood cut, so its 82 people partly rested on the oversupply S5b was built to remove.

## For the owner

- **Decide:** whether to keep S5d, and whether the margin's half and 100 stand.
- **Still open:** the older occupation-choice limit (above) is the clearest remaining cause of lost private towns. Market value in work stays deferred.
