# Handoff

What is true right now. Durable detail lives in the linked docs, and past milestones are in git history and each design doc's log. Update this when a milestone closes.

*Last updated: 2026-11-08.* Phase 0 (Economic Foundations S1a–S9) and master roadmap Phase 1 with S13 are on `develop`. 60 of 60 tests pass, along with saves and determinism. `main` is unchanged since 2026-11-02 and awaits the owner's review.

## Current Objective

**Master roadmap Phases 1–3 (authorized 2026-11-07; Phase 4 is not).** The order of all work is `docs/MASTER_ROADMAP.md`. Each sprint merges into `develop` at its gate.
- **On `develop`:** Phase 1 (`docs/phase1/`: land from position without floors, the land-use record, Stage C foundations, E13 V0, scale check and benchmark, X1 and X4), and S13 fish and game stocks.
- **Built and held for the owner's review:** S10, S11 (behind a switch), S12, S14 (`docs/phase2/S10_S12_S14_review.md`, `docs/phase2/OPEN_QUESTIONS.md`), on the stacked branches `feature/p2-s10-food` … `feature/p2-s14-livestock` (worktree `../ngg-p1`).
- **Player Agency A and B** (owner, 2026-11-07): on `feature/player-agency` (worktree `../ngg-agency`), not to be merged or pushed without the owner's approval.
- **Playtests deferred, not dropped:** checkpoints 0 and 1 are owed when the owner returns.

- **Economic Foundations:** backlog and sprint cards in `docs/ECONOMIC_FOUNDATIONS_ROADMAP.md`, tests and evidence in `docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md`, sprint reports in `docs/economic_foundations/`.
- **Design baseline for the economy and geography work:** `docs/RESOURCE_AND_PRODUCTION_AUDIT.md` (2026-11-02).

## State of Play

Detail on each system is in its doc: `AUTONOMOUS_OCCUPATIONS.md`, `OCCUPATION_RECONSIDERATION.md`, `HOUSEHOLD_SELF_SUFFICIENCY.md`, `EMERGENT_RECOGNITION_AND_LEADERSHIP.md`, `GUIDING_WISDOM.md`, `COMMUNITY_PRIORITIES.md`, `HOME_SITES.md`, `TOWN_UI.md`, `PLAYER_AGENCY_AUDIT.md`.

- **Families lead by default.** Esc > Town rules (or `-- --classic`) switches a town to the classic rules.
- **Occupations:** families choose every trade with a hand-work stage: farm, woodcutter, toolmaker, fisher, hunter and herder. They choose by scored terms with seeded noise, and survival comes before a calling. Stone and craft workshops are player-built only. Quarries stand on stone deposits, and deposits run out (S1b).
- **Shared land:** woods, fishing water and pasture are divided among the workplaces of their kind in use. The tool trap is fixed. Kept woods are binding.
- **Reproducing the old defaults:** `--meta=comfort_calling_kept,water_not_shared,pasture_not_shared` on `tests/sim/intervention_check.gd`.
- **Accepted:** shared water cuts fishing towns' catch by up to 45%, and fishing balance may be revisited. Foundings are still decided by a few first-week work choices; no further occupation tuning is planned.

## Open Owner Decisions

1. **Proficiency's cost** (`HOUSEHOLD_SELF_SUFFICIENCY.md`, "For the owner"). Novices work at 60%, which costs ordinary towns 10–15 people. Options: keep it, soften it to 75%, give founders basic trades, or first measure which half of the cost does it.
2. **A harder stores disruption** for validation (the first autumn, or food before winter).
3. **The tool gap.** A town with no forge-called family may never take up tool work. Recommended: let the occupation review start early when the town has no toolmaking and is out of tools.
4. **The "it knows the work" pull** (up to +2) in a family's first choice when the town lacks a whole trade.
5. **The Speaker:** immediate opposition to an appointment? A prompt to reappoint after a vacancy? Any Speaker leaves trust below having none.
6. **Still standing:**
   - occupation reconsideration's rate and the retired swap's cost;
   - the guiding-wisdom list;
   - generated worlds (no seed choice or reroll in game; the amount of ice; frontier skews tropical or dry);
   - town building (`TOWN_BUILDING_MODEL.md`, Open Owner Decisions);
   - upkeep plates shown only when they need attention;
   - balance after the town terrain (don't tune before the next design pass).

## Decisions Made (don't re-litigate without the owner)

- Woods can be cleared and spread back, and paths in use hold the land. Nobody walks through buildings, sites or the stockpile. Routes run on tile lines, fields can be trampled and fenced, and the road tool stays. Paths form from walking.
- Town building: the player plans and families build. Everything goes through one construction pipeline, and tier 0 never deadlocks.
- Map scales: the town map is the region ×4, the regional map is the atlas magnified, the whole planet is viewable, and only frontier land can be settled (on unclaimed or contested land, not frozen ground). One player settlement.
- Generated continent-style planets with a new seed each launch; the authored planet is the test world.
- Decoration never shows what the tile data doesn't hold (enforced by tests).
- Saves: named slots plus one autosave each season and on quit.

## Where Things Are

- **Comparison harnesses** (commands in `TESTING.md`):
  - `tests/sim/wisdom_check.gd` (`--no-reconsider`, `--no-self-sufficiency`, `--no-proficiency-effects`, `--no-secondary`, `--disrupt=`);
  - `tests/sim/speaker_check.gd`;
  - `tests/sim/workplace_choice_check.gd`;
  - `tests/sim/intervention_check.gd` (`--leave-out`, `--veto`, `--meta`, `--trace`, `--trace-tools`, `--provisions`).

  A 12-town, 6-year run takes 20–60 minutes per process. Run them in parallel from separate `git worktree`s.
- **Worktrees** beside the main folder (`ngg-occupations`, `ngg-p5-runs`, `ngg-p5-base`, `ngg-occ-runs`…`ngg-occ-runs11`, `ngg-baseline`) are detached and safe to remove.
- **Merged feature branches** are kept for reference.
- **The owner's playtest town** is the autosave at day 82 (`%APPDATA%/Godot/app_userdata/New Game Project/saves/autosave.save`). It has no forge-called family, 8 tools, and a loom family wishing for a fold.
- **Deferred map work:**
  - draw the player's town on the regional map;
  - roads beyond the town's spur, abandoned settlements, mines;
  - trade only with towns in the neighbourhood;
  - town map generation runs on the main thread (about 40 ms);
  - integrated-GPU performance is untested.

## Risks And Gotchas

- **Flaky test:** `tests/world_map_flow_validation.gd`, wheel-zoom drift (fails about 2 runs in 8 on a busy machine). It waits a frame count instead of for the animation to end.
- **State that steers play must be saved,** even if it looks like a cache. New object-valued domain fields, caches and new `main.gd` state need a line in `GameState`. `tests/save_game_validation.gd` only catches what its town exercises.
- **Saves rebuild their planet from its seed.** Changing `WorldGenerator` or `WorldFieldBuilder` output makes existing saves refuse to load (a world fingerprint).
- **Determinism:**
  - generated worlds use only the generator's `rng`, in a fixed order, with ties broken by index;
  - regional tiles are pointwise in global position;
  - town maps never use the game `rng`, and the founded town must equal the surveyed one. Changing that generator changes balance: re-run `map_luck_check` and `town_map_probe`.
- **`RegionalTerrain.wait_for_tasks()`** must be called before quitting a script that streamed chunks, or Godot hangs.
- **Large coordinates** reach 72,000. Keep polygons local and shader noise coordinates small.
- **Visibility:** don't toggle `visible` on map layers. Use `RenderingServer.canvas_item_set_visible`, and re-apply it in `_ready`.
- **`main.gd` input:** a click that switches views calls `set_input_as_handled()`. Map clicks go through the views (`map_clicked`).
- **Headless tests:** the root window is 64×64, so tests that click set `root.size`. Streaming takes seconds; wait on wall-clock time.
- **New `class_name` scripts** need an import pass (`validate_project.ps1`) before tests run.
- **Balance tools print long logs.** Write them to a file; piping stalls Godot on Windows.
- **Town maps change in play.** Watch `TownWoodland.land_version`, `TownLogistics.paths_version` and `layout_version`. A route-grid rebuild costs about 40 ms, so avoid layout changes in loops. Routes are half-tile cells (`cell_position`).
- **Buildings are never placed finished in play.** `City.add_building` is the completion step. City's helpers hold the city weakly.
- **Git:** run it as `git -c safe.directory=D:/AI/projects/incubating/games/new-game-godot …`.
- **Python on Windows:** write files with `newline=''`.
- **Long comparison runs:** run from a fixed-commit worktree, and stop only processes whose command line names that worktree.
- **Visual checks** need a real window: `tests/visual/*_capture.gd`.
