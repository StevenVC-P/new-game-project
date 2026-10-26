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

## Economy Balance Pass (2026-10-20)

All economy numbers now live in `scripts/domain/economy_balance.gd`. `tests/sim/opening_check.gd` founds 20 towns (each with different founding families) and plays two years, once with the owner's first-playtest opening (3 houses, 1 farm, 1 woodcutter, 1 toolmaker) and once with a simple stand-in player.

**What the first playtest exposed:** with the original numbers, one woodcutter (2 wood/day) and one toolmaker (2 wood per tool, 1 tool/day) net zero wood, so a town could not afford another farm. Worse, every building cost tools, including the toolmaker, so a town that spent its 14 starting tools before running a toolmaker could never build again and emptied within a year.

**First pass, following owner direction** (tools are a slow, valuable craft; running short should be more common than having too many; every town must be able to start):

| Number | Before | Now |
| --- | --- | --- |
| Woodcutter output | 2 wood/day | 3 wood/day |
| Toolmaker output | 1 tool/day | 0.5 tool/day (still 2 wood per tool) |
| Tool upkeep per workplace | every 8-12 days | every 16-24 days |
| House cost | 8 wood + 1 tool | 6 wood + 0 tools |
| Toolmaker cost | 10 wood + 3 tools | 10 wood + 0 tools, so a town can always rebuild its tool supply |
| Stone and craft buildings | 2-3 tools | 1-2 tools |

| Opening check (20 towns, 2 years) | Before | Now |
| --- | --- | --- |
| Owner's opening | 4/20 off the ground, 20 stuck on wood | 20/20, none stuck |
| Stand-in player | 0/20, all out of tools | 20/20 |

Over ten years with one toolmaker, small towns build a tool buffer (about 166 by year 4); as the town reaches about 13 workplaces, one toolmaker no longer keeps up, tools run out in year 8, and the town shrinks to 31-42 people and carries on. A second toolmaker is what a growing town needs. Wood is now plentiful (about 1,300 by year 2 in the opening check), which may be too generous once more wood consumers exist.

These are a starting point for owner tuning, not final values.

**Random founding families (2026-10-20, owner decision).** Each founded town gets a random seed from the game, so founders differ every game: random life stage (never an old couple) and a fully random value profile, with the family trade following the calling. Tests and tools pass no seed and stay reproducible. The opening check shows founders now matter: with a sensible opening 17/20 towns get off the ground (was 20/20 when every town had the same founders); the strugglers had no family called to the soil, so their farms ran at -25%, and towns without a toolmaking family ran short of tools. The owner's playtest opening still succeeds 20/20.

**One farming founder guaranteed (2026-10-20, owner decision).** Farms are the only food source, so every founding includes at least one family called to the soil; nothing else about founders is forced. This lifts the sensible opening from 17/20 to 19/20.

**Pacing and the toolmaker allowance (2026-10-20, owner decision).** A month now takes a minute at 1x (2 seconds per game day; a year is 12 minutes). The owner wants 3-5 minutes to get a toolmaker running. Measured as the latest toolmaker start day at which about 16/20 towns still get off the ground:

| Upkeep grace | Toolmaker deadline | At 1x |
| --- | --- | --- |
| 20 days (previous) | about day 60 | 2 min |
| 60 days (chosen) | about day 90 | 3 min |
| 90 days | about day 120 | 4 min |

The owner settled on 2-3 minutes, with a newly founded town starting paused so the clock only runs once the player is ready. New buildings now need no tools for their first 60 days. The deadline is a cliff: 30 days past it, survival drops to about 4/20.

**Room for error (opening check, first-pass numbers, random founders, before the two changes above):** food and shelter mistakes are mostly forgiving (four farms first 17/20, two idle months 13/20). Wood and tools are each a one-way door: a woodcutter after about day 60, or a toolmaker after about day 50-60, is fatal in every town. A free woodcutter plus 20 starting tools was tested (before founder randomization) and closes the wood door; the tool deadline remains. Owner decision pending.

## One Holding Per Family (2026-10-20, owner decisions)

- **A family runs one holding**: a farmstead or workshop worked by the whole family (labor capacity 1). Family size changes output, not the number of jobs. Balance outputs are per two-adult family (farm 4, woodcutter 6, toolmaker 1, crafts 2 per day); a one-adult family works at half; older children add the periodic family-support bonus.
- **A farm is a family farmstead**: one family's fields, animals, and tools.
- **At scale, Houses employ families**: estates and workshop groups exist when a House holds several holdings worked by dependent families from the commons (`docs/HOUSES_AND_LINEAGE_MODEL.md`).
- **More founders**: with one holding each, four founding families meant exactly four jobs (two farms, wood, tools) and no slack; the opening check fell from 19/20 to 15/20 (sensible) and 0/20 (four farms first). Founding families became a balance number (`EconomyBalance.FOUNDING_FAMILIES`) and is now **6** (historically, founding groups were often 5-10 families).

| Opening check (20 towns, 2 years) | 4 founders | 5 founders | 6 founders |
| --- | --- | --- | --- |
| Sensible | 15/20 | 18/20 | 20/20 |
| Owner's playtest opening | 17/20 | 20/20 | 20/20 |
| Four farms first | 0/20 | 17/20 | 20/20 |
| Toolmaker by day 90 | 14/20 | 18/20 | 19/20 |
| Idle first 60 days | 7/20 | 9/20 | 15/20 |

Ten-year run with 6 founders: grows to 31 families / 124 people with three generations, outgrows its 10 farms in year 9, and recovers.

**Open tuning point:** converting outputs to per-family doubled the toolmaker (1 tool/day per family) while upkeep stayed per building, and one holding per family halves the buildings. Tools now overproduce (about 2,600 stockpiled by year 10 with one toolmaker), against the owner's aim that running short be more common. Likely fix: `TOOLMAKER_TOOLS_PER_DAY` around 0.6, or more frequent upkeep; either moves the measured toolmaker deadline, so re-run the opening check after changing it.

## Building Tiers (2026-10-20, owner decisions)

Tier 0 is hand work a family can always do, so no shortage of wood or tools is a permanent dead end; tier 1 is today's proper holdings; tier 2 (later) gives the stone and craft chain a purpose. Implemented in `scripts/domain/building_tiers.gd`; tested by `tests/building_tiers_validation.gd`.

| Tier 0 | Upgrades into | Produces |
| --- | --- | --- |
| Hut | House | a home (rough housing) |
| Forager's Garden | Farm | food |
| Gatherer's Camp | Woodcutter | wood |
| Tool Mender | Toolmaker | tools from wood (same 2 wood per tool) |

- **Free to build, no tool upkeep, about a third of tier 1 output** (`EconomyBalance.TIER0_OUTPUT_FRACTION`).
- **Upgrade in place**: pay the tier 1 cost and the same family keeps the holding. The Upgrade action appears on a selected tier 0 building.
- **Huts are homes.** New families and newcomers can move into them; proper houses are offered first.
- **Rough housing** (a hut or temporary shelter) lowers birth odds, and after 6 months (`ROUGH_HOUSING_GRACE_MONTHS`) adds monthly hardship scaled by Home and Place values.

**Judgment calls (owner may revisit):**

- Tier 0 buildings share the footprint and terrain rules of their tier 1 counterpart (a garden needs fertile land, a camp needs nearby trees), so an upgrade always fits in place.
- Callings apply to tier 0 as to tier 1 (a farming family is well suited to a garden).
- Rough-housing hardship uses the same tolerance as crowding: Simple Living and Town-Loving families do not mind huts, so a town of such families can live in huts indefinitely.
- Tier 0 buildings draw like their tier 1 counterpart, washed toward bare earth.

**Opening check with tiers** (6 founders; the stand-in player falls back to tier 0 when it cannot afford tier 1 and upgrades when it can; delaying the woodcutter also delays the camp):

| Build order | Before tiers | With tiers |
| --- | --- | --- |
| Sensible, owner's opening, four farms first | 20/20 | 20/20 |
| All wood on houses first | 0/20 | 20/20 |
| Woodcutter delayed to day 60 / 120 | 0/20 / 0/20 | 10/20 / 8/20 |
| Toolmaker delayed to day 120 / 150 | 14/20 / 1/20 | 18/20 / 6/20 |
| Never build houses or huts | fails only the "all housed" rule | families leave (rough housing hardship) |
| Only one farm, never a toolmaker, never any wood source | 0/20 | 0/20 |

Mild mistakes now cost time instead of the town; obviously bad play still fails.

## Map And Presentation Track (2026-10-20)

Owner direction: the map is part of the plan now; art and presentation wait for mechanics to settle.

**Done:**

- `tests/sim/map_luck_check.gd`: real generated worlds, real valid founding sites, real town maps, the stand-in player placing every building on the map. Result: 47/48 towns get off the ground; even the worst site has room for 12+ farms and 12+ gatherer's camps. Map luck is not a hidden killer.
- **Founding site survey.** Picking a site generates its town map right away and shows a plain-language survey (farmland, forest, water, rough ground, stone/ore in the region); founding reuses that exact map, so what the player sees is what the town gets (`scripts/world/site_survey.gd`).

**Findings:**

- Regional fertility misleads: 84% of valid sites would read as "poor farmland" by the regional measure, yet every town map holds room for many farms, because the town map generator guarantees fertile pockets. The survey therefore reads the town map, not the region.
- Stone and ore deposits never appear on town maps: the "stone cluster" step paints rough ground, and quarries can be placed anywhere. A site's stone and ore currently have no effect on the town.
- The `isolated` site tag applies to 44/48 sites (it mostly measures nearby roads, which barely exist before founding), so it carries little information.

**Owner decisions (2026-10-25):**

1. **A site means which resources the town can reach.** Some resources must be built on (a quarry sits on stone); others only need to be near the building (a camp near trees, as today).
2. **Stone appears on town maps** as a real deposit.
3. **Not every site has every resource.** More kinds of resources will be added later, so the resource model should be easy to extend.

Next implementation step: draw regional deposits onto town maps as resource tiles, give each resource an access rule (on-site or nearby), require quarries to sit on stone, and show available resources in the founding site survey.

**World atlas v1 (2026-10-25, owner-requested ahead of the village):** a fixed, hand-authored planet drawn as a painterly atlas, with kingdoms, regions, settlements, and roads as data a later simulation can change. The game opens on it, and entering an unclaimed region opens the existing regional map. It sets the global art direction. Details and remaining integration work are in `docs/WORLD_MAP.md`.

**Later in this track (after the first playable village):**

1. Living neighbors and rivals on the world map; the regional map generated from its world region's geography.
2. Readability pass: tell tier 0 from tier 1, who works where, who is struggling, at a glance.
3. Art direction decision (style, perspective, scope), then art, the UI overhaul, and audio replacing code-drawn shapes. `BuildingVisuals` profiles are the intended hook for sprites.

## Future Feature Notes

Ideas recorded for later design, not scheduled:

- **Side work (by-employment).** Pre-modern farming families also cut their own firewood, mended their own tools, spun, or brewed. A family keeps one primary holding but produces a little of a secondary good on the side, which gives small hamlets slack without turning families back into worker slots. Owner-endorsed as the planned follow-up to one holding per family.

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
