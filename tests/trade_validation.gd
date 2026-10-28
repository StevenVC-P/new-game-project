extends SceneTree

# The first neighbour (docs/FIRST_STAGE_LOOP.md, milestone 4): traders from the neutral town come
# in summer and autumn to towns a road or river links to the world; an isolated town builds a road
# out. A trader wants some goods and offers others, prices them in grain, pays less as it takes
# more, and takes nothing it has no use for. The first trade is recorded.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_isolated_town_sees_no_trader()
	test_road_out_brings_traders()
	test_barter()
	test_trader_seasons_and_departure()

	if failure_count > 0:
		push_error("Trade validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Trade validation passed.")
	quit()

# The synthetic town map (town_construction_validation.gd) has a lake but no river and no road.
func run_summer_days(city: City, days: int) -> void:
	for _day in range(days):
		city.day_of_year = 120
		city.tick()

func lay_road_north(city: City) -> void:
	var heart: Vector2i = city.trade.get_heart()
	for y in range(0, heart.y + 1):
		city.local_map[y][heart.x]["has_road"] = true
	city.construction.roads_version += 1

func test_isolated_town_sees_no_trader() -> void:
	var city: City = ConstructionTest.make_city()
	_check(city.trade.get_link() == TownTrade.LINK_NONE, "a town with no road or river is isolated")
	run_summer_days(city, 120)
	_check(city.trade.visits == 0, "no trader reaches an isolated town")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).any(func(line: String) -> bool: return line.begins_with("No road out")), "the town is told it needs a road out")

func test_road_out_brings_traders() -> void:
	var city: City = ConstructionTest.make_city()
	city.resources["wood"] = 500
	var heart: Vector2i = city.trade.get_heart()
	var tiles: Array[Vector2i] = city.construction.plan_road(heart, Vector2i(heart.x, 0))
	_check(not tiles.is_empty(), "a road can be planned from the town's heart to the map's edge")
	var project: ConstructionProject = city.construction.request_road(tiles)
	_check(project != null, "the road out is requested")
	if project == null:
		return
	ConstructionTest.run_until_built(city, project, 200)
	_check(city.trade.get_link() == TownTrade.LINK_ROAD, "a finished road out links the town, link '%s'" % city.trade.get_link())
	run_summer_days(city, 60)
	print("[TRADE] visits in 60 summer days on a road out: %d" % city.trade.visits)
	_check(city.trade.visits >= 1, "traders come once the road is built")

func test_barter() -> void:
	var city: City = ConstructionTest.make_city()
	lay_road_north(city)
	city.resources["wood"] = 400
	city.resources["food"] = 400
	city.resources["tools"] = 40
	city.resources["stone_blocks"] = 100
	city.resources["bricks"] = 100
	city.resources["carved_goods"] = 20
	city.trade.arrive(city.construction.day, TownTrade.LINK_ROAD)
	_check(city.trade.is_trader_here() and city.trade.wants.size() == EconomyBalance.TRADER_WANT_KINDS and city.trade.offers.size() == EconomyBalance.TRADER_OFFER_KINDS, "a trader wants some goods and offers others")
	for good: String in city.trade.wants.keys():
		_check(not city.trade.offers.has(good), "a trader does not offer what it wants")
	var lots: Array[Dictionary] = city.trade.get_lots()
	_check(not lots.is_empty(), "lots are on offer")
	for lot: Dictionary in lots:
		_check(city.trade.wants.has(lot["give"]), "every lot gives only what the trader wants")
	print("[TRADE] %s; first lot: %s" % [" | ".join(city.trade.get_price_lines()), TownTrade.describe_lot(lots[0])])
	var lot: Dictionary = lots[0]
	var give: String = lot["give"]
	var get_good: String = lot["get"]
	var give_before: int = int(city.resources[give])
	var get_before: int = int(city.resources[get_good])
	var bid_before: float = city.trade.get_bid(give)
	_check(city.trade.accept_lot(0), "a lot can be taken")
	_check(int(city.resources[give]) == give_before - int(lot["give_amount"]) and int(city.resources[get_good]) == get_before + int(lot["get_amount"]), "the town gives and gets the lot's goods")
	_check(not city.trade.wants.has(give) or city.trade.get_bid(give) < bid_before, "the trader pays less for a good the more of it it takes")
	var worth_given: float = float(lot["give_amount"]) * TownTrade.get_value(give)
	var worth_got: float = float(lot["get_amount"]) * TownTrade.get_value(get_good)
	_check(worth_got < worth_given, "barter has friction: the town gets less grain's worth than it gives")
	_check(city.trade.first_trade_day >= 0 and city.trade.trades_made == 1, "the first trade is recorded")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).any(func(line: String) -> bool: return line.begins_with("Trades with")), "the town is told of its trades")
	# A trader takes only what it wants, and only what the town holds.
	var poor: City = ConstructionTest.make_city()
	lay_road_north(poor)
	for good: String in EconomyBalance.TRADER_WANTS:
		poor.resources[good] = 0
	poor.trade.arrive(poor.construction.day, TownTrade.LINK_ROAD)
	_check(poor.trade.get_lots().is_empty(), "a town with nothing the trader wants is offered no lot")
	# Taking lots until the trader has had enough.
	var taken: int = 0
	while city.trade.accept_lot(0) and taken < 200:
		taken += 1
	_check(taken < 200, "a trader's wants and stock run out")

func test_trader_seasons_and_departure() -> void:
	var city: City = ConstructionTest.make_city()
	lay_road_north(city)
	run_summer_days(city, 40)
	_check(city.trade.visits >= 1, "on a road, a trader comes within a summer month or so")
	var until: int = city.trade.trader_until_day
	for _day in range(EconomyBalance.TRADER_STAY_DAYS + 2):
		city.day_of_year = 300
		city.tick()
	_check(not city.trade.is_trader_here(), "the trader leaves after its stay (was until day %d)" % until)
	var visits: int = city.trade.visits
	for _day in range(80):
		city.day_of_year = 300
		city.tick()
	_check(city.trade.visits == visits, "no trader comes in winter")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
