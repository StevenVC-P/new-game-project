# Testing

Every test, balance check, and screenshot script, moved from `CLAUDE.md`. Tests extend `SceneTree` and quit with a non-zero code on failure.

The Godot executable path is in the local, untracked `.godot-exe` file.

```powershell
# Validate (headless import pass; the pre-commit gate)
$env:GODOT_BIN = (Get-Content .godot-exe).Trim(); .\scripts\validate_project.ps1

# Run one test (tests extend SceneTree and quit with a non-zero code on failure)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/founding_city_validation.gd

# Every rules test in tests/, four at a time; one line each in test-logs/<time>/summary.txt ("-Filter quarry*" for some)
.\scripts\run_tests.ps1

# Economic foundations (docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md): the invariant checker's own test, quarries on stone
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/economy_invariants_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/quarry_deposit_validation.gd
# The ownership ledger (S6): families' shares in the one store, who paid for a building, losses, saves
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_ledger_validation.gd
# The founding compact (S7): sharing at the rate, the chain rule, eating and warming from one's own, giving more
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_compact_validation.gd
# Diagnostic: one divergence town under a compact, a line for each family short a day (filter for [CT])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/compact_trace.gd -- --environment=forested --start=0 --compact=private > trace.log
# Divergence check: the same founder sets on five kinds of land, daily invariants (filter for [DIV]; "-- --survey" lists
# the site pool). Batches and tables: run_divergence.ps1 -Label X [-Extra "--commission=quarry@360"], then
# compare_divergence.ps1 -Base X -New Y. Run batches from a fixed-commit worktree.
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/divergence_check.gd -- --environments=forested --starts=2 --years=1 > div.log
.\scripts\run_divergence.ps1 -Label B0 -ProjectRoot ..\ngg-ef-runs

# Opening check: can 20 different towns get off the ground in two years? (filter for [OPEN])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/opening_check.gd

# Map luck: 48 towns on real generated maps and sites (filter for [MAP]); add "-- --world-seed=N" to play a generated planet
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/map_luck_check.gd

# Terrain costs, woodcutters clearing marked woods, and yearly forest expansion (filter for [WOOD])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_woodland_validation.gd

# Town building: construction, travel, and families building homes on plots, on 20 real town maps
# (write to a file, then filter for [BUILD]; piping Godot's household log stalls it on Windows)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/town_building_check.gd > building.log

# Family influence prototype (docs/FAMILY_INFLUENCE_PROTOTYPE.md): the rules, then direct building against
# families developing their own work on 20 real town maps (write to a file, filter for [INFL]; "-- --years=N")
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/family_initiative_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/influence_check.gd > influence.log

# Household social model (docs/HOUSEHOLD_SOCIAL_MODEL.md): the rules, the directive's ten demonstrations, and the owner
# review's cases (kin, recognition, trust, four land scenarios); then eight player approaches on the same towns (with
# the model off as the yardstick for construction) plus a scale probe (write to a file, filter for [SOC];
# "-- --years=N --sites=N --approaches=none,fair --no-scale")
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/household_social_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/social_check.gd > social.log

# Community priorities (docs/COMMUNITY_PRIORITIES.md): the priority's rules, then 16 strategies using community choices
# only (passive, each priority under both stores rules, informed, uninformed with matched policy changes, poor,
# destructive) on ordinary towns, the same towns with the first winter's stores lost, and naturally difficult sites
# (write to a file, filter for [PRI]; about an hour a condition: run one per process with "-- --conditions=ordinary"
# etc.; also "--years=N --sites=N --strategies=a,b --layout=compact" for the residential land towns start with)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/community_priority_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/priority_check.gd > priority.log

# Guiding wisdom (docs/GUIDING_WISDOM.md): leadership and fixed choices, no change without a wisdom, one expectation each,
# conflicting wisdoms, conduct becoming experience, counter-qualities, a level a year, framed lessons, the page, saves;
# then no wisdom against the six pairs, two priority stacks, and a pair given a third wisdom by the village's Elder
# (endure+respect>pride, endure+respect>prepare), six years with a year-3 snapshot (one condition and
# strategy per process; "--prepare-difficult" caches the difficult sites first; filter for [WIS])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/guiding_wisdom_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/wisdom_check.gd -- --conditions=ordinary --strategies=none,endure+respect > wis.log

# Families reconsidering their work (docs/OCCUPATION_RECONSIDERATION.md): the rules; then the wisdom check's towns with
# reconsideration on and off ("-- --no-reconsider"), and with the monthly limit lifted ("-- --change-limit=0").
# Every work decision traced (docs/WORKPLACE_CHOICE_INVESTIGATION.md; filter for [WPC]):
# res://tests/sim/workplace_choice_check.gd -- --conditions=ordinary > wpc.log
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/occupation_review_validation.gd

# Emergent recognition and the Speaker of the Gathering (docs/EMERGENT_RECOGNITION_AND_LEADERSHIP.md): the rules; then the
# same towns under three priority/wisdom strategies, one branch per process: existing, emergent, speaker0/1/2 (the first,
# second or third most influential household appointed at Village), replace01/12/20 (appointed, then replaced 540 days
# later); filter for [SPK]
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_regard_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/speaker_check.gd -- --conditions=ordinary --strategies=food --branch=speaker0 > spk.log
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/wisdom_check.gd -- --conditions=ordinary --strategies=none,food --no-reconsider > occ_off.log

# Household self-sufficiency and proficiency (docs/HOUSEHOLD_SELF_SUFFICIENCY.md): the rules; then the wisdom check's towns with the
# system on and off ("-- --no-self-sufficiency"), with one part at a time ("--no-proficiency-effects", "--no-secondary"), and
# with a disruption in the second autumn ("--disrupt=specialist" or "--disrupt=stores")
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/household_economy_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/wisdom_check.gd -- --conditions=difficult --strategies=none --no-self-sufficiency > hse_off.log

# Autonomous occupations and survival-aware work decisions (docs/AUTONOMOUS_OCCUPATIONS.md): the rules; then the wisdom
# check's towns under four modes, one per process: existing (today's game), shortage (narrow recognition), occupations
# (fishing, hunting, herding, with survival awareness), both; diagnostics survival_only and occupations_blind
# (filter for [OCC]; "-- --years=N --sites=N --from=K --priority=investment"); and a copy of a saved game's town replayed under a
# mode, every work decision traced with the priority's part ("--no-priority" clears it; filter for [REPLAY])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/autonomous_occupations_validation.gd
# Player agency (docs/PLAYER_AGENCY_AUDIT.md): the towns under kinds of player acting only on what the game shows, through its
# controls (none, informed, informed_priority/_commission/_woods, late, inappropriate); "--seed=N --trace" prints one town's
# timeline (warnings, the player's acts, every family's choice and review with reasons; filter for [TRACE], else [INT])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/intervention_check.gd -- --conditions=stressed --policies=none,informed > int.log
# Gameplay regression: a viable founding (seed 20261102) must come through its year, and the sidebar test's founding
# (20261101) must fail for hunger, families leaving only after the stores ran out; both stay consistent day by day, and the
# failing town saved mid-decline loads and plays on identically (own save folder). "-- --probe=1,2,3" prints seeds' years.
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/founded_town_regression.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/occupation_check.gd -- --conditions=ordinary --modes=both > occ.log
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/autosave_replay.gd -- --save=C:/path/to/copy.save --mode=all --days=360 > replay.log
# (replay options: --no-priority clears the town's priority; --appeal=tools|food|wood makes a focused appeal at the start)
# Intervention check, priority 5 diagnostics (comparison only): --leave-out=hunter,herder,fisher [--leave-out-until=DAY];
# --veto=HOUSEHOLD:OCCUPATION:UNTIL[;...] (one family may not choose one trade until a day); --meta=a,b (comparison metas,
# e.g. known_work_yields_to_survival, familiar_comfort_yields); --trace also prints each first choice ranked ("CHOICE").
# Policies added: informed_appeal_once, keep_hunting, keep_lodges, informed_appeal, informed_land, priority_switcher, overprotect.
# Save-using tests (save_game_validation, community_play_validation) write to a folder of their own process and found a fixed
# town, so they may run side by side and pass or fail the same way every run.
# Fifth round (docs/AUTONOMOUS_OCCUPATIONS.md): policy keep_on_warning answers the early hunting-grounds card with its keep
# button; keep_hunting now keeps only once a lodge has lost a third of its best yield (the late rule). Metas:
# comfort_calling_kept (the old calling rule; the fading adjustment is the default since the sixth round), woods_not_shared,
# water_not_shared, pasture_not_shared (the old double-counted land), late_hunting_card. Previous defaults (before the sixth
# round): --meta=comfort_calling_kept,water_not_shared,pasture_not_shared. Results also carry "made" (fish, game, wool).
# --provisions=food:N,wood:N,tools:N sets the starting stores (founding-provisions diagnostic); --trace-tools (with --seed=N)
# prints the tool and wood stores, reserve, upkeep and every family's word on improving its work ([TOOLS]).
# Results now carry people at years 1 and 3, first-year shortage days, work taken up, founding herders, the candidate's
# changed decisions (fade_changed, fade_cases), woodcutter-days lost to kept woods and the early card's first showing.

# Hunting grounds (fifth round): woods shared among lodges (seven cases), the early warning's timing, no false warnings,
# keeping binding and its cost to woodcutters, reading changes nothing, clearing obstacles, and the card answered by real
# clicks at 1920x1080 and 1366x768; then its screenshots (needs a window)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/hunting_grounds_validation.gd
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/hunting_warning_capture.gd -- <output_dir>

# Shared land (sixth round): fishing water and pasture divided among workplaces of their kind like woods, the shares of
# overlapping workplaces adding up to the land once, families' expectations, kinds not competing, only workplaces in use
# sharing (empty, abandoned and idle ones take nothing; neutral-worked ones count), the old counting by meta
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/shared_land_validation.gd

# Home sites (docs/HOME_SITES.md): families choosing their own sites on land set aside, preferred land, no land, no
# overlap, explanations, starting land, land reserved from work, shared works among homes, preferred land between equal sites, explanations
# that no longer hold; then starting land, plots, and equal-capacity compact, dispersed, poor, far and
# preferred-far land on the same towns (write to a file, filter for [HOME]; "-- --years=N --sites=N --layouts=a,b")
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/home_site_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/home_site_check.gd > homes.log
# Preferred land between two equal places (two blocks on opposite sides, plain, then one preferred):
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/home_site_check.gd -- --layouts=twin,twin_preferred > twin.log

# Multi-year settlement run, yearly report (filter output for [SIM])
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/settlement_growth_run.gd

# Household simulation benchmark (filter output for [BENCH]; takes several minutes)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd

# Saved games: a town saved, loaded, and played on stays identical to the original; menus; the save store
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/save_game_validation.gd

# Start and in-game menu screenshots (needs a window; uses its own save folder)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/menu_capture.gd -- <output_dir>

# World map: data checks, and the hand-off into the regional/founding flow
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_map_flow_validation.gd

# Generated planets: design rules on seeds 1-6 (filter for [GEN]; pass other seeds after "--" for a sweep)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/world_generator_validation.gd

# World map screenshots for visual review (needs a window, so no --headless); add "seed=N" for a generated planet
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/world_map_capture.gd -- <output_dir>

# Continuous regional map: seamless chunks (also across the date line), determinism, matches the world, view coordinates ([PERF] lines)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/regional_terrain_validation.gd

# Regional map: unchanged original maps (fingerprints), bounded-mode decoration, clicking the landscape founds a town
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/region_map_validation.gd

# Regional map screenshots: showcases near and far, border, date line, [PERF] render and panning times; and the real
# atlas zoom-in / found / cross a border / zoom-out flow (both need a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_map_capture.gd -- <output_dir>
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_flow_capture.gd -- <output_dir>

# Town map: generator (determinism, follows the region, floors) and the view in the real flow (fit, coordinates, click/drag/wheel)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_map_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_map_view_validation.gd

# Town sidebar (docs/TOWN_UI.md): layout, every page from a new and a grown town without changing it, attention from state,
# tabs, wheel, buttons and family focus by real clicks, the footer, every shortcut the Planning page lists, starting land at
# founding, choosing and withdrawing the community priority, and marking and clearing residential land
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/town_sidebar_validation.gd

# Community play in the real game: founding with starting land and no tool in hand, marking preferred land by clicks on
# the map, families building their own homes on it, choosing a priority, a family's reasons, answering a warning, save/load
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/community_play_validation.gd

# Town interface screenshots at 1920x1080 and 1366x768: each page, a family selected, a tool placed, the community priority,
# residential land, alerts, families finding nowhere to build (needs a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/town_ui_capture.gd -- <output_dir>

# What town maps hold over 160 real sites, and generation time (filter for [TOWN]); the survey's thresholds come from it
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/town_map_probe.gd

# Town map screenshots: showcase sites, a grown town, every building type, the real game ([PERF] lines; needs a window)
& (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/town_map_capture.gd -- <output_dir>
```

`scenes/region_map_demo.tscn` opens the continuous regional map on the showcase regions (keys 1-6, G for a grown town).

`tests/expanded_goods_production_validation.gd` extends `RefCounted`, so it cannot be run with `--script` directly; load it from a small `SceneTree` wrapper and call `run_all()`.
