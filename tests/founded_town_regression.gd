extends SceneTree

# Gameplay regression (docs/AUTONOMOUS_OCCUPATIONS.md, sixth round): real foundings with families
# leading, played for a year by the stand-in player. A founding may succeed or fail; this test pins
# one of each, so an unintended change to either shows, without asking every founding to survive.
#
# - A viable founding (VIABLE_SEED): its families take up work for their own reasons, food work
#   among them; families build; it keeps its founding families, is fed at the end and has a family
#   in a proper home.
# - A failed founding (the sidebar test's seed, FAILING_SEED): its families' close choices leave it
#   growing less food than it eats; the stores run out, hungry months build hardship, and families
#   leave, never before the town has gone hungry. Since 2026-11-02 (woods shared among lodges) a
#   forest family's near tie between hunting and woodcutting goes to wood; until then this town came
#   through its year. Failing for those reasons is the expected outcome here.
# - Both: the state stays consistent (no negative stores, no work held by a family that is gone, no
#   family at two workplaces, no empty family), and the failing town, saved in the middle of its decline and
#   loaded, plays on exactly as the original (saves to a folder of this process's own, removed
#   afterwards).
#
# "-- --probe=1,2,3" founds and plays each seed instead and prints its year, to choose seeds.

const MainScript = preload("res://scripts/main.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const SidebarTest = preload("res://tests/town_sidebar_validation.gd")

# Chosen by --probe among the save and hunting tests' founding seeds as one that comes through its
# year under the rules of 2026-11-02 (docs/AUTONOMOUS_OCCUPATIONS.md, sixth round).
const VIABLE_SEED: int = 20261102
const FAILING_SEED: int = SidebarTest.FOUNDING_SEED
const DAYS: int = 360
# Between its families leaving (days 119, 149 and 179 under the rules of 2026-11-02), mid-decline.
const SAVE_DAY: int = 150
const DAYS_AFTER_LOAD: int = 60
var TEST_DIRECTORY: String = "user://founded_town_regression_%d" % OS.get_process_id()

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	root.size = Vector2i(1600, 900)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe="):
			for seed_text: String in argument.trim_prefix("--probe=").split(","):
				var probe: Dictionary = await play_founding(int(seed_text), DAYS)
				print("[PROBE] seed %s | %s" % [seed_text, describe(probe)])
				await free_main(probe["main"])
			quit()
			return
	clear_directory(TEST_DIRECTORY)
	await test_viable_founding()
	await test_failed_founding()
	clear_directory(TEST_DIRECTORY)
	if failure_count > 0:
		push_error("Founded town regression failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Founded town regression passed.")
	quit()

# --- The foundings ---------------------------------------------------------------------------------

# Founds the town nearest the middle of Meander Plains with the game's random numbers from `seed`,
# and plays it `days` days as the stand-in player's play() does with no scenario, a day at a time so
# each day can be recorded. Returns {"main", "city", "founders", "callings", "short_days",
# "first_short_day", "departures": [{day, household, short_days_before}], "consistent": [problems]}.
func play_founding(seed: int, days: int) -> Dictionary:
	var main: Node2D = MainScript.new()
	main.use_authored_world = true
	root.add_child(main)
	main.rng.seed = seed
	await settle()
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()
	await settle()
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	_check(main.found_player_city_at_pending_site(), "founding should open the town (seed %d)" % seed)
	main.simulation_clock.is_paused = true
	var city: City = main.cities[main.selected_city_index]
	var record: Dictionary = {"main": main, "city": city, "founders": city.households.map(func(h: Household) -> int: return h.id), "callings": city.households.map(func(h: Household) -> String: return "/".join(CultureEffects.get_callings(h.values))), "short_days": 0, "first_short_day": -1, "departures": [], "consistent": []}
	var present: Array = (record["founders"] as Array).duplicate()
	var player = StandInPlayerScript.new()
	var calendar: Calendar = Calendar.new()
	for day in range(days):
		var month_before: int = calendar.current_month
		var season_before: String = calendar.get_current_season()
		calendar.advance_day()
		city.tick()
		if calendar.current_month != month_before:
			city.advance_household_lifecycle_month(0)
		if calendar.get_current_season() != season_before:
			city.advance_household_birth_rolls_season(calendar, 0)
		if day % StandInPlayerScript.POLICY_INTERVAL_DAYS == 0:
			player.upgrade_one(city, {}, day)
			var wanted: String = player.choose_build(city, {}, day)
			if wanted != "" and not player.try_build(city, wanted, {}, day):
				player.try_build(city, player.tier0_fallback(wanted), {}, day)
		if city.resources["food_shortage"] == true:
			record["short_days"] = int(record["short_days"]) + 1
			if int(record["first_short_day"]) < 0:
				record["first_short_day"] = day
		var ids: Array = city.households.map(func(h: Household) -> int: return h.id)
		for id: int in present:
			if not ids.has(id):
				(record["departures"] as Array).append({"day": day, "household": id, "short_days_before": int(record["short_days"])})
		present = ids
		(record["consistent"] as Array).append_array(check_consistent(city, day))
	return record

# What would make a town's state corrupt, today: [problems].
func check_consistent(city: City, day: int) -> Array:
	var problems: Array = []
	for good: String in ["food", "wood", "tools", "wool"]:
		if city.resources.has(good) and float(city.resources[good]) < 0.0:
			problems.append("day %d: %s below zero (%s)" % [day, good, str(city.resources[good])])
	var ids: Array = city.households.map(func(h: Household) -> int: return h.id)
	var working: Dictionary = {}
	for building: Building in city.buildings:
		if building.assigned_household_id < 0:
			continue
		if not ids.has(building.assigned_household_id):
			problems.append("day %d: a %s held by family %d, which is gone" % [day, building.type, building.assigned_household_id])
		if building.is_production_building():
			if working.has(building.assigned_household_id):
				problems.append("day %d: family %d works two workplaces" % [day, building.assigned_household_id])
			working[building.assigned_household_id] = true
	for household: Household in city.households:
		if household.total_population <= 0:
			problems.append("day %d: family %d has no one left but is still here" % [day, household.id])
	return problems

func describe(record: Dictionary) -> String:
	var city: City = record["city"]
	var work: Dictionary = {}
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_household_id >= 0:
			work[building.type] = int(work.get(building.type, 0)) + 1
	return "founders %s | families %d, people %d | food %d (shortage %s), short %d days from day %d | tools %d | departures %s | work %s | inconsistencies %d" % [str(record["callings"]), city.households.size(), city.get_total_population(), int(city.resources["food"]), str(city.resources["food_shortage"]), int(record["short_days"]), int(record["first_short_day"]), int(city.resources["tools"]), str(record["departures"]), str(work), (record["consistent"] as Array).size()]

# --- Success -------------------------------------------------------------------------------------

func test_viable_founding() -> void:
	var record: Dictionary = await play_founding(VIABLE_SEED, DAYS)
	var city: City = record["city"]
	print("Viable founding after a year: " + describe(record))
	_check((record["consistent"] as Array).is_empty(), "the viable town's state stays consistent: %s" % str((record["consistent"] as Array).slice(0, 3)))
	var founders: Array = record["founders"]
	var at_work: Array = founders.filter(func(id: int) -> bool: return city.buildings.any(func(b: Building) -> bool: return b.is_production_building() and b.assigned_household_id == id))
	_check(at_work.size() == founders.size(), "every founding family is at work (%d of %d)" % [at_work.size(), founders.size()])
	_check(city.influence.workplaces_opened >= founders.size(), "families opened their workplaces themselves (%d)" % city.influence.workplaces_opened)
	var food_work: Array = city.buildings.filter(func(b: Building) -> bool: return b.assigned_household_id >= 0 and FamilyInitiative.get_activity(b.type) == TownInfluence.ACTIVITY_FOOD)
	_check(not food_work.is_empty(), "families work food workplaces (%d)" % food_work.size())
	_check(city.construction.completed_by_households > 0 or city.influence.improvements_started > 0, "families build: homes %d, improvements started %d" % [city.construction.completed_by_households, city.influence.improvements_started])
	_check(city.households.size() >= EconomyBalance.FOUNDING_FAMILIES and (record["departures"] as Array).is_empty(), "it keeps its founding families through its first year (%d families, departures %s)" % [city.households.size(), str(record["departures"])])
	_check(city.resources["food_shortage"] != true, "it is fed at the end of its first year (food %d)" % int(city.resources["food"]))
	var housed: bool = city.households.any(func(h: Household) -> bool: return city.buildings.any(func(b: Building) -> bool: return b.id == h.residence_building_id and b.is_house()))
	_check(housed, "a family lives in a proper home within the year")
	(record["main"] as Node2D).regional_terrain.wait_for_tasks()
	await free_main(record["main"])

# --- Failure -------------------------------------------------------------------------------------

func test_failed_founding() -> void:
	var record: Dictionary = await play_founding(FAILING_SEED, SAVE_DAY)
	var city: City = record["city"]
	var main: Node2D = record["main"]
	_check((record["consistent"] as Array).is_empty(), "the failing town's state stays consistent: %s" % str((record["consistent"] as Array).slice(0, 3)))
	# Saved in the middle of its decline, loaded, and both played on: a save must not change what happens.
	var store: SaveStore = SaveStore.new(TEST_DIRECTORY)
	_check(store.write("Failing founding", GameState.describe(main, "Failing founding"), GameState.capture(main)) == OK, "the failing town saves")
	var state: Dictionary = store.read_state(store.slot_path("Failing founding"))
	var loaded: Node2D = MainScript.new()
	loaded.use_authored_world = true
	loaded.world_seed = int(state["world_seed"])
	loaded.pending_save_state = state
	root.add_child(loaded)
	await settle()
	var town_index: int = main.get_player_city_index()
	_check(GameState.capture_city(loaded.cities[town_index]) == GameState.capture_city(city), "it loads exactly as saved")
	for _day in range(DAYS_AFTER_LOAD):
		main.run_simulation_day()
		loaded.run_simulation_day()
	_check(GameState.capture_city(loaded.cities[town_index]) == GameState.capture_city(main.cities[town_index]), "and plays on exactly as the original for %d days" % DAYS_AFTER_LOAD)
	_check(check_consistent(loaded.cities[town_index], SAVE_DAY + DAYS_AFTER_LOAD).is_empty(), "the loaded town's state is consistent")
	loaded.regional_terrain.wait_for_tasks()
	await free_main(loaded)
	main.regional_terrain.wait_for_tasks()
	await free_main(main)
	# The whole year, from the founding again: why it fails.
	record = await play_founding(FAILING_SEED, DAYS)
	city = record["city"]
	print("Failed founding after a year: " + describe(record))
	_check((record["consistent"] as Array).is_empty(), "its state stays consistent all year: %s" % str((record["consistent"] as Array).slice(0, 3)))
	var departures: Array = record["departures"]
	_check(not departures.is_empty() and city.households.size() < EconomyBalance.FOUNDING_FAMILIES, "it loses founding families in its first year (%d families; departures %s)" % [city.households.size(), str(departures)])
	_check(int(record["short_days"]) >= HouseholdMigration.HARDSHIP_SHORTAGE_DAYS * 2, "the town goes hungry first: %d days short of food" % int(record["short_days"]))
	_check(departures.all(func(d: Dictionary) -> bool: return int(d["short_days_before"]) >= HouseholdMigration.HARDSHIP_SHORTAGE_DAYS * 2), "every family that leaves does so after months of hunger, not before: %s" % str(departures))
	_check(departures.all(func(d: Dictionary) -> bool: return int(d["day"]) > int(record["first_short_day"])), "and none before the stores first ran out (day %d)" % int(record["first_short_day"]))
	_check(city.households.size() > 0 and city.get_total_population() > 0, "the town declines but is not emptied in its first year (%d people)" % city.get_total_population())
	(record["main"] as Node2D).regional_terrain.wait_for_tasks()
	await free_main(record["main"])

func free_main(main: Node2D) -> void:
	main.queue_free()
	await settle()

func clear_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)

func settle() -> void:
	for _i in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
