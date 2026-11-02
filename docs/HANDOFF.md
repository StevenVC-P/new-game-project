# Handoff

Snapshot for whoever picks the project up next. Update it when a milestone closes; durable detail lives in the linked docs, not here.

*Last updated: 2026-11-02. `feature/autonomous-occupations` is merged into `develop` (Priority 5 closed); `main` is unchanged since "Merged 2026-11-01" below and awaits the owner's review.*

## Current Objective

**Next milestone (owner, 2026-11-02): household property, private exchange, communal contributions and treasury allocations.** It has its own architectural plan on branch `docs/property-and-communal-resources` (not merged), and the earlier audit `docs/TREASURY_AUDIT.md`. Nothing of it is built yet. A founding allocation is the intended lever on the first weeks.

**Priority 5 is closed** (`docs/IMPLEMENTATION_ROADMAP.md`, "Autonomous Occupations and Priority 5"; detail in `docs/AUTONOMOUS_OCCUPATIONS.md`, sixth round; agency in `docs/PLAYER_AGENCY_AUDIT.md`, round 6). On `develop`:
- **Occupations:** families choose every trade with a hand-work stage, by scored terms with reasons and seeded noise. Survival comes before a calling as hunger nears; for wool work the calling fades fully (the herding adjustment).
- **Shared land:** woods, fishing water and pasture are divided among the workplaces of their kind that are in use, so no land is counted twice.
- **The tool trap is fixed:** the reserve no longer blocks projects that draw nothing from it.
- **The hunting card:** it comes early and gives both sides as a choice. Kept woods are binding.
- **The founding regression:** it pins a viable founding (20261102) and a failed one (20261101).

**Previous behaviour stays reproducible:** `--meta=comfort_calling_kept,water_not_shared,pasture_not_shared` on `tests/sim/intervention_check.gd` reproduces the earlier defaults town for town.

**Accepted and open:**
- **Fishing:** honest counting lowers fishing towns' catch, by as much as 45% where huts share a lake. The owner accepted this; fishing balance may be revisited.
- **Early foundings:** they are still decided by a few first-week work choices. The first three trades alone still do somewhat better on hard sites, and extra founding food does not help. No further occupation tuning is planned.

**Worktrees** beside the main folder (all detached, safe to remove when no longer wanted):
- `ngg-occupations`: the merged branch;
- `ngg-p5-runs`: the final batches' commit;
- `ngg-p5-base`: the Priority 5 baseline, 7bf9d34;
- `ngg-occ-runs` to `ngg-occ-runs11`: earlier comparison commits;
- `ngg-baseline`: `develop` before the merge.

Diagnostics: `--leave-out`, `--veto`, `--meta`, `--trace`, `--trace-tools`, `--provisions` (`docs/TESTING.md`).

**Merged 2026-11-01 (owner-approved: `develop`, then `develop` into `main`).** Each item has a design doc with its owner decisions, how it was built, validation results and open decisions:
- **Step 3 interface** (community priority and residential land in the game; `docs/TOWN_UI.md`, `docs/HOME_SITES.md`, `docs/COMMUNITY_PRIORITIES.md`).
- **Guiding wisdom** (`docs/GUIDING_WISDOM.md`): four wisdoms as the town's lasting expectations, chosen by the player as Expedition Leader, then as Elder from Village (a third slot).
- **Occupation reconsideration** (`docs/OCCUPATION_RECONSIDERATION.md`): families look again at their work, rarely, for their own reasons. It replaced the instant calling swap.
- **Household self-sufficiency and proficiency** (`docs/HOUSEHOLD_SELF_SUFFICIENCY.md`, `HouseholdEconomy`):
  - families give 10–30% of their day to a garden near home, wood or mending, at hand-work rates;
  - a food larder per family, by choice;
  - shortage and hunger are each family's own;
  - proficiency is learned by practice and fades.
- **Emergent recognition and the Speaker of the Gathering** (`docs/EMERGENT_RECOGNITION_AND_LEADERSHIP.md`, `TownRegard`):
  - families notice, admire and resent each other's achievements;
  - influence in parts;
  - from Village, the Elder appoints a Speaker from the three most influential households;
  - the Speaker leads its followers on the priority, decides first claim within the Elder's rules, and urges settlement.

  It replaced the player's honours and the Reward helping toggle.
- **Investigation: why no toolmaker or herder's fold** (`docs/WORKPLACE_CHOICE_INVESTIGATION.md`). Findings only. Nothing was changed.

**Open owner decisions from this round** (details in each doc):
1. **Proficiency's cost** (self-sufficiency doc, "For the owner"). Novices at 60% output and the pull toward known work cost ordinary towns 10–15 people, and cancel most of the gain on difficult land. Options:
   - keep it;
   - soften to 75%;
   - give founders basic trades;
   - first separate which half does it.
2. **A harder stores disruption for validation** (the first autumn, or food before winter).
3. **Herding, fishing and hunting** can't be chosen by families at all. They are missing from `FamilyInitiative.ACTIVITIES` and have no hand-work stage. Recommended: a family whose calling points there builds it itself, through the improvement pipeline.
4. **The tool gap.** A town whose founders all take food or wood work, with no forge-called family, may never get tool work (one test town sat at 0 tools for three years; the owner's playtest town was heading there). Recommended: the occupation review may start early when the town has no toolmaking and is out of tools.
5. **The "it knows the work" pull** (up to +2) in a family's first choice when the town lacks a whole trade.
6. **The Speaker:**
   - should families sometimes oppose an appointment at once (today opposition grows only from its acts)?
   - prompt the Elder to reappoint after a vacancy?
   - the office brings favouritism, so any Speaker leaves trust below no Speaker.
7. **Earlier open decisions still stand:** occupation reconsideration's rate and the retired swap's cost; the guiding-wisdom list.

**Where things are.**
- **Branches:** the feature branches (`feature/step3-integration`, `feature/guiding-wisdom`, `feature/occupation-reconsideration`, `feature/household-self-sufficiency`, `feature/emergent-recognition`, `investigate/workplace-choices`) are merged and pushed, and kept for reference.
- **Comparison harnesses:**
  - `tests/sim/wisdom_check.gd`, with `--no-reconsider`, `--no-self-sufficiency`, `--no-proficiency-effects`, `--no-secondary` and `--disrupt=`;
  - `tests/sim/speaker_check.gd`, with a `--branch=` per process;
  - `tests/sim/workplace_choice_check.gd`, which traces every work decision.

  Commands are in `docs/TESTING.md`. A 12-town, 6-year comparison takes 20–60 minutes per process. Run them in parallel, one condition, strategy or branch each, from a separate `git worktree` so editing doesn't change runs in flight.
- **The owner's playtest town** (autosave, day 82, `%APPDATA%/Godot/app_userdata/New Game Project/saves/autosave.save`): no forge-called family, tools at 8, and a loom family wishing for a fold.

## Earlier History

**Community priorities and home sites (owner, 2026-10-31)** are merged into `develop` and `main` (the simulation; their interface is Step 3 above).

**Town interface redesign (owner brief, 2026-10-30): `docs/TOWN_UI.md`, on `feature/town-ui-redesign` from `develop`, not merged by itself; included in the Step 3 branch.** The sidebar is now four scrolling pages (Overview, Families, Planning, Community) built by `scripts/ui/town_sidebar/`; the top bar groups place, time, and status (food in days added); the house card on the map is short and the family's reasons open in the sidebar. No simulation code changed. L now opens the Families page instead of the roster overlay; Tab changes pages. Open for the owner: the judgment calls and missing simulation data listed in that doc.

**Locked into `main` (owner, 2026-10-28):** everything through milestone 6, the town status bar, and the playtest fixes (walker bends, paths meeting roads).

**Household social model (owner directive and review, 2026-10-28): `docs/HOUSEHOLD_SOCIAL_MODEL.md`.** Design direction approved after review, with four decisions now built: industrious/leisurely no longer change output anywhere (diligence chooses long days instead); kin help is a strong but voluntary pull; honours come in four kinds judged by each household's convictions; the community decides through informal gatherings of households, with respected voices emerging from standing. Trust has positive sources; four contested-land scenarios are verified by tests; value change was checked over six years. Merged with the influence prototype into `develop` and `main` on the owner's word (2026-10-29). **Since 2026-10-30 both are the default way to play** (owner): new towns start with families leading; Esc > **Town rules** (or I) switches a town to the classic rules, and `-- --classic` founds towns that way. Next: the owner's playtest and the five open questions in that doc (pace of value change, the construction cost of voluntary help and whether commissioning comes next, steady-but-ruinous trust, a button for requesting land, personality change).

**New direction, in prototype (owner, 2026-10-28): `docs/FAMILY_INFLUENCE_PROTOTYPE.md`.** The owner approved the hybrid model for prototyping: the player directly controls what the community holds in common; families decide what is their own. A small, reversible proof of concept (merged with the social model, 2026-10-29; the default since 2026-10-30): families take up and improve their own work for reasons they give, the player influences them by encouragement and a stores rule with protected reserves, and improved workplaces short of tools work by hand. The owner adopted it as the way the game is played (2026-10-30). Still open: resolve the conflicts that doc lists with `GAME_VISION.md` and `FIRST_STAGE_LOOP.md`, which have not been rewritten yet. The earlier tier proposal (families decide upgrades "not by the stores") is superseded there: desire ignores the stores; ability follows the community's rule.

**Current objective: `docs/FIRST_STAGE_LOOP.md`**, approved by the owner on 2026-10-27 with amendments: six milestones from the balance foundation to village completion, worked without per-feature approval within that vision; milestone summaries, measurements, and screenshots after each; the owner playtests only after milestone 6, and work continues straight through. Done: milestone 1 (balance foundation: per-building upkeep grace, the farming year, founding stores, the planning and site variety checks) milestone 2 (geography: fisher's hut, hunter's lodge, high water, wolves, from the land in reach; `TownLand`), and milestone 3 (family ambitions: a proper home, a fenced field, work for the family's calling; contentment; families fence their own fields and trade work toward their callings; `FamilyAmbitions`), and milestone 4 (the first neighbour: traders by road or river in summer and autumn, barter priced in grain, a road out for isolated towns; `TownTrade`), and milestone 5 (village defense: bandits on the roads to tempting towns, seen before they come; a watch post and a militia of families; `TownDefense`). Measurements and judgment calls in that doc's Milestone Log. milestone 6 (village completion: stage and chronicle, `SettlementStage`; the clothing need rescaled; herder's fold and wool). **All six milestones are done; next is the owner's playtest** (Playtest Brief and open decisions in that doc: pacing, sidebar space, the worth of contentment, clothing scale). Homes now stand on a single tile (owner, 2026-10-27).

New focus: the gameplay loop inside towns. Sixth step (`feature/yard-fences-and-errands`, 2026-10-27): fences for any building with an open yard, and families' errands (store, water, firewood, kin) wearing paths. Next: homes 1x1 (owner, 2026-10-27), then the first-stage loop the owner approved in outline: site-driven opportunities and hazards, a seasonal rhythm, family ambitions (M4), defense (M5), the first neighbour (M6), and a chronicle (M8). Owner red lines stand; formulas may be changed to fix balance.

Fifth step, owner answers on woods (`feature/woodcutters-and-seasons`, from `develop`, 2026-10-27): woodcutters of any tier, and with nothing marked they slowly cut the nearest trees; land is tilled into farmland as a second step (F); woods past the map's edge count toward spreading; the year's spread is chosen in spring and grows in one tile at a time through autumn.

Fourth step, owner answers on paths (`feature/route-lines-and-fences`, from `develop`, 2026-10-27): the road tool is back; routes run on the lines between tiles as well as through them; walking through a field tramples its harvest and a field can be fenced; paths in woods wear slowly and stay trails; trails draw thin and paths up to a tile wide (`docs/TOWN_BUILDING_MODEL.md`, Routes, Paths, Fields and fences).

Third step, forest expansion (`feature/forest-expansion`, from `develop`, owner specification 2026-10-27): once a year woods spread onto open land beside them, by influence of woods within 3 steps, capped; it replaces the first growing-back model (`docs/TOWN_BUILDING_MODEL.md`, Woodland).

Second step, terrain and woodland (`feature/woodland-clearing`, from `develop`, owner request 2026-10-27): woods, hills, and rock slow travel and routes skirt them; the player marks woods (C) for woodcutters to clear (`docs/TOWN_BUILDING_MODEL.md`, Terrain and Woodland).

First step, paths (`feature/desire-paths`, from `develop`, owner request 2026-10-27): people move faster on paths and roads, but instead of the player building roads, trails and paths wear where families walk, and routes prefer the quickest ways (`docs/TOWN_BUILDING_MODEL.md`, Paths). The road tool was removed then, and restored in the fourth step.

Before that, owner answers on three open decisions (2026-10-27), on `chore/remove-world-window-and-frozen-founding` from `develop`: the unused world-window code is removed; frozen ground refuses founding; balance waits for the next design pass.

Saved games (`feature/saved-games`, from `develop`, owner request 2026-10-27): a start menu, an in-game menu, named saves, and an autosave each season and on quit (`docs/SAVED_GAMES.md`). Merged into `develop` and, on the owner's approval, into `main` (2026-10-27).

Before that, generated worlds (`feature/procedural-world`, from `develop`): every game now opens on a newly generated, continent-styled planet with a small polar ice cap (owner request, 2026-10-26). Merged into `develop` and, on the owner's approval, into `main` (2026-10-27). Then the main track resumes.

Before that: town building is settled before it is locked in (`docs/TOWN_BUILDING_MODEL.md`): the player plans, families build over time, materials are carried from stores, layout costs or saves travel, and families build their own homes on residential plots. The owner approved it for `main`; the open decisions there remain for tuning, and the main track resumes: the first playable village (`docs/IMPLEMENTATION_ROADMAP.md`).

## Status

- **2026-11-01:** everything is on `develop` and `main`; the full headless suite (41 scripts plus the wrapped expanded-goods test) passes on the merged result.
- **First stage (2026-10-28):** milestones 1-6 of `docs/FIRST_STAGE_LOOP.md`.
- **Working:** saved games and the start/in-game menus (`docs/SAVED_GAMES.md`): a town saved, loaded, and played 120 more days stays identical to the original; generated worlds (`WorldGenerator`; design in `docs/WORLD_MAP.md`): 30 seeds build without warnings, openings on generated planets get off the ground about as often as on the authored one (38/42 and 40/42 on seeds 1 and 2, authored now 41/42 continuous, since frozen regions are no longer picked, and 46/48 original); world atlas (`docs/WORLD_MAP.md`); continuous regional map (`docs/REGIONAL_MAP.md`); town map (`docs/TOWN_MAP.md`); town building: construction sites, builders, carried materials, travel costs, roads, storehouses, residential plots, families building homes (`docs/TOWN_BUILDING_MODEL.md`). All 25 headless test scripts pass (with `world_generator_validation` and `save_game_validation`); import validation is clean; generated planets were reviewed by eye (`world_map_capture` with `seed=`); `town_map_capture` (now with construction scenes) was reviewed by eye.
- **Paths** (`docs/TOWN_BUILDING_MODEL.md`, Paths): all 25 headless test scripts pass; balance is unchanged or better (scattered towns 14/20 to 15/20, travel 13% to 11%); `town_map_capture` was reviewed by eye.
- **Balance:** with construction, the sensible opening stays 20/20 and map luck matches building instantly (46/48, 40/42); an opening that queues every house before the woodcutter falls from 20/20 to 13/20 (queue order). Numbers in the model doc.
- **Branches:** generated worlds, saved games, and the world-window cleanup with frozen-ground founding are on `develop`; the owner approved them and `develop` was merged into `main` on 2026-10-27. Both are pushed.
- **Unchanged:** the original region generator (fingerprints in `tests/region_map_validation.gd`); economy numbers other than the new construction and travel ones.

## Decisions Made (Don't Re-litigate Without The Owner)

- **Woods can be cleared and spread back; paths in use hold the land (owner, 2026-10-27).** Travel is slowed by terrain and routes generally avoid woods and uneven ground. Woods spread by the owner's forest expansion specification onto any open land nothing holds. Numbers (placeholders until calibrated) and judgment calls are open (`docs/TOWN_BUILDING_MODEL.md`, Woodland).
- **Nobody walks through buildings, sites, or the stockpile (owner, 2026-10-27).** Only their own routes go in; unfenced fields stay crossable.
- **Routes run on the lines between tiles; fields can be trampled and fenced; the road tool stays (owner, 2026-10-27).** A road influences where people walk but does not decide it.
- **Paths develop from walking (owner, 2026-10-27).** Routing prefers the quickest ways. Numbers and the judgment calls made implementing it are open (`docs/TOWN_BUILDING_MODEL.md`, Paths).

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

0. **Town building** (details in `docs/TOWN_BUILDING_MODEL.md`, Open Owner Decisions): helpers' spare time cannot be turned off; strict queue order vs builders favoring workplaces; upkeep grace counted from founding rather than per building; first-pass travel numbers; families building only on player-set plots; first-pass path numbers, and whether the road tool should come back later as paving a worn path; terrain and woodland numbers, whether clearings become farmland, and whether a woodcutter needs woods in reach.

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

- **Flaky test (fixed on `feature/autonomous-occupations`, still on `develop`):** `tests/town_sidebar_validation.gd` founds its town at random and checks there is no hunger card after a year, so on `develop` it fails when that town happens to be short of food that day (2 of 4 runs, 2026-11-01). The branch fixes the founding seed, and the gameplay check moves to `tests/founded_town_regression.gd`.
- **Flaky test:** `tests/world_map_flow_validation.gd`, "wheel zoom on the regional map should keep the point under the cursor", failed 2 of 8 runs on the milestone 6 branch (drift 0.51 and 0.55 against a 0.5 limit) and 0 of 5 on `develop`. The zoom animates over the 30 frames the test waits, so a busy machine leaves it unfinished; nothing in milestones 1-6 touches the regional map. Not loosened here: worth a look (wait for the animation to end, not a frame count).

- **Anything kept across days that steers play must be saved,** even if it looks like a cache: errand routes were kept a month and not saved, so loaded towns drifted (fixed 2026-10-31). `tests/save_game_validation.gd` only catches such state once the test town exercises it.
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
- **Town maps change in play.** Felled and spread woods and path levels are written onto `City.local_map`; anything that draws or caches from the town map must watch `TownWoodland.land_version` and `TownLogistics.paths_version` (the town view does). Town maps are saved whole, so this survives saving.
- **A route-grid rebuild costs about 40 ms** (every layout change: buildings, sites, plots, felled or spread woods), a visible hitch at speed. A grown town's day costs about 5 ms. Rebuilding only the changed area is the next step if it bothers play.
- **Routes are cells, not tiles.** `TownLogistics.find_route` takes tiles but returns route cells at half-tile spacing (tile middles, lines, corners); convert with `cell_position` to draw. Path levels and wear are per cell (`cell_levels`, `cell_wear`); `get_tile_path_level` reads a tile's middle. A full route-grid rebuild is about 40 ms, so avoid layout changes in tight loops.
- **Path levels change routes.** A tile's `path_level` changing is a layout change (`TownLogistics.advance_day`); anything that caches routes must key on `layout_version`. Wear is saved with the town (`TownLogistics.wear`), levels on the town map's tiles.
- **Buildings are never placed finished in play.** Everything goes through `TownConstruction`; `City.add_building` is the completion step (tests may still call it directly). City's helpers (`logistics`, `construction`) hold the city weakly, or towns leak.
- **Git:** this repo's `.git` belongs to another Windows account; run git as `git -c safe.directory=D:/AI/projects/incubating/games/new-game-godot ...`.
- **Writing files from Python on Windows:** open them with `newline=''` (or write LF); text mode turns a whole file to CRLF. Git normalizes it on commit, but string replacements against the file then fail.
- **Long comparison runs:** run them from a `git worktree` checked out at a fixed commit, so edits in the main folder can't change processes still queued. Stop only processes whose command line names that worktree: the owner's editor and game may be open.
- **Visual checks** need a real window (no `--headless`): `tests/visual/*_capture.gd`, commands in `CLAUDE.md`.
