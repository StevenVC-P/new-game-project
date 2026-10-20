# Implementation Roadmap

Ordered milestones from the current code (a founded hamlet) to the **first playable village**, drawn from the build orders in the design models (2026-10-19). Draft for owner review.

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

- Decide the untracked June 29 files (root `main.gd`, three `household_settlement_debug_inspector.gd` copies in `addons/`, `features/`, `ui/`): compare with committed versions, then keep, move, or delete per owner.
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

**Authorized formula changes:** output modifiers, birth chance, formation timing, assignment fit.
**Done when:** tests show values inherited, calling fit affecting output, kin values affecting births; effects capped per the model.
**Why first:** migration, marriage, ambitions, defense, and policy reactions all read values. Building them first avoids retrofitting migrants and soldiers later.

### M2 - Families Arrive And Leave

**Objective:** growth and decline come from whole families, and hardship has real but recoverable consequences.

- Migrants arrive as **whole households** with lifecycle, calling, values, and lineage, driven by settlement attractiveness (food days, housing headroom, soft-need satisfaction, no shortages).
- A slowly refilling **regional migrant pool** replaces the fixed pool of 20.
- **Departures:** households leave after sustained hardship (food shortage, no shelter), with values shifting the threshold (Rooted, Wanderlust, Charitable, Hopeful).
- Player-facing warnings before a family leaves.
- Housing pressure measured in households first (pending owner decision R3 below).

**Authorized formula changes:** `update_population_from_external_pool`, `add_population_from_external_pool`, growth target selection; new departure logic.
**Done when:** a timed headless run shows growth continuing past about 9 households, and a sustained-shortage run shows families leaving and the settlement recovering when the shortage ends.

### M3 - Marriage Between Lineages

**Objective:** families join across lineages, and culture decides how.

- Pairing step between adult children of **different** households.
- Lineage membership set by the Kin lineage rule (Father's / Mother's / Strongest Line; settlement default when absent).
- New household draws values from both parents' households.
- Inspector shows both parent lineages.

**Authorized formula changes:** `advance_new_family_formation_month`, `form_new_family_from_parent`, `spend_adult_children_for_new_family`.
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

- `settlement-stage-status-v0`: stage, progress, and milestone chronicle (`SETTLEMENT_GROWTH_SCALE_MODEL.md`).
- `clothing-textile-production-v0`: production answer for the clothing need (Of the Loom).
- Pacing pass against the targets in the growth model (Village around years 3-10).
- Owner playtest of the first playable village.

**Done when:** owner playtest confirms the first playable target (decision R5).

## Gate Before Town Scale

Before work on Houses, neighborhoods, coin, armies, or a larger world:

- `chore/household-sim-lookup-tables`: remove the quadratic scans and slow auto-assignment found in `docs/HOUSEHOLD_SIM_BENCHMARK.md`, then re-run the benchmark.
- Keep simulation logic out of `scripts/main.gd` as these milestones add systems (`SIMULATION_SCALE_MODEL.md`, Architecture Guardrails).

Village-scale milestones do not need this gate: the measured daily tick is 2.2 ms at 100 households, so a 30-50 household village stays around 1 ms.

## After The First Playable Village

In rough order, each needing its own planning pass: Houses and the commons (Grouped level); merchant families and routes; foreign coin; patrols and bandit clearing on the map; government and further policies; armies and capture; minting; living neighbors and established powers; world-scale map.

## Owner Decisions Needed

Carried over from `SETTLEMENT_GROWTH_SCALE_MODEL.md`, now blocking specific milestones:

- **R1** (M8): are the stage names and exit conditions acceptable (Founding Camp, Hamlet, Village, Early Town)?
- **R2** (M2): confirm migration as whole households with a refilling regional pool. The vision strongly implies yes.
- **R3** (M2): should births be blocked by each family's own housing instead of city-wide population capacity?
- **R4** (M8): do earned stage titles never regress?
- **R5** (M8): is the first playable target to reach Village, or to hold it for a number of years?
- **R6** (M0): what to do with the untracked June 29 files.
