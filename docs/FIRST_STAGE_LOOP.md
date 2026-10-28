# First Stage Loop

The plan for a town's first stage, from founding to a stable village, and the terms on which it is built with less owner input. It sits under `docs/GAME_VISION.md` (which wins on conflict) and turns `docs/IMPLEMENTATION_ROADMAP.md` M4-M8 and `docs/SETTLEMENT_GROWTH_SCALE_MODEL.md` (stages 0-2) into one loop.

**Status: approved by the owner on 2026-10-27, with the amendments below folded in.** All nine decisions at the end are approved. Work proceeds through the six milestones in order without asking about individual features, routine implementation decisions, or balance adjustments that stay within this vision. Significant judgment calls and measured effects are recorded in the design docs and stay open to veto.

## The Principle

**We are not simply building a game about keeping a settlement alive. We are building a game about establishing a settlement capable of becoming something important** (owner, 2026-10-27).

Survival is the foundation. The rewards are thoughtful planning, economic development, specialization, prosperity, and eventually regional influence. The first stage should establish a satisfying loop that supports that long arc.

## Terms Of Working

- **Red lines.** Households stay the core unit (no anonymous worker slots). Nothing silently takes control away from the player. The pace stays slow and contemplative. Hardships are not tuned away to make numbers look good (`AGENTS.md`). No money, government, or warfare beyond village defense in this stage. `main` only after owner review.
- **Formulas may change to fix balance**, including in `city.gd` and `household.gd`, with before/after measurements recorded in the doc that owns them.
- **Freedom to improve.** If testing shows a mechanic causes excessive micromanagement, needless waiting, or dull play, it may be changed. Watch closely how family autonomy and direct player control interact as a town grows: the player should have meaningful control without having to manage every household activity personally.
- **Check-ins.** After each milestone, a short summary with screenshots, measured effects, and the judgment calls made (Milestone Log, below). **Owner playtest after milestone 6** (owner, 2026-10-27: the one after milestone 2 is dropped; work continues straight through): fun cannot be measured, but survival, pacing, variety, and the payoff of planning can.

## Planning Pays Off

**Meaningful town planning is a central requirement** (owner, 2026-10-27). The loop must reward thoughtful settlement planning, not only successful resource management.

- A well-planned settlement gains measurable advantages from its decisions: where buildings and homes stand, which land is cleared and tilled, which roads are laid, how close workplaces are to their resources and stores, and how the town's trades fit together.
- After several years, a player can look at their village and see how their planning shaped it: paths worn where people walk, fields on the land they tilled, a road that carried the town's trade, homes near the work of the families in them.
- **Use the existing systems first.** Travel time, worn paths, roads, terrain costs, fences, trampling, errands, felling and spreading woods, and tilling already make layout matter. New mechanics are added only where play shows a need.
- **Measured.** A planning check compares well-planned towns with careless ones on the same land: output, travel, growth, and prosperity after several years. A good plan should win clearly, and more than one plan should do well.

## The Loop

The player's year has a shape. Every season offers room to plan and develop, not just a new crisis; the land decides which opportunities matter most.

| Season | What happens | What the player decides |
| --- | --- | --- |
| Spring | Fields are sown; woods choose where they spread; rivers may run high; newcomers come when the town is a good place | What to clear and till; which plots to set aside; who works the new fields |
| Summer | Crops grow; good building weather; traders travel | What to build first; what to fence; whether to trade |
| Autumn | The harvest comes in; stores fill; woods finish growing | Whether the stores will last; what surplus to trade away |
| Winter | Little grows; firewood and food are spent; families plan and work indoors; felling is easiest | How to lay out next year (plots, clearing, tilling, roads); which families to help; what to prepare. Hardship is real, but winter is also the planning season |

Underneath runs what is already built: families who age, marry, and found new households, construction carried out by families, travel that costs work time, paths worn by use, errands to the store, water, woods, and kin, woods that are felled and spread back, and fields that are tilled, trampled, and fenced.

## Geography Shapes The Town

**Opportunities come from the land itself, not from a site's label** (owner, 2026-10-27). The site survey's tags (`SettlementSiteProfile`) describe a place; they do not decide what it can become. A town can have the traits of several site types at once (a forested river valley offers what both forests and rivers do), and what a town can develop depends on what lies within its reach on the town map.

| Where the land offers | Opportunity | Hazard, and its counter | The decision it creates |
| --- | --- | --- | --- |
| Water (a river, lake, or sea bank in reach) | **Fisher's hut** on the bank: food without farmland; clay from the banks later | **High water** some springs spoils low fields by the water; counter: farm higher ground, or fish instead | Farm the rich bank and risk the water, or fish and farm higher up |
| Rich farmland | Large harvests, surplus grain to trade | Neighbours notice a rich village: more bandit interest in later years; counter: militia | Grow for trade, or stay modest and safe |
| Woods | Timber; a **hunter's lodge** for food from the woods | **Wolves** threaten flocks, hunters, and gatherers near the woods' edge, never the stores; counter: fences, herding away from the woods, clearing a margin | Clear and fence, or live with the woods |
| Hills | Stone; **hill pasture** for a herder (wool for the clothing need) | Thin soil, colder winters; counter: pasture and trade instead of grain | Wool and stone to trade for grain |
| Rock and deposits | Stone and ore (quarries, the access rule decided 2026-10-25) | Long winters, bandits in the passes; counter: stores and militia | Invest in tools and stone early |
| A road or crossroads | **Traders come sooner and more often** | More bandits; counter: militia | Trade early and guard the stores |
| Open land, few woods | Wide farmland | **Little wood**; counter: trade for it, or plant woods (the reverse of clearing) | Plant woods or depend on trade |
| Far from roads | No bandits | No traders at first, slower newcomers; counter: a road out (below) | Grow alone, or build the link |

Each opportunity is one building or designation, available wherever the land has what it needs. Each hazard is a seasonal event with a visible cause and a counter. **No hazard alone ends a town, and hazards complement development rather than dominate it** (owner, 2026-10-27): the season's main business stays planning and building, with real but occasional hardship, not continuous crisis management. Several viable strategies should exist on any given land.

## The Way To Trade

Trade opens because the land makes the town good at something and short of something, not on a schedule.

1. **Surplus and shortage emerge** from the land: woodland towns have wood and want grain; open farmland has grain and wants wood.
2. **A trader visits** in summer along the regional road or river (sooner where roads meet) and offers barter with the neutral town, as `docs/ECONOMY_MODEL.md` decided: supply and demand on both sides, refusal possible, prices read in grain.
3. **Isolated towns start without traders, but not forever** (owner, 2026-10-27): building a road out to the regional road (or another link, such as a landing on a navigable river) brings traders.
4. **The first trade is a chronicle entry and a milestone record, not a requirement.** A developed, self-sufficient settlement reaches Village without trading (owner, 2026-10-27).
5. Later stages build on it: a merchant family responsibility, trade routes, and then the choice about coin. Those are out of scope here.

## Balance Targets

Measured by the balance tools on every milestone (`tests/sim/`), plus the new site variety and planning checks.

| Target | Measure | Today |
| --- | --- | --- |
| A sensible opening survives on most land | map luck, original and continuous maps | 46/48, 42/42 |
| Bad openings fail visibly but slowly, with a way back | opening check: queue-order and late-toolmaker openings | 13/20 (all wood on houses), 6/20 (toolmaker by day 150) |
| No random collapse from the tool cliff | 6 real-flow towns on one site, three seeds | 0-3 of 6 collapsed |
| Hamlet by year 1-3, Village by about year 3 | settlement growth run | not yet measured against stages |
| Travel costs a compact town 5-10% of its day, a sprawling one 10-20% | town building check | 6%, 10% |
| **Planning pays:** a well-planned town clearly outdoes a careless one on the same land after several years | new planning check | compact 19/20 and 43 people against scattered 14/20 and 31 people (two years) |
| **Towns differ:** the best opening differs between kinds of land, and more than one strategy works on each | new site variety check | not measured |

## Milestones

Each milestone is a feature branch from `develop` with tests, balance runs, screenshots, and doc updates, merged to `develop` when the gate passes.

1. **Balance foundation.** Fix the tool cliff (per-building upkeep grace, open decision 3 in `docs/HANDOFF.md`). Add the site variety and planning checks. Add a seasonal harvest: farms sow in spring and harvest in summer and autumn, and winter lives on stores, with winter work (felling, indoor crafts, planning) so it is not idle.
2. **Geography shapes the town.** First two opportunities (the fisher's hut and the hunter's lodge) and first two hazards (high water and wolves near the woods' edge), each with its counter, available wherever the land allows.
3. **Family ambitions (M4).** Three ambitions (a better home, a workshop for the family's calling, a fence or a field of their own) that feed satisfaction, departures, and newcomers, and that let families act on their own where the player has set the frame.
4. **The first neighbour (M6).** Visiting traders and barter with the neutral town, with prices in grain; a road out opens trade for isolated towns.
5. **Village defense (M5, light).** Bandit raids where the land and roads make a town tempting; militia from families; no army.
6. **Village completion (M8).** Stage display and chronicle; herder and wool for clothing; a pacing pass toward Village by about year 3. **Owner playtest.**

Later opportunities (clay and bricks, woods planted on open land, ore) follow milestone 2's pattern once it proves itself.

## Milestone Log

### Milestone 1: balance foundation (2026-10-27)

- **Upkeep grace per building.** Each new or upgraded workplace runs 60 days before it needs tools (`Building.upkeep_grace_days`), replacing the town-wide grace from founding. Alone it ends the tool cliff: a toolmaker built by day 150 now gets 19/20 towns off the ground (was 6/20).
- **The farming year.** Fields yield 80% in spring, 100% in summer, 140% in autumn, and 80% in winter (`EconomyBalance.FARM_SEASON_YIELD`), the same harvest over a year. Founders bring 300 food (was 60): enough to carry them through their first lean spring. Woodcutters fell twice as fast in winter, so winter has its own work. Towns know the calendar's day of the year.
- **Two new checks.** `tests/sim/planning_check.gd` (five years, careless / compact / planned) and `tests/sim/site_variety_check.gd` (four openings by kind of land).
- **Measured** against the start of the milestone:

  | Check | Before | After |
  | --- | --- | --- |
  | Map luck, original / continuous | 46/48, 42/42 | 48/48, 39/42 |
  | Opening: sensible / owner's first playtest / four farms first | 20, 20, 20 of 20 | 19, 20, 20 |
  | Opening: all wood on houses first / idle 60 days / toolmaker by day 150 | 13, 12, 6 | 17, 18, 19 |
  | Town building: houses / homes on plots / scattered | 19 (43 people), 19 (33), 12 (26) | 19 (46), 19 (36), 13 (29) |
  | Planning, five years: careless / compact / planned | | 13/20 (65 people), 19/20 (105), 18/20 (98) |
  | Different best openings across kinds of land | | 2 |

- **Tuning tried:** a sharp year (40/100/220/40%) starved towns founded in spring (map luck 32/48). 70/100/160/70% with 300 food still lost three sensible openings. 80/100/140/80% keeps the shape and the towns. The three continuous-map towns that fail are tool shortages with founders of few farming callings; watched in later milestones.
- **Findings for later milestones.** Planning pays: a compact town ends five years with 60% more people than a careless one. The stand-in's extra planning (storehouses beside far workplaces, homes beside work) does not add to that: storehouses cost 8 wood for a modest saving, and homes beside far workplaces spread the town and lengthen errands. Storehouse cost and value, and why homes cluster, are for the ambitions and village milestones. Openings barely differ by land yet (two best openings): milestone 2's purpose.

### Milestone 2: geography shapes the town (2026-10-27)

- **Fisher's hut** (Y, 1x1, 4 wood): stands beside water and catches up to 4 food a day, all year, by how much water lies within 3 tiles (12 tiles for a full catch, a quarter at least). **Hunter's lodge** (U, 2x2, 5 wood and a tool): stands near woods and brings in up to 3.5 food a day by the woods within 6 tiles (40 for a full bag), more in autumn and winter, less as the woods are felled. Both work for families of the water and the forest. Numbers in `EconomyBalance` (Land).
- **High water:** a third of springs, in towns with a river or lake, fields beside the water yield 40% of their spring harvest. **Wolves:** in winter, an unfenced lodge or gatherer's camp within 2 tiles of woods works at 75%; a fence answers them. Stores are never touched. Both show on the sidebar and on workplace cards. `TownLand` (`city.land`) holds all of it; saves keep it.
- **Fixed along the way:** newcomers' food estimate counted only farms, so towns fed by fishers and hunters turned families away.
- **Measured** (after raising the first guesses, fisher 3.5 to 4 and hunter 3 to 3.5, which made "land food first" viable on woods and water):

  | Check | Milestone 1 | Milestone 2 |
  | --- | --- | --- |
  | Map luck, original / continuous | 48/48, 39/42 | 48/48, 41/42 |
  | Opening: sensible / all wood on houses first / toolmaker by day 150 | 19, 17, 19 of 20 | 19, 17, 19 |
  | Town building: houses / homes on plots / scattered | 19 (46), 19 (36), 13 (29) | 19 (47), 19 (37), 12 (27) |
  | Planning, five years: careless / compact / planned | 13/20 (65), 19/20 (105), 18/20 (98) | 12/20 (59), 19/20 (106), 18/20 (100) |
  | Different best openings across kinds of land | 2 | 4 |

- **Judgment on variety.** The count of best openings rose to 4, but the leaders on each kind of land are within one or two people of each other, so the count overstates it. What clearly differs: opening on fishers and hunters works on woods and water (45-51 people, every town) and fails on plain and rock land (23 people, half the towns). Farms remain the safe opening everywhere. Real divergence will come from trade (milestone 4): what a town is good at decides what it can sell.
- **Not yet seen by eye:** the fisher's hut and lodge drawings (the screenshot catalog stands on dry plains, where neither can be placed). Worth a look in the owner's playtest.

### Milestone 3: family ambitions (2026-10-28)

- **Three ambitions** (`FamilyAmbitions`, monthly, before hardship): each family wants one thing at a time, the first that applies: **a proper home** (it lives in a tent, in the open, or in a hut), **its field fenced** (it works a field others walk through), then **work for its calling** (it works a holding its calling is not drawn to, and the town's land allows work it is drawn to: no fisher's hut wish without water). The house card says what a family wants and whether it is content; the sidebar sums up the town's wishes.
- **Contentment.** A fulfilled ambition adds 2 contentment (at most 4). Each point lets a family endure one more point of hardship before leaving, and every content family adds 3 to the town's monthly arrival chance (15 at most). Contentment lasts while a family has all it wants, and fades a point a year while it wants something. A wish waiting more than a year makes a family endure one point less; waiting for a home is left out, since rough housing already costs hardship.
- **Families act within the player's frame.** They fence their own trampled field when the stores can spare the wood (beyond the reserve families keep for homes). A family wishing for its calling swaps work with a family that holds such work and is not drawn to it, or takes up a free workplace when another family is free to take up what it leaves. Work the player assigned is never traded. Building calling work stays the player's decision.
- **Judgment calls, from measurement.**
  - A wish left waiting first added a hardship point a month. It also stopped recovery, so every long-waiting family eventually left: compact towns fell from 106 to 73 people. It is now a lower threshold (a strain), which makes hard times harder but drives no one out alone.
  - Contentment first faded on a clock, so after five years almost no family was content. It now fades only while a family wants something.
  - The fence wish comes before the calling wish: families can answer it themselves, so it should not wait behind a wish only the player can answer.
  - A family moving to calling work first left its old field empty when nobody was free, and a workplace built for a wish went to whichever family was free, not the one that wished for it. Answering wishes then cost a town a third of its people (72 against 105). The swap fixes both.
- **Measured** (the planning check gains a "wishes" plan: planned, and the stand-in builds the work families wish for, food work where the catch is good, only while some family has labor to spare):

  | Check | Milestone 2 | Milestone 3 |
  | --- | --- | --- |
  | Map luck, original / continuous | 48/48, 41/42 | 48/48, 41/42 |
  | Opening: sensible / all wood on houses first / toolmaker by day 150 / idle 60 days | 19, 17, 19, 18 of 20 | 19, 17, 19, 20 |
  | Town building: houses / homes on plots / scattered | 19 (47), 19 (37), 12 (27) | 19 (50), 19 (39), 11 (26) |
  | Planning, five years: careless / compact / planned | 12/20 (59), 19/20 (106), 18/20 (100) | 11/20 (61), 19/20 (114), 18/20 (109) |
  | Planning: wishes answered | | 18/20 (107), 3.4 content families against 1.9 |
  | Different best openings across kinds of land | 4 | 2 |

- **Variety fell back to 2 best openings** with the same leaders within a few people; farms first leads almost everywhere and land food leads by water. The count moves with near-ties and is not a signal on its own (milestone 2's judgment).
- **Finding for later milestones.** Answering wishes now costs nothing, but it does not clearly pay either: content families stay and draw newcomers, yet the town ends the same size. What a content family is worth beyond staying (better work, more children, values) is for the values work after this stage. A family's wish for its calling is also where trade and specialised work (milestone 4) can give it something to want.

### Milestone 4: the first neighbour (2026-10-28)

- **Traders.** In summer and autumn a trader from the nearest neutral town (named in the game, for example Callow Ford) comes to a linked town and stays 10 days: about every 20 days at a crossroads, 30 on a road, 45 by river. A town is linked when a road joins its heart to the map's edge (the regional road, or one the player builds with G) or a river runs within 12 tiles of its heart. An isolated town is told it needs a road out. `TownTrade` (`city.trade`); numbers in `EconomyBalance` (Trade); saved.
- **Barter with friction from supply and demand** (`docs/ECONOMY_MODEL.md`). Each trader wants three goods and offers two, valued in grain (food 1, wood 1.5, tools 10, stone blocks 3, bricks 4, cut stone 5, carved goods 8). It pays 85% of value and asks 115%, and each unit it takes or sells moves its price by up to half again over the visit. It takes only what it wants. The sidebar's Trader section shows its prices in grain and up to six lots ("Give 10 wood for 11 food"), one click each. Nothing trades without the player. The first trade and the count of trades are recorded on the sidebar; the chronicle (milestone 6) will carry it.
- **Judgment calls.**
  - Clothing is left out of traders' goods for now: the clothing need asks a unit per person a day, so a trader's lot would vanish in a day. Milestone 6 (herder and wool) settles what clothing is.
  - The stand-in for the "trading" plan builds a road out once it has 40 wood, and takes lots only to turn a surplus into a shortage.
- **Measured.** Of the planning check's 20 real sites, none has a regional road on its town map and 16 are tagged isolated, so every link was a road out the town built (17 of 20; on three no road could be planned to open ground at the edge). Over five years: about 18 trader visits and 6 trades a town.

  | Planning, five years | People | Towns off the ground | Content families |
  | --- | --- | --- | --- |
  | wishes (milestone 3) | 107 | 18/20 | 3.4 |
  | trading | 110 | 19/20 | 3.6 |

  Openings and map luck are unchanged from milestone 3 (sensible 19/20, idle 60 days 20/20, map luck 48/48 and 41/42): traders change nothing until the player trades.
- **Finding.** Trade is a modest help, as intended (not required for Village). It will matter more once towns have real surpluses and needs that only trade answers: clothing, and goods the land cannot give. The neutral town does not yet run out of stock or remember earlier trades; refusal is by wants only.
- **Seen by eye:** the Trader section in the real game (`game_trader` in `tests/visual/town_map_capture.gd`).

### Milestone 5: village defense (2026-10-28)

- **Bandits follow the roads.** From the second year, each month outside winter, a band may take the road toward a town traders can reach: 12% a month at a crossroads, 8% on a road, 4% by river, times how tempting the stores are (their worth in grain against 3,000, from half to double). Isolated towns see none: being far from roads is its own protection. A band is **seen on the road 10 days before it comes**, with its strength (2 times temptation, plus 0-1, at most 5). `TownDefense` (`city.defense`); numbers in `EconomyBalance` (Defense); saved.
- **The counters are families** (`docs/WARFARE_AND_CONFLICT_MODEL.md`): a **watch post** (O, one tile, 6 wood and a tool) kept by a family guards with 2 all year, and suits families of the shield; the **militia** (M, or the sidebar button) calls up 3 families, the shield first, never the watch's keepers, for 1 guard each. They leave their work until the band is dealt with, so their fields go unworked: a call-up at harvest is a real sacrifice.
- **A raid.** A band meeting enough guard is driven off. Otherwise it takes up to 30% of the food, tools, and wood, less in proportion to the guard it met, never the town's last 30 days of food, and every family loses a point of contentment. No raid alone ends a town; raids sap stores, not lives.
- **Measured.** Openings, map luck, and town building are unchanged (none of their towns has a road). In the planning check, where towns build a road out to trade:

  | Planning, five years | People | Towns off the ground | Raids (driven off) | Content families | Food in store |
  | --- | --- | --- | --- | --- | --- |
  | trading, milestone 4 (no bandits) | 110 | 19/20 | | 3.6 | 14,100 |
  | trading, undefended | 104 | 19/20 | 5.1 (0) | 1.1 | 8,800 |
  | defended | 99 | 18/20 | 5.2 (4.8) | 5.0 | 11,100 |

- **Judgment and finding.** A rich, linked town draws about a raid a year: rich stores tempt bands, as the land table says. Defending keeps stores and contentment but costs a family's work for the watch and the militia's days away, so a defended town ends with a few fewer people. That is a real choice, which the loop wants; it will lean toward defense once contentment and trust (a failure to defend, `docs/WARFARE_AND_CONFLICT_MODEL.md`) weigh more. The stand-in builds its watch post only once tempting or raided, and calls the militia whenever a band outnumbers its guard.
- **Seen by eye:** the warning, guard, and call-up in the sidebar (`game_bandits`), and the watch post in the building catalog.

## Approved Decisions

All approved by the owner on 2026-10-27, with the amendments above.

1. **A seasonal harvest.** Food comes mostly in summer and autumn; winter lives on stores, and is also the planning season.
2. **Upkeep grace per building** rather than from founding, to end the random tool-cliff collapses.
3. **Opportunities and hazards** as in the table, from the land within reach rather than the site's label, starting with the fisher, the hunter, high water, and wolves.
4. **No hazard alone ends a town;** each has a visible counter, and hazards complement development rather than dominate it.
5. **Trade opens with a visiting trader,** barter only with the neutral town: sooner where roads meet; isolated towns start without traders but can build a road out. Trade is not required for Village.
6. **Three family ambitions** as in milestone 3.
7. **Defense stays light in this stage:** raids and militia only.
8. **The milestone order** above, with the owner playtest after milestone 6.
9. **Site variety target:** the best opening differs between kinds of land, and more than one strategy works on each. Alongside it, the **planning target:** a well-planned town clearly outdoes a careless one.
