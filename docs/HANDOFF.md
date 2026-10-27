# Handoff

Snapshot for whoever picks the project up next. Update it when a milestone closes; durable detail lives in the linked docs, not here.

*Last updated: 2026-10-27, after the world-window cleanup and frozen-ground founding.*

## Current Objective

Owner answers on three open decisions (2026-10-27), on `chore/remove-world-window-and-frozen-founding` from `develop`: the unused world-window code is removed; frozen ground refuses founding; balance waits for the next design pass.

Saved games (`feature/saved-games`, from `develop`, owner request 2026-10-27): a start menu, an in-game menu, named saves, and an autosave each season and on quit (`docs/SAVED_GAMES.md`). Merged into `develop`; `main` waits for the owner's look.

Before that, generated worlds (`feature/procedural-world`, from `develop`): every game now opens on a newly generated, continent-styled planet with a small polar ice cap (owner request, 2026-10-26). Merged into `develop`; `main` waits for the owner's look. Then the main track resumes.

Before that: town building is settled before it is locked in (`docs/TOWN_BUILDING_MODEL.md`): the player plans, families build over time, materials are carried from stores, layout costs or saves travel, and families build their own homes on residential plots. The owner approved it for `main`; the open decisions there remain for tuning, and the main track resumes: the first playable village (`docs/IMPLEMENTATION_ROADMAP.md`).

## Status

- **Working:** saved games and the start/in-game menus (`docs/SAVED_GAMES.md`): a town saved, loaded, and played 120 more days stays identical to the original; generated worlds (`WorldGenerator`; design in `docs/WORLD_MAP.md`): 30 seeds build without warnings, openings on generated planets get off the ground about as often as on the authored one (38/42 and 40/42 on seeds 1 and 2, authored now 41/42 continuous, since frozen regions are no longer picked, and 46/48 original); world atlas (`docs/WORLD_MAP.md`); continuous regional map (`docs/REGIONAL_MAP.md`); town map (`docs/TOWN_MAP.md`); town building: construction sites, builders, carried materials, travel costs, roads, storehouses, residential plots, families building homes (`docs/TOWN_BUILDING_MODEL.md`). All 25 headless test scripts pass (with `world_generator_validation` and `save_game_validation`); import validation is clean; generated planets were reviewed by eye (`world_map_capture` with `seed=`); `town_map_capture` (now with construction scenes) was reviewed by eye.
- **Balance:** with construction, the sensible opening stays 20/20 and map luck matches building instantly (46/48, 40/42); an opening that queues every house before the woodcutter falls from 20/20 to 13/20 (queue order). Numbers in the model doc.
- **Branches:** the town building work is on `feature/town-building-model` (from `develop`), merged into `develop`, and `develop` into `main` on the owner's approval (2026-10-26). `main` now carries the town map art and the town building model.
- **Unchanged:** the original region generator (fingerprints in `tests/region_map_validation.gd`); economy numbers other than the new construction and travel ones.

## Decisions Made (Don't Re-litigate Without The Owner)

- **Saved games (owner, 2026-10-27).** Named slots plus one autosave; a start menu (Continue, New world, Load game); autosave each in-game season and on quit.
- **Town building (owner brief, 2026-10-26).** Plan the town, families develop it; homes and workplaces separate; construction takes builder families, materials, and time; goods physically move (aggregated, not per item); no rigid slot caps; one construction pipeline for the player and for families or a future government; tier 0 never deadlocks. Implementation judgment calls are marked in `docs/TOWN_BUILDING_MODEL.md` and open to veto.

- **The town map is the region magnified (owner, 2026-10-26).** 4 town tiles per regional tile; what the regional map shows around a site is what the town gets. Town maps are deterministic per site.
- **Town view: pan and zoom, same information restyled, layout fills the window (owner, 2026-10-26).**
- **The regional map is the atlas magnified (owner, 2026-10-26).** One continuous map of the planet at the old tile scale (1 tile = 1.2 world units).
- **The whole planet can be viewed; only frontier land can be settled (owner, 2026-10-26).** After founding, other regions are view-only too (one player settlement).
- **Founding is allowed on any unclaimed or contested land (owner, 2026-10-26).** The founding neighbourhood (160x100 tiles) follows the camera until a town is founded, then stays put.
- **Zooming hands off between the atlas and regional map (owner, 2026-10-26)** at matching scale: regional zoom 0.4 = atlas zoom 4.0.
- **Frozen ground refuses founding, for now (owner, 2026-10-27).** The line is the regional map's own frozen temperature (snow, no farmland or woods); it closes the southern ice shelf, while cold tundra stays open (`docs/REGIONAL_MAP.md`).
- **Generated planets, continent styled, less polar ice (owner, 2026-10-26).** Replaces the earlier "no randomization" direction. A new seed each launch; the authored planet stays as the test and reference world (`docs/WORLD_MAP.md`).
- Decoration never shows what the tile data does not hold, on the regional and town maps. Tests enforce it.

## Open Owner Decisions

- **Generated worlds** (details in `docs/WORLD_MAP.md`): a new planet every launch with no way to pick one in the game yet (the seed shows in the atlas top bar; `-- --world-seed=N` replays it); is that the wanted default, or should the player choose or reroll? How much ice: generated land stops at about 72 N / 58 S, pack ice from 77 N / 72 S. Frontier tends to be tropical or dry, because kingdoms start on the most habitable land.

0. **Town building** (details in `docs/TOWN_BUILDING_MODEL.md`, Open Owner Decisions): helpers' spare time cannot be turned off; strict queue order vs builders favoring workplaces; upkeep grace counted from founding rather than per building; first-pass travel numbers; families building only on player-set plots.

1. **Upkeep plates only when they need attention?** The town view shows a workplace's upkeep plate only below full or when upkeep is off ("no plate" = fully maintained). The old view always showed a bar. Easy to reverse.
2. **Balance after the town terrain.** Farmland per town rose (median 364 fertile tiles, was 160); map-luck is 41/42 continuous (frozen regions are no longer picked, 2026-10-27), 46/48 original (was 47/48); most towns have no water. The owner will revisit it with the next design work (2026-10-27); don't tune it before then.
3. **Quarries on stone.** Deposits are on town maps now; the access rule decided on 2026-10-25 is still unbuilt. Next step when wanted.

## Remaining Work (Map Leg, Deferred)

In rough priority order; details in each doc's "Remaining Work" section.

1. Draw the player's town on the regional map from its real layout (possible now that town tiles have a real scale).
2. Development the simulation can't feed yet: cleared woodland, player-built roads beyond the town's spur (the spur is not on the town map either), abandoned settlements, mines.
3. Only one player settlement is supported; only towns in the neighbourhood can trade.
4. Town map generation runs on the main thread at site pick (about 40 ms).
5. Performance on integrated GPUs is untested (RTX 3070 Ti: regional 5-7 ms GPU, town 2.4-6.4 ms GPU, under 4 ms CPU per frame).
6. The regional view's zoom easing takes its anchor from the pixel-rounded map position and can drift a little (fixed in the town view; see `TownMapView._process`).

## Risks And Gotchas

- **Saves rebuild their planet from its seed.** Any change to `WorldGenerator` or `WorldFieldBuilder` output makes existing saves refuse to load (a world fingerprint catches it; `docs/SAVED_GAMES.md`). New `main.gd` state, object-valued domain fields, and caches need a line in `GameState`; `tests/save_game_validation.gd` catches a missed field in a town.
- **The project's main scene is `scenes/app.tscn`.** It sets `auto_accept_quit` off so closing the window autosaves first, then quits.
- **Generated worlds must stay deterministic per seed.** Draw only from the generator's own `rng`, iterate in a fixed order, and break sort ties by index; `tests/world_generator_validation.gd` builds a seed twice and compares. Tests that name places must set `main.use_authored_world` before adding `main` to the tree.
- **Startup is now about 3.4 s** on the main thread (generation plus build; was 2.4 s). Building on a thread is the next step if it bothers the owner.
- **Chunks must stay pointwise.** Every regional tile must depend only on its global position (and the world). Anything region-wide or order-dependent makes chunks disagree at their edges; `tests/regional_terrain_validation.gd` compares every shared tile.
- **Town maps must stay deterministic.** Never draw from the game's `rng` in `LocalCityMapGenerator`; the founded town must equal the surveyed map (`tests/founding_city_validation.gd`), and changing the generator changes balance: re-run `tests/sim/map_luck_check.gd` and `tests/sim/town_map_probe.gd` (survey thresholds).
- **Worker threads and exit:** call `RegionalTerrain.wait_for_tasks()` before quitting a script that streamed chunks, or Godot hangs on exit.
- **Large coordinates:** global map units reach 72,000. Keep polygons local to their chunk or settlement window. In shaders, keep noise coordinates small: big offsets lose precision in fine octaves and draw one-pixel lines.
- **Frame budget and visibility:** don't toggle `visible` on map layers (it re-records them); use `RenderingServer.canvas_item_set_visible`, and re-apply it in `_ready` for nodes hidden before entering the tree (the town view once covered the regional map that way). Keep main-thread work per frame well under 16.7 ms.
- **`main.gd` input:** when a click or wheel step switches views, mark it handled with `get_viewport().set_input_as_handled()`. Map clicks go through the views (`map_clicked`), not `main.gd`'s press handling.
- **Headless tests:** the root window is 64x64; tests that click set `root.size` first. Streaming takes several seconds; wait on wall-clock time.
- **New `class_name` scripts** are unknown until an import pass: run `scripts/validate_project.ps1` before running tests or captures.
- **Balance tools print a long household log.** Write their output to a file and filter it (`> log`); piping it through a shell pipe on Windows stalls Godot at a few percent CPU.
- **Buildings are never placed finished in play.** Everything goes through `TownConstruction`; `City.add_building` is the completion step (tests may still call it directly). City's helpers (`logistics`, `construction`) hold the city weakly, or towns leak.
- **Git:** this repo's `.git` belongs to another Windows account; run git as `git -c safe.directory=D:/AI/projects/incubating/games/new-game-godot ...`.
- **Visual checks** need a real window (no `--headless`): `tests/visual/*_capture.gd`, commands in `CLAUDE.md`.
