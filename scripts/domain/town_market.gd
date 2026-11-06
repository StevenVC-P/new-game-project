class_name TownMarket
extends RefCounted

# The market day (sprint S9, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md; owner decision D2;
# PROPERTY_AND_COMMUNAL_RESOURCES.md §4.5). Under a compact, once a month, families barter what they
# hold beyond their own needs for what they lack. Food is the medium: a good's price in food is its
# worth scaled by the town's own demand against supply. It clears in aggregate, good by good: nothing
# is owed afterwards, no credit. Goods stay in the one store; only whose they are changes.
#
# Values decide how families deal: Insular families bring less to market, Hagglers take a larger cut
# of what buyers pay. A family short of food on any day may sell goods for food to a family with food
# to spare (sell_for_food; D2: the calendar never blocks a necessary exchange). Wealth is a level
# (get_wealth) that prosperity reads under a compact. Pooled towns hold nothing of their own to trade.

static func is_on(city: City) -> bool:
	return TownCompact.is_set(city)

# A good's worth in food.
static func get_base_price(good: String) -> float:
	return TownCompact.get_value(good) / TownCompact.get_value("food")

# The price at the last market day, else its worth.
static func get_price(city: City, good: String) -> float:
	return float(city.market_prices.get(good, get_base_price(good)))

# What a family keeps before it offers any: its months of food and winter fuel, and what its own
# sites still wait for.
static func get_keep(city: City, household: Household, good: String) -> int:
	var keep: float = 0.0
	if good == "food":
		keep += HouseholdEconomy.get_daily_need(household) * float(EconomyBalance.MARKET_KEEPS_FOOD_DAYS)
	elif good == "wood" and TownFuel.is_on(city):
		keep += TownFuel.get_household_need(city, household, 3) * float(EconomyBalance.MARKET_WANTS_FUEL_DAYS)
	keep += float(get_project_need(city, household, good))
	return int(ceil(keep))

static func get_project_need(city: City, household: Household, good: String) -> int:
	var need: int = 0
	for project: ConstructionProject in city.construction.projects:
		if project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and project.requester_household_id == household.id:
			need += int(project.get_remaining_materials().get(good, 0))
	return need

# What a family would buy, good -> units: wood for the winter, materials its own sites wait for,
# and tools for the holding it keeps up. (It wants food too, but food is what goods are paid in: it
# gets food by selling.)
static func get_wants(city: City, household: Household) -> Dictionary:
	var wants: Dictionary = {}
	for good: String in TownLedger.SHOWN_GOODS:
		if good == "food":
			continue
		var want: int = get_keep(city, household, good) - TownLedger.get_share(household, good)
		if good == "tools":
			var holding: Building = FamilyInitiative.get_holding(city, household)
			if holding != null and city.get_upkeep_payer(holding) == household:
				want = maxi(want, 2 * holding.get_maintenance_tool_cost() + get_project_need(city, household, good) - TownLedger.get_share(household, good))
		if want > 0:
			wants[good] = want
	return wants

# What it would sell, good -> units: its own beyond what it keeps.
static func get_offers(city: City, household: Household) -> Dictionary:
	var offers: Dictionary = {}
	for good: String in household.stores_share.keys():
		if good == "food":
			continue
		var spare: int = TownLedger.get_share(household, good) - get_keep(city, household, good)
		if spare > 0:
			offers[good] = spare
	return offers

# The food a family may pay with: its own in the store beyond its keep.
static func get_food_budget(city: City, household: Household) -> float:
	return maxf(0.0, float(TownLedger.get_share(household, "food")) - household.share_food_owed - float(get_keep(city, household, "food")))

# What a family could buy of a good at the market as it stands: its own want, what the others
# would bring, and what its food would pay for at the last price, each as the market day limits it
# (hold). Nothing here decides or trades.
static func get_obtainable(city: City, household: Household, good: String) -> int:
	if not is_on(city):
		return 0
	var want: int = int(scale(get_wants(city, household), get_market_share(household)).get(good, 0))
	if want <= 0:
		return 0
	var offered: int = 0
	for other: Household in city.households:
		if other != household:
			offered += int(scale(get_offers(city, other), get_market_share(other)).get(good, 0))
	return mini(mini(want, offered), int(floor(get_food_budget(city, household) / get_price(city, good))))

# How much of what it would deal an Insular family brings to market.
static func get_market_share(household: Household) -> float:
	return maxf(EconomyBalance.MARKET_SHARE_MIN, 1.0 - EconomyBalance.INSULAR_MARKET_SHARE * float(HouseholdCharacter.get_strength(household, "insular")))

static func get_haggle_weight(household: Household) -> float:
	return 1.0 + EconomyBalance.HAGGLE_PER_POINT * float(HouseholdCharacter.get_strength(household, "hagglers"))

# --- The market day -----------------------------------------------------------------------------

# Monthly (HouseholdMigration.advance_month). Good by good, in a fixed order: the price from demand
# and supply; buyers' wants limited by the food they can pay; what changes hands is the lesser of
# what's offered and what's wanted, shared among sellers and buyers in proportion; buyers pay food,
# which the sellers share by what each sold (Hagglers' shares weigh more). Food a seller earns can
# buy its next good.
static func hold(city: City) -> void:
	if not is_on(city):
		return
	var ordered: Array[Household] = city.households.duplicate()
	ordered.sort_custom(func(a: Household, b: Household) -> bool: return a.id < b.id)
	var offers: Dictionary = {}
	var wants: Dictionary = {}
	var budget: Dictionary = {}
	for household: Household in ordered:
		var share: float = get_market_share(household)
		offers[household.id] = scale(get_offers(city, household), share)
		wants[household.id] = scale(get_wants(city, household), share)
		budget[household.id] = get_food_budget(city, household)
	city.market_last = {}
	var goods: Array = []
	for household: Household in ordered:
		for good: String in (offers[household.id] as Dictionary).keys():
			if not goods.has(good):
				goods.append(good)
	goods.sort()
	for good: String in goods:
		var supply: int = 0
		var demand: int = 0
		for household: Household in ordered:
			supply += int((offers[household.id] as Dictionary).get(good, 0))
			demand += int((wants[household.id] as Dictionary).get(good, 0))
		if supply <= 0 or demand <= 0:
			continue
		var price: float = get_base_price(good) * clampf(sqrt(float(demand) / float(supply)), EconomyBalance.MARKET_PRICE_MIN, EconomyBalance.MARKET_PRICE_MAX)
		city.market_prices[good] = snappedf(price, 0.01)
		var effective: Dictionary = {}
		var wanted: int = 0
		for household: Household in ordered:
			var can: int = mini(int((wants[household.id] as Dictionary).get(good, 0)), int(floor(float(budget[household.id]) / price)))
			if can > 0:
				effective[household.id] = can
				wanted += can
		var traded: int = mini(supply, wanted)
		if traded <= 0:
			continue
		var bought: Dictionary = allocate(effective, wanted, traded, ordered)
		var sold_from: Dictionary = {}
		for household: Household in ordered:
			var offered: int = int((offers[household.id] as Dictionary).get(good, 0))
			if offered > 0:
				sold_from[household.id] = offered
		var sold: Dictionary = allocate(sold_from, supply, traded, ordered)
		var pool: int = 0
		for household: Household in ordered:
			var units: int = int(bought.get(household.id, 0))
			if units <= 0:
				continue
			var paid: int = mini(int(round(float(units) * price)), TownLedger.get_share(household, "food"))
			TownLedger.set_share(household, "food", TownLedger.get_share(household, "food") - paid)
			TownLedger.set_share(household, good, TownLedger.get_share(household, good) + units)
			budget[household.id] = float(budget[household.id]) - float(paid)
			pool += paid
		var weights: Dictionary = {}
		for household: Household in ordered:
			if int(sold.get(household.id, 0)) > 0:
				weights[household.id] = float(sold[household.id]) * get_haggle_weight(household)
		var earned: Dictionary = split(pool, weights, ordered)
		for household: Household in ordered:
			var units: int = int(sold.get(household.id, 0))
			if units <= 0:
				continue
			TownLedger.set_share(household, good, TownLedger.get_share(household, good) - units)
			TownLedger.set_share(household, "food", TownLedger.get_share(household, "food") + int(earned.get(household.id, 0)))
			budget[household.id] = float(budget[household.id]) + float(earned.get(household.id, 0))
			household.market_sales += units
		city.market_last[good] = {"units": traded, "price": snappedf(price, 0.01), "food": pool}
		city.market_traded[good] = int(city.market_traded.get(good, 0)) + traded

static func scale(amounts: Dictionary, share: float) -> Dictionary:
	var scaled: Dictionary = {}
	for good: String in amounts.keys():
		var units: int = int(floor(float(amounts[good]) * share))
		if units > 0:
			scaled[good] = units
	return scaled

# `total` units shared among `claims` (id -> units claimed, summing to `claimed`) in proportion,
# whole units, the remainder one each in id order, never more than a claim.
static func allocate(claims: Dictionary, claimed: int, total: int, ordered: Array[Household]) -> Dictionary:
	var given: Dictionary = {}
	var left: int = total
	for household: Household in ordered:
		if claims.has(household.id):
			var units: int = int(floor(float(claims[household.id]) * float(total) / float(claimed)))
			given[household.id] = units
			left -= units
	for household: Household in ordered:
		if left <= 0:
			break
		if claims.has(household.id) and int(given[household.id]) < int(claims[household.id]):
			given[household.id] = int(given[household.id]) + 1
			left -= 1
	return given

# `pool` whole units shared by weight; the remainder to the first in id order with a weight.
static func split(pool: int, weights: Dictionary, ordered: Array[Household]) -> Dictionary:
	var total: float = 0.0
	for id: int in weights.keys():
		total += float(weights[id])
	var shares: Dictionary = {}
	if total <= 0.0:
		return shares
	var left: int = pool
	for household: Household in ordered:
		if weights.has(household.id):
			var units: int = int(floor(float(pool) * float(weights[household.id]) / total))
			shares[household.id] = units
			left -= units
	for household: Household in ordered:
		if left <= 0:
			break
		if weights.has(household.id):
			shares[household.id] = int(shares[household.id]) + 1
			left -= 1
	return shares

# --- Any day ------------------------------------------------------------------------------------

# A family short of food today sells what it holds beyond its own needs for food, eaten at once, to
# families with food to spare, at the last market price. Insular families deal only with kin.
# Returns the food it got.
static func sell_for_food(city: City, household: Household, wanted: float) -> float:
	if not is_on(city):
		return 0.0
	var offers: Dictionary = get_offers(city, household)
	if offers.is_empty():
		return 0.0
	var kin: Array[Household] = city.social.get_kin(household) if city.social.enabled else []
	var buyers: Array[Household] = city.households.filter(func(other: Household) -> bool: return other != household and get_food_budget(city, other) >= 1.0 and (HouseholdCharacter.get_strength(other, "insular") < 2 or kin.has(other)))
	buyers.sort_custom(func(a: Household, b: Household) -> bool: return a.id < b.id)
	var got: float = 0.0
	var goods: Array = offers.keys()
	goods.sort()
	for good: String in goods:
		var price: float = get_price(city, good)
		var units: int = int(offers[good])
		for buyer: Household in buyers:
			while units > 0 and got < wanted - 0.001 and get_food_budget(city, buyer) >= price:
				var paid: float = TownCommons.give_from_own(city, buyer, price)
				if paid <= 0.0:
					break
				TownLedger.set_share(household, good, TownLedger.get_share(household, good) - 1)
				TownLedger.set_share(buyer, good, TownLedger.get_share(buyer, good) + 1)
				units -= 1
				got += paid
				city.market_emergency_sales += 1
	return got

# --- Wealth -------------------------------------------------------------------------------------

# A family's wealth, in food: its larder and its own goods at their worth.
static func get_wealth(household: Household) -> float:
	var wealth: float = household.larder
	for good: String in household.stores_share.keys():
		wealth += float(household.stores_share[good]) * get_base_price(good)
	return wealth

# Under a compact, a family whose wealth is well above the town's middle reads as prosperous.
static func is_wealthy(city: City, household: Household) -> bool:
	if not is_on(city) or city.households.size() < 2:
		return false
	var levels: Array[float] = []
	for other: Household in city.households:
		levels.append(get_wealth(other))
	levels.sort()
	var middle: float = levels[levels.size() / 2]
	return get_wealth(household) > maxf(1.0, middle * EconomyBalance.PROSPEROUS_WEALTH_SHARE)
