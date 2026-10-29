extends SceneTree

# Family influence prototype (docs/FAMILY_INFLUENCE_PROTOTYPE.md): families take up and improve
# their own work for reasons they can give, the player influences them by encouragement and the
# stores rule, protected reserves keep the tools for upkeep, and proper workplaces short of tools
# work by hand instead of standing idle. Off by default: the town then plays as before.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_off_by_default()
	test_founders_take_up_work()
	test_temperaments_decide_differently()
	test_prediction_and_encouragement()
	test_desire_and_ability_are_separate()
	test_protected_reserve()
	test_neighbours_example()
	test_hand_method_fallback()
	test_work_ground()
	test_saved_with_the_town()

	if failure_count > 0:
		push_error("Family initiative validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Family initiative validation passed.")
	quit()

# A profile with nothing in it that moves a work decision, apart from what `overrides` sets.
func profile(overrides: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var preset: Dictionary = {
		CultureValues.CATEGORY_CALLING: ["soil"],
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
	for category: String in overrides.keys():
		preset[category] = overrides[category]
	return CultureValues.make_random_profile(rng, preset)

# About seven weeks of food: enough to live on, not enough to feel secure (FamilyInitiative weighs
# the risk of waiting against the risk of acting).
func enabled_city() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.resources["food"] = 600
	return city

# A family on a forager's garden on the farmland.
func garden_family(city: City, index: int, values: Dictionary, origin: Vector2i = Vector2i(28, 4)) -> Household:
	var household: Household = city.households[index]
	household.set_values(profile(values))
	city.add_building(Building.new(-1, "forager_garden", origin, city.construction.get_size("forager_garden")), household)
	return household

func count_household_workplace_projects(city: City) -> int:
	return city.construction.projects.filter(func(p: ConstructionProject) -> bool: return p.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and not p.is_home()).size()

func test_off_by_default() -> void:
	var city: City = ConstructionTest.make_city()
	_check(not city.influence.enabled, "influence is off unless enabled")
	ConstructionTest.run_days(city, 10)
	_check(count_household_workplace_projects(city) == 0 and city.buildings.filter(func(b: Building) -> bool: return b.is_production_building()).is_empty(), "with influence off, families open no workplaces of their own")

func test_founders_take_up_work() -> void:
	var city: City = enabled_city()
	var callings: Array = [["soil"], ["forest"], ["forge_bench"], ["soil"], ["forest"], ["hearth"]]
	for i in range(city.households.size()):
		city.households[i].set_values(profile({CultureValues.CATEGORY_CALLING: callings[i]}))
	ConstructionTest.run_days(city, 1)
	var forest_family: Household = city.households[1]
	_check(forest_family.initiative_note.contains("calling"), "the family of the forest says its work is its calling: %s" % forest_family.initiative_note)
	ConstructionTest.run_days(city, 29)
	var activities: Dictionary = {}
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		var planned: bool = city.construction.projects.any(func(p: ConstructionProject) -> bool: return p.claimant_household_id == household.id and not p.is_home())
		_check(holding != null or planned, "every founder has taken up work within a month (family %d: %s)" % [household.id, household.initiative_note])
		_check(household.initiative_note != "", "every founder can say why it chose its work")
		if holding != null:
			activities[FamilyInitiative.get_activity(holding.type)] = true
	_check(activities.size() >= 2, "families of different callings take up different work: %s" % str(activities.keys()))
	var forest_holding: Building = FamilyInitiative.get_holding(city, forest_family)
	_check(forest_holding != null and FamilyInitiative.get_activity(forest_holding.type) == TownInfluence.ACTIVITY_WOOD, "the family of the forest cuts wood: %s" % forest_family.initiative_note)
	_check(city.influence.workplaces_opened >= city.households.size(), "the town counts the workplaces families opened")

# The owner's example: given the same call, a daring family improves at once, while a cautious,
# traditional one keeps to hand work, and each says why.
func test_temperaments_decide_differently() -> void:
	var city: City = enabled_city()
	var daring: Household = garden_family(city, 0, {CultureValues.CATEGORY_CHANGE_RISK: ["daring"], CultureValues.CATEGORY_AUTHORITY: ["reformist"]})
	var careful: Household = garden_family(city, 1, {CultureValues.CATEGORY_CHANGE_RISK: ["cautious"], CultureValues.CATEGORY_AUTHORITY: ["traditionalist"]}, Vector2i(40, 4))
	FamilyInitiative.advance(city)
	var daring_garden: Building = FamilyInitiative.get_holding(city, daring)
	var careful_garden: Building = FamilyInitiative.get_holding(city, careful)
	_check(city.construction.get_upgrade_project(daring_garden.id) != null, "the daring family improves its garden: %s" % daring.initiative_note)
	_check(daring.initiative_note.contains("daring"), "and says it is daring: %s" % daring.initiative_note)
	_check(city.construction.get_upgrade_project(careful_garden.id) == null, "the cautious, traditional family keeps to hand work: %s" % careful.initiative_note)
	_check(careful.initiative_note.contains("old ways"), "and says it keeps to the old ways: %s" % careful.initiative_note)
	_check(daring.improve_decision_day >= 0 and careful.improve_decision_day < 0, "the day a family first decides to improve is recorded")

func test_prediction_and_encouragement() -> void:
	var city: City = enabled_city()
	var plain: Household = garden_family(city, 0, {CultureValues.CATEGORY_AUTHORITY: ["deferential"]})
	var proud: Household = garden_family(city, 1, {CultureValues.CATEGORY_CHANGE_RISK: ["cautious"], CultureValues.CATEGORY_AUTHORITY: ["traditionalist"]}, Vector2i(40, 4))
	var before: Dictionary = FamilyInitiative.predict_improvement(city, plain, false)
	var after: Dictionary = FamilyInitiative.predict_improvement(city, plain, true)
	_check(before["outlook"] == FamilyInitiative.OUTLOOK_UNCERTAIN, "a family with nothing for or against is uncertain: %s" % str(before))
	_check(after["outlook"] == FamilyInitiative.OUTLOOK_LIKELY, "asked by the gathering, a deferential family is likely to improve: %s" % str(after))
	_check((after["reasons"] as Array).any(func(r: String) -> bool: return r.contains("heeds the gathering")), "and the prediction says why: %s" % str(after["reasons"]))
	_check(not city.influence.is_encouraged(TownInfluence.ACTIVITY_IMPROVE), "predicting changes nothing")
	var proud_after: Dictionary = FamilyInitiative.predict_improvement(city, proud, true)
	_check(proud_after["outlook"] != FamilyInitiative.OUTLOOK_LIKELY, "a cautious, traditional family is not won over by being asked alone: %s" % str(proud_after))
	# The unknown is bounded: a family predicted likely always does it.
	city.influence.set_encouraged(TownInfluence.ACTIVITY_IMPROVE, true)
	FamilyInitiative.advance(city)
	_check(city.construction.get_upgrade_project(FamilyInitiative.get_holding(city, plain).id) != null, "a family predicted likely improves: %s" % plain.initiative_note)

# A family can want an improvement the stores rule will not fund; it says which.
func test_desire_and_ability_are_separate() -> void:
	var city: City = enabled_city()
	var daring: Household = garden_family(city, 0, {CultureValues.CATEGORY_CHANGE_RISK: ["daring"]})
	city.influence.store_rule = TownInfluence.RULE_PRIORITIES
	city.influence.set_encouraged(TownInfluence.ACTIVITY_WOOD, true)
	FamilyInitiative.advance(city)
	var garden: Building = FamilyInitiative.get_holding(city, daring)
	_check(city.construction.get_upgrade_project(garden.id) == null, "with the stores kept for the community's priorities, an improvement nobody asked for waits")
	_check(daring.initiative_note.begins_with("Wants to improve") and daring.initiative_note.contains("priorities"), "the family says it wants to but the stores go elsewhere: %s" % daring.initiative_note)
	_check(city.influence.held_back_by_stores == 1, "the town counts wishes held back by the stores")
	city.influence.set_encouraged(TownInfluence.ACTIVITY_IMPROVE, true)
	city.construction.day += FamilyInitiative.INTERVAL_DAYS
	FamilyInitiative.advance(city)
	_check(city.construction.get_upgrade_project(garden.id) != null, "once better work is a priority, the stores fund it")
	# Tier 0 needs no materials: the rule never keeps a family from taking up hand work.
	var free_family: Household = city.households[2]
	free_family.set_values(profile({CultureValues.CATEGORY_CALLING: ["forge_bench"], CultureValues.CATEGORY_CHANGE_RISK: ["cautious"]}))
	city.construction.day += FamilyInitiative.INTERVAL_DAYS
	FamilyInitiative.advance(city)
	_check(city.construction.projects.any(func(p: ConstructionProject) -> bool: return p.claimant_household_id == free_family.id and not p.is_home()), "a family takes up hand work whatever the stores rule: %s" % free_family.initiative_note)

func test_protected_reserve() -> void:
	var city: City = enabled_city()
	var daring: Household = garden_family(city, 0, {CultureValues.CATEGORY_CHANGE_RISK: ["daring"], CultureValues.CATEGORY_WORK_ETHIC: ["industrious"]})
	var reserve: Dictionary = city.influence.get_protected_reserve()
	city.resources["tools"] = int(reserve["tools"])
	FamilyInitiative.advance(city)
	_check(city.construction.get_upgrade_project(FamilyInitiative.get_holding(city, daring).id) == null, "families never spend the tools kept for upkeep")
	_check(daring.initiative_note.contains("kept back"), "and say so: %s" % daring.initiative_note)
	var farm: Building = Building.new(-1, "farm", Vector2i(10, 4), city.construction.get_size("farm"))
	city.add_building(farm, city.households[1])
	_check(int(city.influence.get_protected_reserve()["tools"]) >= int(reserve["tools"]), "the reserve grows with the proper workplaces it keeps in tools")

# A cautious family is moved by its neighbours' improved work paying, and put off when it stands
# short of tools.
func test_neighbours_example() -> void:
	var city: City = enabled_city()
	var careful: Household = garden_family(city, 0, {CultureValues.CATEGORY_CHANGE_RISK: ["cautious"]})
	var neighbour: Household = city.households[1]
	careful.parent_household_id = neighbour.id
	var alone: float = float(FamilyInitiative.get_improve_desire(city, careful, "farm")["score"])
	var farm: Building = Building.new(-1, "farm", Vector2i(40, 4), city.construction.get_size("farm"))
	city.add_building(farm, neighbour)
	var paying: Dictionary = FamilyInitiative.get_improve_desire(city, careful, "farm")
	_check(float(paying["score"]) > alone, "a neighbour's paying farm makes improving more attractive (%.2f against %.2f)" % [float(paying["score"]), alone])
	_check(FamilyInitiative.get_reasons(paying["terms"], true).has("its neighbours' improved work is paying"), "and it is a reason the family gives")
	farm.maintenance_level = 0
	var idle: float = float(FamilyInitiative.get_improve_desire(city, careful, "farm")["score"])
	_check(idle < alone, "a neighbour's farm short of tools makes it warier than seeing nothing (%.2f against %.2f)" % [idle, alone])

func test_hand_method_fallback() -> void:
	var city: City = ConstructionTest.make_city(false)
	var farm: Building = Building.new(-1, "farm", Vector2i.ZERO, Vector2i(3, 3))
	city.add_building(farm, city.households[0])
	farm.maintenance_level = 0
	_check(not farm.can_produce(), "today's rules: a farm without tools stands idle")
	city.set_hand_method_fallback(true)
	_check(farm.can_produce() and farm.is_working_by_hand(), "with the fallback, it works by hand")
	var made: int = 0
	for _day in range(30):
		made += city.get_current_building_output_amount(farm)
	_check(farm.type == "farm", "the building stays a farm")
	_check(made > 0 and made < int(EconomyBalance.FARM_FOOD_PER_DAY * 30.0 * 0.6), "at about hand work's pace: %d food in 30 days" % made)
	farm.maintenance_level = 100
	_check(not farm.is_working_by_hand(), "with tools again, it works as a farm")
	var later: Building = Building.new(-1, "woodcutter", Vector2i(10, 0), Vector2i(2, 2))
	city.add_building(later)
	_check(later.works_by_hand_without_tools, "buildings finished later follow the town's rule")

func test_work_ground() -> void:
	var city: City = enabled_city()
	var household: Household = city.households[0]
	household.set_values(profile({}))
	var anywhere: Vector2i = FamilyInitiative.choose_site(city, household, "forager_garden")
	_check(anywhere.x >= 0, "with no work ground marked, a family finds a site anywhere the land allows")
	city.influence.mark_work_ground(Vector2i(46, 0), Vector2i(54, 8))
	_check(city.influence.work_ground_tiles == 81, "a 9x9 block is marked, %d tiles" % city.influence.work_ground_tiles)
	var marked: Vector2i = FamilyInitiative.choose_site(city, household, "forager_garden")
	_check(marked.x >= 46 and marked.y <= 8, "with work ground marked, families open work only there: %s (was %s)" % [str(marked), str(anywhere)])
	city.influence.mark_work_ground(Vector2i(46, 0), Vector2i(54, 8))
	_check(city.influence.work_ground_tiles == 0, "marking the same block again unmarks it")

func test_saved_with_the_town() -> void:
	var city: City = enabled_city()
	city.set_hand_method_fallback(true)
	city.influence.set_encouraged(TownInfluence.ACTIVITY_TOOLS, true)
	city.influence.store_rule = TownInfluence.RULE_PRIORITIES
	city.influence.mark_work_ground(Vector2i(46, 0), Vector2i(48, 2))
	ConstructionTest.run_days(city, 8)
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	_check(loaded.influence.enabled and loaded.hand_method_fallback, "a loaded town keeps the prototype on")
	_check(loaded.influence.is_encouraged(TownInfluence.ACTIVITY_TOOLS) and loaded.influence.store_rule == TownInfluence.RULE_PRIORITIES, "and what the community asks for, and the stores rule")
	_check(loaded.influence.work_ground_tiles == 9 and loaded.influence.get_work_ground().size() == 9, "and the work ground")
	_check(loaded.households[0].initiative_note == city.households[0].initiative_note and loaded.households[0].initiative_note != "", "and what each family decided")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
