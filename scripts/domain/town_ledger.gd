class_name TownLedger
extends RefCounted

# Who owns what in the town's one store (sprint S6; docs/PROPERTY_AND_COMMUNAL_RESOURCES.md §4.1
# and §4.2, owner decision D1). city.resources stays the only physical stock of each good, so
# carrying, building, upkeep, trade and raids keep reading one place. Each household holds a share
# in it (Household.stores_share, good -> amount); the community's goods are the rest, worked out and
# never stored, so the two can't drift apart.
#
# Pooled (every share zero: today's game, old saves and comparison runs, D1's migration setting),
# nothing here changes play. Contributions (S7) are what first give families goods of their own.
#
# A family that leaves or dies out takes nothing: its share drops out of the total and so becomes
# the community's. That is a placeholder until families own enough for it to matter (S7, S8).

const COMMUNITY: int = -1
# The goods the treasury card shows, in this order, when the store holds any.
const SHOWN_GOODS: Array[String] = ["food", "wood", "tools", "stone_blocks", "cut_stone", "bricks", "lime", "masonry", "clothing"]

static func get_share(household: Household, good: String) -> int:
	return int(household.stores_share.get(good, 0))

static func get_shares_total(city: City, good: String) -> int:
	var total: int = 0
	for household: Household in city.households:
		total += get_share(household, good)
	return total

static func is_pooled(city: City) -> bool:
	for household: Household in city.households:
		if not household.stores_share.is_empty():
			return false
	return true

# The community's goods: the physical stock less every household's share.
static func get_community(city: City, good: String) -> int:
	return maxi(0, int(city.resources.get(good, 0)) - get_shares_total(city, good))

# What a household may draw on for its own use: its share and, unless told otherwise, the
# community's goods. A household never draws on another's share.
static func get_available(city: City, household: Household, good: String, with_community: bool = true) -> int:
	var own: int = get_share(household, good) if household != null else 0
	return own + (get_community(city, good) if with_community else 0)

# Puts goods in the store as the household's own.
static func credit(city: City, household: Household, good: String, amount: int, cause: String) -> void:
	if amount <= 0:
		return
	city.add_resource(good, amount, cause)
	household.stores_share[good] = get_share(household, good) + amount

# Charges goods taken from the store (the caller has removed them) to whoever pays: the paying
# household's own share first, the community's goods for the rest. Returns {payer id: amount},
# the community as COMMUNITY.
static func charge(household: Household, good: String, amount: int) -> Dictionary:
	var paid: Dictionary = {}
	var own: int = 0
	if household != null:
		own = mini(amount, get_share(household, good))
		if own > 0:
			set_share(household, good, get_share(household, good) - own)
			paid[household.id] = own
	if amount > own:
		paid[COMMUNITY] = amount - own
	return paid

# A loss nobody chose (a raid; spoilage later) falls on everyone with goods in the store, in
# proportion to what each holds.
static func lose(city: City, good: String, amount: int, cause: String) -> void:
	var before: int = int(city.resources.get(good, 0))
	if amount <= 0 or before <= 0:
		return
	city.remove_resource(good, amount, cause)
	var kept: float = float(maxi(0, before - amount)) / float(before)
	for household: Household in city.households:
		if household.stores_share.has(good):
			set_share(household, good, int(float(get_share(household, good)) * kept))

# Keeps shares within the physical stock: if a good was taken without being charged to anyone
# (eating, a workshop's inputs), owners lose in proportion. Run each day and after any removal.
static func settle(city: City) -> void:
	if is_pooled(city):
		return
	var goods: Dictionary = {}
	for household: Household in city.households:
		for good: String in household.stores_share.keys():
			goods[good] = true
	for good: String in goods.keys():
		settle_good(city, good)

static func settle_good(city: City, good: String) -> void:
	var total: int = get_shares_total(city, good)
	var stock: int = maxi(0, int(city.resources.get(good, 0)))
	if total <= stock:
		return
	var kept: float = float(stock) / float(total)
	for household: Household in city.households:
		if household.stores_share.has(good):
			set_share(household, good, int(float(get_share(household, good)) * kept))

static func set_share(household: Household, good: String, amount: int) -> void:
	if amount > 0:
		household.stores_share[good] = amount
	else:
		household.stores_share.erase(good)

# --- Who paid for a building (§4.2) -------------------------------------------------------------
# funded is {good: {payer id: amount}} on a project, carried to its building on completion. A
# building with nothing recorded (everything built before S6) was paid from the common store.

static func add_funding(funded: Dictionary, good: String, paid: Dictionary) -> void:
	if not funded.has(good):
		funded[good] = {}
	var by_payer: Dictionary = funded[good]
	for payer: int in paid.keys():
		by_payer[payer] = int(by_payer.get(payer, 0)) + int(paid[payer])

static func merge_funding(into: Dictionary, from: Dictionary) -> void:
	for good: String in from.keys():
		add_funding(into, good, from[good])

# The share of a building's materials, by units, a payer gave: 1.0 for the community on anything
# with no record.
static func get_funded_share(funded: Dictionary, payer: int) -> float:
	var total: int = 0
	var given: int = 0
	for good: String in funded.keys():
		var by_payer: Dictionary = funded[good]
		for id: int in by_payer.keys():
			total += int(by_payer[id])
			if id == payer:
				given += int(by_payer[id])
	if total == 0:
		return 1.0 if payer == COMMUNITY else 0.0
	return float(given) / float(total)

# Materials returned to the store from a cancelled project go back to whoever paid for them; the
# community takes anything unrecorded (a project from before S6) or paid by a family since gone.
static func refund(city: City, delivered: Dictionary, funded: Dictionary) -> void:
	for good: String in delivered.keys():
		var left: int = int(delivered[good])
		var by_payer: Dictionary = funded.get(good, {})
		for payer: int in by_payer.keys():
			var household: Household = city.get_household_by_id(payer) if payer != COMMUNITY else null
			if household != null:
				var back: int = mini(left, int(by_payer[payer]))
				credit(city, household, good, back, "built")
				left -= back
		if left > 0:
			city.add_resource(good, left, "built")
