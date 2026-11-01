extends SceneTree

# Autonomous occupations and essential shortages (docs/AUTONOMOUS_OCCUPATIONS.md): every trade with a
# hand-work stage is a family's own choice, opened as hand work and improved later, where the land
# allows it; and a family sees an essential shortage coming and looks at its work again early, the
# danger weighed against its calling, skill and investment rather than deciding for it.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_every_trade_with_hand_work_is_a_choice()
	test_water_family_fishes_by_hand()
	test_no_water_no_fishing()
	test_loom_family_herds()
	test_hand_work_improves_into_proper()
	test_shortage_seen_coming()
	test_shortage_competes_but_does_not_decide()
	test_shortage_starts_an_early_review()
	test_survival_before_prosperity()
	test_temperament_and_desperation()
	test_narrow_shortage_by_default()
	test_hungry_family_looks_again()
	test_food_judged_by_work_done()
	test_holding_worth_what_it_yields()
	test_hunger_counted_once()
	test_warning_no_land()
	test_warning_failing_livelihood()
	if failure_count > 0:
		push_error("Autonomous occupations validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Autonomous occupations validation passed.")
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

func set_calling(household: Household, calling: String) -> void:
	household.set_values(profile(calling))
	for axis: String in HouseholdCharacter.AXES:
		household.personality[axis] = 0
	household.value_strengths.clear()
	for value_id: String in HouseholdCharacter.get_held_values(household):
		household.value_strengths[value_id] = 0

# Families lead, plenty in store, every family of the soil with a neutral temperament. The test map
# has farmland along the top, woods down the right edge and a lake in the bottom left.
func town(map: Array = []) -> City:
	var city: City = ConstructionTest.make_city()
	if not map.is_empty():
		city.local_map = map
	city.influence.enabled = true
	# Skill is not what these rules are about: families work at full pace and weigh no skill, so the
	# food the town grows (from work actually done) is what each test sets up.
	city.set_meta("economy_no_proficiency_effects", true)
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	for household: Household in city.households:
		set_calling(household, "soil")
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

# Every family but one at work on a farm, out of the way.
func busy_everyone_else(city: City, except: Household) -> void:
	var x: int = 14
	for other: Household in city.households:
		if other != except and FamilyInitiative.get_holding(city, other) == null:
			give(city, other, "farm", Vector2i(x, 4))
			x += 4

func reasons(terms: Array) -> String:
	return " | ".join(terms.map(func(t: Dictionary) -> String: return "%s %.2f" % [t["reason"], float(t["weight"])]))

func has_reason(terms: Array, text: String) -> bool:
	return terms.any(func(t: Dictionary) -> bool: return str(t["reason"]).contains(text))

func own_project(city: City, household: Household) -> ConstructionProject:
	for project: ConstructionProject in city.construction.projects:
		if project.requester_household_id == household.id and not project.is_home():
			return project
	return null

# 1. The trades families choose come from the hand-work stages; the comparison can keep the first three.
func test_every_trade_with_hand_work_is_a_choice() -> void:
	var city: City = town()
	var occupations: Array[String] = FamilyInitiative.get_occupations(city)
	_check(occupations == (["farm", "woodcutter", "toolmaker", "fisher", "hunter", "herder"] as Array[String]), "every trade with a hand-work stage is a choice, the first three first: %s" % str(occupations))
	for pair: Array in [["fish_weir", "fisher"], ["snare_line", "hunter"], ["grazing_pen", "herder"]]:
		_check(BuildingTiers.get_upgrade_type(pair[0]) == pair[1] and BuildingTiers.get_hand_work_type(pair[1]) == pair[0], "%s improves into %s" % pair)
		_check(EconomyBalance.get_build_cost(pair[0]).is_empty(), "%s needs no materials, like all hand work" % pair[0])
		_check(city.construction.get_size(pair[0]) == city.construction.get_size(pair[1]), "%s stands on its proper workplace's footprint" % pair[0])
	_check(FamilyInitiative.get_activity("fish_weir") == "food" and FamilyInitiative.get_activity("snare_line") == "food" and FamilyInitiative.get_activity("grazing_pen") == "wool", "each trade is weighed by the good it makes")
	_check(FamilyInitiative.get_activity("house") == "" and FamilyInitiative.get_activity("hut") == "", "a home is not a trade")
	city.set_meta("occupations_first_three", true)
	_check(FamilyInitiative.get_occupations(city) == (["farm", "woodcutter", "toolmaker"] as Array[String]), "the comparison can leave families only the first three")

# 2. A family of the water, free to choose with the lake in reach, takes up a fish weir, not a
# fisher's hut, beside the water.
func test_water_family_fishes_by_hand() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	set_calling(family, "water")
	busy_everyone_else(city, family)
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, family, "fisher")
	_check(bool(desire["available"]) and desire.has("site"), "fishing is open to it where water is in reach")
	_check(has_reason(desire["terms"], "family's calling"), "it weighs its calling: %s" % reasons(desire["terms"]))
	# A family with no calling for either is not drawn from fields to the woods: game yields less.
	var plain: Household = city.households[1]
	set_calling(plain, "hearth")
	var hunting: Dictionary = FamilyInitiative.get_work_desire(city, plain, "hunter")
	_check(has_reason(hunting["terms"], "yields less") or has_reason(hunting["terms"], "little game"), "hunting counts as yielding less than a field: %s" % reasons(hunting["terms"]))
	_check(float(hunting["score"]) < float(FamilyInitiative.get_work_desire(city, plain, "farm")["score"]), "so a family with no calling for either would rather farm")
	var project: ConstructionProject = FamilyInitiative.take_up_work(city, family)
	_check(project != null and project.building_type == "fish_weir", "it takes up a fish weir: %s" % family.initiative_note)
	if project != null:
		var beside: bool = false
		for tile: Vector2i in [project.tile + Vector2i.LEFT, project.tile + Vector2i.RIGHT, project.tile + Vector2i.UP, project.tile + Vector2i.DOWN]:
			if tile.x >= 0 and tile.y >= 0 and tile.y < city.local_map.size() and tile.x < (city.local_map[0] as Array).size():
				beside = beside or city.local_map[tile.y][tile.x]["type"] == "water"
		_check(beside, "beside the water")

# 3. Where no water lies, fishing is not weighed at all, whatever the family's calling.
func test_no_water_no_fishing() -> void:
	var map: Array = ConstructionTest.make_map()
	for row: Array in map:
		for tile: Dictionary in row:
			if tile["type"] == "water":
				tile["type"] = "ground"
				tile["water_kind"] = ""
	var city: City = town(map)
	var family: Household = city.households[0]
	set_calling(family, "water")
	busy_everyone_else(city, family)
	_check(not bool(FamilyInitiative.get_work_desire(city, family, "fisher")["available"]), "without water, fishing is no choice")
	var project: ConstructionProject = FamilyInitiative.take_up_work(city, family)
	_check(project != null and project.building_type != "fish_weir", "it takes up other work: %s" % family.initiative_note)

# 4. A family of the loom, in a town that grows plenty of food and goes without clothing, takes up a
# grazing pen for wool.
func test_loom_family_herds() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	set_calling(family, "loom")
	busy_everyone_else(city, family)
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, family, "herder")
	_check(has_reason(desire["terms"], "no one makes wool") and has_reason(desire["terms"], "goes without clothing"), "it sees no one makes wool and the town goes without clothing: %s" % reasons(desire["terms"]))
	var project: ConstructionProject = FamilyInitiative.take_up_work(city, family)
	_check(project != null and project.building_type == "grazing_pen", "it takes up a grazing pen: %s" % family.initiative_note)
	var other: Household = city.households[1]
	give(city, other, "grazing_pen", Vector2i(30, 20))
	var second: Dictionary = FamilyInitiative.get_work_desire(city, family, "herder")
	_check(not has_reason(second["terms"], "no one makes wool"), "once someone keeps a flock, that reason is gone")

# 5. Hand work improves into the proper workplace through the same pipeline as any other.
func test_hand_work_improves_into_proper() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	set_calling(family, "water")
	family.personality[HouseholdCharacter.RISK] = 2
	family.personality[HouseholdCharacter.AMBITION] = 2
	family.personality[HouseholdCharacter.DILIGENCE] = 2
	busy_everyone_else(city, family)
	var weir: Building = give(city, family, "fish_weir", Vector2i(12, 33))
	var project: ConstructionProject = FamilyInitiative.consider_improving(city, family, weir)
	_check(project != null and project.kind == ConstructionProject.KIND_UPGRADE and project.building_type == "fisher", "an eager family improves its fish weir into a fisher's hut: %s" % family.initiative_note)

# A town short of tools: every family on a proper farm, past its grace, and no one making tools.
func tool_short_town(tools: int) -> City:
	var city: City = town()
	busy_everyone_else(city, null)
	city.resources["tools"] = tools
	for building: Building in city.buildings:
		building.upkeep_grace_days = 0
	return city

# 6. How near the town is to running out: none while anyone makes tools; none for a good the town
# only goes without; the comparison can turn it off.
func test_shortage_seen_coming() -> void:
	var city: City = tool_short_town(3)
	var shortage: float = FamilyInitiative.get_shortage(city, "tools")
	_check(shortage > 0.5, "three tools for six farms' season of upkeep is a shortage coming (%.2f)" % shortage)
	_check(FamilyInitiative.get_shortage(tool_short_town(200), "tools") == 0.0, "two hundred tools are not")
	_check(FamilyInitiative.get_shortage(city, "wool") == 0.0, "going without clothing is not an essential shortage")
	for building: Building in city.buildings:
		building.upkeep_grace_days = 200
	_check(FamilyInitiative.get_shortage(city, "tools") == 0.0, "workplaces in their grace draw no upkeep this season")
	city = tool_short_town(3)
	var mender: Household = city.households[0]
	for building: Building in city.buildings:
		if building.assigned_household_id == mender.id:
			building.unassign_worker(false)
	give(city, mender, "tool_mender", Vector2i(40, 20))
	_check(FamilyInitiative.get_shortage(city, "tools") == 0.0, "once a family makes tools, the town is not without them")
	city = tool_short_town(3)
	city.set_meta("no_shortage_recognition", true)
	_check(FamilyInitiative.get_shortage(city, "tools") == 0.0, "the comparison can turn recognition off")

# 7. The danger competes with a family's reasons; it does not decide for it. A family with no calling
# for farming and little invested leaves for tools; a family of the soil on its own farm stays.
func test_shortage_competes_but_does_not_decide() -> void:
	var city: City = tool_short_town(0)
	var free: Household = city.households[0]
	set_calling(free, "hearth")
	var farm: Building = FamilyInitiative.get_holding(city, free)
	var decision: Dictionary = OccupationReview.weigh(city, free, farm)
	_check(bool(decision["change"]) and decision["activity"] == "toolmaker" and has_reason(decision["alternative_terms"], "run out of tools"), "a family with no calling for its farm leaves it for tools as they run out (margin %.2f): %s" % [float(decision["margin"]), reasons(decision["alternative_terms"])])
	city.set_meta("no_shortage_recognition", true)
	var blind: Dictionary = OccupationReview.weigh(city, free, farm)
	_check(not bool(blind["change"]), "without seeing the danger it would stay (margin %.2f)" % float(blind["margin"]))
	city.remove_meta("no_shortage_recognition")
	var soil: Household = city.households[1]
	var own: Building = FamilyInitiative.get_holding(city, soil)
	var kept: Dictionary = OccupationReview.weigh(city, soil, own)
	_check(not bool(kept["change"]), "a family of the soil on its own farm stays (margin %.2f): %s" % [float(kept["margin"]), reasons(kept["stay_terms"])])
	city.remove_meta("economy_no_proficiency_effects")
	HouseholdEconomy.ensure_seeded(city, soil)
	soil.proficiency["toolmaker"] = HouseholdEconomy.ESTABLISHED
	var skilled: Dictionary = FamilyInitiative.get_work_desire(city, soil, "toolmaker")
	_check(has_reason(skilled["terms"], "it knows the work"), "a family that knows toolmaking still counts it: %s" % reasons(skilled["terms"]))

# 8. The danger starts a review early, after a month at the work rather than two seasons; a priority
# alone, without the danger, never does.
func test_shortage_starts_an_early_review() -> void:
	var city: City = tool_short_town(0)
	var family: Household = city.households[0]
	set_calling(family, "hearth")
	var farm: Building = FamilyInitiative.get_holding(city, family)
	city.construction.day = 400
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		household.work_building_id = holding.id
		household.work_since = city.construction.day - (40 if household == family else 10)
	_check(not OccupationReview.is_due(city, family), "forty days at its work is too soon for an ordinary review")
	_check(OccupationReview.get_triggers(city, family, farm).has(OccupationReview.SHORTAGE) and OccupationReview.is_due_in_danger(city, family), "but not when tools are running out")
	OccupationReview.advance_month(city)
	_check(city.influence.work_reviews == 1 and int(city.influence.work_triggers.get(OccupationReview.SHORTAGE, 0)) == 1, "it looks at its work again, and only it (reviews %d)" % city.influence.work_reviews)
	_check(own_project(city, family) != null and own_project(city, family).building_type == "tool_mender", "and takes up mending tools by hand: %s" % family.work_review_note)
	var calm: City = tool_short_town(200)
	calm.set_meta("work_change_limit", 0)
	calm.influence.set_priority(CommunityPriority.INVESTMENT)
	calm.construction.day = 400
	for household: Household in calm.households:
		var holding: Building = FamilyInitiative.get_holding(calm, household)
		household.work_building_id = holding.id
		household.work_since = calm.construction.day - 40
	OccupationReview.advance_month(calm)
	_check(calm.influence.work_reviews == 0, "the gathering asking for tools starts no review while tools are plentiful")

# A town about to go hungry: little in store, and every other family cutting wood.
func hungry_town(food: int) -> City:
	var city: City = town()
	city.resources["food"] = food
	var x: int = 14
	for other: Household in city.households.slice(1):
		give(city, other, "woodcutter", Vector2i(x, 20))
		x += 4
	return city

# 9. A calling pursues prosperity; hunger makes survival come first. A family of the loom in a town
# about to go hungry would rather grow food than keep sheep; in a fed town it keeps sheep. No rule
# forbids either.
func test_survival_before_prosperity() -> void:
	var city: City = hungry_town(0)
	var loom: Household = city.households[0]
	set_calling(loom, "loom")
	var hardship: Dictionary = FamilyInitiative.get_hardship(city, loom)
	_check(float(hardship["level"]) > 0.8, "with nothing in store and no one growing food, hunger is near (%.2f)" % float(hardship["level"]))
	var farm: Dictionary = FamilyInitiative.get_work_desire(city, loom, "farm")
	var herd: Dictionary = FamilyInitiative.get_work_desire(city, loom, "herder")
	_check(has_reason(farm["terms"], "go hungry") and has_reason(herd["terms"], "survival comes first"), "it weighs the coming hunger, and sets its calling aside for now: farm %s / herd %s" % [reasons(farm["terms"]), reasons(herd["terms"])])
	_check(float(farm["score"]) > float(herd["score"]), "it would rather grow food (farm %.2f, herd %.2f)" % [float(farm["score"]), float(herd["score"])])
	_check(bool(herd["available"]) and float(herd["score"]) > -INF, "herding stays a choice it can make")
	var fed: City = town()
	var fed_loom: Household = fed.households[0]
	set_calling(fed_loom, "loom")
	busy_everyone_else(fed, fed_loom)
	_check(float(FamilyInitiative.get_hardship(fed, fed_loom)["level"]) == 0.0, "a town with years of food in store faces no hunger")
	_check(float(FamilyInitiative.get_work_desire(fed, fed_loom, "herder")["score"]) > float(FamilyInitiative.get_work_desire(fed, fed_loom, "farm")["score"]), "in a fed town it follows its calling")
	city.set_meta("no_survival_awareness", true)
	_check(float(FamilyInitiative.get_hardship(city, loom)["level"]) == 0.0, "the comparison can turn survival awareness off")

# 10. A cautious family weighs coming hunger more than a daring one; a family already going hungry
# weighs it fully; and food work that would bring in little here relieves less.
func test_temperament_and_desperation() -> void:
	var city: City = hungry_town(600)
	var family: Household = city.households[0]
	family.personality[HouseholdCharacter.RISK] = -2
	var cautious: float = float(FamilyInitiative.get_hardship(city, family)["level"])
	family.personality[HouseholdCharacter.RISK] = 2
	family.personality[HouseholdCharacter.AMBITION] = 2
	var daring: float = float(FamilyInitiative.get_hardship(city, family)["level"])
	_check(cautious > daring and daring > 0.0, "the cautious weigh coming hunger more (%.2f) than the daring and ambitious (%.2f)" % [cautious, daring])
	family.short_days_this_month = 10
	var desperate: Dictionary = FamilyInitiative.get_hardship(city, family)
	_check(float(desperate["level"]) == 1.0 and str(desperate["reason"]).contains("itself is going hungry"), "a family going hungry itself weighs it fully, whatever its temperament")
	var garden: float = FamilyInitiative.get_food_relief(city, family, "farm", 1.0)
	var poor_snares: float = FamilyInitiative.get_food_relief(city, family, "hunter", 0.3)
	_check(garden > poor_snares, "snares in thin woods would feed fewer than a garden (%.2f against %.2f)" % [poor_snares, garden])

# 11. Shortage recognition is narrow by default: a good no one makes, not a deficit in one the town
# does make (owner, 2026-11-01).
func test_narrow_shortage_by_default() -> void:
	var city: City = hungry_town(0)
	give(city, city.households[0], "forager_garden", Vector2i(28, 4))
	_check(FamilyInitiative.get_shortage(city, "food") == 0.0, "a town growing some food, if too little, is not in an essential shortage")
	city.set_meta("shortage_counts_deficits", true)
	_check(FamilyInitiative.get_shortage(city, "food") > 0.0, "the broad version, kept for comparison, counts the deficit")

# 12. A family that has itself gone hungry for two months looks at its work again, without waiting
# for its tenure or its year; with its hunger weighed, it leaves snares in felled woods for a garden.
func test_hungry_family_looks_again() -> void:
	var city: City = town()
	city.resources["food"] = 0
	var family: Household = city.households[0]
	set_calling(family, "forest")
	var snares: Building = give(city, family, "snare_line", Vector2i(57, 2))
	busy_everyone_else(city, family)
	city.construction.day = 400
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		household.work_building_id = holding.id
		household.work_since = city.construction.day - 60
	_check(not OccupationReview.is_due(city, family), "sixty days at its work is too soon for an ordinary review")
	family.short_days_this_month = 12
	OccupationReview.update_strain(city, family, snares)
	_check(not OccupationReview.get_triggers(city, family, snares).has(OccupationReview.HUNGER), "one hungry month is not yet a reason")
	OccupationReview.update_strain(city, family, snares)
	_check(OccupationReview.get_triggers(city, family, snares).has(OccupationReview.HUNGER) and OccupationReview.is_due_in_danger(city, family), "two are, and do not wait")
	var decision: Dictionary = OccupationReview.weigh(city, family, snares)
	_check(has_reason(decision["stay_terms"], "survival comes first") or has_reason(decision["alternative_terms"], "going hungry"), "its own hunger is weighed: %s / %s" % [reasons(decision["alternative_terms"]), reasons(decision["stay_terms"])])
	city.set_meta("no_survival_awareness", true)
	family.work_strain.clear()
	OccupationReview.update_strain(city, family, snares)
	OccupationReview.update_strain(city, family, snares)
	_check(not OccupationReview.get_triggers(city, family, snares).has(OccupationReview.HUNGER), "without survival awareness, hunger starts no review")

# 13. The town's food is judged by work actually done: an empty farm feeds no one.
func test_food_judged_by_work_done() -> void:
	var city: City = town()
	var farmer: Household = city.households[0]
	give(city, farmer, "farm", Vector2i(14, 4))
	var empty: Building = Building.new(-1, "farm", Vector2i(20, 4), city.construction.get_size("farm"))
	city.add_building(empty)
	empty.unassign_worker(false)
	var worked: float = FamilyInitiative.get_working_output(city, "food")
	_check(worked > 0.0 and worked <= city.get_base_building_output_amount("farm") + 0.01, "only the worked farm counts (%.2f a day)" % worked)
	var ratio: float = FamilyInitiative.get_food_ratio(city)
	city.set_meta("food_ratio_counts_empty", true)
	var old_ratio: float = FamilyInitiative.get_food_ratio(city)
	_check(old_ratio > ratio * 1.9, "the old judgement counted the empty farm as well (%.2f against %.2f)" % [old_ratio, ratio])

# 14. What a family has built is worth what its land still yields; its years and convictions count
# in full, and it may still stay.
func test_holding_worth_what_it_yields() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	set_calling(family, "forest")
	busy_everyone_else(city, family)
	var lodge: Building = give(city, family, "hunter", Vector2i(30, 20))
	var worth: float = OccupationReview.get_holding_worth(city, lodge)
	_check(worth < 0.75, "a lodge far from the woods is not the holding it would be in them (%.2f)" % worth)
	var staying: Dictionary = OccupationReview.get_stay_desire(city, family, lodge)
	_check(has_reason(staying["terms"], "yields little now") and has_reason(staying["terms"], "family's calling"), "it weighs a failing holding for what it yields, its calling in full: %s" % reasons(staying["terms"]))
	var built: float = 0.0
	for term: Dictionary in staying["terms"]:
		if str(term["reason"]).begins_with("it has built up"):
			built = float(term["weight"])
	_check(absf(built - OccupationReview.BUILT_UP_PROPER * worth) < 0.01, "what it built counts for its yield (%.2f)" % built)
	city.set_meta("stay_value_ignores_yield", true)
	_check(OccupationReview.get_holding_worth(city, lodge) == 1.0, "the comparison can count it in full")
	var field: Building = FamilyInitiative.get_holding(city, city.households[1])
	city.remove_meta("stay_value_ignores_yield")
	_check(OccupationReview.get_holding_worth(city, field) == 1.0, "a farm is judged by its land elsewhere, not here")

# 15. A town about to go hungry is one reason, looking ahead, not two: the survival term, without the
# older "grows less food than it eats" beside it (owner, 2026-11-01).
func test_hunger_counted_once() -> void:
	var city: City = hungry_town(0)
	var family: Household = city.households[0]
	var farm: Dictionary = FamilyInitiative.get_work_desire(city, family, "farm")
	_check(has_reason(farm["terms"], "go hungry") and not has_reason(farm["terms"], "grows less food than it eats"), "hunger is weighed once, looking ahead: %s" % reasons(farm["terms"]))
	city.set_meta("hunger_counted_twice", true)
	var twice: Dictionary = FamilyInitiative.get_work_desire(city, family, "farm")
	_check(has_reason(twice["terms"], "go hungry") and has_reason(twice["terms"], "grows less food than it eats"), "the comparison can count it twice, as before")
	city.remove_meta("hunger_counted_twice")
	# A full store puts off a town growing less than it eats, but does not hide it.
	var stored: City = town()
	stored.resources["food"] = 5000
	var family_two: Household = stored.households[0]
	_check(float(FamilyInitiative.get_hardship(stored, family_two)["level"]) > 0.5 and str(FamilyInitiative.get_hardship(stored, family_two)["reason"]).contains("grows less food than it eats"), "years of food in store, nothing growing: still a danger, by what the town grows")
	busy_everyone_else(stored, family_two)
	var desire: Dictionary = FamilyInitiative.get_work_desire(stored, family_two, "farm")
	_check(not has_reason(desire["terms"], "go hungry") and not has_reason(desire["terms"], "grows less food"), "fields for most families and years in store: no hunger weighed: %s" % reasons(desire["terms"]))

func card_titled(city: City, title: String) -> Dictionary:
	for card: Dictionary in SidebarOverviewPage.get_attention(city):
		if str(card["title"]) == title:
			return card
	return {}

# 16. Families who chose work and found no land for it are shown to the player, with the land tools
# that make such land; and only while it is so.
func test_warning_no_land() -> void:
	var map: Array = ConstructionTest.make_map()
	for row: Array in map:
		for tile: Dictionary in row:
			tile["is_fertile"] = false
	var city: City = town(map)
	var family: Household = city.households[0]
	busy_everyone_else(city, family)
	_check(card_titled(city, "Families find no land for their work").is_empty(), "no warning before any family is blocked")
	FamilyInitiative.note_blocked(city, family, "forager_garden")
	family.short_days_this_month = 4
	var card: Dictionary = card_titled(city, "Families find no land for their work")
	_check(not card.is_empty() and str(card["lines"]).contains("fertile land") and str(card["lines"]).contains("going hungry"), "a blocked, hungry family is a warning that says why: %s" % str(card.get("lines", [])))
	_check(not card.is_empty() and (card["buttons"] as Array).any(func(b: Dictionary) -> bool: return b["action"]["tool"] == TownFarmland.TILL), "with the tool to till land")
	city.construction.day += SidebarOverviewPage.NO_LAND_DAYS + 1
	_check(card_titled(city, "Families find no land for their work").is_empty(), "and it passes when the family has not been blocked for two months")

# 17. Hunting whose woods are being felled is shown to the player, measured against the best the
# woods gave; a lodge that was always thin is not a failing livelihood.
func test_warning_failing_livelihood() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	busy_everyone_else(city, family)
	var lodge: Building = give(city, family, "hunter", Vector2i(30, 20))
	lodge.peak_land_yield = 0.3
	_check(card_titled(city, "Hunting grounds are being felled").is_empty(), "a lodge that never had much woods is not failing")
	lodge.peak_land_yield = 1.0
	var card: Dictionary = card_titled(city, "Hunting grounds are being felled")
	_check(not card.is_empty() and str(card["lines"]).contains("of the game they did"), "a lodge whose woods are going is: %s" % str(card.get("lines", [])))
	_check(not card.is_empty() and (card["buttons"] as Array).any(func(b: Dictionary) -> bool: return b["action"]["tool"] == TownWoodland.CLEAR), "with the tool to steer felling elsewhere")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
