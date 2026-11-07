extends SceneTree

# The commons and asking for help (sprint S8, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md): under a
# compact the table's reserve is kept for families in danger; without a reserve every family eats
# alike; a hungry family asks those it knows, who give from their own as their values move them;
# grants follow the player's rule and keep what the town needs; pooled, none of it applies.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_pooled_is_untouched()
	test_without_a_reserve_everyone_eats_alike()
	test_the_reserve_is_for_families_in_danger()
	test_own_means_before_the_reserve()
	test_neighbours_answer_a_hungry_family()
	test_values_decide_who_gives()
	test_grants_follow_the_rule()
	test_it_survives_a_save()
	if failure_count > 0:
		push_error("Town commons validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town commons validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.social.set_enabled(true)
	city.resources["wood"] = 500
	TownCompact.set_preset(city, "private")
	for household: Household in city.households:
		household.larder = 0.0
		household.severe_hunger_months = 0
		household.severe_cold_months = 0
	return city

func need_of(city: City) -> float:
	var total: float = 0.0
	for household: Household in city.households:
		total += HouseholdEconomy.get_daily_need(household)
	return total

func test_pooled_is_untouched() -> void:
	var city: City = ConstructionTest.make_city()
	city.commons_reserve_days = 30
	_check(not TownCommons.is_on(city) and TownCommons.get_reserve(city) == 0, "a pooled town has no commons' rules")

func test_without_a_reserve_everyone_eats_alike() -> void:
	var city: City = town()
	city.resources["food"] = int(floor(need_of(city) * 0.5))
	city.consume_food()
	_check(city.households.all(func(h: Household) -> bool: return h.short_today), "half the town's food leaves every family short alike")
	_check(int(city.resources["food"]) == 0, "and is all eaten")

func test_the_reserve_is_for_families_in_danger() -> void:
	var city: City = town()
	TownCommons.set_reserve_days(city, 30)
	var reserve: int = TownCommons.get_reserve(city)
	_check(reserve > 0, "a 30-day reserve keeps food back")
	city.resources["food"] = reserve
	var danger: Household = city.households[0]
	danger.severe_hunger_months = 1
	city.consume_food()
	_check(not danger.short_today, "a family in danger eats from the reserve")
	_check(city.households.slice(1).all(func(h: Household) -> bool: return h.short_today), "the others don't")
	_check(int(city.resources["food"]) < reserve and int(city.resources["food"]) >= reserve - int(ceil(HouseholdEconomy.get_daily_need(danger))), "only the family in danger's day came out of it")

# Own means first, the player's reserve last (owner, 2026-11-07).
func test_own_means_before_the_reserve() -> void:
	var city: City = town()
	TownCommons.set_reserve_days(city, 30)
	var reserve: int = TownCommons.get_reserve(city)
	city.resources["food"] = reserve
	var danger: Household = city.households[0]
	danger.severe_hunger_months = 1
	danger.larder = HouseholdEconomy.get_daily_need(danger) * 2.0
	var larder: float = danger.larder
	city.consume_food()
	_check(danger.larder < larder and int(city.resources["food"]) == reserve and not danger.short_today, "a family in danger eats its own larder and the reserve stays whole")
	danger.larder = 0.0
	city.consume_food()
	_check(int(city.resources["food"]) < reserve and not danger.short_today, "the reserve answers once its own food is gone")

func test_neighbours_answer_a_hungry_family() -> void:
	var city: City = town()
	var hungry: Household = city.households[0]
	var giver: Household = city.households[1]
	giver.values = {}
	giver.value_strengths = {"sharing": 3, "charitable": 3}
	HouseholdMemory.touch_tie(city, hungry, giver, 1, "neighbours")
	city.resources["food"] = 0
	TownLedger.credit(city, giver, "food", 200, "made")
	city.consume_food()
	_check(not hungry.short_today, "a hungry family is fed by a neighbour who will give")
	_check(city.commons_help_asked > 0 and city.commons_help_given > 0.0, "the asking and the giving are counted")
	var help_before: int = giver.help_given
	_check(help_before >= 1 and HouseholdMemory.get_disposition(hungry, giver.id) > 1, "the help warms the tie and counts for the giver: help %d, disposition %d" % [help_before, HouseholdMemory.get_disposition(hungry, giver.id)])
	city.consume_food()
	_check(giver.help_given == help_before, "a second day in the same month counts the tie once: %d then %d" % [help_before, giver.help_given])
	# Drain the giver down to its own month, then ask again: it gives no further.
	TownLedger.set_share(giver, "food", int(ceil(float(EconomyBalance.HELP_KEEPS_FOOD_DAYS) * HouseholdEconomy.get_daily_need(giver))))
	giver.share_food_owed = 0.0
	var kept: int = TownLedger.get_share(giver, "food")
	_check(TownCommons.ask_for_food(city, hungry, 5.0) < 1.0 and TownLedger.get_share(giver, "food") >= kept - 1, "the giver keeps its own month")

func test_values_decide_who_gives() -> void:
	var city: City = town()
	var hungry: Household = city.households[0]
	# Not kin: kin owe each other help whatever their values (SocialDecisions.get_kin_obligation).
	var kin: Array[Household] = city.social.get_kin(hungry)
	var strangers: Array[Household] = city.households.slice(1).filter(func(h: Household) -> bool: return not kin.has(h))
	if strangers.is_empty():
		print("[COMMONS] every family in the test town is kin to household 0; values test skipped")
		return
	var keeper: Household = strangers[0]
	keeper.values = {}
	keeper.value_strengths = {"acquisitive": 3, "each_to_their_own": 3, "thrifty": 3}
	keeper.personality = {}
	HouseholdMemory.touch_tie(city, hungry, keeper, 1, "neighbours")
	city.resources["food"] = 0
	# The keeper is the only family with food of its own, so the only one that could give.
	TownLedger.credit(city, keeper, "food", 200, "made")
	var desire: Dictionary = SocialDecisions.get_share_desire(city, keeper, hungry)
	city.consume_food()
	_check(hungry.short_today, "a family that holds on to what it has doesn't give: %.2f %s" % [float(desire["score"]), str(desire["terms"])])
	_check(TownLedger.get_share(keeper, "food") >= 200 - int(ceil(HouseholdEconomy.get_daily_need(keeper))), "and keeps its food, eating only its own day: %d" % TownLedger.get_share(keeper, "food"))

func test_grants_follow_the_rule() -> void:
	var city: City = town()
	var short_one: Household = city.households[0]
	city.resources["food"] = 10000
	short_one.short_days_this_month = 3
	TownCommons.set_grants(city, TownCommons.GRANTS_IN_NEED)
	TownCommons.advance_month(city)
	_check(TownLedger.get_share(short_one, "food") > 0, "a family in need gets a grant")
	_check(city.households.slice(1).all(func(h: Household) -> bool: return TownLedger.get_share(h, "food") == 0 or TownCommons.is_in_danger(h) or h.short_days_this_month > 0 or TownSocial.is_in_need(city, h)), "families not in need get none")
	var keeps: int = TownCommons.get_reserve(city) + EconomyBalance.GRANT_KEEPS_DAYS * city.get_food_consumption_for_population(city.get_total_population())
	_check(TownLedger.get_community(city, "food") >= keeps, "the community keeps two months and its reserve")
	TownCommons.set_grants(city, TownCommons.GRANTS_EQUAL)
	TownCommons.advance_month(city)
	_check(city.households.all(func(h: Household) -> bool: return TownLedger.get_share(h, "food") > 0), "every family alike gets one")
	var poor: City = town()
	poor.resources["food"] = 10
	TownCommons.set_grants(poor, TownCommons.GRANTS_EQUAL)
	TownCommons.advance_month(poor)
	_check(not poor.commons_granted.has("food"), "a community with no food to spare grants no food")

func test_it_survives_a_save() -> void:
	var city: City = town()
	TownCommons.set_reserve_days(city, 60)
	TownCommons.set_grants(city, TownCommons.GRANTS_EQUAL)
	city.commons_help_month["1:2"] = 4
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.commons_reserve_days == 60 and restored.commons_grants == TownCommons.GRANTS_EQUAL and int(restored.commons_help_month.get("1:2", 0)) == 4, "the commons' rules survive a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
