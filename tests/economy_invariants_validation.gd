extends SceneTree

# The economy invariant checker and the store's flow counters (docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md,
# section 4): a town playing normally breaks no invariant and every good it makes, uses, eats and
# builds with is counted; a change to the store nothing accounts for (I2), a negative store (I1) and
# an overfilled site (I7) are caught; shared land checks clean with an idle and a neutral-worked
# workplace beside working ones (I6), the cases the 2026-11-02 fixes settled.

const Invariants = preload("res://tests/sim/economy_invariants.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const ConstructionTest = preload("res://tests/town_construction_validation.gd")

const LAKE: Rect2i = Rect2i(20, 14, 4, 3)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_normal_play_is_clean()
	test_unaccounted_change_is_caught()
	test_negative_store_is_caught()
	test_overfilled_site_is_caught()
	test_shared_land_with_idle_and_neutral()
	if failure_count > 0:
		push_error("Economy invariants validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Economy invariants validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map([])
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			if LAKE.has_point(Vector2i(x, y)):
				city.local_map[y][x]["type"] = "water"
				city.local_map[y][x]["water_kind"] = "lake"
			elif x < 12:
				city.local_map[y][x]["has_trees"] = true
			elif y > 30:
				city.local_map[y][x]["is_fertile"] = true
	city.logistics.mark_layout_changed()
	city.resources["food"] = 400
	city.resources["wood"] = 100
	city.resources["tools"] = 30
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func test_normal_play_is_clean() -> void:
	var city: City = town()
	give(city, city.households[0], "farm", Vector2i(30, 34))
	give(city, city.households[1], "woodcutter", Vector2i(12, 10))
	give(city, city.households[2], "toolmaker", Vector2i(40, 20))
	var checker = Invariants.new()
	checker.watch(city)
	var food: int = int(city.resources["food"])
	var food_flows: int = Invariants.get_flow_total(city, "food")
	for day in range(1, 91):
		city.tick()
		checker.check_day(city, day)
		if day % 30 == 0:
			checker.check_month(city, day)
	_check(checker.is_clean(), "a town playing normally breaks no invariant: %s" % str(checker.violations))
	var flows: Dictionary = city._flows
	_check(int((flows.get("food", {}) as Dictionary).get("made", 0)) > 0, "food made is counted (%s)" % str(flows.get("food", {})))
	_check(int((flows.get("food", {}) as Dictionary).get("need_food", 0)) < 0, "food eaten is counted")
	_check(int((flows.get("wood", {}) as Dictionary).get("used", 0)) < 0, "wood the toolmaker used is counted (%s)" % str(flows.get("wood", {})))
	_check(int((flows.get("tools", {}) as Dictionary).get("made", 0)) > 0, "tools made are counted")
	_check(int(city.resources["food"]) - food == Invariants.get_flow_total(city, "food") - food_flows, "the store's food changed by exactly its flows")

func test_unaccounted_change_is_caught() -> void:
	var city: City = town()
	var checker = Invariants.new()
	checker.watch(city)
	city.resources["wood"] = int(city.resources["wood"]) + 5
	checker.check_day(city, 1)
	_check(checker.violation_count == 1 and checker.violations[0].contains("I2 store wood"), "wood appearing from nowhere is caught: %s" % str(checker.violations))
	checker.check_day(city, 2)
	_check(checker.violation_count == 1, "and reported once, not every day after")
	checker.reset_conservation(city)
	city.add_resource("wood", 3, "test")
	checker.check_day(city, 3)
	_check(checker.violation_count == 1, "a counted change is not a violation")

func test_negative_store_is_caught() -> void:
	var city: City = town()
	var checker = Invariants.new()
	checker.watch(city)
	city.remove_resource("tools", 40, "test")
	checker.check_day(city, 1)
	_check(checker.violations.any(func(v: String) -> bool: return v.contains("I1 store tools")), "a negative store is caught: %s" % str(checker.violations))

func test_overfilled_site_is_caught() -> void:
	var city: City = town()
	var project: ConstructionProject = ConstructionProject.new()
	project.materials_needed = {"wood": 4}
	project.materials_delivered = {"wood": 5}
	city.construction.projects.append(project)
	var checker = Invariants.new()
	checker.watch(city)
	checker.check_day(city, 1)
	_check(checker.violations.any(func(v: String) -> bool: return v.contains("I7")), "a site holding more than it needs is caught: %s" % str(checker.violations))
	city.construction.projects.erase(project)

func test_shared_land_with_idle_and_neutral() -> void:
	var city: City = town()
	var a: Building = give(city, city.households[0], "fisher", Vector2i(21, 17))
	give(city, city.households[1], "fisher", Vector2i(23, 13))
	# One held but worn to nothing, with no hand work to fall back on: it takes no share.
	var idle: Building = give(city, city.households[2], "fisher", Vector2i(19, 15))
	idle.maintenance_level = 0
	idle.works_by_hand_without_tools = false
	var neutral: Building = give(city, city.households[3], "fisher", Vector2i(24, 15))
	neutral.assign_neutral_worker()
	var checker = Invariants.new()
	checker.watch(city)
	checker.check_month(city, 30)
	_check(not idle.can_produce() and a.can_produce() and neutral.can_produce(), "the case holds an idle hut and a neutral-worked one")
	_check(checker.is_clean(), "shared water adds up to the lake once, the idle hut taking nothing: %s" % str(checker.violations))
	_check(Invariants.count_union(city, "water", [TownLand.get_reach_rect("fisher", a.tile, a.size)]) == city.land.count_near(a.tile, a.size, EconomyBalance.FISHER_REACH, "water"), "one reach counted once is the land near it")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
