extends SceneTree

# The world map's hand-off into the existing regional and founding flow in main.gd.

const MainScript = preload("res://scripts/main.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	var main: Node2D = MainScript.new()
	root.add_child(main)

	test_game_opens_on_world_map(main)
	test_calendar_waits_until_a_region_is_entered(main)
	test_kingdom_land_cannot_be_entered(main)
	var frontier: WorldMapData.Region = test_entering_frontier_builds_regional_map(main)
	test_same_region_gives_same_map(main, frontier)
	test_founding_locks_player_to_home_region(main, frontier)

	main.queue_free()
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

func test_kingdom_land_cannot_be_entered(main: Node2D) -> void:
	var held: WorldMapData.Region = main.world_map_data.find_region_by_name("Highmoor")
	_check(not bool(main.world_map_view.get_region_entry_status(held)["allowed"]), "free settlers should not enter kingdom land")
	main.world_map_view.request_region_entry(held.id)
	_check(main.current_view == MainScript.VIEW_WORLD, "requesting kingdom land should leave the player on the world map")

func test_entering_frontier_builds_regional_map(main: Node2D) -> WorldMapData.Region:
	var frontier: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	_check(bool(main.world_map_view.get_region_entry_status(frontier)["allowed"]), "contested frontier should be enterable")
	main.world_map_view.request_region_entry(frontier.id)
	_check(main.current_view == MainScript.VIEW_REGION, "entering a region should open the regional map")
	_check(main.entered_world_region_id == frontier.id, "main should remember which world region it entered")
	_check(main.tiles.size() == MainScript.MAP_HEIGHT, "the regional map should be generated")
	_check(not main.world_map_view.visible, "the world map should hide behind the regional map")
	_check(main.get_top_bar_title() == frontier.name, "the regional map should be titled with the world region")
	return frontier

func test_same_region_gives_same_map(main: Node2D, frontier: WorldMapData.Region) -> void:
	var first_map: String = _describe_tiles(main.tiles)
	main.open_world_map()
	_check(main.current_view == MainScript.VIEW_WORLD, "the world button should reopen the world map")
	var other: WorldMapData.Region = main.world_map_data.find_region_by_name("Tall Pines")
	main.world_map_view.request_region_entry(other.id)
	_check(main.entered_world_region_id == other.id, "before founding, the player may choose another region")
	var other_map: String = _describe_tiles(main.tiles)
	main.open_world_map()
	main.world_map_view.request_region_entry(frontier.id)
	_check(_describe_tiles(main.tiles) == first_map, "re-entering a region should rebuild the same regional map")
	_check(other_map != first_map, "different regions should get different regional maps")

func test_founding_locks_player_to_home_region(main: Node2D, frontier: WorldMapData.Region) -> void:
	var site: Vector2i = _find_valid_founding_tile(main)
	_check(site.x >= 0, "the entered region should offer a founding site")
	if site.x < 0:
		return
	_check(main.set_pending_founding_tile(site), "the founding site should be accepted")
	_check(main.found_player_city_at_pending_site(), "founding should still work after entering from the world map")

	main.try_return_to_region(Vector2.ZERO)
	main.open_world_map()
	var other: WorldMapData.Region = main.world_map_data.find_region_by_name("Tall Pines")
	_check(not bool(main.world_map_view.get_region_entry_status(other)["allowed"]), "after founding, other regions should be locked")
	_check(bool(main.world_map_view.get_region_entry_status(frontier)["allowed"]), "the home region should stay enterable")
	main.world_map_view.request_region_entry(frontier.id)
	_check(main.current_view == MainScript.VIEW_REGION and main.has_player_city(), "returning home should keep the founded town")

func _find_valid_founding_tile(main: Node2D) -> Vector2i:
	for y in range(MainScript.MAP_HEIGHT):
		for x in range(MainScript.MAP_WIDTH):
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
