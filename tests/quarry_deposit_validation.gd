extends SceneTree

# Quarries on stone (owner decision 2026-10-25; sprint S1b, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md,
# TownDeposits): a quarry must take in a stone deposit and may stand on it, while plain rock and every
# other building stay refused; what it cuts follows the grade and number of stone tiles underfoot;
# every block cut comes out of the deposit, which never grows; a deposit cut out turns to rock, and a
# quarry with no stone left lets its family go and takes no one else; the stone left survives a save;
# without a town map a quarry works as before.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

# A deposit of stone 5 tiles wide, 4 high, with plain rock to its left.
const DEPOSIT: Rect2i = Rect2i(30, 10, 5, 4)
const ROCK: Rect2i = Rect2i(26, 10, 4, 4)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_placement_needs_stone()
	test_output_follows_the_stone()
	test_cutting_takes_from_the_deposit()
	test_a_worked_out_quarry_lets_its_family_go()
	test_stone_left_is_saved()
	test_no_map_works_as_before()
	if failure_count > 0:
		push_error("Quarry deposit validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Quarry deposit validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map([])
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			var tile: Dictionary = city.local_map[y][x]
			tile["resource"] = "none"
			if DEPOSIT.has_point(Vector2i(x, y)):
				tile["type"] = "rough"
				tile["resource"] = "stone"
			elif ROCK.has_point(Vector2i(x, y)):
				tile["type"] = "rough"
	city.logistics.mark_layout_changed()
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func quarry(city: City, origin: Vector2i, household: Household) -> Building:
	var building: Building = Building.new(-1, "quarry", origin, city.construction.get_size("quarry"))
	city.add_building(building, household)
	return building

func test_placement_needs_stone() -> void:
	var city: City = town()
	var off: Dictionary = city.construction.validate("quarry", Vector2i(10, 20))
	_check(off["is_valid"] == false and str(off["message"]).contains("stone"), "a quarry on open ground is refused for want of stone: %s" % off["message"])
	_check(city.construction.validate("quarry", Vector2i(31, 10))["is_valid"] == true, "a quarry wholly on the deposit is allowed")
	_check(city.construction.validate("quarry", Vector2i(33, 12))["is_valid"] == true, "a quarry taking in the deposit's edge from open ground is allowed")
	_check(city.construction.validate("quarry", Vector2i(26, 10))["is_valid"] == false, "plain rock is still refused, stone beside it or not")
	_check(city.construction.validate("toolmaker", Vector2i(31, 10))["is_valid"] == false, "no other building stands on the deposit")
	_check(city.construction.validate("house", Vector2i(32, 11))["is_valid"] == false, "nor a home")

func test_output_follows_the_stone() -> void:
	var city: City = town()
	var deep: Building = quarry(city, Vector2i(31, 10), city.households[0])
	var edge: Building = quarry(city, Vector2i(34, 13), city.households[1])
	var deep_factor: float = TownDeposits.get_quarry_factor(city, deep)
	var edge_factor: float = TownDeposits.get_quarry_factor(city, edge)
	_check(is_equal_approx(deep_factor, 1.0), "nine tiles of the deposit's heart give a full cut (%.2f)" % deep_factor)
	_check(edge_factor > 0.0 and edge_factor < 0.25, "one tile at the deposit's corner gives a small one (%.2f)" % edge_factor)
	var lone: Array = HuntingTest.open_map([])
	lone[5][5]["type"] = "rough"
	lone[5][5]["resource"] = "stone"
	_check(is_equal_approx(TownDeposits.get_grade(lone, Vector2i(5, 5)), EconomyBalance.DEPOSIT_GRADE_FLOOR), "a lone stone tile is the poorest grade")
	var before: int = int(city.resources["stone_blocks"])
	var deep_made: int = 0
	var edge_made: int = 0
	for _day in range(60):
		var flows_before: int = int((city._flows.get("stone_blocks", {}) as Dictionary).get("made", 0))
		city.apply_building_production(deep)
		deep_made += int((city._flows.get("stone_blocks", {}) as Dictionary).get("made", 0)) - flows_before
		flows_before = int((city._flows.get("stone_blocks", {}) as Dictionary).get("made", 0))
		city.apply_building_production(edge)
		edge_made += int((city._flows.get("stone_blocks", {}) as Dictionary).get("made", 0)) - flows_before
	_check(deep_made > edge_made * 4, "the deep quarry cuts several times what the edge one does (%d, %d)" % [deep_made, edge_made])
	_check(int(city.resources["stone_blocks"]) - before == deep_made + edge_made, "everything cut reaches the store")

func test_cutting_takes_from_the_deposit() -> void:
	var city: City = town()
	var deep: Building = quarry(city, Vector2i(31, 10), city.households[0])
	var left: int = TownDeposits.get_stone_left(city, deep)
	_check(left == 9 * EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE, "nine tiles hold their full amount (%d)" % left)
	var checker = Invariants.new()
	checker.watch(city)
	for day in range(1, 91):
		city.apply_building_production(deep)
		checker.check_day(city, day)
		var now: int = TownDeposits.get_stone_left(city, deep)
		_check(now <= left, "the deposit never grows (day %d: %d after %d)" % [day, now, left])
		left = now
	var made: int = int((city._flows.get("stone_blocks", {}) as Dictionary).get("made", 0))
	_check(made > 0 and TownDeposits.get_stone_left(city, deep) == 9 * EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE - made, "every block cut came out of the deposit (%d cut)" % made)
	_check(checker.is_clean(), "the store moved only by what was cut: %s" % str(checker.violations))

func test_a_worked_out_quarry_lets_its_family_go() -> void:
	var city: City = town()
	var household: Household = city.households[0]
	var small: Building = quarry(city, Vector2i(33, 12), household)
	for y in range(12, 15):
		for x in range(33, 36):
			if TownDeposits.is_stone(city.local_map[y][x]):
				city.local_map[y][x]["deposit_left"] = 3
	var cut: int = 0
	for _day in range(60):
		if not small.can_produce():
			break
		var before: int = int(city.resources["stone_blocks"])
		city.apply_building_production(small)
		cut += int(city.resources["stone_blocks"]) - before
	var stone_tiles: int = 0
	for y in range(12, 15):
		for x in range(33, 36):
			stone_tiles += 1 if str(city.local_map[y][x].get("resource", "none")) == "stone" else 0
	_check(stone_tiles == 0, "the stone underfoot is cut out and turned to rock (%d stone tiles left)" % stone_tiles)
	_check(cut == 4 * 3, "it cut exactly what the deposit held (%d)" % cut)
	_check(TownDeposits.is_worked_out(city, small) and small.assigned_household_id < 0, "the worked-out quarry let its family go")
	_check(small.auto_assignment_blocked, "and no one is put to work there again")
	city.auto_assign_workers()
	_check(small.assigned_household_id < 0, "auto-assignment passes it over")
	_check(city.construction.validate("quarry", Vector2i(33, 12))["is_valid"] == false, "a new quarry can't be planned on rock cut out (the old one stands there)")

func test_stone_left_is_saved() -> void:
	var city: City = town()
	var deep: Building = quarry(city, Vector2i(31, 10), city.households[0])
	for _day in range(30):
		city.apply_building_production(deep)
	var left: int = TownDeposits.get_stone_left(city, deep)
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	var restored_quarry: Building = restored.buildings[city.buildings.find(deep)]
	_check(left < 9 * EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE and TownDeposits.get_stone_left(restored, restored_quarry) == left, "the stone left survives a save (%d, %d)" % [left, TownDeposits.get_stone_left(restored, restored_quarry)])

func test_no_map_works_as_before() -> void:
	var city: City = ConstructionTest.make_city(false)
	var building: Building = Building.new(-1, "quarry", Vector2i(2, 2), Vector2i(3, 3))
	city.add_building(building, city.households[0])
	_check(is_equal_approx(TownDeposits.get_quarry_factor(city, building), 1.0) and not TownDeposits.is_worked_out(city, building), "without a town map a quarry cuts as before")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
