extends SceneTree

# M2: families arrive and leave (docs/IMPLEMENTATION_ROADMAP.md, docs/SETTLEMENT_GROWTH_SCALE_MODEL.md).

const CityScript = preload("res://scripts/domain/city.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const CultureEffectsScript = preload("res://scripts/domain/culture_effects.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_regional_pool_starts_in_families()
	test_arrival_needs_an_empty_house()
	test_arrival_needs_sustainable_food()
	test_whole_family_arrives_when_town_is_attractive()
	test_family_leaves_after_sustained_shortage()
	test_only_one_family_leaves_per_month()
	test_departure_frees_work_for_neighbors()
	test_families_do_not_leave_after_hard_times_pass()
	test_rooted_families_endure_longer()
	test_household_ids_stay_unique_after_departure()
	test_births_only_blocked_without_shelter()
	test_crowding_lowers_birth_chance_by_values()
	test_departure_warning_is_counted()

	if failure_count > 0:
		push_error("Household migration validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Household migration validation passed.")
	quit()

func test_regional_pool_starts_in_families() -> void:
	var city = CityScript.new("Pool Town", Vector2(3, 3), CityScript.ROLE_PLAYER, 4)
	_check(int(city.resources["regional_migrant_families"]) == HouseholdMigrationScript.POOL_START_FAMILIES, "regional pool should start with the configured number of families")
	_check(not city.resources.has("external_population_pool"), "the per-person external pool should be gone")

func test_arrival_needs_an_empty_house() -> void:
	var city = _fed_city(2, 4)
	_check(HouseholdMigrationScript.get_arrival_blocker(city) == HouseholdMigrationScript.BLOCKER_NO_HOUSE, "newcomers should need an empty house")
	_add_house(city)
	_check(HouseholdMigrationScript.get_arrival_blocker(city) == "", "an empty house and enough food should allow newcomers")

func test_arrival_needs_sustainable_food() -> void:
	var city = _fed_city(2, 0)
	_add_house(city)
	_check(HouseholdMigrationScript.get_arrival_blocker(city) == HouseholdMigrationScript.BLOCKER_FOOD_NOT_SUSTAINABLE, "newcomers should not come when farms cannot feed them, even with food stored")

func test_whole_family_arrives_when_town_is_attractive() -> void:
	var city = _fed_city(2, 4)
	for index in range(3):
		_add_house(city)
	var pool_before: int = int(city.resources["regional_migrant_families"])
	var households_before: int = city.households.size()
	for month in range(24):
		HouseholdMigrationScript.advance_month(city)
		if city.households.size() > households_before:
			break
	_check(city.households.size() > households_before, "a family should arrive within two years in an attractive town")
	if city.households.size() <= households_before:
		return
	var newcomer: Household = city.households[city.households.size() - 1]
	_check(newcomer.working_adults == 2, "newcomers should arrive as a couple, not single people")
	_check(newcomer.total_population == 2 + newcomer.young_children, "newcomer population should match its family")
	_check(newcomer.lifecycle_stage == Household.LIFECYCLE_NEWLYWED or newcomer.lifecycle_stage == Household.LIFECYCLE_YOUNG_FAMILY, "newcomers should be a newlywed or young family")
	_check(newcomer.housing_status == Household.RESIDENCE_HOUSED, "newcomers should move into the empty house")
	_check(CultureValuesScript.is_valid_profile(newcomer.values), "newcomers should bring a valid value profile")
	_check(int(city.resources["regional_migrant_families"]) < pool_before, "the regional pool should shrink when a family arrives")
	_check(int(city.resources["arrived_households"]) >= 1, "arrivals should be counted")

func test_family_leaves_after_sustained_shortage() -> void:
	var city = _fed_city(1, 1)
	var household: Household = city.households[0]
	var threshold: int = HouseholdMigrationScript.get_departure_threshold(household)
	var months_needed: int = int(ceil(float(threshold) / float(HouseholdMigrationScript.HARDSHIP_SHORTAGE_POINTS)))
	for month in range(months_needed - 1):
		_starve_month(city)
	_check(city.households.size() == 1, "a family should endure shortage until its hardship reaches its threshold")
	_starve_month(city)
	_check(city.households.is_empty(), "a family should leave once hardship reaches its threshold")
	_check(int(city.resources["departed_households"]) == 1, "departures should be counted")

func test_only_one_family_leaves_per_month() -> void:
	var city = _fed_city(4, 4)
	for household: Household in city.households:
		household.hardship_points = 20
	_starve_month(city)
	_check(city.households.size() == 3, "at most one family should leave in a month")

func test_departure_frees_work_for_neighbors() -> void:
	var city = _fed_city(2, 1)
	var farm: Building = _first_farm(city)
	var leaver: Household = city.get_household_by_id(farm.assigned_household_id)
	leaver.hardship_points = 20
	for household: Household in city.households:
		if household != leaver:
			household.hardship_points = 0
	_starve_month(city)
	_check(city.get_household_by_id(leaver.id) == null, "the hardest-hit family should leave")
	_check(not farm.auto_assignment_blocked, "a workplace left by a departing family should stay open to neighbors")
	_check(farm.assigned_workers > 0 and farm.assigned_household_id != leaver.id, "another family should take up the departed family's farm")

func test_families_do_not_leave_after_hard_times_pass() -> void:
	var city = _fed_city(1, 2)
	var household: Household = city.households[0]
	household.hardship_points = HouseholdMigrationScript.get_departure_threshold(household) + 1
	city.resources["shortage_days_this_month"] = 0
	HouseholdMigrationScript.advance_month(city)
	_check(city.households.size() == 1, "a family should not leave in a month without hardship")
	_check(household.hardship_points < HouseholdMigrationScript.get_departure_threshold(household) + 1, "hardship should ease in a good month")

func test_rooted_families_endure_longer() -> void:
	var plain: Dictionary = _profile(["solitary"], ["fathers_line"], ["cautious"])
	var rooted: Dictionary = _profile(["solitary"], ["fathers_line"], ["rooted"])
	_check(CultureEffectsScript.get_departure_threshold(rooted) > CultureEffectsScript.get_departure_threshold(plain), "rooted families should tolerate more hardship")

func test_household_ids_stay_unique_after_departure() -> void:
	var city = _fed_city(3, 3)
	city.households.remove_at(0)
	var new_id: int = city.get_next_household_id()
	for household: Household in city.households:
		_check(household.id != new_id, "a new household id should never reuse a living household's id")

func test_births_only_blocked_without_shelter() -> void:
	var city = _fed_city(1, 2)
	var household: Household = city.households[0]
	household.lifecycle_stage = Household.LIFECYCLE_YOUNG_FAMILY
	household.young_children = 0
	city.resources["housing_capacity"] = 0
	_check(city.get_birth_blocker_reason(household) == "", "a full town should no longer block births for a housed family")
	household.move_to_temporary_shelter()
	_check(city.get_birth_blocker_reason(household) == "", "temporary shelter should not block births")
	household.move_to_unsheltered()
	_check(city.get_birth_blocker_reason(household) == "not_housed", "families with no shelter should not have children")

func test_crowding_lowers_birth_chance_by_values() -> void:
	var city = _fed_city(1, 2)
	var household: Household = city.households[0]
	household.lifecycle_stage = Household.LIFECYCLE_YOUNG_FAMILY
	household.young_children = 0
	household.set_values(_profile(["solitary"], ["fathers_line"], ["cautious"], ["simple_living"]))
	var roomy_chance: int = city.get_birth_roll_chance(household)
	household.move_to_temporary_shelter()
	var tolerant_crowded: int = city.get_birth_roll_chance(household)
	household.set_values(_profile(["solitary"], ["fathers_line"], ["cautious"], ["hearth_proud"]))
	var sensitive_crowded: int = city.get_birth_roll_chance(household)
	_check(tolerant_crowded < roomy_chance, "crowding should lower the birth chance")
	_check(sensitive_crowded < tolerant_crowded, "hearth-proud families should mind crowding more than simple-living ones")

func test_departure_warning_is_counted() -> void:
	var city = _fed_city(2, 2)
	var household: Household = city.households[0]
	household.hardship_points = HouseholdMigrationScript.get_departure_threshold(household) - 2
	city.resources["shortage_days_this_month"] = 0
	city.resources["households_considering_departure"] = HouseholdMigrationScript.get_households_considering_departure(city).size()
	_check(int(city.resources["households_considering_departure"]) == 1, "a family close to its limit should be flagged as considering leaving")

# --- helpers ---

# A town with `household_count` housed families and `farm_count` worked farms, food stocked.
func _fed_city(household_count: int, farm_count: int):
	var city = CityScript.new("Test", Vector2(5, 5), CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = 500
	city.resources["food_shortage"] = false
	for index in range(household_count):
		var house: Building = _add_house(city)
		var household: Household = Household.new(city.get_next_household_id(), house.id, Household.WORK_PREF_NEUTRAL, 4, Household.RESIDENCE_HOUSED)
		household.working_adults = 2
		household.update_labor_capacity()
		household.move_to_house(house.id)
		household.set_values(_profile(["solitary"], ["fathers_line"], ["cautious"]))
		city.households.append(household)
	for index in range(farm_count):
		var farm: Building = Building.new(city.buildings.size(), Building.BUILDING_FARM)
		city.buildings.append(farm)
	city.update_shelter_counts()
	city.auto_assign_workers()
	city.consume_food()
	return city

func _starve_month(city) -> void:
	city.resources["shortage_days_this_month"] = 30
	city.resources["food_shortage"] = true
	HouseholdMigrationScript.advance_month(city)

func _first_farm(city) -> Building:
	for building: Building in city.buildings:
		if building.type == Building.BUILDING_FARM and building.assigned_workers > 0:
			return building
	return null

func _add_house(city) -> Building:
	var house: Building = Building.new(city.buildings.size(), Building.BUILDING_HOUSE)
	city.buildings.append(house)
	return house

func _profile(work_ethic: Array, kin: Array, change_risk: Array, home_place: Array = []) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var preset: Dictionary = {
		CultureValuesScript.CATEGORY_CALLING: ["soil"],
		CultureValuesScript.CATEGORY_WORK_ETHIC: work_ethic,
		CultureValuesScript.CATEGORY_KIN: kin,
		CultureValuesScript.CATEGORY_CHANGE_RISK: change_risk,
		CultureValuesScript.CATEGORY_COMMUNITY: ["each_to_their_own"]
	}
	preset[CultureValuesScript.CATEGORY_HOME_PLACE] = home_place if not home_place.is_empty() else ["open_country"]
	return CultureValuesScript.make_random_profile(rng, preset)

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
