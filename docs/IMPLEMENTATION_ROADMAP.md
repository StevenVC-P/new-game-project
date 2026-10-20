# Implementation Roadmap

Ordered milestones from the current code (a founded hamlet) to the **first playable village**, drawn from the build orders in the design models (2026-10-19). Blocking owner decisions R1-R6 are resolved (see end).

Design sources: `docs/GAME_VISION.md`, `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md`, `docs/ECONOMY_MODEL.md`, `docs/SIMULATION_SCALE_MODEL.md`, `docs/HOUSES_AND_LINEAGE_MODEL.md`, `docs/CULTURE_AND_VALUES_MODEL.md`, `docs/WARFARE_AND_CONFLICT_MODEL.md`.

## Where The Code Is Today

Working:

- regional map, one inert neutral town, founding-site selection, a founded `Player Town` with 4 seeded households
- local city map with houses, farms, woodcutters, toolmakers, and the stone/brick/tile/carving chain
- households with lifecycle stages, seasonal births, aging child cohorts, new family formation, old-couple completion, work succession, and lineage fields (`parent_household_id`, `origin_household_id`, `generation`, `family_trade`)
- food, shelter, labor, tools, and maintenance pressure; household goods and clothing soft needs
- City Overview pressure rows and Action Hints; F3/F4 debug panels; household inspector
- manual city-to-city trade menu (food, wood, tools); neutral-town trade blocked

Known gaps that block the vision:

- migration adds single people from a pool of 20 that never refills (`SETTLEMENT_GROWTH_SCALE_MODEL.md`, findings 1-2)
- families never leave; shortages only block growth
- values are one placeholder `preference` (agrarian / industrial / neutral)
- new families form from two adult children of the same household; no marriage between lineages
- no defense, bandits, wealth, taxes, or barter

## Working Method

- One milestone = one or more feature branches from `develop`, merged back when done (`AGENTS.md`). Never `main` without review.
- Every milestone adds or updates a validation test in `tests/` and passes `scripts/validate_project.ps1`.
- Every milestone updates the design doc it implements in the same change.
- Formula changes in `city.gd` / `household.gd` are product-design changes: each milestone below names the ones it is authorized to make.

## Milestones

### M0 - Housekeeping

**Objective:** a clean starting point.

- Untracked June 29 files (decision R6: note, then delete):
  - root `main.gd` is an exact copy of the initial-commit `main.gd` (`64a2528`) and remains recoverable from history
  - three `household_settlement_debug_inspector.gd` attempts in `addons/`, `features/`, `ui/` are broken local-agent output (Godot 3 `rect_position`; one does not parse), are unreferenced, and duplicate the existing F3 inspector
  - record them in a short failed-experiment note, then delete all four and their `.uid` files
- Add workspace `CLAUDE.md` and `project.md` pointing at `AGENTS.md`, `ARCHITECTURE.md`, and the design docs.
- Fix the starter newlywed seed whose population (4) disagrees with its family structure (2 adults, no children).

**Done when:** working tree clean; seeds consistent; validation passes.

### M1 - Values Foundation

**Objective:** every family carries culture, and culture already changes outcomes.

- Values data on households: 12 categories, 1-2 values per category, no opposing pairs (`CULTURE_AND_VALUES_MODEL.md`).
- Starter and newly formed households get values; inheritance at family formation.
- **Calling replaces `preference`**: assignment fit, output bonus, satisfaction. Existing agrarian/industrial map to Of the Soil / Of the Forest and Of the Forge and Bench.
- **Work Ethic** modifies output, reliability, and quality hooks.
- **Kin** modifies birth chance and family-formation timing.
- Household inspector shows all values and highlights defining values. Nothing on cards.

**Status: done (2026-10-19).** See Implementation Status in `CULTURE_AND_VALUES_MODEL.md` for what shipped and which hooks are deferred.

**Authorized formula changes:** output modifiers, birth chance, formation timing, assignment fit.
**Done when:** tests show values inherited, calling fit affecting output, kin values affecting births; effects capped per the model.
**Why first:** migration, marriage, ambitions, defense, and policy reactions all read values. Building them first avoids retrofitting migrants and soldiers later.

### M2 - Families Arrive And Leave

**Objective:** growth and decline come from whole families, and hardship has real but recoverable consequences.

**Measured starting point** (`tests/sim/settlement_growth_run.gd`, identical before and after M1): with 40 houses, 6 farms, and 2 woodcutters, the founded town grows from 14 to about 27 people in year 1, falls into permanent food shortage, and shrinks to 3 households by year 9. Causes: migration adds people whenever food is *stored* without checking whether production can sustain them; shortage skips production every other day, locking in the spiral; shortage blocks births while old couples keep passing. M2 must break this spiral.

- Migrants arrive as **whole households** with lifecycle, calling, values, and lineage, driven by settlement attractiveness (food days, housing headroom, soft-need satisfaction, no shortages) and Community values (R2).
- A slowly refilling **regional migrant pool** replaces the fixed pool of 20. Migrants bring values from their place of origin (R2).
- **Departures:** households leave after sustained hardship (food shortage, no shelter), with values shifting the threshold (Rooted, Wanderlust, Charitable, Hopeful).
- Player-facing warnings before a family leaves.
- **Births (R3):** remove the city-wide "population at or above housing capacity" block; only unsheltered families are blocked. Crowded homes lower satisfaction and birth chance and raise departure risk, tuned by Home and Place values. New families still need an empty house.

**Authorized formula changes:** `update_population_from_external_pool`, `add_population_from_external_pool`, growth target selection, `get_birth_blocker_reason` / `get_birth_roll_chance` housing rules; new departure and crowding logic.

**Status: done (2026-10-19).** Implemented in `scripts/domain/household_migration.gd`, run monthly from `City.advance_household_lifecycle_month()`; tested by `tests/household_migration_validation.gd`.

- Arrivals: at most one family per month; requires an empty house and enough worked-farm output to feed the newcomers (the overshoot fix), then rolls against attractiveness (food stored, recent shortage, soft needs, Welcoming vs Clannish share). Newcomers are newlyweds or young families with values drawn from a seeded regional culture. Pool starts at 5 families, refills 1 every 4 months to 8, and departing families return to it.
- Departures: monthly hardship points (shortage of 10+ days: 2; no shelter: 2; overcrowded home: 0-2 by Home and Place values), recovering 1 per good month. Threshold 6, adjusted by values (Rooted +4, Hopeful +2, Fatalistic +2, Close-Knit +1, Wanderlust -2, Leave the Nest -1). At most one family leaves per month, only in a month it is suffering hardship, and hardship is capped just past the threshold so towns recover once a crisis ends.
- Births: only unsheltered families are blocked. Crowding (temporary shelter, or more than 5 people in a house) lowers the chance by 2/5/10 for tolerant/normal/Hearth-Proud families.
- Display: sidebar shows the newcomer status and how many families are thinking of leaving; Action Hints put leaving families first; the selected house shows a hardship warning.
- Fixed a latent bug: new household ids reused `households.size()`, which collided once any household was removed.

**Judgment calls made during implementation (owner may revisit):**

- Temporary shelter counts as crowding for births but not as hardship, so founding families are not driven out while the first houses go up.
- A departing family's workplace stays open to auto-assignment. Workplaces vacated when an old couple passes on still wait for the player's succession choice (existing design), so towns rely on the player answering succession hints.

**Measured result** (`tests/sim/settlement_growth_run.gd`; the run fills succession vacancies monthly as a stand-in player): the founded town grows to 13 families / 58 people by year 4, outgrows its 10 farms, loses 5 families, and settles at 12-15 families / about 40 people with a second generation. A half-year famine in year 6 drops it to 10 families / 29 people; when the farms restart it recovers to 54 people by year 8 with newcomers arriving again, and reaches a third generation by year 10.
**Done when:** a timed headless run shows growth continuing past about 9 households, and a sustained-shortage run shows families leaving and the settlement recovering when the shortage ends.

### M3 - Marriage Between Lineages

**Objective:** families join across lineages, and culture decides how.

- Pairing step between adult children of **different** households.
- Lineage membership set by the Kin lineage rule (Father's / Mother's / Strongest Line; settlement default when absent).
- New household draws values from both parents' households.
- Inspector shows both parent lineages.

**Authorized formula changes:** `advance_new_family_formation_month`, `form_new_family_from_parent`, `spend_adult_children_for_new_family`.

**Status: done (2026-10-19).** Tested by `tests/marriage_lineage_validation.gd`.

- Each month, households with a grown child ready (after any Close-Knit delay) pair with a ready household; siblings never marry each other. Each household marries off at most one child per month; each side gives one grown child.
- Partner choice: most families prefer another lineage; Clannish families prefer their own lineage (but never their own household).
- Lineage: each pairing has a groom's and a bride's side. If both families hold the same lineage rule it applies; otherwise the town's most common rule does (Father's Line if no family holds one). Father's Line follows the groom's side, Mother's Line the bride's, Strongest Line the side whose lineage has more households in town.
- New families record both parent households (`second_parent_household_id`); work succession and descendants count children through either parent; the lineage display names both parents.
- Values are inherited from both parent households.

**Judgment call (owner may revisit):** a grown child with no partner in town marries someone from outside after 6 months. The spouse brings the region's culture, and the family joins the town parent's lineage. Without this, small hamlets could stall with unmarried children. In the sim run this produced 10 outside and 21 in-town marriages over 10 years, and it moves the first home-grown family from about year 3 to year 1, which the M8 pacing pass should consider.
**Done when:** tests show cross-lineage formation, the lineage rule applied, and two-parent value inheritance.

### M4 - Satisfaction And Family Ambitions

**Objective:** families want things, and that pulls the player forward.

- `household-satisfaction-records-v0`: per-household satisfaction snapshots from needs, housing, calling fit, and values.
- `docs/family-ambitions-model`: design pass (what families want, how they signal it, what fulfilling or ignoring it does).
- `family-ambitions-v0`: first ambitions (for example a better home, a workshop for their calling, a home for a child's new family) feeding satisfaction, departures, and attractiveness.

**Done when:** satisfaction visible in the inspector; at least three ambition types appear, resolve, and change outcomes.

### M5 - Defense

**Objective:** the frontier is dangerous, and protecting families matters.

- Soldier families as a household responsibility (Of the Shield), supplied from shared stores.
- Militia call-up that takes families off their work for its duration.
- Bandit raids on stores, with regional danger from the founding site.
- Protection expectations: failed defense lowers trust and raises departure risk; successful defense builds trust.
- Casualties fall on specific households.

**Done when:** raids happen at a rate set by region; defended and undefended outcomes differ visibly; losses appear in the affected families.

### M6 - First Neighbor: Barter

**Objective:** the neutral town becomes a reason to trade, and barter feels real.

- Neutral-town trade enabled as **barter**, with outcomes set by supply and demand on both sides and refusal possible (`ECONOMY_MODEL.md`).
- Local scarcity prices measured in grain, shown where trade decisions are made.
- Neutral town gets a simple Summary-level economy (`SIMULATION_SCALE_MODEL.md`) so its needs and surplus change over time.

**Done when:** trading surplus for a shortage good works; the neutral town refuses or pays little for goods it does not need; prices respond to stock.

### M7 - Household Wealth And Tithes

**Objective:** the two pockets exist, and in-kind taxes feed the settlement.

- Household wealth level (stored-goods wealth) affected by work, needs, and Wealth values (Thrifty, Lavish, Sharing).
- State storehouse and in-kind tithes; tithe rate as the first **policy**, with value reactions shown at the decision.
- Soldier supply drawn from tithes.

**Done when:** tithe changes visibly trade storehouse growth against household wealth and satisfaction; value reactions appear in the decision UI.

### M8 - Village Completion

**Objective:** Hamlet -> Village is a complete, satisfying arc.

- `settlement-stage-status-v0`: stage, progress, and milestone chronicle (`SETTLEMENT_GROWTH_SCALE_MODEL.md`). Stage names and conditions as drafted (R1); events such as surviving a raid are chronicle entries, not requirements. Titles never regress; decline shows as a status (R4).
- `clothing-textile-production-v0`: production answer for the clothing need (Of the Loom).
- Pacing pass against the targets in the growth model (Village around year 3).
- Owner playtest of the first playable village.

**Done when (R5):** in an owner playtest, a settlement reaches Village and holds it stable for about 5-10 game years, including at least one generational turnover (a founding couple passes and their trade is carried on by descendants), and the owner judges it fun.

## Owner Tuning Decisions (2026-10-20)

Made after M3, before the first owner playtest. Tested by `tests/succession_shortage_validation.gd`.

- **Work succession.** When a family passes on or leaves, a direct child's family with spare labor inherits its workplaces immediately, same-trade heirs first, even when a better-suited family exists. With no heir, the workplace waits: the player can fill it at any point, and after 2 months the game fills it (the suggested successor first). Workplaces the player emptied on purpose are never auto-filled. The sidebar hint shows the countdown.
- **Food shortage loss** is 25% (one production day in four is lost), down from 50%.
- **Marrying outside the town** stays, with a culturally set wait: 6 months base, Clannish +12, Insular +6, Welcoming -3, Cosmopolitan -3, minimum 2.

**Balance finding:** one toolmaker (about 1 tool a day) only just covers the upkeep of about 13 buildings. Because heirs now inherit regardless of fit, a poorly suited heir at the toolmaker tipped the 10-year sim into a tool collapse; with two toolmakers the same town stays healthy (15-17 families, a third generation, full famine recovery). Expect to need a second toolmaker as the town grows.

## Future Feature Notes

Ideas recorded for later design, not scheduled:

- **Contested succession.** When more than one party has a claim to control a workplace (rival Houses, competing heirs, or another power), the wait before the game fills it could lengthen, turning succession into a contest the player can influence. Today the wait is a flat 2 months (`City.SUCCESSION_AUTO_FILL_MONTHS`).

## Gate Before Town Scale

Before work on Houses, neighborhoods, coin, armies, or a larger world:

- `chore/household-sim-lookup-tables`: remove the quadratic scans and slow auto-assignment found in `docs/HOUSEHOLD_SIM_BENCHMARK.md`, then re-run the benchmark.
- Keep simulation logic out of `scripts/main.gd` as these milestones add systems (`SIMULATION_SCALE_MODEL.md`, Architecture Guardrails).

Village-scale milestones do not need this gate: the measured daily tick is 2.2 ms at 100 households, so a 30-50 household village stays around 1 ms.

## After The First Playable Village

In rough order, each needing its own planning pass: Houses and the commons (Grouped level); merchant families and routes; foreign coin; patrols and bandit clearing on the map; government and further policies; armies and capture; minting; living neighbors and established powers; world-scale map.

## Owner Decisions

All resolved 2026-10-19 (details in `SETTLEMENT_GROWTH_SCALE_MODEL.md`):

- **R1** (M8): stage names and conditions kept as drafted; raids are chronicle milestones only.
- **R2** (M2): whole-household migration from a slowly refilling regional pool; migrants bring their origin's values.
- **R3** (M2): crowding is pressure, not a birth block; only unsheltered families are blocked.
- **R4** (M8): stage titles never regress; decline shows as a status.
- **R5** (M8): first playable = reach Village and hold it 5-10 game years with a generational turnover.
- **R6** (M0): note, then delete the untracked June 29 files.
