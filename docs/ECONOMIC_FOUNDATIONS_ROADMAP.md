# Economic Foundations and Geographic Diversity: Roadmap

**Status: authorized and in progress (2026-11-02).** Decisions D1–D8 and working terms Q1–Q6 approved by the owner. Work happens on `feature/economic-foundations` in its own worktree; nothing merges into `develop` without the owner. This is the living backlog for the initiative: update the tracking table after every sprint, and reorder freely when a sprint's results say so.

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

## 2. Owner Decisions (approved 2026-11-02)

All eight are resolved. Routine design details are made in sprint and recorded in the sprint's card; anything that departs from these goes back to the owner.

- **D1. Ownership and contributions: the brief supersedes the property doc wherever they conflict** (its §4.3 founding compact, where families set their own share, is retired).
  - The player sets communal contribution percentages **per resource category, of total production**. What remains belongs to the producing household. No automatic subsistence exemption. Families don't set or approve the mandatory rates.
  - Households keep private inventories; the community keeps its own. The player controls communal reserves, redistribution and spending.
  - Families may **contribute more voluntarily**, and their values shape how they react to the policy. They respond through economic behaviour, culture, loyalty, migration, and later crime or resistance.
  - The property doc's mechanism still serves: the ledger over one store (P1), building rights (P2), commitments (Phase 3), the market day (Phase 4).
  - **Migration only:** today's 100% pooling may stay temporarily so old saves and comparison sims keep working. It must **not** become the permanent default for new games: once ownership exists, a new game asks the player for an **initial contribution choice** at founding.
- **D2. Trade between households: approved.** `ECONOMY_MODEL.md`'s prohibition is superseded. A monthly market day is the ordinary mechanism: real supply and demand, privately owned goods, specialisation, values and interests, no currency at founding. **The calendar never blocks emergency help or a necessary exchange.**
- **D3. Food: approved.** One shared food need, met by several food goods that differ in production, season, storage, spoilage and value. No nutrition simulation for now.
- **D4. Stocks: approved.** Timber, fish and game become stocks that deplete and recover; recovery depends on environmental conditions and remaining productive capacity (what's left to regrow or breed). Overharvesting has consequences. Shared-reach competition must stay correct.
- **D5. Winter firewood: approved.** A heating need supplied by firewood, eventually responding to seasonal temperature, housing, household size, available fuel, and climate and geography. It must compete with timber's other uses. Families answer shortages by their survival priorities.
- **D6. Stone and craft occupations: approved.** The split between family-chosen basic trades and player-assigned crafts is removed as development allows. Families judge accessible resources, skills and equipment, production requirements, expected benefit, household needs and values. The player keeps commissioning public works and communal projects. **Families choose the materials of their own buildings where viable; the player chooses for communal construction.**
- **D7. Branching: approved.** One integration branch for the initiative, `feature/economic-foundations` from `develop`. Each sprint has identifiable changes, validation results and commits, and merges into the integration branch once validated. **Nothing reaches `develop` or `main` without the owner's authorization.**
- **D8. Difficulty and balance: approved.** Report differences honestly; don't compensate difficult sites or equalise settlements. Some sites should be substantially less viable to found on; others hard early but strong industrially later. Tell intended disadvantage from defects, and keep fixing bugs, numerical instability and unintended regressions. Evaluate with deterministic sims across several seeds.

### Working terms (approved 2026-11-02)

- **Q1 Pausing:** continue through S1–S5 while each sprint passes its validation; report at every ◆ without stopping. Stop only for serious correctness failures, architectural blockers, or conflicts with the design principles.
- **Q2 Machine time:** unattended runs allowed, **at most four concurrent Godot processes**; watch memory and load and reduce concurrency if the machine struggles. Eight starts for some on/off comparisons is acceptable when documented; baselines and review comparisons keep twelve.
- **Q3 Pushing:** the integration and sprint branches may be pushed to `origin`. No merges into `develop` or `main`, no force-push, no changes to unrelated branches.
- **Q4 Interface:** small, necessary additions to existing pages (deposit quality, forest resources, fuel warnings, material choice, household resources). No broad redesign; focused changes to high-risk UI files, verified by the sidebar tests and screenshots.
- **Q5 Mortality: severe, sustained hunger or cold can kill.** Families first try what they can (own reserves, the commons, trade, other work, other fuel or shelter, leaving), and none of it is guaranteed. Death follows sustained, severe conditions, never one missed day; housing, resources and environment shape the risk; no arbitrary mortality and no artificial protection. Uses the existing household member counts and lifecycle removal, as its own bounded sprint (S3b).
- **Q6 Worktree:** the initiative runs in a separate `git worktree`; the main folder stays on `develop` for playtesting.

### Track B guidance (owner, 2026-11-05)

S7, S8 and S9 go in order; no food exchange is pulled forward into S7. Low-contribution towns are judged at S9's review point, not before: private economies need household exchange as communal ones need shared resources.
- **The compact is an agreement among families, not taxation.** Their values, trust and circumstances should eventually shape acceptance and compliance.
- **Household ownership is meaningful:** families keep goods, provide for themselves, invest in their own interests and later exchange. Communal goods stay distinct in ownership though they share one physical store.
- **No artificial advantage to either arrangement:** high rates give communal security and fewer private resources; low rates the reverse, and more dependence on cooperation and trade. Let it emerge.
- **The founding choice must matter** to the town's development; families respond by their values.
- **Track hunger, specialisation, household holdings and community reserves in S7 and S8** without balancing them early.
- **Keep the `main.gd` change narrow** and verify founding still works.
- **Count contributions correctly along production chains,** so processing creates no extra claims on the same goods.
- **After S9:** compare across environments and founding families. The question is whether different arrangements can succeed under the right circumstances, not whether they perform equally.

**Sequencing approved:** geography and scarcity (S1–S5) before property and markets; Track B follows by dependencies and findings. Each sprint should still move toward the eventual joining of geography, autonomous production, ownership, exchange and culture.

## 3. Sequencing

1. **Measure first.** S1a builds the test framework (`docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md`) on the existing checks and records baseline B0 on `develop`; S1b lands the first mechanic against it. (The owner's testing mandate, 2026-11-02, puts the framework before substantial mechanics, so it is its own small sprint.)
2. **Make geography bite: Track A (S1–S5).** Stone, finite forests, fuel, materials in construction and grounded clay give sites real advantages, scarcity and sinks, and give settlements their first visible identity. It closes F1–F4 and some of F6, and makes property worth having.
3. **Ownership and exchange: Track B (S6–S9).** The ledger (behaviour-neutral), player-set contributions, redistribution and survival-seeking, and the market day. S6 touches nothing Track A changes in behaviour and may move earlier if convenient.
4. **Local value: E13 (V0–V4), between Tracks B and C.** A town-specific value for each good, from projected scarcity and an anchor that emerges from the economy. It informs decisions and never dictates them. Numbers stay hidden from players. No new goods or categories. V0 decides the timing of the later stages, so V2 isn't committed before S10 without evidence. Proposal: `economic_foundations/E13_local_value.md`.
5. **The land's year: Track C (S10–S14).** Food kinds, seasonal crops, soil, fish and game stocks, livestock and draft animals.
6. **Metal and quality: Track D (S15–S17).** Iron with charcoal, tool tiers, wood species.
7. **Threads through every sprint:** culture ↔ economy (a sprint states which values touch its decisions), autonomy (no new player micromanagement), saves, determinism and the cost of the tick.

**Why not property first,** as `HANDOFF.md` had it planned: with no scarcity beyond the first year, a ledger, a contribution rate and a market move goods nobody lacks (F3). Track A makes those decisions matter. The owner approved this order (2026-11-02).

## 4. Epics

| Epic | Covers (brief part) | Sprints |
|---|---|---|
| E1 Measurement | Evaluation across sites and seeds (9.4); the test plan | S1a, then every sprint |
| E2 Geology and deposits | Stone, clay, limestone, iron, copper, tin, coal, salt (3) | S1b, S5, S15, B-items |
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
| E13 Local Value | Town-specific values from projected scarcity and an emergent anchor; informs decisions, never dictates | V0–V4 |

## 5. Tracking

Status: Planned, Active, Complete, Blocked. Complexity: S (days), M (about a week), L (more). ◆ = review point for the owner (merge to `develop`).

| Sprint | Epic | Status | Depends on | Acceptance (short) | Validation | Commit | Follow-up |
|---|---|---|---|---|---|---|---|
| S0 Roadmap and decisions | — | **Complete** | — | Owner answers D1–D8 | Approved 2026-11-02 | — | — |
| S1a Test framework and baseline | E1 | **Complete** | S0 | Suite runner, flow counters, invariant checker, founder sets, divergence check; baseline B0 recorded | Test plan §9; identical 6,101-line log against `fcfc0fc`; 47/47 tests; repeats identical; B0 ordinary 60 towns, no violations ([report](economic_foundations/S1a_framework.md)) | `e5410ba` | B0 stressed and quarry runs to add |
| S1b Stone quarries | E2 | **Complete** ([report](economic_foundations/S1b_quarries.md)) | S1a | Quarry only on stone; output by deposit grade; stone only where the land has it | Divergence check, B0 vs S1b | — | — |
| S2 Living forests | E3 | **Complete** ([report](economic_foundations/S2_forests.md)) | S1 (report) | Woodcutting thins the woods and slows with them; regrowth over years; families weigh woods for woodcutting | Report on forest and sparse sites; hunting coupling | — | — |
| S3 Winter fuel | E3 | **Active** (built `accb93d`, suite passes; comparison queued) | S2 | Households burn firewood in the cold season; shortage has real cost; wood surplus falls | Report; first-winter stress | — | — |
| S3b Fatal hardship | E3, E11 | **Active** (built `07b80eb`, 51/51 tests; comparison queued: one build measures S2, S3 and S3b through its switches) | S3 | Sustained severe hunger or cold can kill members, then a household; risk follows severity, housing and season; families tried what they could first | Rules test; deaths by cause vs B0 | — | — |
| S4 Materials in construction ◆ | E4, E10 | **Active** (S4a/b `2179f49`, S4c families quarry `4d78d9d`; 52/52 tests; comparison and review queued) | S1 | Timber and stone versions of homes and workplaces; families choose; masonry and paving get uses | Report: share of stone buildings by site | — | — |
| S5 Clay and limestone | E2, E4 | **Active** (built `4a08dc6`, 53/53 tests; comparison and review queued) | S4 | Brickworks needs clay, lime kiln needs limestone; brick and tile have building uses | Report | — | — |
| S5b Wood beyond the winter | E3 | **Accepted** (owner 2026-11-06; `G` and `G-review` run, survival essentially unchanged; merged into S6–S9; [report](economic_foundations/S5b_wood_sense.md)) | S5 | Owner 2026-11-05, option b of the Track A review: families weigh the wood in store against the coming winter's need in choosing wood work and gathering, as a reason, never a rule; no added founding fuel (option c declined) | Rules test; G against F by land; no survival target | — | — |
| S6 Ownership ledger | E5 | **Active** (built on `feature/ef-s6-ledger`; 54/54 tests; matched towns identical to the base; held unmerged until the Track A review is read; [report](economic_foundations/S6_ledger.md)) | S0 | Household shares, building funders, treasury view; play unchanged under the migration-only 100% setting | Matched snapshots identical to the base; saves | — | — |
| S7 Contributions by category ◆ | E5 | **Active** (owner approved S7–S9 in order, 2026-11-05; built on `feature/ef-s7-compact`; [report](economic_foundations/S7_compact.md)) | S6 | Player sets % per category of total output; families keep the rest; new games ask for an initial choice | Matched towns at 100/60/30/10% | — | — |
| S8 Redistribution and asking for help | E5, E11 | **Active** (built on `feature/ef-s8-commons`; [report](economic_foundations/S8_commons.md)) | S7 | Player's reserve/redistribute rules; families in danger seek the commons and neighbours | Report: deaths and departures where goods existed | — | — |
| S9 Market day ◆ | E6 | **Active** (built on `feature/ef-s9-market`; [report](economic_foundations/S9_market.md)) | S7 | Monthly barter among families; urgent exchange any day; specialists live by exchange | Report: specialisation and wealth spread | — | — |
| S10 Food kinds and spoilage | E7 | Planned | — | Several food goods meet one need; storage and spoilage differ | Saves; matched survival | — | — |
| S11 The farming year | E7 | Planned | S10 | Sowing and harvest seasons, labour peaks, winter stores; 2–3 grains, legumes, vegetables | Report by climate | — | — |
| S12 Soil | E7 | Planned | S11 | Fertility tires and recovers (fallow, manure); suitability by soil and climate | Report over 10 years | — | — |
| S13 Fish and game stocks ◆ | E8 | Planned | S2 | Over-fishing and over-hunting deplete; stocks recover | Report on water and forest sites | — | — |
| S14 Livestock and draft | E9 | Planned | S11, S12 | Sheep, cattle/oxen, pigs, poultry with feed, space and breeding; oxen raise farm output; manure | Report | — | — |
| S15 Iron | E2, E10 | Planned | S2, S3, S9 | Mine on ore, charcoal from woods, smithy; iron tools | Report: iron sites diverge | — | — |
| S16 Tool tiers and quality ◆ | E10, E11 | Planned | S15 | Wood and iron tools differ in cost, life and productivity; families choose by values | Report | — | — |
| S17 Wood species | E3 | Planned | S2, S4 | Species by climate and soil; each has a distinct use (durability, handles, baskets, fuel) | Report | — | — |
| S18 Values from experience | E11 | Planned | S7, S9 | Economic experience moves values (e.g. hunger under hoarding → private holdings) | Report: culture drift by policy | — | — |
| S19 Scale check | E12 | Planned | Track B | Tick cost at 100 households within the benchmark's budget | `HOUSEHOLD_SIM_BENCHMARK.md` | — | — |
| V0 Observe | E13 | Planned; **not authorized** ([proposal](economic_foundations/E13_local_value.md)) | S9b reviewed; owner authorizes | Harness only: monthly raw inputs logged, the proposal's eight questions answered | Gameplay logs identical with it on or off; report reviewed | — | — |
| V1 Town Reference ◆ | E13 | Planned | V0 | Local values in market and wealth; signals preserved; food floats | Pooled towns identical day for day; saves and determinism hold; owner reviews how far exchange diverges from values | — | — |
| V2 Work Decisions ◆ | E13 | Planned | V1; timing set by V0 | One reasoned term; old scarcity terms retired one at a time | Fixed weights; matched on/off runs; no boom-and-bust cycle; callings, values and survival remain meaningful | — | — |
| V3 Household Valuation | E13 | Planned | V1, likely V2; Track C and S18 | Different exchange terms by household | Differences explained by need, values or expectations | — | — |
| V4 Regional Valuation | E13 | Planned | A second economy, merchant families | Value gaps drive trade | Separate design | — | — |

**Backlog, not yet sprinted:** copper and tin → bronze (after S16 shows tiers matter); coal; salt preserving meat and fish (after S10); flax → linen and wool → spun cloth, so clothing has a producer (F4); dogs for herding and hunting; horses and transport; water transport; trader wants and offers from the neutral town's own geography, so a mining town can import food; settlement visuals by material beyond S4's first pass; evasion, resentment and departure as answers to contribution policy (only once the mechanics in S7–S9 exist); fruit trees.

## 6. Sprint Cards: Track A

### S1a: Test framework and baseline (M)

- **Objective:** the yardstick every later sprint reports against, before any mechanic changes.
- **Scope:** `docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md` section 9: suite runner, per-good flow counters, the invariant checker, founder sets independent of the tile, and the divergence check over five environments (fertile valley, forested, rocky highland, balanced, marginal; test-side groupings only). Then baseline B0 on `develop` at `fcfc0fc`, and the benchmark.
- **Acceptance:** test plan section 10. No change in play: the gameplay regression and the full suite pass unchanged.

### S1b: Stone quarries (M)

- **Objective:** the first real mineral advantage.
- **Scope:**
  1. The 2026-10-25 access rule: a quarry's footprint must include stone-deposit tiles, which may now be built on by a quarry only. Output scales with the deposit tiles in the footprint and a deposit **grade** read from the town map (a pure function of the tile, so no new randomness).
  2. Deposits are large but finite (a per-tile amount). An exhausted quarry says so and its family reconsiders its work through the existing `OccupationReview`.
  3. The site survey and the placement hint name the stone and its grade.
- **As built** (`scripts/domain/town_deposits.gd`): grade = 0.4 + 0.6 × (stone neighbours / 8), so the heart of a large deposit is good and a lone edge tile poor; full cut with 4 tiles' worth of the best stone underfoot; 600 blocks per tile, kept on the tile (`deposit_left`) and taken from the fullest tile first; output capped at the stone left. Quarries aren't among the trades `OccupationReview` weighs, so **a worked-out quarry releases its family** (the existing unassign path, which also blocks auto-assignment) and families' own initiative finds them work.
- **Changed from the plan:** an old save's quarry with no stone underfoot does **not** keep working: it is worked out at once and its family is freed, and the building panel says why. Keeping it would be stone from nowhere, the kind of exemption D8 rules out. The building stays standing.
- **Visible behaviour:** quarries cluster on rock; towns without stone can't quarry (stone only by trade); a good-grade deposit outproduces a poor one.
- **Acceptance:** placement refuses a quarry off stone with a reason; output follows grade; matched towns that never build a quarry are unchanged day for day; old saves load.
- **Tests:** a rules test (placement, output, exhaustion, saves); the divergence check against B0.
- **Risks:** rough tiles currently block placement everywhere; opening them to quarries touches `building_placement.gd` validation and route grid passability. Stone has few uses until S4, so S1 alone barely moves outcomes (the report should show stone appearing only on stone sites, and little else).
- **Measuring it:** in family-led towns nobody builds a quarry (the stand-in player builds only homes and public works, and families can't choose stone work yet), so the comparison adds a player commissioning one quarry at the start of year 2 on its best stone (`--commission=quarry@360`), against the same commission in B0 where a quarry may stand anywhere.
- **Autonomy:** quarrying stays player-built in S1; families take it up through a hand-work stage in S4 (D6).

### S2: Living forests (M–L)

- **Objective:** timber as a finite, regrowing stock (F2).
- **Scope:** a woodcutter's output comes from felling trees within its reach, and its yield falls as nearby woods thin; felled tiles regrow through stages over several years (a stage per tile, no per-tree data), and regrowth and the yearly spreading depend on standing woods nearby, so a clear-cut recovers slower than a thinned wood (D4). Families judge woods in reach for woodcutting as they do for hunting, including shared reach. Gathering by families thins woods too. Kept woods stay binding.
- **What exists to build on** (`TownWoodland`): woodcutters already fell tiles (marked ones at full pace, otherwise the nearest trees at 10%: about 18 tiles a year for a full woodcutter), and woods already spread each spring by the pull of nearby woods. What's missing is the link: the 6 wood a day doesn't come out of the trees felled, and with no trees at all `get_felling_factor` returns 1.
- **Design:** each wooded tile holds timber (`timber`, kept on the tile like `deposit_left`; an old map's tile is mature). A woodcutter's wood is cut from the fellable trees nearest it, tile by tile, and a tile with no timber left is felled; so the felling rate follows the wood made (with about 40 wood a tile, a full woodcutter clears about 50 tiles a year, against 18 now). Output falls with the walk to the nearest fellable trees, like the kept-woods factor, and is nothing with no trees in reach. A tile the woods spread to starts young (little timber) and grows each spring towards maturity over many years, so new woods are not instantly timber. Families' wood gathering cuts timber near their homes the same way. Kept woods stay binding.
- **Visible behaviour:** clearings widen around camps; on sparse sites wood work moves, slows or stops, and the tool chain feels it; forest sites can sustain cutting.
- **Acceptance:** no wood from a woodcutter whose reach holds no trees; a forest cut slowly holds steady over six years, one cut hard recedes; hunting still falls with felling.
- **Tests:** rules test for felling, regrowth and shared reach; the divergence report; `woodland` checks in `TESTING.md`.
- **Risks:** the biggest balance risk in Track A: wood feeds tools, and tools feed every proper workplace. Expect the tool gap (HANDOFF decision 3) to widen on sparse sites. Report it; don't tune it away. Changes `TownWoodland` and `TownLand.get_output_factor` (production formulas, high risk).

### S3: Winter fuel (M)

- **Objective:** wood's main sink, and a reason forests matter to survival.
- **Scope:** each household burns firewood daily in the cold months, by season and climate (longer and more in colder places) and by household size; housing enters as unsheltered versus housed now, and through materials once S4 lands (D5). Its own gathering goes to its hearth first; then the commons. A shortage costs workdays and adds to hardship, below hunger. Fuel becomes a need bucket like food. Kilns and brickworks already burn wood.
- **As built** (`scripts/domain/town_fuel.gd`): a season's warmth is the site's climate temperature plus a seasonal offset (0, +0.2, 0, −0.25); below 0.5 a hearth burns 0.25 wood per person a day at full cold, scaled down as it is milder, ×1.5 in temporary shelter or a hut. So a temperate site (0.55) heats only in winter, a cold one (0.3) from autumn to spring, a tropical one never. Fuel is a need bucket served by wood from the common store; the fraction of a unit is carried. Short of wood, every hearth that needs fuel goes cold: one working day in four lost (on other days than hunger's) and, after 10 cold days in a month, 1 hardship point (hunger gives 2). Families answer through their existing reasoning: the coming fuel counts in the town's wood use and wood risk (`FamilyInitiative.get_use`, `get_waiting_risk`), and a family whose hearth went cold has reason to gather wood. Cards "Hearths are going cold" (alert) and "Firewood will run short" (caution) offer an appeal for wood. Only towns with a map heat; meta `no_winter_fuel` switches it off for comparisons. No deaths: those are S3b.
- **Visible behaviour:** autumn wood work; stores fall over winter; cold sites without woods struggle; wood surplus of later years shrinks.
- **Acceptance:** survival-first holds (a cold family gathers or takes up wood work when it can); a matched first-winter stress shows fuel shortages only where wood is short.
- **Risks:** adds a hard-ish need; first-year survival on stressed sites is reported at the next ◆. S3 itself adds no deaths: those come in S3b.

### S3b: Fatal hardship (M)

- **Objective:** Q5. Environmental hardship can be fatal; behaviour stays survival-driven.
- **Scope:** a monthly risk to a household's members once hunger or cold has been both severe and sustained (weeks, not days), rising with severity and duration, higher without shelter or in a poor home, in the cold season, and for the young and old. Seeded rolls as elsewhere in `City`. A death lowers the member counts (children first by vulnerability, then adults); a household with no adults left is removed through the existing lifecycle path (work succession, house freed). Deaths are logged with their cause and shown to the player as a chronicle line and a family card note.
- **Acceptance:** no death without sustained severe conditions; a family with an available response took it before the risk began (traced); risk falls when conditions lift; departures still happen for those who can leave.
- **Risks:** changes hunger's consequences in every town, so B0 comparisons will move; reported honestly, not offset.

### S4: Materials in construction (L) ◆

- **Objective:** buildings that show their town's materials, and uses for the stone chain's dead ends (F4).
- **Scope:** homes and proper workplaces gain a timber and a stone version: stone costs stone (or masonry for the better home) and more labour, decays slower, and needs less upkeep. Families choose a version for their own projects by what's available, what it costs them, and their values (thrifty, ambitious, perfectionist, steady), with reasons like every other choice. The player chooses the material of communal buildings (D6). A home's material also sets how much firewood it needs (S3). Paving stones make a paved road (lower travel cost, no trampling). Families can take up stone work through a hand-work stage (D6). Stone buildings are drawn differently.
- **Visible behaviour:** stone towns on rock, timber towns in forests; mixed towns where families differ.
- **Acceptance:** the divergence report shows the share of stone buildings following deposits and values; the one construction pipeline is unchanged (tier 0 never deadlocks).
- **Risks:** touches `TownConstruction`, `BUILD_COSTS`, `FamilyDevelopment`, building visuals and saves (a building records its material). Split into S4a (uses for masonry and paving, player side) and S4b (family choice) if it grows.
- **As built:** S4a: timber, rough stone and dressed stone (masonry) for homes and proper buildings (stone keeps a third of the wood, 1.5 blocks or 0.5 masonry per wood replaced; work ×1.6 / ×1.25; upkeep interval ×1.5; a stone home ×0.75 firewood); fields and hand work timber only; a "Building material" card on the Planning page sets the player's choice. S4b: `MaterialChoice` for families' own homes and improvements (stores, labour and urgency, warmth or upkeep, values, seeded noise; only what the stores can supply). S4c: the stone pit, hand work on a deposit, makes stone a trade families choose (`TownLand` kind "stone"; drawn by calling and by building waiting for stone). Grey walls for stone on the map.
- **Not done, moved to the backlog:** paving stones as paved roads (no use for paving yet); the placement preview still shows the timber cost.

### S5: Clay and limestone (M)

- **Objective:** ground the brick and lime chains in geography.
- **Scope:** clay deposits derived in town-map generation from the regional data already there (low, wet ground beside rivers and lakes); limestone as a kind of stone deposit. The brickworks needs a clay pit; the lime kiln burns limestone. Brick and tile become building materials (tile roofs last longer).
- **Constraint:** `region_map_generator.gd` stays byte-identical and the world fingerprint unchanged; only new towns get new deposits (town maps are saved).
- **Acceptance:** brick only where clay is; `map_luck_check` and `town_map_probe` re-run.

## 7. Sprint Cards: Track B (summary)

Mechanism from `docs/PROPERTY_AND_COMMUNAL_RESOURCES.md`, revised by D1.

- **S6 Ownership ledger (M).** `city.resources` stays the one physical store; each household holds a share in it; the community's goods are the rest (computed, never stored). Buildings record who paid. The player trades only the community's goods; raid losses fall proportionally. **Under the 100%-pooled setting play is identical:** matched snapshots must equal the base branch day for day. That setting is for old saves and comparison sims only (D1). Saves: new dictionaries are domain fields.
- **S7 Contributions by category (L) ◆.** The player sets a percentage per category (food, wood, stone, tools, goods…) of each holding's total output; the rest enters the household's share. **A new game asks the player for the initial rates at founding**; old saves keep 100% until the player changes it. Families may give more voluntarily, by their values. Families eat and build from their own share first. Occupation choice, improvement cost and "can it pay" read the family's own share (property doc C3). No happiness modifier from the rate itself: families respond to what they actually have and receive. Matched towns at several rates on ordinary, stressed and difficult sites must show real, different outcomes, and both high and low rates must have a viable path.
- **S8 Redistribution and asking for help (M).** Player rules: reserve, redistribute (to whom, how much), supply public works, commitments (property doc Phase 3). Survival first: a family in danger asks the commons and neighbours (the existing sharing in shortage) before hunger, and the player's rules decide whether the commons answers. Fairness judged through `TownSocial.judge_distribution`.
- **S9 Market day (L) ◆.** Monthly barter among families, prices in grain from the town's scarcity with the trader's friction, cleared in aggregate, no credit. Values decide who deals and how (Hagglers, Fair Dealers, Insular, Cosmopolitan). A family in danger may exchange or receive help on any day, not only on market day (D2). Wealth as a level.

## 8. Evaluating Results

**Between every two sprints, a review** (owner, 2026-11-02; test plan section 10b): does the complexity still hold together, do villages diverge by land, and do player choices produce both successful and failing villages? It is recorded in the sprint's report and may reorder this backlog. A sprint's own comparison plus its review costs roughly 3–6 hours of unattended runs, so sprints close a few a day at best, and the handoff below is kept current after each.

**`docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md` governs:** the four test levels, environments and founder sets, invariants, metrics, the intended-versus-defect rule, stopping rules, the Definition of Done and the sprint report format. Sprint reports live in `docs/economic_foundations/`. In short: every economic sprint runs the divergence check against its base and B0, mechanic on and off; unequal outcomes are reported, not equalised; a failing invariant stops the affected work.

## 9. Constraints Carried Into Every Sprint

From `AGENTS.md`, `HANDOFF.md` and the brief: `main.gd` gets no simulation logic; every economy number in `economy_balance.gd`; no game RNG in town maps; seeded noise for decisions; new object-valued state gets a line in `GameState`; long sim logs written to files; comparison runs from fixed-commit worktrees; no new player micromanagement without a design reason; no arbitrary bonuses standing in for constraints.

## 10. Handoff

*Update 2026-11-03:* the first comparisons ran. **S1b confirmed** (stone only where the land holds it: marginal towns' stone fell from 412 to 45 blocks by year 3, rocky kept 320 of 342; `S1b_summary_y3.md`). **S2 stands** (no harm; `S2_S3_S3b_summary_y6.md`). **S3 had a survival-first defect** (towns froze beside their woods; traced and fixed in `4556af0`, report `S3_firewood.md`), so the first S3, S3b, S4 and S5 comparisons are set aside. Re-running on the fixed build (`../ngg-ef-runs5` at `4556af0`): labels `A` (all on, ordinary and stressed), `A-nodeaths`, `A-nofuel` (deaths and fuel off), `A-review`. The fix sits on top of the stack (`feature/ef-s5-clay-lime`) rather than on S3's branch; the integration merge takes the stack in order.

*As of 2026-11-02 evening.*
- **Track A is built:** S1a (`e5410ba`), S1b (`3ca6e31`), S2 (`10c8745`), S3 (`accb93d`), S3b (`07b80eb`), S4 (`2179f49`, S4c `4d78d9d`), S5 (`4a08dc6`), each on its own branch `feature/ef-<sprint>` stacked on the one before and pushed. Every sprint's rules tests and the full suite pass (53/53 at S5).
- **Measured so far:** only the baseline B0 (ordinary, quarry commission; stressed running). The comparisons and reviews of S1b–S5 are queued in order and take roughly 3–6 hours each at three processes: S1b quarry → the S3b build run as S2, S3 and S3b (metas `no_hardship_deaths`, `no_winter_fuel`) → S3b review → S4 and review → S5 and review. Fixed worktrees: `../ngg-ef-runs` (B0, `e5410ba`), `-runs3` (S1b), `-runs2` (S3b), `-runs4` (S4), `-runs5` (S5). Logs in `test-logs/div/<label>/`; tables by `scripts/compare_divergence.ps1`.
- **Not yet merged into `feature/economic-foundations`:** sprint branches are merged as each one's comparison confirms it.
- **Next:** read each comparison and review as it lands, write the sprint reports (`docs/economic_foundations/`), fix what they reveal, then start Track B (S6 ledger) only once Track A's results are understood. Open question for the review: the 80–140 ms simulated day (stand-in included) needs the town's own tick measured (the S2+ runs record `tick_ms_mean`).
- **Open housekeeping:** the unmerged `docs/property-and-communal-resources` holds the superseded §4.3; when S6 begins, bring its doc in with a note that D1 replaces §4.3, rather than leave it to mislead.

## Log

- 2026-11-02: roadmap written from the owner's brief and the resource audit. No code.
- 2026-11-02: owner approved D1–D8 with additions (an initial contribution choice in new games, voluntary contributions, exchange outside market day, firewood by housing and household size, families choosing their own building materials). Recorded; work not started.
- 2026-11-02: owner's testing mandate → `docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md`. S1 split into S1a (framework and baseline) and S1b (quarries). Not started.
- 2026-11-02: owner approved Q1–Q6 and authorized the work. Mortality from sustained hunger and cold added as S3b.
- 2026-11-06: owner added E13 Local Value (V0–V4). Nothing built; V0 waits for the owner's word.
