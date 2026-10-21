extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const FoundingSiteHelperScript = preload("res://scripts/world/founding_site_helper.gd")
const MainScript = preload("res://scripts/main.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_starting_region_prompt_guides_founding()
	test_pending_site_prompt_guides_confirmation_and_clear()
	test_invalid_hover_reason_is_readable()
	test_founded_player_city_updates_prompt()

	if failure_count > 0:
		push_error("Founding UI validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Founding UI validation passed.")
	quit()

func test_starting_region_prompt_guides_founding() -> void:
	var main = _make_main_with_neutral_town()

	_check(main.get_founding_prompt_text() == "Choose a founding site.", "region start should prompt player to choose founding site")
	_check(main.get_founding_hover_status_text(Vector2i(35, 35)) == "Valid founding site", "valid hover should use readable valid-site text")
	main.free()

func test_pending_site_prompt_guides_confirmation_and_clear() -> void:
	var main = _make_main_with_neutral_town()

	_check(main.set_pending_founding_tile(Vector2i(35, 35)), "valid tile should become pending")
	_check(main.get_founding_prompt_text() == "Confirm the chosen site.", "pending site should prompt explicit confirmation")
	_check(main.can_found_player_city(), "pending valid site should enable founding confirmation")
	main.clear_pending_founding_tile()
	_check(main.get_founding_prompt_text() == "Choose a founding site.", "clearing pending site should restore choose prompt")
	main.free()

func test_invalid_hover_reason_is_readable() -> void:
	var main = _make_main_with_neutral_town()

	main.tiles[1][1]["type"] = "river"
	_check(main.get_founding_hover_status_text(Vector2i(1, 1)) == "Cannot found here: " + FoundingSiteHelperScript.REASON_RIVER, "invalid hover should include clear reason")
	_check(main.get_founding_hover_status_text(Vector2i(4, 4)) == "Cannot found here: " + FoundingSiteHelperScript.REASON_OCCUPIED, "occupied hover should include clear reason")
	main.free()

func test_founded_player_city_updates_prompt() -> void:
	var main = _make_main_with_neutral_town()

	_check(main.set_pending_founding_tile(Vector2i(35, 35)), "valid tile should become pending")
	_check(main.found_player_city_at_pending_site(), "founding should succeed")
	_check(main.get_founding_prompt_text() == "Player town founded.", "after founding, prompt should report founded state")
	_check(main.get_founding_hover_status_text(Vector2i(36, 36)) == "Player town already founded", "after founding, hover should explain founding is complete")
	main.free()

func _make_main_with_neutral_town() -> Node2D:
	var main = MainScript.new()
	main.tiles = _make_tiles(MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT)
	main.cities = _make_neutral_city_list()
	return main

func _make_neutral_city_list() -> Array[City]:
	var generated_cities: Array[City] = []
	generated_cities.append(CityScript.new("Neutral Town", Vector2(4, 4), CityScript.ROLE_NEUTRAL))
	return generated_cities

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

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
