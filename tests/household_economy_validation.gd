extends SceneTree

# Household self-sufficiency and proficiency (docs/HOUSEHOLD_SELF_SUFFICIENCY.md): with larders empty
# eating is what it always was; food is never made or eaten twice; a family above its larder's target
# eats its own, below it keeps its harvest, and draws on it only when the store falls short; who went
# short is each family's own, and so is the hardship; secondary work comes out of the holding's day;
# a garden needs ground near home; mending stands in for a store tool; gathered wood goes to the
# family's own building first; proficiency is learned by practice, fades to nothing unused, carries
# to related work and to children; families decide their time for their own reasons, a step a month;
# saves.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_empty_larders_eat_as_before()
	test_food_is_never_made_or_eaten_twice()
	test_shortage_is_each_familys_own()
	test_secondary_work_comes_out_of_the_holding()
	test_garden_needs_ground_near_home()
	test_mending_and_gathered_wood()
	test_proficiency_learned_forgotten_and_passed_on()
	test_starting_knowledge()
	test_families_decide_their_time()
	test_larder_decisions_and_gifts()
	test_saved()
	if failure_count > 0:
		push_error("Household economy validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Household economy validation passed.")
	quit()

func profile(calling: String) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var preset: Dictionary = {
		CultureValues.CATEGORY_CALLING: [calling],
		CultureValues.CATEGORY_WORK_ETHIC: ["steady"],
		CultureValues.CATEGORY_KIN: ["fathers_line"],
		CultureValues.CATEGORY_WEALTH: ["sharing"],
		CultureValues.CATEGORY_TRADE_COIN: ["fair_dealers"],
		CultureValues.CATEGORY_AUTHORITY: ["lawful"],
		CultureValues.CATEGORY_CHANGE_RISK: ["rooted"],
		CultureValues.CATEGORY_CRAFT_LEARNING: ["hands_on"],
		CultureValues.CATEGORY_CONFLICT: ["pragmatic"],
		CultureValues.CATEGORY_FAITH: ["worldly"],
		CultureValues.CATEGORY_COMMUNITY: ["welcoming"],
		CultureValues.CATEGORY_HOME_PLACE: ["monument_makers"],
	}
	return CultureValues.make_random_profile(rng, preset)

# A town where families lead, with plenty in store, every family of the soil, with a neutral
# temperament and no strong convictions (as in occupation_review_validation.gd).
func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	for household: Household in city.households:
		household.set_values(profile("soil"))
		for axis: String in HouseholdCharacter.AXES:
			household.personality[axis] = 0
		household.value_strengths.clear()
		for value_id: String in HouseholdCharacter.get_held_values(household):
			household.value_strengths[value_id] = 0
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func total_food(city: City) -> float:
	var total: float = float(int(city.resources["food"]))
	for household: Household in city.households:
		total += household.larder
	return total

# 1. With every larder empty, a day's eating takes from the store exactly what it did before, and a
# short store leaves every family short, as the town flag always did.
func test_empty_larders_eat_as_before() -> void:
	var on: City = town()
	var off: City = town()
	off.influence.self_sufficiency = false
	for city: City in [on, off]:
		city.resources["food"] = 3
		city.consume_food()
	_check(int(on.resources["food"]) == int(off.resources["food"]) and on.resources["food_shortage"] == off.resources["food_shortage"], "empty larders: the store and the flag as before (%d / %d)" % [int(on.resources["food"]), int(off.resources["food"])])
	_check(on.households.all(func(h: Household) -> bool: return h.short_today), "every family short when the store is")
	var fed: City = town()
	fed.resources["food"] = 1000
	var before: int = int(fed.resources["food"])
	fed.consume_food()
	_check(before - int(fed.resources["food"]) == int(fed.resources["food_consumption_rate"]), "a full store pays the whole demand")

# 2. Food is conserved: what leaves the store and the larders in a day is what the families eat.
func test_food_is_never_made_or_eaten_twice() -> void:
	var city: City = town()
	var keeper: Household = city.households[0]
	var eater: Household = city.households[1]
	keeper.larder = 20.0
	keeper.larder_target_days = 30
	eater.larder = 20.0
	eater.larder_target_days = 0
	city.resources["food"] = 1000
	var before: float = total_food(city)
	city.consume_food()
	var eaten: float = before - total_food(city)
	var needed: float = 0.0
	for household: Household in city.households:
		needed += HouseholdEconomy.get_daily_need(household)
	_check(eaten >= needed - 0.001 and eaten < needed + 1.0, "eaten %.2f for a need of %.2f (rounded up as the town always was)" % [eaten, needed])
	_check(is_equal_approx(keeper.larder, 20.0), "below its target, a family keeps its harvest and eats from the store (%.2f)" % keeper.larder)
	_check(is_equal_approx(eater.larder, 20.0 - HouseholdEconomy.get_daily_need(eater)), "above it, it eats its own first (%.2f)" % eater.larder)
	# The store falls short: the keeper's larder covers it; a family without one goes short.
	city.resources["food"] = 2
	before = total_food(city)
	city.consume_food()
	_check(not keeper.short_today and keeper.larder < 20.0, "short store: the larder covers its family (%.2f left)" % keeper.larder)
	var bare: Household = city.households[2]
	_check(bare.short_today and bare.short_days_this_month == 1, "a family with nothing put by goes short")
	_check(before - total_food(city) <= needed + 1.0, "and nothing is eaten twice")

# 3. Hardship from a shortage falls on the families who went short, not on one fed from its larder.
func test_shortage_is_each_familys_own() -> void:
	var city: City = town()
	var keeper: Household = city.households[0]
	keeper.larder = 500.0
	keeper.larder_target_days = 90
	city.resources["food"] = 0
	for i in range(15):
		city.consume_food()
		city.resources["food"] = 0
	city.resources["shortage_days_this_month"] = 15
	_check(keeper.short_days_this_month == 0 and city.households[1].short_days_this_month == 15, "short days are each family's (%d / %d)" % [keeper.short_days_this_month, city.households[1].short_days_this_month])
	_check(HouseholdMigration.get_monthly_hardship_points(city, keeper) == 0 and HouseholdMigration.get_monthly_hardship_points(city, city.households[1]) >= HouseholdMigration.HARDSHIP_SHORTAGE_POINTS, "and so is the hardship")
	city.influence.self_sufficiency = false
	_check(HouseholdMigration.get_monthly_hardship_points(city, keeper) >= HouseholdMigration.HARDSHIP_SHORTAGE_POINTS, "with the system off, the town's shortage is everyone's")
	_check(city.skips_work_today(city.households[1].id) == city.should_skip_for_food_shortage(), "off: hunger as the town rule")

# 4. Secondary work comes straight out of the holding's day: the holding's share falls by what the
# garden takes, and its output with it.
func test_secondary_work_comes_out_of_the_holding() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	give(city, family, "house", Vector2i(20, 4))
	var shop: Building = give(city, family, "toolmaker", Vector2i(30, 20))
	HouseholdEconomy.plan_day(city)
	var whole: float = city.get_work_time_factor(shop)
	family.secondary_activity = "food"
	family.secondary_share = 0.2
	family.garden_land = 1.0
	HouseholdEconomy.plan_day(city)
	var less: float = city.get_work_time_factor(shop)
	_check(is_equal_approx(whole - less, 0.2), "a fifth of its day to a garden is a fifth less at the toolmaker (%.2f -> %.2f)" % [whole, less])
	family.secondary_share = 0.3
	city.construction.spare_time_today[family.id] = 0.2
	city.influence._secondary_today.clear()
	HouseholdEconomy.plan_day(city)
	city.construction.spare_time_today[family.id] = 0.2
	var share: float = float(city.influence._secondary_today.get(family.id, 0.0))
	_check(share <= 1.0 - city.logistics.get_travel_share(shop) - 0.2 + 0.0001 and city.get_work_time_factor(shop) >= 0.0, "building and secondary work never take more than the day (%.2f)" % share)
	# The garden: a hand-work day's food, for its share, by the season and the ground.
	family.secondary_share = 0.2
	city.construction.spare_time_today.clear()
	HouseholdEconomy.plan_day(city)
	var larder: float = family.larder
	HouseholdEconomy.produce_secondary(city, family, "food", 0.2)
	var expected: float = 0.2 * EconomyBalance.FARM_FOOD_PER_DAY * EconomyBalance.TIER0_OUTPUT_FRACTION * EconomyBalance.FARM_SEASON_YIELD[city.get_season_index()] * HouseholdEconomy.get_output_factor(city, family, "farm")
	_check(is_equal_approx(family.larder - larder, expected), "a garden yields hand work's rate for its share (%.3f, expected %.3f)" % [family.larder - larder, expected])
	_check(HouseholdEconomy.get_output_factor(city, family, "farm") < 1.0 or HouseholdEconomy.get_level(family, "farm") >= HouseholdEconomy.ESTABLISHED, "at its own proficiency")

# 5. A garden needs free ground within reach of home: fertile land in full, plain ground at half,
# none in the woods or without a home; neighbours never garden the same tile.
func test_garden_needs_ground_near_home() -> void:
	var city: City = town()
	var a: Household = city.households[0]
	var b: Household = city.households[1]
	var c: Household = city.households[2]
	var d: Household = city.households[3]
	give(city, a, "house", Vector2i(20, 4))
	give(city, b, "house", Vector2i(21, 4))
	give(city, c, "house", Vector2i(30, 25))
	give(city, d, "house", Vector2i(61, 20))
	var claimed: Dictionary = {}
	_check(is_equal_approx(HouseholdEconomy.get_garden_land(city, a, claimed, true), 1.0), "on farmland, a full garden")
	_check(is_equal_approx(HouseholdEconomy.get_garden_land(city, b, claimed, true), 1.0), "a neighbour finds its own ground")
	var tiles: Dictionary = {}
	for at: Vector2i in claimed.keys():
		tiles[claimed[at]] = int(tiles.get(claimed[at], 0)) + 1
	_check(claimed.size() == 2 * HouseholdEconomy.GARDEN_TILES and int(tiles[a.id]) == HouseholdEconomy.GARDEN_TILES, "no tile is gardened twice")
	_check(is_equal_approx(HouseholdEconomy.get_garden_land(city, c, claimed, false), HouseholdEconomy.PLAIN_GROUND_YIELD), "plain ground, half a garden")
	_check(HouseholdEconomy.get_garden_land(city, d, claimed, false) == 0.0, "in the woods, none")
	_check(HouseholdEconomy.get_garden_land(city, city.households[4], claimed, false) == 0.0, "no home, no garden")
	_check(HouseholdEconomy.get_woods_land(city, d) == 1.0 and HouseholdEconomy.get_woods_land(city, a) == 0.0, "wood is gathered only where trees are near")

# 6. Mending the family did takes the place of a tool from the store; wood it gathered goes to its
# own building first, then to the store.
func test_mending_and_gathered_wood() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	var farm: Building = give(city, family, "farm", Vector2i(28, 4))
	farm.upkeep_grace_days = 0
	farm.maintenance_level = 75
	farm.maintenance_timer = farm.get_maintenance_interval() - 1
	family.mending = 1.2
	var tools: int = int(city.resources["tools"])
	city.update_building_maintenance(farm)
	_check(int(city.resources["tools"]) == tools and farm.maintenance_level == 100 and is_equal_approx(family.mending, 0.2), "mending kept its farm without a store tool")
	farm.maintenance_timer = farm.get_maintenance_interval() - 1
	city.update_building_maintenance(farm)
	_check(int(city.resources["tools"]) == tools - 1, "without enough mending, the store's tool as before")
	var home: ConstructionProject = city.construction.request_building("house", Vector2i(20, 14), ConstructionProject.REQUESTED_BY_HOUSEHOLD, family.id, family.id)
	var wood: int = int(city.resources["wood"])
	HouseholdEconomy.deliver_wood(city, family)
	_check(int(home.materials_delivered.get("wood", 0)) == 1 and int(city.resources["wood"]) == wood, "gathered wood goes to its own home first")
	home.materials_delivered["wood"] = int(home.get_remaining_materials().get("wood", 0)) + 1
	HouseholdEconomy.deliver_wood(city, family)
	_check(int(city.resources["wood"]) == wood + 1, "then to the common store")

# 7. Proficiency grows with practice, more slowly near mastery; unused it fades, and in the end it is
# gone; returning finds what is left; practice teaches related work a little.
func test_proficiency_learned_forgotten_and_passed_on() -> void:
	var family: Household = Household.new(0)
	for day in range(360):
		HouseholdEconomy.learn(family, {"woodcutter": 1.0})
	var cutter: float = HouseholdEconomy.get_level(family, "woodcutter")
	var tools: float = HouseholdEconomy.get_level(family, "toolmaker")
	_check(cutter > 0.6 and cutter < 0.66, "a year's full practice: about two thirds (%.3f)" % cutter)
	_check(tools > 0.15 and tools < 0.25, "related work learned a little (%.3f)" % tools)
	for day in range(360):
		HouseholdEconomy.learn(family, {})
	var after_year: float = HouseholdEconomy.get_level(family, "woodcutter")
	_check(after_year < cutter and after_year > cutter * 0.7, "a year unused: it fades slowly (%.3f -> %.3f)" % [cutter, after_year])
	for day in range(360):
		HouseholdEconomy.learn(family, {"woodcutter": 1.0})
	_check(HouseholdEconomy.get_level(family, "woodcutter") > cutter, "returning starts from what was kept, not from nothing")
	for day in range(360 * 20):
		HouseholdEconomy.learn(family, {})
	_check(not family.proficiency.has("woodcutter") and not family.proficiency.has("toolmaker"), "unused for long enough, it is gone (%s)" % str(family.proficiency))

# 8. Founders know the trades of their calling and nothing else; a new family inherits part of what
# its parents still know; a town that was going before the system knows its own work.
func test_starting_knowledge() -> void:
	var city: City = town()
	var founder: Household = city.households[0]
	founder.proficiency_seeded = false
	HouseholdEconomy.ensure_seeded(city, founder)
	_check(is_equal_approx(HouseholdEconomy.get_level(founder, "farm"), HouseholdEconomy.ESTABLISHED) and HouseholdEconomy.get_level(founder, "toolmaker") == 0.0, "a family of the soil knows farming, not toolmaking (%s)" % str(founder.proficiency))
	_check(is_equal_approx(HouseholdEconomy.get_output_factor(city, founder, "toolmaker"), HouseholdEconomy.NOVICE_OUTPUT) and is_equal_approx(HouseholdEconomy.get_output_factor(city, founder, "farm"), 1.0), "a novice makes 60%, an established family all it ever did")
	founder.proficiency["farm"] = 0.3
	var child: Household = city.households[1]
	child.parent_household_id = founder.id
	child.proficiency.clear()
	child.proficiency_seeded = false
	HouseholdEconomy.ensure_seeded(city, child)
	_check(is_equal_approx(HouseholdEconomy.get_level(child, "farm"), 0.3 * HouseholdEconomy.INHERITED_SHARE), "a child's family inherits part of what its parents still know (%.3f)" % HouseholdEconomy.get_level(child, "farm"))
	var going: City = town()
	var smith: Household = going.households[0]
	give(going, smith, "toolmaker", Vector2i(30, 20))
	going.construction.day = 400
	HouseholdEconomy.plan_day(going)
	_check(HouseholdEconomy.get_level(smith, "toolmaker") >= HouseholdEconomy.ESTABLISHED, "in a town already going, a family knows the work it has been doing")

# 9. A family decides its own time: a cautious, self-reliant family in a hungry town takes up a
# garden a step at a time; a confident family that relies on the stores in a fed town keeps to its
# work; Take Pride in Your Work pulls toward a family's own work.
func test_families_decide_their_time() -> void:
	var city: City = town()
	var keen: Household = city.households[0]
	var easy: Household = city.households[1]
	give(city, keen, "house", Vector2i(20, 4))
	give(city, easy, "house", Vector2i(24, 4))
	give(city, keen, "toolmaker", Vector2i(30, 20))
	give(city, easy, "toolmaker", Vector2i(36, 20))
	keen.personality[HouseholdCharacter.RISK] = -2
	HouseholdCharacter.set_strength(keen, "self_reliant", 2)
	easy.personality[HouseholdCharacter.RISK] = 2
	HouseholdCharacter.set_strength(easy, "common_stores", 2)
	city.resources["food"] = 20
	city.construction.day = 200
	HouseholdEconomy.advance_month(city)
	var first: float = keen.secondary_share
	_check(keen.secondary_activity == "food" and first >= 0.1 - 0.0001, "the cautious family starts a garden, at a share of its own choosing (%.1f): %s" % [first, keen.economy_note])
	_check(keen.economy_note.contains("short of food") and keen.economy_note.contains("garden"), "and says why: %s" % keen.economy_note)
	city.construction.day += 30
	HouseholdEconomy.advance_month(city)
	_check(keen.secondary_share >= first - 0.0001 and keen.secondary_share <= first + 0.1 + 0.0001, "then at most a step a month, never a leap (%.1f -> %.1f)" % [first, keen.secondary_share])
	city.resources["food"] = 5000
	keen.larder = 1000.0
	for i in range(3):
		city.construction.day += 30
		HouseholdEconomy.advance_month(city)
	_check(easy.secondary_share == 0.0, "the confident family keeps to its work: %s" % easy.economy_note)
	_check(keen.secondary_share <= 0.1 + 0.0001, "once the town is fed and its larder full, the cautious family gives less time (%.1f): %s" % [keen.secondary_share, keen.economy_note])
	var holding: Building = FamilyInitiative.get_holding(city, keen)
	var plain: Dictionary = HouseholdEconomy.get_secondary_desire(city, keen, holding, "food", {})
	_check(not bool(HouseholdEconomy.get_secondary_desire(city, keen, holding, "tools", {})["possible"]), "a toolmaker does not take up mending as secondary work")
	city.social.enabled = true
	GuidingWisdom.choose(city, GuidingWisdom.PRIDE)
	var proud: Dictionary = HouseholdEconomy.get_secondary_desire(city, keen, holding, "food", {})
	_check(float(proud["score"]) < float(plain["score"]) and float(proud["pride"]) < 0.0, "Take Pride in Your Work pulls toward its own work (%.2f -> %.2f)" % [float(plain["score"]), float(proud["score"])])

# 10. How much food a family keeps back is its own decision: a cautious, thrifty family keeps more;
# one that holds to the common stores leaves it to the town. A gift moves food, not makes it.
func test_larder_decisions_and_gifts() -> void:
	var city: City = town()
	var keeper: Household = city.households[0]
	var sharer: Household = city.households[1]
	for household: Household in [keeper, sharer]:
		household.secondary_activity = "food"
		household.secondary_share = 0.1
	keeper.personality[HouseholdCharacter.RISK] = -2
	HouseholdCharacter.set_strength(keeper, "thrifty", 2)
	HouseholdCharacter.set_strength(sharer, "common_stores", 2)
	for i in range(3):
		HouseholdEconomy.decide_larder(city, keeper)
		HouseholdEconomy.decide_larder(city, sharer)
		city.construction.day += 30
	_check(keeper.larder_target_days >= 60 and sharer.larder_target_days == 0, "the thrifty family keeps back %d days, the other %d: %s" % [keeper.larder_target_days, sharer.larder_target_days, keeper.larder_note])
	keeper.larder = 100.0
	var before: float = keeper.larder + sharer.larder
	_check(HouseholdEconomy.can_give_food(keeper, sharer), "a full larder can give")
	HouseholdEconomy.give_food(city, keeper, sharer)
	_check(is_equal_approx(keeper.larder + sharer.larder, before) and sharer.larder > 0.0, "a gift moves food from one larder to another")

# 11. Saves: proficiency, time, larders and the town's counts survive a save; with the system off
# nothing of it runs.
func test_saved() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	family.proficiency = {"farm": 0.5, "toolmaker": 0.1}
	family.proficiency_seeded = true
	family.secondary_activity = "food"
	family.secondary_share = 0.2
	family.larder = 12.5
	family.larder_target_days = 30
	city.influence.economy_started_day = 1
	city.influence.mended_upkeep = 3
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	var again: Household = loaded.get_household_by_id(family.id)
	_check(again.proficiency == family.proficiency and again.secondary_share == 0.2 and again.larder == 12.5 and again.larder_target_days == 30, "each family's economy is saved")
	_check(loaded.influence.self_sufficiency and loaded.influence.economy_started_day == 1 and loaded.influence.mended_upkeep == 3, "and the town's")
	var off: City = town()
	off.influence.self_sufficiency = false
	ConstructionTest.run_days(off, 40)
	_check(off.households.all(func(h: Household) -> bool: return h.proficiency.is_empty() and h.secondary_share == 0.0), "off: no proficiency, no secondary work")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
