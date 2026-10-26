# World Map

The world atlas: one fixed, hand-authored planet shown as a painterly physical atlas, sitting above the regional map in the hierarchy **World -> Region -> Settlement**. Built 2026-10-25 on `feature/world-map`. It is a foundation for later political, economic, and cultural simulation; none of that simulation exists yet.

## Seeing It

- **In the game:** the game now opens on the world atlas. Click a region to inspect it; **Enter region** (or double-click, or Enter) opens the regional map there, and zooming in past the atlas's closest view lands on the regional map at the same place and scale. The regional map's top bar has a **World** button back to the atlas, and zooming out past its widest view returns too.
- **Isolated:** run `scenes/world_map_demo.tscn` (F6 in the editor).
- **Screenshots:** `tests/visual/world_map_capture.gd` renders nine views (planet, continents, close zoom, a selected region, the wrap seam) to PNG files. It needs a window, so run it without `--headless` (command in `CLAUDE.md`).

Controls: drag (left, right, or middle) to pan; mouse wheel, `+`/`-`, or trackpad pinch to zoom toward the cursor; WASD/arrows pan; Home resets; Escape or right-click clears the selection; B, R, T, L toggle borders, roads, towns, and labels.

## Architecture

Data, its construction, and its presentation are separate so generated or simulated data can replace the fixed world without touching the renderer.

| Stage | File | Role |
| --- | --- | --- |
| Authored world | `scripts/world/fixed_world_definition.gd` | Everything hand-placed, in degrees: landmass outlines, lakes, mountain ranges, plateaus, climate and forest zones, rivers, kingdoms, region seeds, settlements, roads, map labels. |
| Builder | `scripts/world/world_field_builder.gd` | Turns a definition into `WorldMapData`: terrain fields, region partition, settlement placement, road geometry, region summaries. Deterministic. |
| Model | `scripts/world/world_map_data.gd` | The world as data (kingdoms, regions, settlements, roads, rivers, fields) plus lookups (`region_id_at`, wrapping). Emits `changed(layer)`. |
| Renderer | `scripts/visuals/world_map/` | `WorldMapView` (camera, input, selection) and one node per layer: terrain shader, rivers, settlement footprints, roads, settlement icons, labels. `WorldMapStyle` holds colors and zoom rules. |
| Terrain shader | `shaders/world_terrain.gdshader` | Biomes, relief shading, water, coast, cultivated land, and political borders, all from data textures. |
| HUD | `scripts/ui/world_map_panel.gd` | Top bar, layer toggles, region/settlement inspector, tooltip, legend. |

A future system changes the world by editing `WorldMapData` and calling `notify_changed(layer)` with `terrain`, `political`, `settlements`, or `roads`; the view rebuilds only that layer (a texture upload or one layer's draw commands).

## Decisions And Why

- **No procedural generation, but fixed detail noise.** The layout (every coastline, range, river, kingdom, settlement, and road) is authored. Coastlines, climate band edges, ridge texture, and region border wiggle use noise with a constant seed, so the same world is built on every run and every machine. Hand-drawing detail at that scale is impractical, and without it coasts read as blobs and borders as boxes. *Owner check:* if "no randomization" was meant to exclude this too, the alternative is denser authored outlines.
- **One shader quad instead of tiles or nodes.** Terrain is a 1024x512 field (elevation, moisture, forest, relief) drawn by one shader; panning never touches the CPU. Relief comes from hillshading the elevation plus fixed ridged noise, so ranges read as mountain ranges rather than icons, and forests read as broad textured areas.
- **Borders without fills.** Kingdoms show a thin border line and a soft ribbon of their color just inside it; land keeps its natural colors. The shader smooths the 512x256 region grid into curved borders, and regions are spread into the sea so borders never trace coastlines.
- **Borders follow geography.** Regions grow outward from authored seed points; crossing mountains, high ground, and rivers is expensive, so borders settle on ranges and rivers.
- **Control is separate from claims and influence.** A region has one controlling kingdom (or none) and a list of claimants. Contested regions are hatched. Economic and cultural influence are not modeled and should become their own layers, not reuse ownership.
- **Capital status is separate from size.** Capitals carry a pennant in the kingdom's color. Carvel's capital is a town, and Aldermark's largest city (Varenne) is not its capital.
- **Roads are physical classes.** Major, regional, and local roads differ by drawing, not traffic. Routes are pathfound over land (mountains costly), major routes first, and later roads prefer existing roadbed so networks merge.
- **Camera is a transform, not a Camera2D,** so the atlas lives on its own `CanvasLayer` without disturbing `main.gd`'s screen-space drawing.
- **Fully zoomed out, the map fills the screen height.** Pole to pole spans the area below the top bar; the sides need no fit because the map wraps. The game window opens maximized (1600x900 when restored, set in `project.godot`) so the atlas uses the whole screen.
- **Horizontal wrap draws only visible copies.** Each layer can draw the planet at three offsets; it records only the copies on screen and re-records when the view crosses the seam. This cut per-frame canvas CPU time at close zoom from 9-12 ms to 2-3 ms.

## Level Of Detail

| Zoom (screen px per world unit) | Shows |
| --- | --- |
| Fully out (about 0.17 to 0.4, set by window height) to 0.3 | Continents, biomes, kingdom names and borders, capitals and great cities, faint major routes, ocean and continent names |
| 0.3 to 0.75 | Cities, then towns; regional roads; minor rivers; landform and sea names; region names and boundaries from ~0.55 |
| 0.75 to 1.4 | Villages; local roads; urban footprints fade in; kingdom names fade out |
| 1.4 to 4.0 | Rooftop texture in footprints, field patchwork around towns, forest clumps |

The rules live in `WorldMapStyle`, shared by drawing and label collision.

## Integration With The Existing Game

`scripts/main.gd` has a third view, `VIEW_WORLD`, and opens on it. Its input and drawing return early in that view; the atlas handles its own input.

- The regional map is the atlas magnified: one regional tile is 1.2 world units, and regional zoom 0.4 equals the atlas's closest zoom (4.0). `WorldMapView.zoom_in_past_max` and `RegionMapView.zoom_out_past_min` hand the view over at that scale, keeping the point under the cursor in place. Details: `docs/REGIONAL_MAP.md`.
- Every region can be viewed. Only land no kingdom holds can be settled: the player starts as free settlers on frontier land (`docs/GAME_VISION.md`), so kingdom regions show **View region** and founding there is refused.
- Entering a region looks at its main settlement. Before founding, the founding neighbourhood moves there; after founding, other regions are view-only because only one player settlement is supported.
- The calendar does not advance on the atlas before the regional map has been shown.

## Remaining Work And Limitations

- **Regional maps follow the world** (done since): the regional map is one continuous, true-scale map of the planet; see `docs/REGIONAL_MAP.md`.
- **Startup cost.** Building the world takes about 2.4 s on the main thread when the game starts, and the regional terrain's setup about 1 s more when the regional map is first needed. Caching the built fields or building on a thread are the options if it becomes a problem.
- **Only one player settlement is supported,** so after founding other regions are view-only.
- **Capacity.** The political texture carries at most 254 regions and 64 kingdoms.
- **Not built (per the brief):** trade, wealth, culture, migration, or resource map modes; sea lanes; culture-specific architecture; world simulation of any kind.
- **Measured on one machine only** (RTX 3070 Ti: about 2 ms GPU per frame at any zoom). Integrated GPUs are untested.
- **Fonts.** Labels use an installed serif face (Palatino Linotype, Book Antiqua, Georgia, Cambria, Times New Roman) via `SystemFont`, falling back to Godot's default font.
- **Label placement is greedy.** Lower-priority labels (small villages, regions) drop out where space is tight.

## Changing The World

Edit `scripts/world/fixed_world_definition.gd`, then run `tests/world_map_validation.gd`. It fails on any build warning (a road that cannot be routed over land, a settlement at sea, a capital outside its kingdom, a river that does not reach the sea) and checks the design rules (unclaimed and contested frontier exist, a small capital and an outgrown capital exist, the build is deterministic).
