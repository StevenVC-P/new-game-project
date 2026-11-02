extends SceneTree

# Winter fuel (sprint S3, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md, TownFuel): hearths burn wood by the
# season's cold at the town's climate (a temperate town in winter only, a cold one from autumn to
# spring, a tropical one never), by how many they keep warm and by their shelter; the wood truly
# leaves the store, a fraction carried; with none, hearths go cold, families lose some working days
# and hardship builds; the fuel to come counts in the wood families judge the town will use, so fuel
# competes with building and tools; a family whose hearth went cold wants to gather wood; the player
# is warned; without a town map nothing burns; the cold survives a save.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_cold_follows_climate_and_season()
	test_need_follows_people_and_shelter()
	test_burning_takes_wood()
	test_cold_hearths()
	test_fuel_counts_in_wood_use()
	test_a_cold_family_gathers_wood()
	test_the_player_is_warned()
	test_no_map_no_fuel()
	test_cold_is_saved()
	if failure_count > 0:
		push_error("Winter fuel validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Winter fuel validation passed.")
	quit()

func town(temperature: float = 0.55, woods: Array[Rect2i] = [Rect2i(10, 10, 6, 6)]) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map(woods)
	city.logistics.mark_layout_changed()
	city.site_profile = SettlementSiteProfile.new()
	city.site_profile.climate = {"temperature": temperature, "moisture": 0.6, "family": "temperate", "tree_temperature": temperature}
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 100
	return city

# Puts the town on a day of the given season.
func set_season(city: City, season: int) -> void:
	city.day_of_year = season * 90 + 10

func test_cold_follows_climate_and_season() -> void:
	var temperate: City = town(0.55)
	var cold: City = town(0.3)
	var tropical: City = town(0.8)
	_check(TownFuel.get_coldness(temperate, WINTER) > 0.0 and TownFuel.get_coldness(temperate, SPRING) == 0.0 and TownFuel.get_coldness(temperate, AUTUMN) == 0.0 and TownFuel.get_coldness(temperate, SUMMER) == 0.0, "a temperate town heats in winter only")
	_check(TownFuel.get_coldness(cold, SPRING) > 0.0 and TownFuel.get_coldness(cold, AUTUMN) > 0.0 and TownFuel.get_coldness(cold, SUMMER) == 0.0, "a cold one from autumn to spring")
	_check(TownFuel.get_coldness(cold, WINTER) > TownFuel.get_coldness(temperate, WINTER) * 2.0, "and its winter is much colder (%.2f, %.2f)" % [TownFuel.get_coldness(cold, WINTER), TownFuel.get_coldness(temperate, WINTER)])
	_check(range(4).all(func(s: int) -> bool: return TownFuel.get_coldness(tropical, s) == 0.0), "a tropical one never")
	_check(TownFuel.get_need_over(cold, 360) > TownFuel.get_need_over(temperate, 360) * 3.0, "a cold town burns several times a temperate one's wood in a year (%.0f, %.0f)" % [TownFuel.get_need_over(cold, 360), TownFuel.get_need_over(temperate, 360)])

func test_need_follows_people_and_shelter() -> void:
	var city: City = town(0.3)
	var household: Household = city.households[0]
	household.housing_status = Household.RESIDENCE_HOUSED
	household.total_population = 4
	var four: float = TownFuel.get_household_need(city, household, WINTER)
	household.total_population = 8
	_check(is_equal_approx(TownFuel.get_household_need(city, household, WINTER), four * 2.0), "twice the people, twice the fuel")
	household.total_population = 4
	household.housing_status = Household.RESIDENCE_TEMPORARY
	_check(is_equal_approx(TownFuel.get_household_need(city, household, WINTER), four * EconomyBalance.ROUGH_SHELTER_FUEL_FACTOR), "rough shelter burns more")

func test_burning_takes_wood() -> void:
	var city: City = town(0.3)
	set_season(city, WINTER)
	var checker = Invariants.new()
	checker.watch(city)
	var wood: int = int(city.resources["wood"])
	var expected: float = 0.0
	for day in range(1, 31):
		expected += TownFuel.get_daily_need(city)
		TownFuel.burn(city)
		checker.check_day(city, day)
	var burned: int = wood - int(city.resources["wood"])
	_check(burned > 0 and burned == city.fuel_burned, "the hearths burned wood from the store (%d)" % burned)
	_check(absf(float(burned) + city.fuel_carry - expected) < 0.001, "exactly the month's need, the fraction carried (%d + %.2f for %.2f)" % [burned, city.fuel_carry, expected])
	_check(checker.is_clean(), "the store moved only by what burned: %s" % str(checker.violations))
	var summer: City = town(0.3)
	set_season(summer, SUMMER)
	var before: int = int(summer.resources["wood"])
	for _day in range(30):
		TownFuel.burn(summer)
	_check(int(summer.resources["wood"]) == before, "nothing burns in a cold town's summer")

func test_cold_hearths() -> void:
	var city: City = town(0.3)
	set_season(city, WINTER)
	city.resources["wood"] = 0
	var household: Household = city.households[0]
	TownFuel.burn(city)
	_check(household.cold_today and household.cold_days_this_month == 1 and city.fuel_short_days == 1, "with no wood every hearth goes cold")
	var lost: int = 0
	for tick in range(EconomyBalance.COLD_SKIP_TICK_INTERVAL * 5):
		city.resources["production_tick_count"] = tick
		lost += 1 if city.skips_work_today(household.id) else 0
	_check(lost == 5, "a cold family loses one working day in %d (%d of %d)" % [EconomyBalance.COLD_SKIP_TICK_INTERVAL, lost, EconomyBalance.COLD_SKIP_TICK_INTERVAL * 5])
	household.cold_days_this_month = EconomyBalance.HARDSHIP_COLD_DAYS
	household.short_days_this_month = 0
	household.housing_status = Household.RESIDENCE_HOUSED
	household.total_population = 4
	_check(HouseholdMigration.get_monthly_hardship_points(city, household) >= EconomyBalance.COLD_HARDSHIP_POINTS, "a month of cold hearths is hardship")
	city.resources["wood"] = 100
	TownFuel.burn(city)
	_check(not household.cold_today, "with wood again the hearth is warm")

func test_fuel_counts_in_wood_use() -> void:
	var cold: City = town(0.3)
	set_season(cold, AUTUMN)
	var mild: City = town(0.8)
	set_season(mild, AUTUMN)
	var horizon: int = FamilyInitiative.SHORTAGE_HORIZON_DAYS
	_check(FamilyInitiative.get_use(cold, TownInfluence.ACTIVITY_WOOD, horizon) > FamilyInitiative.get_use(mild, TownInfluence.ACTIVITY_WOOD, horizon) + 1.0, "the coming fuel counts in the wood a cold town will use")
	cold.resources["wood"] = int(TownFuel.get_need_over(cold, FamilyInitiative.FUEL_RISK_DAYS)) - 10
	_check(FamilyInitiative.get_waiting_risk(cold, TownInfluence.ACTIVITY_WOOD) > 0.0, "less wood than the cold season will burn puts wood at risk")
	mild.resources["wood"] = cold.resources["wood"]
	_check(FamilyInitiative.get_waiting_risk(mild, TownInfluence.ACTIVITY_WOOD) == 0.0, "the same store is no risk where nothing burns")

func test_a_cold_family_gathers_wood() -> void:
	var city: City = town(0.3, [Rect2i(20, 18, 8, 8)])
	set_season(city, WINTER)
	var household: Household = city.households[0]
	var holding: Building = Building.new(-1, "farm", Vector2i(30, 30), Vector2i(3, 3))
	city.add_building(holding, household)
	household.cold_days_this_month = 3
	var desire: Dictionary = HouseholdEconomy.get_secondary_desire(city, household, holding, "wood", {})
	var reasons: String = str(FamilyInitiative.get_reasons(desire["terms"], true))
	_check(not bool(desire["possible"]) or reasons.contains("hearth went cold"), "a family whose hearth went cold has that reason to gather wood: %s" % reasons)

func test_the_player_is_warned() -> void:
	var city: City = town(0.3)
	set_season(city, AUTUMN)
	city.resources["wood"] = 5
	var card: Dictionary = SidebarOverviewPage.get_fuel_card(city)
	_check(str(card.get("title", "")) == SidebarOverviewPage.FUEL_SHORT_TITLE, "a cold season ahead with little wood is a warning: %s" % str(card.get("title", "")))
	set_season(city, WINTER)
	city.resources["wood"] = 0
	TownFuel.burn(city)
	card = SidebarOverviewPage.get_fuel_card(city)
	_check(str(card.get("title", "")) == SidebarOverviewPage.FUEL_COLD_TITLE, "cold hearths are an alert: %s" % str(card.get("title", "")))
	var warm: City = town(0.8)
	warm.resources["wood"] = 0
	_check(SidebarOverviewPage.get_fuel_card(warm).is_empty(), "no warning where nothing burns")

func test_no_map_no_fuel() -> void:
	var city: City = ConstructionTest.make_city(false)
	city.day_of_year = 300
	var wood: int = int(city.resources["wood"])
	TownFuel.burn(city)
	_check(int(city.resources["wood"]) == wood and TownFuel.get_need_over(city, 360) == 0.0, "without a town map nothing burns")

func test_cold_is_saved() -> void:
	var city: City = town(0.3)
	set_season(city, WINTER)
	city.resources["wood"] = 0
	TownFuel.burn(city)
	TownFuel.burn(city)
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.households[0].cold_days_this_month == 2 and restored.fuel_short_days == 2, "cold days survive a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
