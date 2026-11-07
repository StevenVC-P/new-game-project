extends SceneTree

# Living forests (sprint S2, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md, TownWoodland): a woodcutter's wood
# comes out of the trees it fells, so the standing timber falls by exactly what it makes and it fells
# at the agreed pace (about 16 tiles a year at full work); with no tree it may fell it makes nothing,
# and it makes less the farther the trees are; kept woods are never cut; woods that spread grow in
# young and mature over years; families' gathering cuts trees near home; felling still thins a
# hunter's woods; a woodcutter whose trees are gone reconsiders its work; the timber left survives a
# save; a tile from an older map counts as mature.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

const WOODS: Rect2i = Rect2i(10, 10, 12, 12)
const CUTTER: Vector2i = Vector2i(22, 14)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_wood_comes_out_of_the_trees()
	test_felling_pace()
	test_no_trees_no_wood()
	test_distance_costs_wood()
	test_kept_woods_are_not_cut()
	test_young_woods_grow()
	test_gathering_cuts_trees_near_home()
	test_felling_thins_hunting_woods()
	test_a_woodcutter_without_trees_reconsiders()
	test_timber_is_saved()
	if failure_count > 0:
		push_error("Living forests validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Living forests validation passed.")
	quit()

func town(woods: Array[Rect2i] = [WOODS]) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map(woods)
	city.logistics.mark_layout_changed()
	city.woodland.forget_frontier()
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 100
	city.resources["tools"] = 200
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func made(city: City, good: String) -> int:
	return int((city._flows.get(good, {}) as Dictionary).get("made", 0))

func test_wood_comes_out_of_the_trees() -> void:
	var city: City = town()
	var woodcutter: Building = give(city, city.households[0], "woodcutter", CUTTER)
	var timber: int = city.woodland.get_standing_timber()
	_check(timber == WOODS.get_area() * EconomyBalance.TIMBER_PER_TILE, "an older map's woods count as mature (%d)" % timber)
	var checker = Invariants.new()
	checker.watch(city)
	for day in range(1, 121):
		city.apply_building_production(woodcutter)
		checker.check_day(city, day)
	var wood: int = made(city, "wood")
	_check(wood > 0, "the woodcutter made wood (%d)" % wood)
	_check(timber - city.woodland.get_standing_timber() == wood, "the standing timber fell by exactly the wood made (%d, %d)" % [timber - city.woodland.get_standing_timber(), wood])
	_check(checker.is_clean(), "the store moved only by what was made: %s" % str(checker.violations))

func test_felling_pace() -> void:
	var city: City = town()
	var woodcutter: Building = give(city, city.households[0], "woodcutter", CUTTER)
	var tiles: int = WOODS.get_area()
	for _day in range(Calendar.DAYS_PER_YEAR):
		city.apply_building_production(woodcutter)
	var felled: int = tiles - city.woodland.get_wooded_in_rect(WOODS).size()
	var expected: float = float(made(city, "wood")) / float(EconomyBalance.TIMBER_PER_TILE)
	_check(absf(float(felled) - expected) <= 1.0, "it fells as fast as its wood is made: %d tiles for %d wood (%.1f expected)" % [felled, made(city, "wood"), expected])
	_check(felled <= 18, "no faster than the agreed pace for a full woodcutter (about 16 a year): %d" % felled)

func test_no_trees_no_wood() -> void:
	var city: City = town([])
	var woodcutter: Building = give(city, city.households[0], "woodcutter", CUTTER)
	_check(city.woodland.get_felling_factor(woodcutter) == 0.0 and city.land.get_reach_factor(woodcutter) == 0.0, "with no trees it may fell, nothing to cut")
	for _day in range(30):
		city.apply_building_production(woodcutter)
	_check(made(city, "wood") == 0, "and it makes no wood (%d)" % made(city, "wood"))

func test_distance_costs_wood() -> void:
	var near: City = town([Rect2i(25, 14, 3, 3)])
	var far: City = town([Rect2i(36, 14, 3, 3)])
	var a: Building = give(near, near.households[0], "woodcutter", CUTTER)
	var b: Building = give(far, far.households[0], "woodcutter", CUTTER)
	var near_factor: float = near.woodland.get_felling_factor(a)
	var far_factor: float = far.woodland.get_felling_factor(b)
	_check(is_equal_approx(near_factor, 1.0), "trees within its reach give a full cut (%.2f)" % near_factor)
	_check(far_factor < 0.6 and far_factor > 0.0, "trees a dozen tiles off give about half (%.2f)" % far_factor)
	_check(is_equal_approx(far.woodland.estimate_felling_factor_at(CUTTER, Vector2i(2, 2)), far_factor), "a family judging the site sees the same")

func test_kept_woods_are_not_cut() -> void:
	var city: City = town()
	var woodcutter: Building = give(city, city.households[0], "woodcutter", CUTTER)
	city.woodland.protect_block(WOODS.position, WOODS.end - Vector2i.ONE)
	_check(city.woodland.get_felling_factor(woodcutter) == 0.0, "every tree kept: nothing it may fell")
	var timber: int = city.woodland.get_standing_timber()
	for _day in range(60):
		city.apply_building_production(woodcutter)
	_check(city.woodland.get_standing_timber() == timber and made(city, "wood") == 0, "kept woods lose no timber, and it makes no wood")

func test_young_woods_grow() -> void:
	var city: City = town()
	var tile: Vector2i = Vector2i(30, 30)
	city.woodland.plant(tile)
	_check(TownWoodland.get_timber(city.local_map[tile.y][tile.x]) == EconomyBalance.YOUNG_WOODS_TIMBER, "woods that spread grow in young")
	var years: int = 0
	while TownWoodland.get_timber(city.local_map[tile.y][tile.x]) < EconomyBalance.TIMBER_PER_TILE and years < 30:
		city.woodland.grow_timber()
		years += 1
	_check(years >= 8 and years <= 12, "and take about ten years to mature (%d)" % years)
	city.woodland.grow_timber()
	_check(TownWoodland.get_timber(city.local_map[tile.y][tile.x]) == EconomyBalance.TIMBER_PER_TILE, "never more than a mature tile")

func test_gathering_cuts_trees_near_home() -> void:
	var city: City = town()
	var home: Vector2i = Vector2i(23, 16)
	var timber: int = city.woodland.get_standing_timber()
	_check(city.woodland.take_timber_near(home, HouseholdEconomy.WOODS_REACH, 5) == 5 and city.woodland.get_standing_timber() == timber - 5, "gathering takes its wood from the trees")
	var bare: City = town([])
	_check(bare.woodland.take_timber_near(home, HouseholdEconomy.WOODS_REACH, 5) == 0, "and gets nothing where there are none")

func test_felling_thins_hunting_woods() -> void:
	var city: City = town()
	var lodge: Building = give(city, city.households[1], "hunter", Vector2i(16, 22))
	var woodcutter: Building = give(city, city.households[0], "woodcutter", Vector2i(13, 22))
	var before: float = city.land.count_share("woods", lodge.tile, lodge.size, [])
	for _day in range(Calendar.DAYS_PER_YEAR * 2):
		city.apply_building_production(woodcutter)
	city.logistics.mark_layout_changed()
	var after: float = city.land.count_share("woods", lodge.tile, lodge.size, [])
	_check(after < before and city.woodland.felled_count > 0, "felling still thins the woods a lodge hunts (%.0f to %.0f wooded tiles)" % [before, after])

func test_a_woodcutter_without_trees_reconsiders() -> void:
	var city: City = town([Rect2i(25, 14, 2, 1)])
	var household: Household = city.households[0]
	var woodcutter: Building = give(city, household, "woodcutter", CUTTER)
	for _day in range(200):
		city.apply_building_production(woodcutter)
	_check(city.woodland.get_felling_factor(woodcutter) == 0.0, "the two tiles of trees are cut out")
	var triggers: Array[String] = OccupationReview.get_triggers(city, household, woodcutter)
	_check(triggers.has(OccupationReview.TIMBER) and OccupationReview.is_urgent(triggers), "its family has reason to look at its work again, at once: %s" % str(triggers))

func test_timber_is_saved() -> void:
	var city: City = town()
	var woodcutter: Building = give(city, city.households[0], "woodcutter", CUTTER)
	for _day in range(40):
		city.apply_building_production(woodcutter)
	var timber: int = city.woodland.get_standing_timber()
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.woodland.get_standing_timber() == timber and timber < WOODS.get_area() * EconomyBalance.TIMBER_PER_TILE, "the timber left survives a save (%d, %d)" % [timber, restored.woodland.get_standing_timber()])

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
