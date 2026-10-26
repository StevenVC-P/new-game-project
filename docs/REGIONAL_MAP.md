# Regional Map

The regional map is the middle scale between the world atlas and the town map: the whole planet at regional scale, drawn as a stylized miniature landscape you can scroll from region to region without edges. Its job is to show what a place offers (farmland, timber, stone, water, routes) and where a town can be founded. Since 2026-10-26 it is a true-scale magnification of the world atlas: one tile is 1.2 world units, so the planet is 6000x3000 tiles and a typical region is about 290x270 tiles.

## How To Run And Check It

- **In the game:** the game opens on the world atlas. Zoom in past the atlas's closest view (or choose a region and press Enter region) to land on the regional map at the same place and scale. Zoom out past the regional map's widest view to return to the atlas.
- **Demo scene:** `scenes/region_map_demo.tscn` opens the continuous map on the showcase regions. Keys 1-6 jump between showcases, G adds a grown player town, F, L, and B toggle founding sites, labels, and borders.
- **Data checks:** `tests/regional_terrain_validation.gd` (headless): chunks agree on every shared tile, including across the date line; generation is deterministic on any thread; coasts, rivers, high ground, and settlements follow the world; tile data keeps the decoration rules; every frontier region offers room to found; the view maps tiles to the screen and back. Prints `[PERF]` generation times.
- **Flow checks:** `tests/world_map_flow_validation.gd` (headless): entering regions, kingdom land as view-only, the founding neighbourhood following the camera, both zoom hand-offs, founding.
- **Screenshots:** `tests/visual/region_map_capture.gd` renders showcases near and far, a region border, the date line, and the widest view, with `[PERF]` render and panning times. `tests/visual/region_flow_capture.gd` plays atlas zoom-in, founding, a border crossing, and zoom-out. Both need a window (commands in `CLAUDE.md`).

## Architecture

```
WorldMapData --RegionalTerrain (setup: fields, streams, line index)--> RegionalChunkGenerator --> RegionalChunk (60x60 tiles, packed)
                                    |                                                                  |
main.gd: neighbourhood = extract_window() --> tiles, cities, roads (game rules)      RegionChunkStreamer --> chunk nodes
                                    \--set_neighbourhood--> RegionMapView <--------------------------------/
```

- **`scripts/world/regional_terrain.gd`** is the planet at regional scale. At setup it copies the world's fields and their local averages, prepares the atlas's region vote, traces minor streams downhill (the atlas draws only major rivers), and indexes rivers, streams, and roads by chunk. It generates chunks on `WorkerThreadPool`, caches them, and answers tile queries: `extract_window()` returns any window of the planet in the tile-dictionary format `RegionMapGenerator` produces, so the game's rules work unchanged.
- **`scripts/world/regional_chunk_generator.gd`** makes one chunk. Every tile is a function of its global position: noise is sampled on a cylinder at global tile coordinates (so it wraps at the date line) and compared, as a rank, against amounts read from the world's local averages; rivers, streams, and roads are stamped from their world courses with a meander that depends only on distance along the line. A 16-tile generation margin keeps every distance-based rule (valleys, farmland near water, shore depth, deposit clusters) exact, so neighbouring chunks agree tile for tile.
- **`scripts/visuals/region_map/`** draws it. `RegionMapView` owns the camera (a transform on `map_root`; east-west it wraps, north-south it stops at the poles) and two modes: the continuous map (`set_terrain`, `set_neighbourhood`) and the bounded region of the original maps (`set_region`). `RegionChunkStreamer` keeps chunks around the camera, building a few per frame: a terrain quad (`RegionChunkTerrain`), the world's roads, bridges, and settlements, and close up its trees and peaks (`RegionChunkFeatureLayer`). Behind them the world atlas's terrain is drawn at regional scale, so a chunk still generating shows the atlas, never a hole.
- **`main.gd`** owns the rules. They run on a **neighbourhood** of 160x100 tiles: `tiles`, `cities` (the world's settlements in it as neutral towns, plus the player's town), and `roads`, in the neighbourhood's own tile coordinates. Before founding, the neighbourhood follows the camera once it settles near the edge, and a click beyond it moves it there first. Founding pins it around the town. The view draws the neighbourhood's development at its place on the planet, and its public coordinates (`screen_to_map`, `screen_to_tile`, `map_to_screen`) are the neighbourhood's.

## Layers

Bottom to top. Permanent geography is separate from development, so a change rebuilds only what it touches.

| Layer | Draws | Rebuilt when |
| --- | --- | --- |
| Atlas backdrop | The world atlas's terrain at regional scale, where no chunk is ready yet | Never (camera moves change uniforms) |
| Chunk terrain (shader) | Lit relief, meadow, fertile land, rock and snow, deposits, shores, water, canopy from afar, kingdom and region borders | Chunk built |
| Fields | World settlements' fields; the neighbourhood's fields and quarries | Chunk built; towns change |
| Chunk features | Trees, peaks, boulders; shrubs and flowers up close (from zoom 1.0) | Chunk built, or development nearby clears ground |
| Structures | World roads and bridges, world settlements by tier; the neighbourhood's roads, towns, palisades, and the player's banner | Chunk built; towns or roads change |
| Sites, Overlay | Founding pegs; exclusion zones, hover, the chosen site's land (neighbourhood only) | Founding state, hover, zoom |
| Labels | Settlements, rivers, lakes, and from afar region names; the neighbourhood's towns | Camera, zoom, data |

The HUD names the region under the camera and its status (unclaimed, contested, or held by a kingdom).

## Key Decisions

- **True scale, one continuous map (owner decision 2026-10-26).** The regional map is the atlas magnified about 2.5 times beyond its closest view, at the old tile scale, so town spacing, catchment, and town maps keep their meaning. It replaces the earlier "representative window" of each region, which showed about a fifth of a region and could not join its neighbours.
- **The zoom hands off at matching scale.** Regional zoom 0.4 is exactly atlas zoom 4.0 (10 map units per world unit), so the hand-off keeps the point under the cursor in place in both directions.
- **The whole planet is viewable; only frontier land is settleable.** Kingdom land and, after founding, other regions are view-only; founding there is refused with the kingdom's name (`FoundingSiteHelper.kingdom_land_reason`).
- **The maps agree.** Coasts use the atlas's B-spline elevation; borders use the atlas shader's smooth vote over political cells, on both the GPU (regional shader) and the CPU (founding legality), so a border lies on the same curve everywhere.
- **Local rules, not region-wide amounts.** The earlier world-driven generator ranked a whole region's tiles to hit exact shares of woods and high ground. Pointwise rules compare noise ranks against the world's local averages instead, so shares vary around the target. The map-luck probe measures the effect (below).
- **Decoration never misrepresents the data.** Trees grow only on forest tiles, peaks only on mountains, boulders only on deposits, fields only on fertile land, buildings never on water, mountains, forest, or deposits, and bridges sit where roads cross rivers. A mountain on a world road becomes a hill: roads keep their passes.
- **Coordinates stay local to their chunk or settlement.** Global map units reach 72,000; single-precision vertices that far out are too coarse for house polygons, so shapes are built relative to their chunk or settlement window and the node is placed there.
- **The original generator is untouched.** Without the world, `RegionMapGenerator` still makes byte-identical maps (20 recorded fingerprints in `tests/region_map_validation.gd`), and the bounded view mode still draws them.
- **One palette with the world map.** Ground and canopy colors come from `shaders/natural_palette.gdshaderinc`, which the world shader also uses.

## Performance

Measured at 1600x900 on an RTX 3070 Ti (`[PERF]` lines in the tests and captures):

- Terrain setup: about 1 s on a worker thread while the atlas is shown, so the first zoom in does not wait for it.
- Chunk generation: about 65 ms per chunk on a worker thread; a fresh view streams in within 0.4-1.1 s.
- Rendering: 0.3-1 ms CPU and 5-6 ms GPU per frame; panning holds 60 fps (worst frame 17 ms).
- Scrolling from the atlas into a region and back holds 60 fps at the median; the worst single frames are 40-70 ms (they were 0.4-0.8 s).

What keeps it smooth, and must stay that way:

- **The founding neighbourhood is prepared on a worker thread** (`main.gd` `prepare_neighbourhood`: tiles, regions, settlements, founding sites); the main thread only applies it.
- **Trees are collected and painted one strip per frame**, nearest the middle of the view first (`RegionChunkStreamer.paint_pending_strips`); woods keep the shader's canopy until their trees are in. With vsync, a frame that runs past 16.7 ms waits for the next refresh, so even three strips per frame halved the frame rate.
- **Layers are hidden in the rendering server, not with `visible`.** Making a node visible queues a redraw of it and everything under it: showing the trees when zooming past 1.0 re-painted every chunk at once (0.2-0.3 s), and so did switching back from the atlas. `RegionMapView.set_shown` and the streamer's tree layers use `RenderingServer.canvas_item_set_visible`.
- **The atlas records its layers for an area three screens wide** and only re-records on leaving it, after the zoom drifts 15%, or when it settles (`WorldMapView.refresh_layer_recordings`); re-recording every layer on every zoom frame cost 110-150 ms per frame.
- **Zoom momentum crosses the hand-off.** A zoom aimed past either map's limit eases to the limit and the other map carries on with the rest (`zoom_out_past_min` / `zoom_in_past_max` pass the remaining factor), so there is no extra wheel step and no jump in scale.

## Gameplay Effect

The map-luck probe (`tests/sim/map_luck_check.gd`) founds 3 towns in each of 14 frontier regions of every climate on the continuous map and plays two years: 42/42 got off the ground (2026-10-26). The original maps get 47/48, and the earlier world-window maps got 40/42. Every frontier region offers at least 900 buildable tiles around its main settlement; the tightest neighbourhood probed (The Debatable Fells) had 700 valid founding sites.

## Remaining Work And Limitations

- **The old world-driven path is unused.** `RegionGeography` and the world path of `RegionMapGenerator` (and `RegionShowcase.build`) remain only for `tests/region_map_validation.gd`; removing them is pending the owner's go-ahead.
- **Settlements are depicted, not simulated.** World settlements are drawn from their world tier; the player's town from its buildings. Houses are placed by rule around roads, not from the town map's layout.
- **Neutral towns are rebuilt when the neighbourhood moves before founding**, which costs a short pause (a few hundred milliseconds when new chunks are needed). Only towns in the neighbourhood can trade.
- **Founding on ice is allowed.** Polar frontier offers thousands of valid sites; whether frozen land should refuse founding is a design question.
- **Town maps ignore coasts and lakes beyond the water edge** (the survey names them correctly).
- **Streams end in hollows.** A stream traced downhill can stop in a local low with no outlet; no pond is drawn there.
- **Integrated GPUs are untested.**
