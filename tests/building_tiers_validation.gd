extends SceneTree

# Building tiers (owner decision 2026-10-20): tier 0 hand work is free, needs no tool upkeep,
# produces about a third of tier 1, and upgrades in place. Huts are homes, and rough housing
# becomes hardship after a grace period.

const CityScript = preload("res://scripts/domain/city.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_tier0_buildings_are_free()
	test_tier0_produces_a_third_of_tier1()
	test_tier0_needs_no_tool_upkeep()
	test_town_with_no_wood_or_tools_can_restart()
	test_upgrade_in_place_keeps_the_family()
	test_upgrade_needs_the_tier1_cost()
	test_huts_are_homes_but_houses_come_first()
	test_rough_housing_becomes_hardship_after_grace()
	test_callings_apply_to_tier0()

	if failure_count > 0:
		push_error("Building tiers validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Building tiers validation passed.")
	quit()

func test_tier0_buildings_are_free() -> void:
	for building_type in BuildingTiersScript.TIER0_TO_TIER1.keys():
		_check(EconomyBalanceScript.get_build_cost(building_type).is_empty(), str(building_type) + " should be free to build")

func test_tier0_produces_a_third_of_tier1() -> void:
	var farm_food: int = _output_over(Building.BUILDING_FARM, "food", 300)
	var garden_food: int = _output_over("forager_garden", "food", 300)
	# Design rule: tier 0 is a fallback, always below tier 1 (the exact fraction is a balance value).
	_check(EconomyBalanceScript.TIER0_OUTPUT_FRACTION > 0.0 and EconomyBalanceScript.TIER0_OUTPUT_FRACTION < 1.0, "tier 0 output should be a fraction of tier 1")
	var ratio: float = float(garden_food) / float(farm_food)
	_check(abs(ratio - EconomyBalanceScript.TIER0_OUTPUT_FRACTION) < 0.02, "a forager's garden should produce about a third of a farm, got ratio " + str(ratio))
	var camp_wood: int = _output_over("gatherer_camp", "wood", 300)
	_check(camp_wood > 0, "a gatherer's camp should produce wood")

func test_tier0_needs_no_tool_upkeep() -> void:
	var city = _city()
	city.resources["tools"] = 0
	city.resources["maintenance_grace_ticks"] = 0
	var camp: Building = _workplace(city, "gatherer_camp", _household(city, 1, ["forest"]))
	for day in range(200):
		city.tick()
	_check(camp.maintenance_level == 100, "tier 0 buildings should not decay without tools")

func test_town_with_no_wood_or_tools_can_restart() -> void:
	var city = _city()
	city.resources["wood"] = 0
	city.resources["tools"] = 0
	city.resources["maintenance_grace_ticks"] = 0
	_workplace(city, "gatherer_camp", _household(city, 1, ["forest"]))
	_workplace(city, "tool_mender", _household(city, 2, ["forge_bench"]))
	for day in range(60):
		city.tick()
	_check(int(city.resources["tools"]) > 0, "a gatherer's camp and tool mender should rebuild tools from nothing")

func test_upgrade_in_place_keeps_the_family() -> void:
	var city = _city()
	city.resources["wood"] = 100
	city.resources["tools"] = 10
	var family: Household = _household(city, 1, ["soil"])
	var garden: Building = _workplace(city, "forager_garden", family)
	var wood_before: int = int(city.resources["wood"])
	_check(city.upgrade_building(garden.id), "an affordable upgrade should succeed")
	_check(garden.type == Building.BUILDING_FARM, "a forager's garden should upgrade into a farm")
	_check(garden.assigned_household_id == family.id, "the same family should keep working the upgraded holding")
	_check(int(city.resources["wood"]) == wood_before - int(EconomyBalanceScript.get_build_cost(Building.BUILDING_FARM).get("wood", 0)), "the upgrade should cost the tier 1 price")
	_check(not city.can_upgrade_building(garden.id), "a tier 1 building should not upgrade further")

func test_upgrade_needs_the_tier1_cost() -> void:
	var city = _city()
	city.resources["wood"] = 0
	city.resources["tools"] = 0
	var hut: Building = _add_building(city, "hut")
	_check(not city.upgrade_building(hut.id), "an upgrade should fail without the tier 1 cost")
	_check(hut.type == "hut", "a failed upgrade should leave the building unchanged")

func test_huts_are_homes_but_houses_come_first() -> void:
	var city = _city()
	var hut: Building = _add_building(city, "hut")
	var house: Building = _add_building(city, Building.BUILDING_HOUSE)
	_check(hut.is_house() and not hut.is_production_building(), "a hut should be a home")
	var empty: Array[int] = city.get_empty_house_building_ids()
	_check(empty.size() == 2 and empty[0] == house.id, "proper houses should be offered before huts")

func test_rough_housing_becomes_hardship_after_grace() -> void:
	var city = _city()
	var hut: Building = _add_building(city, "hut")
	var family: Household = Household.new(1, hut.id, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	family.working_adults = 2
	family.update_labor_capacity()
	family.move_to_house(hut.id)
	family.set_values(_profile(["soil"], ["open_country"]))
	city.households.append(family)
	_check(city.is_household_in_rough_housing(family), "a family in a hut is in rough housing")
	_check(HouseholdMigrationScript.is_household_crowded(family, city), "a hut should count as crowded for births")
	for month in range(EconomyBalanceScript.ROUGH_HOUSING_GRACE_MONTHS):
		HouseholdMigrationScript.update_hardship(city)
	_check(family.hardship_points == 0, "rough housing should not be hardship during the grace period")
	HouseholdMigrationScript.update_hardship(city)
	_check(family.hardship_points > 0, "rough housing should become hardship after the grace period")

func test_callings_apply_to_tier0() -> void:
	var family: Household = Household.new(1, -1, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	family.set_values(_profile(["soil"], ["open_country"]))
	_check(family.get_match_quality("forager_garden") == "good match", "a farming family should be well suited to a forager's garden")

# --- helpers ---

func _output_over(building_type: String, resource: String, days: int) -> int:
	var city = _city()
	var family: Household = _household(city, 1, ["hearth"])
	var building: Building = _workplace(city, building_type, family)
	city.resources["maintenance_grace_ticks"] = days + 1
	var before: int = int(city.resources[resource])
	for day in range(days):
		city.resources["production_tick_count"] = day
		city.apply_building_production(building)
	return int(city.resources[resource]) - before

func _city():
	var city = CityScript.new("Tier Town", Vector2(6, 6), CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = 100000
	city.resources["food_shortage"] = false
	return city

func _add_building(city, building_type: String) -> Building:
	var building: Building = Building.new(city.buildings.size(), building_type)
	city.buildings.append(building)
	return building

func _household(city, household_id: int, callings: Array) -> Household:
	var house: Building = _add_building(city, Building.BUILDING_HOUSE)
	var household: Household = Household.new(household_id, house.id, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	household.working_adults = 2
	household.update_labor_capacity()
	household.move_to_house(house.id)
	household.set_values(_profile(callings, ["open_country"]))
	city.households.append(household)
	return household

func _workplace(city, building_type: String, household: Household) -> Building:
	var building: Building = _add_building(city, building_type)
	building.assign_household(household, Building.ASSIGNMENT_PLAYER)
	city.update_household_assignments()
	return building

func _profile(callings: Array, home_place: Array) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	return CultureValuesScript.make_random_profile(rng, {
		CultureValuesScript.CATEGORY_CALLING: callings,
		CultureValuesScript.CATEGORY_WORK_ETHIC: ["solitary"],
		CultureValuesScript.CATEGORY_HOME_PLACE: home_place
	})

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
