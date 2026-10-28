class_name TownDefense
extends RefCounted

# Village defense (docs/FIRST_STAGE_LOOP.md, milestone 5; docs/WARFARE_AND_CONFLICT_MODEL.md,
# defense first at village scale). Light by design: bandit raids on the stores, a watch, and a
# militia; no army.
#
# Bandits follow the roads: from the second year, in spring, summer, and autumn, a town traders
# can reach may draw a band, more often at a crossroads, and the richer its stores the likelier
# and bolder the band. Towns far from roads see none. A band is seen on the road some days before
# it comes, so the player can answer it:
# - a watch post, kept by a family (soldier families suit the shield calling), guards the town
#   all year;
# - the militia: the player calls families up when a band is seen; they leave their work until the
#   band is dealt with, so a call-up costs the town that work.
# A band that meets enough guard is driven off. Otherwise it takes a share of the food, tools, and
# wood, less the more guard it met, and never so much food that the town cannot eat for a month;
# no raid alone ends a town. A town that failed to defend its families loses some of their
# contentment. Numbers in EconomyBalance (Defense).

const WATCH_POST: String = "watch_post"
const SEASON_WINTER: int = 3
const RAIDED_GOODS: Array[String] = ["food", "tools", "wood"]

var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# A band seen on the road: the day it comes and how strong it is; -1 when none.
var raid_day: int = -1
var raid_strength: int = 0
# Families called up to the militia until the band is dealt with.
var called_household_ids: Array[int] = []
var raids: int = 0
var raids_driven_off: int = 0
var last_raid_text: String = ""

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func is_band_coming() -> bool:
	return raid_day >= 0

func advance_day() -> void:
	if not has_map():
		return
	var today: int = city.construction.day
	if is_band_coming():
		if today >= raid_day:
			resolve_raid()
		return
	if today < EconomyBalance.BANDITS_FROM_DAY or today % EconomyBalance.BANDIT_ROLL_INTERVAL_DAYS != 0 or city.get_season_index() == SEASON_WINTER:
		return
	var rng: RandomNumberGenerator = make_rng(today)
	if rng.randf() < get_monthly_chance():
		raid_day = today + EconomyBalance.BANDIT_WARNING_DAYS
		raid_strength = clampi(roundi(EconomyBalance.BANDIT_BASE_STRENGTH * get_temptation()) + rng.randi_range(0, 1), 1, EconomyBalance.BANDIT_MAX_STRENGTH)

func make_rng(today: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), today, "bandits"])
	return rng

# A band's monthly chance: by how the town is reached, times how tempting its stores are.
func get_monthly_chance() -> float:
	return float(EconomyBalance.BANDIT_MONTHLY_CHANCE.get(city.trade.get_link(), 0.0)) * get_temptation()

# The stores' worth in grain against TEMPTING_STORE_GRAIN, within limits.
func get_temptation() -> float:
	var worth: float = 0.0
	for good: String in EconomyBalance.VALUE_IN_GRAIN.keys():
		worth += float(city.resources.get(good, 0)) * TownTrade.get_value(good)
	return clampf(worth / EconomyBalance.TEMPTING_STORE_GRAIN, EconomyBalance.TEMPTATION_MIN, EconomyBalance.TEMPTATION_MAX)

func get_watch_posts_kept() -> int:
	var kept: int = 0
	for building: Building in city.buildings:
		if BuildingTiers.get_base_type(building.type) == WATCH_POST and building.assigned_workers > 0:
			kept += 1
	return kept

func get_guard() -> int:
	return get_watch_posts_kept() * EconomyBalance.WATCH_POST_GUARD + called_household_ids.size() * EconomyBalance.MILITIA_GUARD

func is_called_up(household_id: int) -> bool:
	return household_id >= 0 and called_household_ids.has(household_id)

# The player calls up the militia while a band is coming: up to MILITIA_FAMILIES families, those of
# the shield first, then those with time to spare, then the rest; never the watch post's keepers.
func call_militia() -> bool:
	if not is_band_coming() or not called_household_ids.is_empty():
		return false
	var keepers: Array[int] = []
	for building: Building in city.buildings:
		if BuildingTiers.get_base_type(building.type) == WATCH_POST and building.assigned_household_id >= 0:
			keepers.append(building.assigned_household_id)
	var candidates: Array[Household] = []
	for household: Household in city.households:
		if not keepers.has(household.id):
			candidates.append(household)
	candidates.sort_custom(func(a: Household, b: Household) -> bool: return militia_rank(a) > militia_rank(b))
	for household: Household in candidates.slice(0, EconomyBalance.MILITIA_FAMILIES):
		called_household_ids.append(household.id)
	return not called_household_ids.is_empty()

func militia_rank(household: Household) -> int:
	var rank: int = 0
	if household.get_match_quality(WATCH_POST) == CultureEffects.MATCH_GOOD:
		rank += 2
	if household.is_available():
		rank += 1
	return rank

# The band comes: driven off by enough guard, or it takes its share of the stores.
func resolve_raid() -> void:
	var guard: int = get_guard()
	raids += 1
	if guard >= raid_strength:
		raids_driven_off += 1
		last_raid_text = "Bandits driven off on day %d (band %d, guard %d)" % [city.construction.day, raid_strength, guard]
	else:
		var share: float = EconomyBalance.RAID_TAKE_SHARE * (1.0 - float(guard) / float(raid_strength))
		var taken: Array[String] = []
		for good: String in RAIDED_GOODS:
			var keep: int = 0
			if good == "food":
				keep = int(float(city.resources["food_consumption_rate"]) * EconomyBalance.RAID_FOOD_KEPT_DAYS)
			var amount: int = mini(int(float(city.resources.get(good, 0)) * share), maxi(0, int(city.resources.get(good, 0)) - keep))
			if amount > 0:
				city.resources[good] = int(city.resources[good]) - amount
				taken.append("%d %s" % [amount, good])
		for household: Household in city.households:
			household.contentment = maxi(0, household.contentment - EconomyBalance.RAID_CONTENTMENT_LOSS)
		last_raid_text = "Bandits raided on day %d: took %s" % [city.construction.day, ", ".join(taken) if not taken.is_empty() else "little"]
	raid_day = -1
	raid_strength = 0
	called_household_ids.clear()

# Sidebar lines: the guard and the last raid. A band on the road is an alert in the top bar
# (TownStatusBar), with the militia button in the sidebar.
func get_notices() -> Array[String]:
	var lines: Array[String] = []
	if not has_map():
		return lines
	if is_band_coming() and not called_household_ids.is_empty():
		lines.append("Militia called: %d families (guard %d)" % [called_household_ids.size(), get_guard()])
	elif city.trade.get_link() == TownTrade.LINK_NONE:
		pass
	elif get_watch_posts_kept() > 0:
		lines.append("Watch kept: %d post%s" % [get_watch_posts_kept(), "" if get_watch_posts_kept() == 1 else "s"])
	if last_raid_text != "":
		lines.append(last_raid_text)
	return lines
