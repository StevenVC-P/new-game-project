extends RefCounted

# A simple, reasonable stand-in player used by the balance tools (opening_check, map_luck_check).
# It plays a town for a number of days and reports whether it got off the ground.
#
# Policy: a wood source first, then shelter, food, tools, and room to grow. Workplaces are only
# planned when a family is free to work them (counting workplaces already planned). Everything is
# built through the town's construction pipeline (TownConstruction): it plans a building only
# when the stores can supply it on top of what other sites still need, and the town's families
# build it over the following days. When a proper (tier 1) building is unaffordable it falls back
# to tier 0 hand work, and it upgrades tier 0 in place when it can. It never reassigns families
# between jobs, so it is somewhat worse than a real player.
#
# With a town map (`city.local_map` filled), every building must find a valid spot on it
# (fertile land for farms, trees for camps, nothing blocked), searched outward from the town's
# stockpile at its heart. Without one, buildings are placed without terrain or travel.

const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")

const POLICY_INTERVAL_DAYS: int = 5
const SHORTAGE_WINDOW_DAYS: int = 90
const STUCK_WOOD_DAYS: int = 60

# Building kinds that could not find a valid spot on the map at least once.
var blocked_by_map: Dictionary = {}

# scenario: see opening_check.gd (prebuild, never, not_before, idle_until, max_count), plus, on a
# town map, "homes_on_plots" (set aside residential plots and let families build their own homes
# instead of placing houses) and "scattered" (build far out instead of close to the stockpile);
# and "instant" (the rules before construction: pay and place finished buildings at once), as a
# control for measuring what construction changes; and "planned" (every month after the first
# few, fence fields people walk through, put a storehouse beside a workplace that loses much of
# its day to carrying), for the planning check; with "answer_wishes", it also builds the work
# families wish for (FamilyAmbitions).
func play(city, scenario: Dictionary, days: int) -> Dictionary:
	var uses_map: bool = not city.local_map.is_empty()
	for entry: String in scenario.get("prebuild", []):
		if entry.ends_with("*"):
			while try_build(city, entry.trim_suffix("*"), scenario, 0):
				pass
		else:
			try_build(city, entry, scenario, 0)

	var calendar: Calendar = Calendar.new()
	var last_shortage_day: int = -SHORTAGE_WINDOW_DAYS - 1
	var low_wood_streak: int = 0
	var stuck_on_wood: bool = false
	var ran_out_of_tools: bool = false
	var tools_out_day: int = -1
	var stalled_site_days: int = 0
	var first_home_day: int = -1
	for day in range(days):
		var month_before: int = calendar.current_month
		var season_before: String = calendar.get_current_season()
		calendar.advance_day()
		city.tick()
		if calendar.current_month != month_before:
			city.advance_household_lifecycle_month(0)
		if calendar.get_current_season() != season_before:
			city.advance_household_birth_rolls_season(calendar, 0)
		if city.resources["food_shortage"] == true:
			last_shortage_day = day
		for project: ConstructionProject in city.construction.projects:
			if project.blocked_reason == "no builders free":
				stalled_site_days += 1
		if first_home_day < 0 and int(city.resources["house_shelter_capacity"]) > 0:
			first_home_day = day
		if day > 30 and int(city.resources["tools"]) == 0:
			ran_out_of_tools = true
			if tools_out_day < 0:
				tools_out_day = day
		if scenario.get("planned", false) and uses_map and day >= PLANNING_START_DAY and day % PLANNING_INTERVAL_DAYS == 0:
			plan_town(city, scenario)
		if scenario.get("trades", false) and uses_map:
			trade(city, day)
		if day % POLICY_INTERVAL_DAYS == 0 and day >= int(scenario.get("idle_until", 0)):
			upgrade_one(city, scenario, day)
			var wanted: String = choose_build(city, scenario, day)
			if wanted == "":
				low_wood_streak = 0
			elif try_build(city, wanted, scenario, day) or try_build(city, tier0_fallback(wanted), scenario, day):
				low_wood_streak = 0
			elif int(city.resources["wood"]) < int(EconomyBalanceScript.get_build_cost(wanted).get("wood", 0)):
				low_wood_streak += POLICY_INTERVAL_DAYS
				if low_wood_streak >= STUCK_WOOD_DAYS:
					stuck_on_wood = true

	var all_housed: bool = true
	for household: Household in city.households:
		if household.housing_status != Household.RESIDENCE_HOUSED:
			all_housed = false
	var fed: bool = days - 1 - last_shortage_day > SHORTAGE_WINDOW_DAYS
	var kept_families: bool = city.households.size() >= EconomyBalanceScript.FOUNDING_FAMILIES
	var homes_by_families: int = city.construction.completed_by_households
	var reasons: Array[String] = []
	if not kept_families:
		reasons.append("families left")
	if not all_housed:
		reasons.append("unhoused")
	if not fed:
		reasons.append("hungry")
	if ran_out_of_tools:
		reasons.append("ran out of tools")
	if stuck_on_wood:
		reasons.append("stuck on wood")
	if uses_map:
		for kind in blocked_by_map.keys():
			reasons.append("no room for " + str(kind))
	return {
		"off_the_ground": all_housed and fed and kept_families,
		"reasons": reasons,
		"population": city.get_total_population(),
		"tools_out_day": tools_out_day,
		"stalled_site_days": stalled_site_days,
		"first_home_day": first_home_day,
		"travel_share": average_travel_share(city),
		"buildings": city.buildings.size(),
		"homes_by_families": homes_by_families,
		"households": city.households.size(),
		"food": int(city.resources["food"]),
		"fences": count_fences(city),
		"storehouses": count_kinds(city).get("storehouse", 0),
		"content": city.households.filter(func(h: Household) -> bool: return h.contentment > 0).size(),
		"linked": 1 if city.trade.get_link() != TownTrade.LINK_NONE else 0,
		"trader_visits": city.trade.visits,
		"trades": city.trade.trades_made,
		"calling_wishes": city.households.filter(func(h: Household) -> bool: return h.ambition == FamilyAmbitions.CALLING).size()
	}

func choose_build(city, scenario: Dictionary, day: int) -> String:
	var counts: Dictionary = count_kinds(city)
	var idle_labor: bool = int(city.resources["idle_workers"]) - count_planned_workplaces(city) > 0
	var houses: int = int(counts.get("house", 0))
	var woodcutters: int = int(counts.get("woodcutter", 0))
	var toolmakers: int = int(counts.get("toolmaker", 0))
	var food_needed: int = city.get_food_consumption_for_population(city.get_total_population())
	var wants: Array[String] = []
	if woodcutters == 0:
		wants.append("woodcutter")
	if houses < city.households.size():
		wants.append("house")
	if idle_labor and HouseholdMigrationScript.estimate_daily_food_production(city) < float(food_needed) * 1.15:
		wants.append(choose_food(city, scenario, day, counts))
	if idle_labor and toolmakers == 0 and int(city.resources["tools"]) < 10:
		wants.append("toolmaker")
	if idle_labor and int(city.resources["wood"]) < 10 and woodcutters < 1 + toolmakers:
		wants.append("woodcutter")
	if houses < city.households.size() + 2:
		wants.append("house")
	for want: String in wants:
		if allowed(want, scenario, day, counts):
			return want
	return ""

# Food from the land where it is good (docs/FIRST_STAGE_LOOP.md, Geography): a fisher's hut on a
# bank with water in reach, a hunter's lodge at the edge of plenty of woods, each taken while the
# town has fewer of them than farms; otherwise a farm.
const LAND_FOOD_MIN_REACH: float = 0.75
const LAND_FOOD_MAX_EACH: int = 2

func choose_food(city, scenario: Dictionary, day: int, counts: Dictionary) -> String:
	if city.local_map.is_empty() or not scenario.get("land_food", true):
		return "farm"
	var land_food: int = int(counts.get(Building.BUILDING_FISHER, 0)) + int(counts.get(Building.BUILDING_HUNTER, 0))
	if land_food > int(counts.get(Building.BUILDING_FARM, 0)):
		return "farm"
	for kind: String in [Building.BUILDING_FISHER, Building.BUILDING_HUNTER]:
		if not allowed(kind, scenario, day, counts) or int(counts.get(kind, 0)) >= LAND_FOOD_MAX_EACH:
			continue
		var spot: Vector2i = find_spot(city, kind)
		if spot.x >= 0 and city.land.get_reach_factor_at(kind, spot, city.construction.get_size(kind)) >= LAND_FOOD_MIN_REACH:
			return kind
	return "farm"

# Scenario rules apply to the kind of building, so delaying the woodcutter also delays the
# gatherer's camp (forgetting wood means forgetting both).
func allowed(building_type: String, scenario: Dictionary, day: int, counts: Dictionary) -> bool:
	building_type = BuildingTiersScript.get_base_type(building_type)
	if (scenario.get("never", []) as Array).has(building_type):
		return false
	if day < int((scenario.get("not_before", {}) as Dictionary).get(building_type, 0)):
		return false
	var max_count: Dictionary = scenario.get("max_count", {})
	if max_count.has(building_type) and int(counts.get(building_type, 0)) >= int(max_count[building_type]):
		return false
	return true

func try_build(city, building_type: String, scenario: Dictionary, day: int) -> bool:
	if building_type == "":
		return false
	if not allowed(building_type, scenario, day, count_kinds(city)):
		return false
	if scenario.get("homes_on_plots", false) and not city.local_map.is_empty() and BuildingTiersScript.get_base_type(building_type) == Building.BUILDING_HOUSE:
		return set_aside_plot(city, scenario)
	if not city.construction.can_supply(EconomyBalanceScript.get_build_cost(building_type)):
		return false
	var origin: Vector2i = Vector2i.ZERO
	if not city.local_map.is_empty():
		origin = find_spot(city, building_type, scenario.get("scattered", false))
		# A planner puts a new home beside the workplace whose family walks farthest to it.
		if scenario.get("planned", false) and BuildingTiersScript.get_base_type(building_type) == Building.BUILDING_HOUSE:
			var near_work: Vector2i = home_spot_near_work(city, building_type)
			if near_work.x >= 0:
				origin = near_work
		if origin.x < 0:
			blocked_by_map[BuildingTiersScript.get_base_type(building_type)] = true
			return false
	if scenario.get("instant", false):
		return build_at_once(city, building_type, origin)
	return city.construction.request_building(building_type, origin) != null

func build_at_once(city, building_type: String, origin: Vector2i) -> bool:
	var size: Vector2i = city.construction.get_size(building_type)
	city.construction.set_occupied(TownLogistics.footprint(origin, size), true)
	city.pay_cost(EconomyBalanceScript.get_build_cost(building_type))
	city.add_building(Building.new(-1, building_type, origin, size))
	return true

# Map positions sorted by distance from the center, computed once per map size.
var _origins_by_distance: Array[Vector2i] = []
# How far out a scattered town builds, in tiles from its stockpile.
const SCATTERED_RADIUS: float = 22.0

# Sets one more plot aside for a family that needs a home, nearest the stockpile first (open plots
# count as planned homes in count_kinds).
func set_aside_plot(city, scenario: Dictionary) -> bool:
	var origin: Vector2i = find_spot(city, "plot", scenario.get("scattered", false))
	return origin.x >= 0 and city.construction.designate_plot(origin) >= 0

const PLANNING_START_DAY: int = 120
const PLANNING_INTERVAL_DAYS: int = 30
# A workplace losing more than this share of its day to travel earns a storehouse beside it.
const STOREHOUSE_TRAVEL_SHARE: float = 0.08
# Daily trips through a field before the planner fences it.
const FENCE_TRAMPLING_TRIPS: float = 0.5

# What a thoughtful player does once the town is running: fence the fields people trample, and
# bring a store to the workplace that carries farthest.
func plan_town(city, scenario: Dictionary = {}) -> void:
	if scenario.get("answer_wishes", false):
		answer_calling_wish(city)
	for building: Building in city.buildings:
		if TownLogistics.is_field(building) and float(city.logistics.trampled_trips.get(building.id, 0.0)) >= FENCE_TRAMPLING_TRIPS and city.construction.can_fence(building.id) and city.construction.can_supply(EconomyBalanceScript.get_fence_cost(building.size)):
			city.construction.request_fence(building.id)
	var farthest: Building = null
	var worst: float = STOREHOUSE_TRAVEL_SHARE
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers > 0:
			var share: float = city.logistics.get_travel_share(building)
			if share > worst:
				worst = share
				farthest = building
	if farthest == null or count_kinds(city).get("storehouse", 0) >= 3 or not city.construction.can_supply(EconomyBalanceScript.get_build_cost("storehouse")):
		return
	var spot: Vector2i = find_spot_near(city, "storehouse", TownLogistics.center_tile(farthest.tile, farthest.size))
	if spot.x >= 0:
		city.construction.request_building("storehouse", spot)

# Work a planner builds when families wish for work of their calling (FamilyAmbitions), only while
# some family has labor to spare: the wishing family moves to it, and the spare family takes up
# the work it leaves.
const CALLING_ANSWERS: Array[String] = ["fisher", "hunter", "farm", "woodcutter", "toolmaker"]

# A thoughtful player answers the town's most common calling wish, one workplace at a time.
func answer_calling_wish(city) -> void:
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers <= 0:
			return
	if city.get_available_households().is_empty():
		return
	var wanted: Dictionary = {}
	for household: Household in city.households:
		if household.ambition == FamilyAmbitions.CALLING:
			for building_type: String in FamilyAmbitions.get_calling_work(household, city):
				if CALLING_ANSWERS.has(building_type):
					wanted[building_type] = int(wanted.get(building_type, 0)) + 1
	for project: ConstructionProject in city.construction.projects:
		wanted.erase(BuildingTiersScript.get_base_type(project.building_type))
	var best: String = ""
	for building_type: String in wanted.keys():
		if best == "" or int(wanted[building_type]) > int(wanted[best]):
			best = building_type
	if best == "" or not city.construction.can_supply(EconomyBalanceScript.get_build_cost(best)):
		return
	var spot: Vector2i = find_spot(city, best)
	if spot.x < 0:
		return
	# Only where the water or woods in reach give a good catch, as for a food opening.
	if (best == Building.BUILDING_FISHER or best == Building.BUILDING_HUNTER) and city.land.get_reach_factor_at(best, spot, city.construction.get_size(best)) < LAND_FOOD_MIN_REACH:
		return
	city.construction.request_building(best, spot)

# Trading (TownTrade): an isolated town builds a road out once it has wood to spare; with a trader
# in town, it takes lots that swap a surplus for a shortage, a few a day.
const ROAD_OUT_WOOD: int = 40
const TRADES_PER_DAY: int = 3
const SURPLUS_FOOD_DAYS: float = 90.0
const SHORT_FOOD_DAYS: float = 30.0
const SURPLUS: Dictionary = {"wood": 80, "stone_blocks": 30, "bricks": 30, "carved_goods": 5, "tools": 25}
const SHORT: Dictionary = {"wood": 20, "tools": 8, "stone_blocks": 5}

func trade(city, day: int) -> void:
	if day % PLANNING_INTERVAL_DAYS == 0 and city.trade.get_link() == TownTrade.LINK_NONE and int(city.resources["wood"]) >= ROAD_OUT_WOOD and not city.construction.projects.any(func(p: ConstructionProject) -> bool: return p.kind == ConstructionProject.KIND_ROAD):
		build_road_out(city)
	if not city.trade.is_trader_here():
		return
	for _i in range(TRADES_PER_DAY):
		var chosen: int = -1
		var lots: Array[Dictionary] = city.trade.get_lots()
		for index in range(lots.size()):
			if is_surplus(city, lots[index]["give"], int(lots[index]["give_amount"])) and is_short(city, lots[index]["get"]):
				chosen = index
				break
		if chosen < 0 or not city.trade.accept_lot(chosen):
			return

func food_days(city) -> float:
	return float(city.resources["food"]) / maxf(1.0, float(city.resources["food_consumption_rate"]))

func is_surplus(city, good: String, amount: int) -> bool:
	if good == "food":
		return (float(city.resources["food"]) - amount) / maxf(1.0, float(city.resources["food_consumption_rate"])) >= SURPLUS_FOOD_DAYS
	return SURPLUS.has(good) and int(city.resources.get(good, 0)) - amount >= int(SURPLUS[good])

func is_short(city, good: String) -> bool:
	if good == "food":
		return food_days(city) < SHORT_FOOD_DAYS
	return SHORT.has(good) and int(city.resources.get(good, 0)) < int(SHORT[good])

# A road from open ground beside the town's heart to the nearest road already on the map, or else
# to the nearest open ground on the map's edge (a road's ends must be ground a road can take).
func build_road_out(city) -> void:
	var heart: Vector2i = city.trade.get_heart()
	var size: Vector2i = city.logistics.map_size()
	var start: Vector2i = Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	for y in range(size.y):
		for x in range(size.x):
			var tile: Vector2i = Vector2i(x, y)
			var on_edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			var roadable: bool = city.construction.is_roadable(tile)
			if roadable and city.trade.is_near_heart(tile, 3) and (start.x < 0 or tile.distance_squared_to(heart) < start.distance_squared_to(heart)):
				start = tile
			if (city.trade.has_road(tile) or (on_edge and roadable)) and (best.x < 0 or tile.distance_squared_to(heart) < best.distance_squared_to(heart)):
				best = tile
	if start.x < 0 or best.x < 0:
		return
	var tiles: Array[Vector2i] = city.construction.plan_road(start, best)
	if not tiles.is_empty():
		city.construction.request_road(tiles)

# A spot for a home next to the workplace whose family has the longest walk to it.
func home_spot_near_work(city, building_type: String) -> Vector2i:
	var farthest: Building = null
	var longest: float = 0.0
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers > 0:
			var walk: float = city.logistics.get_commute_effort(building)
			if walk > longest:
				longest = walk
				farthest = building
	if farthest == null:
		return Vector2i(-1, -1)
	return find_spot_near(city, building_type, TownLogistics.center_tile(farthest.tile, farthest.size))

# The valid spot nearest a tile, within a few tiles.
func find_spot_near(city, building_type: String, near: Vector2i) -> Vector2i:
	for radius in range(1, 8):
		for y in range(near.y - radius, near.y + radius + 1):
			for x in range(near.x - radius, near.x + radius + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) == radius and city.construction.validate(building_type, Vector2i(x, y))["is_valid"] == true:
					return Vector2i(x, y)
	return Vector2i(-1, -1)

static func count_fences(city) -> int:
	var count: int = 0
	for building: Building in city.buildings:
		count += 1 if building.fenced else 0
	return count

# Mean share of the working day the town's workplaces lose to travel.
static func average_travel_share(city) -> float:
	var total: float = 0.0
	var count: int = 0
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers > 0:
			total += city.logistics.get_travel_share(building)
			count += 1
	return total / count if count > 0 else 0.0

# The valid spot closest to the town center, as a player building outward would choose; or, for a
# scattered town, the farthest one within SCATTERED_RADIUS.
func find_spot(city, building_type: String, scattered: bool = false) -> Vector2i:
	if _origins_by_distance.is_empty():
		var height: int = city.local_map.size()
		var width: int = (city.local_map[0] as Array).size()
		city.logistics.ensure_ready()
		var center: Vector2 = Vector2(city.logistics.stockpile_tile) if city.logistics.stockpile_tile.x >= 0 else Vector2(width * 0.5, height * 0.5)
		for y in range(height):
			for x in range(width):
				_origins_by_distance.append(Vector2i(x, y))
		_origins_by_distance.sort_custom(func(a: Vector2i, b: Vector2i): return center.distance_squared_to(Vector2(a)) < center.distance_squared_to(Vector2(b)))
	var center: Vector2 = Vector2(city.logistics.stockpile_tile)
	var found: Vector2i = Vector2i(-1, -1)
	for origin: Vector2i in _origins_by_distance:
		if scattered and Vector2(origin).distance_to(center) > SCATTERED_RADIUS:
			break
		var result: Dictionary = city.construction.validate(building_type, origin)
		if result["is_valid"] == true:
			found = origin
			if not scattered:
				return found
	return found

# Buildings standing and planned, by kind.
func count_kinds(city) -> Dictionary:
	var counts: Dictionary = {}
	for building: Building in city.buildings:
		var kind: String = BuildingTiersScript.get_base_type(building.type)
		counts[kind] = int(counts.get(kind, 0)) + 1
	for project: ConstructionProject in city.construction.projects:
		if project.kind != ConstructionProject.KIND_BUILDING:
			continue
		var kind: String = BuildingTiersScript.get_base_type(project.building_type)
		counts[kind] = int(counts.get(kind, 0)) + 1
	# An open plot is a home a family will build.
	counts[Building.BUILDING_HOUSE] = int(counts.get(Building.BUILDING_HOUSE, 0)) + city.construction.get_open_plots().size()
	return counts

# Workplaces planned but not yet built: each will take a family when it is done.
func count_planned_workplaces(city) -> int:
	var count: int = 0
	for project: ConstructionProject in city.construction.projects:
		if project.kind == ConstructionProject.KIND_BUILDING and not project.is_home():
			count += 1
	return count

func tier0_fallback(building_type: String) -> String:
	for tier0_type in BuildingTiersScript.TIER0_TO_TIER1.keys():
		if BuildingTiersScript.TIER0_TO_TIER1[tier0_type] == building_type:
			return str(tier0_type)
	return ""

# Plans one upgrade of a tier 0 building per policy step when the stores can supply it: wood and
# tools first.
func upgrade_one(city, scenario: Dictionary, day: int) -> void:
	for tier0_type: String in ["gatherer_camp", "tool_mender", "forager_garden", "hut"]:
		var upgrade_type: String = BuildingTiersScript.get_upgrade_type(tier0_type)
		if day < int((scenario.get("not_before", {}) as Dictionary).get(upgrade_type, 0)):
			continue
		if not city.construction.can_supply(EconomyBalanceScript.get_build_cost(upgrade_type)):
			return
		for building: Building in city.buildings:
			if building.type != tier0_type or city.construction.get_upgrade_project(building.id) != null:
				continue
			if scenario.get("instant", false):
				if city.upgrade_building(building.id):
					return
			elif city.construction.request_upgrade(building.id) != null:
				return
