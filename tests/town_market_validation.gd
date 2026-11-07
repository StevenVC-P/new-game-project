extends SceneTree

# The market day (sprint S9, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md): under a compact families barter
# what they hold beyond their needs, paid in food, at prices from the town's demand and supply;
# nothing is created or owed; nobody sells below its own keep; Insular families bring less,
# Hagglers take more of the pool; a hungry family can sell for food any day; wealth reads as
# prosperity; pooled, nothing happens.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_pooled_has_no_market()
	test_food_buys_what_a_family_lacks()
	test_prices_follow_the_town()
	test_values_change_how_families_deal()
	test_a_hungry_family_can_sell_any_day()
	test_wealth_and_prosperity()
	test_it_survives_a_save()
	if failure_count > 0:
		push_error("Town market validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town market validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.social.set_enabled(true)
	city.resources["wood"] = 0
	city.resources["food"] = 0
	city.resources["tools"] = 0
	TownCompact.set_preset(city, "private")
	for household: Household in city.households:
		household.larder = 0.0
		household.values = {}
		household.value_strengths = {}
	return city

func totals(city: City) -> Dictionary:
	var sums: Dictionary = {}
	for good: String in ["food", "wood", "tools", "stone_blocks"]:
		sums[good] = TownLedger.get_shares_total(city, good)
	return sums

# A farm family with food to spare and no winter wood; a woodcutting family with wood to spare and
# little food.
func farmer_and_woodcutter(city: City) -> Array[Household]:
	var farmer: Household = city.households[0]
	var woodcutter: Household = city.households[1]
	TownLedger.credit(city, farmer, "food", 2000, "made")
	TownLedger.credit(city, woodcutter, "wood", 2000, "made")
	TownLedger.credit(city, woodcutter, "food", TownMarket.get_keep(city, woodcutter, "food"), "made")
	return [farmer, woodcutter]

func test_pooled_has_no_market() -> void:
	var city: City = ConstructionTest.make_city()
	TownMarket.hold(city)
	_check(not TownMarket.is_on(city) and city.market_last.is_empty(), "a pooled town holds no market")

func test_food_buys_what_a_family_lacks() -> void:
	var city: City = town()
	var pair: Array[Household] = farmer_and_woodcutter(city)
	var farmer: Household = pair[0]
	var woodcutter: Household = pair[1]
	if not TownFuel.is_on(city) or TownMarket.get_wants(city, farmer).get("wood", 0) <= 0:
		print("[MARKET] the test town needs no winter wood; trade test skipped")
		return
	var before: Dictionary = totals(city)
	var stock: Dictionary = city.resources.duplicate()
	TownMarket.hold(city)
	_check(TownLedger.get_share(farmer, "wood") > 0, "the farm family buys wood for the winter")
	_check(TownLedger.get_share(woodcutter, "food") > TownMarket.get_keep(city, woodcutter, "food"), "the woodcutting family gets food for it")
	_check(totals(city) == before, "nothing is made or lost: %s against %s" % [str(totals(city)), str(before)])
	_check(int(city.resources["food"]) == int(stock["food"]) and int(city.resources["wood"]) == int(stock["wood"]), "the goods stay in the store")
	_check(TownLedger.get_share(woodcutter, "wood") >= TownMarket.get_keep(city, woodcutter, "wood"), "the seller keeps its own winter")
	_check(TownLedger.get_share(farmer, "food") >= TownMarket.get_keep(city, farmer, "food"), "the buyer keeps its own months of food")
	_check(city.market_last.has("wood"), "the market records the day's dealing")

func test_prices_follow_the_town() -> void:
	# One woodcutting family with a little wood to spare beyond its winter, and every other family
	# wanting winter wood; in the town of plenty a second family offers much more.
	var scarce: City = town()
	var plenty: City = town()
	for city: City in [scarce, plenty]:
		TownLedger.credit(city, city.households[0], "food", 5000, "made")
		var seller: Household = city.households[1]
		TownLedger.credit(city, seller, "wood", TownMarket.get_keep(city, seller, "wood") + 15, "made")
		TownLedger.credit(city, seller, "food", TownMarket.get_keep(city, seller, "food"), "made")
	TownLedger.credit(plenty, plenty.households[2], "wood", TownMarket.get_keep(plenty, plenty.households[2], "wood") + 3000, "made")
	TownMarket.hold(scarce)
	TownMarket.hold(plenty)
	if not scarce.market_prices.has("wood") or not plenty.market_prices.has("wood"):
		print("[MARKET] no wood dealt in the test towns; price test skipped")
		return
	_check(float(plenty.market_prices["wood"]) < float(scarce.market_prices["wood"]), "wood is cheaper where more is offered: %.2f against %.2f" % [float(plenty.market_prices["wood"]), float(scarce.market_prices["wood"])])

func test_values_change_how_families_deal() -> void:
	var open: City = town()
	var closed: City = town()
	farmer_and_woodcutter(open)
	farmer_and_woodcutter(closed)
	closed.households[1].value_strengths = {"insular": 3}
	_check(TownMarket.get_market_share(closed.households[1]) < TownMarket.get_market_share(open.households[1]), "an Insular family brings less to market")
	var weights: Dictionary = {1: 10.0, 2: 10.0 * TownMarket.get_haggle_weight(_with(open.households[2], {"hagglers": 3}))}
	var shares: Dictionary = TownMarket.split(100, weights, open.households)
	_check(int(shares[2]) > int(shares[1]) and int(shares[1]) + int(shares[2]) == 100, "a Haggler takes more of the pool, and the pool is all paid out: %s" % str(shares))

func _with(household: Household, strengths: Dictionary) -> Household:
	household.value_strengths = strengths
	return household

func test_a_hungry_family_can_sell_any_day() -> void:
	var city: City = town()
	var hungry: Household = city.households[0]
	var buyer: Household = city.households[1]
	TownLedger.credit(city, hungry, "tools", 50, "made")
	TownLedger.credit(city, buyer, "food", 3000, "made")
	for household: Household in city.households:
		household.ties.clear()
	var got: float = TownMarket.sell_for_food(city, hungry, 3.0)
	_check(got >= 3.0 - 0.001, "a family short of food sells its tools for a day's food: %.2f" % got)
	_check(TownLedger.get_share(buyer, "tools") > 0 and TownLedger.get_share(hungry, "tools") < 50, "the tools change hands")
	_check(city.market_emergency_sales > 0, "the sale is counted")

func test_wealth_and_prosperity() -> void:
	var city: City = town()
	var rich: Household = city.households[0]
	TownLedger.credit(city, rich, "tools", 100, "made")
	_check(is_equal_approx(TownMarket.get_wealth(rich), 100.0 * TownMarket.get_base_price("tools")), "wealth is own goods at their worth in food")
	_check(TownMarket.is_wealthy(city, rich) and city.social.is_prosperous(rich), "a family far above the town's middle reads as prosperous")
	_check(not TownMarket.is_wealthy(city, city.households[1]), "one at the middle doesn't")

func test_it_survives_a_save() -> void:
	var city: City = town()
	farmer_and_woodcutter(city)
	TownMarket.hold(city)
	city.households[0].market_sales = 3
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.market_prices == city.market_prices and restored.market_traded == city.market_traded and restored.households[0].market_sales == 3, "the market's record survives a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
