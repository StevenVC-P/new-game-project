extends SceneTree

# Fish and game stocks (sprint S13, master roadmap Phase 2; TownLand): the town's fish and game regrow
# logistically and fall with every catch; a fisher's and hunter's yield follows the stock, with no
# floor; a stock taken to nothing recovers only slowly, from beyond the town's reach; heavy fishing
# empties a small lake while light fishing holds; felling woods leaves less game land; the stocks
# survive a save.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const LAKE: Rect2i = Rect2i(10, 10, 6, 5)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_regrowth()
	test_a_catch_takes_from_the_stock()
	test_heavy_and_light_fishing()
	test_game_land_follows_the_woods()
	test_stocks_are_saved()
	if failure_count > 0:
		push_error("Wild stocks validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Wild stocks validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map([])
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			var tile: Dictionary = city.local_map[y][x]
			if LAKE.has_point(Vector2i(x, y)):
				tile["type"] = "water"
				tile["water_kind"] = "lake"
				tile["has_trees"] = false
	city.logistics.mark_layout_changed()
	city.resources["food"] = 50000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func test_regrowth() -> void:
	var half: float = 0.5
	var empty: float = 0.0
	var full: float = 1.0
	for _day in range(360):
		half = TownLand.regrow(half, EconomyBalance.FISH_GROWTH_PER_YEAR)
		empty = TownLand.regrow(empty, EconomyBalance.FISH_GROWTH_PER_YEAR)
		full = TownLand.regrow(full, EconomyBalance.FISH_GROWTH_PER_YEAR)
	_check(half > 0.6 and half < 0.75, "half a stock grows by about its growth rate's share in a year (%.3f)" % half)
	_check(empty > 0.0 and empty < 0.05, "a stock fished out recovers only slowly, from beyond the town (%.3f after a year)" % empty)
	_check(is_equal_approx(full, 1.0), "a full stock stays full")

func fisher(city: City, household: Household, at: Vector2i) -> Building:
	var building: Building = Building.new(-1, "fisher", at, city.construction.get_size("fisher"))
	city.add_building(building, household)
	return building

func test_a_catch_takes_from_the_stock() -> void:
	var city: City = town()
	var hut: Building = fisher(city, city.households[0], Vector2i(LAKE.end.x, LAKE.position.y + 1))
	var capacity: float = city.land.get_capacity("fish")
	_check(is_equal_approx(capacity, LAKE.get_area() * EconomyBalance.FISH_STOCK_PER_WATER_TILE), "the lake holds its tiles' worth of fish (%.0f)" % capacity)
	var full: float = city.land.get_output_factor(hut)
	city.land.note_catch(hut, int(capacity * 0.4))
	_check(is_equal_approx(city.land.fish_stock, 0.6), "a catch comes out of the stock (%.3f)" % city.land.fish_stock)
	_check(is_equal_approx(city.land.get_output_factor(hut), full * 0.6), "and the hut's yield follows it (%.3f of %.3f)" % [city.land.get_output_factor(hut), full])
	_check(is_equal_approx(city.land.get_reach_factor_at("fisher", hut.tile, hut.size), city.land.get_land_factor_at("fisher", hut.tile, hut.size) * 0.6), "families judging a site see the stock too")
	city.land.note_catch(hut, int(capacity * 2.0))
	_check(city.land.fish_stock == 0.0 and city.land.get_output_factor(hut) == 0.0, "fished out, the water gives nothing: no floor")

# The same lake worked by one hut and by four, six years each. Huts share the water (TownLand), so all
# of them together take at most the lake's worth: worked to the full, the stock settles near half,
# where it regrows as fast as it is fished, and the catch is halved. One hut leaves it nearly full.
func test_heavy_and_light_fishing() -> void:
	var stocks: Array[float] = []
	for huts in [1, 4]:
		var city: City = town()
		var spots: Array[Vector2i] = [Vector2i(LAKE.end.x, LAKE.position.y), Vector2i(LAKE.position.x - 2, LAKE.position.y), Vector2i(LAKE.position.x, LAKE.end.y), Vector2i(LAKE.end.x, LAKE.end.y - 1)]
		var built: Array[Building] = []
		for i in range(huts):
			built.append(fisher(city, city.households[i], spots[i]))
		for _day in range(2160):
			city.land.advance_day()
			for hut: Building in built:
				city.land.note_catch(hut, int(round(EconomyBalance.FISHER_FOOD_PER_DAY * city.land.get_output_factor(hut))))
		stocks.append(city.land.fish_stock)
	print("[STOCK] fish left after six years: one hut %.2f, four huts %.2f" % stocks)
	_check(stocks[0] > 0.75 and stocks[1] >= 0.45 and stocks[1] < stocks[0] - 0.15, "four huts work the lake well down, never below about half; one leaves it nearly full (%.2f, %.2f)" % stocks)

func test_game_land_follows_the_woods() -> void:
	var city: City = town()
	for y in range(20, 35):
		for x in range(30, 50):
			city.local_map[y][x]["has_trees"] = true
	city.woodland.land_version += 1
	var before: float = city.land.get_capacity("game")
	var felled: int = 0
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			if city.local_map[y][x]["has_trees"] == true and felled < 200:
				city.local_map[y][x]["has_trees"] = false
				felled += 1
	city.woodland.land_version += 1
	_check(felled > 0 and is_equal_approx(city.land.get_capacity("game"), before - felled * EconomyBalance.GAME_STOCK_PER_WOODS_TILE), "felled woods hold no game (%.0f -> %.0f)" % [before, city.land.get_capacity("game")])

func test_stocks_are_saved() -> void:
	var city: City = town()
	city.land.fish_stock = 0.42
	city.land.game_stock = 0.17
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(is_equal_approx(restored.land.fish_stock, 0.42) and is_equal_approx(restored.land.game_stock, 0.17), "fish and game survive a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
