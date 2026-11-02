# Economic Foundations: Test Plan

**Status: in force (2026-11-02); framework built in S1a. Items not yet built are marked by the sprint that adds them.** This is the standing test and validation plan for `docs/ECONOMIC_FOUNDATIONS_ROADMAP.md`, from the owner's "Testing and Validation Mandate" (2026-11-02). It changes with the roadmap: when a sprint adds a mechanic, add its tests, invariants and metrics here in the same change.

**Rule zero:** a sprint is not done because it compiles or its unit tests pass. It is done when the evidence below shows that it does what it should, breaks nothing that worked, and changes the simulation in ways that can be explained.

## 1. What Exists and Is Reused

All commands are in `docs/TESTING.md`. Tests extend `SceneTree` and exit non-zero on failure; balance checks print tagged lines (`[OCC]`, `[WIS]`…) and are written to a file, never piped.

| Kind | Exists | Use in this initiative |
|---|---|---|
| Import gate | `scripts/validate_project.ps1` | Before every commit |
| Rules tests (46 scripts in `tests/`) | `shared_land_validation`, `town_woodland_validation`, `hunting_grounds_validation`, `household_economy_validation`, `town_construction_validation`, `building_tiers_validation`, `expanded_goods_production_validation` (a `RefCounted`, run through a wrapper), `geography_validation`, `trade_validation`, `save_game_validation`, `founded_town_regression`, `family_initiative_validation`, `occupation_review_validation`… | Level 1 and 2. Extend the relevant one rather than add a parallel file. |
| Gameplay regression | `tests/sim/occupation_check.gd` (seed 20261102 must come through its year; 20261101 must fail for hunger; a mid-decline save plays on identically) | Level 2, every sprint |
| Real sites | `TownBuildingCheck.collect_sites` (deterministic regions and sites on generated worlds) | Site pool for Level 3 |
| Land classification | `tests/sim/site_variety_check.gd` (`land_kinds`: shares of water, woods, rock, farmland) | Basis for the environment classifier |
| Family-led towns over years | `tests/sim/wisdom_check.gd`, `intervention_check.gd` (6 years with a year-3 snapshot, `--conditions=ordinary/stressed/difficult`, `--disrupt=`, `--meta=` switches, `--seed=N --trace`) | The engine for Level 3: one 6-year run gives both the 3- and 6-year results |
| Player stand-in | `tests/sim/stand_in_player.gd` (acts only through real controls) | Player policies in comparisons |
| Longer runs | `tests/sim/settlement_growth_run.gd` | Level 4, after a check of how far it runs reliably |
| Performance | `tests/benchmarks/household_sim_benchmark.gd`, `docs/HOUSEHOLD_SIM_BENCHMARK.md` (2.2 ms daily tick at 100 households) | Baseline and per-milestone re-runs |
| Map checks | `map_luck_check`, `town_map_probe`, regional fingerprint tests | Re-run whenever town map generation changes (S5) |

**Gaps this plan fills** (built in sprint S1a; see section 9):
1. No script runs the whole suite and records which tests passed.
2. No check reports economic flows: what was made, used, spoiled, stored, per good.
3. No automatic invariant checking during long runs.
4. **Founders depend on the town's tile** (`City` seeds them from `hash([founding_seed, tile, "founders"])`), so the same families can't yet be put on different land.
5. No environment grouping for family-led multi-year runs; no reproducibility check that runs a town twice.

## 2. The Four Levels

| Level | What | When | Typical cost |
|---|---|---|---|
| **1. Mechanic** | One rule in isolation on a small built town (the style of `shared_land_validation`) | While implementing; on every change to that system | Seconds |
| **2. Integration and regression** | The full suite, the gameplay regression, save/load, and the integration cases in section 5 | Before a sprint is called done | About 10–20 minutes |
| **3. Comparative** | The divergence check: environments × starts, mechanic on and off, 6 years with a year-3 snapshot | Every sprint that changes the economy | Hours (parallel processes) |
| **4. Stability** | 10–20 years on a smaller sample; equilibrium, exhaustion, performance drift | At review points (◆ in the roadmap), not after small changes | Hours |

## 3. Scenarios

### 3.1 Environments

Categories for **grouping results only**. The game never learns these labels, and nothing in play reads them (mandate §7).

Rules as built in S1a (`divergence_check.gd classify`), applied in this order (rarest first), each site in the first that fits. Shares are of all town-map tiles; "pool p" is that share's p-quantile over the whole pool.

| Environment | Classified by (town map, test side) | Expected pressure | Pool sites |
|---|---|---|---|
| Rocky highland | Rough ground ≥ pool 0.75, some stone deposit, farmland ≤ pool 0.5 | Food insecurity, extraction | 24 |
| Fertile valley | Farmland ≥ pool 2/3 | Agricultural growth | 80 |
| Forested | Woods ≥ pool 2/3 | Forestry | 47 |
| Marginal | Farmland ≤ pool 1/3, woods ≤ pool 0.5, water ≤ pool 0.5 | Hard survival | 52 |
| Balanced | Farmland > pool 1/3, and woods > pool 1/3 or some water or stone | Flexibility | 17 |

- **Site pool:** `collect_sites(60, 4)` on the authored test world (the same source as the other checks), duplicates removed: 240 sites, 20 fitting no group. Each group is taken a region at a time, so every environment's first 12 starts come from 12 different regions. `--survey` prints the pool, its classes and each site's land.
- **Many marginal sites are cold** (the White Shelf regions: farmland at the generator's floor, thin woods).

### 3.2 Starts

- **12 starts per environment.** Start *k* in every environment uses **founder set *k*** (the same families, values and callings), so differences between environments come from the land (mandate §3).
- The rest of the town's randomness still follows its founding seed, as today; that's why the comparison is over 12 starts and not one.
- **How:** founder set *k* is what a reference town (tile 0,0, seed 77000 + *k*) is founded with, copied into each site's town before its first day (`divergence_check.gd make_founders`). `City` rolls founders from the town's tile, so copying in the check avoids touching `city.gd`.

### 3.3 Conditions and policies

- **Ordinary** (the town as founded) and **stressed** (the stand-in's existing hard first winter: the food store cut to 8 days on day 270, as the other checks' "stressed" condition). From S3, a fuel disruption joins it.
- **Player:** `none` (never intervenes) is the yardstick; `guided` uses the stand-in's existing `guide()` (stores kept for the priorities, asks for what is short). Contrasting players for the review between sprints (section 10b): `attentive` (answers warning cards with their appeals), `investment_first` (investment priority from founding, kept), `overprotect` (keeps every wood from the first week). None orders a family. `--commission=type@day` adds a player commissioning one workplace on the spot with the most of its deposit underfoot (S1b: a quarry at the start of year 2), since families can't yet choose stone and craft work.
- **Values profiles** (mandate §8, from S4): the same land with founders' values pushed toward one side (communal vs independent, thrifty vs quality-seeking, traditional vs open), then the same under the stressed condition to confirm survival wins.

### 3.4 Horizons

One 6-year run per town with a year-3 snapshot. Level 4: 10 and 20 years on 4 starts per environment.

## 4. Correctness Invariants

Hard requirements (mandate §3). A failing invariant stops the affected work until fixed (section 8).

**Checked every simulated day by the invariant checker** in Level 3 and 4 runs (cheap; it reads what exists):

| ID | Invariant | From |
|---|---|---|
| I1 | No good in any inventory is negative | now |
| I2 | **Conservation per good:** stock change = made − used − spoiled − built with − traded away + traded in, to the unit carried (`Building.output_carry` remainders allowed) | S1a (flow counters) |
| I3 | Output that needs inputs never exceeds what the inputs allowed, and those inputs left the store | now |
| I4 | Extraction never takes more than the deposit or stock holds; a finite deposit never grows | S1b |
| I5 | A renewable stock stays within [0, its capacity] and regrows only by its rule | S2, S13 |
| I6 | **Shared reach:** each tile's shares among workplaces of one kind sum to at most 1; empty, abandoned and idle workplaces take none; a neutral-worked one does (the fixed bugs must stay fixed) | now (`shared_land_validation` cases), daily from S1a |
| I7 | Materials delivered to a building equal its cost; the protected reserve is never spent by families | now |
| I8 | Fuel burned ≤ fuel held; no household heats from wood it doesn't have access to | S3 |
| I14 | Member counts never go negative and sum to the household's population; a death has a recorded cause and follows the cause's sustained conditions (never a single short day) | S3b |

**Added with ownership and trade** (S6–S9), as stated in the mandate:
- I9: household shares plus the community's goods equal the physical store; no good belongs to two owners or is eaten twice.
- I10: a contribution of *p*% on *q* units sends exactly *p*·*q* to the community and the rest to the household (only modelled losses or evasion excepted). No subsistence exemption.
- I11: redistribution removes from the community's goods what it gives.
- I12: a trade moves ownership and nothing else; total goods are unchanged by trading.
- I13: holdings survive save and load exactly.

**Behaviour invariants** (checked in Level 2 scenarios and traced in Level 3):
- **Survival first:** when food or fuel runs short, or a family's work fails, its land is lost, the commons can't help or a trade fails, the family responds (changes or adds work, gathers, asks for help, leaves) within a bounded time if any means exists. Values may change *which* response; they never prevent one. A family not choosing the economic optimum is fine.
- **Fatal hardship (S3b):** every death is traced back to sustained severe conditions, and the trace shows what the family tried. A death where a response was available but untried is a survival-first defect; a death where none was available is intended hardship. No rule prevents a death that the conditions make likely.
- **Player authority:** no new automation changes a player control (priority, stores rule, kept woods, land set aside, commissions, later contribution and redistribution rules). A test sets each control, runs the new system, and checks the control still holds.
- **Determinism:** the same seeds give the same town, day for day (fingerprint of stores, households and buildings each month), on a repeated run and after save and load.

## 5. Integration Cases (Level 2)

Per sprint, alongside the full suite:

| Sprint | Must hold with existing systems |
|---|---|
| S1 Quarries | The quarry rule works with land set aside, kept woods, plots and paths; rough tiles open to quarries only; route grid stays correct; old saves with a quarry off stone load and keep working |
| S2 Forests | Felling lowers hunting yield as before; shared woods (I6) unchanged; kept woods binding; woods spreading and paths holding land unchanged; families judge woodcutting land correctly |
| S3b Fatal hardship | Member counts and the lifecycle path stay consistent when a member or a household dies; succession and the freed house behave as for old couples; deaths appear in the chronicle |
| S3 Firewood | Heating and eating draw on separate stores without double use; a family short of both chooses by survival; gathering for the hearth doesn't starve construction silently (it is reported); the first winter of a viable seed is still survivable |
| S4 Materials | Families' homes on plots choose a viable material; the player's communal buildings keep the player's choice; the one pipeline still never deadlocks at tier 0; stone shortage delays, never freezes, a queue |
| S5 Clay and lime | Brickworks and kilns refuse sites without clay or limestone; the downstream goods have consumers; `map_luck_check` and `town_map_probe` re-run; regional fingerprints unchanged |

## 6. Metrics

Reported per environment as **towns surviving (of 12), median, range, and named outliers** (seed and why), at years 3 and 6. Only metrics the game supports; those that arrive with a sprint are marked.

| Category | Metrics | From |
|---|---|---|
| Survival | Towns alive and off the ground, people, households, deaths (by cause from S3b), departures, hunger days | now |
| Resources | Woods tiles, deposit units left; starting vs remaining; regrowth per year | S1b, S2; fish and game S13 |
| Production | Per good: made, used, stored, (spoiled S10) | S1a |
| Food security | Days of food in store, larder totals, shortage days, first-year shortage | now |
| Fuel | Fuel days in store each winter, cold days, households short | S3 |
| Labour | Holdings per trade, worked days, output per worker by trade | now / S1a |
| Construction | Buildings finished, materials used, time from plan to finish, stalled projects; buildings by material | now / S4 |
| Specialisation | Share of households outside food work; spread across trades (an index) | S1a |
| Household economy | Private production, contributions, communal receipts, trades | S6–S9 |
| Culture | Value drift, norms, trust, disputes (existing social measures) | now (read only) |
| Performance | Daily tick mean and worst, ms per simulated year, static memory at start and end | S1a |

Raw logs stay out of the repository; a sprint report keeps the summary tables, seeds and commands.

## 7. Interpreting Results

From mandate §6. **Unequal outcomes between environments are expected, not failures.** For each notable difference the report says which of these it is:

- **Intended:** follows from legitimate mechanics (less farmland, fewer people; heavy felling, less wood; no fuel, a hard winter), and families responded sensibly.
- **Defect:** an invariant fails; a family ignores an available means of survival; output without input; a dependency that can never be met; double-counted land; a loaded game diverging; numbers going unstable (oscillation, runaway, NaN).
- **Unclear:** investigated with switches (the mechanic off, one part off) and a traced town (`--seed=N --trace`) until it is one of the two.

No compensation for hard sites: no hidden bonuses, supplies or survival protections. Defects are fixed; intended hardship is reported.

**Emergent, not scripted:** a test confirms no production rule reads an environment label, and that a group's specialisation comes from families choosing it.

## 8. Stopping Rules

From mandate §12. Stop advancing the affected work, fix or report, when:
- an invariant in section 4 fails;
- household behaviour is seriously broken (survival-first fails, autonomy lost);
- a regression can't be explained or safely fixed;
- a fix would conflict with the design principles, or needs an unapproved architectural change.

A difficult environment doing badly is not a reason to stop. Non-critical balance surprises are investigated, documented and carried as findings.

## 9. Framework Work (sprint S1a)

Built in S1a, before S1b's mechanic, so the baseline exists first. Each item extends what exists.

1. **Suite runner** `scripts/run_tests.ps1`: every `tests/*.gd` that extends `SceneTree` (the `RefCounted` expanded-goods test runs through `tests/expanded_goods_production_run.gd`), four at a time, with a timeout; one line per script to a summary file. Reruns the known-flaky `world_map_flow_validation` once before it counts as failed. `-Filter shared_land*` runs a subset.
2. **Flow counters:** `City._flows` (good → cause → signed amount), recorded where goods enter or leave the store: `made`, `used` (inputs), `need_<bucket>` (eaten, worn, used), `upkeep`, `built` (carried to sites; returned on cancel), `gathered`, `traded`, `raided`, `disrupted` (a check's own shocks). Measurement only: nothing in play reads them, and the leading underscore keeps them out of saves.
3. **Invariant checker** `tests/sim/economy_invariants.gd`: I1, I2, I6 and I7 from section 4, called by any check each day and month; collects violations with day, town seed and detail. Its own rules test: `tests/economy_invariants_validation.gd`.
4. **Founder sets:** copied from a reference town in the check (section 3.2).
5. **The divergence check** `tests/sim/divergence_check.gd`: reuses `collect_sites`, the stand-in player and the family-led setup of `intervention_check` (`BASE`, the starting residential land). Options: `--survey`, `--environments=`, `--starts=N`, `--from=K`, `--years=N`, `--conditions=`, `--policies=`, `--meta=`, `--commission=type@day`, `--repeat`, `--seed=N`. Prints `[DIV]` lines (TOWN per town and snapshot as JSON, SUM per group, INV, REPEAT).
6. **Baseline B0:** the divergence check on S1a's code, which plays exactly as `develop` at `fcfc0fc` (shown below), every environment, 12 starts, 6 years, ordinary and stressed; plus the quarry commission; plus the benchmark. Recorded in the S1a report.

**S1a changes no play.** `intervention_check` (4 sites, 2 years, ordinary and stressed, players none and informed) gives the same 6,101-line log, household lifecycle events included, at `fcfc0fc` and on S1a.

**Tools:** `scripts/run_divergence.ps1 -Label X` (a batch of divergence runs, four processes at most, waiting while free memory is under 3 GB; logs in `test-logs/div/X/`, with the commit in `run.txt`), `scripts/compare_divergence.ps1 -Base X -New Y` (markdown tables, median [min-max] per environment). `test-logs/` is ignored by git; reports keep the tables.

**Runtime and adjustments.** Measured in S1a: a family-led town costs about 7 s of wall time per simulated year in the divergence check, invariants included, so 12 towns over 6 years take about 8–9 minutes per process (the older checks quoted 20–60 minutes for 12 towns). A full comparison (5 environments × 12 starts, on and off) is about 10 such runs: run them from fixed-commit `git worktree`s (`HANDOFF.md`), **at most four Godot processes at once** (owner, Q2), checking free memory and load before starting more and dropping concurrency if the machine struggles. Starts may drop to 8 for on/off sprint comparisons; baselines and review points keep 12; any reduction is written in the sprint report.

**Interface changes** (Q4) are verified by `town_sidebar_validation`, `founding_ui_validation` where the survey changes, and the windowed screenshot captures in `tests/visual/`.

## 10. Sprint Acceptance

Every sprint meets the **Definition of Done** (mandate §10): mechanic implemented; its Level 1 tests pass; the full suite passes, or each pre-existing failure is shown to fail on the base too; integration cases verified; comparative runs when the economy changes; surprises investigated; performance considered; docs updated; committed; roadmap updated.

| Sprint | Must demonstrate |
|---|---|
| S1a Framework | Runner, counters, invariants, founder sets and divergence check work; baseline B0 recorded; a repeated run is identical |
| S1b Quarries | Placement needs stone; grade changes output; nothing extracts from no deposit; exhaustion ends output; stone output differs by environment; same seeds reproduce |
| S2 Forests | Felling reduces standing timber; sustained over-cutting creates scarcity; regrowth under its conditions; different forests support different output; hunting and shared woods unchanged. Includes a sustainable vs unsustainable cutting scenario (a woodcutter count or kept-woods policy held fixed) |
| S3 Firewood | Demand follows season, climate and household size; wood is truly burned; families respond to shortage; fuel competes with building and tools; timber-poor sites pay for it. Winter survival and fuel days reported |
| S3b Fatal hardship | A town with no fuel or food and no way out loses members after sustained weeks, not days; housing and season change the risk; deaths stop when conditions lift; heirs and houses handled by the existing lifecycle; saves keep the counts |
| S4 Materials | Materials consumed correctly; availability changes choices; families pick viable materials for their homes; the player's choice holds for communal buildings; stone and timber differ in cost, labour, durability, upkeep and heating. Run where each material is abundant and scarce, and with the values profiles |
| S5 Clay and lime | Brickworks need clay, kilns limestone; deposits cap output; the products have consumers; opportunities differ by geography |
| S6–S9 | The ownership and trade invariants I9–I13; contribution policies compared; reserves and redistribution in shortage; barter; families choosing among own work, commons and trade; survival-driven change; culture's response. Tests written with the sprint, never results imagined ahead of it |

## 10b. Review Between Sprints (owner, 2026-11-02)

Before the next sprint starts, the last one gets a review. It goes in that sprint's report and can reorder the backlog.

1. **Complexity holds.** Daily tick cost (`day_ms`, median and worst) against the previous sprint and B0; any invariant violation; new state fields and the high-risk files touched; whether the new mechanic's effects can be read from the game (its warnings, panel lines) and from the families' stated reasons. A sprint that makes the town's behaviour harder to explain is a finding, not a pass.
2. **Villages diverge by land.** Per environment, the spread of people, trades held, goods made and shortages, against the previous sprint: the environments should move further apart, or stay apart, for reasons the mechanics explain.
3. **Player choices make and break villages.** The same land and founders under contrasting players: `none`, `attentive`, `investment_first` and `overprotect` (section 3.3 and `divergence_check.gd act_as_player`).
   - **Success:** at year 6 the town is alive, has kept at least its founding families, and is off the ground (housed, fed, no families lost).
   - **Failure:** fewer families than it was founded with, or not off the ground.

   Expected: on every environment some player does clearly better than another, and no player wins everywhere or fails everywhere. If choices stop mattering (every policy within a town or two of the others), or one policy dominates, that is reported as a design finding for the owner, not tuned in passing.
4. **Cost.** The review runs 6 starts per environment and policy over 6 years (5 × 3 × 6 = 90 towns besides the sprint's own `none` runs), about 2–3 hours on three processes. The sample size is a documented reduction from 12 (section 9).

## 11. Sprint Reports

One file per sprint in `docs/economic_foundations/`, named `S1a_framework.md` and so on, in this order:

- **Implementation:** objective, what was built, files and systems changed, commits.
- **Verification:** tests run and results, scenarios, seeds and commands, performance.
- **Economic outcomes:** change from the previous baseline and from B0, differences between environments, surprises, intended vs suspected defects.
- **Next steps:** open issues, backlog changes and why, the recommended next sprint.

The roadmap's tracking table links each report.

## 12. Known Limitations

- Environments are test-side groupings of real generated sites; some kinds may be rare, so samples can be uneven (recorded per run).
- Same founders still meet different daily randomness, which is seeded by the town; 12 starts per group absorb it.
- `world_map_flow_validation` is flaky (wheel-zoom drift, about 2 in 8 on a busy machine).
- 10–20-year runs are untested at this point; how far `settlement_growth_run` and the family-led checks run reliably is checked in S1a before Level 4 is relied on.
- Performance figures come from a fast desktop CPU; integrated graphics and slower machines are untested.
- Culture metrics can be read, but few economic systems move values yet; culture-response tests become meaningful from S4 and S7.

## Log

- 2026-11-02: plan written from the owner's testing mandate. Nothing built.
- 2026-11-02: owner's working terms: four processes at most, mortality (I14, S3b), interface verification.
- 2026-11-02: owner: a review between sprints (section 10b) of complexity, divergence by land, and success and failure from player choices; contrasting players added to the divergence check. Batches run at three processes, keeping the fourth for tests.
