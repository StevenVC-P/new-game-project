class_name TownCommons
extends RefCounted

# The commons and asking for help (sprint S8, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md; owner's Track B
# guidance, 2026-11-05). Under a compact (TownCompact):
# - the player's rules say how the community's goods answer: how many days of food the common
#   table keeps back from families not in danger (a family in danger may still eat from it: survival
#   first), and whether the community grants part of its surplus to families each month (to those in
#   need, or to every family alike), judged for fairness by the others (TownSocial.judge_distribution);
# - a family the table and its larder leave short on a day asks the households it knows, which give
#   from what they own as their values move them (SocialDecisions.get_share_desire). The calendar
#   never blocks it (D2).
# Pooled towns keep the game before S7: the table feeds everyone and sharing is monthly.

const GRANTS_NONE: String = "none"
const GRANTS_IN_NEED: String = "in_need"
const GRANTS_EQUAL: String = "equal"
const GRANT_RULES: Array[String] = [GRANTS_NONE, GRANTS_IN_NEED, GRANTS_EQUAL]
const GRANT_NAMES: Dictionary = {GRANTS_NONE: "No grants", GRANTS_IN_NEED: "To families in need", GRANTS_EQUAL: "To every family alike"}

static func is_on(city: City) -> bool:
	return TownCompact.is_set(city)

# The food the table keeps back from families not in danger.
static func get_reserve(city: City) -> int:
	if not is_on(city):
		return 0
	return int(ceil(float(city.commons_reserve_days) * float(city.get_food_consumption_for_population(city.get_total_population()))))

# A family going hungry this month, one the shortage could drive away, or one already in severe
# hunger or cold (HouseholdMortality).
static func is_in_danger(city: City, household: Household) -> bool:
	return get_danger_short_days(city, household) >= EconomyBalance.DANGER_SHORT_DAYS or household.severe_hunger_months > 0 or household.severe_cold_months > 0 or HouseholdMigration.is_considering_departure(household)

# Experiment (not adopted; owner 2026-11-06): with the meta "reserve_30_days", danger reads the last
# 30 days, so a family short since the 20th isn't turned away on the 1st.
static func get_danger_short_days(city: City, household: Household) -> int:
	if not city.has_meta("reserve_30_days"):
		return household.short_days_this_month
	var from_day: int = city.construction.day - Calendar.DAYS_PER_MONTH
	household.recent_short_days = household.recent_short_days.filter(func(day: int) -> bool: return day > from_day)
	return household.recent_short_days.size()

static func note_short_day(city: City, household: Household) -> void:
	if city.has_meta("reserve_30_days"):
		household.recent_short_days.append(city.construction.day)

# The common table under a compact, after families ate their own (HouseholdEconomy.feed): the
# community's food above the reserve feeds every family alike (as before S8 when there is no
# reserve); the reserve feeds only families in danger. What the table can't give comes from each
# family's larder reserve, then from neighbours who will give, then from selling its goods for food
# (TownMarket, S9). A family left wanting is short today.
static func feed_from_table(city: City, from_store: Dictionary) -> void:
	var community: int = TownLedger.get_community(city, "food")
	var open: float = float(maxi(0, community - get_reserve(city)))
	# Experiments (not adopted; owner 2026-11-06): the meta "reserve_last" moves the reserve after the
	# larder, neighbours and the market; "reserve_limit" holds a family's daily draw to a survival share.
	var reserve_last: bool = city.has_meta("reserve_last")
	var draw_limit: float = EconomyBalance.RESERVE_DRAW_SHARE if city.has_meta("reserve_limit") else 1.0
	var danger_need: float = 0.0
	var total_need: float = 0.0
	for household: Household in city.households:
		total_need += float(from_store[household.id])
		if is_in_danger(city, household):
			danger_need += float(from_store[household.id])
	var from_open: float = minf(total_need, open)
	var fed_open: float = from_open / total_need if total_need > 0.0 else 1.0
	var from_reserve: float = 0.0 if reserve_last else minf(danger_need * minf(1.0 - fed_open, draw_limit), float(community) - from_open)
	var units: int = mini(community, int(ceil(from_open + from_reserve - 0.000001)))
	city.consume_need_bucket(GoodsNeedBucketHelper.BUCKET_FOOD, units)
	var reserve_left: float = float(community - units)
	var drawn_last: float = 0.0
	var fed_others: float = fed_open
	var fed_danger: float = fed_open + (from_reserve / danger_need if danger_need > 0.0 else 0.0)
	var town_short: bool = false
	for household: Household in city.households:
		var unmet: float = float(from_store[household.id]) * (1.0 - (fed_danger if is_in_danger(city, household) else fed_others))
		if unmet <= 0.001:
			continue
		town_short = true
		var reserve_food: float = minf(unmet, household.larder)
		household.larder -= reserve_food
		unmet -= reserve_food
		city.influence.larder_eaten_short += reserve_food
		if unmet > 0.001:
			unmet -= ask_for_food(city, household, unmet)
		# Still short: it may sell what it holds for food, any day (TownMarket, sprint S9).
		if unmet > 0.001:
			unmet -= TownMarket.sell_for_food(city, household, unmet)
		if reserve_last and unmet > 0.001 and is_in_danger(city, household):
			var draw: float = minf(minf(unmet, float(from_store[household.id]) * draw_limit), reserve_left)
			reserve_left -= draw
			drawn_last += draw
			unmet -= draw
		if unmet > 0.001:
			household.short_today = true
			household.short_days_this_month += 1
			city.influence.household_short_days += 1
			note_short_day(city, household)
	if drawn_last > 0.0:
		city.consume_need_bucket(GoodsNeedBucketHelper.BUCKET_FOOD, int(ceil(drawn_last - 0.000001)))
	city.resources["food_shortage"] = town_short

# What a family holds of its own food it could give on a hungry day: beyond its own month.
static func get_spare_food(household: Household) -> float:
	return HouseholdEconomy.get_own_food(household) - float(EconomyBalance.HELP_KEEPS_FOOD_DAYS) * HouseholdEconomy.get_daily_need(household)

# A hungry family asks the households it knows, the nearest in feeling first; each with food to
# spare gives if its values move it to. Returns what the family received and ate today.
static func ask_for_food(city: City, household: Household, wanted: float) -> float:
	if not city.social.enabled:
		return 0.0
	var donors: Array[Household] = city.social.get_known_households(household).filter(func(other: Household) -> bool: return get_spare_food(other) >= 1.0)
	if donors.is_empty():
		return 0.0
	donors.sort_custom(func(a: Household, b: Household) -> bool: return HouseholdMemory.get_disposition(household, a.id) > HouseholdMemory.get_disposition(household, b.id) or (HouseholdMemory.get_disposition(household, a.id) == HouseholdMemory.get_disposition(household, b.id) and a.id < b.id))
	city.commons_help_asked += 1
	var received: float = 0.0
	for donor: Household in donors:
		if received >= wanted - 0.001:
			break
		var desire: Dictionary = SocialDecisions.get_share_desire(city, donor, household)
		if float(desire["score"]) + FamilyInitiative.get_noise(city, donor, "help:%d" % household.id) < SocialDecisions.SHARE_THRESHOLD:
			continue
		var given: float = give_from_own(city, donor, minf(wanted - received, get_spare_food(donor)))
		if given <= 0.0:
			continue
		received += given
		city.commons_help_given += given
		remember_help(city, donor, household)
	return received

# Food a donor gives to be eaten today: from its share in the store first (whole units as they add
# up, as eating does), then its larder.
static func give_from_own(city: City, donor: Household, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var from_share: float = minf(amount, maxf(0.0, float(TownLedger.get_share(donor, "food")) - donor.share_food_owed))
	if from_share > 0.0:
		donor.share_food_owed += from_share
		var whole: int = int(floor(donor.share_food_owed + 0.000001))
		if whole > 0:
			city.remove_resource("food", whole, "need_food")
			TownLedger.charge(donor, "food", whole)
			donor.share_food_owed = maxf(0.0, donor.share_food_owed - float(whole))
	var from_larder: float = minf(amount - from_share, donor.larder)
	donor.larder -= from_larder
	return from_share + from_larder

# Once a month for each pair, the help counts as the shortage's sharing does: a warmer tie each
# way, standing for the giver, and a memory for both (TownSocial.share_in_shortage).
static func remember_help(city: City, donor: Household, recipient: Household) -> void:
	var key: String = "%d:%d" % [donor.id, recipient.id]
	var month: int = int(city.resources.get("migration_month_index", 0))
	if int(city.commons_help_month.get(key, -1)) == month:
		return
	city.commons_help_month[key] = month
	donor.help_given += 1
	city.social.adjust_standing(donor, 0.5)
	HouseholdMemory.touch_tie(city, recipient, donor, 1, "fed us when we went hungry", 1)
	HouseholdMemory.touch_tie(city, donor, recipient, 1, "we fed them when they went hungry", -1)
	HouseholdMemory.experience(city, recipient, "food_received", "%s fed it on a hungry day" % city.get_household_label(donor.id), donor, {"benefit": 1, "voluntary": true})

# --- Grants (monthly) ---------------------------------------------------------------------------

# Monthly (HouseholdMigration.advance_month): under the player's grant rule, a share of the
# community's food and wood beyond the reserve and two months of the town's need passes into
# families' own goods, to those in need or to all alike. The others judge whether it was fair.
static func advance_month(city: City) -> void:
	if not is_on(city) or city.commons_grants == GRANTS_NONE or city.households.is_empty():
		return
	var ordered: Array[Household] = city.households.duplicate()
	ordered.sort_custom(func(a: Household, b: Household) -> bool: return a.id < b.id)
	var recipients: Array[Household] = ordered
	if city.commons_grants == GRANTS_IN_NEED:
		recipients = ordered.filter(func(h: Household) -> bool: return h.short_days_this_month > 0 or is_in_danger(city, h) or TownSocial.is_in_need(city, h))
	if recipients.is_empty():
		return
	var keeps: Dictionary = {
		"food": get_reserve(city) + EconomyBalance.GRANT_KEEPS_DAYS * city.get_food_consumption_for_population(city.get_total_population()),
		"wood": int(ceil(TownFuel.get_need_over(city, EconomyBalance.GRANT_KEEPS_DAYS))),
	}
	for good: String in keeps.keys():
		var surplus: int = TownLedger.get_community(city, good) - int(keeps[good])
		var each: int = int(floor(float(surplus) * EconomyBalance.GRANT_SHARE / float(recipients.size())))
		if each <= 0:
			continue
		for household: Household in recipients:
			TownLedger.set_share(household, good, TownLedger.get_share(household, good) + each)
			city.commons_granted[good] = int(city.commons_granted.get(good, 0)) + each
	for household: Household in recipients:
		household.grants_received += 1
		city.social.judge_distribution(household, "a grant from the commons")

static func set_reserve_days(city: City, days: int) -> void:
	if EconomyBalance.COMMONS_RESERVE_STEPS.has(days):
		city.commons_reserve_days = days

static func set_grants(city: City, rule: String) -> void:
	if GRANT_RULES.has(rule):
		city.commons_grants = rule
