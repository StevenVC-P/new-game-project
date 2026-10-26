# Handoff

Snapshot for whoever picks the project up next. Update it when a milestone closes; durable detail lives in the linked docs, not here.

*Last updated: 2026-10-26, closing the map leg (world atlas and regional map).*

## Current Objective

The map leg is done: the game opens on a world atlas, entering an unclaimed region shows a miniature regional landscape built from that region's world geography, and founding leads into the existing town map. The next objective returns to the main track: the first playable village (`docs/IMPLEMENTATION_ROADMAP.md`).

## Status

- **Working:** world atlas (`docs/WORLD_MAP.md`); regional map art, camera, world-driven generation, and founding presentation (`docs/REGIONAL_MAP.md`); the World button round trip (fixed 2026-10-26). All 18 test scripts pass; import validation is clean.
- **Branches:** the owner approved this leg and `develop` was merged into `main` on 2026-10-26; both are pushed.
- **Unchanged:** the town map, economy numbers, and the original region generator (maps made without world data are byte-identical, checked by fingerprints in `tests/region_map_validation.gd`).

## Decisions Made (Don't Re-litigate Without The Owner)

- The world is hand-authored; detail noise uses fixed seeds, so it is identical every run. Owner check pending: whether "no randomization" was meant to exclude that noise too (`docs/WORLD_MAP.md`).
- Each regional map is a representative window of its world region, not a true-scale zoom. Geography carries over; distances do not.
- Regional decoration never shows what the tile data does not hold. Tests enforce it.
- Lakes and sea are new open-water tile types (`lake`, `sea`) used only in world regions.

## Open Owner Decision

World-driven regions change what towns start with. A map-luck probe across 14 regions of every climate got 40/42 towns off the ground, against 47/48 on the original maps. This is accepted for now but not confirmed as intended balance (`docs/REGIONAL_MAP.md`, "Gameplay Effect Of World Geography").

## Remaining Work (Map Leg, Deferred)

In rough priority order; details in each doc's "Remaining Work" section.

1. Town maps treat coasts and lakes as a river edge (the survey already names them correctly).
2. Development the simulation can't feed yet: cleared woodland, player-built roads, abandoned settlements, mines.
3. Regional settlement depiction is rule-based, not taken from the town map's layout.
4. Kingdom land cannot be entered; only one player settlement is supported.
5. Performance on integrated GPUs is untested (regional map: 4.4-6.3 ms GPU per frame on an RTX 3070 Ti).

## Risks And Gotchas

- **`main.gd` input:** when a click switches views (World, Back, Found Town), mark it handled with `get_viewport().set_input_as_handled()`. Otherwise the newly shown view receives the same click. The World button bounced straight back to the region because of this.
- **Headless tests:** the root window is 64x64, so docked panels cover the map; tests that click set `root.size` first.
- **Git:** this repo's `.git` belongs to another Windows account; run git as `git -c safe.directory=D:/AI/projects/incubating/games/new-game-godot ...`.
- **Visual checks** need a real window (no `--headless`): `tests/visual/*_capture.gd`, commands in `CLAUDE.md`.
