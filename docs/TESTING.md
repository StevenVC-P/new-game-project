# Testing

Every test, balance check, and screenshot script, moved from `CLAUDE.md`. Tests extend `SceneTree` and quit with a non-zero code on failure.

The Godot executable path is in the local, untracked `.godot-exe` file.

```powershell
# Validate (headless import pass; the pre-commit gate)
$env:GODOT_BIN = (Get-Content .godot-exe).Trim(); .\scripts\validate_project.ps1

# Run one test (tests extend SceneTree and quit with a non-zero code on failure)
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/founding_city_validation.gd

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

# Home sites (docs/HOME_SITES.md): families choosing their own sites on land set aside, preferred land, no land, no
# overlap, explanations, starting land, land reserved from work; then starting land, plots, and equal-capacity compact, dispersed, poor, far and
# preferred-far land on the same towns (write to a file, filter for [HOME]; "-- --years=N --sites=N --layouts=a,b")
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/home_site_validation.gd
& (Get-Content .godot-exe).Trim() --headless --path . --script res://tests/sim/home_site_check.gd > homes.log

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
