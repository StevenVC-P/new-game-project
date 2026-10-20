extends SceneTree

# Owner tuning decisions (2026-10-20): work succession, food shortage loss, and cultural
# outsider marriage. See docs/IMPLEMENTATION_ROADMAP.md.

const CityScript = preload("res://scripts/domain/city.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const CultureEffectsScript = preload("res://scripts/domain/culture_effects.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_child_family_inherits_work_without_gap()
	test_workplace_without_heir_is_filled_after_two_months()
	test_player_can_fill_during_the_gap()
	test_player_hold_is_never_auto_filled()
	test_heir_is_not_given_more_work_than_it_can_do()
	test_food_shortage_costs_a_quarter_of_production()
	test_outsider_marriage_wait_depends_on_culture()

	if failure_count > 0:
		push_error("Succession and shortage validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Succession and shortage validation passed.")
	quit()

func test_child_family_inherits_work_without_gap() -> void:
	var city = _city()
	var elders: Household = _household(city, 1)
	var child: Household = _household(city, 2)
	child.parent_household_id = elders.id
	var farm: Building = _farm(city, elders)
	city.complete_old_couple_lifecycle(elders)
	_check(farm.assigned_household_id == child.id, "a child's family should take over the work immediately")
	_check(farm.succession_vacancy_months == -1, "an inherited workplace should not wait as a vacancy")

func test_workplace_without_heir_is_filled_after_two_months() -> void:
	var city = _city()
	var elders: Household = _household(city, 1)
	var neighbor: Household = _household(city, 2)
	var farm: Building = _farm(city, elders)
	city.complete_old_couple_lifecycle(elders)
	city.update_worker_counts()
	_check(farm.assigned_workers == 0 and farm.succession_vacancy_months == 0, "with no heir, the workplace should wait for the player")
	city.advance_work_succession_vacancies()
	_check(farm.assigned_workers == 0, "the workplace should still wait after one month")
	city.advance_work_succession_vacancies()
	_check(farm.assigned_household_id == neighbor.id, "the game should fill the workplace after two months")

func test_player_can_fill_during_the_gap() -> void:
	var city = _city()
	var elders: Household = _household(city, 1)
	var neighbor: Household = _household(city, 2)
	var farm: Building = _farm(city, elders)
	city.complete_old_couple_lifecycle(elders)
	city.update_worker_counts()
	city.assign_household_by_id_to_building(farm.id, neighbor.id)
	_check(farm.assigned_household_id == neighbor.id, "the player should be able to fill the workplace at any point")
	_check(farm.succession_vacancy_months == -1, "a filled workplace should stop counting as a vacancy")

func test_player_hold_is_never_auto_filled() -> void:
	var city = _city()
	var worker: Household = _household(city, 1)
	_household(city, 2)
	var farm: Building = _farm(city, worker)
	city.unassign_building_worker(farm.id, true)
	for month in range(4):
		city.advance_work_succession_vacancies()
	_check(farm.assigned_workers == 0, "a workplace the player emptied should not be refilled by succession")

func test_heir_is_not_given_more_work_than_it_can_do() -> void:
	var city = _city()
	var elders: Household = _household(city, 1)
	var child: Household = _household(city, 2)
	child.parent_household_id = elders.id
	var own_farm: Building = _farm(city, child)
	var first: Building = _farm(city, elders)
	var second: Building = _farm(city, elders)
	city.complete_old_couple_lifecycle(elders)
	var inherited: int = 0
	for building: Building in [first, second]:
		if building.assigned_household_id == child.id:
			inherited += 1
	_check(own_farm.assigned_household_id == child.id, "the heir should keep its own work")
	_check(inherited == child.labor_capacity - 1, "the heir should inherit only as much work as it has labor for, got " + str(inherited))

func test_food_shortage_costs_a_quarter_of_production() -> void:
	var city = _city()
	var farm: Building = Building.new(city.buildings.size(), Building.BUILDING_FARM)
	city.buildings.append(farm)
	farm.assign_neutral_worker()
	city.resources["food_shortage"] = true
	var before: int = int(city.resources["food"])
	for day in range(100):
		city.resources["production_tick_count"] = day
		city.apply_building_production(farm)
	var produced: int = int(city.resources["food"]) - before
	_check(produced == 150, "a food shortage should cost a quarter of production (200 -> 150), got " + str(produced))

func test_outsider_marriage_wait_depends_on_culture() -> void:
	var clannish: int = CultureEffectsScript.get_outsider_marriage_wait_months(_profile(["clannish"], ["insular"]))
	var plain: int = CultureEffectsScript.get_outsider_marriage_wait_months(_profile(["each_to_their_own"], ["hagglers"]))
	var open_minded: int = CultureEffectsScript.get_outsider_marriage_wait_months(_profile(["welcoming"], ["cosmopolitan"]))
	_check(plain == CultureEffectsScript.OUTSIDER_MARRIAGE_BASE_WAIT_MONTHS, "a family without related values should wait the base time")
	_check(clannish > plain and plain > open_minded, "clannish families should wait longest and welcoming ones least")
	_check(open_minded >= CultureEffectsScript.OUTSIDER_MARRIAGE_MIN_WAIT_MONTHS, "the wait should never drop below the minimum")

# --- helpers ---

func _city():
	var city = CityScript.new("Test", Vector2(9, 9), CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = 1000
	city.resources["food_shortage"] = false
	return city

func _household(city, household_id: int) -> Household:
	var house: Building = Building.new(city.buildings.size(), Building.BUILDING_HOUSE)
	city.buildings.append(house)
	var household: Household = Household.new(household_id, house.id, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	household.working_adults = 2
	household.update_labor_capacity()
	household.move_to_house(house.id)
	household.family_trade = "farming"
	household.set_values(_profile(["each_to_their_own"], ["hagglers"]))
	city.households.append(household)
	return household

func _farm(city, household: Household) -> Building:
	var farm: Building = Building.new(city.buildings.size(), Building.BUILDING_FARM)
	city.buildings.append(farm)
	farm.assign_household(household, Building.ASSIGNMENT_AUTO)
	city.update_household_assignments()
	return farm

func _profile(community: Array, trade_coin: Array) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13
	return CultureValuesScript.make_random_profile(rng, {
		CultureValuesScript.CATEGORY_CALLING: ["soil"],
		CultureValuesScript.CATEGORY_COMMUNITY: community,
		CultureValuesScript.CATEGORY_TRADE_COIN: trade_coin
	})

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
