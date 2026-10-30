extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const MainScript = preload("res://scripts/main.gd")
const TradeMenuScript = preload("res://scripts/ui/trade_menu.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_cannot_found_without_pending_site()
	test_pending_site_creates_player_city()
	test_second_player_city_is_prevented()
	test_neutral_town_remains_neutral_and_not_tradable()
	test_town_rules_page_reports_the_choice()

	if failure_count > 0:
		push_error("Founding city validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Founding city validation passed.")
	quit()

func test_cannot_found_without_pending_site() -> void:
	var main = _make_main_with_neutral_town()

	_check(not main.can_found_player_city(), "cannot found without pending founding tile")
	_check(not main.found_player_city_at_pending_site(), "founding without pending tile should fail")
	_check(main.cities.size() == 1, "failed founding should not create a city")
	main.free()

func test_pending_site_creates_player_city() -> void:
	var main = _make_main_with_neutral_town()
	var founding_tile: Vector2i = Vector2i(35, 35)

	_check(main.set_pending_founding_tile(founding_tile), "valid founding tile should become pending")
	_check(main.pending_site_survey.size() >= 4, "a picked site should show a survey of its town map")
	var surveyed_map: Array = main.pending_local_map
	_check(main.can_found_player_city(), "pending valid founding tile should allow founding")
	_check(main.found_player_city_at_pending_site(), "founding should succeed at pending tile")

	_check(main.cities.size() == 2, "founding should add one player city")
	var founded_city: City = main.cities[1]
	_check(founded_city.name == "Player Town", "founded city should use default player-town name")
	_check(founded_city.is_player_city(), "founded city should have player role")
	_check(founded_city.tile == Vector2(founding_tile.x, founding_tile.y), "founded city should use pending tile")
	var founders: int = EconomyBalance.FOUNDING_FAMILIES
	_check(founded_city.households.size() == founders, "founded city should start with the founding families")
	# Founders have random life stages: a newlywed couple is 2 people, the other stages 4.
	_check(founded_city.get_total_population() >= founders * 2 and founded_city.get_total_population() <= founders * 4, "founded city should start with 2-4 people per family, got " + str(founded_city.get_total_population()))
	for household: Household in founded_city.households:
		_check(household.total_population == household.working_adults + household.get_total_child_count(), "seeded household population should match its adults and children")
	_check(int(founded_city.resources["temporary_shelter_capacity"]) == founders * 4, "founded city should have temporary shelter for the founding households")
	_check(int(founded_city.resources["housing_capacity"]) == founders * 4, "founded city should have startup housing capacity state for founding population")
	_check(int(founded_city.resources["food"]) == EconomyBalance.STARTING_FOOD, "founded city should keep expected starting food")
	_check(int(founded_city.resources["wood"]) == 45, "founded city should keep expected starting wood")
	_check(int(founded_city.resources["tools"]) == 14, "founded city should keep expected starting tools")
	_check(not founded_city.local_map.is_empty(), "founded city should receive a local map")
	_check(founded_city.local_map == surveyed_map, "the founded town should get exactly the surveyed map")
	_check(main.pending_founding_tile == Vector2i(-1, -1), "pending founding tile should clear after founding")
	_check(main.selected_city_index == 1, "founded city should become selected city")
	_check(main.current_view == MainScript.VIEW_CITY, "founding should enter city view")
	_check(main.simulation_clock.is_paused, "a newly founded town should start paused")
	# Families leading their own work is the default way to play (Town rules in the menu).
	_check(founded_city.influence.enabled and founded_city.social.enabled and founded_city.hand_method_fallback, "a new town should start with families leading")
	_check(main.get_player_city() == founded_city, "the Town rules page should apply to the player's town")
	main.set_families_lead(founded_city, false)
	_check(not founded_city.influence.enabled and not founded_city.social.enabled and not founded_city.hand_method_fallback, "the classic rules should turn both prototypes off")
	main.set_families_lead(founded_city, true)
	_check(founded_city.influence.enabled and founded_city.social.enabled, "families should lead again when switched back")
	main.free()

func test_second_player_city_is_prevented() -> void:
	var main = _make_main_with_neutral_town()

	_check(main.set_pending_founding_tile(Vector2i(35, 35)), "first valid founding tile should be accepted")
	_check(main.found_player_city_at_pending_site(), "first founding should succeed")
	main.current_view = MainScript.VIEW_REGION
	_check(main.set_pending_founding_tile(Vector2i(70, 45)), "second distant pending tile can be selected for validation")
	_check(not main.can_found_player_city(), "second founding should be blocked once player city exists")
	_check(not main.found_player_city_at_pending_site(), "second founding should fail")
	_check(main.cities.size() == 2, "second founding should not create another city")
	main.free()

func test_neutral_town_remains_neutral_and_not_tradable() -> void:
	var main = _make_main_with_neutral_town()
	_check(main.set_pending_founding_tile(Vector2i(35, 35)), "valid founding tile should be accepted")
	_check(main.found_player_city_at_pending_site(), "founding should succeed")

	var neutral_town: City = main.cities[0]
	_check(neutral_town.is_neutral_city(), "neutral town should remain neutral")
	_check(not neutral_town.is_controllable_city(), "neutral town should remain non-controllable")
	_check(not neutral_town.should_tick_simulation(), "neutral town should remain non-ticking")

	var trade_menu = TradeMenuScript.new()
	trade_menu.open(main.cities)
	trade_menu.handle_city_selection(0, main.cities)
	_check(trade_menu.source_city_index == -1, "trade menu should still reject neutral town")
	main.free()

func test_town_rules_page_reports_the_choice() -> void:
	var menu: GameMenu = GameMenu.new()
	menu.setup(SaveStore.new())
	# In the tree, as in the game: pages give a button focus.
	root.add_child(menu)
	menu.show_pause()
	_check(_menu_button(menu, "Town rules").disabled, "Town rules should wait until there is a town")
	menu.town_rules = {"name": "Player Town", "families_lead": true}
	menu.show_pause()
	var rules_button: Button = _menu_button(menu, "Town rules")
	_check(not rules_button.disabled, "Town rules should open once there is a town")
	rules_button.pressed.emit()
	var chosen: Array = []
	menu.families_lead_chosen.connect(func(on: bool) -> void: chosen.append(on))
	_menu_button(menu, "Classic").pressed.emit()
	_check(chosen == [false], "choosing Classic should be reported to the app")
	menu.free()

# The live button whose text ends with `text` (the page may still hold the previous page's
# buttons until they are freed).
func _menu_button(menu: GameMenu, text: String) -> Button:
	for child: Node in menu.content.get_children():
		if child is Button and not child.is_queued_for_deletion() and (child as Button).text.ends_with(text):
			return child
	return null

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
