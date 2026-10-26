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
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const SITES: int = 20
const DAYS: int = 720

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
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, DAYS)
	result["founders"] = founders
	return result

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
