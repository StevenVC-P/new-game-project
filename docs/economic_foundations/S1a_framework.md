# S1a: Test Framework and Baseline B0

## Implementation

- **Objective:** a yardstick for every later sprint, built before any mechanic changes (owner's testing mandate, 2026-11-02).
- **Built** (detail: `docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md` section 9):
  - `City._flows`: every good entering or leaving the store, by cause. Measurement only; not saved.
  - `tests/sim/economy_invariants.gd`: invariants I1, I2, I6, I7 checked daily and monthly; its own test `tests/economy_invariants_validation.gd`.
  - `tests/sim/divergence_check.gd`: five test-side environments over a 240-site pool, the same founder sets on each, family-led play, monthly fingerprints for repeat runs.
  - `scripts/run_tests.ps1`, `scripts/run_divergence.ps1`, `scripts/compare_divergence.ps1`.
- **Files touched in play code** (all to record flows, no behaviour change): `city.gd`, `household_economy.gd`, `town_construction.gd`, `town_defense.gd`, `town_trade.gd`, `trade_route.gd`; test side `stand_in_player.gd` (its hard winter records its own change).
- **Commit:** `e5410ba` on `feature/ef-s1a-framework`.

## Verification

- **No change in play:** `intervention_check` (4 sites, 2 years, ordinary and stressed, players none and informed) gives an identical 6,101-line log, household lifecycle events included, at `fcfc0fc` and at `e5410ba`.
- **Suite:** 47/47 rules tests pass (203 s, four at a time). The gameplay regression is `tests/founded_town_regression.gd`, part of the suite.
- **Invariants in real play:** a trial divergence run (forested, 2 starts, 1 year) kept every good's store equal to its counted flows, every day; no violation.
- **Determinism:** `--repeat` replayed both trial towns with identical monthly fingerprints.
- **Two runner bugs found and fixed while building:** exit codes read as null (every test reported failed until the process handle was taken at start), and the comparison table repeated the median as its range.

## Baseline B0

Run from a fixed worktree at `e5410ba` (`../ngg-ef-runs`): every environment, 12 starts, 6 years, player `none`, ordinary (full tables: `B0_ordinary_y6.md`). The quarry commission (8 starts) and stressed (12 starts) follow. 60 towns, **no invariant violation**: every good's store matched its flows every day.

| Year 6, ordinary | Housed and fed | People (median, range) | Departed | Food shortage days | Outside-food share | Woods left |
|---|---|---|---|---|---|---|
| Fertile valley | 9 / 12 | 51 [0–99] | 3 | 39 | 0.29 | 0.71 |
| Forested | 8 / 12 | 48 [0–94] | 3 | 89 | 0.25 | 0.96 |
| Balanced | 10 / 12 | 34 [0–106] | 3 | 44 | 0.29 | 0.56 |
| Marginal | 7 / 12 | 32 [0–114] | 2 | 223 | 0.33 | 0.36 |
| Rocky highland | 8 / 12 | 26 [0–72] | 4 | 207 | 0.33 | 0.61 |

**What B0 says about today's game:**
- **Land already shapes size and hunger:** fertile and forest towns grow to about 50 people; marginal and rocky towns go hungry five times as many days and stay near 30.
- **Land doesn't shape what villages do.** Every environment holds the same mix of work (farms first, about one woodcutter, one toolmaker, a hunter or fisher where land allows) and only a quarter to a third of families work outside food. The audit's finding (section 7: "no industry is exclusive") is now measured.
- **Woods are already being felled hard** (marginal towns keep 36% of their woods, rocky 61%) while wood output stays the same: the gap S2 closes.
- **Every environment has towns that die out** (range down to 0 people) and towns that thrive, before any player acts: founding is still decided by a few first choices (as `HANDOFF.md` notes).
- **Cost:** a simulated day takes 80–140 ms on average including the stand-in player's searching (the town's own tick wasn't timed separately yet; it is from S2's runs). The worst-day figures above 1 s are the owner's one-hour pause, inside one town each in marginal and balanced.
- The success measure (test plan 10b) was added after B0 started, so B0's tables show 0 / 0 for it; "housed and fed" above is the stand-in's own end-of-run judgment, equivalent at year 6.

**Process note.** For about half an hour a stray earlier runner and the S1b comparison ran beside the baseline, six Godot processes at the peak against the owner's limit of four. Both were stopped; the batch runner now records its own process id so a stop can't miss it. Batches run at three processes, keeping one for tests.

## Next Steps

- Record the B0 tables here; then close S1b against B0-quarry.
- Measured cost: a six-year family-led town takes several minutes once it grows (much more than the one-year trial's 7 s per town-year suggested); comparisons are planned at three processes accordingly.
