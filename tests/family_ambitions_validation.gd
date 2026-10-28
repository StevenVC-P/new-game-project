extends SceneTree

# Family ambitions (docs/FIRST_STAGE_LOOP.md, milestone 3): families want a proper home, work for
# their calling, and their trampled field fenced. A fulfilled ambition makes a family content:
# it endures more before leaving and draws newcomers. An ambition left waiting too long makes it
# endure a little less. Families fence their own field when the stores can spare the wood.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_a_proper_home()
	test_work_for_the_calling()
	test_swapping_work()
	test_families_fence_their_own_field()
	test_contentment_and_its_effects()
	test_waiting_too_long()

	if failure_count > 0:
		push_error("Family ambitions validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Family ambitions validation passed.")
	quit()

func water_family(city: City, household: Household) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	household.set_values(CultureValues.make_random_profile(rng, {CultureValues.CATEGORY_CALLING: ["water"]}))

func test_a_proper_home() -> void:
	var city: City = ConstructionTest.make_city()
	var household: Household = city.households[0]
	_check(household.housing_status != Household.RESIDENCE_HOUSED, "founders start in shelter")
	FamilyAmbitions.advance_month(city)
	_check(household.ambition == FamilyAmbitions.HOME, "a family in shelter wants a proper home, wanted '%s'" % household.ambition)
	_check(HouseholdHomeWorkLinkHelper.get_links(city, -1).size() > 0, "card helper still answers")
	city.add_building(Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE), household)
	FamilyAmbitions.advance_month(city)
	_check(household.fulfilled_ambitions == 1 and household.contentment == EconomyBalance.FULFILLED_CONTENTMENT, "a home of its own makes the family content")
	var card: Array[String] = HouseholdHomeWorkLinkHelper.get_links(city, city.buildings.size() - 1)
	_check(card.any(func(line: String) -> bool: return line.begins_with("Content:")), "the house card says the family is content: %s" % str(card))

func test_work_for_the_calling() -> void:
	var city: City = ConstructionTest.make_city()
	var household: Household = city.households[0]
	water_family(city, household)
	city.add_building(Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE), household)
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), household)
	FamilyAmbitions.advance_month(city)
	FamilyAmbitions.advance_month(city)
	_check(household.ambition == FamilyAmbitions.CALLING, "a family of the water working a field wants work for its calling, wanted '%s'" % household.ambition)
	_check(FamilyAmbitions.get_calling_work(household, city).has("fisher"), "a lake in reach makes a fisher's hut its wish")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).any(func(line: String) -> bool: return line.begins_with("Wishes:") and line.contains("fisher's hut")), "the town is told of the wish")
	var card: Array[String] = HouseholdHomeWorkLinkHelper.get_links(city, 0)
	_check(card.any(func(line: String) -> bool: return line.begins_with("Wants: work for its calling")), "the house card tells what it wants: %s" % str(card))
	# A fisher's hut stands empty: the family moves to it and leaves its field to others.
	var farm: Building = city.buildings[1]
	var fisher: Building = Building.new(-1, "fisher", Vector2i(12, 34), Vector2i.ONE)
	city.buildings.append(fisher)
	fisher.id = city.buildings.size() - 1
	FamilyAmbitions.advance_month(city)
	_check(fisher.assigned_household_id == household.id and farm.assigned_household_id != household.id, "the family takes the empty fisher's hut and leaves its field")
	var before: int = household.fulfilled_ambitions
	FamilyAmbitions.advance_month(city)
	_check(household.fulfilled_ambitions == before + 1 and household.ambition != FamilyAmbitions.CALLING, "fishing fulfils its calling")
	# Without water, a family of the water has no calling work to wish for.
	var dry: City = ConstructionTest.make_city()
	for row: Array in dry.local_map:
		for tile: Dictionary in row:
			if tile["type"] == "water":
				tile["type"] = "grass"
	water_family(dry, dry.households[0])
	_check(FamilyAmbitions.get_calling_work(dry.households[0], dry).is_empty(), "no water, no fisher's hut to wish for")

# A family of the water on a field and a family of the soil in a fisher's hut trade places; work
# the player assigned is never traded.
func test_swapping_work() -> void:
	var city: City = ConstructionTest.make_city()
	var fisher_family: Household = city.households[0]
	var farmer_family: Household = city.households[1]
	water_family(city, fisher_family)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	farmer_family.set_values(CultureValues.make_random_profile(rng, {CultureValues.CATEGORY_CALLING: ["soil"]}))
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), fisher_family)
	city.add_building(Building.new(-1, "fisher", Vector2i(12, 34), Vector2i.ONE), farmer_family)
	var farm: Building = city.buildings[0]
	var fisher: Building = city.buildings[1]
	fisher_family.ambition = FamilyAmbitions.CALLING
	FamilyAmbitions.take_calling_work(city, fisher_family)
	_check(fisher.assigned_household_id == fisher_family.id and farm.assigned_household_id == farmer_family.id, "the two families trade places")
	# The player's own assignment stays.
	var kept: City = ConstructionTest.make_city()
	water_family(kept, kept.households[0])
	kept.households[1].set_values(farmer_family.values)
	kept.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), kept.households[0])
	kept.add_building(Building.new(-1, "fisher", Vector2i(12, 34), Vector2i.ONE), kept.households[1])
	kept.buildings[0].assign_household(kept.households[0], Building.ASSIGNMENT_PLAYER)
	FamilyAmbitions.take_calling_work(kept, kept.households[0])
	_check(kept.buildings[0].assigned_household_id == kept.households[0].id, "a family keeps work the player gave it")

func test_families_fence_their_own_field() -> void:
	var city: City = ConstructionTest.make_city()
	var household: Household = city.households[0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	household.set_values(CultureValues.make_random_profile(rng, {CultureValues.CATEGORY_CALLING: ["soil"]}))
	city.add_building(Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE), household)
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), household)
	var field: Building = city.buildings[1]
	FamilyAmbitions.advance_month(city)
	_check(household.ambition == "", "an untrampled field needs no fence, wanted '%s'" % household.ambition)
	city.logistics.trampled_trips[field.id] = 2.0
	city.resources["wood"] = 3
	FamilyAmbitions.advance_month(city)
	_check(household.ambition == FamilyAmbitions.FENCE, "a family whose field is walked through wants it fenced, wanted '%s'" % household.ambition)
	_check(city.construction.get_fence_project(field.id) == null, "no fence while the stores cannot spare the wood")
	city.resources["wood"] = 100
	FamilyAmbitions.advance_month(city)
	var project: ConstructionProject = city.construction.get_fence_project(field.id)
	_check(project != null and project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD, "with wood to spare the family plans the fence itself")
	if project == null:
		return
	ConstructionTest.run_until_built(city, project, 60)
	_check(field.fenced, "the fence is built")
	FamilyAmbitions.advance_month(city)
	_check(household.fulfilled_ambitions == 1 and household.ambition != FamilyAmbitions.FENCE, "a fenced field fulfils the wish")

func test_contentment_and_its_effects() -> void:
	var city: City = ConstructionTest.make_city()
	var household: Household = city.households[0]
	var threshold: int = HouseholdMigration.get_departure_threshold(household)
	var attraction: int = HouseholdMigration.get_attractiveness(city)
	household.contentment = 2
	_check(HouseholdMigration.get_departure_threshold(household) == threshold + 2, "a content family endures more before leaving")
	_check(HouseholdMigration.get_attractiveness(city) >= mini(attraction + EconomyBalance.CONTENT_ATTRACTION, HouseholdMigration.MAX_ARRIVAL_CHANCE), "content families draw newcomers")
	for household_other: Household in city.households:
		household_other.contentment = 1
	_check(HouseholdMigration.get_attractiveness(city) <= mini(attraction + EconomyBalance.CONTENT_ATTRACTION_MAX, HouseholdMigration.MAX_ARRIVAL_CHANCE), "the draw of content families is capped")
	# Contentment fades while a family wants something (these founders want a home), and lasts
	# while it has all it wants.
	household.contentment = EconomyBalance.MAX_CONTENTMENT
	household.contentment_months = 0
	for _month in range(EconomyBalance.CONTENTMENT_FADE_MONTHS):
		FamilyAmbitions.advance_month(city)
	_check(household.contentment == EconomyBalance.MAX_CONTENTMENT - 1, "contentment fades a point a year while a wish waits, now %d" % household.contentment)
	var settled: City = ConstructionTest.make_city()
	var family: Household = settled.households[0]
	family.set_values({})
	settled.add_building(Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE), family)
	family.contentment = 2
	for _month in range(EconomyBalance.CONTENTMENT_FADE_MONTHS * 2):
		FamilyAmbitions.advance_month(settled)
	_check(family.contentment >= 2, "a family with all it wants stays content, now %d" % family.contentment)

func test_waiting_too_long() -> void:
	var city: City = ConstructionTest.make_city()
	var household: Household = city.households[0]
	water_family(city, household)
	city.add_building(Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE), household)
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), household)
	for _month in range(EconomyBalance.AMBITION_PATIENCE_MONTHS + 2):
		FamilyAmbitions.advance_month(city)
	_check(household.ambition == FamilyAmbitions.CALLING and FamilyAmbitions.get_waiting_strain(household) == EconomyBalance.AMBITION_WAITING_STRAIN, "a wish left waiting past its patience strains the family")
	var expected: int = CultureEffects.get_departure_threshold(household.values) + household.contentment - EconomyBalance.AMBITION_WAITING_STRAIN
	_check(HouseholdMigration.get_departure_threshold(household) == expected, "a strained family endures less before leaving")
	_check(HouseholdMigration.get_monthly_hardship_points(city, household) == 0, "waiting alone is no hardship: it drives no one out by itself")
	var shelter: City = ConstructionTest.make_city()
	for _month in range(EconomyBalance.AMBITION_PATIENCE_MONTHS + 2):
		FamilyAmbitions.advance_month(shelter)
	_check(FamilyAmbitions.get_waiting_strain(shelter.households[0]) == 0, "waiting for a home is already counted by rough housing")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
