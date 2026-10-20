extends SceneTree

# Opening check: how forgiving is the start? Founds the same 20 towns (each with different
# founding families and values) under several build orders, good and bad, plays two years, and
# reports which towns got off the ground and why the others did not.
# Run: <godot> --headless --path . --script res://tests/sim/opening_check.gd   (filter for [OPEN])
# Only some build orders: add  -- toolmaker  (runs scenarios whose name contains "toolmaker").
#
# A town is "off the ground" at the end of year 2 when every family is housed, it had no food
# shortage in the last 90 days, and it has at least as many families as founded it.
#
# Limits: the headless run ignores terrain (fertile land, trees, water), so map luck is not tested;
# towns differ only in their founding families.

const CityScript = preload("res://scripts/domain/city.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const SimulationClockScript = preload("res://scripts/simulation/simulation_clock.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")

const SITES: int = 20
const DAYS: int = 720
const POLICY_INTERVAL_DAYS: int = 5
const SHORTAGE_WINDOW_DAYS: int = 90
const STUCK_WOOD_DAYS: int = 60

# prebuild: built in order on day 0 while affordable ("*" repeats the type until unaffordable).
# never: types the player never builds. not_before: {type: day}. idle_until: no building before
# that day. max_count: {type: n}.
const SCENARIOS: Array = [
	{"name": "sensible"},
	{"name": "owner_first_playtest", "prebuild": ["house", "house", "house", "farm", "woodcutter", "toolmaker"]},
	{"name": "all_wood_on_houses_first", "prebuild": ["house*"]},
	{"name": "four_farms_first", "prebuild": ["farm", "farm", "farm", "farm"]},
	{"name": "spend_all_before_woodcutter", "prebuild": ["house", "farm", "house", "farm", "house*", "farm*"], "not_before": {"woodcutter": 9999}},
	{"name": "woodcutter_day_60", "not_before": {"woodcutter": 60}},
	{"name": "woodcutter_day_120", "not_before": {"woodcutter": 120}},
	{"name": "toolmaker_day_60", "not_before": {"toolmaker": 60}},
	{"name": "toolmaker_day_90", "not_before": {"toolmaker": 90}},
	{"name": "toolmaker_day_120", "not_before": {"toolmaker": 120}},
	{"name": "toolmaker_day_150", "not_before": {"toolmaker": 150}},
	{"name": "toolmaker_day_180", "not_before": {"toolmaker": 180}},
	{"name": "toolmaker_day_365", "not_before": {"toolmaker": 365}},
	{"name": "never_toolmaker", "never": ["toolmaker"]},
	{"name": "idle_first_60_days", "idle_until": 60},
	{"name": "only_one_farm", "max_count": {"farm": 1}},
	{"name": "never_houses", "never": ["house"]}
]

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	_report("balance: %d founding families; food %.1f, wood %.1f, tools %.1f per family-day; start %d food, %d wood, %d tools" % [
		EconomyBalanceScript.FOUNDING_FAMILIES,
		EconomyBalanceScript.FARM_FOOD_PER_DAY, EconomyBalanceScript.WOODCUTTER_WOOD_PER_DAY, EconomyBalanceScript.TOOLMAKER_TOOLS_PER_DAY,
		EconomyBalanceScript.STARTING_FOOD, EconomyBalanceScript.STARTING_WOOD, EconomyBalanceScript.STARTING_TOOLS])
	var only: Array = OS.get_cmdline_user_args()
	for scenario: Dictionary in SCENARIOS:
		if not only.is_empty() and not str(scenario["name"]).contains(str(only[0])):
			continue
		_run_scenario(scenario)
	quit()

func _run_scenario(scenario: Dictionary) -> void:
	var made_it: int = 0
	var reasons: Dictionary = {}
	var smallest: Dictionary = {}
	var largest: Dictionary = {}
	var total_people: int = 0
	var tools_out_days: Array[int] = []
	for site in range(SITES):
		var result: Dictionary = _play(scenario, Vector2(5 + site * 3, 7 + site * 2))
		total_people += int(result["population"])
		if int(result["tools_out_day"]) >= 0:
			tools_out_days.append(int(result["tools_out_day"]))
		if result["off_the_ground"]:
			made_it += 1
		for reason: String in result["reasons"]:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		if smallest.is_empty() or int(result["population"]) < int(smallest["population"]):
			smallest = result
		if largest.is_empty() or int(result["population"]) > int(largest["population"]):
			largest = result
	var reason_text: String = "none"
	if not reasons.is_empty():
		var parts: Array[String] = []
		for reason in reasons.keys():
			parts.append(str(reason) + " x" + str(reasons[reason]))
		reason_text = ", ".join(parts)
	_report("%-28s %2d/%d off the ground | avg people %.0f (smallest %d, largest %d) | problems: %s" % [
		scenario["name"], made_it, SITES, float(total_people) / SITES, int(smallest["population"]), int(largest["population"]), reason_text])
	_report("    smallest town founders: %s | largest: %s" % [smallest["founders"], largest["founders"]])
	if not tools_out_days.is_empty():
		tools_out_days.sort()
		_report("    tools ran out in %d towns, earliest day %d (%.1f min at 1x)" % [
			tools_out_days.size(), tools_out_days[0], float(tools_out_days[0]) * SimulationClockScript.DEFAULT_DAY_SECONDS_AT_1X / 60.0])

func _play(scenario: Dictionary, site: Vector2) -> Dictionary:
	var city = CityScript.new("Player Town", site, CityScript.ROLE_PLAYER, EconomyBalanceScript.FOUNDING_FAMILIES)
	var founders: String = _describe_founders(city)
	for entry: String in scenario.get("prebuild", []):
		if entry.ends_with("*"):
			while _try_build(city, entry.trim_suffix("*"), scenario, 0):
				pass
		else:
			_try_build(city, entry, scenario, 0)

	var calendar: Calendar = Calendar.new()
	var last_shortage_day: int = -SHORTAGE_WINDOW_DAYS - 1
	var low_wood_streak: int = 0
	var stuck_on_wood: bool = false
	var ran_out_of_tools: bool = false
	var tools_out_day: int = -1
	for day in range(DAYS):
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
			_upgrade_one(city, scenario, day)
			var wanted: String = _choose_build(city, scenario, day)
			if wanted == "":
				low_wood_streak = 0
			elif _try_build(city, wanted, scenario, day) or _try_build(city, _tier0_fallback(wanted), scenario, day):
				low_wood_streak = 0
			elif int(city.resources["wood"]) < int(EconomyBalanceScript.get_build_cost(wanted).get("wood", 0)):
				low_wood_streak += POLICY_INTERVAL_DAYS
				if low_wood_streak >= STUCK_WOOD_DAYS:
					stuck_on_wood = true

	var all_housed: bool = true
	for household: Household in city.households:
		if household.housing_status != Household.RESIDENCE_HOUSED:
			all_housed = false
	var fed: bool = DAYS - 1 - last_shortage_day > SHORTAGE_WINDOW_DAYS
	var reasons: Array[String] = []
	if city.households.size() < 4:
		reasons.append("families left")
	if not all_housed:
		reasons.append("unhoused")
	if not fed:
		reasons.append("hungry")
	if ran_out_of_tools:
		reasons.append("ran out of tools")
	if stuck_on_wood:
		reasons.append("stuck on wood")
	return {
		"off_the_ground": all_housed and fed and city.households.size() >= EconomyBalanceScript.FOUNDING_FAMILIES,
		"reasons": reasons,
		"population": city.get_total_population(),
		"tools_out_day": tools_out_day,
		"founders": founders
	}

# A reasonable player: a wood source first, then shelter, food, tools, and room to grow.
# Workplaces are only built when a family has labor free to work them. Scenario rules can
# forbid or delay a choice, in which case the next want is considered.
func _choose_build(city, scenario: Dictionary, day: int) -> String:
	var counts: Dictionary = _count_types(city)
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
		if _allowed(want, scenario, day, counts):
			return want
	return ""

# Scenario rules apply to the kind of building, so delaying the woodcutter also delays the
# gatherer's camp (forgetting wood means forgetting both).
func _allowed(building_type: String, scenario: Dictionary, day: int, counts: Dictionary) -> bool:
	building_type = BuildingTiersScript.get_base_type(building_type)
	if (scenario.get("never", []) as Array).has(building_type):
		return false
	if day < int((scenario.get("not_before", {}) as Dictionary).get(building_type, 0)):
		return false
	var max_count: Dictionary = scenario.get("max_count", {})
	if max_count.has(building_type) and int(counts.get(building_type, 0)) >= int(max_count[building_type]):
		return false
	return true

func _try_build(city, building_type: String, scenario: Dictionary, day: int) -> bool:
	if building_type == "":
		return false
	if not _allowed(building_type, scenario, day, _count_types(city)):
		return false
	var cost: Dictionary = EconomyBalanceScript.get_build_cost(building_type)
	if not city.can_afford_cost(cost):
		return false
	city.pay_cost(cost)
	city.add_building(Building.new(-1, building_type))
	return true

# Counts by kind: a gatherer's camp counts as a woodcutter, a hut as a house.
func _count_types(city) -> Dictionary:
	var counts: Dictionary = {}
	for building: Building in city.buildings:
		var kind: String = BuildingTiersScript.get_base_type(building.type)
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

# When the proper building is unaffordable, a player falls back to tier 0 hand work.
func _tier0_fallback(building_type: String) -> String:
	for tier0_type in BuildingTiersScript.TIER0_TO_TIER1.keys():
		if BuildingTiersScript.TIER0_TO_TIER1[tier0_type] == building_type:
			return str(tier0_type)
	return ""

# Upgrade one tier 0 building per policy step when affordable: wood and tools first.
func _upgrade_one(city, scenario: Dictionary, day: int) -> void:
	for tier0_type: String in ["gatherer_camp", "tool_mender", "forager_garden", "hut"]:
		var upgrade_type: String = BuildingTiersScript.get_upgrade_type(tier0_type)
		if day < int((scenario.get("not_before", {}) as Dictionary).get(upgrade_type, 0)):
			continue
		for building: Building in city.buildings:
			if building.type == tier0_type and city.upgrade_building(building.id):
				return

func _describe_founders(city) -> String:
	var callings: Array[String] = []
	for household: Household in city.households:
		var names: Array[String] = []
		for calling in household.values.get(CultureValuesScript.CATEGORY_CALLING, []):
			names.append(str(calling))
		callings.append("+".join(names))
	return ", ".join(callings)

func _report(line: String) -> void:
	print("[OPEN] " + line)
