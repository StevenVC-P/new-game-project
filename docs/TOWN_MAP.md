# Town Map

The town map is the smallest scale under the world atlas and the regional map: the player's town on its 64x44 tiles, where houses and workplaces are placed. Since 2026-10-26 it is the regional land around the site magnified four times, drawn in the regional map's miniature style under a pan and zoom camera, so zooming from the regional map into a town reads as the same world closer up.

## How To Run And Check It

- **In the game:** found a town on the regional map; the town view opens fitted to the window beside the sidebar. Wheel zooms toward the cursor (up to 6x), left or middle drag pans, arrow keys pan (letters and digits choose buildings here), Home refits. A click is a press and release without a drag.
- **Generator checks:** `tests/town_map_validation.gd` (headless): the same site always gives the same town; deep inside regional water or mountains the town has water or rock, woods are wooded apart from glades, open land is open apart from copses; every town keeps its floors; original (bounded) regional maps still get towns.
- **View checks:** `tests/town_map_view_validation.gd` (headless, plays the real flow): the town opens fitted beside a full-height sidebar; screen and tile coordinates agree at every zoom; a click plans the chosen building on the tile under the cursor and the town builds it there, the road and plot tools work (`docs/TOWN_BUILDING_MODEL.md`); a drag pans without placing; the wheel keeps the point under the cursor; sidebar clicks never reach the map; ground details stand only on open ground.
- **What town maps hold:** `tests/sim/town_map_probe.gd` prints the spread of farmland, trees, water, rock, deposits, roads, and buildable land over 160 real sites, and generation times. The site survey's thresholds come from it.
- **Screenshots:** `tests/visual/town_map_capture.gd` finds showcase sites (river, lakeshore, coast, woods, stone, arid, cold, plains) and renders each fitted and close up, a town grown by the stand-in player, every building type in both tiers, and the real game with a house selected, with `[PERF]` lines. Needs a window (command in `CLAUDE.md`).

## Scale And Generation

`scripts/world/local_city_map_generator.gd` makes the town map from the regional tiles around the site (owner decision 2026-10-26).

- **Four town tiles per regional tile.** The 64x44 town map covers the 16x11 regional tiles around the site, about its 7-tile catchment (the gold circle on the regional map). A 2x2 house is half a regional tile, close to how big the regional map draws houses.
- **Blended, warped, and noised.** Each town tile samples the regional fields (water, mountain, hill, forest, fertile, deposit, road) bilinearly between regional tile centers. The sample point moves by up to 0.45 regional tiles along a slow noise (domain warp), and a finer noise moves each threshold, so shores and wood edges curve instead of showing 4x4 blocks. Interiors never move: the warp stays under half a tile.
- **What the region holds, the town holds.** River, lake, and sea become water with a `water_kind`; mountains become rock; deposits become rock holding `resource` stone or iron; regional roads become `has_road` tiles, which block building; forest becomes woods.
- **What the region cannot say is decided at town scale.** Regional fertility only marks land near water, so the rest of the open land is arable in pockets ranked by a slow noise, with a share set by the site's temperature and moisture (6% on dry or frozen land up to 34% on wet temperate land, halved on hills). Hills get rock outcrops (22%), woods get glades (8%), open land gets copses (3%).
- **Floors.** The town's heart (radius 4) is cleared of trees and rock; every town keeps 180 buildable tiles, 18 fertile tiles, and 90 tree tiles, made up nearest the center first.
- **Deterministic per site.** Noise is sampled at global town coordinates, never from the game's random generator, so a site always gives the same town and the founded town is exactly the surveyed map.
- On the continuous map, `generate_from_terrain` reads a window cut around the site from `RegionalTerrain`, so a site near the neighbourhood's edge still gets the land beyond it. The site's climate comes from `RegionalTerrain.climate_at` and is stored on the site profile (`SettlementSiteProfile.climate`).

## Architecture

```
main.gd (rules, sidebar, input routing) --set_city / interaction state--> TownMapView (CanvasLayer -1, camera on map_root)
                                                                              |- table (screen space)
City.local_map + City.buildings -------------------------------------------> |- TownBoardLayer
SettlementSiteProfile.climate --------------------------------------------> |- TownGroundLayer (shaders/town_terrain.gdshader)
                                                                              |- TownFeatureLayer (+ shrub and flower canvases)
                                                                              |- TownStructureLayer
                                                                              '- TownOverlayLayer (+ placement ghost)
```

- **`main.gd`** owns the town and its rules. `sync_town_map_view` hands the view the town and the interaction state each frame (hovered tile, building being placed and whether it fits, inspected building, home-work links, walker time). Mouse events over the map go to `TownMapView.handle_mouse_event`; a click comes back as `map_clicked` and runs the same selection and placement as before (`on_town_map_clicked`). The sidebar is docked full height on the right (`get_city_sidebar_rect`), and the map fills the rest (`get_town_map_screen_rect`).
- **`TownMapView`** draws what it is given. A new town map rebuilds everything; otherwise it compares a development signature each frame (building type, place, upkeep in steps of ten, staffed or not, families camped) and re-records only the buildings and ground details when it changes.
- **Painters are shared with the regional map.** `LandscapePainter` (trees, shrubs, flowers, peaks, boulders) and `BuildingPainter` (gabled buildings) were moved out of the regional layers; the regional captures were pixel-identical before and after. Trees take the climate's tree style (`RegionMapStyle.tree_style_for`) at 1.7x their regional size, and the ground uses `natural_palette.gdshaderinc` like the other two maps.
- **`BuildingVisuals`** maps each building type to a drawing and materials (the intended hook for sprites); `TownBuildingPainter` draws them. Tier 0 types have rougher drawings of their own.
- **`CityBuildingOverlay`** (the building card) is placed from the view's screen rectangle for the building and kept inside the map area.

## Layers

| Layer | Draws | Recorded again when |
| --- | --- | --- |
| Table, board | The town as a model on a table, with the cut soil edge | Screen area changes |
| Ground (shader) | Meadow and farmland in the site's climate colors, forest floor, rock and scree, stone and ore outcrops, tracks with ruts, banks and beaches, water with depth, gloss, and surf | New town map (camera moves change uniforms) |
| Features | Trees on tree tiles, boulders on rock and deposits; shrubs from zoom 2.0 and flowers from 3.2 on open ground | New town map; shrubs and flowers when buildings change |
| Structures | Every building on its plot; a tent for each family in temporary shelter and a bedroll by a fire for each unsheltered family, at the town's heart | Development signature changes, level of detail |
| Overlay | Placement footprint and ghost, hover, selection, home-work links, worker badges, house pennants, upkeep plates, walkers | Every frame |

Shrub and flower visibility is switched in the rendering server, never with `visible` (which re-records); the whole view is hidden the same way when another view is shown, and re-applies that state when it enters the tree.

## Key Decisions

- **The town is the region magnified (owner, 2026-10-26).** Town maps continue the regional landscape, replacing the abstract board shaped by direction hints, where lakes and coasts became a river edge.
- **Pan and zoom, fitted on open (owner, 2026-10-26).** Like the regional map; arrow keys pan because letters and digits choose buildings.
- **Same information, restyled (owner, 2026-10-26).** Worker dots became badges in the family's color (a red badge when vacant), preference stripes became pennants on houses, walkers became figures, and maintenance bars became slim plates. Plates show only when upkeep is below full or switched off, so "no plate" means fully maintained (a judgment call; easy to reverse in `TownOverlayLayer.draw_workplace_marks`). An idle workplace looks unused (fields lie fallow), and missing upkeep greys roofs.
- **The layout fills the window (owner, 2026-10-26).** The sidebar runs full height; when a selection fills it, the building key list shrinks to one line.
- **Decoration never shows what the town map does not hold.** Trees only on tree tiles, boulders only on rock, details never under buildings, tents only for families without a house.
- **Deposits are drawn, not yet required.** Town maps hold stone and ore since this change, but quarries can still stand anywhere: the access rule (owner decision 2026-10-25) is not built.
- **Small noise offsets in the shader.** Each town shifts its ground texture by under 100 tiles. Larger offsets lost float precision in the finest noise octaves and drew one-pixel lines across the ground.

## Performance

Measured at 1600x900 on an RTX 3070 Ti (`tests/visual/town_map_capture.gd`):

- Rendering: about 0.2 ms CPU per frame; GPU 2.4 ms fitted in the game, about 6.4 ms close up on a grown town (the regional map runs 5-6 ms).
- Generation: about 37 ms per town map (worst 56 ms), on the main thread when a site is picked. Most of it is noise sampling and the ranking sorts.

## Gameplay Effect

Town maps changed, so balance was re-measured (2026-10-26):

- The map-luck probe got 42/42 towns off the ground on the continuous map (unchanged) and 46/48 on the original maps (47/48 before; both failed towns had room for 12 farms and 12 camps, and the new generator no longer consumes the game's random numbers, so founders differ). The worst continuous site has room for 9 farms (12 before).
- Farmland grew: fertile tiles per town are 118-1196 (median 364) on the continuous map, against 79-671 (median 160) before. Tree tiles stay above the old floor (at least 90).
- Water appears only where regional water lies within the town's 16x11 regional tiles: most sites have none, where before every site within 5 regional tiles of a river got a riverbank. No rule uses water yet.

## Remaining Work And Limitations

- **The quarry access rule** (quarries on stone, owner decision 2026-10-25) is not built; the deposits it needs are on the map.
- **The regional map still draws the player's town by rule.** With the town map at a real scale, its buildings could now be placed on the regional map where they stand in town.
- **The player's spur road is not on the town map** (it is made after founding); world roads crossing the town's land are.
- **Seasons do not show** (fields keep one crop color), and walkers still walk in straight lines between home and work, across water too, as before (travel itself is routed: `TownLogistics`; the selected workplace's routes are drawn).
- Construction (sites, plots, the stockpile, storehouses, roads, routes) is drawn by `TownConstructionPainter` and the overlay; the design is in `docs/TOWN_BUILDING_MODEL.md`.
- **Generation runs on the main thread** at site pick (about 40 ms).
- **Bounded (original) regional maps carry no climate**, so their towns use temperate colors.
- **Integrated GPUs are untested.**
