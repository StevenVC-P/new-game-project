class_name TownTrade
extends RefCounted

# The first neighbour (docs/FIRST_STAGE_LOOP.md, The Way To Trade; docs/ECONOMY_MODEL.md, barter
# with the neutral town). In summer and autumn a trader from the neutral town comes along the road
# or river and stays a few days. Each trader wants some goods and offers others, and reads every
# price in grain. Barter friction comes from supply and demand, not a fixed loss: the trader pays
# less for each more of a good it takes and asks more for each more it sells, and takes nothing it
# has no use for. The player picks lots (give this, get that); nothing trades on its own.
#
# A town is linked when a road joins its heart to the edge of the town map (the regional road, or
# one the player builds out to it), or a river runs within reach of its heart. Crossroads see traders more
# often, river towns less; an isolated town sees none until it builds a road out. Trading is never
# required: a self-sufficient town reaches Village without it. The first trade is recorded.
# Numbers in EconomyBalance (Trade).

const LINK_NONE: String = ""
const LINK_CROSSROADS: String = "crossroads"
const LINK_ROAD: String = "road"
const LINK_RIVER: String = "river"
const SEASON_SUMMER: int = 1
const SEASON_AUTUMN: int = 2
# Tiles from the town's heart (its stockpile) that count as the heart for a road link; boats land
# at a river within RIVER_REACH of it.
const HEART_RADIUS: int = 6
const RIVER_REACH: int = 12
const MAX_LOTS: int = 6

var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# The neutral town traders come from; the game names it after the nearest one.
var partner_name: String = "the market town"
# The trader in town: until which day (TownConstruction.day), what it still wants (good -> units)
# and still offers, and what it has taken and sold this visit (for its prices).
var trader_until_day: int = -1
var wants: Dictionary = {}
var offers: Dictionary = {}
var taken: Dictionary = {}
var sold: Dictionary = {}
var next_visit_day: int = -1
var visits: int = 0
var trades_made: int = 0
var first_trade_day: int = -1
var last_trade_text: String = ""
var _link: String = ""
var _link_version: int = -1

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func is_trader_here() -> bool:
	return trader_until_day >= 0 and city.construction.day <= trader_until_day

func advance_day() -> void:
	if not has_map():
		return
	var today: int = city.construction.day
	if trader_until_day >= 0 and today > trader_until_day:
		trader_until_day = -1
		wants.clear()
		offers.clear()
	var season: int = city.get_season_index()
	if season != SEASON_SUMMER and season != SEASON_AUTUMN:
		next_visit_day = -1
		return
	var link: String = get_link()
	if link == LINK_NONE or is_trader_here():
		return
	if next_visit_day < 0:
		next_visit_day = today + int(roll(0, 9999) % maxi(1, get_visit_interval(link)))
	if today >= next_visit_day:
		arrive(today, link)

# A trader arrives: what it wants and offers this visit, and when the next one comes.
func arrive(today: int, link: String) -> void:
	visits += 1
	trader_until_day = today + EconomyBalance.TRADER_STAY_DAYS
	taken.clear()
	sold.clear()
	wants = choose_goods(EconomyBalance.TRADER_WANTS, EconomyBalance.TRADER_WANT_KINDS, {}, "wants")
	offers = choose_goods(EconomyBalance.TRADER_OFFERS, EconomyBalance.TRADER_OFFER_KINDS, wants, "offers")
	next_visit_day = trader_until_day + get_visit_interval(link) + roll(0, EconomyBalance.TRADER_INTERVAL_JITTER_DAYS)

func choose_goods(pool: Array[String], count: int, exclude: Dictionary, salt: String) -> Dictionary:
	var candidates: Array[String] = []
	for good: String in pool:
		if not exclude.has(good):
			candidates.append(good)
	var chosen: Dictionary = {}
	var rng: RandomNumberGenerator = make_rng(salt)
	while chosen.size() < count and not candidates.is_empty():
		var good: String = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		chosen[good] = maxi(1, int(EconomyBalance.TRADER_GRAIN_PER_GOOD / get_value(good)))
	return chosen

func make_rng(salt: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), visits, salt])
	return rng

func roll(low: int, high: int) -> int:
	return make_rng("visit").randi_range(low, high)

func get_visit_interval(link: String) -> int:
	return int(EconomyBalance.TRADER_INTERVAL_DAYS.get(link, 0))

static func get_value(good: String) -> float:
	return float(EconomyBalance.VALUE_IN_GRAIN.get(good, 1.0))

# What the trader pays, in grain, for one more unit of a good it wants: less the more it has taken.
func get_bid(good: String) -> float:
	var capacity: float = float(int(wants.get(good, 0)) + int(taken.get(good, 0)))
	var share: float = float(taken.get(good, 0)) / maxf(1.0, capacity)
	return get_value(good) * EconomyBalance.TRADER_BID_SHARE * (1.0 - EconomyBalance.TRADER_PRICE_SLOPE * share)

# What the trader asks, in grain, for one more unit it offers: more the more it has sold.
func get_ask(good: String) -> float:
	var capacity: float = float(int(offers.get(good, 0)) + int(sold.get(good, 0)))
	var share: float = float(sold.get(good, 0)) / maxf(1.0, capacity)
	return get_value(good) * EconomyBalance.TRADER_ASK_SHARE * (1.0 + EconomyBalance.TRADER_PRICE_SLOPE * share)

# The lots on offer now: give a lot of a good the trader wants and the town holds, get as much of
# an offered good as it is worth to the trader. Each lot is worth about TRADER_LOT_GRAIN.
func get_lots() -> Array[Dictionary]:
	var lots: Array[Dictionary] = []
	if not is_trader_here():
		return lots
	for give: String in wants.keys():
		var give_amount: int = mini(int(wants[give]), maxi(1, roundi(EconomyBalance.TRADER_LOT_GRAIN / get_value(give))))
		if give_amount <= 0 or int(city.resources.get(give, 0)) < give_amount:
			continue
		for get_good: String in offers.keys():
			var worth: float = float(give_amount) * get_bid(give)
			var get_amount: int = mini(int(offers[get_good]), int(worth / get_ask(get_good)))
			if get_amount >= 1:
				lots.append({"give": give, "give_amount": give_amount, "get": get_good, "get_amount": get_amount})
	return lots.slice(0, MAX_LOTS)

func accept_lot(index: int) -> bool:
	var lots: Array[Dictionary] = get_lots()
	if index < 0 or index >= lots.size():
		return false
	var lot: Dictionary = lots[index]
	var give: String = lot["give"]
	var get_good: String = lot["get"]
	city.resources[give] = int(city.resources[give]) - int(lot["give_amount"])
	city.resources[get_good] = int(city.resources.get(get_good, 0)) + int(lot["get_amount"])
	wants[give] = int(wants[give]) - int(lot["give_amount"])
	taken[give] = int(taken.get(give, 0)) + int(lot["give_amount"])
	offers[get_good] = int(offers[get_good]) - int(lot["get_amount"])
	sold[get_good] = int(sold.get(get_good, 0)) + int(lot["get_amount"])
	if int(wants[give]) <= 0:
		wants.erase(give)
	if int(offers[get_good]) <= 0:
		offers.erase(get_good)
	trades_made += 1
	if first_trade_day < 0:
		first_trade_day = city.construction.day
	last_trade_text = describe_lot(lot)
	return true

static func describe_lot(lot: Dictionary) -> String:
	return "%d %s for %d %s" % [int(lot["give_amount"]), get_good_name(lot["give"]), int(lot["get_amount"]), get_good_name(lot["get"])]

static func get_good_name(good: String) -> String:
	return str(GoodsNeedBucketHelper.GOOD_DISPLAY_NAMES.get(good, good)).to_lower()

# How traders reach the town, worked out again whenever roads change.
func get_link() -> String:
	if not has_map():
		return LINK_NONE
	if _link_version != city.construction.roads_version:
		_link_version = city.construction.roads_version
		_link = find_link()
	return _link

func find_link() -> String:
	if road_reaches_edge():
		return LINK_CROSSROADS if city.site_profile != null and city.site_profile.tags.has("crossroads") else LINK_ROAD
	if river_passes_heart():
		return LINK_RIVER
	return LINK_NONE

func get_heart() -> Vector2i:
	var heart: Vector2i = city.logistics.stockpile_tile
	if heart.x < 0:
		heart = city.logistics.map_size() / 2
	return heart

func is_near_heart(tile: Vector2i, radius: int = HEART_RADIUS) -> bool:
	var heart: Vector2i = get_heart()
	return maxi(absi(tile.x - heart.x), absi(tile.y - heart.y)) <= radius

# A road (regional or built) runs from within the heart to the map's edge.
func road_reaches_edge() -> bool:
	var size: Vector2i = city.logistics.map_size()
	var open: Array[Vector2i] = []
	var seen: Dictionary = {}
	for y in range(size.y):
		for x in range(size.x):
			var tile: Vector2i = Vector2i(x, y)
			if is_near_heart(tile) and has_road(tile):
				open.append(tile)
				seen[tile] = true
	while not open.is_empty():
		var tile: Vector2i = open.pop_back()
		if tile.x == 0 or tile.y == 0 or tile.x == size.x - 1 or tile.y == size.y - 1:
			return true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var next: Vector2i = tile + step
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or seen.has(next) or not has_road(next):
				continue
			seen[next] = true
			open.append(next)
	return false

func has_road(tile: Vector2i) -> bool:
	return (city.local_map[tile.y][tile.x] as Dictionary).get("has_road", false) == true

func river_passes_heart() -> bool:
	var size: Vector2i = city.logistics.map_size()
	for y in range(size.y):
		for x in range(size.x):
			var data: Dictionary = city.local_map[y][x]
			if data["type"] == "water" and data.get("water_kind", "") == "river" and is_near_heart(Vector2i(x, y), RIVER_REACH):
				return true
	return false

# Sidebar lines: the trader in town, how traders reach the town, the first trade.
func get_notices() -> Array[String]:
	var lines: Array[String] = []
	if not has_map():
		return lines
	# A trader in town is an alert in the top bar (TownStatusBar) and has its own sidebar section.
	if not is_trader_here():
		match get_link():
			LINK_NONE:
				lines.append("No road out: traders cannot reach the town (build a road (G) from the town to the map's edge)")
			LINK_RIVER:
				lines.append("Traders come by river in summer and autumn")
			_:
				lines.append("Traders come by road in summer and autumn" + (" (a crossroads: often)" if get_link() == LINK_CROSSROADS else ""))
	if first_trade_day >= 0:
		lines.append("Trades with %s: %d (first on day %d)" % [partner_name, trades_made, first_trade_day])
	return lines

# Prices in grain at the trader, for the panel: what it pays for what it wants, and what it asks
# for what it offers.
func get_price_lines() -> Array[String]:
	var pays: Array[String] = []
	for good: String in wants.keys():
		pays.append("%s %.1f" % [get_good_name(good), get_bid(good)])
	var asks: Array[String] = []
	for good: String in offers.keys():
		asks.append("%s %.1f" % [get_good_name(good), get_ask(good)])
	return ["Pays (grain): " + (", ".join(pays) if not pays.is_empty() else "wants nothing more"), "Asks: " + (", ".join(asks) if not asks.is_empty() else "has nothing more")]
