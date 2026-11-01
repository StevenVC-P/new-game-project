extends SceneTree

# Community play in the real game (main.gd, the town map, the sidebar), as a player meets it:
# founding a town where families lead; setting residential land aside by clicks on the map;
# families building their homes on it by themselves; choosing a community priority on the
# Community page; reading a family's reasons on the Families page; answering a warning by changing
# the stores rule; and saving and loading the town with all of it.

const MainScript = preload("res://scripts/main.gd")
const SAVE_DIRECTORY: String = "user://community_play_validation"
# Long enough for the founders' first homes (median day 96 on the balance check's towns).
const DAYS_PLAYED: int = 150

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	# Headless runs report a 64x64 window; give the panels their normal layout.
	root.size = Vector2i(1600, 900)
	clear_directory()
	var main: Node2D = MainScript.new()
	main.use_authored_world = true
	root.add_child(main)
	await _settle()
	var city: City = await found_town(main)
	await test_marking_land_on_the_map(main, city)
	test_families_build_their_homes(main, city)
	await test_choosing_a_priority(main, city)
	await test_reading_a_familys_reasons(main, city)
	await test_answering_a_warning(main, city)
	await test_save_and_load(main, city)

	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await _settle()
	clear_directory()
	if failure_count > 0:
		push_error("Community play validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Community play validation passed.")
	quit()

func found_town(main: Node2D) -> City:
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()
	await _settle()
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	_check(main.found_player_city_at_pending_site(), "founding should open the town")
	await _settle()
	var city: City = main.cities[main.selected_city_index]
	_check(city.influence.enabled and city.influence.priority == CommunityPriority.NONE, "a new town has families leading and no priority")
	_check(not main.is_placing_building, "and the player has no tool in hand: a click on the town plans nothing")
	_check(HomeSites.count_room(city) >= EconomyBalance.FOUNDING_FAMILIES, "and its starting land has room for every founding family (%d spots)" % HomeSites.count_room(city))
	return city

# The Planning page's tool, then two clicks on the map: preferred land, shown on the map.
func test_marking_land_on_the_map(main: Node2D, city: City) -> void:
	var view: TownMapView = main.town_map_view
	main.show_sidebar_tab(TownSidebar.TAB_PLANNING)
	await _settle()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "select_tool" and a.get("tool") == HomeSites.TOOL_PREFERRED), "the Planning page offers preferred residential land")
	_check(main.is_placing_building and main.selected_building_type == HomeSites.TOOL_PREFERRED, "clicking it picks up the tool")
	var corner: Vector2i = open_block(city, 3)
	_check(corner.x >= 0, "the town has open ground for more homes")
	view.reset_camera()
	_click(view.tile_rect_to_screen(corner).get_center())
	await _settle()
	_check(HomeSites.count_land(city, HomeSites.LAND_PREFERRED) == 0, "the first click only marks where the block starts")
	main.update_city_hovered_tile(view.tile_rect_to_screen(corner + Vector2i(2, 2)).get_center())
	main.sync_town_map_view()
	_check(view.block_preview.has_point(corner) and view.block_preview.has_point(corner + Vector2i(2, 2)), "the block to be marked shows while the player picks its corner")
	_click(view.tile_rect_to_screen(corner + Vector2i(2, 2)).get_center())
	await _settle()
	_check(HomeSites.count_land(city, HomeSites.LAND_PREFERRED) == 9, "the second click marks the block preferred (%d tiles)" % HomeSites.count_land(city, HomeSites.LAND_PREFERRED))
	main.is_placing_building = false

# Days pass with the player doing nothing more: families choose sites on the land and build.
func test_families_build_their_homes(main: Node2D, city: City) -> void:
	var buildings_before: int = city.buildings.size()
	for _day in range(DAYS_PLAYED):
		main.run_simulation_day()
	var homes: Array[Building] = []
	for index in range(buildings_before, city.buildings.size()):
		if city.buildings[index].is_house():
			homes.append(city.buildings[index])
	_check(homes.size() >= 3, "families built homes of their own in %d days (%d)" % [DAYS_PLAYED, homes.size()])
	_check(homes.all(func(home: Building) -> bool: return HomeSites.get_land(city, home.tile) != HomeSites.LAND_NONE or city.construction.get_plot_at(home.tile) != null), "every home stands on land set aside for homes")
	_check(city.construction.projects.all(func(p: ConstructionProject) -> bool: return p.is_home() or p.kind == ConstructionProject.KIND_ROAD or p.kind == ConstructionProject.KIND_FENCE or p.kind == ConstructionProject.KIND_UPGRADE or not city.construction.is_on_residential_land(p.get_footprint())), "no new workplace is planned on it")
	var workplaces_on_land: int = 0
	for index in range(buildings_before, city.buildings.size()):
		var building: Building = city.buildings[index]
		if not building.is_house() and city.construction.is_on_residential_land(TownLogistics.footprint(building.tile, building.size)):
			workplaces_on_land += 1
	_check(workplaces_on_land == 0, "and none was built on it (%d)" % workplaces_on_land)
	# A family records its latest site decision: why it chose the site, or what kept it from building.
	var noted: Array = city.households.filter(func(h: Household) -> bool: return h.home_site_note != "")
	var explained: int = noted.filter(func(h: Household) -> bool: return h.home_site_note.contains(" chose ")).size()
	_check(explained >= 3 and noted.all(func(h: Household) -> bool: return h.home_site_note.contains(" chose ") or h.home_site_note.contains("cannot build a home: ")), "families say why they chose their sites, or what stopped them (%d of %d explain a choice)" % [explained, noted.size()])

# The Community page: choosing a priority by a click; families' views are recorded and shown.
func test_choosing_a_priority(main: Node2D, city: City) -> void:
	main.show_sidebar_tab(TownSidebar.TAB_COMMUNITY)
	await _settle()
	var changes: int = city.social.get_recent_policy_changes()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_priority" and a.get("priority") == CommunityPriority.HOUSING), "the Community page offers permanent housing")
	_check(city.influence.priority == CommunityPriority.HOUSING, "clicking it puts housing first")
	_check(city.influence.responses.filter(func(r: Dictionary) -> bool: return r["priority"] == CommunityPriority.HOUSING).size() == city.households.size(), "every family's view of it is recorded")
	# The gathering notes what it has changed once a week (TownSocial.record_policy).
	for _day in range(FamilyInitiative.INTERVAL_DAYS):
		main.run_simulation_day()
	_check(city.social.get_recent_policy_changes() == changes + 1, "the gathering counts the change")
	var page: Array = SidebarCommunityPage.build({"city": city})
	_check(page.any(func(b: Dictionary) -> bool: return str(b.get("title", "")) == "How the town takes it"), "the page shows how the town takes it")

# The Families page: a family opened by a click shows why it lives where it does, and how it takes
# the priority.
func test_reading_a_familys_reasons(main: Node2D, city: City) -> void:
	var family: Household = null
	for household: Household in city.households:
		if family == null and household.home_site_note.contains("chose"):
			family = household
	_check(family != null, "a family has chosen a home site")
	if family == null:
		return
	main.show_sidebar_tab(TownSidebar.TAB_FAMILIES)
	await _settle()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "focus_household" and int(a.get("household", -1)) == family.id), "the Families page lists the family")
	_check(main.town_sidebar.focused_household_id == family.id, "clicking its card opens it")
	var card: Dictionary = SidebarFamiliesPage.get_card(city, family, true)
	var muted: Array = card["muted"]
	_check(muted.any(func(line: String) -> bool: return line.begins_with("Home site (") and line.contains(family.home_site_note)), "its details say why it chose its home site")
	_check(muted.any(func(line: String) -> bool: return line.begins_with("On homes first: ")), "and how it takes housing being put first")

# A warning, and the player's answer to it: housing first with the stores kept for priorities
# funds no family's improvement; opening the stores again ends the warning.
func test_answering_a_warning(main: Node2D, city: City) -> void:
	main.show_sidebar_tab(TownSidebar.TAB_COMMUNITY)
	await _settle()
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_store_rule" and a.get("rule") == TownInfluence.RULE_PRIORITIES), "the Community page offers 'priorities first'")
	var warning: Callable = func() -> bool: return SidebarCommunityPage.build({"city": city}).any(func(b: Dictionary) -> bool: return str(b.get("title", "")) == "Before you lean on it" and (b["lines"] as Array).any(func(line: String) -> bool: return line.begins_with("No family's improvement will be funded")))
	_check(warning.call(), "the page warns that no family's improvement will be funded")
	_check(city.influence.store_rule == TownInfluence.RULE_PRIORITIES, "and the choice stands: a warning never stops it")
	_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "set_store_rule" and a.get("rule") == TownInfluence.RULE_OPEN), "the page offers opening the stores again")
	_check(city.influence.store_rule == TownInfluence.RULE_OPEN and not warning.call(), "opening them answers the warning")

# Saved and loaded: the land, the priority, the stores rule, and families' reasons come back.
func test_save_and_load(main: Node2D, city: City) -> void:
	var store: SaveStore = SaveStore.new(SAVE_DIRECTORY)
	_check(store.write("Community play", GameState.describe(main, "Community play"), GameState.capture(main)) == OK, "the game saves")
	var state: Dictionary = store.read_state(store.slot_path("Community play"))
	var loaded: Node2D = MainScript.new()
	loaded.use_authored_world = true
	loaded.world_seed = int(state["world_seed"])
	loaded.pending_save_state = state
	root.add_child(loaded)
	await _settle()
	var town: City = loaded.cities[main.selected_city_index]
	_check(GameState.capture_city(town) == GameState.capture_city(city), "the town comes back exactly")
	_check(HomeSites.count_land(town) == HomeSites.count_land(city) and HomeSites.count_land(town, HomeSites.LAND_PREFERRED) == 9, "with its residential land, preferred land included")
	_check(town.influence.priority == CommunityPriority.HOUSING and town.influence.store_rule == TownInfluence.RULE_OPEN, "its priority and stores rule")
	_check(town.households.map(func(h: Household) -> String: return h.home_site_note) == city.households.map(func(h: Household) -> String: return h.home_site_note), "and why each family chose its site")
	loaded.regional_terrain.wait_for_tasks()
	loaded.queue_free()
	await _settle()

# The first block of `side` x `side` tiles a home could stand on, none set aside yet, nearest the
# stockpile.
func open_block(city: City, side: int) -> Vector2i:
	var heart: Vector2i = TownLogistics.center_tile(city.logistics.stockpile_tile, TownLogistics.STOCKPILE_SIZE)
	for radius in range(4, 20):
		for y in range(heart.y - radius, heart.y + radius + 1):
			for x in range(heart.x - radius, heart.x + radius + 1):
				var open: bool = true
				for dy in range(side):
					for dx in range(side):
						var tile: Vector2i = Vector2i(x + dx, y + dy)
						open = open and city.construction.is_inside(tile) and HomeSites.get_land(city, tile) == HomeSites.LAND_NONE and city.construction.validate(Building.BUILDING_HOUSE, tile)["is_valid"] == true
				if open:
					return Vector2i(x, y)
	return Vector2i(-1, -1)

# Scrolls the sidebar's hit for the first action `matches` accepts into view and clicks it.
func _click_action(main: Node2D, matches: Callable) -> bool:
	var sidebar: TownSidebar = main.town_sidebar
	sidebar.rebuild()
	for prim: Dictionary in sidebar.prims:
		if str(prim["p"]) != "hit" or not matches.call(prim["action"]):
			continue
		var rect: Rect2 = prim["rect"]
		sidebar.scroll_to(rect.position.y - TownSidebar.HEADER_HEIGHT - 20.0)
		_click(sidebar.position + rect.get_center() - Vector2(0.0, sidebar.get_scroll()))
		await _settle()
		return true
	return false

func clear_directory() -> void:
	for directory: String in [SAVE_DIRECTORY.path_join("store"), SAVE_DIRECTORY]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file_name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file_name))

func _click(position: Vector2) -> void:
	_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	_mouse_button(MOUSE_BUTTON_LEFT, false, position)

func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event)

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
