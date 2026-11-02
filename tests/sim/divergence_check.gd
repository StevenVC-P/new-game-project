extends SceneTree

# Divergence check (docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md): do towns founded by the same families
# on different land develop differently, and does each sprint's mechanic change that? Real sites are
# grouped into five environments by what their town maps hold. The groups exist only here; nothing
# in play reads them. Start k in every environment is founded by founder set k (the same families,
# values and callings), so differences come from the land. Towns are family-led (today's rules) and
# played by a player who never intervenes (or, with "--policies=guided", keeps the stores for its priorities and asks for what is short:
# the stand-in's guide()), with the
# economy invariants checked every day (tests/sim/economy_invariants.gd).
#
#   <godot> --headless --path . --script res://tests/sim/divergence_check.gd -- --environments=forested > div.log
# then filter for [DIV]. Options:
#   --survey                 classify the site pool and stop (no play)
#   --environments=a,b       fertile_valley, forested, rocky_highland, balanced, marginal (default all)
#   --starts=N               starts per environment (12); --from=K skips the first K
#   --years=N                years (6), with a year-3 snapshot
#   --conditions=a,b         ordinary (default), stressed (the stand-in's hard first winter)
#   --policies=a,b           none (default), guided; and contrasting players, each acting only through
#                            the game's own controls, so player choices can make or break a village:
#                            attentive (weekly, answers the warning cards with the appeals they offer),
#                            investment_first (productive investment as the town's priority from
#                            founding, never changed), overprotect (keeps every wood from the first week)
#   --meta=a,b               comparison switches set on each town before its first day
#   --commission=type@day    the player commissions one workplace of that type on that day (repeat
#                            with commas), on the valid spot with the most of its deposit underfoot,
#                            then nearest the town centre; a family is found to work it as in play
#   --repeat                 play each town twice and compare its monthly fingerprints (determinism)
#   --seed=N                 only the town on the site with this seed
# Lines: "[DIV] TOWN ..." one per town and snapshot (JSON), "[DIV] SUM ..." per group, "[DIV] INV ..."
# for invariant violations, "[DIV] REPEAT ..." for determinism.

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

const ENVIRONMENTS: Array[String] = ["rocky_highland", "fertile_valley", "forested", "marginal", "balanced"]
# Regions and sites per region in the pool, from the authored test world (as the other checks use).
const POOL_REGIONS: int = 60
const POOL_SITES_PER_REGION: int = 4
const FOUNDER_SET_BASE: int = 77000
const SNAPSHOT_YEAR: int = 3
const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const FOOD_TRADES: Array[String] = ["farm", "fisher", "hunter"]

var starts: int = 12
var from: int = 0
var years: int = 6
var only_seed: int = -1
var repeat: bool = false
var metas: Array[String] = []
var commissions: Array[Dictionary] = []
# The deposit a workplace is best placed on, for choosing a commissioned site.
const DEPOSIT_OF: Dictionary = {"quarry": "stone"}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var environments: Array[String] = ENVIRONMENTS.duplicate()
	var conditions: Array[String] = ["ordinary"]
	var policies: Array[String] = ["none"]
	var survey: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--survey":
			survey = true
		elif argument.begins_with("--environments="):
			environments.assign(argument.trim_prefix("--environments=").split(","))
		elif argument.begins_with("--starts="):
			starts = int(argument.trim_prefix("--starts="))
		elif argument.begins_with("--from="):
			from = int(argument.trim_prefix("--from="))
		elif argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--policies="):
			policies.assign(argument.trim_prefix("--policies=").split(","))
		elif argument.begins_with("--meta="):
			metas.assign(argument.trim_prefix("--meta=").split(","))
		elif argument.begins_with("--commission="):
			for entry: String in argument.trim_prefix("--commission=").split(","):
				commissions.append({"type": entry.get_slice("@", 0), "day": int(entry.get_slice("@", 1))})
		elif argument == "--repeat":
			repeat = true
		elif argument.begins_with("--seed="):
			only_seed = int(argument.trim_prefix("--seed="))
	var groups: Dictionary = classify(collect_pool())
	for environment: String in ENVIRONMENTS:
		var seeds: Array = (groups[environment] as Array).map(func(s: Dictionary) -> int: return int(s["seed"]))
		_report("POOL %-15s %3d sites | first %d: %s" % [environment, (groups[environment] as Array).size(), starts, str(seeds.slice(0, starts))])
	if survey:
		for environment: String in ENVIRONMENTS + ["unclassified"]:
			for site: Dictionary in groups[environment]:
				_report("SITE %-15s seed %d | %s | %s" % [environment, int(site["seed"]), site["label"], JSON.stringify(site["land"])])
		quit()
		return
	var failed: bool = false
	for condition: String in conditions:
		for policy: String in policies:
			for environment: String in environments:
				var sites: Array = (groups[environment] as Array).slice(from, from + starts)
				var rows: Dictionary = {SNAPSHOT_YEAR: [], years: []} if years > SNAPSHOT_YEAR else {years: []}
				var started: int = Time.get_ticks_msec()
				for index in range(sites.size()):
					var site: Dictionary = sites[index]
					if only_seed >= 0 and int(site["seed"]) != only_seed:
						continue
					var start: int = from + index
					var result: Dictionary = play(site, start, condition, policy)
					if repeat:
						var again: Dictionary = play(site, start, condition, policy)
						var same: bool = again["fingerprints"] == result["fingerprints"]
						failed = failed or not same
						_report("REPEAT %s | start %d | seed %d | %s" % [environment, start, int(site["seed"]), "identical" if same else "DIFFERENT from month %d" % first_difference(result["fingerprints"], again["fingerprints"])])
					var checker = result["invariants"]
					if not checker.is_clean():
						failed = true
						_report("INV %s | start %d | seed %d | %d violations: %s" % [environment, start, int(site["seed"]), checker.violation_count, " / ".join(checker.violations)])
					for year: int in rows.keys():
						var measured: Dictionary = result["years"][year]
						(rows[year] as Array).append(measured)
						_report("TOWN %s | %s | %s | start %d | year %d | seed %d | %s" % [environment, condition, policy, start, year, int(site["seed"]), JSON.stringify(measured)])
				for year: int in rows.keys():
					summarize(environment, condition, policy, year, rows[year])
				_report("   (%s %s %s: %d towns in %.0f s)" % [environment, condition, policy, sites.size(), (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed else 0)

# --- Sites and environments -------------------------------------------------------------------------

static func collect_pool() -> Array:
	var pool: Array = []
	var seen: Dictionary = {}
	for site: Dictionary in TownBuildingCheck.collect_sites(POOL_REGIONS, POOL_SITES_PER_REGION):
		if seen.has(int(site["seed"])):
			continue
		seen[int(site["seed"])] = true
		site["land"] = measure_land(site["map"])
		pool.append(site)
	return pool

# What a town map holds, as shares of all its tiles.
static func measure_land(map: Array) -> Dictionary:
	var counts: Dictionary = {"farmland": 0, "woods": 0, "rock": 0, "water": 0, "stone": 0, "iron": 0, "hills": 0}
	var total: int = 0
	for row: Array in map:
		for tile: Dictionary in row:
			total += 1
			if tile["type"] == "water":
				counts["water"] += 1
			elif tile["type"] == "rough":
				counts["rock"] += 1
			elif tile.get("is_fertile", false) == true:
				counts["farmland"] += 1
			if tile.get("has_trees", false) == true:
				counts["woods"] += 1
			if tile.get("is_hill", false) == true:
				counts["hills"] += 1
			var resource: String = str(tile.get("resource", "none"))
			if counts.has(resource):
				counts[resource] += 1
	var land: Dictionary = {}
	for key: String in counts.keys():
		land[key] = snappedf(float(counts[key]) / float(maxi(1, total)), 0.0001)
	land["stone_tiles"] = counts["stone"]
	land["iron_tiles"] = counts["iron"]
	return land

# Each site in the first environment it fits (ENVIRONMENTS order, rarest first), by where its land
# falls in the pool's own spread. Sites fitting none stay unclassified.
static func classify(pool: Array) -> Dictionary:
	var spread: Dictionary = {}
	for key: String in ["farmland", "woods", "rock", "water"]:
		var values: Array = pool.map(func(s: Dictionary) -> float: return float(s["land"][key]))
		values.sort()
		spread[key] = values
	var at: Callable = func(key: String, share: float) -> float:
		var values: Array = spread[key]
		return float(values[clampi(int(share * values.size()), 0, values.size() - 1)])
	var groups: Dictionary = {"unclassified": []}
	for environment: String in ENVIRONMENTS:
		groups[environment] = []
	for site: Dictionary in pool:
		var land: Dictionary = site["land"]
		var farmland: float = float(land["farmland"])
		var woods: float = float(land["woods"])
		var picked: String = "unclassified"
		if float(land["rock"]) >= at.call("rock", 0.75) and int(land["stone_tiles"]) > 0 and farmland <= at.call("farmland", 0.5):
			picked = "rocky_highland"
		elif farmland >= at.call("farmland", 2.0 / 3.0):
			picked = "fertile_valley"
		elif woods >= at.call("woods", 2.0 / 3.0):
			picked = "forested"
		elif farmland <= at.call("farmland", 1.0 / 3.0) and woods <= at.call("woods", 0.5) and float(land["water"]) <= at.call("water", 0.5):
			picked = "marginal"
		elif farmland > at.call("farmland", 1.0 / 3.0) and (woods > at.call("woods", 1.0 / 3.0) or float(land["water"]) > 0.0 or int(land["stone_tiles"]) > 0):
			picked = "balanced"
		(groups[picked] as Array).append(site)
	for environment: String in groups.keys():
		groups[environment] = interleave_regions(groups[environment])
	return groups

# The sites of a group taken a region at a time (the first site of each region, then the second...),
# so the first starts aren't all one region's.
static func interleave_regions(sites: Array) -> Array:
	var by_region: Dictionary = {}
	var order: Array[String] = []
	for site: Dictionary in sites:
		var label: String = str(site["label"])
		if not by_region.has(label):
			by_region[label] = []
			order.append(label)
		(by_region[label] as Array).append(site)
	var result: Array = []
	var round_index: int = 0
	while result.size() < sites.size():
		for label: String in order:
			if round_index < (by_region[label] as Array).size():
				result.append(by_region[label][round_index])
		round_index += 1
	return result

# --- Playing a town ----------------------------------------------------------------------------------

# Founder set k: the families a town at a fixed reference place would be founded with from seed k.
# Founders are rolled from the town's tile (City.create_starter_households), so the same set on
# different land is made once and copied in.
static func make_founders(start: int) -> Array[Household]:
	var reference: City = City.new("Founders", Vector2.ZERO, City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, FOUNDER_SET_BASE + start)
	return reference.households

static func found(site: Dictionary, start: int) -> City:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.households.assign(make_founders(start))
	city.recalculate_household_succession_pressures()
	city.update_shelter_counts()
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	return city

func play(site: Dictionary, start: int, condition: String, policy: String) -> Dictionary:
	var city: City = found(site, start)
	for meta: String in metas:
		city.set_meta(meta, true)
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = condition == "stressed"
	scenario["guided"] = policy == "guided"
	var checker = Invariants.new()
	checker.watch(city)
	var state: Dictionary = {"fingerprints": [], "short_days": 0, "first_year_short_days": 0, "tools_out_days": 0, "old_age": 0, "ids": city.households.map(func(h: Household) -> int: return h.id),
		"departed": 0, "woods_start": count_woods(city), "commissioned": [], "day_ms": [], "memory_start": Performance.get_monitor(Performance.MEMORY_STATIC), "last_ms": Time.get_ticks_usec()}
	var measured: Dictionary = {}
	scenario["each_day"] = func(town: City, day: int, player) -> void:
		state["tick_usec"] = int(player.tick_usec)
		state["days"] = day + 1
		# The day's tick and the stand-in's own work, not this check's (the clock restarts at the end).
		(state["day_ms"] as Array).append(float(Time.get_ticks_usec() - int(state["last_ms"])) / 1000.0)
		checker.check_day(town, day)
		if day % Calendar.DAYS_PER_MONTH == Calendar.DAYS_PER_MONTH - 1:
			checker.check_month(town, day)
			(state["fingerprints"] as Array).append(fingerprint(town))
		if day % Calendar.DAYS_PER_MONTH == 0:
			state["short_days_last_month"] = int(state.get("short_days_this_month", 0))
			state["short_days_this_month"] = 0
		if town.resources["food_shortage"] == true:
			state["short_days_this_month"] = int(state.get("short_days_this_month", 0)) + 1
			state["short_days"] = int(state["short_days"]) + 1
			if day < Calendar.DAYS_PER_YEAR:
				state["first_year_short_days"] = int(state["first_year_short_days"]) + 1
		if int(town.resources["tools"]) == 0 and town.buildings.any(func(b: Building) -> bool: return b.needs_maintenance()):
			state["tools_out_days"] = int(state["tools_out_days"]) + 1
		# Households gone without departing came to the end of their lives (old couples).
		var ids: Array = town.households.map(func(h: Household) -> int: return h.id)
		var departed: int = int(town.resources.get("departed_households", 0))
		var gone: int = (state["ids"] as Array).filter(func(id: int) -> bool: return not ids.has(id)).size()
		state["old_age"] = int(state["old_age"]) + maxi(0, gone - (departed - int(state["departed"])))
		state["ids"] = ids
		state["departed"] = departed
		act_as_player(town, day, policy, state)
		for order: Dictionary in commissions:
			if day == int(order["day"]):
				var spot: Vector2i = choose_commission_site(town, str(order["type"]))
				var planned: bool = spot.x >= 0 and town.construction.request_building(str(order["type"]), spot, ConstructionProject.REQUESTED_BY_PLAYER) != null
				(state["commissioned"] as Array).append({"type": order["type"], "day": day, "planned": planned, "deposit_tiles": count_deposit(town, str(order["type"]), spot) if planned else 0})
		if day == SNAPSHOT_YEAR * Calendar.DAYS_PER_YEAR - 1 and years > SNAPSHOT_YEAR:
			measured[SNAPSHOT_YEAR] = measure(town, state, false)
		state["last_ms"] = Time.get_ticks_usec()
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	measured[years] = measure(city, state, bool(result["off_the_ground"]))
	return {"years": measured, "invariants": checker, "fingerprints": state["fingerprints"]}

# What the contrasting players do (see the options), through the game's own controls only. Every act
# is counted in the town's measures.
static func act_as_player(city: City, day: int, policy: String, state: Dictionary) -> void:
	match policy:
		"investment_first":
			if day == 0:
				city.influence.set_priority(CommunityPriority.INVESTMENT)
				state["player_acts"] = int(state.get("player_acts", 0)) + 1
		"overprotect":
			if day == 7:
				var size: Vector2i = city.logistics.map_size()
				for y in range(0, size.y, TownWoodland.MAX_MARK_SIDE):
					for x in range(0, size.x, TownWoodland.MAX_MARK_SIDE):
						var from: Vector2i = Vector2i(x, y)
						var to: Vector2i = (from + Vector2i.ONE * (TownWoodland.MAX_MARK_SIDE - 1)).min(size - Vector2i.ONE)
						if not city.woodland.get_wooded_in_block(from, to).all(func(t: Vector2i) -> bool: return city.woodland.is_protected(t)):
							city.woodland.protect_block(from, to)
				state["player_acts"] = int(state.get("player_acts", 0)) + 1
		"attentive":
			if day % 7 != 0:
				return
			var titles: Array[String] = []
			for card: Dictionary in SidebarOverviewPage.get_attention(city):
				titles.append(str(card["title"]))
			var food_short: bool = titles.any(func(t: String) -> bool: return t.begins_with("Food") or t.contains("less food"))
			var tools_short: bool = titles.any(func(t: String) -> bool: return t.begins_with("Tools")) and FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS) == 0
			var wood_short: bool = titles.any(func(t: String) -> bool: return t.begins_with("Wood") or t == "Timber is running out" or t == SidebarOverviewPage.FUEL_COLD_TITLE or t == SidebarOverviewPage.FUEL_SHORT_TITLE)
			for want: Array in [[food_short, TownInfluence.ACTIVITY_FOOD], [tools_short, TownInfluence.ACTIVITY_TOOLS], [wood_short, TownInfluence.ACTIVITY_WOOD]]:
				if bool(want[0]) and not FocusedAppeal.is_active(city, str(want[1])):
					FocusedAppeal.make(city, str(want[1]))
					state["player_acts"] = int(state.get("player_acts", 0)) + 1

# The valid spot with the most of the workplace's deposit underfoot, then the nearest the stockpile.
static func choose_commission_site(city: City, building_type: String) -> Vector2i:
	city.logistics.ensure_ready()
	var center: Vector2i = city.logistics.stockpile_tile
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			var origin: Vector2i = Vector2i(x, y)
			if city.construction.validate(building_type, origin)["is_valid"] != true:
				continue
			var score: float = count_deposit(city, building_type, origin) * 1000.0 - Vector2(origin).distance_to(Vector2(center))
			if score > best_score:
				best_score = score
				best = origin
	return best

static func count_deposit(city: City, building_type: String, origin: Vector2i) -> int:
	if not DEPOSIT_OF.has(building_type):
		return 0
	var size: Vector2i = city.construction.get_size(building_type)
	var count: int = 0
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			if y < city.local_map.size() and x < (city.local_map[y] as Array).size() and str(city.local_map[y][x].get("resource", "none")) == str(DEPOSIT_OF[building_type]):
				count += 1
	return count

static func count_woods(city: City) -> int:
	var count: int = 0
	for row: Array in city.local_map:
		for tile: Dictionary in row:
			count += 1 if tile.get("has_trees", false) == true else 0
	return count

# The town at a moment as one number: its stores, its families and its buildings.
static func fingerprint(city: City) -> int:
	var parts: Array = []
	for good: String in Invariants.get_goods():
		parts.append(int(city.resources.get(good, 0)))
	for household: Household in city.households:
		parts.append([household.id, household.total_population, household.hardship_points, snappedf(household.larder, 0.001), household.family_trade])
	for building: Building in city.buildings:
		parts.append([building.id, building.type, building.tile, building.assigned_household_id, building.maintenance_level])
	return hash(parts)

static func first_difference(a: Array, b: Array) -> int:
	for i in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return i + 1
	return mini(a.size(), b.size()) + 1

# One town at one moment, in the test plan's metric categories (section 6).
func measure(city: City, state: Dictionary, off_the_ground: bool) -> Dictionary:
	var m: Dictionary = {}
	m["off_the_ground"] = off_the_ground
	# The test plan's success (section 10b), measured the same at any snapshot: alive, its founding
	# families' number kept, everyone housed, and fed this past month.
	var housed: bool = city.households.all(func(h: Household) -> bool: return h.housing_status == Household.RESIDENCE_HOUSED)
	var fed: bool = int(state.get("short_days_last_month", 0)) == 0
	m["success"] = city.households.size() >= EconomyBalance.FOUNDING_FAMILIES and housed and fed
	m["failure"] = city.households.size() < EconomyBalance.FOUNDING_FAMILIES
	m["people"] = city.get_total_population()
	m["households"] = city.households.size()
	m["departed"] = int(city.resources.get("departed_households", 0))
	m["arrived"] = int(city.resources.get("arrived_households", 0))
	m["old_age"] = int(state["old_age"])
	m["short_days"] = int(state["short_days"])
	# Winter fuel (TownFuel, sprint S3).
	m["fuel_burned"] = city.fuel_burned
	m["fuel_short_days"] = city.fuel_short_days
	m["first_year_short_days"] = int(state["first_year_short_days"])
	m["household_short_days"] = city.influence.household_short_days
	m["tools_out_days"] = int(state["tools_out_days"])
	m["food_days"] = snappedf(FamilyInitiative.get_food_days(city), 0.1)
	var larder: float = 0.0
	for household: Household in city.households:
		larder += household.larder
	m["larder_food"] = snappedf(larder, 0.1)
	var stores: Dictionary = {}
	for good: String in Invariants.get_goods():
		if int(city.resources.get(good, 0)) != 0:
			stores[good] = int(city.resources[good])
	m["stores"] = stores
	var flows: Dictionary = {}
	for good: String in city._flows.keys():
		flows[good] = (city._flows[good] as Dictionary).duplicate()
	m["flows"] = flows
	m["commissioned"] = (state["commissioned"] as Array).duplicate(true)
	m["player_acts"] = int(state.get("player_acts", 0))
	m["woods_start"] = int(state["woods_start"])
	m["woods_now"] = count_woods(city)
	# Who does what: the holding each family works, by trade.
	var trades: Dictionary = {}
	var outside_food: int = 0
	var holders: int = 0
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding == null:
			continue
		var trade: String = BuildingTiers.get_base_type(holding.type)
		trades[trade] = int(trades.get(trade, 0)) + 1
		holders += 1
		outside_food += 0 if FOOD_TRADES.has(trade) else 1
	m["trades"] = trades
	m["outside_food_share"] = snappedf(float(outside_food) / float(maxi(1, holders)), 0.01)
	var diversity: float = 1.0
	for count in trades.values():
		diversity -= pow(float(count) / float(maxi(1, holders)), 2.0)
	m["trade_diversity"] = snappedf(diversity, 0.01)
	var kinds: Dictionary = {}
	for building: Building in city.buildings:
		kinds[building.type] = int(kinds.get(building.type, 0)) + 1
	m["buildings"] = kinds
	m["projects_open"] = city.construction.projects.size()
	m["homes_by_families"] = city.construction.completed_by_households
	m["improvements"] = city.influence.improvements_started
	var trust: float = 0.0
	for household: Household in city.households:
		trust += household.trust
	m["trust"] = snappedf(trust / maxf(1.0, city.households.size()), 0.01)
	m["value_changes"] = city.social.value_changes
	var times: Array = (state["day_ms"] as Array).duplicate()
	times.sort()
	var total: float = 0.0
	for t in times:
		total += float(t)
	m["day_ms_mean"] = snappedf(total / maxf(1.0, times.size()), 0.01)
	m["day_ms_max"] = snappedf(float(times[-1]) if not times.is_empty() else 0.0, 0.01)
	# The town's own tick alone, without the stand-in player's searching.
	m["tick_ms_mean"] = snappedf(float(state.get("tick_usec", 0)) / 1000.0 / maxf(1.0, float(state.get("days", 1))), 0.01)
	m["memory_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	return m

# --- Reporting -------------------------------------------------------------------------------------

func summarize(environment: String, condition: String, policy: String, year: int, rows: Array) -> void:
	if rows.is_empty():
		return
	var alive: int = rows.filter(func(r: Dictionary) -> bool: return int(r["households"]) > 0).size()
	var kept: int = rows.filter(func(r: Dictionary) -> bool: return int(r["households"]) >= EconomyBalance.FOUNDING_FAMILIES).size()
	var off: int = rows.filter(func(r: Dictionary) -> bool: return bool(r.get("success", r["off_the_ground"]))).size()
	var trades: Dictionary = {}
	var made: Dictionary = {}
	for row: Dictionary in rows:
		for trade: String in (row["trades"] as Dictionary).keys():
			trades[trade] = int(trades.get(trade, 0)) + int(row["trades"][trade])
		for good: String in (row["flows"] as Dictionary).keys():
			made[good] = int(made.get(good, 0)) + int((row["flows"][good] as Dictionary).get("made", 0))
	var n: float = float(rows.size())
	var trade_text: Array[String] = []
	for trade: String in trades.keys():
		trade_text.append("%s %.1f" % [trade, trades[trade] / n])
	var made_text: Array[String] = []
	for good: String in made.keys():
		made_text.append("%s %.0f" % [good, made[good] / n])
	_report("SUM %-15s %-8s %-8s y%d | towns %d | alive %d | kept founders %d | succeeding %d | people %s | departed %s | old age %s | short days %s | first-year short %s | tools-out days %s | food days %s | outside-food share %s | diversity %s | woods left %s | day ms %s" % [
		environment, condition, policy, year, rows.size(), alive, kept, off, spread(rows, "people"), spread(rows, "departed"), spread(rows, "old_age"),
		spread(rows, "short_days"), spread(rows, "first_year_short_days"), spread(rows, "tools_out_days"), spread(rows, "food_days"),
		spread(rows, "outside_food_share"), spread(rows, "trade_diversity"), spread_ratio(rows, "woods_now", "woods_start"), spread(rows, "day_ms_mean")])
	_report("SUM %-15s %-8s %-8s y%d | holdings per town: %s" % [environment, condition, policy, year, ", ".join(trade_text)])
	_report("SUM %-15s %-8s %-8s y%d | made per town: %s" % [environment, condition, policy, year, ", ".join(made_text)])

# "median [min-max]" of a measure over the towns.
static func spread(rows: Array, key: String) -> String:
	var values: Array = rows.map(func(r: Dictionary) -> float: return float(r[key]))
	values.sort()
	return "%s [%s-%s]" % [_number(values[values.size() / 2]), _number(values[0]), _number(values[-1])]

static func spread_ratio(rows: Array, key: String, of: String) -> String:
	var values: Array = rows.map(func(r: Dictionary) -> float: return float(r[key]) / maxf(1.0, float(r[of])))
	values.sort()
	return "%.2f [%.2f-%.2f]" % [values[values.size() / 2], values[0], values[-1]]

static func _number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.2f" % value

func _report(line: String) -> void:
	print("[DIV] " + line)
