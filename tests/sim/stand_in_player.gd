extends RefCounted

# A simple, reasonable stand-in player used by the balance tools (opening_check, map_luck_check).
# It plays a town for a number of days and reports whether it got off the ground.
#
# Policy: a wood source first, then shelter, food, tools, and room to grow. Workplaces are only
# built when a family has labor free to work them. When a proper (tier 1) building is
# unaffordable it falls back to tier 0 hand work, and it upgrades tier 0 when it can afford to.
# It never reassigns families between jobs, so it is somewhat worse than a real player.
#
# With a town map (`city.local_map` filled), every building must find a valid spot on it
# (fertile land for farms, trees for camps, nothing blocked), searched outward from the center.
# Without one, buildings are placed without terrain, as before.

const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")
const BuildingPlacementScript = preload("res://scripts/ui/building_placement.gd")

const POLICY_INTERVAL_DAYS: int = 5
const SHORTAGE_WINDOW_DAYS: int = 90
const STUCK_WOOD_DAYS: int = 60

var placement = BuildingPlacementScript.new()
# Building kinds that could not find a valid spot on the map at least once.
var blocked_by_map: Dictionary = {}

# scenario: see opening_check.gd (prebuild, never, not_before, idle_until, max_count).
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
		if day > 30 and int(city.resources["tools"]) == 0:
			ran_out_of_tools = true
			if tools_out_day < 0:
				tools_out_day = day
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
		"tools_out_day": tools_out_day
	}

func choose_build(city, scenario: Dictionary, day: int) -> String:
	var counts: Dictionary = count_kinds(city)
	var idle_labor: bool = int(city.resources["idle_workers"]) > 0
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
		wants.append("farm")
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
	var cost: Dictionary = EconomyBalanceScript.get_build_cost(building_type)
	if not city.can_afford_cost(cost):
		return false
	if city.local_map.is_empty():
		city.pay_cost(cost)
		city.add_building(Building.new(-1, building_type))
		return true

	var origin: Vector2i = find_spot(city, building_type)
	if origin.x < 0:
		blocked_by_map[BuildingTiersScript.get_base_type(building_type)] = true
		return false
	var size: Vector2i = placement.get_building_size(building_type)
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			(city.local_map[y][x] as Dictionary)["occupied"] = true
	city.pay_cost(cost)
	city.add_building(Building.new(-1, building_type, origin, size))
	return true

# Map positions sorted by distance from the center, computed once per map size.
var _origins_by_distance: Array[Vector2i] = []

# The valid spot closest to the town center, as a player building outward would choose.
func find_spot(city, building_type: String) -> Vector2i:
	if _origins_by_distance.is_empty():
		var height: int = city.local_map.size()
		var width: int = (city.local_map[0] as Array).size()
		var center: Vector2 = Vector2(width * 0.5, height * 0.5)
		for y in range(height):
			for x in range(width):
				_origins_by_distance.append(Vector2i(x, y))
		_origins_by_distance.sort_custom(func(a: Vector2i, b: Vector2i): return center.distance_squared_to(Vector2(a)) < center.distance_squared_to(Vector2(b)))
	for origin: Vector2i in _origins_by_distance:
		var result: Dictionary = placement.validate(city, city.local_map, building_type, origin)
		if result["is_valid"] == true:
			return origin
	return Vector2i(-1, -1)

func count_kinds(city) -> Dictionary:
	var counts: Dictionary = {}
	for building: Building in city.buildings:
		var kind: String = BuildingTiersScript.get_base_type(building.type)
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func tier0_fallback(building_type: String) -> String:
	for tier0_type in BuildingTiersScript.TIER0_TO_TIER1.keys():
		if BuildingTiersScript.TIER0_TO_TIER1[tier0_type] == building_type:
			return str(tier0_type)
	return ""

# Upgrade one tier 0 building per policy step when affordable: wood and tools first.
func upgrade_one(city, scenario: Dictionary, day: int) -> void:
	for tier0_type: String in ["gatherer_camp", "tool_mender", "forager_garden", "hut"]:
		var upgrade_type: String = BuildingTiersScript.get_upgrade_type(tier0_type)
		if day < int((scenario.get("not_before", {}) as Dictionary).get(upgrade_type, 0)):
			continue
		for building: Building in city.buildings:
			if building.type == tier0_type and city.upgrade_building(building.id):
				return
