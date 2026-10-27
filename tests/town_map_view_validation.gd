extends SceneTree

# The town view in the real game (main.gd + TownMapView): it opens fitted beside the sidebar;
# screen and tile coordinates agree at every zoom; a click on the map plans the chosen building
# on the tile under the cursor, and the town builds it there; the plot tool sets land aside; a
# click on a site selects it; a drag pans instead of placing; the wheel zooms; a click on the
# sidebar never reaches the map; paths worn by the townsfolk show on the ground; and decoration
# stands only where the town map allows it.

const MainScript = preload("res://scripts/main.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	# Headless runs report a 64x64 window; give the panels their normal layout.
	root.size = Vector2i(1600, 900)
	var main: Node2D = MainScript.new()
	# Looks up places by name, so it plays on the hand-authored planet.
	main.use_authored_world = true
	root.add_child(main)
	await _settle()
	await _found_town(main)
	var view: TownMapView = main.town_map_view

	test_view_opens_fitted(main, view)
	test_coordinates_round_trip(view)
	await test_click_plans_a_site(main, view)
	await test_planning_tools(main, view)
	await test_drag_pans_without_placing(main, view)
	await test_wheel_zooms(main, view)
	await test_sidebar_click_stays_off_the_map(main, view)
	await test_paths_show_on_the_ground(main, view)
	test_decoration_follows_the_map(main, view)

	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await _settle()
	if failure_count > 0:
		push_error("Town map view validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town map view validation passed.")
	quit()

func _found_town(main: Node2D) -> void:
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

func test_view_opens_fitted(main: Node2D, view: TownMapView) -> void:
	_check(main.current_view == MainScript.VIEW_CITY, "founding should show the town view")
	_check(view.shown and view.city == main.cities[main.selected_city_index], "the town view should show the founded town")
	_check(view.map_size == Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT), "the view should draw the whole town map")
	_check(is_equal_approx(view.zoom, view.min_zoom()), "the town should open fitted to the screen")
	var sidebar: Rect2 = main.get_city_sidebar_rect()
	_check(view.screen_rect.end.x <= sidebar.position.x, "the map should end where the sidebar begins")
	_check(view.screen_rect.size.x > 1100.0 and view.screen_rect.size.y > 800.0, "the map should fill the window beside the sidebar, got " + str(view.screen_rect))
	_check(sidebar.end.y > 850.0, "the sidebar should run the window's full height")

func test_coordinates_round_trip(view: TownMapView) -> void:
	for zoom: float in [view.min_zoom(), 2.5, TownMapStyle.MAX_ZOOM]:
		view.focus_on(Vector2(view.map_size) * TownMapStyle.TILE * 0.5, zoom)
		var checked: int = 0
		for tile: Vector2i in [Vector2i(32, 22), Vector2i(30, 20), Vector2i(35, 24), Vector2i(0, 0), Vector2i(63, 43)]:
			var rect: Rect2 = view.tile_rect_to_screen(tile)
			if not view.screen_rect.has_point(rect.get_center()):
				continue
			checked += 1
			_check(view.screen_to_tile(rect.get_center()) == tile, "screen and tile coordinates should agree at zoom %.2f for %s" % [zoom, str(tile)])
			_check(is_equal_approx(rect.size.x, TownMapStyle.TILE * zoom), "a tile should be TILE * zoom pixels wide")
		_check(checked >= 1, "some tiles should be on screen at zoom %.2f" % zoom)
	view.reset_camera()

func test_click_plans_a_site(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	main.select_building_type(MainScript.BUILDING_HOUSE)
	var tile: Vector2i = _valid_spot(main, MainScript.BUILDING_HOUSE)
	_check(tile.x >= 0, "the town should have room for a house")
	view.focus_on(TownMapStyle.tile_rect(tile).get_center(), 2.5)
	var position: Vector2 = view.tile_rect_to_screen(tile).get_center()
	var before: int = city.buildings.size()
	var planned: int = city.construction.projects.size()
	_click(position)
	await _settle()
	_check(city.construction.projects.size() == planned + 1, "a click on the map should plan the chosen building")
	_check(city.buildings.size() == before, "nothing stands until the town has built it")
	if city.construction.projects.size() != planned + 1:
		return
	var project: ConstructionProject = city.construction.projects[-1]
	_check(project.tile == tile, "the site should be on the clicked tile, got " + str(project.tile) + " for " + str(tile))
	for _day in range(90):
		city.tick()
		if not city.construction.projects.has(project):
			break
	_check(city.buildings.size() == before + 1 and city.buildings[-1].tile == tile, "the house should stand on the clicked tile once built")
	await _settle()
	_check(view.development_signature != 0, "the view should notice the new building")

func test_planning_tools(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	view.reset_camera()
	main.select_building_type(TownConstruction.PLOT)
	var plot_tile: Vector2i = _valid_spot(main, TownConstruction.PLOT)
	var plots: int = city.construction.plots.size()
	_click(view.tile_rect_to_screen(plot_tile).get_center())
	await _settle()
	_check(city.construction.plots.size() == plots + 1, "the plot tool should set land aside")
	main.select_building_type(MainScript.BUILDING_HOUSE)
	_click(view.tile_rect_to_screen(plot_tile + Vector2i.ONE).get_center())
	await _settle()
	_check(city.construction.projects[-1].plot_id == int(city.construction.plots[-1]["id"]), "a house placed on a plot is built on that plot")

	main.is_placing_building = false
	_click(view.tile_rect_to_screen(plot_tile).get_center())
	await _settle()
	_check(main.city_building_overlay.inspected_project_id == city.construction.projects[-1].id, "a click on a site should select it")
	main.clear_selected_household()
	view.focus_on(Vector2(view.map_size) * TownMapStyle.TILE * 0.5, 2.5)

func test_drag_pans_without_placing(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	main.is_placing_building = true
	var tile: Vector2i = _valid_spot(main, MainScript.BUILDING_HOUSE)
	var start: Vector2 = view.tile_rect_to_screen(tile).get_center()
	var camera_before: Vector2 = view.camera_center
	var before: int = city.buildings.size()
	_mouse_button(MOUSE_BUTTON_LEFT, true, start)
	for step in range(1, 6):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = start + Vector2(step * 12.0, 0.0)
		motion.global_position = motion.position
		root.push_input(motion)
	var planned: int = city.construction.projects.size()
	_mouse_button(MOUSE_BUTTON_LEFT, false, start + Vector2(60.0, 0.0))
	await _settle()
	_check(city.buildings.size() == before and city.construction.projects.size() == planned, "a drag should not place a building")
	_check(view.camera_center.x < camera_before.x - 1.0, "dragging right should move the view toward the west")

# From a middle zoom: near the fitted view the camera keeps the board on screen, which takes
# precedence over the point under the cursor.
func test_wheel_zooms(_main: Node2D, view: TownMapView) -> void:
	view.focus_on(Vector2(view.map_size) * TownMapStyle.TILE * 0.5, 2.5)
	var zoom_before: float = view.zoom
	var cursor: Vector2 = view.screen_rect.get_center() + Vector2(120.0, 60.0)
	var under_cursor: Vector2 = view.screen_to_map(cursor)
	_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, cursor)
	for _frame in range(40):
		await process_frame
	_check(view.zoom > zoom_before * 1.1, "the wheel should zoom in")
	_check(view.screen_to_map(cursor).distance_to(under_cursor) < 1.0, "zooming should keep the point under the cursor in place: %s became %s at zoom %.2f -> %.2f, camera %s" % [str(under_cursor), str(view.screen_to_map(cursor)), zoom_before, view.zoom, str(view.camera_center)])

func test_sidebar_click_stays_off_the_map(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	var before: int = city.buildings.size()
	var planned: int = city.construction.projects.size()
	main.select_building_type(MainScript.BUILDING_HOUSE)
	_click(main.get_city_sidebar_rect().get_center())
	await _settle()
	_check(city.buildings.size() == before and city.construction.projects.size() == planned, "a click on the sidebar should not place a building")
	_check(view.press_button == MOUSE_BUTTON_NONE, "a click on the sidebar should not start a drag on the map")

# Families walking to work and carrying goods wear paths, and the view redraws the ground.
func test_paths_show_on_the_ground(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	var spot: Vector2i = _valid_spot(main, "forager_garden")
	_check(city.construction.request_building("forager_garden", spot) != null, "the town should have room for a garden to walk to")
	for _day in range(60):
		city.tick()
	await _settle()
	var trodden: int = 0
	for y in range(view.map_size.y):
		for x in range(view.map_size.x):
			trodden += 1 if TownLogistics.get_path_level(city.local_map[y][x]) != TownLogistics.PATH_NONE else 0
	print("[TOWN] trodden tiles after 60 days: %d" % trodden)
	_check(trodden > 0 and city.logistics.paths_version > 0, "two months of working a garden should wear a trail to it")
	_check(view.ground_paths_version == city.logistics.paths_version, "the view should redraw the ground when paths change")

# Trees only on tree tiles; ground details never on occupied, wooded, rough, road, path, or
# water tiles.
func test_decoration_follows_the_map(main: Node2D, view: TownMapView) -> void:
	var city: City = main.cities[main.selected_city_index]
	var features: TownFeatureLayer = view.feature_layer
	var trees: int = 0
	var shrub_tiles: int = 0
	for y in range(view.map_size.y):
		for x in range(view.map_size.x):
			var tile: Dictionary = city.local_map[y][x]
			trees += 1 if tile["has_trees"] else 0
			if features.is_open_ground(tile):
				shrub_tiles += 1
				_check(tile["type"] == "ground" and not tile["has_trees"] and not tile["occupied"] and not tile["has_road"] and TownLogistics.get_path_level(tile) == TownLogistics.PATH_NONE, "ground details should only stand on open ground")
	_check(trees > 0 and shrub_tiles > 0, "the town map should have woods and open ground")
	for building: Building in city.buildings:
		var tile: Dictionary = city.local_map[building.tile.y][building.tile.x]
		_check(not features.is_open_ground(tile), "no ground details under a building")

func _valid_spot(main: Node2D, building_type: String) -> Vector2i:
	var center: Vector2i = Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) / 2
	for radius in range(0, 20):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if main.is_valid_building_placement(main.selected_city_index, building_type, Vector2i(x, y)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)

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
