extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const FoundingSiteHelperScript = preload("res://scripts/world/founding_site_helper.gd")
const MainScript = preload("res://scripts/main.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_invalid_terrain_reasons()
	test_resource_tile_is_invalid()
	test_occupied_and_too_close_tiles_are_invalid()
	test_clear_empty_tile_is_valid()
	test_main_pending_founding_tile_can_be_set_and_cleared()
	test_no_player_city_is_created_by_pending_selection()

	if failure_count > 0:
		push_error("Founding location validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Founding location validation passed.")
	quit()

func test_invalid_terrain_reasons() -> void:
	var tiles: Array = _make_tiles(12, 12)
	var cities: Array[City] = []

	tiles[1][1]["type"] = "river"
	tiles[2][2]["type"] = "mountain"
	tiles[3][3]["has_forest"] = true

	_check(_reason(tiles, cities, Vector2i(1, 1), 4) == FoundingSiteHelperScript.REASON_RIVER, "river tile should be invalid")
	_check(_reason(tiles, cities, Vector2i(2, 2), 4) == FoundingSiteHelperScript.REASON_MOUNTAIN, "mountain tile should be invalid")
	_check(_reason(tiles, cities, Vector2i(3, 3), 4) == FoundingSiteHelperScript.REASON_FOREST, "forest tile should be invalid")

func test_resource_tile_is_invalid() -> void:
	var tiles: Array = _make_tiles(12, 12)
	var cities: Array[City] = []
	tiles[4][4]["resource"] = "stone"

	_check(_reason(tiles, cities, Vector2i(4, 4), 4) == FoundingSiteHelperScript.REASON_RESOURCE, "resource tile should be invalid")

func test_occupied_and_too_close_tiles_are_invalid() -> void:
	var tiles: Array = _make_tiles(30, 30)
	var cities: Array[City] = [CityScript.new("Neutral Town", Vector2(10, 10), CityScript.ROLE_NEUTRAL)]

	_check(_reason(tiles, cities, Vector2i(10, 10), 8) == FoundingSiteHelperScript.REASON_OCCUPIED, "neutral town tile should be occupied")
	_check(_reason(tiles, cities, Vector2i(14, 10), 8) == FoundingSiteHelperScript.REASON_TOO_CLOSE_NEUTRAL, "near-neutral tile should be too close")

func test_clear_empty_tile_is_valid() -> void:
	var tiles: Array = _make_tiles(40, 40)
	var cities: Array[City] = [CityScript.new("Neutral Town", Vector2(4, 4), CityScript.ROLE_NEUTRAL)]

	_check(FoundingSiteHelperScript.is_valid_founding_tile(tiles, cities, Vector2i(35, 35), 8), "clear distant tile should be valid")
	_check(_reason(tiles, cities, Vector2i(35, 35), 8) == FoundingSiteHelperScript.VALID_FOUNDING_SITE, "valid tile should return valid reason")

func test_main_pending_founding_tile_can_be_set_and_cleared() -> void:
	var main = MainScript.new()
	main.tiles = _make_tiles(40, 40)
	main.cities = _make_neutral_city_list()

	_check(main.set_pending_founding_tile(Vector2i(35, 35)), "main should accept valid pending founding tile")
	_check(main.pending_founding_tile == Vector2i(35, 35), "main should store pending founding tile")
	_check(not main.set_pending_founding_tile(Vector2i(4, 4)), "main should reject occupied founding tile")
	_check(main.pending_founding_tile == Vector2i(35, 35), "invalid selection should preserve previous pending founding tile")
	main.clear_pending_founding_tile()
	_check(main.pending_founding_tile == Vector2i(-1, -1), "main should clear pending founding tile")
	main.free()

func test_no_player_city_is_created_by_pending_selection() -> void:
	var main = MainScript.new()
	main.tiles = _make_tiles(40, 40)
	main.cities = _make_neutral_city_list()

	var city_count_before: int = main.cities.size()
	main.set_pending_founding_tile(Vector2i(35, 35))
	_check(main.cities.size() == city_count_before, "pending founding selection should not create a player city")
	main.free()

func _make_tiles(width: int, height: int) -> Array:
	var generated_tiles: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append({
				"type": "grass",
				"has_forest": false,
				"is_fertile": false,
				"resource": "none",
				"has_road": false,
				"has_ford": false
			})
		generated_tiles.append(row)
	return generated_tiles

func _make_neutral_city_list() -> Array[City]:
	var generated_cities: Array[City] = []
	generated_cities.append(CityScript.new("Neutral Town", Vector2(4, 4), CityScript.ROLE_NEUTRAL))
	return generated_cities

func _reason(tiles: Array, cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> String:
	return FoundingSiteHelperScript.get_founding_tile_invalid_reason(tiles, cities, tile_pos, min_city_distance)

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
