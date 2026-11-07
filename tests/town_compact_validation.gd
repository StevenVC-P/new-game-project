extends SceneTree

# The founding compact (sprint S7, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md; owner's S7 guidance
# 2026-11-05): a holding's work is shared between the community and the working family at the
# compact's rate; along a production chain inputs go back to their owners and only the worth the work
# added is shared, so nothing is claimed twice; families eat and warm from their own goods first,
# keep their side work, pay for their own projects from it, and may give more by their values;
# pooled, nothing changes.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_pooled_gives_everything_to_the_community()
	test_presets_and_rates()
	test_a_holding_is_shared_at_the_rate()
	test_a_chain_claims_nothing_twice()
	test_families_eat_their_own_first()
	test_neighbours_can_share_food_they_own()
	test_hearths_burn_their_own_wood_first()
	test_side_work_is_the_familys()
	test_a_family_can_pay_from_its_own()
	test_upkeep_of_a_family_holding()
	test_values_lean_families_to_give_more()
	test_it_survives_a_save()
	if failure_count > 0:
		push_error("Town compact validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town compact validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func worked_by(household: Household) -> Building:
	var building: Building = Building.new(-1, "farm", Vector2i(2, 2), Vector2i(2, 2))
	building.assigned_household_id = household.id
	return building

func test_pooled_gives_everything_to_the_community() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownCompact.deliver_output(city, worked_by(family), "food", 10, {})
	_check(not TownCompact.is_set(city) and TownLedger.get_share(family, "food") == 0, "pooled, a holding's work is the community's")
	_check(TownCompact.get_rate(city, "tools") == 1.0, "pooled is everything to the community")

func test_presets_and_rates() -> void:
	var city: City = town()
	TownCompact.change_rate(city, TownCompact.FOOD, -3)
	_check(TownCompact.is_set(city) and is_equal_approx(TownCompact.get_rate(city, "food"), 0.7) and TownCompact.get_rate(city, "wood") == 1.0, "a pooled town's first change starts a compact from everything given")
	_check(TownCompact.get_preset(city) == "", "mixed rates match no preset")
	TownCompact.set_preset(city, "private")
	_check(is_equal_approx(TownCompact.get_rate(city, "bricks"), 0.2) and TownCompact.get_preset(city) == "private", "a preset sets every category")
	_check(TownCompact.get_category("bricks") == TownCompact.STONE and TownCompact.get_category("statues") == TownCompact.GOODS, "goods fall in their categories")
	TownCompact.change_rate(city, TownCompact.WOOD, -5)
	_check(TownCompact.get_rate(city, "wood") == 0.0, "rates stop at nothing")

func test_a_holding_is_shared_at_the_rate() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownCompact.set_preset(city, "shared")
	var farm: Building = worked_by(family)
	var before: int = int(city.resources["food"])
	for _day in range(10):
		TownCompact.deliver_output(city, farm, "food", 3, {})
	_check(int(city.resources["food"]) == before + 30, "everything made enters the store")
	_check(TownLedger.get_share(family, "food") == 12, "the family keeps 40%% of its farm's food: %d" % TownLedger.get_share(family, "food"))
	var empty: Building = Building.new(-1, "farm", Vector2i(2, 2), Vector2i(2, 2))
	TownCompact.deliver_output(city, empty, "food", 5, {})
	_check(TownLedger.get_share(family, "food") == 12, "a workplace nobody works gives everything to the community")

# A toolmaker turns 2 wood (worth 3) into a tool (worth 10): the work adds 7.
func test_a_chain_claims_nothing_twice() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	var shop: Building = worked_by(family)
	TownCompact.set_preset(city, "communal")
	TownCompact.deliver_output(city, shop, "tools", 10, {"wood": {family.id: 20}})
	_check(TownLedger.get_share(family, "tools") == 3, "at 100%%, tools made of the family's own wood give it back its wood's worth (3 of 10): %d" % TownLedger.get_share(family, "tools"))
	TownLedger.set_share(family, "tools", 0)
	shop.share_carry = 0.0
	TownCompact.set_preset(city, "shared")
	TownCompact.deliver_output(city, shop, "tools", 10, {"wood": {TownLedger.COMMUNITY: 20}})
	_check(TownLedger.get_share(family, "tools") == 2, "of the community's wood, the family gets only its 40%% of the work's 7 (2.8 of 10): %d" % TownLedger.get_share(family, "tools"))
	TownLedger.set_share(family, "tools", 0)
	shop.share_carry = 0.0
	TownCompact.deliver_output(city, shop, "tools", 10, {"wood": {family.id: 20}})
	_check(TownLedger.get_share(family, "tools") == 5, "of its own wood, the wood's worth and 40%% of the work's (5.8 of 10): %d" % TownLedger.get_share(family, "tools"))
	# Through the city: a workshop draws its family's own wood first.
	TownLedger.set_share(family, "tools", 0)
	TownLedger.credit(city, family, "wood", 4, "made")
	var community_wood: int = TownLedger.get_community(city, "wood")
	city.apply_input_output_production("tools", 2, {"wood": 2}, shop)
	_check(TownLedger.get_share(family, "wood") == 0 and TownLedger.get_community(city, "wood") == community_wood, "the workshop used the family's own wood, not the community's")

func test_families_eat_their_own_first() -> void:
	var city: City = town()
	var fed: Household = city.households[0]
	TownCompact.set_preset(city, "private")
	city.resources["food"] = 0
	for household: Household in city.households:
		household.larder = 0.0
	TownLedger.credit(city, fed, "food", 50, "made")
	city.consume_food()
	_check(not fed.short_today, "a family with food of its own eats when the table is bare")
	_check(city.households.slice(1).all(func(h: Household) -> bool: return h.short_today), "the others go short: the family's food is not the table's")
	_check(TownLedger.get_share(fed, "food") < 50 and TownLedger.get_shares_total(city, "food") <= int(city.resources["food"]), "it ate from its own share")
	city.add_resource("food", 200, "made")
	var family_food: int = TownLedger.get_share(fed, "food")
	for _day in range(3):
		city.consume_food()
	_check(city.households.all(func(h: Household) -> bool: return not h.short_today), "the common table feeds everyone else")
	_check(TownLedger.get_share(fed, "food") < family_food, "the family still eats its own before the table's")

# Sharing in a shortage (TownSocial) gives real food from what the donor owns: its larder and,
# under a compact, its food in the store.
func test_neighbours_can_share_food_they_own() -> void:
	var city: City = town()
	TownCompact.set_preset(city, "private")
	var donor: Household = city.households[0]
	var recipient: Household = city.households[1]
	donor.larder = 0.0
	recipient.larder = 0.0
	_check(not HouseholdEconomy.can_give_food(donor, recipient), "with nothing of its own a family can't give food")
	TownLedger.credit(city, donor, "food", 100, "made")
	_check(HouseholdEconomy.can_give_food(donor, recipient), "its food in the store is its to give")
	var stock: int = int(city.resources["food"])
	HouseholdEconomy.give_food(city, donor, recipient)
	_check(TownLedger.get_share(recipient, "food") > 0 and TownLedger.get_share(donor, "food") + TownLedger.get_share(recipient, "food") == 100, "the gift passes from the donor's share to the recipient's")
	_check(int(city.resources["food"]) == stock, "the food stays in the store")

func test_hearths_burn_their_own_wood_first() -> void:
	var city: City = town()
	var warm: Household = city.households[0]
	TownCompact.set_preset(city, "private")
	city.day_of_year = Calendar.DAYS_PER_YEAR - 10
	city.resources["wood"] = 0
	TownLedger.credit(city, warm, "wood", 40, "made")
	if TownFuel.get_household_need(city, warm, city.get_season_index()) <= 0.0:
		print("[COMPACT] the test site needs no winter fuel; hearth test skipped")
		return
	TownFuel.burn(city)
	_check(not warm.cold_today, "a family with wood of its own keeps warm when the store is bare")
	_check(city.households.slice(1).any(func(h: Household) -> bool: return h.cold_today), "families without go cold")
	_check(TownLedger.get_share(warm, "wood") <= 40, "it burned its own")

func test_side_work_is_the_familys() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	HouseholdEconomy.deliver_wood(city, family)
	_check(TownLedger.get_share(family, "wood") == 0, "pooled, gathered wood is the community's")
	TownCompact.set_preset(city, "communal")
	HouseholdEconomy.deliver_wood(city, family)
	_check(TownLedger.get_share(family, "wood") == 1, "under any compact, side work is the family's own")

func test_a_family_can_pay_from_its_own() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownCompact.set_preset(city, "private")
	var cost: Dictionary = {"wood": 600}
	_check(not city.construction.can_supply(cost), "the community's 500 wood can't pay for 600")
	TownLedger.credit(city, family, "wood", 150, "made")
	_check(city.construction.can_supply(cost, {}, family), "the family's own 150 and the community's can")
	_check(not city.construction.can_supply(cost, {}, city.households[1]), "another family can't count it")
	_check(FamilyInitiative.get_spending_risk(city, {"wood": 100}, family) < FamilyInitiative.get_spending_risk(city, {"wood": 100}), "a family weighs a cost against what it can draw on")

func test_upkeep_of_a_family_holding() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownCompact.set_preset(city, "private")
	var holding: Building = worked_by(family)
	TownLedger.add_funding(holding.funded, "wood", {family.id: 20})
	_check(city.get_upkeep_payer(holding) == family, "a family keeps up the workplace it paid for")
	var communal: Building = worked_by(family)
	_check(city.get_upkeep_payer(communal) == null, "the community keeps up its own")

func test_values_lean_families_to_give_more() -> void:
	var city: City = town()
	TownCompact.set_preset(city, "private")
	var giver: Household = city.households[0]
	var keeper: Household = city.households[1]
	giver.values = {}
	keeper.values = {}
	giver.value_strengths = {"common_stores": 3, "sharing": 2}
	keeper.value_strengths = {"private_holdings": 3, "acquisitive": 2}
	for household: Household in [giver, keeper]:
		household.trust = 0
		TownLedger.credit(city, household, "stone_blocks", 100, "made")
	_check(TownCompact.get_giving_lean(giver) > 0.0 and TownCompact.get_giving_lean(keeper) < 0.0, "Common Stores and Sharing lean toward giving, Private Holdings and Acquisitive away: %.1f, %.1f" % [TownCompact.get_giving_lean(giver), TownCompact.get_giving_lean(keeper)])
	TownCompact.advance_month(city)
	_check(TownLedger.get_share(giver, "stone_blocks") < 100 and giver.given_to_community > 0, "a communal-minded family gives some of what it doesn't need")
	_check(TownLedger.get_share(keeper, "stone_blocks") == 100, "a private-minded family keeps its own")
	_check(int(city.compact_given.get("stone_blocks", 0)) == 100 - TownLedger.get_share(giver, "stone_blocks"), "the town records what was given")
	var food_keep: int = TownCompact.get_keep(city, giver, "food")
	TownLedger.credit(city, giver, "food", food_keep, "made")
	TownCompact.advance_month(city)
	_check(TownLedger.get_share(giver, "food") == food_keep, "it never gives away the food it needs itself")

func test_it_survives_a_save() -> void:
	var city: City = town()
	TownCompact.set_preset(city, "shared")
	city.compact_given["food"] = 4
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.compact == city.compact and int(restored.compact_given.get("food", 0)) == 4, "the compact survives a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
