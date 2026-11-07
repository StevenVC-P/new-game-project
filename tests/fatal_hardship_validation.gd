extends SceneTree

# Fatal hardship (sprint S3b, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md, HouseholdMortality; owner Q5):
# sustained, severe hunger or cold can kill, never one bad day or month; the risk grows with each
# further month and is gone when conditions lift; cold without a proper home is deadlier; the most
# vulnerable die first; a family with no adult left ends as an old couple's does; a death is in the
# chronicle and the family's note; the same town and month always roll the same; the counts survive
# a save; members stay consistent (invariant I14); a starving town loses no one in its first month.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_no_risk_until_sustained()
	test_risk_grows_and_lifts()
	test_rough_shelter_and_cold()
	test_the_vulnerable_first()
	test_a_family_ends()
	test_deaths_are_told()
	test_rolls_are_seeded()
	test_a_starving_town()
	test_counts_are_saved()
	test_switched_off()
	if failure_count > 0:
		push_error("Fatal hardship validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Fatal hardship validation passed.")
	quit()

func family(adults: int = 2, young: int = 1, older: int = 1, grown: int = 0) -> Household:
	var household: Household = Household.new(1)
	household.working_adults = adults
	household.young_children = young
	household.older_children = older
	household.adult_children = grown
	household.total_population = adults + young + older + grown
	household.housing_status = Household.RESIDENCE_HOUSED
	return household

func test_no_risk_until_sustained() -> void:
	var household: Household = family()
	_check(HouseholdMortality.get_risk(household, 1, 1.0) == 0.0, "one severe month risks no death")
	_check(HouseholdMortality.get_risk(household, 0, 1.0) == 0.0, "nor none")
	_check(HouseholdMortality.get_risk(household, EconomyBalance.HARDSHIP_SUSTAINED_MONTHS, 1.0) > 0.0, "%d months running do" % EconomyBalance.HARDSHIP_SUSTAINED_MONTHS)

func test_risk_grows_and_lifts() -> void:
	var household: Household = family()
	var two: float = HouseholdMortality.get_risk(household, 2, 1.0)
	var three: float = HouseholdMortality.get_risk(household, 3, 1.0)
	_check(three > two, "each further month is riskier (%.2f, %.2f)" % [two, three])
	_check(HouseholdMortality.get_risk(household, 40, 1.0) <= EconomyBalance.HARDSHIP_DEATH_CHANCE_MAX, "up to a cap")
	var city: City = ConstructionTest.make_city(false)
	var someone: Household = city.households[0]
	someone.short_days_this_month = 25
	someone.severe_hunger_months = 3
	someone.short_days_this_month = 2
	city.set_meta("no_hardship_deaths", true)
	HouseholdMortality.advance_month(city)
	_check(someone.severe_hunger_months == 0, "a month fed starts the count again")

func test_rough_shelter_and_cold() -> void:
	var household: Household = family()
	_check(HouseholdMortality.get_risk(household, 3, EconomyBalance.ROUGH_SHELTER_COLD_RISK) > HouseholdMortality.get_risk(household, 3, 1.0), "cold without a proper home is deadlier")

func test_the_vulnerable_first() -> void:
	var city: City = ConstructionTest.make_city(false)
	var household: Household = family(2, 1, 1, 1)
	city.households.append(household)
	HouseholdMortality.die(city, household, HouseholdMortality.HUNGER, 0)
	_check(household.young_children == 0 and household.older_children == 1 and household.total_population == 4, "a young child dies first")
	HouseholdMortality.die(city, household, HouseholdMortality.HUNGER, 0)
	_check(household.older_children == 0 and household.adult_children == 1, "then a child")
	var old: Household = family(2, 0, 0, 0)
	old.lifecycle_stage = Household.LIFECYCLE_OLD_COUPLE
	city.households.append(old)
	HouseholdMortality.die(city, old, HouseholdMortality.COLD, 0)
	_check(old.working_adults == 1 and old.total_population == 1 and old.labor_capacity == 1, "the old in an old couple are vulnerable too")

func test_a_family_ends() -> void:
	var city: City = ConstructionTest.make_city(false)
	var household: Household = city.households[0]
	var farm: Building = Building.new(-1, "farm", Vector2i(2, 2), Vector2i(3, 3))
	city.add_building(farm, household)
	household.working_adults = 1
	household.young_children = 0
	household.older_children = 0
	household.adult_children = 0
	household.total_population = 1
	var before: int = city.households.size()
	var ended: bool = HouseholdMortality.die(city, household, HouseholdMortality.HUNGER, 0)
	_check(ended and household.total_population == 0, "the last adult's death ends the family")
	city.end_household(household, "hardship_hunger")
	_check(city.households.size() == before - 1 and not city.households.has(household), "it leaves the town's families")
	_check(farm.assigned_household_id != household.id, "its work no longer belongs to it")
	_check(city.households_ended_by_hardship == 1, "and is counted")

func test_deaths_are_told() -> void:
	var city: City = ConstructionTest.make_city(false)
	var household: Household = city.households[0]
	household.young_children = maxi(1, household.young_children)
	household.total_population = household.working_adults + household.get_total_child_count()
	HouseholdMortality.die(city, household, HouseholdMortality.COLD, 0)
	var lines: String = str(city.settlement.chronicle)
	_check(lines.contains("died of cold") and lines.contains("Household %d" % household.id), "the chronicle tells it: %s" % lines)
	_check(household.economy_note.contains("died of the cold"), "and the family's note: %s" % household.economy_note)
	_check(int(city.hardship_deaths.get("cold", 0)) == 1 and household.hardship_deaths == 1, "and it is counted by cause")

func test_rolls_are_seeded() -> void:
	var outcomes: Array = []
	for _run in range(2):
		var city: City = ConstructionTest.make_city(false)
		for household: Household in city.households:
			household.short_days_this_month = 30
			household.severe_hunger_months = 8
		HouseholdMortality.advance_month(city)
		outcomes.append(city.households.map(func(h: Household) -> int: return h.total_population))
	_check(outcomes[0] == outcomes[1], "the same town and month roll the same: %s" % str(outcomes))

func test_a_starving_town() -> void:
	var city: City = ConstructionTest.make_city(false)
	city.resources["food"] = 0
	var checker = Invariants.new()
	checker.watch(city)
	var first_death_month: int = -1
	for month in range(1, 13):
		for day in range(Calendar.DAYS_PER_MONTH):
			city.tick()
			checker.check_day(city, (month - 1) * Calendar.DAYS_PER_MONTH + day)
		city.resources["food"] = 0
		var before: int = city.hardship_deaths.values().reduce(func(a, b): return int(a) + int(b), 0)
		HouseholdMigration.advance_month(city)
		var after: int = city.hardship_deaths.values().reduce(func(a, b): return int(a) + int(b), 0)
		if after > before and first_death_month < 0:
			first_death_month = month
	_check(first_death_month >= EconomyBalance.HARDSHIP_SUSTAINED_MONTHS, "nobody dies before %d months of hunger (first death in month %d)" % [EconomyBalance.HARDSHIP_SUSTAINED_MONTHS, first_death_month])
	_check(first_death_month > 0, "but a town without food for a year does lose people")
	_check(checker.is_clean(), "members stay consistent throughout: %s" % str(checker.violations))

func test_counts_are_saved() -> void:
	var city: City = ConstructionTest.make_city(false)
	var household: Household = city.households[0]
	household.severe_hunger_months = 2
	household.severe_cold_months = 1
	city.hardship_deaths = {"hunger": 3}
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.households[0].severe_hunger_months == 2 and restored.households[0].severe_cold_months == 1 and int(restored.hardship_deaths.get("hunger", 0)) == 3, "severe months and deaths survive a save")

func test_switched_off() -> void:
	var city: City = ConstructionTest.make_city(false)
	city.set_meta("no_hardship_deaths", true)
	for household: Household in city.households:
		household.short_days_this_month = 30
		household.severe_hunger_months = 20
	var people: int = city.get_total_population()
	HouseholdMortality.advance_month(city)
	_check(city.get_total_population() == people, "with the comparison switch, no deaths")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
