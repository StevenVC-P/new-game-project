extends SceneTree

# The world map's hand-off into the continuous regional map and the founding flow in main.gd:
# entering regions, kingdom land as view-only, the founding neighbourhood following the
# camera, zooming between the two maps at the same place and scale, and founding.

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

	test_game_opens_on_world_map(main)
	test_calendar_waits_until_a_region_is_entered(main)
	test_kingdom_land_is_view_only(main)
	var frontier: WorldMapData.Region = test_entering_frontier_shows_its_land(main)
	test_same_region_gives_same_map(main, frontier)
	test_neighbourhood_follows_the_camera(main, frontier)
	await test_wheel_zoom_keeps_the_point_under_the_cursor(main)
	await test_zoom_hands_off_between_maps(main, frontier)
	test_founding_keeps_the_home_town(main, frontier)
	await test_world_button_opens_the_world_map(main)

	main.queue_free()
	await _settle()
	if failure_count > 0:
		push_error("World map flow validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("World map flow validation passed.")
	quit()

func test_game_opens_on_world_map(main: Node2D) -> void:
	_check(main.current_view == MainScript.VIEW_WORLD, "the game should open on the world map")
	_check(main.tiles.is_empty(), "no regional map should exist before a region is chosen")
	_check(main.world_map_view != null and main.world_map_view.visible, "the world map should be showing")

func test_calendar_waits_until_a_region_is_entered(main: Node2D) -> void:
	var date_before: String = main.world_calendar.get_formatted_date()
	main._process(30.0)
	_check(main.world_calendar.get_formatted_date() == date_before, "the calendar should not advance before any region exists")

func test_kingdom_land_is_view_only(main: Node2D) -> void:
	var held: WorldMapData.Region = main.world_map_data.find_region_by_name("Highmoor")
	var status: Dictionary = main.world_map_view.get_region_entry_status(held)
	_check(bool(status["allowed"]) and not bool(status["can_settle"]), "kingdom land should be viewable but not settleable")
	_enter(main, held)
	_check(main.current_view == MainScript.VIEW_REGION, "viewing kingdom land should open the regional map")
	var center: Vector2i = main.NEIGHBOURHOOD_SIZE / 2
	var refused: int = 0
	var checked: int = 0
	for y in range(center.y - 10, center.y + 10):
		for x in range(center.x - 10, center.x + 10):
			if main.get_kingdom_holding_tile(Vector2i(x, y)) == null:
				continue
			checked += 1
			if not main.is_valid_founding_tile(Vector2i(x, y)) and (FoundingSiteHelper.VALID_FOUNDING_SITE != main.get_founding_tile_invalid_reason(Vector2i(x, y))):
				refused += 1
	_check(checked > 0 and refused == checked, "no town may be founded on land a kingdom holds (%d of %d refused)" % [refused, checked])
	main.open_world_map()

func test_entering_frontier_shows_its_land(main: Node2D) -> WorldMapData.Region:
	var frontier: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	var status: Dictionary = main.world_map_view.get_region_entry_status(frontier)
	_check(bool(status["allowed"]) and bool(status["can_settle"]), "contested frontier should be enterable and settleable")
	_enter(main, frontier)
	_check(main.current_view == MainScript.VIEW_REGION, "entering a region should open the regional map")
	_check(main.entered_world_region_id == frontier.id, "main should remember which world region it entered")
	_check(main.tiles.size() == main.NEIGHBOURHOOD_SIZE.y and (main.tiles[0] as Array).size() == main.NEIGHBOURHOOD_SIZE.x, "the founding neighbourhood should be loaded")
	_check(not main.world_map_view.visible, "the world map should hide behind the regional map")
	_check(main.get_top_bar_title() == frontier.name, "the regional map should be titled with the region in view")
	_check(not main.region_founding_sites.is_empty(), "the frontier should offer founding sites")
	var has_callow_ford: bool = main.cities.any(func(city: City) -> bool: return city.name == "Callow Ford")
	_check(has_callow_ford, "the world's settlements should be towns of the neighbourhood")
	return frontier

func test_same_region_gives_same_map(main: Node2D, frontier: WorldMapData.Region) -> void:
	var first_map: String = _describe_tiles(main.tiles)
	main.open_world_map()
	_check(main.current_view == MainScript.VIEW_WORLD, "the world button should reopen the world map")
	var other: WorldMapData.Region = main.world_map_data.find_region_by_name("Tall Pines")
	_enter(main, other)
	_check(main.entered_world_region_id == other.id, "before founding, the player may choose another region")
	var other_map: String = _describe_tiles(main.tiles)
	main.open_world_map()
	_enter(main, frontier)
	_check(_describe_tiles(main.tiles) == first_map, "re-entering a region should show the same land")
	_check(other_map != first_map, "different regions should show different land")

# Before founding, panning away and stopping moves the founding neighbourhood with the camera.
func test_neighbourhood_follows_the_camera(main: Node2D, frontier: WorldMapData.Region) -> void:
	var view: RegionMapView = main.region_map_view
	var start_origin: Vector2i = main.neighbourhood_origin
	var start: Vector2 = view.camera_global_tile()
	view.focus_on_global_tile(start + Vector2(140.0, 0.0), view.zoom)
	main.follow_camera_with_neighbourhood()
	_check(main.neighbourhood_origin == start_origin, "the neighbourhood should wait for the camera to come to rest")
	_rest_camera(main)
	main.follow_camera_with_neighbourhood()
	main.wait_for_neighbourhood_job()
	_check(main.neighbourhood_origin != start_origin, "the neighbourhood should follow the camera before founding")
	var local: Vector2i = main.global_to_local_tile(Vector2i(view.camera_global_tile().floor()))
	_check(main.is_inside_map(local.x, local.y), "the camera should be over the neighbourhood after it moves")
	# Back to the region's settlement for the rest of the flow.
	main.open_world_map()
	_enter(main, frontier)

func test_wheel_zoom_keeps_the_point_under_the_cursor(main: Node2D) -> void:
	var view: RegionMapView = main.region_map_view
	view.focus_on_global_tile(view.camera_global_tile(), 1.0)
	var cursor: Vector2 = view.screen_rect.get_center() + Vector2(-120.0, 80.0)
	var world_point: Vector2 = view.screen_to_world(cursor)
	for button: MouseButton in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_wheel(button, cursor)
		for _frame in range(30):
			await process_frame
		var drift: float = view.screen_to_world(cursor).distance_to(world_point)
		_check(drift < 0.5, "wheel zoom on the regional map should keep the point under the cursor (off by %.2f world units)" % drift)

func test_zoom_hands_off_between_maps(main: Node2D, frontier: WorldMapData.Region) -> void:
	var view: RegionMapView = main.region_map_view
	view.focus_on_global_tile(view.camera_global_tile(), RegionMapView.HANDOFF_ZOOM)
	var cursor: Vector2 = view.screen_rect.get_center() + Vector2(60.0, 30.0)
	var world_point: Vector2 = view.screen_to_world(cursor)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, cursor)
	await _settle()
	_check(main.current_view == MainScript.VIEW_WORLD, "zooming out past the regional map's widest view should open the world map")
	var atlas: WorldMapView = main.world_map_view
	_check(atlas.zoom <= WorldMapStyle.MAX_ZOOM and atlas.target_zoom < WorldMapStyle.MAX_ZOOM * 0.95, "the zoom-out should carry on into the world map (zoom %.2f, aiming at %.2f)" % [atlas.zoom, atlas.target_zoom])
	_check(atlas.screen_to_world(cursor).distance_to(world_point) < 1.0, "the place under the cursor should stay under the cursor (off by %.2f world units)" % atlas.screen_to_world(cursor).distance_to(world_point))

	# Back at the closest view, one more step in carries on into the regional map.
	atlas.focus_on(world_point - (cursor - atlas.map_screen_rect().get_center()) / WorldMapStyle.MAX_ZOOM, WorldMapStyle.MAX_ZOOM)
	_wheel(MOUSE_BUTTON_WHEEL_UP, cursor)
	await _settle()
	_check(main.current_view == MainScript.VIEW_REGION, "zooming in past the world map's closest view should open the regional map")
	_check(view.zoom >= RegionMapView.HANDOFF_ZOOM and view.target_zoom > RegionMapView.HANDOFF_ZOOM * 1.05, "the zoom-in should carry on into the regional map (zoom %.2f, aiming at %.2f)" % [view.zoom, view.target_zoom])
	_check(view.screen_to_world(cursor).distance_to(world_point) < 1.0, "the place under the cursor should stay under the cursor coming back (off by %.2f)" % view.screen_to_world(cursor).distance_to(world_point))

	# Zooming into the sea stays on the atlas.
	main.open_world_map()
	atlas.focus_on(Vector2(3600.0, 3500.0), WorldMapStyle.MAX_ZOOM)
	var sea_cursor: Vector2 = atlas.map_screen_rect().get_center()
	if not main.world_map_data.is_land_at(atlas.screen_to_world(sea_cursor)):
		_wheel(MOUSE_BUTTON_WHEEL_UP, sea_cursor)
		await _settle()
		_check(main.current_view == MainScript.VIEW_WORLD, "zooming into open sea should stay on the world map")
	_enter(main, frontier)

func test_founding_keeps_the_home_town(main: Node2D, frontier: WorldMapData.Region) -> void:
	var site: Vector2i = _find_valid_founding_tile(main)
	_check(site.x >= 0, "the entered region should offer a founding site")
	if site.x < 0:
		return
	_check(main.set_pending_founding_tile(site), "the founding site should be accepted")
	_check(main.found_player_city_at_pending_site(), "founding should still work after entering from the world map")
	var home_origin: Vector2i = main.neighbourhood_origin

	main.try_return_to_region(Vector2.ZERO)
	main.open_world_map()
	var other: WorldMapData.Region = main.world_map_data.find_region_by_name("Tall Pines")
	var status: Dictionary = main.world_map_view.get_region_entry_status(other)
	_check(bool(status["allowed"]) and not bool(status["can_settle"]), "after founding, other regions should be viewable but not settleable")
	_enter(main, other)
	_check(main.current_view == MainScript.VIEW_REGION and main.has_player_city(), "viewing another region should keep the founded town")
	_check(main.neighbourhood_origin == home_origin, "the home neighbourhood should stay put after founding")
	main.region_map_view.focus_on_global_tile(main.region_map_view.camera_global_tile() + Vector2(200.0, 0.0), 1.0)
	_rest_camera(main)
	main.follow_camera_with_neighbourhood()
	main.wait_for_neighbourhood_job()
	_check(main.neighbourhood_origin == home_origin, "after founding the neighbourhood should not follow the camera")
	main.open_world_map()
	_check(bool(main.world_map_view.get_region_entry_status(frontier)["allowed"]), "the home region should stay enterable")
	_enter(main, frontier)
	_check(main.current_view == MainScript.VIEW_REGION and main.has_player_city(), "returning home should keep the founded town")

# Clicks pushed through the whole input chain. The atlas's "Back to (region)" button sits
# where the regional map's World button is, so a click that opened the atlas must not also
# reach the atlas and close it again.
func test_world_button_opens_the_world_map(main: Node2D) -> void:
	var world_button: Vector2 = Vector2(50.0, 21.0)
	for trip in range(3):
		await _settle()
		_check(main.current_view == MainScript.VIEW_REGION, "trip %d should start on the regional map" % trip)
		_click(world_button)
		await _settle()
		_check(main.current_view == MainScript.VIEW_WORLD, "the World button should open the world map (trip %d)" % trip)
		# The atlas's own "Back to" button returns to the region.
		_click(Vector2(30.0, 21.0))
		await _settle()
		_check(main.current_view == MainScript.VIEW_REGION, "the atlas's Back button should return to the region (trip %d)" % trip)

# Enters a region from the atlas and waits for its founding neighbourhood, which is prepared
# on a worker thread.
func _enter(main: Node2D, region: WorldMapData.Region) -> void:
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()

# As if the camera had been still long enough for the neighbourhood to follow it.
func _rest_camera(main: Node2D) -> void:
	main.region_map_view.last_camera_change_msec -= main.NEIGHBOURHOOD_FOLLOW_REST_MSEC + 100

func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event)

func _wheel(button: MouseButton, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _find_valid_founding_tile(main: Node2D) -> Vector2i:
	for y in range(main.region_map_size.y):
		for x in range(main.region_map_size.x):
			if main.is_valid_founding_tile(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _describe_tiles(tiles: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for row: Array in tiles:
		for tile: Dictionary in row:
			parts.append(str(tile["type"]) + str(tile["has_forest"]) + str(tile["resource"]))
	return "".join(parts).md5_text()

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
