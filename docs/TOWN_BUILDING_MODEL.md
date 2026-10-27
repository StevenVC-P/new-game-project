# Town Building Model

How a town gets built: who decides where, who builds, what it costs, and why layout matters. Sits under `docs/GAME_VISION.md` ("you don't directly build an empire; you build a society capable of becoming one") and builds on `docs/TOWN_MAP.md` (the land) and `docs/ECONOMY_MODEL.md` (the goods).

First implementation 2026-10-26, from the owner's town-building brief. Settled by the owner: homes and workplaces stay separate (a nucleated village); construction takes builder families and time; goods physically move; no rigid slot caps; player and town-driven construction share one pipeline; tier 0 must never deadlock. Everything marked **judgment call** below was decided during implementation and is open to owner veto.

## How To Run And Check It

- **In the game:** in the town view, every building choice (1-0, Q-R, T storehouse) now plans a construction site rather than placing a finished building. P sets aside a residential plot; G lays a road (click both ends; Esc cancels); C marks woods for the woodcutters to clear (click both corners). Trails and paths wear on their own where families walk (Paths, below); a road is quicker ground that people use where it is the easiest way. A field's card offers a fence (Fields and fences, below). Click a site, plot, or building to see its card: a site shows its status, materials on site, work done, builders today, who asked for it and who pays, with "Build this first" and "Cancel". A workplace's card shows what travel costs it and how much of its way is on paths or roads, and the map draws its routes to the nearest store (gold) and from its family's home (blue). The sidebar's Construction section lists the queue.
- **Rules:** `tests/town_construction_validation.gd` (headless, synthetic town map): a request reserves land and pays nothing; the building appears only when built; sites wait for materials; more builders build faster; every site, tier 1 workplaces included, goes up from spare time even with every family at work; upgrades happen in place while the building keeps working; distance to a store and from home costs output; storehouses, roads, and worn paths cut it; walking wears a trail in a month and a path where traffic is heavy; routes bend onto worn ground; abandoned paths fade, and building over one ends it; open ground costs a tile a tile straight and 1.41 diagonally on the route grid; a route follows the line between two fields rather than crossing either; walking through a field tramples it and its harvest falls, while its own family does not count; a fenced field is walked around while its family and its fence's builders still get in; paths wear along the lines between yards; a way through woods wears at half speed, stays a trail, and keeps its trees; an island cut off by water loses the most; cancelling returns materials; families claim plots and build homes (huts when wood is short), then upgrade huts; values steer plot choice and home type; towns without a town map still build.
- **Terrain and woodland:** `tests/town_woodland_validation.gd` (headless, synthetic town map): what each ground costs; routes go around a small wood; a woodcutter clears marked woods nearest first and keeps producing; marking again unmarks; a gatherer's camp does not fell; forest expansion for a single wooded tile, a compact and a narrow forest, far woods adding nothing, blocked land (water, rock, fields, roads, trails; unfarmed farmland is open), the cap, the simultaneous yearly update, a lone tile spreading irregularly over 100 years, once a year in play, and a loaded town spreading the same.
- **Real flow:** `tests/town_map_view_validation.gd`: a click plans a site and the house later stands on that tile; the plot tool sets land aside and a house placed on it uses the plot; the clearing tool marks woods between two clicks with a preview; clicking a site selects it; a worked garden wears a trail and the view redraws the ground.
- **Balance:** `tests/sim/opening_check.gd` and `tests/sim/map_luck_check.gd` now play through the construction pipeline (the stand-in player plans buildings and the town builds them). `tests/sim/town_building_check.gd` compares three policies on real town maps: houses placed by the player, homes built by families on plots, and a scattered layout. Write their output to a file and filter it; piping Godot's household log through a shell pipe stalls Godot on Windows.
- **Screenshots:** `tests/visual/town_map_capture.gd` section 5: sites at every stage, plots, a site's card, a town grown with families building on plots, the trails and paths it wore (fitted and close), and a workplace's routes.

## The Pipeline

One pipeline for everyone (`scripts/domain/town_construction.gd`, `TownConstruction`, one per `City`):

1. **Request.** `request_building`, `request_upgrade`, `request_road`, `request_fence`, and `designate_plot` validate against the town map (`BuildingPlacement`, materials not checked) and reserve the land. Nothing is paid up front. Each project (`ConstructionProject`) records `requested_by` (player, household, town), the requesting family, and `funded_by` (today always `town_stores`; household wealth, the player's own capital, and public funds are later sources).
2. **Supply.** Builders carry the materials from the nearest store to the site (`TownLogistics`). Materials leave the stores only as each load arrives, so a site waits, with "waiting for 4 wood", while the stores are short, and the queue's order decides who gets scarce wood first.
3. **Build.** With every material on site, builders work off the project's family-days.
4. **Complete.** A new building becomes a real `Building` (a home's family moves in before anyone else is housed); an upgrade swaps the building's type in place; a fence closes its field; a road's tiles become road.

The queue is worked in order; the player can move a site to the front or cancel it (materials go back to the stores, the land is freed; a plot stays a plot).

### Who builds

- **Builders are families without a holding.** They work a site full time, up to a crew of 3 (2 for tier 0 and roads). Labor follows the same rules as a holding: a one-adult family does half, and calling and work ethic apply. Construction draws on the Stone and Forest callings (masons and carpenters), so a farming family is a slower builder. **Judgment call:** no separate builder responsibility or builder's yard yet; any free family builds, which keeps the founding hamlet's six families useful from day one.
- **Spare time.** A family working a holding still gives 20% of its day (`SPARE_TIME_SHARE`) to its own project (its home, or its workplace's upgrade), or else to the first site in the queue whose crew has room, and its holding makes 20% less that day. This is the floor that keeps any site from stalling for want of hands, with every family at work; a family free of a holding builds five times as fast, so freeing one is still the way to build quickly. Tier 0 also needs no materials, so a town short of wood can always raise huts, gardens, camps, and menders. **Judgment call:** an earlier version kept spare time to tier 0 and a family's own home; measured on real town maps, a fully employed town then never finished the spare houses that marriages and newcomers need and stopped growing, and a farm finishing could take a toolmaker site's only builder and leave the town without tools for good. Helpers cannot be turned off yet: a long queue costs output across the town.
- **Everything new is built for a family.** A house the player plans goes to the first family still in a tent or out in the open (else, for a proper house, a family in a hut), which works on it first. A new workplace goes to the free family best suited to it (the auto-assignment score: calling first), which builds it as its own, is not taken for other vacancies meanwhile, and works it the day it is done: a holding is a family's holding. **Judgment call:** measured on real town maps, without this a family leaving mid-build let the planned toolmaker's family be pulled onto the vacated farm; the toolmaker stood finished and empty, and the town ran out of tools and emptied.

### What it takes

All numbers are in `scripts/domain/economy_balance.gd` (Construction and Logistics sections).

| | Work (family-days) | Materials |
| --- | --- | --- |
| Hut, forager's garden, gatherer's camp, tool mender | 3, 2, 2, 3 | none |
| House, farm, woodcutter, toolmaker | 8, 6, 6, 10 | as before (`BUILD_COSTS`) |
| Storehouse (new) | 8 | 8 wood |
| Stone and craft buildings | 12 | as before |
| Upgrade in place | 75% of the tier 1 type's work | the tier 1 type's cost |
| Road | 0.25 per tile | none |

With six founding families a farm takes about two to three days, a house about three.

## Logistics

`scripts/domain/town_logistics.gd` (`TownLogistics`, one per `City`).

- **Stores.** The founders' stockpile sits on open ground at the town's heart (placed the first time the town map is used); storehouses add more. All stores share one stock, `City.resources`. **Judgment call / limitation:** separate inventories per store, and carts between them, are later work; today a storehouse is a second door to the same stock.
- **Routes run on the lines between tiles too** (owner, 2026-10-27). The route grid has a cell at half-tile spacing: one in each tile's middle, one on each line between two tiles, and one at each corner where four meet ((2W+1) x (2H+1) cells, 129x89 for a town). So people walk through a tile or along its edge: between two fields, along a fence, through the strip between two yards. Each step costs its length (half a tile, or 0.71 diagonally) times the effort of the cell it enters, so open ground still costs 1 a tile straight and 1.41 diagonally. Found with `AStarGrid2D`, once per layout change (a full rebuild takes about 40 ms); a path level changing updates only its cells. Routes are the cheapest there are: the grid's weights are divided by the cheapest effort, so its distance estimate never overshoots.
- **Nobody walks through buildings** (owner, 2026-10-27). A building, a building site (a home rising on a plot too), and the stockpile are closed to every route that does not start or end there: the family goes in at its own door, builders onto their own site, and goods into the store, and everyone else walks round along the strips between. Unfenced fields stay open (crossing one tramples it), and so do open plots.
- **A cell's effort.** A tile's middle costs the tile (the table below). A line or corner inside one footprint (between two tiles of the same field or yard) costs that footprint. Any other line or corner costs the cheapest margin beside it: built land and fields have an open margin as easy as their bare ground (1, or 1.4 on hill land), so the strip between two fields or two yards walks like open ground; other ground costs what crossing it does, so the line between two wooded tiles is still woods.
- **Terrain** (owner, 2026-10-27: travel is slowed by the ground it crosses, and routes generally avoid woods and uneven ground). A tile's effort is its terrain times its cover, then its wear:

  | Ground | Effort |
  | --- | --- |
  | Road | 0.5 |
  | Open ground | 1 |
  | Hill land (`is_hill`, sloping ground on the regional map's hills) | 1.4 |
  | Woods | 2 (was 1.5) |
  | Wooded hillside | 2.8 |
  | Fields and open plots (crossable; fields are trampled) | 2 |
  | Buildings, sites, the stockpile | closed, except to their own routes |
  | Rock | 3 |
  | Water | impassable |
  | Line between two different things (field margin, the strip between yards) | the cheapest side; built land counts as its bare ground |
  | Trail / path | 85% / 65% of the ground under it |

  A route around a small wood five tiles deep is cheaper than the straight line through it, so routes skirt woods unless the way around is long. **Judgment calls:** slope has no direction (uphill costs the same as down: the grid weighs tiles, not steps), and hill land is lit as rising ground on the town map so the player can see why routes avoid it.
- **Aggregated carrying, not per-item agents.** A workplace's family carries its output to the nearest store and its inputs back (`EconomyBalance.PRODUCTION` now holds the production chain the city uses), and walks from home to work. A family covers 500 effort-tiles in a day (`DAY_EFFORT_TILES`) and carries 5 units a trip (`CARRY_LOAD`). The trips become a share of its working day, capped at 60%, and its output drops by that share. A workplace no store or home can reach loses the full 60%.
- **Builders carry the same way:** each unit of material costs a moment to handle plus a round trip from the nearest store.
- Walkers on the map are cosmetic but walk the real routes (2026-10-27): each working family walks its route from home and back, one of it carries a load along the store route, and builders carry materials along a site's delivery route while it waits for them, then work on the site. So what the player sees walked is what wears the paths. Before, walkers slid in a straight line from home to work, through buildings, and nobody was drawn carrying goods, which made paths look unrelated to the walking.

What this means in play (measured in `tests/town_construction_validation.gd` on open ground): a farm 13 tiles from the stockpile, its family camped there, loses 10% of its day; one 26 tiles out loses 19%; a storehouse next to the far farm, or a road, cuts that by a quarter to a half.

**Why this shape.** It accounts for distance, travel time, and carrying capacity at a cost of a few path queries per layout change, so it scales to many towns, and it maps directly onto the Grouped and Summary levels (`docs/SIMULATION_SCALE_MODEL.md`): a district's travel share is the same formula over district-to-store distances. No universally optimal layout falls out: farms must sit on farmland and camps by woods wherever the map puts them, so the player trades store placement and homes against the land, and a compact town also wears its paths sooner.

## Paths

Owner direction (2026-10-27): people move faster on paths and roads, but rather than the player building roads, paths develop over time where people walk, and routing prefers the quickest ways. Code: `TownLogistics` (Paths); numbers: `EconomyBalance` (Paths).

- **Wear.** The trips the logistics model already charges for wear the ground they cross. Each working day a workplace's family walks from home and back (2 trips) and makes its carrying trips to the store; builders make a round trip for every 5 units they carry to a site. Each trip adds 1 wear to every route cell it crosses; wear fades by a sixtieth a day, so a cell settles near 60 times its daily trips. Open ground wears, and so do the lines and corners between things (a field's margin, the strip between yards). Water, roads, built or reserved ground, and the inside of a footprint do not.
- **Woods** (owner, 2026-10-27). A cell in woods (every tile it touches wooded) wears at half the rate and never past a trail. Wear never fells a tree.
- **Strips between buildings** (owner, 2026-10-27). A line or corner with built land on every side is a way between buildings: people walk it at open-ground cost, and it wears, but never past a trail. A line between a building and open land is open land and can become a path.
- **Trails and paths.** Wear 40 makes a trail and 150 a path; a tile falls back a level only below half of that, so paths do not flicker. A trail takes 15% off the ground's effort, a path 35% (open ground 1 becomes 0.85 and 0.65; woods and rock keep their extra cost in proportion). A road (0.5) stays quickest.
- **Routes follow them.** A level change is a layout change: routes are found again, bend onto the worn ground where it is quicker, and wear it further. Shared ground (the way into the stockpile, a lane past several farms) turns to path first; one family's walk to work alone stays a trail (2 trips a day settles at 120).
- **In play** (`tests/town_construction_validation.gd`, open ground): a woodcutter 25 tiles from the stockpile, its family camped there, wears a trail within 30 days and a path by 150; its travel share falls from 19.5% to 13.2% (a road on the same route: 11.5%). A path nobody walks is a trail again after about six weeks and grass after about four months.
- **On the map** (owner, 2026-10-27: up to one tile wide, and thinner): trails are a thin line of flattened, paler grass; paths are bare earth up to about a tile wide with a trampled verge. They are drawn from a mask at route-cell resolution, so a path along the line between two fields runs on that line. Shrubs and flowers keep off them. A workplace's card says how much of its way is on paths or roads.
- **Cost:** wear is added along routes already cached for the travel figures, once a day; levels change rarely, and only those days find routes again.

**Judgment calls**, open to owner veto:

- Only travel the model charges for wears paths. Builders' walks to their sites, and errands it does not model (fetching food, visiting), leave no trace.
- The road tool came back (owner, 2026-10-27): a fresh road influences where people walk but does not decide it. Roads are only quicker ground (0.5), so a route takes one where it is the easiest way and ignores one that is not.
- A route cell's path level is its own: a path along the line between two fields and one through the tile beside it are separate.
- Older saved games lose their worn paths: wear was kept per tile and is now per route cell (`docs/SAVED_GAMES.md`).

## Fields And Fences

Owner direction (2026-10-27): walking through a field should harm its yield, and fields can be fenced to keep people out. Code: `TownLogistics` (trampling, fenced cells), `TownConstruction.request_fence`; numbers: `EconomyBalance` (Fields).

- **Trampling.** A field is a farm or a forager's garden. Every route laid in a day (commutes, carrying, builders' deliveries) that enters another field's footprint (its tiles' middles or the lines inside it, not the lines round it) counts its trips against that field. Each daily trip costs the field 2% of its harvest, up to 40%, the next day. A field's own family, and routes that start or end in it, do not count. The field's card says what it lost ("Trampled: -6% harvest (3.0 trips a day through it)").
- **Fences.** Any field or building with an open yard can be fenced (owner, 2026-10-27): every building but a quarry, an open pit. "Fence the field" or "Fence the yard" on its card plans a fence: the family working or living there takes it on, materials are carried and it is built like anything else. Wood and work follow the fence's length (a wood per 3 tiles of edge, a sixth of a family-day per tile): a 3x3 field takes 4 wood and 2 family-days, a 2x2 house 3 wood and about 1.3. A fenced building closes its whole square, the lines and corners round it included, since the fence stands on its edge (owner, 2026-10-27): no route passes through it, along its edge, or between it and another fenced building, so fencing neighbours closes the strip between them. Only routes that start or end in it go in, so its own family and anyone building on it use the gate, and everyone else walks round on the tiles outside. The map draws posts as the fence goes up, then rails with a gap for the gate on the south side.
- **Judgment calls**, open to owner veto: trampling counts the routes the model already lays (no stray walkers); a fence costs no upkeep and is never torn down.

## Errands

Owner direction (2026-10-27): walking should not only join workplaces; more kinds of trips, which cultural values can shape later. Code: `TownErrands` (`city.errands`); numbers: `EconomyBalance.ERRAND_ROUND_TRIPS_PER_DAY`.

- **What families do.** Every family makes trips from home besides work: to the nearest store for food and goods every three days, to the nearest bank of a river or lake for water every day (where the town has water), to the nearest edge of the woods for firewood every four days, and to visit kin (the households it came from and the ones its children founded) once a week.
- **What they do to the town.** Errands wear paths and trample fields like any walking, so trails form to the water and the woods and between related homes. They cost the family's workplace nothing: they are the household's own time, not travel the working day pays for. In the test, a month of daily water trips wears a trail to the bank.
- **On the map.** One of each family is out on an errand, a different one each walk, and comes back carrying what it was for: a bucket of water, a bundle of firewood, or a sack from the store.
- **Values, later.** `TownErrands.get_rates` gives each family's rates and is the one place values will shape them (kin-minded families visiting more, town-loving ones going to the store more, families of the forest gathering more). Today every family keeps the same rates.
- **Cost.** Errand routes are kept until the layout changes, not each time a path level does, so many errands stay cheap.
- **Judgment calls**, open to owner veto: the rates; water every day dominates where a town has water, so paths to the bank are often a town's busiest; errands do not yet change what a family has (water and firewood are not goods yet).


## Woodland

Owner direction (2026-10-27): the woodcutter can be given woods to clear; trees try to grow back around the edges over a long time; well-worn paths stop them: paths in use win, unused paths give way. The owner then specified how woods spread (Forest expansion, below). Code: `TownWoodland` (`city.woodland`); numbers: `EconomyBalance` (Woodland).

- **Marking.** C (or Clear Woods in the build menu), then two clicks at opposite corners, marks every wooded tile in the block (at most 16 a side) for clearing. Marking a block that is all marked already takes the marks off. Marked tiles are tinted orange, deeper as felling goes on; the sidebar counts them and says when no woodcutter is at work.
- **Felling.** Each working woodcutter, of any tier (owner, 2026-10-27; a gatherer's camp at its tier's third of the pace), puts its day into the marked tile nearest it that a route reaches, as much of the day as travel and spare time leave. A tile takes 2 working days: one woodcutter clears a 3x5 block in about six weeks. Felling is where it cuts its wood, so its output is unchanged. A felled tile is open ground: buildable, and quicker to cross.
- **Unmarked felling** (owner, 2026-10-27). With nothing marked, a woodcutter slowly cuts the trees nearest it that a route reaches: a tenth of its day goes into felling, so a tile falls about every 20 working days (5 in its first 120 days in the test).
- **Tilling** (owner, 2026-10-27: clearing only clears; making land tillable is a second step). F (or Till Land in the build menu), then two clicks at opposite corners, marks the open ground in a block that is not farmland yet: cleared woods or meadow, not woods, rock, water, roads, or built land. Each working field (farm or forager's garden, at its tier's pace) tills the marked tile nearest it, 3 working days a tile, its harvest unchanged; a tilled tile is farmland, where a farm can stand. Marked land is tinted brown; the sidebar counts it. One farm tills a 3x3 block in about 36 days. Code: `TownFarmland` (`city.farmland`).
- **Forest expansion** (owner specification, 2026-10-27; `TownWoodland.spread_forest`). Woods spread on their own, slowly, onto any open land beside them, felled or never wooded. Once a year, chosen on the first day of spring and grown in through spring, summer, and autumn:
  1. Candidates are open tiles with woods on at least one side (not just a corner) that woods can take (below).
  2. Each wooded tile within 3 steps (|dx| + |dy|) adds influence 0.5^(steps - 1): a side neighbour 1, a corner 0.5, three steps 0.25. Woods further away add nothing, so a big forest is no bonus to an edge it is far from.
  3. The year's chance for total influence I is `P_max * (1 - (1 - P_base / P_max)^I)`: the base chance beside a lone wooded tile, rising toward the cap with more woods near.
  4. Each candidate draws one number in [0, 1), in row order, and is chosen below its chance. All candidates are judged against the woods as spring began, so woods never spread two tiles in a year.
  5. Each chosen tile grows in on its own day between the first day of spring and the end of autumn (owner, 2026-10-27: visibly sporadic, spring to fall), if nothing has taken the land meanwhile. Nothing grows in winter. Woods past the town map's edge count toward the pull: the woods at the edge are taken to go on past it (owner: they should count, if not costly).
- **What woods can take:** open ground, meadow or farmland nobody farms. Not water or rock, nothing built or reserved (fields are buildings, and so are plots and sites), no road, and no trail or path. A path in use holds its line open; once nobody walks it, it fades to grass and the woods may take it.
- **Parameters** (`EconomyBalance`, Woodland), placeholders until a town tile's size and the game's pace are calibrated (a year is 360 days, 6 minutes at 1x):

  | Parameter | Default | Meaning |
  | --- | --- | --- |
  | `FOREST_SPREAD_BASE_CHANCE` | 0.01 | yearly chance beside a lone wooded tile (influence 1) |
  | `FOREST_SPREAD_MAX_CHANCE` | 0.04 | the cap the chance approaches and never passes |
  | `FOREST_INFLUENCE_RADIUS` | 3 | steps within which woods add influence |
  | `FOREST_INFLUENCE_DECAY` | 0.5 | each step further away halves a wooded tile's influence |

- **What it means** (`tests/town_woodland_validation.gd`): beside a lone wooded tile 1% a year; the side of a line of woods (influence 2.5) 2.1%; the middle of a 5x5 forest's edge (3.75) 2.6%; a tile ringed by woods (11) 3.8%. A 5x5 forest gains about 0.48 tiles a year against 0.04 for a lone tile (twelve times as much, from five times as much edge). A lone wooded tile grew to 28 tiles in 100 years, in a 5x10 patch, not a block. A clearing nobody uses therefore closes over decades, not years.
- **Implementation.** The frontier (open tiles with woods on a side) is kept as woods are felled or spread and found again from the town map after loading; it is not saved. Each year's draws come from a generator seeded by the town and the year, as the town's other chances are, so a loaded game spreads exactly as the original would have (tested).

**Judgment calls**, open to owner veto:

- This replaces the first version of growing back (felled land only, a year to three, saplings, wear pushing growth back), at the owner's specification. Land that was never wooded can now become woods, so open land at a town's edge slowly fills in unless it is built on, farmed, or walked.
- Felled land is building land; tilling it (or meadow) is a separate step that makes it farmland.
- A woodcutter's output does not depend on woods in reach: one that has cleared all the woods around it still cuts wood, now from the nearest woods it can reach. Its placement still needs woods within 5 tiles.
- A field's harvest does not drop while its family tills; tilling is part of its work, as felling is a woodcutter's.
- In the game the spring day comes from the calendar; tests and balance tools, which run towns without one, count years from founding.
- Felling costs the woodcutter nothing extra and leaves no extra wood; the walk to the felling site is not travel it pays for, and does not wear a path.

## Plots And Family Homes

- **Residential plots** are 2x2 pieces of land the player sets aside for homes (P). A plot reserves its land; a house the player places on it uses it.
- **Families act on their own** every week (`scripts/domain/family_development.gd`, at most two new projects each time), through the same pipeline and rules:
  - a family in a hut upgrades it in place to a house when the stores can spare a house's materials (keeping 10 wood back for the workshops) and it has lived there 3 months;
  - a family without a home claims the open plot it likes best and builds a house there, or a hut when the stores cannot spare the wood;
  - when no home stands empty, a family with a grown child ready to marry builds one on a plot for the new family (marriage needs a home), Leave the Nest families first. Without this, a town that left homes to its families never had a spare home and stopped growing.
- **Values decide who acts and where.** Hearth-Proud families want a proper house at once; Simple Living families are content in a hut and build one; Town-Loving families settle near the town's heart and Open Country families toward its edge (each tile from the heart weighs 1.5 tiles of walk); everyone else picks the plot nearest its work.
- Families that want a home and find no plot are counted for the player in the sidebar ("2 families want a home plot (P)").

**Judgment call:** families build homes only on plots the player set aside, never anywhere; the player keeps the town's shape, families fill it. Autonomous workplace investment, and a town choosing its own plots, are later steps (below).

## Changes To Existing Rules

These are product-design changes this milestone was authorized to make (owner brief, 2026-10-26):

- Buildings appear only when built; nothing is paid at placement. `City.add_building` is the "finished" entry point; `City.upgrade_building` (instant, paid) stays for tests, play goes through `TownConstruction.request_upgrade`.
- Workplace output is reduced by travel and spare-time share (`City.get_work_time_factor`); the migration food estimate counts travel too.
- A storehouse is neither a home nor a workplace (`Building.is_store`): no family, no upkeep.
- `BuildingPlacement.validate` takes `check_cost` (default true).
- The labor pressure row counts families on a site as building, not idle.
- Paths wear where people walk, and the player can still lay roads (owner, 2026-10-27): worn ground cuts the travel share as roads do, and routes are now always the cheapest (see Routes).
- Routes run on the lines between tiles as well as through them, and the strips between yards and fields walk like open ground, so compact towns travel less (see Measured Effect).
- A field's harvest is reduced by trampling (`City.apply_building_output_modifiers`).

## Measured Effect

The stand-in player (`tests/sim/stand_in_player.gd`) plans buildings and the town builds them; "before" is the same stand-in building instantly (`instant` policy). 2026-10-26:

| Check | Before | With construction |
| --- | --- | --- |
| Opening check, sensible opening (20 towns, no map) | 20/20, 48 people | 20/20, 47 people |
| Opening check, owner's first-playtest opening | 20/20 | 20/20 |
| Opening check, all wood on houses first | 20/20 | 13/20 |
| Opening check, idle for the first 60 days | 15/20 | 12/20 |
| Opening check, toolmaker by day 90 / 120 / 150 | 19 / 18 / 6 of 20 | 19 / 18 / 6 of 20 |
| Map luck, original maps (48 towns) | 46/48 | 46/48, same failing sites |
| Map luck, continuous map (42 towns) | 40/42 | 40/42, same failing sites |
| Town building check, houses placed by the player (20 towns) | 18/20, 42 people | 17/20, 39 people |
| Town building check, homes left to families on plots | | 18/20, 33 people, 9.5 homes built by families |
| Town building check, scattered layout | | 14/20, 27 people |

- **No construction deadlocks:** across every policy no site ever waited for a builder (`site-days waiting for builders` 0).
- **Layout matters:** a scattered town loses 13% of its working day to travel against 8% for a compact one, and gets 14/20 towns off the ground against 17/20. Travel alone (map luck "before" already counts it) moved the continuous map from 42/42 to 40/42.
- **Queue order matters:** spending all the wood on houses first puts them ahead of the woodcutter in the queue; builders and wood go to the houses, and 7 of 20 towns do not recover (they did when buildings were instant). "Build this first" on the woodcutter's card is the remedy; whether builders should favor workplaces on their own is an owner decision below.
- **Family homes are slower but steadier:** a town that leaves homes to its families houses them by day 10 (day 9 when the player places houses) and grows a little more slowly.
- **Paths (2026-10-27).** Same tools, `develop` before paths against this branch:

  | Check | Before paths | With paths |
  | --- | --- | --- |
  | Opening check, every opening (no town map, so no travel) | | identical |
  | Map luck, original / continuous maps | 46/48, 41/42 | 46/48, 41/42, same failing sites |
  | Town building check, houses placed by the player | 17/20, 39 people, travel 8% | 18/20, 40 people, travel 8% |
  | Town building check, homes left to families on plots | 18/20, 33 people, travel 8% | 18/20, 33 people, travel 8% |
  | Town building check, scattered layout | 14/20, 27 people, travel 13% | 15/20, 33 people, travel 11% |

  Paths help most where travel hurts most: a scattered town's routes cross open ground that wears, while a compact town's short routes run mostly through yards and fields, which do not wear (a stand-in town grown 18 months shows almost no paths; the plots town in the screenshots shows 14 trail and 11 path tiles after a year).
- **Terrain and woodland (2026-10-27)**, against paths alone: the opening check is identical; map luck stays 46/48 and 41/42 with the same failing sites; the town building check is unchanged for houses placed by the player (18/20) and homes on plots (18/20), and the scattered layout falls back from 15/20 to 14/20 (33 to 30 people; its routes pay more for woods). The stand-in player never marks woods, so these measure the terrain costs only. `tests/sim/town_map_probe.gd`: what town maps hold is unchanged (hill land is a new marker, not new land); generation median 38 ms.
- **Routes on the lines between tiles, trampling, and fences (2026-10-27)**, against forest expansion: the opening check is identical; map luck 46/48 on the original maps (same failing sites) and 42/42 on the continuous map (was 41/42); the town building check: houses placed by the player 19/20 and 43 people (was 18/20, 39), homes on plots 18/20 and 31 people (was 33), scattered 14/20 and 31 people (was 30). A compact town's travel falls from 8% to 5% of the working day (families walk the strips between yards and fields instead of crossing them); a scattered one's from 11% to 10%. The stand-in player never fences, so trampling costs are counted in full. Capping the strips between buildings at trail moves a compact town's travel from 5% to about 6%; towns off the ground and people are unchanged. Closing buildings, sites, and the stockpile to through-traffic changed no figure in the opening, town building, or map luck checks. Nor did woodcutters cutting the nearest trees, any-tier felling, spring-to-autumn spreading, woods past the edge, and tilling (the stand-in player never marks land to till).
- **What measuring changed:** three stalls were found and fixed during implementation (see the judgment calls above): spare time limited to tier 0 and a family's own home left spare houses unbuilt and stopped growth; a finished workplace stood empty because its family had been pulled onto another vacancy (the toolmaker, fatally); towns that left homes to families never had a spare home for marriages.

## Open Owner Decisions

1. **Helpers cannot be turned off.** Every family at work gives 20% of its day to sites with room in the crew, so a long queue costs output across the town. Keep, make it a town policy, or limit it to homes and tier 0 (which stalls towns, measured above)?
2. **Should builders favor workplaces over homes,** or keep strict queue order (the player reorders with "Build this first")? Strict order is what punishes "all wood on houses first".
3. **Upkeep grace counts from founding.** `MAINTENANCE_GRACE_DAYS` is a town-wide grace that starts at founding (the roadmap's wording, "new buildings need no tools for their first 60 days", reads per building). With construction, buildings start later, so the effective grace is shorter. Per-building grace would soften the tool cliff.
4. **Travel numbers** (`DAY_EFFORT_TILES` 500, `CARRY_LOAD` 5, road 0.5) were set so a compact town lost about 8% and a sprawled one 15-25%; first-pass values for owner tuning. Since routes run between yards and fields (2026-10-27) a compact town loses about 5%.
5. **Families build homes only on plots the player set aside.** Should mature towns choose their own residential land?
6. **Path numbers** (trail at wear 40, path at 150, fading over about two months, trail -15% and path -35% effort) are first-pass values: a busy route turns to path within two to five months (owner: keep them for now, 2026-10-27).
7. **Terrain and woodland numbers** (woods 2, hills 1.4; 2 working days to fell a tile; forest expansion 1% to 4% a year within 3 steps) are first-pass values, the spread ones placeholders until tile size and pace are calibrated, and the judgment calls under Woodland are open. Settled by the owner (2026-10-27): terrain numbers; clearing only clears and tilling makes farmland; woodcutters of any tier, cutting the nearest trees when nothing is marked; spread numbers kept; woods past the map's edge count; spread grows in from spring to autumn. Still open: unmarked felling pace (a tile per 20 working days) and tilling (3 working days a tile, by the fields' families).
8. **Field and fence numbers** (2% of a harvest per daily trip through a field, at most 40%; a fence 4 wood and 2 family-days) are first guesses. Strips between buildings walk like open ground and stay trails (owner, 2026-10-27).

## Remaining Work And Limitations

In rough priority order:

1. **Per-store inventories and carts.** Stores share one stock; goods do not move between stores, and households do not fetch food from a store. Needed before markets and the M7 storehouse and tithes.
2. **Autonomous workplace investment and town planning.** Families build homes; nobody yet decides to open a workshop, and a town does not set aside its own plots. Both requests already fit the pipeline (`requested_by` town or household).
3. **Who pays.** `funded_by` is recorded but every project draws on the town's stores; household wealth (M7), the player's capital, and public funds come later.
4. **Builder specialization.** Any free family builds; a builder's yard or builder responsibility, and the Grouped-scale crew model, are not built.
5. **Demolition and moving.** Nothing can be torn down; roads cannot be removed.
6. **Paving.** A well-worn path cannot yet be made a road; the road project in the pipeline is ready for it once there is a reason (a cart, a paver yard's stone).
7. **Industry next to homes** has no cost yet (noise, smoke); with satisfaction (M4) it can.
8. **Storage capacity** is unlimited.
9. **Regional depiction** still draws the player's town by rule, not from its layout.
