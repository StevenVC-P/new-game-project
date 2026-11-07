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
	test_families_take_up_stone_work()
	test_food_security_and_own_demand_weigh_in()
	test_stone_no_one_uses()
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

# Sprint S4c (owner D6): stone work is a trade families choose, starting as a stone pit by hand on a
# deposit; it is open only where there is stone, judged by the stone underfoot, drawn by a calling
# and by building that waits for stone, and a pit cuts from the deposit like a quarry.
func test_families_take_up_stone_work() -> void:
	var city: City = town()
	city.influence.enabled = true
	var household: Household = city.households[0]
	var profile: Dictionary = household.values.duplicate(true)
	profile[CultureValues.CATEGORY_CALLING] = ["stone"]
	household.set_values(profile)
	_check(FamilyInitiative.get_occupations(city).has("quarry"), "stone work is among the trades families choose")
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, "quarry")
	_check(bool(desire.get("available", true)) and desire.has("site"), "a family can take it up where there is stone: %s" % str(desire.get("site", "no site")))
	if desire.has("site"):
		var site: Vector2i = desire["site"]
		_check(TownDeposits.get_footprint_factor(city.local_map, site, Vector2i(3, 3)) > 0.5, "and sets its pit on good stone (%s)" % str(site))
	_check(str(FamilyInitiative.get_reasons(desire["terms"], true)).contains("calling"), "drawn by its calling: %s" % str(FamilyInitiative.get_reasons(desire["terms"], true)))
	var bare: City = ConstructionTest.make_city()
	bare.local_map = HuntingTest.open_map([])
	bare.influence.enabled = true
	bare.households[0].set_values(profile)
	_check(not bool(FamilyInitiative.get_work_desire(bare, bare.households[0], "quarry").get("available", true)), "with no stone on the map it can't")
	# A fed town (survival first: with no food work, wants beyond food fade entirely).
	for i in range(2, 5):
		city.add_building(Building.new(-1, "farm", Vector2i(6 * i, 36), Vector2i(3, 3)), city.households[i])
	city.influence.build_material = EconomyBalance.MATERIAL_STONE
	city.construction.request_building("toolmaker", Vector2i(10, 30))
	var wanted: Dictionary = FamilyInitiative.get_work_desire(city, city.households[1], "quarry")
	_check(str(FamilyInitiative.get_reasons(wanted["terms"], true)).contains("building waits for"), "building that waits for stone draws families to stone work: %s" % str(FamilyInitiative.get_reasons(wanted["terms"], true)))
	var pit: Building = Building.new(-1, "stone_pit", Vector2i(31, 10), Vector2i(3, 3))
	city.add_building(pit, household)
	var left: int = TownDeposits.get_stone_left(city, pit)
	for _day in range(60):
		city.apply_building_production(pit)
	var cut: int = left - TownDeposits.get_stone_left(city, pit)
	_check(cut > 0 and cut < 60 * 2, "a pit cuts from the deposit by hand, slower than a quarry (%d in 60 days)" % cut)

# Owner 2026-11-03: food security is a weighed reason against new deposit trades, as strong as the
# family's temperament and values make it (never a bar); a family that means to build its own home of
# stone has its own reason to quarry, so new industries start without the player.
func test_food_security_and_own_demand_weigh_in() -> void:
	var city: City = town()
	city.influence.enabled = true
	city.resources["food"] = 0
	_check(FamilyInitiative.get_food_insecurity(city) > 0.9, "a town with no food is far from secure (%.2f)" % FamilyInitiative.get_food_insecurity(city))
	var household: Household = city.households[0]
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, "quarry")
	_check(str(FamilyInitiative.get_reasons(desire["terms"], false, 6)).contains("secure yet"), "and that weighs against stone work: %s" % str(FamilyInitiative.get_reasons(desire["terms"], false, 6)))
	var plain: float = FamilyInitiative.get_survival_mindedness(household)
	var profile: Dictionary = household.values.duplicate(true)
	profile[CultureValues.CATEGORY_CRAFT_LEARNING] = ["keepers_of_craft"]
	household.set_values(profile)
	_check(FamilyInitiative.get_survival_mindedness(household) < plain, "a family keeping to its craft weighs it less (%.2f against %.2f)" % [FamilyInitiative.get_survival_mindedness(household), plain])
	city.resources["food"] = 100000
	_check(FamilyInitiative.get_food_insecurity(city) == 0.0, "a well-stocked town is secure")
	# A housed family in a hut that wants a better home and would build it of stone.
	var builder: Household = city.households[1]
	var stone_profile: Dictionary = builder.values.duplicate(true)
	stone_profile[CultureValues.CATEGORY_WORK_ETHIC] = ["perfectionist"]
	stone_profile[CultureValues.CATEGORY_CRAFT_LEARNING] = ["keepers_of_craft"]
	builder.set_values(stone_profile)
	var choice: Dictionary = MaterialChoice.choose(city, builder, "house", true)
	_check((choice["options"] as Array).any(func(o: Dictionary) -> bool: return str(o["material"]) == EconomyBalance.MATERIAL_STONE), "with supply set aside, stone is among what a family would build of")
	if str(choice["material"]) == EconomyBalance.MATERIAL_STONE:
		builder.housing_status = Household.RESIDENCE_TEMPORARY
		var wants: Dictionary = FamilyInitiative.get_work_desire(city, builder, "quarry")
		_check(str(FamilyInitiative.get_reasons(wants["terms"], true, 6)).contains("its own home of"), "a family meaning to build its own stone home has its own reason to quarry: %s" % str(FamilyInitiative.get_reasons(wants["terms"], true, 6)))

# Sprint S4 review (owner 2026-11-03, kept 2026-11-07): stone no need, building or workshop uses,
# with a pile already in store, counts against more stone work and tells a quarrying family it may
# reconsider; once building waits for stone, it counts for the work again.
func test_stone_no_one_uses() -> void:
	var city: City = town()
	city.influence.enabled = true
	var stone: String = FamilyInitiative.get_activity("quarry")
	city.resources[stone] = FamilyInitiative.NO_USE_STOCK - 1
	_check(not FamilyInitiative.has_no_use(city, stone), "a little stone in store isn't yet a pile no one uses")
	city.resources[stone] = FamilyInitiative.NO_USE_STOCK * 3
	_check(FamilyInitiative.has_no_use(city, stone), "a pile of stone with no use is one")
	var household: Household = city.households[0]
	if not FamilyInitiative.means_to_build_with(city, household, stone):
		var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, "quarry")
		_check(str(FamilyInitiative.get_reasons(desire["terms"], false, 6)).contains("than it uses"), "and it counts against stone work: %s" % str(FamilyInitiative.get_reasons(desire["terms"], false, 6)))
	var pit: Building = quarry(city, Vector2i(31, 10), household)
	_check(OccupationReview.is_oversupplied(city, pit), "a quarrying family sees its work oversupplied")
	_check(not FamilyInitiative.has_no_use(city, "food") and not FamilyInitiative.has_no_use(city, "wood"), "food and wood are never piles no one uses")
	city.influence.build_material = EconomyBalance.MATERIAL_STONE
	for i in range(6):
		if int(city.construction.get_committed_materials().get(stone, 0)) <= FamilyInitiative.NO_USE_STOCK:
			city.construction.request_building("toolmaker", Vector2i(4 + 6 * i, 30))
	city.resources[stone] = FamilyInitiative.NO_USE_STOCK
	var committed: int = int(city.construction.get_committed_materials().get(stone, 0))
	_check(committed > FamilyInitiative.NO_USE_STOCK and not FamilyInitiative.has_no_use(city, stone), "building that waits for more stone than the store holds gives it a use again (%d waiting)" % committed)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
