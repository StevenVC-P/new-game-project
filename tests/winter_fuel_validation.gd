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
	test_cold_draws_families_to_wood_work()
	test_wood_beyond_winter()
	test_reachable_wood()
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

# Survival first for cold as for hunger (sprint S3 review): a town whose hearths will go cold draws
# families to wood work, a family whose own hearth went cold more so, and two cold months running
# make a family look at its work again at once. Found when the first comparison showed forest towns
# freezing beside their woods because no family changed its work.
func test_cold_draws_families_to_wood_work() -> void:
	var city: City = town(0.3, [Rect2i(20, 18, 10, 10)])
	set_season(city, AUTUMN)
	city.resources["wood"] = 0
	var household: Household = city.households[0]
	var cold: Dictionary = FamilyInitiative.get_cold_hardship(city, household)
	_check(float(cold["level"]) > 0.5, "a cold town with no wood is a danger to its families (%.2f)" % float(cold["level"]))
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, "woodcutter")
	_check(str(FamilyInitiative.get_reasons(desire["terms"], true)).contains("go cold"), "and draws them to wood work: %s" % str(FamilyInitiative.get_reasons(desire["terms"], true)))
	var warm: City = town(0.8, [Rect2i(20, 18, 10, 10)])
	warm.resources["wood"] = 0
	_check(float(FamilyInitiative.get_cold_hardship(warm, warm.households[0])["level"]) == 0.0, "where nothing burns, no such danger")
	var holding: Building = Building.new(-1, "farm", Vector2i(34, 30), Vector2i(3, 3))
	city.add_building(holding, household)
	household.work_building_id = holding.id
	for _month in range(2):
		household.cold_days_this_month = OccupationReview.HUNGRY_DAYS_IN_MONTH
		OccupationReview.update_strain(city, household, holding)
	var triggers: Array[String] = OccupationReview.get_triggers(city, household, holding)
	_check(triggers.has(OccupationReview.COLD) and OccupationReview.is_urgent(triggers), "two cold months make a family look at its work at once: %s" % str(triggers))

# Wood beyond the coming winter (sprint S5b; owner 2026-11-05, option b of the Track A review): the
# store against what the town will burn and use through the end of the coming winter weighs against
# wood work and gathering, a past cold hearth weighs less once the store holds the coming need, and a
# woodcutter in a town short of food looks at its work again. A reason, never a rule. Found when cold
# towns kept three woodcutters beside 500 wood while their families went hungry and left.
func test_wood_beyond_winter() -> void:
	var city: City = town(0.3, [Rect2i(20, 18, 10, 10)])
	set_season(city, SPRING)
	var household: Household = city.households[0]
	var need: float = FamilyInitiative.get_use(city, TownInfluence.ACTIVITY_WOOD, Calendar.DAYS_PER_YEAR - (city.get_day_of_year() - 1))
	city.resources["wood"] = int(need * 0.9)
	_check(FamilyInitiative.get_wood_plenty(city, household) == 0.0, "a store that won't see the coming winter out is no plenty (%d for %.0f)" % [int(city.resources["wood"]), need])
	var lean: float = float(FamilyInitiative.get_work_desire(city, household, "woodcutter")["score"])
	set_season(city, WINTER)
	_check(FamilyInitiative.get_wood_plenty(city, household) > 0.0, "the same store is spare with only the winter's end left to burn")
	set_season(city, SPRING)
	city.resources["wood"] = int(need * 2.5)
	_check(is_equal_approx(FamilyInitiative.get_wood_plenty(city, household), 1.0), "twice the coming need and more is plenty")
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, "woodcutter")
	_check(has_reason(desire["terms"], FamilyInitiative.WOOD_PLENTY_REASON) and float(desire["score"]) < lean, "and weighs against wood work (%.2f, %.2f before)" % [float(desire["score"]), lean])
	household.cold_days_this_month = int(FamilyInitiative.HUNGRY_DAYS_DESPERATE)
	set_season(city, AUTUMN)
	_check(float(FamilyInitiative.get_cold_hardship(city, household)["level"]) == 0.0, "a hearth gone cold weighs nothing once the store holds the coming need")
	city.resources["wood"] = 0
	_check(float(FamilyInitiative.get_cold_hardship(city, household)["level"]) == 1.0, "and fully while the store is empty")
	household.cold_days_this_month = 0
	city.resources["wood"] = int(need * 2.5)
	var holding: Building = Building.new(-1, BuildingTiers.get_hand_work_type("woodcutter"), Vector2i(34, 30), Vector2i(2, 2))
	city.add_building(holding, household)
	var gathering: Dictionary = HouseholdEconomy.get_secondary_desire(city, household, Building.new(-1, "farm", Vector2i(30, 30), Vector2i(3, 3)), "wood", {})
	_check(not bool(gathering["possible"]) or has_reason(gathering["terms"], FamilyInitiative.WOOD_PLENTY_REASON), "and against gathering more")
	_check(not OccupationReview.get_triggers(city, household, holding).has(OccupationReview.WOOD_PLENTY), "a fed town's woodcutter goes on")
	city.resources["food"] = 0
	var triggers: Array[String] = OccupationReview.get_triggers(city, household, holding)
	_check(triggers.has(OccupationReview.WOOD_PLENTY) and OccupationReview.is_urgent(triggers), "a hungry town's woodcutter looks at its work again: %s" % str(triggers))
	city.set_meta("no_wood_plenty", true)
	_check(FamilyInitiative.get_wood_plenty(city, household) == 0.0 and not OccupationReview.get_triggers(city, household, holding).has(OccupationReview.WOOD_PLENTY), "the Track A comparison switch restores the old judgment")

# Sprint S5c (owner 2026-11-06): a family weighs the wood it can turn to, its own, the community's
# and what it could buy. A neighbour's pile is not its wood.
func test_reachable_wood() -> void:
	var city: City = town(0.3, [Rect2i(20, 18, 10, 10)])
	set_season(city, SPRING)
	var family: Household = city.households[0]
	var neighbour: Household = city.households[1]
	city.resources["wood"] = 500
	_check(FamilyInitiative.get_reachable_wood(city, family) == 500, "a pooled town's store is every family's")
	city.resources["wood"] = 0
	city.resources["food"] = 0
	TownCompact.set_preset(city, "private")
	for household: Household in city.households:
		household.larder = 0.0
		household.values = {}
		household.value_strengths = {}
	var need: float = FamilyInitiative.get_use(city, TownInfluence.ACTIVITY_WOOD, Calendar.DAYS_PER_YEAR - (city.get_day_of_year() - 1))
	TownLedger.credit(city, neighbour, "wood", int(need * 3.0) + 400, "made")
	_check(FamilyInitiative.get_reachable_wood(city, family) == 0, "a neighbour's wood is out of reach of a family that can't pay for it")
	_check(FamilyInitiative.get_wood_plenty(city, family) == 0.0, "so it is no plenty to that family")
	_check(FamilyInitiative.get_wood_plenty(city, neighbour) > 0.0, "though it is to the family that owns it")
	city.resources["wood"] = int(city.resources["wood"]) + 40
	_check(FamilyInitiative.get_reachable_wood(city, family) == 40, "the community's wood is within reach")
	var want: int = int(TownMarket.scale(TownMarket.get_wants(city, family), TownMarket.get_market_share(family)).get("wood", 0))
	_check(want > 0, "the family wants winter wood (%d)" % want)
	TownLedger.credit(city, family, "food", TownMarket.get_keep(city, family, "food") + 10, "made")
	var price: float = TownMarket.get_price(city, "wood")
	_check(TownMarket.get_obtainable(city, family, "wood") == mini(want, int(floor(10.0 / price))), "it can buy what its spare food pays for (%d)" % TownMarket.get_obtainable(city, family, "wood"))
	TownLedger.credit(city, family, "food", 100000, "made")
	_check(TownMarket.get_obtainable(city, family, "wood") == want, "and no more than it wants, however much food it has")
	_check(FamilyInitiative.get_reachable_wood(city, family) == 40 + want, "so reach stops well short of the neighbour's pile")
	TownLedger.credit(city, family, "wood", 7, "made")
	_check(FamilyInitiative.get_reachable_wood(city, family) >= 47, "and its own wood counts")

func has_reason(terms: Array, reason: String) -> bool:
	return terms.any(func(term: Dictionary) -> bool: return str(term["reason"]) == reason)

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
