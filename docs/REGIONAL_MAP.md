# Regional Map

The regional map is the middle scale between the world atlas and the town map: one river valley or county, 80x50 tiles, drawn as a stylized miniature landscape on a table. Its job is to show what a place offers (farmland, timber, stone, water, routes) and where a town can be founded.

## How To Run And Check It

- **In the game:** the game opens on the world atlas; enter an unclaimed region.
- **Demo scene:** `scenes/region_map_demo.tscn` shows the fixed showcase regions without the rest of the game. Keys 1-6 switch region, G adds a grown player town, F and L toggle founding sites and labels.
- **Data checks:** `tests/region_map_validation.gd` (headless). It checks that maps made without the world are unchanged, every frontier region is playable, regions follow their world geography, generation is deterministic, decoration follows the tile data, the camera maps screen to tiles, and clicking the landscape still chooses the site, founds the town, and shows it.
- **Screenshots:** `tests/visual/region_map_capture.gd` renders the showcases with render-time measurements, and `tests/visual/region_flow_capture.gd` plays the real flow (enter a region, choose a site, found the town, return). Both need a window, so run them without `--headless` (commands in `CLAUDE.md`).

## Architecture

```
WorldMapData --RegionGeography.from_world--> RegionGeography --> RegionMapGenerator --> tiles, towns, roads
                                                                                            |
                                         main.gd (owns data and rules) --set_region / notify_changed--> RegionMapView
```

- **`scripts/world/region_geography.gd`** is the world-to-region interface: what the world says about one region, sampled into regional tiles. It picks a fixed window of the region (96x60 world units) centered so the region's river, coast, and main settlement are in view, then samples elevation, moisture, forest cover, relief, temperature, sea, and lakes per tile, and lists the world rivers that cross the window, where world roads leave it, and the world settlements inside it. It involves no randomness.
- **`scripts/world/region_map_generator.gd`** keeps its original path unchanged and adds a world path used when `geography` is set. The world path places sea and lakes, stamps the world's rivers with regional meanders (or a stream that flows downhill or toward the sea when the world shows no river), puts hills and mountains where the world is high, with valleys along rivers, and sizes farmland and woods by climate. It reuses the original deposit clustering, makes the world settlement the regional town, and routes roads with A* out to where the world's roads leave the map. Noise only shapes edges; the world decides amounts.
- **`scripts/visuals/region_map/`** draws the region. `RegionMapView` owns the camera (a transform on `map_root`, like the world atlas) and the layers. `RegionMapGeometry` derives drawable shapes from the data: smoothed roads, bridges, settlement footprints, fields, and quarries.
- **`main.gd`** creates the view on a `CanvasLayer` below its panels, routes mouse input to it, converts screen positions to tiles through the camera, and calls `notify_changed` when towns or roads change. It keeps every rule: validity, survey, founding, and trade. Without the view (scripts that never enter the scene tree), the original tile drawing is used.

## Layers

Bottom to top. Permanent geography is separate from development, so a change rebuilds only what it touches.

| Layer | Draws | Rebuilt when |
| --- | --- | --- |
| Board | Table shadow and the cut soil edge of the model base | Never |
| Terrain (shader) | Lit relief, meadow, fertile land, hills, rock and snow, stone and iron ground, shores, water | Tiles change (`LAYER_GROUND`) |
| Fields | Field strips on fertile land around settlements, quarries | Towns change |
| Features | Trees, peaks, boulders on deposits; shrubs and flowers up close | Tiles change, or roads and houses clear new ground |
| Structures | Roads by class, bridges, buildings, palisades and walls, the player's banner | Towns or roads change |
| Sites, Overlay | Founding pegs; exclusion zones, hover, the chosen site's land | Founding state, hover, zoom |
| Labels | Settlement names, the world's river and lake names, "to (town)" where roads leave | Zoom, data |

## Key Decisions

- **Decoration never misrepresents the data.** Trees grow only on forest tiles (so woodland is always woodcutter timber), peaks only on mountains, pale or rust boulders only on stone or iron deposits, fields only on fertile tiles, and buildings never on water, mountains, forest, or deposits. Bridges sit where roads cross river tiles (the data's fords). A quarry appears only when the player's town has one. `tests/region_map_validation.gd` checks all of this.
- **Edges follow tiles.** The terrain shader smooths the per-tile masks so a boundary between two tiles still lies on the tile edge, and its rounding warp stays well inside a tile. Hover outlines and founding use the same tile coordinates, and one tile is 12 map units, as in `main.gd`.
- **The original generator is untouched.** Without world geography it makes byte-identical maps (20 recorded fingerprints), so the tests and sim checks built on it still mean what they did.
- **World consistency over true scale.** The window is a representative slice of a world region, not a measured zoom. Rivers, coast, lakes, high ground, climate, woods, roads, and the settlement carry over; distances do not.
- **One palette with the world map.** Ground and canopy colors come from `shaders/natural_palette.gdshaderinc`, which the world shader also uses, fed by the region's sampled temperature and moisture.
- **The look of a model landscape** comes from a low northwest light (hillshade, cast shadows on trees, peaks, and houses), glossy resin-like water with pale edges, individually drawn trees and buildings, and the board's base and shadow on the table.
- **Rendering cost is kept low.** The terrain is one shader quad, and camera moves change only uniforms. Features are recorded once per data change into horizontal strips that the engine culls off screen, each strip one triangle batch. Measured at 1600x900 on an RTX 3070 Ti: 0.3-1.9 ms CPU and 4.4-6.3 ms GPU per frame across runs (`[PERF]` lines in `tests/visual/region_map_capture.gd`).

## Founding Presentation

While no town exists, pale pegs mark every valid founding tile (toggle with F), red rings mark the zone too close to existing towns, and the hovered tile turns green or red with the reason in the inspector. A dashed circle shows the land a town there would draw its town map from. Choosing a site plants a stake and a gold circle; the inspector shows the site's character ("Riverside, fertile, wooded") above the unchanged plain-language survey. Founding still opens the town view, and the town appears on the regional map and grows with its buildings.

## Showcases

`RegionShowcase` lists fixed development examples: real world regions generated exactly as the game generates them. They are Meander Plains (fertile river valley), Thornspine North (forested foothills), Crownspine Heights (mountain mining country), Tessaly (coastal plain), Siwan Oases (desert oasis), and Taigard (northern taiga). With "grown", it adds a player town with houses, farms, and a quarry to show developed settlements.

## Gameplay Effect Of World Geography

World regions now get different land: cold regions have less farmland, deserts keep their trees and farmland along the water, mountain regions are mostly rough ground. A probe of 42 founding sites across 14 world regions of every climate (the `tests/sim/map_luck_check.gd` method on world-driven maps) got 40 towns off the ground. The same check on the original maps gets 47/48. Every frontier region keeps at least 300 valid founding sites (`tests/region_map_validation.gd`).

## Remaining Work And Limitations

- **Settlements are depicted, not simulated.** The neutral town's look comes from its world tier; the player's town from its building count and population. Houses are placed by rule around roads, not from the town map's layout.
- **Development is partial.** Fields, roads, bridges, settlement growth, and quarries respond to data. Cleared woodland, new roads built by the player, abandoned settlements, and mines need simulation data that does not exist yet; the layers are in place for them (`notify_changed`).
- **One regional town and one exit per world road.** World regions with several settlements show only the largest; roads to more than three exits are merged.
- **Town maps ignore coasts and lakes beyond the water edge.** The town-map generator treats any nearby open water as a river edge; the survey names it correctly (sea coast, lakeshore).
- **Rendering cost.** 4.4-6.3 ms GPU per frame on a fast discrete card, mostly the terrain shader; integrated GPUs are untested. If integrated GPUs struggle, render the static terrain into a texture once per data change.
- **Kingdom land** still cannot be entered, so held regions have no regional map yet.
