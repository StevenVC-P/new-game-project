# World Map

The world atlas: the planet shown as a painterly physical atlas, sitting above the regional map in the hierarchy **World -> Region -> Settlement**. Built 2026-10-25 on `feature/world-map` around one hand-authored planet; since 2026-10-26 every game is played on a newly generated planet (`feature/procedural-world`), and the authored planet remains as the reference and test world. It is a foundation for later political, economic, and cultural simulation; none of that simulation exists yet.

## Seeing It

- **In the game:** the game opens on the world atlas of a newly generated planet. The top bar shows its seed; `--world-seed=N` after `--` on the command line replays it. Click a region to inspect it; **Enter region** (or double-click, or Enter) opens the regional map there, and zooming in past the atlas's closest view lands on the regional map at the same place and scale. The regional map's top bar has a **World** button back to the atlas, and zooming out past its widest view returns too.
- **Isolated:** run `scenes/world_map_demo.tscn` (F6 in the editor); it shows the authored planet.
- **Screenshots:** `tests/visual/world_map_capture.gd` renders nine views of the authored planet (planet, continents, close zoom, a selected region, the wrap seam) to PNG files, or with `seed=N` a generated planet's continents, a capital, a frontier region, and the seam. It needs a window, so run it without `--headless` (command in `CLAUDE.md`).

Controls: drag (left, right, or middle) to pan; mouse wheel, `+`/`-`, or trackpad pinch to zoom toward the cursor; WASD/arrows pan; Home resets; Escape or right-click clears the selection; B, R, T, L toggle borders, roads, towns, and labels.

## Architecture

Data, its construction, and its presentation are separate so generated or simulated data can replace the fixed world without touching the renderer.

| Stage | File | Role |
| --- | --- | --- |
| Generated world | `scripts/world/world_generator.gd`, `world_name_generator.gd` | A definition of the same shape from a seed: continents, ranges, climate, lakes, rivers, kingdoms, regions, settlements, roads, labels, and names. What the game plays on. |
| Authored world | `scripts/world/fixed_world_definition.gd` | Everything hand-placed, in degrees: landmass outlines, lakes, mountain ranges, plateaus, climate and forest zones, rivers, kingdoms, region seeds, settlements, roads, map labels. The reference planet for tests and demos. |
| Builder | `scripts/world/world_field_builder.gd` | Turns a definition into `WorldMapData`: terrain fields, region partition, settlement placement, road geometry, region summaries. Deterministic. Runs in two halves (`begin_world`, `finish_world`) so the generator can read the built land in between. |
| Model | `scripts/world/world_map_data.gd` | The world as data (kingdoms, regions, settlements, roads, rivers, fields) plus lookups (`region_id_at`, wrapping). Emits `changed(layer)`. |
| Renderer | `scripts/visuals/world_map/` | `WorldMapView` (camera, input, selection) and one node per layer: terrain shader, rivers, settlement footprints, roads, settlement icons, labels. `WorldMapStyle` holds colors and zoom rules. |
| Terrain shader | `shaders/world_terrain.gdshader` | Biomes, relief shading, water, coast, cultivated land, and political borders, all from data textures. |
| HUD | `scripts/ui/world_map_panel.gd` | Top bar, layer toggles, region/settlement inspector, tooltip, legend. |

A future system changes the world by editing `WorldMapData` and calling `notify_changed(layer)` with `terrain`, `political`, `settlements`, or `roads`; the view rebuilds only that layer (a texture upload or one layer's draw commands).

## Decisions And Why

- **A generated planet each game, continent styled (owner, 2026-10-26).** The owner asked for more random generation while keeping continents. `WorldGenerator` plans what the authored world spells out by hand and leaves the drawing to the same builder, so the atlas, regional map, and town map work unchanged. How it plans:
  - *Continents* are chains of overlapping, stretched, wobbly lobes along a wandering spine, grown outward lobe by lobe until about 27-32% of the planet is land, with at least 7 degrees of sea between continents (the builder's coastline warp moves coasts up to about 6 degrees, so narrower gaps let continents merge). Archipelagos and lone islands come after. The date line is moved into the emptiest ocean, because roads are pathfound without wrapping.
  - *Ranges, highlands, lakes, and climate* are placed on the planned continents. Ranges cast rain shadows by latitude (easterlies in the tropics and polar zones, westerlies between 30 and 60 degrees); a subtropical interior gets at most one great desert; wet belts get rain and forest.
  - *Rivers* are drained over the built elevation with a priority flood from the sea, so every river reaches the sea (through lakes and out of hollows). The largest basins become rivers; major rivers get tributaries.
  - *Regions* are seeded by dart throwing (about one per 420 land cells; islands with room get their own), nudged toward rivers and coasts, and grown with the builder's own region growth. The builder takes that partition over instead of growing it again.
  - *Kingdoms* (5-8) start at the most habitable regions, kept four regions apart, and grow to a size (one large, the rest small to middling); the rest is frontier. Some border regions between kingdoms become contested, and kingdoms claim some frontier on their borders. Each kingdom has a culture whose sounds name its towns, regions, and rivers (`WorldNameGenerator`, which never repeats a name and blocks a short list of words a player would read as a joke or a slur).
  - *Settlements and roads:* a town at every kingdom region's seed (the capital's tier follows the kingdom's size, and in some large kingdoms a port outgrows the capital), villages on rivers and coasts, and a village in about half the frontier regions. Major routes join each kingdom's cities, towns and villages tie in to the nearest town, and neighbouring kingdoms share one road.
  - The same seed always builds the same planet. `tests/world_generator_validation.gd` checks the design rules (no build warnings, several continents, little polar land, capitals inside their kingdoms, unclaimed and contested frontier) on several seeds; 30 seeds passed on 2026-10-26.
- **The authored planet stays.** Tests that look up places by name (Meander Plains, Highmoor) and the balance tools use it, and it remains the visual reference. `main.gd` plays on it when `use_authored_world` is set.
- **Detail noise uses fixed seeds.** Coastlines, climate band edges, ridge texture, and region border wiggle use noise; in a generated world its seed comes from the world seed. Hand-drawing detail at that scale is impractical, and without it coasts read as blobs and borders as boxes.
- **Less polar ice (owner, 2026-10-26).** Generated land stays below about 72 degrees north and 58 degrees south, so no land shelf spans a pole. The far south's extra chill is smaller and closer to the pole (it had turned everything past 60 degrees south to ice), and pack ice starts at 77 degrees north and 72 degrees south (was 75 and 64). The authored White Shelf is now tundra at its edge with ice toward the pole.
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
- **Startup cost.** Generating and building the world takes about 3.4 s on the main thread when the game starts (the authored world 2.4 s; the generator's own share is about 1 s), and the regional terrain's setup about 1 s more when the regional map is first needed. Caching the built fields or building on a thread are the options if it becomes a problem.
- **Only one player settlement is supported,** so after founding other regions are view-only.
- **Capacity.** The political texture carries at most 254 regions and 64 kingdoms.
- **Not built (per the brief):** trade, wealth, culture, migration, or resource map modes; sea lanes; culture-specific architecture; world simulation of any kind.
- **Measured on one machine only** (RTX 3070 Ti: about 2 ms GPU per frame at any zoom). Integrated GPUs are untested.
- **Fonts.** Labels use an installed serif face (Palatino Linotype, Book Antiqua, Georgia, Cambria, Times New Roman) via `SystemFont`, falling back to Godot's default font.
- **Label placement is greedy.** Lower-priority labels (small villages, regions) drop out where space is tight.

## Changing The World

For generated worlds, change `scripts/world/world_generator.gd` and run `tests/world_generator_validation.gd` (pass more seeds after `--` for a wider sweep), then look at a few seeds with `tests/visual/world_map_capture.gd -- <dir> seed=N` and play openings on one with `tests/sim/map_luck_check.gd -- --world-seed=N` (on 2026-10-26: 38/42 and 40/42 towns off the ground on seeds 1 and 2, against 40/42 on the authored planet, which the polar change left at 40/42 and 46/48).

For the authored world, edit `scripts/world/fixed_world_definition.gd`, then run `tests/world_map_validation.gd`. It fails on any build warning (a road that cannot be routed over land, a settlement at sea, a capital outside its kingdom, a river that does not reach the sea) and checks the design rules (unclaimed and contested frontier exist, a small capital and an outgrown capital exist, the build is deterministic).
