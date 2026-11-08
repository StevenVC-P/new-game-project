extends RefCounted

# E13 V0, the local-value observer (docs/economic_foundations/E13_local_value.md, section 4 and the V0
# card; master roadmap Phase 1). On a switch in the divergence check (--value-log=DIR), once a month
# it writes the raw inputs a town value would be worked out from, one JSON line per town and month:
# each good's stock, the community's part, flows so far, the use and production the town expects over
# the coming year at today's work, building waiting for it and its price; and each household's
# holdings, keep-back, offers, wants, need, danger and the material it would build its home of with
# supply set aside (latent demand). Formula variants then run over the saved logs (value_report.gd)
# without repeating the runs. It only reads: play is identical with it on or off.

const Invariants = preload("res://tests/sim/economy_invariants.gd")
const HORIZONS: Array[int] = [30, 90, 180, 360]

# short_by_household: each family's hungry days this month, counted by the caller day by day (the
# family's own count is reset at the month's turn, before the month's last day is observed).
static func record(city: City, day: int, label: String, short_by_household: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var goods: Dictionary = {}
	var committed: Dictionary = city.construction.get_committed_materials()
	var market: bool = TownMarket.is_on(city)
	for good: String in Invariants.get_goods():
		var uses: Array = []
		for days: int in HORIZONS:
			uses.append(snappedf(FamilyInitiative.get_use(city, good, days), 0.01))
		goods[good] = {
			"stock": int(city.resources.get(good, 0)),
			"community": TownLedger.get_community(city, good),
			"use": uses,
			"daily_output": snappedf(FamilyInitiative.get_expected_output(city, good), 0.001),
			"committed": int(committed.get(good, 0)),
			"price": snappedf(TownMarket.get_price(city, good), 0.001) if market else -1.0,
			"base_value": float(EconomyBalance.VALUE_IN_GRAIN.get(good, -1.0)),
			"flows": (city._flows.get(good, {}) as Dictionary).duplicate(),
		}
	var households: Array = []
	for household: Household in city.households:
		var shares: Dictionary = {}
		var keep: Dictionary = {}
		for good: String in household.stores_share:
			shares[good] = int(household.stores_share[good])
			if market:
				keep[good] = TownMarket.get_keep(city, household, good)
		households.append({
			"id": household.id,
			"people": household.total_population,
			"occupation": TownDemographics.occupation_of(city, household),
			"need": snappedf(HouseholdEconomy.get_daily_need(household), 0.001),
			"larder": snappedf(household.larder, 0.01),
			"shares": shares,
			"keep": keep,
			"offers": TownMarket.get_offers(city, household) if market else {},
			"wants": TownMarket.get_wants(city, household) if market else {},
			"short_days": int(short_by_household.get(household.id, household.short_days_this_month)),
			"in_danger": TownCommons.is_in_danger(household),
			"housing": household.housing_status,
			"latent_home": str(MaterialChoice.choose(city, household, "house", true)["material"]),
			"home_now": str(MaterialChoice.choose(city, household, "house")["material"]),
		})
	return {
		"label": label,
		"day": day,
		"compact": TownCompact.is_set(city),
		"reserve": TownCommons.get_reserve(city),
		"people": city.get_total_population(),
		"food_coverage": snappedf(FamilyInitiative.get_food_coverage(city), 0.001) if city.get_total_population() > 0 else -1.0,
		"signals": {"food": FamilyInitiative.get_waiting_risk(city, TownInfluence.ACTIVITY_FOOD), "wood": FamilyInitiative.get_waiting_risk(city, TownInfluence.ACTIVITY_WOOD), "tools": FamilyInitiative.get_waiting_risk(city, TownInfluence.ACTIVITY_TOOLS), "tools_shortage": FamilyInitiative.get_shortage(city, TownInfluence.ACTIVITY_TOOLS)},
		"goods": goods,
		"households": households,
		"observer_usec": Time.get_ticks_usec() - started,
	}

static func append(path: String, line: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		push_error("value observer: cannot write " + path)
		return
	file.seek_end()
	file.store_line(JSON.stringify(line))
	file.close()
