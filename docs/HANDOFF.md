# Handoff

Snapshot for whoever picks the project up next. Update it when a milestone closes; durable detail lives in the linked docs, not here.

*Last updated: 2026-10-26, after the continuous regional map.*

## Current Objective

The map leg is done again, now with one continuous regional map: it matches the world atlas at true scale, scrolls seamlessly from region to region (wrapping east-west), and hands off to the atlas by zooming. The next objective returns to the main track: the first playable village (`docs/IMPLEMENTATION_ROADMAP.md`).

## Status

- **Working:** world atlas (`docs/WORLD_MAP.md`); continuous regional map with streamed chunks, borders matching the atlas, founding anywhere on frontier land, view-only kingdom land, and zoom hand-off both ways (`docs/REGIONAL_MAP.md`). All 19 headless test scripts pass; import validation is clean; the windowed captures were reviewed by eye.
- **Branches:** the work is on `feature/continuous-region-map` (from `develop`), merged into `develop`. `main` waits for owner review (AGENTS.md).
- **Unchanged:** the town map, economy numbers, and the original region generator (maps made without the world are byte-identical, checked by fingerprints in `tests/region_map_validation.gd`).

## Decisions Made (Don't Re-litigate Without The Owner)

- **The regional map is the atlas magnified (owner, 2026-10-26).** One continuous map of the planet at the old tile scale (1 tile = 1.2 world units). This replaces the earlier "representative window" per region.
- **The whole planet can be viewed; only frontier land can be settled (owner, 2026-10-26).** Kingdom land is view-only; founding there is refused with the kingdom's name. After founding, other regions are view-only too (one player settlement).
- **Founding is allowed on any unclaimed or contested land (owner, 2026-10-26).** The founding neighbourhood (160x100 tiles) follows the camera until a town is founded, then stays put.
- **Zooming hands off between the maps (owner, 2026-10-26)** at matching scale: regional zoom 0.4 = atlas zoom 4.0.
- The world is hand-authored; detail noise uses fixed seeds. Owner check still pending: whether "no randomization" was meant to exclude that noise too (`docs/WORLD_MAP.md`).
- Regional decoration never shows what the tile data does not hold. Tests enforce it.

## Open Owner Decisions

1. **Remove the unused world-window code?** `RegionGeography`, the world path of `RegionMapGenerator`, and `RegionShowcase.build` are no longer used by the game, only by `tests/region_map_validation.gd`. Removing them means deleting `scripts/world/region_geography.gd` and trimming that test.
2. **Balance.** Starting land shifted again: the map-luck probe now gets 42/42 towns off the ground across 14 frontier regions (earlier world-window maps 40/42, original maps 47/48). Accepted for now, not confirmed as intended.
3. **Founding on frozen land.** Polar frontier offers thousands of valid founding sites. Should ice refuse founding?

## Remaining Work (Map Leg, Deferred)

In rough priority order; details in each doc's "Remaining Work" section.

1. Town maps treat coasts and lakes as a river edge (the survey already names them correctly).
2. Development the simulation can't feed yet: cleared woodland, player-built roads beyond the town's spur, abandoned settlements, mines.
3. Regional settlement depiction is rule-based, not taken from the town map's layout.
4. Only one player settlement is supported; only towns in the neighbourhood can trade.
5. Performance on integrated GPUs is untested (RTX 3070 Ti: 5-7 ms GPU, 1-4 ms CPU per frame; ~65 ms per chunk on a worker thread).

## Risks And Gotchas

- **Chunks must stay pointwise.** Every regional tile must depend only on its global position (and the world). Anything region-wide or order-dependent makes chunks disagree at their edges; `tests/regional_terrain_validation.gd` compares every shared tile.
- **Worker threads and exit:** call `RegionalTerrain.wait_for_tasks()` before quitting a script that streamed chunks (the view does it on `_exit_tree`), or Godot hangs on exit. Shared state the workers touch (`RegionalTerrain.chunks`) is read only under its mutex.
- **Large coordinates:** global map units reach 72,000. Keep polygons in coordinates local to their chunk or settlement window, or triangulation fails.
- **Frame budget on the maps** (details in `docs/REGIONAL_MAP.md`, "Performance"): don't toggle `visible` on map layers (it redraws everything under them; use `RenderingServer.canvas_item_set_visible`), keep main-thread work per frame well under 16.7 ms (vsync doubles a frame that runs over), and keep regional coordinates straight: `RegionMapView.screen_to_map` is the neighbourhood's, the camera is global (`screen_to_global_map`). Mixing them made wheel zoom teleport the camera.
- **Worker task ids:** `WorkerThreadPool.wait_for_task_completion` releases the id; don't ask `is_task_completed` about it afterwards (a wait loop that did spun forever).
- **`main.gd` input:** when a click or wheel step switches views (World, Back, Found Town, zoom hand-off), mark it handled with `get_viewport().set_input_as_handled()`. Otherwise the newly shown view receives the same input.
- **Headless tests:** the root window is 64x64, so docked panels cover the map; tests that click set `root.size` first. Streaming in headless takes several seconds; wait on wall-clock time, not frame counts.
- **Git:** this repo's `.git` belongs to another Windows account; run git as `git -c safe.directory=D:/AI/projects/incubating/games/new-game-godot ...`.
- **Visual checks** need a real window (no `--headless`): `tests/visual/*_capture.gd`, commands in `CLAUDE.md`.
