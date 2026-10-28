extends SceneTree

# Geography shapes the town (docs/FIRST_STAGE_LOOP.md, milestone 2): a fisher's hut stands on a
# bank and catches what the water in reach allows, all year; a hunter's lodge stands at the
# woods' edge and brings in what the woods in reach hold, less as they are felled; some springs
# high water waterlogs fields beside a river or lake; in winter wolves make an unfenced lodge at
# the woods' edge work warily, and a fence answers them.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_fisher_needs_a_bank()
	test_hunter_needs_woods_and_depends_on_them()
	test_high_water_waterlogs_bank_fields()
	test_wolves_and_fences()
	test_land_food_feeds_a_town()

	if failure_count > 0:
		push_error("Geography validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Geography validation passed.")
	quit()

# The synthetic town map (town_construction_validation.gd): a lake in the south-west corner
# (x < 12, y >= 32), woods along the east edge (x >= 56), farmland along the north.

func test_fisher_needs_a_bank() -> void:
	var city: City = ConstructionTest.make_city()
	_check(city.construction.validate("fisher", Vector2i(30, 20))["is_valid"] != true, "a fisher's hut needs water beside it")
	var bank: Vector2i = Vector2i(12, 34)
	_check(city.construction.validate("fisher", bank)["is_valid"] == true, "a fisher's hut can stand on the lake's bank")
	_check(city.construction.get_size("fisher") == Vector2i.ONE, "a fisher's hut stands on one tile")
	var factor: float = city.land.get_reach_factor_at("fisher", bank, Vector2i.ONE)
	print("[LAND] a fisher's hut on the lake's bank: %.0f%% of a full catch" % (factor * 100.0))
	_check(factor >= 0.75, "the lake gives a good catch")
	city.add_building(Building.new(-1, "fisher", bank, Vector2i.ONE), city.households[0])
	var fisher: Building = city.buildings[-1]
	var by_season: Array[float] = []
	for season in range(4):
		city.day_of_year = season * 90 + 45
		by_season.append(city.land.get_output_factor(fisher))
	_check(by_season.min() == by_season.max() and by_season[0] > 0.0, "fishing does not follow the farming year: %s" % str(by_season))

func test_hunter_needs_woods_and_depends_on_them() -> void:
	var city: City = ConstructionTest.make_city()
	_check(city.construction.validate("hunter", Vector2i(30, 20))["is_valid"] != true, "a hunter's lodge needs woods close by")
	var edge: Vector2i = Vector2i(53, 20)
	_check(city.construction.validate("hunter", edge)["is_valid"] == true, "a hunter's lodge can stand at the woods' edge")
	var before: float = city.land.get_reach_factor_at("hunter", edge, Vector2i(2, 2))
	for y in range(10, 32):
		for x in range(56, 62):
			city.woodland.fell(Vector2i(x, y))
	city.logistics.mark_layout_changed()
	var after: float = city.land.get_reach_factor_at("hunter", edge, Vector2i(2, 2))
	print("[LAND] a hunter's lodge at the woods' edge: %.0f%% of a full bag; %.0f%% once the woods near it are felled" % [before * 100.0, after * 100.0])
	_check(before >= 0.99 and after < before, "felling the woods around a lodge thins its game")

func test_high_water_waterlogs_bank_fields() -> void:
	var city: City = ConstructionTest.make_city()
	city.local_map[33][14]["is_fertile"] = true
	city.add_building(Building.new(-1, "farm", Vector2i(12, 32), Vector2i(3, 3)), city.households[0])
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), city.households[1])
	var bank_field: Building = city.buildings[0]
	var high_field: Building = city.buildings[1]
	_check(city.land.has_flowing_water(), "a lake counts as water that can rise")
	city.land.high_water_this_year = true
	city.day_of_year = 30
	_check(city.land.is_waterlogged(bank_field) and not city.land.is_waterlogged(high_field), "high water reaches only fields beside the water")
	_check(is_equal_approx(city.land.get_output_factor(bank_field), EconomyBalance.FARM_SEASON_YIELD[0] * EconomyBalance.HIGH_WATER_FIELD_YIELD), "a waterlogged field yields little this spring")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).has("High water: 1 field by the water waterlogged this spring"), "the town is told of the high water")
	city.day_of_year = 120
	_check(not is_equal_approx(city.land.get_output_factor(bank_field), city.land.get_output_factor(high_field)) == false, "by summer the bank field yields as any other")
	# Over many springs, high water comes some years and not others.
	var town: City = ConstructionTest.make_city()
	var high: int = 0
	for _year in range(30):
		town.day_of_year = 1
		town.land.advance_day()
		high += 1 if town.land.high_water_this_year else 0
	print("[LAND] high water in %d of 30 springs" % high)
	_check(high > 3 and high < 20, "high water comes some springs, not most")

func test_wolves_and_fences() -> void:
	var city: City = ConstructionTest.make_city()
	city.resources["wood"] = 50
	city.add_building(Building.new(-1, "hunter", Vector2i(53, 20), Vector2i(2, 2)), city.households[0])
	city.add_building(Building.new(-1, "hunter", Vector2i(53, 26), Vector2i(2, 2)), city.households[1])
	var lodge: Building = city.buildings[0]
	var fenced: Building = city.buildings[1]
	fenced.fenced = true
	city.day_of_year = 300
	_check(city.land.is_wolf_exposed(lodge) and not city.land.is_wolf_exposed(fenced), "an unfenced lodge at the woods' edge is exposed to wolves; a fenced one is not")
	_check(city.land.get_output_factor(lodge) < city.land.get_output_factor(fenced), "wolves cost an exposed lodge some of its winter bag")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).has("Wolves: 1 workplace at the woods' edge working warily (fence the yard)"), "the town is told of the wolves")
	city.day_of_year = 120
	_check(is_equal_approx(city.land.get_output_factor(lodge), city.land.get_output_factor(fenced)), "wolves keep to winter")
	_check(city.land.is_wolf_exposed(lodge) and not ConstructionDisplayHelper.get_sidebar_lines(city).any(func(line: String) -> bool: return line.begins_with("Wolves")), "no wolf notice outside winter")

# A town by water and woods can feed itself without farmland.
func test_land_food_feeds_a_town() -> void:
	var city: City = ConstructionTest.make_city()
	city.resources["tools"] = 500
	city.logistics.ensure_ready()
	city.add_building(Building.new(-1, "fisher", Vector2i(12, 34), Vector2i.ONE), city.households[0])
	city.add_building(Building.new(-1, "hunter", Vector2i(53, 20), Vector2i(2, 2)), city.households[1])
	var made: Array[int] = [0, 0]
	for day in range(1, 361):
		city.day_of_year = day
		for i in range(2):
			made[i] += city.get_current_building_output_amount(city.buildings[i]) if city.buildings[i].can_produce() else 0
		city.tick()
	print("[LAND] a year's food from a fisher's hut on the lake and a hunter's lodge at the woods: %d and %d (a farm: about %d)" % [made[0], made[1], int(EconomyBalance.FARM_FOOD_PER_DAY * 360.0)])
	_check(made[0] > 600 and made[1] > 600, "both feed the town through the year")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
