extends SceneTree

# Families reconsidering their work (docs/OCCUPATION_RECONSIDERATION.md): only a change in the
# family's own circumstances starts a review, never a priority alone; staying carries what the
# family would give up; a family on proper work against its calling stays, one on hand work goes;
# the old workplace stands empty and open; the change is a memory, not a lesson; once a year, one
# family a month; the old calling swap no longer runs where families lead; saves.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_no_reason_no_review()
	test_hand_work_against_calling_changes()
	test_proper_work_weighs_heavily()
	test_priority_weighs_in_but_does_not_start()
	test_reasons_must_last_a_season()
	test_once_a_year_and_one_a_month()
	test_calling_swap_retired_where_families_lead()
	test_off_and_saved()
	if failure_count > 0:
		push_error("Occupation review validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Occupation review validation passed.")
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

# A town where families lead, with plenty in store (nothing short), and every family set to a calling
# with a neutral temperament.
func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	# These rules are not about skill: families work at full pace and weigh no skill, so how much food
	# the town grows (FamilyInitiative.get_food_ratio, from work actually done) is what the test sets up.
	city.set_meta("economy_no_proficiency_effects", true)
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

# Months pass for the review alone (no ticking): `days` later, and the month's pass runs.
func month(city: City, days: int = 30) -> void:
	city.construction.day += days
	OccupationReview.advance_month(city)

func reasons(terms: Array) -> String:
	return " | ".join(terms.map(func(t: Dictionary) -> String: return "%s %.2f" % [t["reason"], float(t["weight"])]))

# The other families farm, so the town grows enough food.
func busy_everyone_else(city: City, except: Household) -> void:
	var x: int = 2
	for other: Household in city.households:
		if other != except and FamilyInitiative.get_holding(city, other) == null:
			give(city, other, "farm", Vector2i(x, 30))
			x += 6

# 1. A family whose circumstances have not changed does not look again, however long it works.
func test_no_reason_no_review() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	give(city, family, "farm", Vector2i(28, 4))
	busy_everyone_else(city, family)
	for i in range(24):
		month(city)
	_check(city.influence.work_reviews == 0 and family.work_review_day < 0, "a family of the soil on its farm never reconsiders (%d reviews)" % city.influence.work_reviews)

# 2. A family on hand work against its calling reconsiders after two seasons, opens work of its
# calling, and leaves its old work only once that is built. The old workplace stays, empty and
# open; the change is remembered with its reasons, and teaches nothing by itself.
func test_hand_work_against_calling_changes() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	family.set_values(profile("forge_bench"))
	for axis: String in HouseholdCharacter.AXES:
		family.personality[axis] = 0
	var garden: Building = give(city, family, "forager_garden", Vector2i(28, 4))
	busy_everyone_else(city, family)
	month(city)
	_check(city.influence.work_reviews == 0, "not in its first two seasons")
	for i in range(6):
		month(city)
	_check(city.influence.work_reviews == 1 and city.influence.work_changes == 1, "then it reconsiders and changes (%d reviews, %d changes): %s" % [city.influence.work_reviews, city.influence.work_changes, family.work_review_note])
	_check(family.work_review_note.contains("calling") and family.work_review_note.contains("tool mender"), "for its calling, in its own words: %s" % family.work_review_note)
	var project: ConstructionProject = null
	for p: ConstructionProject in city.construction.projects:
		if p.claimant_household_id == family.id:
			project = p
	_check(project != null and project.building_type == "tool_mender", "it opens hand work of its calling")
	_check(garden.assigned_household_id == family.id, "and keeps its garden while that is built")
	var before: int = city.buildings.size()
	var evidence: Dictionary = family.value_evidence.duplicate()
	ConstructionTest.run_until_built(city, project, 240)
	var mender: Building = FamilyInitiative.get_holding(city, family)
	_check(mender != null and mender.type == "tool_mender", "then it works the tool mender's")
	_check(city.buildings.size() == before + 1 and city.buildings.has(garden), "the garden still stands")
	_check(garden.assigned_household_id != family.id and not garden.auto_assignment_blocked, "empty of it, open to the next family free to work")
	_check(family.work_history == ["food", "tools"], "its history: %s" % str(family.work_history))
	_check(family.memories.any(func(m: Dictionary) -> bool: return m["kind"] == "changed_work" and (m["lessons"] as Array).is_empty()), "the change is a memory without a lesson")
	_check(family.value_evidence == evidence, "and moves no value")

# 3. Leaving proper work is weighed heavily but never forbidden. A family of the forge on a proper
# farm, where another family already makes tools, stays: what it has built up and its farm left
# idle outweigh its calling. Where no one makes tools and the town has food to spare, its calling
# and the town's need together outweigh them, and it leaves.
func test_proper_work_weighs_heavily() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	family.set_values(profile("forge_bench"))
	for axis: String in HouseholdCharacter.AXES:
		family.personality[axis] = 0
	var farm: Building = give(city, family, "farm", Vector2i(28, 4))
	busy_everyone_else(city, family)
	family.work_building_id = farm.id
	family.work_since = city.construction.day
	city.construction.day += 400
	var staying: Dictionary = OccupationReview.get_stay_desire(city, family, farm)
	_check(reasons(staying["terms"]).contains("it has built up its farm") and reasons(staying["terms"]).contains("would stand idle"), "staying weighs its farm and the farm left idle: %s" % reasons(staying["terms"]))
	var alone: Dictionary = OccupationReview.weigh(city, family, farm)
	_check(bool(alone["change"]) and alone["activity"] == "toolmaker", "with no one making tools and food to spare, it leaves even a proper farm (margin %.2f): %s" % [float(alone["margin"]), reasons(alone["alternative_terms"])])
	var other: Household = city.households[1]
	for building: Building in city.buildings:
		if building.assigned_household_id == other.id:
			building.unassign_worker(false)
	give(city, other, "toolmaker", Vector2i(40, 4))
	var kept: Dictionary = OccupationReview.weigh(city, family, farm)
	_check(not bool(kept["change"]), "where another family already makes tools, it stays (margin %.2f)" % float(kept["margin"]))

# 4. A priority never starts a review; once a family reconsiders for its own reasons, the priority's
# ask is one of its reasons, for the work asked for and for staying at work the priority wants.
func test_priority_weighs_in_but_does_not_start() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	give(city, family, "forager_garden", Vector2i(28, 4))
	busy_everyone_else(city, family)
	city.influence.set_priority(CommunityPriority.INVESTMENT)
	for i in range(14):
		month(city)
	_check(city.influence.work_reviews == 0, "a family of the soil on food work does not reconsider because the gathering asks for tools")
	var forge: Household = city.households[1]
	forge.set_values(profile("forge_bench"))
	var holding: Building = FamilyInitiative.get_holding(city, forge)
	forge.work_building_id = holding.id
	forge.work_since = 0
	var decision: Dictionary = OccupationReview.weigh(city, forge, holding)
	_check(float(decision["appeal"]) > 0.0 and decision["activity"] == "toolmaker", "for a family that reconsiders, the ask for tools is a reason to change: %s" % reasons(decision["alternative_terms"]))
	city.influence.set_priority(CommunityPriority.FOOD)
	_check(float(OccupationReview.weigh(city, forge, holding)["stay_appeal"]) > 0.0, "and a priority for its own work is a reason to stay")

# 5. Short of tools, oversupplied, or far from home: each counts only once it has held a season.
func test_reasons_must_last_a_season() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	var farm: Building = give(city, family, "farm", Vector2i(28, 4))
	busy_everyone_else(city, family)
	city.construction.day = 400
	OccupationReview.advance_month(city)
	farm.maintenance_level = 25
	OccupationReview.update_strain(city, family, farm)
	_check(not OccupationReview.get_triggers(city, family, farm).has(OccupationReview.TOOLS), "a month short of tools is not yet a reason")
	OccupationReview.update_strain(city, family, farm)
	OccupationReview.update_strain(city, family, farm)
	_check(OccupationReview.get_triggers(city, family, farm).has(OccupationReview.TOOLS), "a season is")
	farm.maintenance_level = 100
	OccupationReview.update_strain(city, family, farm)
	_check(not OccupationReview.get_triggers(city, family, farm).has(OccupationReview.TOOLS), "and it lapses when tools return")
	family.work_start_travel = 0.05
	_check(OccupationReview.TRAVEL_TRIGGER_RISE > 0.0 and not OccupationReview.is_far(city, family, farm) or city.logistics.get_travel_share(farm) >= 0.25, "a farm near home is not far")

# 6. A family reconsiders at most once a year, and the town sees at most one family change its work
# a month; the others wait their turn.
func test_once_a_year_and_one_a_month() -> void:
	var city: City = town()
	# The second family's other work here was woodcutting, against its calling, beside 500 wood the
	# town never burns; since S5b that plenty weighs against it. This test is about the monthly limit,
	# so it keeps the judgment it was written for.
	city.set_meta("no_wood_plenty", true)
	var forge: Array[Household] = []
	var x: int = 4
	for household: Household in city.households:
		if forge.size() < 2:
			household.set_values(profile("forge_bench"))
			for axis: String in HouseholdCharacter.AXES:
				household.personality[axis] = 0
			forge.append(household)
		give(city, household, "forager_garden" if forge.has(household) else "farm", Vector2i(x, 4) if forge.has(household) else Vector2i(x, 30))
		x += 6
	for i in range(7):
		month(city)
	_check(city.influence.work_changes == 1 and city.influence.work_deferred >= 1, "two families ready to change: one this month, the other waits (%d changes, %d deferred)" % [city.influence.work_changes, city.influence.work_deferred])
	month(city)
	_check(city.influence.work_changes == 2, "and changes the next month")
	var day: int = forge[0].work_review_day
	_check(not OccupationReview.is_due(city, forge[0]), "a family that has reconsidered waits a year")
	var stayer: Household = city.households[2]
	stayer.work_review_day = city.construction.day
	city.construction.day = day + OccupationReview.REVIEW_INTERVAL_DAYS - 1
	_check(not OccupationReview.is_due(city, stayer), "not even one day early")

# 7. Where families lead, the instant calling swap no longer runs; the classic rules keep it.
func test_calling_swap_retired_where_families_lead() -> void:
	var city: City = town()
	var forge: Household = city.households[0]
	forge.set_values(profile("forge_bench"))
	var farm: Building = give(city, forge, "farm", Vector2i(28, 4))
	var soil: Household = city.households[1]
	var toolmaker: Building = give(city, soil, "toolmaker", Vector2i(40, 4))
	forge.ambition = FamilyAmbitions.CALLING
	FamilyAmbitions.advance_month(city)
	_check(farm.assigned_household_id == forge.id and toolmaker.assigned_household_id == soil.id, "no instant swap where families lead")
	city.influence.enabled = false
	forge.ambition = FamilyAmbitions.CALLING
	FamilyAmbitions.advance_month(city)
	_check(toolmaker.assigned_household_id == forge.id, "the classic rules still swap")

# 8. Off (for comparison), nothing is reviewed; the review's fields are saved with the town.
func test_off_and_saved() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	family.set_values(profile("forge_bench"))
	give(city, family, "forager_garden", Vector2i(28, 4))
	busy_everyone_else(city, family)
	city.influence.reconsider_work = false
	for i in range(10):
		month(city)
	_check(city.influence.work_reviews == 0, "with reconsideration off, no family reconsiders")
	city.influence.reconsider_work = true
	month(city)
	family.work_history = ["food", "tools"]
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	var again: Household = loaded.get_household_by_id(family.id)
	_check(loaded.influence.reconsider_work and loaded.influence.work_reviews == city.influence.work_reviews, "the town's reviews are saved")
	_check(again.work_since == family.work_since and again.work_history == family.work_history and again.work_review_day == family.work_review_day, "and each family's")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
