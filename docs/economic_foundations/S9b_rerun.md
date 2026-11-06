# S9b: The S9 Comparison After S5b

The S9 review comparison repeated on the build carrying S5b. The pre-fix results stay as they were: `S9_review.md` (build `852fc6a`, logs `test-logs/div/S9-*`).

## Owner's decisions (2026-11-06)

- **S5b accepted** and merged into S6–S9. Nothing goes to develop or main until the reviews are complete.
- **Fertile-valley hunger** after S5b is documented (`S5b_wood_sense.md`), not corrected. Families may make poor economic choices from their values and callings; a correction needs evidence of a defect.
- **Commons reserve:** a protected reserve stays protected in ordinary times. Where the community's access rules allow emergency help, a family in immediate survival danger may draw limited help, once its own accessible goods and ordinary alternatives prove insufficient. The simulation never silently overrides the player's reserve policy; the player controls communal goods, and households own theirs. No new governance system in this sprint.
- **Market value in choosing work:** deferred until an economic valuation system exists. Need, scarcity, anticipated demand, calling, values and opportunity cost stay as they are. S9's scope doesn't grow.
- **Reviewing the rerun:** tell failures caused by the arrangements apart from limits of the current occupation-choice system. Further economic behaviour changes wait for the owner's review.

## Build and runs

- **Build:** `862e84b` (S9 with S5b merged up the chain), run in `../ngg-ef-runs7`.
- **Runs:** as S9's, each 5 lands × 8 starts, ordinary, no player, 6 years. Labels `S9b-communal`, `S9b-shared`, `S9b-private`, `S9b-shared-commons`, `S9b-private-commons` (30-day reserve, grants to families in need).
- **Pooled baseline:** `G` (S5b, pooled).

## The reserve against the owner's principle (proposal, not built)

How it works now (`TownCommons.feed_from_table`):
- The player's setting reads "the table keeps back N days of food for families in danger", so emergency use is the reserve's stated rule, not an override. Families not in danger never draw on it.

Where it differs from the principle:
1. **Order.** A family in danger draws on the reserve before its own larder, before asking neighbours and before selling its goods. The principle puts the reserve after them.
2. **No limit.** A family in danger takes its whole daily need from the reserve, until the reserve is gone.
3. **The danger gate resets monthly.** "In danger" is 5 short days this calendar month, or severe hunger or cold, or considering departure. Short days count only after larder, neighbours and market failed, so the gate does mean alternatives proved insufficient. But a family short since the 20th is turned away on the 1st.

Proposed, for the owner's approval after this review:
- move the reserve after larder, neighbours and market;
- limit a family's daily draw to a survival share of its need;
- count danger over the last 30 days instead of the calendar month.

The player's reserve days and its stated purpose stay the rule. Nothing new is governed.

## Results

Suite on `862e84b`: 57/57. Tables: `S9b_summary_y6.md`. "ok" is the strict measure used in `S9_review.md` (`off_the_ground`). The looser `success` field runs 0–1 higher in the shared arrangements.

Towns ok at year 6, of 8 per land (before S5b → after):

| Arrangement | Balanced | Fertile | Forested | Marginal | Rocky | Total of 40 |
|---|---|---|---|---|---|---|
| Pooled (F → G) | 6 → 6 | 6 → 5 | 4 → 3 | 3 → 2 | 2 → 2 | 21 → 18 |
| Communal | 6 → 6 | 6 → 5 | 3 → 2 | 3 → 2 | 2 → 2 | 20 → 17 |
| Shared | 6 → 5 | 5 → 5 | 5 → 6 | 3 → 2 | 1 → 1 | 20 → 19 |
| Shared + reserve | 4 → 4 | 4 → 4 | 4 → 3 | 3 → 2 | 1 → 1 | 16 → 14 |
| Private | 6 → 3 | 4 → 4 | 3 → 2 | 2 → 0 | 0 → 0 | 15 → 9 |
| Private + reserve | 1 → 0 | 1 → 1 | 1 → 0 | 0 → 0 | 0 → 0 | 3 → 1 |

Totals over the 40 towns at year 6:

| Arrangement | Cold deaths | Fuel-short days | Hunger deaths | Wood in store per town | Woodcutter families |
|---|---|---|---|---|---|
| Pooled | 61 → 43 | 3774 → 3683 | 75 → 89 | 894 → 560 | 38 → 27 |
| Communal | 41 → 39 | 3344 → 3738 | 73 → 78 | 1061 → 553 | 38 → 26 |
| Shared | 26 → 53 | 4491 → 6693 | 64 → 68 | 1627 → 957 | 45 → 34 |
| Private | 25 → 46 | 5900 → 8766 | 42 → 45 | 1886 → 887 | 39 → 19 |

- **Different arrangements still succeed under different circumstances.**
  - Shared is best on forested land: 6 of 8 ok against 3 pooled. Forested founder sets 2, 4, 5 and 7 are empty under pooled and succeed under shared; fertile sets 1 and 4 likewise.
  - Pooled and communal stay the steadiest on balanced and rocky land.
  - No arrangement makes cold or poor land safe.
- **Wood piles shrink under every arrangement**, as S5b intended: a third to a half less in store.
- **Shared and private lost warmth, pooled and communal didn't.** That split led to the experiment below.

## Experiment: wood a family can reach (not built, not committed)

S5b read the town's physical store (`city.resources`), which under a compact includes every family's own share (`TownLedger`). But a hearth burns its own family's wood, then the community's (`TownFuel.burn`). No family can burn a neighbour's wood, and fuel asking isn't modelled. So a woodcutter could see "more wood than the winter needs" while most hearths had no way to reach it. The owner's words were "accessible wood supplies".

Run in the throwaway worktree `../ngg-ef-runs8`, labels `X-reach-private` and `X-reach-shared`. Under a compact, `get_wood_plenty` and `get_cold_hardship` read `TownLedger.get_community(city, "wood")` instead of `city.resources["wood"]`. Pooled towns are unaffected.

| Year 6, of 40 towns | Private: before S5b → S5b → reachable | Shared: before S5b → S5b → reachable |
|---|---|---|
| Towns ok | 15 → 9 → 9 | 20 → 19 → 17 |
| Cold deaths | 25 → 46 → 25 | 26 → 53 → 34 |
| Fuel-short days | 5900 → 8766 → 6979 | 4491 → 6693 → 4960 |
| Hunger deaths | 42 → 45 → 50 | 64 → 68 → 69 |
| Wood in store per town | 1886 → 887 → 1006 | 1627 → 957 → 1233 |

- **The cold harm is S5b's defect under compacts:** it largely goes away when families weigh only wood they can reach.
- **It doesn't explain the fall in towns ok.** Private stays at 9: balanced recovers (3 → 5) while fertile falls (4 → 2). Shared drops two more.
- **Single-town results swing both ways between near-identical builds**, so a change of 1–3 towns ok here isn't strong evidence alone. Private's fall of 6 under both variants is larger than that.
- This is a smoke-level test: private and shared only, no suite run, one community-only definition of "reachable".

## Sorting the failures (owner's question)

**Caused by the economic arrangement, as modelled:**
- Private towns go hungrier, and shared and private run short of fuel more than pooled even before S5b: a family's goods are its own, and that has a price.
- Private + reserve stays the worst arrangement (3 → 1). The reserve gaps above bear on this; they aren't tested here.
- Part of the cold is an unmodelled mechanism, not the arrangement itself: a family can ask neighbours for food but not for fuel. Private towns held about 890 wood each while recording 8766 fuel-short days.

**Caused by S5b reading wood no family can reach:** the rise in cold deaths and fuel-short days under shared and private (experiment above).

**Limits of the occupation-choice system:**
- Under private, woodcutting families halve (39 → 19), and they remain far richer than farm families on paper (about 1,490 against 110 food-worth each). A family weighs what the town needs, not that its wood is its own income. That is the deferred market-value question; it isn't proposed here.
- Woodcutting families remain the hungriest per family (private: about 475 short family-days each against 84), so their wealth still doesn't feed them. Counted over families present at year 6, as in `S9_review.md`.

**Not yet explained:** two private towns lost, where fuel shortage is not the main story.
- Balanced start 5: wood cut 10,687 → 338, woodcutters 2 → 0, short days 713 → 1234, hearths never short.
- Marginal start 0: 82 → 7 people, wood cut 9036 → 420, woodcutters 3 → 0, fuel-short days 21 → 216. Reachable wood doesn't save it either.
- Starting stock isn't the cause: a town starts with 45 wood, below plenty's floor. These need a trace before anyone calls them a defect or a poor choice.
