# Map Scale Architecture Investigation

An investigation of how town, regional and world maps should relate as settlements grow to hundreds of thousands of people, with Songs of Syx as a reference (2026-11-06). **A proposal only.** Nothing here is built, authorized or on the roadmap. No gameplay code changed. Where this conflicts with `GAME_VISION.md` or a recorded owner decision, those stand until the owner decides otherwise.

## The Short Version

1. **The planet already has the room.** One typical region holds about 0.8-1.25 million town tiles, which is one to two Songs of Syx base maps. The problem is not the size of the world. It is that the town is cut out of it.
2. **The town is already nearly continuous with the land.** On shared land, adjacent town maps agreed on water, roads and hills in every tile measured, and on terrain type in 99.6%. Only the town-scale detail disagrees (farmland and trees, 4.1% of tiles overall).
3. **Songs of Syx is an inspiration for density and presence, not for continuity.** It has a detailed city and an abstract world, and its developer's stated aim was one city per game. Your goal, continuous land with many settlements, goes further than Syx does, and our target population is beyond what it simulates.
4. **Recommendation: one continuous land, stored in sectors, with a land-use record per regional tile as the shared truth between scales.** Detail exists only where a settlement has reached. A city's outer districts are drawn from data rather than simulated building by building. The simulation level follows the settlement, never the camera.
5. **Nothing needs rewriting now, and active economic work need not stop.** A few habits avoid future cost, listed under Development Implications. The decision that matters most is number 1 in Open Questions.

## 1. Songs of Syx: What Is Worth Adopting

### How firm this evidence is

Sources were developer statements, the store page, devlogs and player reports. The official wiki timed out and could not be read. Songs of Syx is in early access and changes between versions, so older statements may be out of date. **You have played it and may know better on any of this.**

| What | Evidence | Confidence |
| --- | --- | --- |
| "Tens of thousands of individually simulated citizens" | Store page (developer) | Firm |
| Base settlement map 768; mods offer 1024 and 1408 | Mod listings (the 1408 page could not be read) | Community source |
| A population cap of 40k | One 2020 forum post | Unverified |
| A player at about 16,000 people limited to somewhere between 3x and 25x speed | Player report, v64, 2024 | One player, hardware unknown |
| "The aim right now is 1 city per game"; regions managed "in a more abstract way" | Developer, relayed by a moderator, 2020 | Firm for 2020; conquered towns now exist in some form |
| Taxed regions send shipments that travel to the city's import depots | Developer devlog, 2020 | Firm for 2020 |
| Pathfinding on a layered grid: "starting from 8x8 tiles, then 16x16, 32x32 ... map size x map size" | Developer, 2022 | Firm |
| Custom Java and LWJGL engine, OpenGL 3.3 | Developer, store page | Firm |
| Far-zoom rendering; how a settlement map follows its world location | Not found | **Unknown** |

### The principles worth adopting

1. **The city as one physical mass.** The feeling of scale comes from one continuous piece of land that can be read at any zoom, without changing mode. This is the principle most worth taking.
2. **Density you can read.** A great city feels great because it is dense and varied up close and has a recognizable shape from afar.
3. **Spatial hierarchy for movement.** Syx's layered grid is the proven way to route across huge maps.
4. **What the world gives must physically arrive.** Regions send shipments that travel, so the world's economy is visible at the city's gates. This suits our satellites and the economic fragility principle: a road can be cut.
5. **The province as a city's hinterland.** Syx's developer described each city controlling the area around it. That matches a satellite's role here.

### What not to adopt

- **Individually simulating everyone.** Syx reaches tens of thousands, and our target is many times that. Our route through Houses and groups stays right, and Syx shows the limit of the alternative.
- **A hard split between city and world.** This is exactly what you want to avoid.
- **The player placing every room and zone.** Families lead in this game.
- **One city per game.** Our vision requires several settlements.

## 2. Current State

### What exists today

| Scale | Size | Representation | Source of truth |
| --- | --- | --- | --- |
| World atlas | 7200x3600 world units | Fields, regions, settlements, roads, rivers | World seed |
| Regional | 6000x3000 tiles; 60x60 chunks | Every tile a pure function of its position | Derived; streamed on demand |
| Rules window | 160x100 regional tiles, pinned at founding | `main.gd`'s neighbourhood | Derived |
| Town | 64x44 town tiles (16x11 regional) | `City.local_map`: rows of dictionaries, saved whole | Derived once, then saved and changed by play |

One regional tile is four town tiles on a side, so 16 town tiles. The planet is 24,000x12,000 town tiles (288 million).

### Is there a fixed settlement boundary? Yes, in three separate ways

- **In the data.** 64x44 is hard-coded in `main.gd`, `BuildingPlacement`, `CityBuildingOverlay` and the generator's and shader's defaults. Coordinates start at the map's top-left corner, so growing north or west would shift every saved building. Another 43 lines across 17 files index `local_map` directly.
- **In the rules.** The map's edge means something. `TownTrade.road_reaches_edge` defines a town's link to the world as a road reaching the edge of the map, and the game tells the player to build one. Reach rules stop at the edge.
- **In the picture.** `TownBoardLayer` deliberately draws the town as a model on a table with a cut soil edge. There is no zoom hand-off from the town to the regional map either, though the regional and atlas maps have a seamless one.

### What was measured

A throwaway probe, not added to the repo, on a generated world (seed 12345), 24 frontier sites and this machine, headless. **Rendering was not measured.**

**Do neighbouring town maps agree on shared land?**

| Sites apart | Shared tiles | Any difference | Type | Water kind | Road | Hill | Trees | Fertile |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 8 regional tiles | 33,792 | 4.1% (worst pair 12.2%) | 0.4% | 0.0% | 0.0% | 0.0% | 1.3% | 2.7% |
| 2 regional tiles | 59,136 | 2.4% (worst pair 6.7%) | 0.3% | 0.0% | 0.0% | 0.0% | 1.0% | 1.3% |

The causes are visible in `LocalCityMapGenerator`: farmland, glades, outcrops and copses are ranked as a share *of the window*, one climate is used for the whole map, the heart is cleared, and the floors (180 buildable, 18 fertile, 90 tree tiles) are met nearest the center. So the generator is not yet a pure function of position, though a comment on the `feature/ef-s5` line calls it one. The geography itself joins almost perfectly.

**What does a larger town map cost, as the code stands?**

| Map | Generate (single thread) | Memory held | Saved size |
| --- | --- | --- | --- |
| 64x44 | 34 ms | 3 MB | 0.6 MB |
| 256x256 | 1.0 s | 44 MB | 13.8 MB |
| 512x512 | 5.1 s | 178 MB | 55 MB |
| 1024x1024 | 21.9 s | 705 MB | 220 MB |

About 705 bytes per tile, because each tile is a dictionary. A packed tile would take perhaps 8-16 bytes (an estimate). **The tile format, not the idea of a large map, is the limit.**

**Routes.** Godot's route grid held up better than expected: 1023x1023 cells took 75 ms to build, and a 2047x2047 grid took 319 ms and 195 MB. Paths took about a millisecond, but that was on open ground, the best case. The real cost is ours: the 40 ms rebuild on today's map is mostly per-cell GDScript. Scaled by area, a map of 1024x1024 tiles would take around 15 seconds on every layout change (a projection). The fix is updating only what changed.

**The world's real distances.** Nearest-neighbour settlement spacing has a median of 105-199 regional tiles by tier, and a minimum of 52. Founding requires 24. There are 111 settlements in 98 regions. World settlements declare up to 42,000-95,000 people, drawn by tier.

### How much land does a settlement need?

Assumptions: 4 people per household; a home on one tile, a farm of 3x3 tiles feeding 8 people, as today; built land per household falling with density (12, 8, 5, then 3 tiles, including streets and workplaces). Food is met entirely by farms of today's output. These are planning numbers, not design.

| People | Households | Built land (tiles) | Farmland (tiles) | Across, built only | Across, with farms | In regional tiles |
| --- | --- | --- | --- | --- | --- | --- |
| 1,000 | 250 | 3,000 | 1,125 | 62 | 72 | 18 |
| 10,000 | 2,500 | 20,000 | 11,250 | 160 | 199 | 50 |
| 100,000 | 25,000 | 125,000 | 112,500 | 399 | 550 | 137 |
| 500,000 | 125,000 | 375,000 | 562,500 | 691 | 1,093 | 273 |
| 1,000,000 | 250,000 | 750,000 | 1,125,000 | 977 | 1,545 | 386 |

Reading this:

- **Today's map fills at several hundred people,** the same place the simulation is meant to move from Full to Grouped (250-1,000 people). Those two limits arriving together is convenient.
- **Without any change of scale, a literal city fits.** A 100,000-person city and its farms reach about as far as the median neighbouring settlement. 500,000 is about a whole region. A million overflows one.
- **Two settlements genuinely meet at around 100,000 people.** This is a real event in the game's geography, not a hypothetical.
- **Hinterlands arise by themselves.** Only 6-34% of open land is arable, so the land searched for 112,500 farm tiles is several times that figure: a large part of a region for a city of 100,000. Satellites are not a convenience but a physical necessity. This is exactly the audit's point about metropolises, now with numbers.

### What can safely stay unchanged

- The atlas, `WorldMapData`, and the pure regional chunks; the frozen `region_map_generator.gd`.
- **The ×4 scale.** The numbers above show no need to change it.
- Painters, the shared art style, and "decoration never shows what the data doesn't hold".
- One construction pipeline, `HomeSites`' scored choices, and radius-based reach in `TownLand`.
- Rivers, world roads and deposits already flow down from world to region to town.
- Saves rebuilding the planet from its seed.
- The day's rules for a town at today's size. A hamlet can play exactly as it does now.

### What would complicate larger or joined maps

| Issue | Where | Severity |
| --- | --- | --- |
| Town detail isn't a function of position, so maps can't join | `LocalCityMapGenerator` | Core; changes every town's land, so balance must be re-measured |
| Nothing flows **up**: regional land never learns what a town did. The player's town is drawn by rule, and regional tiles are pure and cannot hold a change | `region_map_geometry.gd`, `RegionalTerrain` | Core; it is what your central goal needs most |
| Tile format at about 705 bytes | `City.local_map` | High above about 256x256 |
| Whole-map scans (about a dozen in the domain, including `HomeSites.get_candidates`) and whole-map layout rebuilds | `TownLogistics`, `TownWoodland`, `HomeSites` | High at size; fine today |
| Map edge as a meaning | `TownTrade` | Small, but new rules must not add more |
| Top-left coordinates; hard-coded size | `main.gd`, `BuildingPlacement`, `CityBuildingOverlay` | Medium; a mechanical change |
| One player settlement; rules pinned to one 160x100 window | `main.gd` | High for several settlements |
| Town layers recorded whole; the ground is one texture | `scripts/visuals/town_map/` | High at size; regional chunks show the pattern to follow |
| Town maps saved whole | `GameState` | Needs a change; the guarantee that a generator change can't move a town must be kept |
| New per-tile state on the `feature/ef-*` line (forests, clay, limestone) | `TownWoodland`, generator | Adds to the above; each new field is one more thing a future format must carry |
| Household tick quadratic above about 250 households | `city.gd` | Already the roadmap's gate before town scale |
| Date line at town scale | Generator noise | Low; generated worlds put it in empty ocean |

### Where this conflicts with what's written down

- `SIMULATION_SCALE_MODEL.md` says growth beyond the local map "shows as district blocks", and that the player places neighbourhoods and then districts.
- `map_and_settlement_scale_audit.md` says the player should not have to pan across one enormous map, and that the local map becomes a core or district view.
- `HANDOFF.md` records "One player settlement".

The first two are the older answer to the question this brief reopens, so your decision here would supersede them. **"Satellite" appears nowhere in the repo.** The nearest are the audit's "abstract producer settlement" and the Summary level, so your distinction lives only in conversation and should be written down.

## 3. Architectural Options

### Option A: Core and blocks

The town map stays bounded as the old core, perhaps a little larger. Growth past it is drawn as district shapes on the regional map, as the current model says.

- **Cost:** low. **Performance:** excellent. **Risk:** low.
- **For:** simple, and already consistent with the docs. No balance change.
- **Against:** the map has a seam just where you want continuity. The town still ends at an edge, and the city you watch growing is on a different map from the one you built. It does not meet the central goal.

### Option B: A large bounded map per settlement (Syx's approach)

Each simulated settlement gets a large map, say 1024x1024, or one that grows by rings.

- **Cost:** medium to high. Needs packed tiles, chunked drawing and partial route updates. **Performance:** workable once packed; the whole map must exist from the start or be extended.
- **For:** a known-good model, with a real single-map feel. Simple for the player.
- **Against:** the edge only moves further out. Two towns can't meet on one piece of land, so each is still a separate board. Fixed sizes either waste memory or cap growth. It solves density but not the relationship with the world, and much of the same work as C gets spent without gaining continuity.

### Option C: One continuous land, in sectors, with fidelity levels (recommended)

Every town tile on the planet already exists as a pure function of position, just as regional tiles do. Only sectors a settlement has touched are held and saved. A compact land-use record per regional tile carries what happened on the land up to the regional and world maps.

- **Cost:** highest in total, but it comes in stages, each useful alone. **Performance:** cost follows what is built, not map size. **Risk:** the generator change shifts balance, and rendering a great city is unproven.
- **For:** the only option where roads, rivers, woods and neighbouring towns are really one land. No edges. Two towns can meet. Zoom works across all scales.
- **Against:** the most new concepts, and the most care needed to keep saves deterministic.

### Compared

| | A: Core and blocks | B: Large map | C: Continuous sectors |
| --- | --- | --- | --- |
| Town continuous with the world | No | No | Yes |
| Footprint can spread freely | No, only a depiction | Up to the map's edge | Yes, limited by geography |
| Two settlements can meet | Only as a depiction | No | Yes |
| Memory for a large city | Very low | Fixed, large | Follows development |
| Fits satellites and aggregation | Yes | Partly | Yes |
| Changes current balance | No | Slightly | Yes; must be measured |
| Rough size (low confidence) | 1-2 milestones | 3-4 | 5-7, staged |

A later move from A to C throws most of A away. A later move from B to C keeps its tile format, drawing and routing work, so B is a partial path to C, but it has no reason to stop there.

## 4. Recommendation

Choose **Option C**, built in stages, keeping the ×4 scale. Everything rests on five ideas.

### 4.1 Base land plus change

Town land has two parts, like the planet and a save today. The **base** is a pure function of position, the same from any window. **Changes** (buildings, felling, paths, founding's cleared heart) are held per sector, only where touched. Touched sectors are saved whole, which keeps today's promise that a generator change cannot shift a town under its buildings.

The guarantees a founding needs, such as floors of buildable land and farmland, become part of the founding act: a saved change around the heart, rather than part of the land. The owner's guarantee stands, and the survey still shows the true map.

### 4.2 The land-use record: one truth across scales

This is the keystone. Each regional tile that development has touched holds a small record: how much is built and how densely, farmland, pasture, cleared woods, the main economic use, the road class through it, which settlement claims it, and the dominant style of who lives there.

```
World atlas     reads the records, summed            shape and colour of civilization
Regional map    reads the records                    fields, sprawl, clearings, real roads
Town scale      reads and writes them                buildings, or districts drawn from data
Simulation      writes them                          households, then groups, then numbers
```

Detail writes the record. Aggregate simulation writes the same record. Every zoom reads it. So **the regional map finally shows what happened**, satellites have a footprint with no town map, and "decoration never shows what the data doesn't hold" still holds at every scale. A region's worth is about 1 MB.

### 4.3 Three levels of land

| Level | What it is | Simulated as | Built when |
| --- | --- | --- | --- |
| **Lived** | Real buildings and paths on real tiles | Households | Up to Full scale, then kept as the old town and anchors |
| **Patterned** | Streets and buildings drawn from land-use records and a seed | Groups (Houses, commons, cohorts) | Beyond the Lived core |
| **Landscape** | Land use only, drawn at regional scale | Summary | Satellites, rivals, hinterland |

**Patterned districts grow without pop-in.** Each potential building has a fixed rank from position and appears when its cell's density passes that rank, the same trick regional chunks use to compare a noise rank against an amount. A city fills in, buildings stay where they appeared, and a district looks the same every time it is seen, with nothing stored per building. 25,000 homes become data about cells.

### 4.4 The simulation never follows the camera

Fidelity belongs to a settlement or district and changes only through the simulation's own transitions. Zooming into a Patterned district shows its drawing and never turns it Lived. Otherwise looking at something would change what happens, and determinism (a loaded game decides as the original would have) would be lost.

### 4.5 Zoom is one motion

Zooming the regional map into a town should hand off the way atlas and regional already do, with the land around the town still there. Roughly:

| Zoom | Shows |
| --- | --- |
| World | Civilizations as tinted territory and city shapes; trade corridors |
| Region | The settlement's real outline, fields, roads, clearings, satellites |
| Settlement | Districts, density, the road network, the old town |
| Street | Lived buildings and families, or Patterned drawing |

### How each question from the brief comes out

| Question | Recommended answer |
| --- | --- |
| Town map size | No fixed size. A window onto continuous land, and at founding it can look the same as today |
| Local terrain and world maps | Direct correspondence; already true for geography, and detail becomes consistent |
| Footprint growth | Follows where families and groups choose to settle, written to the land-use record |
| Zoom between views | Yes, one continuous motion |
| Two growing settlements | Each regional tile is claimed by one settlement; they meet at a boundary and stay separate unless deliberately merged |
| Roads, rivers, forests, mountains | Rivers and mountains stay fixed and flow down. Roads and cleared woods are changes that flow up. Town paths with enough traffic can become regional roads. Roads become one network in global coordinates |
| Consistent geography without full detail | Yes. Base land is computed on demand, so nothing is simulated or held until reached |

### Keeping what makes the game different

**Growth keeps using families' reasons.** `HomeSites` already scores land by walk to work, kin, neighbours, the town's heart, room, land for a calling, stores and roads, safety, and preferred land. A cohort of families can use the same terms over land cells, with a distribution of values instead of one family's, so a town's shape keeps coming from the same reasons. The player still shapes conditions (roads, land marked for use, priorities, later law), never houses.

**The three kinds of town would look different because their rules differ, not because of a theme:**

| Society | Why it looks that way |
| --- | --- |
| Farming | Spread along fertile land and streams, with low density and fields reaching far; homes near fields |
| Mining | Dense and tight around deposits on poor land, with spoil and cleared hillsides; food comes in along one road, a visible dependency |
| Commercial | Compact around a crossing, ford or harbor; density and warehouses follow traffic; roads radiate |

**Culture changes the same site,** through values families already hold:

| Values | Physical effect |
| --- | --- |
| `town_loving` against `open_country` | Compact against scattered |
| `close_knit`, `clannish` against `leave_the_nest` | Kin clusters against even spread |
| `private_holdings`, `landholding` against `common_stores`, `communal_labor` | Fenced individual plots against open common fields and shared works |
| `cautious` against `daring` | Avoiding the floodplain against building on it |
| `insular` against `cosmopolitan` | Closed quarters against mixed ones |
| `monument_makers`, `hearth_proud` | A visible heart; fine homes |

The drawing reads wealth and value **distributions**, not averages, as the E13 scaling constraint requires, so a rich quarter and a poor one look different.

**Prosperity and resilience stay separate.** Grouping must not smooth away what can fail. **Anchors** stay Lived inside Patterned districts: a holding, family, bridge or granary that other things depend on keeps its real place on the map. Which ones are anchors comes from actual dependency, not a label. Geography helps here, because a single bridge or a mine road is a physical failure point the player can see. This needs design with the demographic work.

**Satellites** are Landscape: a land-use footprint, a population and culture, and shipments on real roads. They have no town map and can't be opened. They are extensions of their settlement, and their shipments arrive physically, so they can fail in a way the map shows.

### Risks in the recommendation

- **Rendering a great city is the largest unknown.** Nothing here was measured on a GPU, and integrated GPUs have never been tested. This should be the first thing proven, before committing.
- **Patterned districts might look alike.** "Recognizably different societies" is a promise art must keep.
- **The generator change alters every town,** so `map_luck_check` and `town_map_probe` must be re-run. It may conflict with active economy tuning if done at the wrong moment.
- **Scope.** `GAME_VISION.md` names scope as the main risk, and this is a large addition. The stages must each be good alone, and the hamlet must not suffer.
- **Grouped simulation is not designed yet.** Patterned land depends on it. Its design and this one should be made together.

## 5. Development Implications

### Decide now

1. **The direction** (A, B or C). Everything else depends on it.
2. **That the land-use record is the truth between scales** in principle, because economy and demographic design should know it's coming.
3. **That satellites and the fidelity levels are written down** somewhere durable.

### Cheap habits now, if you agree

These cost almost nothing, need no sprint, and don't disturb the economic work:

- No new rule that gives the map's edge a meaning.
- New per-tile state stays small, with a value derivable from land position wherever possible.
- New rules reach by radius, not by scanning the whole map.
- Land rules stay in domain code as scored terms, so they can later run over groups.

### What can wait

- Packed tiles, sectors, chunked town drawing and partial route updates.
- Second settlements, merging and borders.
- Patterned drawing, and the group simulation behind it.
- Canals, land reclamation, and anything else that alters geography.
- The final look of each zoom band.

### If you choose C: a possible order, not a roadmap

Each stage is playable by itself. Economic Foundations finishes first unless you say otherwise.

| Stage | Result | Depends on |
| --- | --- | --- |
| 0. Prove it | Two spikes: a position-pure generator under matched map-luck sims, and a rendering test of a 100,000-person city including an integrated GPU | Nothing |
| 1. No more board | The land continues past the town and zoom flows from region to town; building stays limited as today | Position-pure base |
| 2. The map tells the truth | Land-use records; the regional map shows real fields, clearings and buildings | 1 |
| 3. Room to grow | Sectors and packed tiles; a Lived town grows past 64x44, with roads and reach | 2 |
| 4. Towns meet the world | Road network across scales; trade along real routes; satellites | 3 |
| 5. The great city | Groups and Patterned districts; old town and anchors | 3, plus the household lookup gate and Grouped design |
| 6. Many settlements | Second settlements, claims, meeting and merging | 4, 5 |

## 6. Open Questions For The Owner

Each has a recommendation.

1. **Direction:** A, B or C? *Recommended: C, starting with stage 0 only, so you can see the rendering proof before committing.*
2. **The ×4 scale:** keep it? *Recommended: keep. It has room for everything you described.*
3. **What limits a settlement's land?** Only geography and how far families will travel, or also a claim the player must establish (`GAME_VISION.md`: influence before territory)? *Recommended: land is reached through roads and travel, and claimed through influence, with no fixed map edge.*
4. **The player's tools at scale:** the current model has the player placing neighbourhoods and districts. Your brief says influence through infrastructure, land use, policy and law. Replace it? *Recommended: replace it. The player marks land use and builds infrastructure, and people decide the rest.*
5. **How close can you get to a Patterned district?** *Recommended: inspect districts and anchors, plan roads and land use, but no individual ordinary houses.*
6. **Satellites:** is this the definition you intend: a footprint on the land, economic and cultural extension, no town map, can't be opened? Can one ever become a full settlement? *Recommended: yes, and promotion only by a deliberate founding act.*
7. **When two settlements meet,** do they stay separate? *Recommended: separate, sharing a boundary. Merging is a deliberate act for settlements of one polity, designed later.*
8. **Can rival towns be taken and then opened in detail?** `GAME_VISION.md` has capture. If they exist only as summaries, what does the player get? *No recommendation yet; this needs its own thinking.*
9. **Lowest hardware to support?** Rendering budgets depend on it. Integrated GPUs are untested. *Recommended: name a target before stage 0.*
10. **Does geography itself change?** *Recommended: woods, fields and roads change; rivers, coasts and mountains don't, for now.*
11. **Timing:** after Economic Foundations, or stage 0 alongside it? *Recommended: stage 0's two spikes can run alongside, as they change nothing merged.*

## Sources

- [Songs of Syx on Steam](https://store.steampowered.com/app/1162750/Songs_of_Syx/)
- [Songs of Syx on itch.io](https://songsofsyx.itch.io/songs-of-syx)
- [The World and Beyond (developer devlog, 2020)](https://songsofsyx.itch.io/songs-of-syx/devlog/157425/the-world-and-beyond)
- [A Beginner's Guide (community, 2020)](https://songsofsyx.itch.io/songs-of-syx/devlog/121752/a-beginners-guidetutorial)
- [How is this game so well optimised (developer on pathfinding, 2022)](https://steamcommunity.com/app/1162750/discussions/3/3419934814481362952/)
- [Founding new towns from the map (developer's aim, relayed, 2020)](https://steamcommunity.com/app/1162750/discussions/0/2946998508790192031/)
- [Is there a limit to map size? (players, 2020)](https://steamcommunity.com/app/1162750/discussions/0/2843417619908161705/)
- [Population and performance (players, 2024)](https://steamcommunity.com/app/1162750/discussions/0/6297799115130440698/)
- [Region cities growth (players, 2025)](https://steamcommunity.com/app/1162750/discussions/0/693121929170761853/)
- [Early development thread (developer, 2016)](https://jvm-gaming.org/t/songs-of-syx-2019/57797)
- [Larger map mod](https://mod.io/g/songsofsyx/m/larger-map)
- [Bigger City Size mod](https://steamcommunity.com/sharedfiles/filedetails/?id=3434918193)
- [Arcen bug tracker thread on minimap and zoom](https://bugtracker.arcengames.com/view.php?id=28231) was excluded: the search summary's "developer" there may not be Songs of Syx's, so its statements aren't used above.
