# Resource and Production Systems Audit

**Status: analysis only (2026-11-02), on `develop` at the close of the early-game sprint.** Nothing was changed. Where a doc and the code disagree, the code is taken as current behaviour.

Labels: **Implemented**, **Partial**, **Planned** (in a doc, not in code), **Not found**.
Evidence: **[code]** read in code; **[doc]** a document's claim; **[inferred]** my reading, not traced end to end.

---

## 1. Current documentation

**Primary long-term design reference: `docs/GAME_VISION.md`.** It says itself that it wins on conflict, and `CLAUDE.md` agrees. It was last edited on 2026-10-20, so it predates the family-influence model. `docs/HANDOFF.md` notes that the conflicts with that model are still unresolved.

| Document | Covers | State |
|---|---|---|
| `GAME_VISION.md` | Objectives, economy pillars (trade dominance, deposits, dependency), world | **Current, top authority.** Doesn't yet reflect family-led play. |
| `ECONOMY_MODEL.md` | Money as metal, two pockets (households and state), local scarcity prices, merchant families, in-kind taxes, no credit | **Current direction, almost entirely Planned.** Only barter with the neutral town exists. |
| `FIRST_STAGE_LOOP.md` | M1–M6: farming year, geography (fisher, hunter, high water, wolves), ambitions, trade, defense, wool | **Current, Implemented.** The most accurate design doc for what is built. |
| `AUTONOMOUS_OCCUPATIONS.md`, `OCCUPATION_RECONSIDERATION.md`, `WORKPLACE_CHOICE_INVESTIGATION.md` | How families choose work; shared land | **Current, Implemented** (Priority 5). |
| `HOUSEHOLD_SELF_SUFFICIENCY.md` | Secondary work, larders, proficiency | **Current, Implemented.** Its header still says "Not merged"; `HANDOFF.md` says it was merged on 2026-11-01. The header is stale. |
| `TOWN_BUILDING_MODEL.md` | Construction, logistics, paths, woodland, tilling, fences | **Current, Implemented.** |
| `TOWN_MAP.md`, `REGIONAL_MAP.md`, `WORLD_MAP.md` | Map scales and tile data | **Current.** The world/regional maps carry geography only; their economic and political layers are Planned. |
| `FAMILY_INFLUENCE_PROTOTYPE.md`, `COMMUNITY_PRIORITIES.md`, `GUIDING_WISDOM.md`, `HOME_SITES.md` | The player's levers and the commons-versus-own split | **Current, Implemented.** |
| `TREASURY_AUDIT.md`, plus branch `docs/property-and-communal-resources` | Household property, private exchange, treasury | **Planned and agreed, not built or authorized.** |
| `archive/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md` | Describes the code's resources, labor and trade | **Outdated** (last edited 2026-10-20). It predates land, trade, wool, larders and family choice. |
| `GOODS_AND_PRODUCTION_EXPANSION_MODEL.md` | Planned goods (wheat, bread, fish, planks, clay, pottery…) | **Speculative/partial** (2026-05-30). Its stone and craft chain exists in code; most of its goods don't. |
| `GOODS_DEMAND_AND_NEED_BUCKETS_MODEL.md`, `soft_need_consumption_model.md` | Need buckets | **Partially implemented** (May 2026). The buckets exist; only food, household goods and clothing are consumed. |
| `goods_quality_preference_modifiers_plan.md`, `household_home_inventory_plan.md` | Quality grades, home inventories | **Planned only** (May 2026). Larders are the only household inventory built. |
| `archive/MONEY_OBLIGATION_AND_CITY_CREDIT_MODEL.md` | Credit and currency | **Mostly superseded** by `ECONOMY_MODEL.md`. |
| `CULTURE_AND_VALUES_MODEL.md` | Values and callings | **Current draft.** Its economic effects are partly built (section 6). |
| `SETTLEMENT_GROWTH_SCALE_MODEL.md`, `SIMULATION_SCALE_MODEL.md`, `map_and_settlement_scale_audit.md` | Scale bands and aggregation | **Current direction, Planned** beyond one town. |

---

## 2. Geographic resources

### Where geography lives

| Layer | What exists | Used by the economy? |
|---|---|---|
| **World atlas** (`WorldGenerator`) | Continents, climate, kingdoms placed at generation | **No.** It feeds the regional map only. There are no world-scale resource or trade flows. |
| **Regional map** (`scripts/world/region_map_generator.gd`, `regional_chunk.gd`) | Tile types (grass, hill, mountain, river, lake, sea), `is_fertile`, `has_forest`, `resource` ∈ {none, stone, iron}, `has_road`, climate | **Only indirectly.** It is magnified into the town map at founding. `SettlementSiteProfile` reads it for tags, but only the `crossroads` tag affects play (`TownTrade.find_link`). Every other tag is display/debug. |
| **Town map** (`LocalCityMapGenerator`, 64×44) | Per tile: `type` (ground, water, rough), `has_trees`, `is_fertile`, `water_kind` (river, lake, sea), `resource` (none, stone, iron), `has_road`, `is_hill`, `occupied`, `path_level` | **Yes.** This is the only layer where resources physically exist and matter. |

### Inventory

| Resource | Map representation | Availability conditions | Renewable? | Depletion/regeneration | Status |
|---|---|---|---|---|---|
| **Farmland** (`is_fertile`) | Town tile | Regional fertile land (near water), plus arable pockets scaled by climate warmth × moisture (6–34% of open land; half that on hills). Floor of 18 tiles. Can be **made** by tilling (`TownFarmland`). | Effectively permanent | **Never depletes.** No soil exhaustion. Lost only by building on it. | Implemented [code: `local_city_map_generator.gd add_arable_land`, `ensure_floors`] |
| **Woods** (`has_trees`) | Town tile | Regional forest field plus copses. Floor of 90 tree tiles. | Yes | Felled by woodcutters and gatherer's camps (marked tiles 2 work-days each; unmarked trees at 10% of a day). Spreads yearly onto adjacent open land (1–4% chance per tile). Player can **Keep** woods (binding). | Implemented [code: `town_woodland.gd`] |
| **Timber as output** | Abstract (`wood`) | A woodcutter needs trees within its radius **at placement** only. | **Effectively unlimited** | Output doesn't fall as trees go. `get_felling_factor` lowers it only when the nearest trees are *kept* and free ones are farther away; with no trees on the map it returns 1.0. | Implemented [code: `town_woodland.gd:154`, `town_land.gd get_output_factor`] |
| **Game** (hunting) | Abstract; derived from wooded tiles within 6 tiles of the lodge | Requires trees within 3 tiles at placement. Full yield at 40 wooded tiles in reach. Autumn/winter ×1.2/1.1. | Yes, via woods | **Indirectly depletable:** felling lowers the woods count and so the yield, down to a 25% floor. No animal population is modelled. | Implemented [code: `town_land.gd`] |
| **Fish** | Abstract; derived from water tiles within 3 tiles of the hut | Fisher's hut must touch water on a side. Full yield at 12 water tiles. The same all year. | Unlimited | **No depletion.** No stock, no overfishing. | Implemented |
| **Pasture** | Abstract; open, unbuilt, treeless ground tiles within 3 of the fold (hills count double) | Full yield at 90 tiles. Shrinks as land is built on or wooded. | Yes | Not grazed down; it only shrinks with land use. | Implemented |
| **Water** (river, lake, sea) | Town tiles with `water_kind` | From the regional map | N/A | Static. Blocks building and walking. | Implemented. Drinking water is **only an errand** (it wears paths); there's no water good or need. |
| **Flowing water** (river, lake) | Same | | | Enables **high water** (33% of springs; fields beside it yield 40% in spring) and **river trade**. | Implemented |
| **Stone deposits** | Town tiles `type: rough`, `resource: stone`; regional `resource: stone` | Regional clusters magnified | N/A | **No building uses them.** Rough tiles block every placement. The quarry needs no stone. `HANDOFF.md` lists "quarries on stone" as an unbuilt decision. | **Partial: map only** |
| **Iron deposits** | Same, `resource: iron` | Regional clusters | N/A | **Nothing uses iron.** No ore, metal or mine. Shown in the site survey only. | **Partial: map only** |
| **Hills** (`is_hill`) | Town tile | Regional hills | N/A | Travel ×1.4, half the arable share, double pasture | Implemented |
| **Rock / mountain** (`type: rough`) | Town tile | Regional mountains, steep hills | N/A | Impassable to building; travel ×3 | Implemented |
| **Roads** (`has_road`) | Town tile; regional roads | Regional road field | N/A | Travel ×0.5. A road reaching the map edge links the town for trade. | Implemented |
| **Climate** | `SettlementSiteProfile.climate` | From regional terrain | N/A | **Only sets the arable share** and the palette. Frozen ground refuses founding. No climate effect on yields, seasons or needs. | Partial |
| **Seasons** | Calendar | Same everywhere | N/A | Farm 0.8/1.0/1.4/0.8; hunt 0.9/0.8/1.2/1.1; winter felling ×2; wolves in winter. Not climate-dependent. | Implemented |
| Clay, sand, salt, fruit, wild plants, herbs, minerals other than stone/iron | — | — | — | — | **Not found** |

**Differences between starting locations:** yes, all town-map resources come from the site [code]. `SiteSurvey` thresholds (`scripts/world/site_survey.gd`) record the real spread: fertile tiles 118–1196 (median 364), tree tiles 90–2115 (median 290). `HANDOFF.md` notes most towns have no water.

**Competition between families:**
- **Woods, fishing water and pasture are shared** [code: `TownLand.count_share`, owner 2026-11-02]. Each tile in reach of several working workplaces of the same kind is divided among them. Planned claims count when a family judges a new site. Empty or idle workplaces take no share.
- **Farmland is exclusive by footprint:** one field per 3×3, plus family gardens claimed in id order [code: `HouseholdEconomy.get_garden_land`].
- **Land itself is contested** when scarce: `FamilyInitiative.contest_for_land` → `TownSocial.contest_land`.
- Woodcutters don't share or compete for timber, since their output is fixed.

---

## 3. Town resources and commodities

Everything is held in **one town-wide dictionary**, `City.resources` (`city.gd make_starting_resources`). It holds integer counts with no units beyond "a unit". Food is 1 unit = 2 people for 1 day (`PEOPLE_FED_PER_FOOD`). Fractional output carries per building (`Building.output_carry`).

| Commodity | Category | Origin | Produced by | Consumed by | Stored where | Quality/tier |
|---|---|---|---|---|---|---|
| `food` | Consumable | Fields, water, woods | Farm/forager's garden; fisher/fish weir; hunter/snare line; family gardens (to its larder) | Eating (hard need) | Common store; **family larders** (garden food only) | None. Grain, fish and game are all one `food`. |
| `wood` | Raw | Woods | Woodcutter/gatherer's camp; families' secondary wood gathering | Construction, fences, toolmaker (2/tool), brickworks, lime kiln, carver, tileworks | Common store; gathered wood goes **first to the family's own site** | None |
| `tools` | Tool/intermediate | Wood | Toolmaker/tool mender | Upkeep (1 per 16–24 days per proper workplace), construction, sculptor, carver | Common store; family **mending** (a private, non-tradable upkeep credit, max 2) | **None.** One tool type, no tiers or grades (Planned in `goods_quality_preference_modifiers_plan.md`) |
| `wool` | Raw/consumable | Pasture | Herder's fold/grazing pen | Clothing need (worn as-is) | Common store | None |
| `clothing` | Finished | — | **Nothing** | Clothing need | Common store (always 0 unless a test seeds it) | — |
| `stone_blocks` | Raw | **Nothing** (the quarry needs no deposit) | Quarry | Stonecutter, lime kiln, mortar yard, paver yard | Common store | None |
| `cut_stone` | Intermediate | stone_blocks | Stonecutter | Mason yard, sculptor | Common store | None |
| `bricks` | Intermediate | **Wood only** (no clay) | Brickworks | Tileworks | Common store | None |
| `lime` | Intermediate | stone_blocks + wood | Lime kiln | Mortar yard | Common store | None |
| `mortar` | Intermediate | lime + stone_blocks | Mortar yard | Mason yard | Common store | None |
| `masonry` | Finished | cut_stone + mortar | Mason yard | **Nothing.** Construction buckets aren't resolved and no building costs it. | Common store | None |
| `statues` | Finished | cut_stone + tools | Sculptor | Household-goods need | Common store | None |
| `carved_goods` | Finished | wood + tools | Carver | Household-goods need; trade | Common store | None |
| `tiles` | Finished | bricks + wood | Tileworks | Household-goods need | Common store | None |
| `paving_stones` | Finished | stone_blocks | Paver yard | **Nothing.** The civic bucket isn't resolved. | Common store | None |

Population/shelter counters (`housing_capacity`, `sheltered_population`…) also sit in `resources`. They are bookkeeping, not goods.

**Need buckets** (`goods_need_bucket_helper.gd`; resolved in `City.consume_food` and `City.resolve_soft_needs`):

| Bucket | Demand | Goods that satisfy it | Effect of shortage | Status |
|---|---|---|---|---|
| Food | population ÷ 2 per day | food | Lost workdays (1 in 4); hunger counted per family; hardship and departures; drives occupation choice | Implemented (hard need) |
| Household goods | 1/day per **housed** family | tiles, carved_goods, statues (in that order) | Migration attractiveness only (met +, unmet −) | Implemented (soft) |
| Clothing | ceil(people/90)/day | clothing, wool | Migration attractiveness; family work choice ("the town goes without") | Implemented (soft) |
| Tools, construction materials, maintenance materials, civic goods | — | mapped | Not resolved | **Partial: mapping only** |

**Answers:**
- **Tracking:** aggregated by type, town-wide. Goods physically move only as hauling **effort** (`TownLogistics.get_travel_share`). Stores hold no per-store inventory [inferred from the single dictionary; storehouses shorten trips].
- **Quality, tiers and grades:** none for goods. Tiers exist only for **buildings** (tier 0 hand work at 1/3 output, no upkeep; tier 1 proper work).
- **Spoilage and decay:** **none.** Food, wood and wool keep forever. Only building condition decays (upkeep).
- **Private inventories:** **partial.** A family has a food `larder` (filled only by its own garden or a gift), `gathered_wood` (a fraction until delivered), and `mending`. Everything a primary holding produces goes **straight into the common store** [code: `City.apply_input_output_production`]. Household property beyond this is Planned (`docs/property-and-communal-resources` branch).
- **Entry to the stores:** automatic and unconditional for primary work. A family's choices touch only its secondary output and its larder's target.
- **Accumulation:** unbounded. There are no storage caps, and surplus has no use except trade and bandits' temptation (`TownDefense`).

---

## 4. Workplaces and industries

Output figures are per worked day for a two-adult family before modifiers. Tier 0 is 1/3 of that with no upkeep. Each workplace has one family. All workplaces are built (nothing is naturally available) through `TownConstruction`.

| Workplace (tier 0 → 1) | Required terrain/resource | Labor | Inputs | Outputs | Tools (build / upkeep) | Ownership | Limiting factors |
|---|---|---|---|---|---|---|---|
| Forager's garden → **Farm** (3×3) | ≥1 fertile tile in footprint | 1 family | — | food 4.0 × season | 1 / 1 per 24 d | Worked by a family; output communal | Farmland; season; high water; trampling (up to −40%; fence it) |
| Gatherer's camp → **Woodcutter** (2×2) | Trees within the radius at placement | 1 | — | wood 6.0 | 1 / 1 per 20 d | Same | Kept woods only; wolves (camp) |
| Tool mender → **Toolmaker** (3×3) | Open ground | 1 | 2 wood/tool | tools 1.0 | 0 / 1 per 16 d | Same | Wood in store |
| Fish weir → **Fisher's hut** (1×1) | Water on a side | 1 | — | food 4.0 × water reach | 0 / default 20 d | Same | Water tiles in 3; **shared** with other huts |
| Snare line → **Hunter's lodge** (2×2) | Trees within 3 | 1 | — | food 3.5 × woods reach × season | 1 / 20 d | Same | Woods in 6; **shared**; felling; wolves |
| Grazing pen → **Herder's fold** (3×3) | Open ground | 1 | — | wool 1.0 × pasture reach | 0 / 20 d | Same | Pasture in 3; **shared**; wolves |
| **Quarry** (3×3) | **Open ground; no deposit needed** | 1 | — | stone_blocks 2.0 | 1 / 20 d | Player-built | Nothing geographic |
| **Stonecutter** | Open ground | 1 | 1 stone_block | cut_stone 2.0 | 1 / 20 d | Player-built | Inputs |
| **Brickworks** | Open ground | 1 | 1 wood | bricks 2.0 | 1 / 20 d | Player-built | Wood |
| **Lime kiln** (3×3) | Open ground | 1 | 1 stone + 1 wood | lime 2.0 | 1 / 20 d | Player-built | Inputs |
| **Mortar yard** | Open ground | 1 | 1 lime + 1 stone | mortar 2.0 | 1 / 20 d | Player-built | Inputs |
| **Mason yard** (3×3) | Open ground | 1 | 1 cut_stone + 1 mortar | masonry 2.0 | 2 / 20 d | Player-built | Inputs |
| **Sculptor** | Open ground | 1 | 1 cut_stone + 1 tool | statues 2.0 | 2 / 20 d | Player-built | Inputs; consumes tools |
| **Carver** | Open ground | 1 | 1 wood + 1 tool | carved_goods 2.0 | 1 / 20 d | Player-built | Consumes tools |
| **Tileworks** | Open ground | 1 | 1 brick + 1 wood | tiles 2.0 | 1 / 20 d | Player-built | Inputs |
| **Paver yard** | Open ground | 1 | 1 stone_block | paving_stones 2.0 | 1 / 20 d | Player-built | Inputs |
| Family garden (secondary) | 2 free tiles within 3 of home (fertile full, plain ½) | 10–30% of a family's day | — | food at 1/3 farm rate × season × land → **own larder** | — | **Family's own** | Ground near home; claimed in id order |
| Wood gathering (secondary) | Woods within 4 of home (full at 6) | 10–30% | — | wood at 1/3 rate → own site, else store | — | Family's own effort | Trees near home |
| Mending (secondary) | Holding needs upkeep | 10–30% | — | upkeep credit (max 2) | — | Family's own | — |
| Watch post, storehouse, house/hut, fences, roads | Open ground | Build only | Wood (+tools) | Guard / shorter hauling / shelter / no trampling / travel | | Player or family | — |

Sources: `economy_balance.gd PRODUCTION, BUILD_COSTS, MAINTENANCE_*`; `ui/building_placement.gd validate`; `city.gd get_base_building_output_amount`.

**Constructed vs natural:** everything is constructed. Hand-work stages have no material cost.

**Which families establish autonomously** [code: `FamilyInitiative.get_occupations`]: only trades with a hand-work stage: farm, woodcutter, toolmaker, fisher, hunter, herder. Families open the tier 0 version near home and later decide to improve it. **The ten stone and craft workplaces can't be chosen by families.** The player builds them and a family is assigned (`TownConstruction.find_family_for_workplace` / auto-assignment).
- *Doc discrepancy:* `HANDOFF.md` open decision 3 says herding, fishing and hunting "can't be chosen by families". The code now has hand-work stages for all three (`building_tiers.gd`). That item is stale.

**How occupations are chosen** (`FamilyInitiative.get_work_desire`): a sum of reasoned terms plus seeded noise (±0.75).
- **Calling:** +3 for a match, −2 for a poor one, fading with hardship. Comfort goods like wool lose the calling entirely as hunger nears.
- **Town need by good:**
  - food: the coverage/ratio terms;
  - wood/tools: counts of producers and stock thresholds;
  - other goods: whether anyone makes it, and whether its need goes unmet.
- **Essential shortage:** within 90 days, and only when no one makes the good.
- **Land in reach** against the best output of that good.
- **Survival:** hunger danger × the work's real food relief.
- **Known work:** up to +2.
- **The player's levers:** community priority, focused appeal, guiding wisdom.

**Reconsideration** is rare and monthly (`OccupationReview`).

**Productivity** (`City.apply_building_output_modifiers`), multiplied together:
- base output;
- labor (working adults ÷ 2);
- the day left after travel, building spare time and secondary work (`get_work_time_factor`, travel ≤60%);
- proficiency (0.6 for a novice → 1.0 established);
- (1 − trampling);
- land and season (`TownLand.get_output_factor`);
- militia call-up (0).

Then the culture percent (calling ±25, work-ethic values, capped ±30), then the condition steps. Hunger skips 1 day in 4.

**Tools and condition:** condition drops 25 per missed upkeep. At 75–99 a workplace loses 1 day in 4; at 50–74, 1 in 2; at 25–49 it works 1 day in 4; at 0 it stops. With the influence model's hand-method fallback, a workplace below 50 works by hand at 1/3 instead. A family's mending replaces a tool.

**Competition for the same resource:**
- Hunters, fishers and herders divide their land (shared reach).
- Hunters also compete *indirectly* with woodcutters, who fell the woods hunters rely on.
- Farms, gardens and folds compete for open land.
- Processing chains compete for **wood** (toolmaker, brickworks, lime kiln, carver, tileworks, construction) and **tools** (upkeep, sculptor, carver). Whichever building ticks first takes it; there is no allocation [code: building order in `City.tick`].

**Proximity and travel:** yes. Hauling and walking to work take up to 60% of the day; terrain, paths and roads change effort; site choice weighs distance to home and store against land yield.

**Recovery after harvesting:** woods respread slowly. Fish, game and pasture have no stock to recover.

**When inputs run short:** output is capped at what the inputs allow (`apply_input_output_production`) and the family's labor is lost that day. The UI flags it (`production_requirement_helper.gd`).

---

## 5. Production chains

| Chain | Raw resource | Extraction | Intermediate processing | Final product | Final use | Completeness |
|---|---|---|---|---|---|---|
| Grain | Farmland | Farm / garden | — | food | Eating | Complete |
| Fish | Water | Fisher | — | food | Eating | Complete |
| Game | Woods | Hunter | — | food | Eating | Complete |
| Timber | Woods | Woodcutter / gathering | — | wood | Building, fuel for processes | Complete. Timber is unlimited. |
| Tools | (wood) | — | Toolmaker: 2 wood → 1 tool | tools | Upkeep, building, sculptor, carver | Complete. **The central feedback loop.** |
| Wool | Pasture | Herder | (spun at home, abstract) | wool | Clothing need | Complete but shallow. `clothing` has no producer. |
| Stone | **none** | Quarry (no deposit) | — | stone_blocks | Feeds 4 workshops; trade | **Source is ungrounded.** |
| Cut stone → masonry | (stone) | — | Stonecutter; lime kiln → mortar yard; mason yard | masonry | **None** | Dead end |
| Statues | (stone) | — | Stonecutter → sculptor (+tool) | statues | Household goods | Complete (soft need) |
| Paving | (stone) | — | Paver yard | paving_stones | **None** | Dead end |
| Bricks → tiles | **wood (no clay)** | — | Brickworks → tileworks (+wood) | tiles | Household goods | Complete, but not geographically grounded |
| Carving | wood | — | Carver (+tool) | carved_goods | Household goods; trade | Complete |
| Iron | Iron deposit (map) | — | — | — | — | **Not found** |

| Process | Inputs | Input qty | Output qty | Labor | Tools | Bottlenecks |
|---|---|---|---|---|---|---|
| Farming | Fertile footprint | — | 4.0 food/day × 0.8/1.0/1.4/0.8 | 1 family | 1 per 24 d | Season, high water, trampling |
| Fishing | Water in reach | — | 4.0 × reach (≥0.25) | 1 | 1 per 20 d | Shared water |
| Hunting | Woods in reach | — | 3.5 × reach × season | 1 | 1 per 20 d | Felling, sharing, wolves |
| Herding | Pasture in reach | — | 1.0 wool × reach | 1 | 1 per 20 d | Pasture, sharing |
| Woodcutting | (trees at placement) | — | 6.0 wood (+felling work, ×2 felling in winter) | 1 | 1 per 20 d | Kept woods |
| Toolmaking | wood | 2 per tool | 1.0 tool | 1 | 1 per 16 d | Wood; few towns staff it (the tool gap) |
| Quarrying | — | — | 2.0 stone_blocks | 1 | 1 per 20 d | None |
| Stonecutting | stone_blocks | 1 | 1 (at 2.0/day) | 1 | 1 per 20 d | Quarry |
| Brickmaking | wood | 1 | 1 | 1 | 1 per 20 d | Wood |
| Lime burning | stone_blocks, wood | 1, 1 | 1 | 1 | 1 per 20 d | Two inputs |
| Mortar | lime, stone_blocks | 1, 1 | 1 | 1 | 1 per 20 d | Lime kiln |
| Masonry | cut_stone, mortar | 1, 1 | 1 | 1 | 1 per 20 d | Three upstream shops |
| Sculpting | cut_stone, tools | 1, 1 | 1 | 1 | 1 per 20 d | **Eats tools** |
| Carving | wood, tools | 1, 1 | 1 | 1 | 1 per 20 d | **Eats tools** (2 tools a day at full rate, vs 1 made per toolmaker) |
| Tilemaking | bricks, wood | 1, 1 | 1 | 1 | 1 per 20 d | Brickworks |
| Paving | stone_blocks | 1 | 1 | 1 | 1 per 20 d | — |
| Garden / gathering / mending | Land near home | — | 1/3 of the trade's rate × share | 10–30% of a day | — | Land near home |

**Dependencies:** every tier 1 workplace depends on the **tool chain**, so tools depend on wood, wood on the woodcutter, and all of it on families staffing them. Stone workshops depend on the quarry. Tiles depend on bricks, which depend on wood. Sculptor and carver draw on tools.

**Loops:**
- **Tools ↔ upkeep** is a positive feedback loop: no tools leads to failing workplaces, which leads to less output. Hand-work fallback and mending dampen it.
- **Food ↔ labor:** hunger leads to lost workdays, which leads to less food. Survival-weighted job choice dampens it.
- **Woodcutting ↔ hunting:** felling lowers the hunting yield.

**Upstream-less commodities:** `stone_blocks` (no deposit), `bricks` (no clay), `clothing` (no producer at all).

**Produced with little downstream use:** `masonry` and `paving_stones` (no use at all); `lime` and `mortar` (only toward masonry); `statues`, `tiles` and `carved_goods` (only the soft household-goods need, which affects migration attractiveness only); surplus food and wood (no storage limit, spoilage or other sink besides trade).

---

## 6. Household economic behavior

The principle holds in code: **the player controls the commons** (stores rule and reserves, community priority, appeals, wisdoms, kept/cleared woods, residential land, what to build), **and families decide their own** work, improvements, secondary time, larder and sharing.

| Question | Behaviour | Simulated or simplified |
|---|---|---|
| What to produce | Scored choice per trade with reasons (section 4) | Simulated |
| Priorities | Survival first as hunger nears; then calling and known work; town shortages; land quality; community asks. Comfort goods fade fully under hunger. | Simulated |
| Values → occupation | Calling (+3/−2); risk, ambition and thrift axes; `town_loving` / `open_country` move site choice; `self_reliant`, `thrifty`, `common_stores`, `sharing`, `private_holdings` move secondary work and larder size | Simulated |
| Values → output | Calling ±25%, work-ethic values (steady +5, expedient +10, perfectionist −10, surging, communal labor), cap ±30 [code: `culture_effects.gd`] | Simplified (flat percents) |
| Values → consumption or product preference | **Not found.** Everyone eats the same; household goods are taken in a fixed order | Not modelled |
| Access to what they don't produce | **The common store**, unconditionally. No exchange between families. | Simplified: a commons economy |
| Surplus | Goes to the common store. Only garden food can stay private (larder above target is eaten first, sparing the store). | Partial |
| Lacking essentials | The family goes short → hunger days, lost workdays → hardship → departure. Neighbours may share larder food (`TownSocial.share_in_shortage`, weighted by disposition). Survival steers work choice. | Simulated |
| Specialization | Yes: one holding per family, proficiency (learned over about 360 days, decays over about 1440, partly inherited, related trades transfer 25%) | Simulated |
| Dependency between households | **Only through the commons.** A toolmaker family supports everyone's upkeep, but no family depends on *another family*, since there's no exchange, price or obligation. | Abstracted |

---

## 7. Geographic differentiation

| Characteristic | Current gameplay effect | Industries affected | Long-term consequences | Status |
|---|---|---|---|---|
| Farmland amount | Where and how many farms fit; garden quality | Farming, gardens | Big. Towns on limited farmland lean on fish and game, and found less reliably. | Implemented |
| Climate | Arable share only | Farming | Indirect, through farmland | Partial |
| Forest | Woodcutter placement; hunting yield; wood gathering; wolves; travel cost; spreading | Wood, hunting | Woods can be farmed out for game but never for timber | Implemented |
| Water | Fishing (yield by water in reach, shared); high water on fields; river trade link; blocks land | Fishing, farming, trade | Fishing towns are viable and distinct, though sharing lowers catches by up to 45% | Implemented |
| Pasture and hills | Wool yield; hill pasture ×2; travel ×1.4 | Herding | Small. Wool only feeds a soft need. | Implemented |
| Stone deposits | **None** (display, blocks land) | — | None | Partial (map only) |
| Iron deposits | **None** | — | None | Partial (map only) |
| Rough ground | Blocks building; travel ×3 | All (via layout) | Layout and travel costs | Implemented |
| Roads | Travel; trade link (crossroads 20 d, road 30 d, river 45 d, isolated none until a road is built) | Trade, defense (bandit odds follow the link) | Trade frequency and raid risk | Implemented |
| Travel distance | Up to 60% of a family's day; site choice | All | Layout matters within a town | Implemented |
| Resource competition | Shared reach for woods, water and pasture | Hunting, fishing, herding | Caps how many of each a site supports | Implemented |

1. **Can identical settlements diverge because of geography?** *Partly.* The **food base** differs: grain versus fish versus game. Food work, layout and founding odds differ substantially. But everything above food (wood, tools, the whole stone and craft tier) behaves the same on every site.
2. **Exclusive resources or industries?** Only **fishing** (needs water) and, weakly, **hunting** (needs woods; every town has a 90-tree floor). Farmland has an 18-tile floor. **No industry is exclusive.** The quarry runs anywhere, and stone and iron deposits do nothing.
3. **Does geography encourage specialization?** Within food, yes: families weigh land in reach, so lake towns fish and forest towns hunt. There's no export specialization, because nothing is scarce enough elsewhere to matter.
4. **Can scarcity make strategies impractical?** For food work, yes (little water, little game, little pasture). For crafts and construction, no. Timber is unlimited and stone is placeless.
5. **Advantages beyond productivity modifiers?** Some: high water and wolves are hazards; travel and layout costs; trade-link frequency and bandit exposure; contested land. Most other effects are yield multipliers.
6. **A reason for future trade between settlements?** **Not yet.**
   - The trader's wants and offers are random picks from fixed lists, valued at fixed grain prices (`EconomyBalance.VALUE_IN_GRAIN`). They don't depend on what either town's geography produces or lacks.
   - There is one neutral partner, and it is inert.
   - The geographic grounds trade could grow from already exist on the map: stone and ore that do nothing, towns with no water, and towns with limited farmland.

---

## 8. Current economic complexity

| System | Current depth | Meaningful player decisions | Household autonomy | Geographic influence | Major limitations |
|---|---|---|---|---|---|
| Resource diversity | 15 goods; 4 matter to survival (food, wood, tools, wool) | What to build | Low (6 chosen trades) | Food types only | One undifferentiated `food` |
| Production depth | Up to 3 steps (stone → cut stone + lime → mortar → masonry) | Which workshops | None for workshops | None | Deep chains end in nothing |
| Industry specialization | One holding per family; proficiency | Indirect levers | High | Food trades | Workshops aren't family-chosen |
| Household economics | Secondary work, larders, gifts, mending | Wisdoms, priority | High | Garden ground, nearby woods | No property, exchange or prices |
| Local scarcity | Food land, shared reach | Clear or keep woods; till | Medium | Strong for food | Timber and stone unlimited; no spoilage or caps |
| Geographic differentiation | Food base and layout | Founding site choice | — | Moderate | Deposits inert; climate shallow |
| Resource competition | Shared reach; inputs taken first-come | Few | Families weigh shares | Yes | No allocation among workshops |
| Consumption diversity | Food, household goods, clothing | Few | None (no preferences) | None | Soft needs only affect migration |
| Supply-chain dependencies | Tools ↔ upkeep central; stone/brick chains | What to build | Partial | None | The tool gap; carver and sculptor drain tools |

---

## 9. Summary

**A. What currently works well**
- **The tools/upkeep loop with hand-work fallback** is a real, readable dependency.
- **Food from the land.** Farms, fishers and hunters are driven by real tiles in reach, with seasons, hazards and **honest shared reach**.
- **Family-chosen work** with visible reasons, survival-weighting, proficiency and land judgment. Families respond sensibly to geography and shortage.
- **The commons/own split.** Larders, gardens, wood gathering, mending and gifts give families a small private economy without breaking the commons.
- **Physical layout:** travel, paths, trampling, felling and spreading, tilling.

**B. What is simplified or abstracted**
- One town-wide store; no per-store inventory; no spoilage or storage limits.
- One `food`; no quality or tiers of goods; one tool type.
- Timber unlimited per woodcutter; fish, game and pasture have no stocks.
- Soil never tires.
- Quarry and brickworks are ungrounded (no deposit, no clay).
- Soft needs affect only migration appeal.
- Values set flat output percents; there are no consumption preferences.
- No exchange between families; trade is player-picked barter with one random trader at fixed prices.

**C. What makes towns economically different today**
- The amount of farmland (and through it climate);
- water in reach (fishing, high water, river link);
- woods (hunting, wolves, gathering);
- pasture and hills (wool);
- road or river link (trade frequency, bandit risk);
- layout and travel costs;
- above all, **the families' callings and first work choices**. `HANDOFF.md` notes foundings are still decided by a few first-week choices.

Stone, iron and the regional site tags (other than `crossroads`) contribute nothing.

**D. What information we still lack**
1. **Workshop staffing:** how player-built stone and craft workshops are staffed in family-led towns in practice. I didn't trace auto-assignment and `OccupationReview` end to end; no balance run was made for this audit.
2. **Craft chains in sims:** whether any sim exercises the stone and craft chains. The `expanded_goods` test exists; its results weren't reviewed here.
3. **Order effects:** first-come input allocation among workshops. Building order in `City.buildings` decides it, and its practical effect is unmeasured.
4. **Neutral town:** whether it has any economy of its own to grow from. It appeared inert in the code I read.
5. **Regional yields:** whether regional tile data (climate, fertility, deposits) is meant to feed yields directly, or only through the town map. Docs say the town map *is* the region magnified, but `SettlementSiteProfile` measures are mostly unused.
6. **Owner decisions:**
   - quarries on stone (decided 2026-10-25, unbuilt);
   - the role of iron;
   - whether timber, fish and game should deplete;
   - whether `food` should split into kinds;
   - how the planned household property (unmerged branch) changes "surplus goes to the commons".
7. **Stale docs:** `GAME_VISION.md` and `FIRST_STAGE_LOOP.md` haven't been reconciled with family-led play; `archive/RESOURCE_HOUSEHOLD_LABOR_TRADE_MODEL.md` and the May goods docs are out of date.
