extends SceneTree

# Saved games (scripts/persistence/): a town saved and loaded comes back exactly, and keeps
# playing exactly as the original does; games saved before founding and on the atlas come back
# where they were; a save whose world this build cannot rebuild is refused; the save store lists,
# overwrites, and deletes; and the app's menus start, save, leave, and load a game.

const MainScript = preload("res://scripts/main.gd")
const AppScript = preload("res://scripts/app.gd")
const TEST_DIRECTORY: String = "user://save_game_validation"
const DAYS_BEFORE_SAVE: int = 75
# Long enough for construction, a season change, births, and monthly family turns.
const DAYS_AFTER_LOAD: int = 120

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	# Headless runs report a 64x64 window; give the panels their normal layout.
	root.size = Vector2i(1600, 900)
	clear_directory(TEST_DIRECTORY)
	await test_town_round_trip_plays_on_identically()
	await test_exploring_a_generated_world_round_trips()
	await test_atlas_save_round_trips()
	await test_unrebuildable_world_is_refused()
	test_save_store()
	await test_app_menus()
	clear_directory(TEST_DIRECTORY)

	if failure_count > 0:
		push_error("Save game validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Save game validation passed.")
	quit()

func test_town_round_trip_plays_on_identically() -> void:
	var original: Node2D = await make_main({"use_authored_world": true})
	await found_town(original, original.world_map_data.find_region_by_name("Meander Plains"))
	plan_buildings(original)
	for _day in range(DAYS_BEFORE_SAVE):
		original.run_simulation_day()
	var town_index: int = original.get_player_city_index()
	var town: City = original.cities[town_index]
	_check(not town.construction.projects.is_empty() or town.buildings.size() > 0, "the town should be building before the save")
	_check(not town.woodland.marked.is_empty() or not town.woodland.regrowth.is_empty(), "woods should be marked or felled before the save")

	var store: SaveStore = SaveStore.new(TEST_DIRECTORY)
	_check(store.write("Round trip", GameState.describe(original, "Round trip"), GameState.capture(original)) == OK, "the game should save")
	var state: Dictionary = store.read_state(store.slot_path("Round trip"))
	var loaded: Node2D = await make_main({"use_authored_world": true, "world_seed": int(state["world_seed"]), "pending_save_state": state})

	_check(loaded.current_view == MainScript.VIEW_CITY, "a game saved in the town view should load into it")
	_check(loaded.world_calendar.get_formatted_date() == original.world_calendar.get_formatted_date(), "the date should come back")
	_check(loaded.neighbourhood_origin == original.neighbourhood_origin, "the neighbourhood should come back where it was")
	_check(loaded.cities.size() == original.cities.size(), "every town in the neighbourhood should come back")
	_check(loaded.roads == original.roads, "the town's road spur should come back")
	_check(tiles_match(loaded.tiles, original.tiles), "the regional land, spur road included, should come back")
	_check(GameState.capture_city(loaded.cities[town_index]) == GameState.capture_city(town), "the town should come back exactly: " + first_difference(GameState.capture_city(town), GameState.capture_city(loaded.cities[town_index])))

	# Anything a save missed would make the two games drift apart from here.
	for _day in range(DAYS_AFTER_LOAD):
		original.run_simulation_day()
		loaded.run_simulation_day()
	var original_town: Dictionary = GameState.capture_city(original.cities[town_index])
	var loaded_town: Dictionary = GameState.capture_city(loaded.cities[town_index])
	_check(loaded_town == original_town, "a loaded town should play on exactly as the original: " + first_difference(original_town, loaded_town))
	_check((loaded_town["households"] as Array).size() > 0 and (loaded_town["buildings"] as Array).size() > 0, "the compared town should have families and buildings")
	await free_main(original)
	await free_main(loaded)

func test_exploring_a_generated_world_round_trips() -> void:
	var original: Node2D = await make_main({"world_seed": 4})
	var frontier: WorldMapData.Region = null
	for region: WorldMapData.Region in original.world_map_data.regions:
		if region.owner_kingdom_id == -1 and not original.world_map_data.get_settlements_in_region(region.id).is_empty():
			frontier = region
			break
	original.world_map_view.request_region_entry(frontier.id)
	original.wait_for_neighbourhood_job()
	await settle()
	for _day in range(10):
		original.run_simulation_day()
	var state: Dictionary = GameState.capture(original)
	var loaded: Node2D = await make_main({"world_seed": int(state["world_seed"]), "pending_save_state": state})
	loaded.wait_for_neighbourhood_job()
	_check(loaded.world_map_data.world_seed == 4, "a generated world should be rebuilt from its seed")
	_check(loaded.current_view == MainScript.VIEW_REGION, "a game saved while exploring should load on the regional map")
	_check(loaded.neighbourhood_origin == original.neighbourhood_origin, "the explored neighbourhood should come back")
	_check(loaded.world_calendar.total_days_elapsed == original.world_calendar.total_days_elapsed, "the days played should come back")
	_check(not loaded.region_founding_sites.is_empty(), "the frontier should offer founding sites again")
	await free_main(original)
	await free_main(loaded)

func test_atlas_save_round_trips() -> void:
	var original: Node2D = await make_main({"use_authored_world": true})
	var state: Dictionary = GameState.capture(original)
	_check(not state.has("cities"), "an atlas save holds no towns")
	var loaded: Node2D = await make_main({"use_authored_world": true, "pending_save_state": state})
	_check(loaded.current_view == MainScript.VIEW_WORLD and not loaded.has_shown_region_map, "an atlas save should load on the atlas")
	await free_main(original)
	await free_main(loaded)

func test_unrebuildable_world_is_refused() -> void:
	var original: Node2D = await make_main({"use_authored_world": true})
	var state: Dictionary = GameState.capture(original)
	await free_main(original)
	state["world_fingerprint"] = int(state["world_fingerprint"]) + 1
	var messages: Array[String] = []
	var loaded: Node2D = MainScript.new()
	loaded.use_authored_world = true
	loaded.pending_save_state = state
	loaded.load_failed.connect(func(message: String) -> void: messages.append(message))
	root.add_child(loaded)
	await settle()
	_check(messages.size() == 1, "a save whose world cannot be rebuilt should be refused")
	await free_main(loaded)

func test_save_store() -> void:
	var store: SaveStore = SaveStore.new(TEST_DIRECTORY.path_join("store"))
	_check(store.list().is_empty() and store.latest().is_empty(), "a new store should be empty")
	_check(store.slot_path("My Town: Year 3!").get_file() == "my-town--year-3.save", "slot names should become safe file names, got " + store.slot_path("My Town: Year 3!").get_file())
	_check(store.slot_path("  ").get_file() == "save.save", "an empty name should still give a file")
	store.write("Older", {"format": GameState.FORMAT, "name": "Older", "saved_unix": 100}, {"value": 1})
	store.write("Newer", {"format": GameState.FORMAT, "name": "Newer", "saved_unix": 200}, {"value": 2})
	store.write("From the future", {"format": GameState.FORMAT + 1, "name": "From the future", "saved_unix": 300}, {"value": 3})
	var names: Array = store.list().map(func(header: Dictionary) -> String: return header["name"])
	_check(names == ["Newer", "Older"], "saves should list newest first, without ones this build cannot read: " + str(names))
	store.write("Older", {"format": GameState.FORMAT, "name": "Older", "saved_unix": 300}, {"value": 4})
	_check(store.latest()["name"] == "Older" and store.read_state(store.slot_path("Older"))["value"] == 4, "saving under a name again should overwrite that save")
	_check(not FileAccess.file_exists(store.slot_path("Older") + ".tmp"), "no temporary file should be left behind")
	store.delete(store.slot_path("Older"))
	_check(store.latest()["name"] == "Newer", "a deleted save should be gone from the list")

func test_app_menus() -> void:
	var app: Node = AppScript.new()
	app.store = SaveStore.new(TEST_DIRECTORY.path_join("app"))
	root.add_child(app)
	await settle()
	_check(app.menu.visible and app.game == null, "the app should open on the start menu")
	await app.start_game({})
	await settle()
	_check(app.game != null and not app.menu.visible, "New world should start a game")
	var game_seed: int = app.game.world_map_data.world_seed
	app.open_menu()
	_check(app.menu.visible and app.game.process_mode == Node.PROCESS_MODE_DISABLED, "the menu should pause the game under it")
	app.save_game("Smoke test")
	var saved: Dictionary = app.store.latest()
	_check(saved.get("name", "") == "Smoke test" and int(saved["world_seed"]) == game_seed, "Save game should write a save of this world")
	app.resume()
	_check(app.game.process_mode == Node.PROCESS_MODE_INHERIT and not app.menu.visible, "Resume should hand the game back")
	app.open_menu()
	app.quit_to_start()
	await settle()
	_check(app.game == null and app.menu.visible, "Quit to start menu should end the game")
	_check(app.store.list().size() == 1, "a game still on the atlas should not be autosaved")
	await app.load_game(saved["path"])
	await settle()
	_check(app.game != null and app.game.world_map_data.world_seed == game_seed, "Load game should rebuild the saved world")
	app.close_game()
	app.queue_free()
	await settle()

# --- Helpers -------------------------------------------------------------------------------------

func make_main(settings: Dictionary) -> Node2D:
	var main: Node2D = MainScript.new()
	for key: String in settings:
		main.set(key, settings[key])
	root.add_child(main)
	await settle()
	return main

func free_main(main: Node2D) -> void:
	main.queue_free()
	await settle()

func found_town(main: Node2D, region: WorldMapData.Region) -> void:
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()
	await settle()
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	_check(main.found_player_city_at_pending_site(), "founding should open the town")
	await settle()

# Plans what a player starts with: food, timber, a home, and a plot for a family's own home.
func plan_buildings(main: Node2D) -> void:
	for building_type: String in [MainScript.BUILDING_FARM, MainScript.BUILDING_WOODCUTTER, MainScript.BUILDING_HOUSE, TownConstruction.PLOT]:
		main.select_building_type(building_type)
		main.city_hovered_tile = valid_spot(main, building_type)
		main.try_place_selected_building()
	# Woods marked for clearing, so the woodcutter fells some before the save and some after.
	var woods: Vector2i = nearest_wooded(main)
	main.select_building_type(TownWoodland.CLEAR)
	for corner: Vector2i in [woods, woods + Vector2i(3, 3)]:
		main.city_hovered_tile = corner
		main.try_place_selected_building()

func nearest_wooded(main: Node2D) -> Vector2i:
	var town: City = main.cities[main.selected_city_index]
	var center: Vector2i = Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) / 2
	for radius in range(0, 32):
		for y in range(maxi(0, center.y - radius), mini(MainScript.CITY_MAP_HEIGHT, center.y + radius + 1)):
			for x in range(maxi(0, center.x - radius), mini(MainScript.CITY_MAP_WIDTH, center.x + radius + 1)):
				if town.local_map[y][x]["has_trees"] == true:
					return Vector2i(x, y)
	return center

func valid_spot(main: Node2D, building_type: String) -> Vector2i:
	var center: Vector2i = Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) / 2
	for radius in range(0, 20):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if main.is_valid_building_placement(main.selected_city_index, building_type, Vector2i(x, y)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func tiles_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for y in range(a.size()):
		if a[y] != b[y]:
			return false
	return true

# Names where two captured towns first differ, to make a failure readable.
func first_difference(a: Dictionary, b: Dictionary, path: String = "") -> String:
	for key: Variant in a:
		if not b.has(key):
			return path + str(key) + " missing"
		if a[key] == b[key]:
			continue
		if a[key] is Dictionary and b[key] is Dictionary:
			return first_difference(a[key], b[key], path + str(key) + ".")
		if a[key] is Array and b[key] is Array and (a[key] as Array).size() == (b[key] as Array).size():
			for i in range((a[key] as Array).size()):
				if a[key][i] != b[key][i]:
					if a[key][i] is Dictionary and b[key][i] is Dictionary:
						return first_difference(a[key][i], b[key][i], path + str(key) + "[%d]." % i)
					return path + str(key) + "[%d]: %s vs %s" % [i, str(a[key][i]).left(80), str(b[key][i]).left(80)]
		return path + str(key) + ": " + str(a[key]).left(80) + " vs " + str(b[key]).left(80)
	for key: Variant in b:
		if not a.has(key):
			return path + str(key) + " only in the second: " + str(b[key]).left(80)
	return "(none)"

func clear_directory(path: String) -> void:
	for directory: String in [path.path_join("store"), path.path_join("app"), path]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file_name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))

func settle() -> void:
	for _frame in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
