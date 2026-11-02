# Economic Foundations and Geographic Diversity: Roadmap

**Status: plan only (2026-11-02). Nothing is built, and no sprint is authorized.** Branch `docs/economic-foundations-roadmap`, from `develop` at `fcfc0fc`. This is the living backlog for the initiative: update the tracking table after every sprint, and reorder freely when a sprint's results say so.

**Sources.** The owner's brief "Economic Foundations and Geographic Diversity" (2026-11-02; summarised below), `docs/GAME_VISION.md` (wins on conflict), the baseline `docs/RESOURCE_AND_PRODUCTION_AUDIT.md` (on `develop` since `ebb632d`), `docs/ECONOMY_MODEL.md`, and the unmerged `docs/PROPERTY_AND_COMMUNAL_RESOURCES.md` on branch `docs/property-and-communal-resources`. Where this roadmap and the code disagree about what exists, the code wins.

## The Brief in Brief

**The goal:** two settlements founded by similar families in different environments develop differently: one agricultural, one forestry, one mining and dependent on outside food. Their houses come to show local materials, their families take different work and depend on each other differently, and their values shape how they use what they have.

**Principles the plan must keep (non-negotiable):**
1. **Player decisions are sacred.** No silent removal or override of a player control. Society answers through outcomes (output, scarcity, satisfaction, migration, evasion, loyalty), never by blocking the choice.
2. **Household autonomy.** Families choose their work, workplaces, homes, investments, consumption, trade and reserves. The player sets communal matters: land use, infrastructure, public works, the commons' rules.
3. **Survival comes first.** Values shape *how* a family survives, never *whether* it tries. Families may misjudge or act late; they never knowingly ignore an available means of survival.
4. **Culture and economics shape each other,** as tendencies, not scripts.
5. **Geography matters.** Don't normalise sites to equal survival.
6. **Complexity through relationships,** not catalogues. No good, industry or variant without an economic purpose.

**Fixed by the brief:** contributions are player-set percentages **per resource category, of total production** (no subsistence exemption, no family approval); collection and redistribution are separate player decisions; households obtain goods three ways (own production, the commons, trade with each other); no conventional tech tree; no currency yet; single village for now, with aggregation possible later but not built.

## 1. Starting Point

The audit (sections 2–9) is the baseline. Seven findings set the order of work:

| # | Finding (audit section) | Consequence for the plan |
|---|---|---|
| F1 | Stone and iron deposits are drawn but do nothing; the quarry stands anywhere (§2, §7) | The cheapest real geographic advantage. The access rule was decided 2026-10-25 and never built. |
| F2 | Timber is effectively unlimited: output doesn't fall as trees go (§2) | Directly contradicts the brief. Forests can't shape a town until they can run out. |
| F3 | Materials aren't scarce after year one (5,000–9,000 wood; `COMMUNITY_PRIORITIES.md`), and there's no spoilage or storage limit (§3) | Property, contributions and trade will mean little until scarcity exists. **Geography and sinks come before property.** |
| F4 | Masonry and paving stones have no use; bricks need no clay; clothing has no producer (§5) | Dead ends to rewire before new chains are added. |
| F5 | One `food`; no seasons beyond flat yield multipliers; no stocks for fish, game or pasture (§2, §3) | Agriculture and animals need a decision on food kinds first (D3). |
| F6 | Stone and craft workshops are player-built and player-staffed (§4) | Conflicts with household autonomy; families must be able to take these trades up. |
| F7 | Everything is one town-wide store; primary output is a 100% contribution in effect (§3, property doc C1) | The ownership ledger is the foundation for contributions and household trade. |

**Doc discrepancies to fix along the way** (each in the sprint that touches the doc): `HOUSEHOLD_SELF_SUFFICIENCY.md`'s "Not merged" header; `ECONOMY_MODEL.md` decision 4 (hamlet assignment, superseded by families leading) and its "no individual transactions between households" (D2); `IMPLEMENTATION_ROADMAP.md` M7 (superseded if D1 is agreed); `GAME_VISION.md` and `FIRST_STAGE_LOOP.md` not yet reconciled with family-led play; the property doc's §4.3 founding compact (superseded by the brief, D1).

## 2. Decisions Needed Before Sprint 1

The brief allows routine design choices to be made in sprint; these are larger, or conflict with an earlier agreed plan. Recommendations first.

- **D1. The brief replaces the property doc's founding compact.** That doc (§4.3) has each family set its own share and the player set none early. The brief says the player sets a percentage per category, of total production, without approval. *Recommend:* adopt the brief; keep the property doc's ledger (P1), building rights (P2), commitments (Phase 3) and market day (Phase 4) as the mechanism. The founding default is **100% contribution, open redistribution**, which is today's game exactly, so nothing changes until the player changes it.
- **D2. Trade between households.** `ECONOMY_MODEL.md` rules out individual transactions between households. *Recommend:* relax it to a monthly market day cleared in aggregate (property doc P4): barter priced in grain from the town's own scarcity, no credit, no debts.
- **D3. Food kinds.** *Recommend:* one food **need** satisfied by several stored **goods** (grain, legumes, vegetables, fish, meat, dairy), each with its own season, storage and spoilage, using the need-bucket helper that already maps goods to needs. Diet variety is a later soft need. Old saves' `food` loads as a generic, slow-spoiling provisions good.
- **D4. Living stocks.** *Recommend:* timber is finite per tile and regrows over years; fish and game are regenerating stocks per site (one number each, not per animal), shared among workplaces as now; pasture can be grazed down. Shared reach stays exactly as it is; stocks add time.
- **D5. Winter fuel (gates S3).** A new need: households burn firewood in the cold months, and a shortage costs workdays and adds to the family's hardship, like hunger but milder. It is the main wood sink and ties forests to survival. *Recommend:* yes, with climate setting the length of the cold season.
- **D6. Families take up stone and craft trades.** *Recommend:* yes, through hand-work stages (stone gathering on a deposit, a clay pit, a home loom), the same path as the six trades families choose today. The player keeps building proper workshops.
- **D7. Branch and merge route for the initiative.** The brief authorises successive sprints without approval each time; `AGENTS.md` and the standing workflow say nothing reaches `develop` without the owner. *Recommend:* one integration branch `feature/economic-foundations` from `develop`; each sprint on its own branch from it, merged into it when the sprint's gate passes; `develop` only on the owner's word, after a review point (marked ◆ in the table).
- **D8. Balance shifts are expected.** Each sprint will move survival and population figures, and difficult sites will get harder. *Recommend:* the owner accepts that sprints report these changes honestly rather than tune them away; tuning happens only in a sprint that says so, with the cause isolated by a switch first.

## 3. Sequencing

1. **Measure first, in the first sprint, not as a sprint of its own.** S1 extends `tests/sim/site_variety_check.gd` (which already classifies real sites by their land) into a divergence report, runs it on `develop`, then lands the first mechanic.
2. **Make geography bite: Track A (S1–S5).** Stone, finite forests, fuel, materials in construction and grounded clay give sites real advantages, scarcity and sinks, and give settlements their first visible identity. It closes F1–F4 and some of F6, and makes property worth having.
3. **Ownership and exchange: Track B (S6–S9).** The ledger (behaviour-neutral), player-set contributions, redistribution and survival-seeking, and the market day. S6 touches nothing Track A changes in behaviour and may move earlier if convenient.
4. **The land's year: Track C (S10–S14).** Food kinds, seasonal crops, soil, fish and game stocks, livestock and draft animals.
5. **Metal and quality: Track D (S15–S17).** Iron with charcoal, tool tiers, wood species.
6. **Threads through every sprint:** culture ↔ economy (a sprint states which values touch its decisions), autonomy (no new player micromanagement), saves, determinism and the cost of the tick.

**Why not property first,** as `HANDOFF.md` had it planned: with no scarcity beyond the first year, a ledger, a contribution rate and a market move goods nobody lacks (F3). Track A makes those decisions matter. S6 can still go first if the owner prefers.

## 4. Epics

| Epic | Covers (brief part) | Sprints |
|---|---|---|
| E1 Measurement | Evaluation across sites and seeds (9.4) | S1, then every sprint |
| E2 Geology and deposits | Stone, clay, limestone, iron, copper, tin, coal, salt (3) | S1, S5, S15, B-items |
| E3 Forests and timber | Finite timber, regrowth, fuel, species (3) | S2, S3, S17 |
| E4 Construction and settlement identity | Materials in buildings, durability, family choice, appearance (5) | S4, S5 |
| E5 Ownership and the commons | Ledger, contributions, redistribution (6) | S6, S7, S8 |
| E6 Household exchange | Barter, specialisation, dependency (7) | S9 |
| E7 Agriculture | Crops, seasons, soil, storage (3) | S10, S11, S12 |
| E8 Water and wildlife | Fish and game stocks (3) | S13 |
| E9 Animal husbandry | Livestock, feed, draft, manure, dogs (3, 4) | S14, B-items |
| E10 Production and technology | Dead ends, tool tiers, practical capability (4) | S4, S15, S16, B-items |
| E11 Culture ↔ economy | Values in consumption and investment; experience changing values (2.4) | thread; S18 |
| E12 Scale guardrails | Aggregation-friendly data, the tick's cost (8) | thread; S19 |

## 5. Tracking

Status: Planned, Active, Complete, Blocked. Complexity: S (days), M (about a week), L (more). ◆ = review point for the owner (merge to `develop`).

| Sprint | Epic | Status | Depends on | Acceptance (short) | Validation | Commit | Follow-up |
|---|---|---|---|---|---|---|---|
| S0 Roadmap and decisions | — | **Active** (this doc) | — | Owner answers D1–D8 | — | — | — |
| S1 Stone that matters, divergence report | E1, E2 | Planned | S0 | Quarry only on stone; output by deposit grade; stone only where the land has it | Divergence report, baseline vs S1 | — | — |
| S2 Living forests | E3 | Planned | S1 (report) | Woodcutting thins the woods and slows with them; regrowth over years; families weigh woods for woodcutting | Report on forest and sparse sites; hunting coupling | — | — |
| S3 Winter fuel | E3 | Planned | S2, D5 | Households burn firewood in the cold season; shortage has real cost; wood surplus falls | Report; first-winter stress | — | — |
| S4 Materials in construction ◆ | E4, E10 | Planned | S1 | Timber and stone versions of homes and workplaces; families choose; masonry and paving get uses | Report: share of stone buildings by site | — | — |
| S5 Clay and limestone | E2, E4 | Planned | S4 | Brickworks needs clay, lime kiln needs limestone; brick and tile have building uses | Report | — | — |
| S6 Ownership ledger | E5 | Planned | S0 (D1) | Household shares, building funders, treasury view; play unchanged at the default policy | Matched snapshots identical to the base; saves | — | — |
| S7 Contributions by category ◆ | E5 | Planned | S6 | Player sets % per category of total output; families keep the rest | Matched towns at 100/60/30/10% | — | — |
| S8 Redistribution and asking for help | E5, E11 | Planned | S7 | Player's reserve/redistribute rules; families in danger seek the commons and neighbours | Report: deaths and departures where goods existed | — | — |
| S9 Market day ◆ | E6 | Planned | S7, D2 | Monthly barter among families; specialists live by exchange | Report: specialisation and wealth spread | — | — |
| S10 Food kinds and spoilage | E7 | Planned | D3 | Several food goods meet one need; storage and spoilage differ | Saves; matched survival | — | — |
| S11 The farming year | E7 | Planned | S10 | Sowing and harvest seasons, labour peaks, winter stores; 2–3 grains, legumes, vegetables | Report by climate | — | — |
| S12 Soil | E7 | Planned | S11 | Fertility tires and recovers (fallow, manure); suitability by soil and climate | Report over 10 years | — | — |
| S13 Fish and game stocks ◆ | E8 | Planned | S2 | Over-fishing and over-hunting deplete; stocks recover | Report on water and forest sites | — | — |
| S14 Livestock and draft | E9 | Planned | S11, S12 | Sheep, cattle/oxen, pigs, poultry with feed, space and breeding; oxen raise farm output; manure | Report | — | — |
| S15 Iron | E2, E10 | Planned | S2, S3, S9 | Mine on ore, charcoal from woods, smithy; iron tools | Report: iron sites diverge | — | — |
| S16 Tool tiers and quality ◆ | E10, E11 | Planned | S15 | Wood and iron tools differ in cost, life and productivity; families choose by values | Report | — | — |
| S17 Wood species | E3 | Planned | S2, S4 | Species by climate and soil; each has a distinct use (durability, handles, baskets, fuel) | Report | — | — |
| S18 Values from experience | E11 | Planned | S7, S9 | Economic experience moves values (e.g. hunger under hoarding → private holdings) | Report: culture drift by policy | — | — |
| S19 Scale check | E12 | Planned | Track B | Tick cost at 100 households within the benchmark's budget | `HOUSEHOLD_SIM_BENCHMARK.md` | — | — |

**Backlog, not yet sprinted:** copper and tin → bronze (after S16 shows tiers matter); coal; salt preserving meat and fish (after S10); flax → linen and wool → spun cloth, so clothing has a producer (F4); dogs for herding and hunting; horses and transport; water transport; trader wants and offers from the neutral town's own geography, so a mining town can import food; settlement visuals by material beyond S4's first pass; evasion, resentment and departure as answers to contribution policy (only once the mechanics in S7–S9 exist); fruit trees.

## 6. Sprint Cards: Track A

### S1: Stone that matters, and the divergence report (M)

- **Objective:** the first real mineral advantage, and the yardstick every later sprint reports against.
- **Scope:**
  1. Extend `site_variety_check.gd` (or a sibling reusing its site classifier) into a family-led divergence report: real generated sites grouped into archetypes (river or lake valley, forest, rocky highland, open plain, dry), several seeds each, six years. Per archetype: survival, people at years 1/3/6, occupations held, goods made and used, stocks and depletion, departures, and a specialisation measure (share of households outside food work). Run it on `develop` first and keep the numbers in this doc.
  2. The 2026-10-25 access rule: a quarry's footprint must include stone-deposit tiles, which may now be built on by a quarry only. Output scales with the deposit tiles in the footprint and a deposit **grade** read from the town map (a pure function of the tile, so no new randomness).
  3. Deposits are large but finite (a per-tile amount). An exhausted quarry says so and its family reconsiders its work through the existing `OccupationReview`.
  4. The site survey and the placement hint name the stone and its grade.
- **Visible behaviour:** quarries cluster on rock; towns without stone can't quarry (stone only by trade); a good-grade deposit outproduces a poor one.
- **Acceptance:** placement refuses a quarry off stone with a reason; output follows grade; matched towns that never build a quarry are unchanged day for day; old saves load (their maps have the deposits already; an existing quarry off stone keeps working until it closes, so no building vanishes under the player).
- **Tests:** a rules test (placement, output, exhaustion, saves); the divergence report before and after.
- **Risks:** rough tiles currently block placement everywhere; opening them to quarries touches `building_placement.gd` validation and route grid passability. Stone has few uses until S4, so S1 alone barely moves outcomes (the report should show stone appearing only on stone sites, and little else).
- **Autonomy:** quarrying stays player-built in S1; families take it up through a hand-work stage if D6 is agreed (S4).

### S2: Living forests (M–L)

- **Objective:** timber as a finite, regrowing stock (F2).
- **Scope:** a woodcutter's output comes from felling trees within its reach, and its yield falls as nearby woods thin; felled tiles regrow through stages over several years (a stage per tile, no per-tree data) and the yearly spreading continues. Families judge woods in reach for woodcutting as they do for hunting, including shared reach. Gathering by families thins woods too. Kept woods stay binding.
- **Visible behaviour:** clearings widen around camps; on sparse sites wood work moves, slows or stops, and the tool chain feels it; forest sites can sustain cutting.
- **Acceptance:** no wood from a woodcutter whose reach holds no trees; a forest cut slowly holds steady over six years, one cut hard recedes; hunting still falls with felling.
- **Tests:** rules test for felling, regrowth and shared reach; the divergence report; `woodland` checks in `TESTING.md`.
- **Risks:** the biggest balance risk in Track A: wood feeds tools, and tools feed every proper workplace. Expect the tool gap (HANDOFF decision 3) to widen on sparse sites. Report it; don't tune it away. Changes `TownWoodland` and `TownLand.get_output_factor` (production formulas, high risk).

### S3: Winter fuel (M; needs D5)

- **Objective:** wood's main sink, and a reason forests matter to survival.
- **Scope:** each household burns firewood daily in the cold months, longer in colder climates; its own gathering goes to its hearth first; then the commons. A shortage costs workdays and adds to hardship, below hunger. Fuel becomes a need bucket like food. Kilns and brickworks already burn wood.
- **Visible behaviour:** autumn wood work; stores fall over winter; cold sites without woods struggle; wood surplus of later years shrinks.
- **Acceptance:** survival-first holds (a cold family gathers or takes up wood work when it can); a matched first-winter stress shows fuel shortages only where wood is short.
- **Risks:** adds a hard-ish need: the owner should see first-year survival on stressed sites before S3 merges.

### S4: Materials in construction (L) ◆

- **Objective:** buildings that show their town's materials, and uses for the stone chain's dead ends (F4).
- **Scope:** homes and proper workplaces gain a timber and a stone version: stone costs stone (or masonry for the better home) and more labour, decays slower, and needs less upkeep. Families choose a version for their own projects by what's available, what it costs them, and their values (thrifty, ambitious, perfectionist, steady), with reasons like every other choice. The player's communal buildings take the player's choice. Paving stones make a paved road (lower travel cost, no trampling). Families can take up stone work through a hand-work stage (D6). Stone buildings are drawn differently.
- **Visible behaviour:** stone towns on rock, timber towns in forests; mixed towns where families differ.
- **Acceptance:** the divergence report shows the share of stone buildings following deposits and values; the one construction pipeline is unchanged (tier 0 never deadlocks).
- **Risks:** touches `TownConstruction`, `BUILD_COSTS`, `FamilyDevelopment`, building visuals and saves (a building records its material). Split into S4a (uses for masonry and paving, player side) and S4b (family choice) if it grows.

### S5: Clay and limestone (M)

- **Objective:** ground the brick and lime chains in geography.
- **Scope:** clay deposits derived in town-map generation from the regional data already there (low, wet ground beside rivers and lakes); limestone as a kind of stone deposit. The brickworks needs a clay pit; the lime kiln burns limestone. Brick and tile become building materials (tile roofs last longer).
- **Constraint:** `region_map_generator.gd` stays byte-identical and the world fingerprint unchanged; only new towns get new deposits (town maps are saved).
- **Acceptance:** brick only where clay is; `map_luck_check` and `town_map_probe` re-run.

## 7. Sprint Cards: Track B (summary)

Mechanism from `docs/PROPERTY_AND_COMMUNAL_RESOURCES.md`, revised by D1.

- **S6 Ownership ledger (M).** `city.resources` stays the one physical store; each household holds a share in it; the community's goods are the rest (computed, never stored). Buildings record who paid. The player trades only the community's goods; raid losses fall proportionally. **At the default policy (100%, open) play is identical:** matched snapshots must equal the base branch day for day. Saves: new dictionaries are domain fields.
- **S7 Contributions by category (L) ◆.** The player sets a percentage per category (food, wood, stone, tools, goods…) of each holding's total output; the rest enters the household's share. Families eat and build from their own share first. Occupation choice, improvement cost and "can it pay" read the family's own share (property doc C3). No happiness modifier from the rate itself: families respond to what they actually have and receive. Matched towns at several rates on ordinary, stressed and difficult sites must show real, different outcomes, and both high and low rates must have a viable path.
- **S8 Redistribution and asking for help (M).** Player rules: reserve, redistribute (to whom, how much), supply public works, commitments (property doc Phase 3). Survival first: a family in danger asks the commons and neighbours (the existing sharing in shortage) before hunger, and the player's rules decide whether the commons answers. Fairness judged through `TownSocial.judge_distribution`.
- **S9 Market day (L) ◆.** Monthly barter among families, prices in grain from the town's scarcity with the trader's friction, cleared in aggregate, no credit. Values decide who deals and how (Hagglers, Fair Dealers, Insular, Cosmopolitan). Wealth as a level.

## 8. Evaluating Results

- **Every sprint reports** the divergence report against its base, same seeds, mechanic on and off (a switch on the check, like the existing `--no-…` flags), plus the existing checks its files touch (`TESTING.md`).
- **Intended versus broken.** A difficult site doing worse is intended when the cause is its land and families responded sensibly. It is broken when families ignore an available means of survival, a stock goes negative or never recovers, output appears without its input, two systems count the same land twice, or a loaded game diverges from the original.
- **Don't tune to equalise.** If a result looks wrong, isolate the cause with switches and report options (`owner-milestone-workflow`).
- **Performance.** Note the daily tick's cost in each report; stocks are per tile or per site, never per animal or tree.

## 9. Constraints Carried Into Every Sprint

From `AGENTS.md`, `HANDOFF.md` and the brief: `main.gd` gets no simulation logic; every economy number in `economy_balance.gd`; no game RNG in town maps; seeded noise for decisions; new object-valued state gets a line in `GameState`; long sim logs written to files; comparison runs from fixed-commit worktrees; no new player micromanagement without a design reason; no arbitrary bonuses standing in for constraints.

## 10. Handoff

- **Completed:** this roadmap. Nothing built or tested.
- **Branch:** `docs/economic-foundations-roadmap` (from `develop` at `fcfc0fc`).
- **Next:** the owner answers D1–D8; then S1 on `feature/economic-foundations` (per D7).
- **Blockers:** D1–D8. The unmerged `docs/property-and-communal-resources` should be merged or retired once D1 is decided, so its superseded §4.3 doesn't mislead.

## Log

- 2026-11-02: roadmap written from the owner's brief and the resource audit. No code.
