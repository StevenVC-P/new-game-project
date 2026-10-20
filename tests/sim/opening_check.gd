extends SceneTree

# Opening check: can every town get off the ground? Founds towns at many sites (each gets
# different founding families and values) and plays the first two years with a simple
# stand-in player, then reports which towns made it.
# Run: <godot> --headless --path . --script res://tests/sim/opening_check.gd   (filter for [OPEN])
#
# Openings:
#   owner_build - 3 houses, 1 farm, 1 woodcutter, 1 toolmaker up front (the first playtest), then the policy
#   policy      - the stand-in player's policy from day one
#
# A town is "off the ground" at the end of year 2 when every family is housed, it had no food
# shortage in the last 90 days, and it still has at least its 4 founding families.

const CityScript = preload("res://scripts/domain/city.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")

const SITES: int = 20
const DAYS: int = 720
const POLICY_INTERVAL_DAYS: int = 5
const SHORTAGE_WINDOW_DAYS: int = 90
const STUCK_WOOD_DAYS: int = 60

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	_report("balance food/wood/tools per day: " + str(EconomyBalanceScript.FARM_FOOD_PER_DAY) + "/" + str(EconomyBalanceScript.WOODCUTTER_WOOD_PER_DAY) + "/" + str(EconomyBalanceScript.TOOLMAKER_TOOLS_PER_DAY) + ", tool upkeep every ~" + str(EconomyBalanceScript.MAINTENANCE_INTERVAL_DEFAULT_DAYS) + " days")
	for opening: String in ["owner_build", "policy"]:
		var made_it: int = 0
		var stuck_on_wood: int = 0
		var totals: Dictionary = {"households": 0, "population": 0, "tools": 0, "wood": 0}
		var failures: Array[String] = []
		for site in range(SITES):
			var result: Dictionary = _play(opening, Vector2(5 + site * 3, 7 + site * 2))
			if result["off_the_ground"]:
				made_it += 1
			else:
				failures.append(result["summary"])
			if result["stuck_on_wood"]:
				stuck_on_wood += 1
			for key in totals.keys():
				totals[key] += int(result[key])
		_report("%s: %d/%d towns off the ground, %d stuck on wood for %d+ days; avg year-2 households %.1f, people %.1f, wood %.0f, tools %.0f" % [
			opening, made_it, SITES, stuck_on_wood, STUCK_WOOD_DAYS,
			float(totals["households"]) / SITES, float(totals["population"]) / SITES,
			float(totals["wood"]) / SITES, float(totals["tools"]) / SITES])
		for line: String in failures:
			_report("  failed " + line)
	quit()

func _play(opening: String, site: Vector2) -> Dictionary:
	var city = CityScript.new("Player Town", site, CityScript.ROLE_PLAYER, 4)
	if opening == "owner_build":
		for building_type: String in ["house", "house", "house", "farm", "woodcutter", "toolmaker"]:
			_try_build(city, building_type)

	var calendar: Calendar = Calendar.new()
	var last_shortage_day: int = -SHORTAGE_WINDOW_DAYS - 1
	var low_wood_streak: int = 0
	var stuck_on_wood: bool = false
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
		if day % POLICY_INTERVAL_DAYS == 0:
			var wanted: String = _choose_build(city)
			if wanted != "" and not _try_build(city, wanted) and int(city.resources["wood"]) < int(EconomyBalanceScript.get_build_cost(wanted).get("wood", 0)):
				low_wood_streak += POLICY_INTERVAL_DAYS
			elif wanted == "" or city.can_afford_cost(EconomyBalanceScript.get_build_cost(wanted)):
				low_wood_streak = 0
			if low_wood_streak >= STUCK_WOOD_DAYS:
				stuck_on_wood = true

	var all_housed: bool = true
	for household: Household in city.households:
		if household.housing_status != Household.RESIDENCE_HOUSED:
			all_housed = false
	var fed: bool = DAYS - 1 - last_shortage_day > SHORTAGE_WINDOW_DAYS
	var off_the_ground: bool = all_housed and fed and city.households.size() >= 4
	return {
		"off_the_ground": off_the_ground,
		"stuck_on_wood": stuck_on_wood,
		"households": city.households.size(),
		"population": city.get_total_population(),
		"wood": int(city.resources["wood"]),
		"tools": int(city.resources["tools"]),
		"summary": "site %s: households %d, housed %s, fed %s, wood %d, tools %d, buildings %s" % [str(site), city.households.size(), str(all_housed), str(fed), int(city.resources["wood"]), int(city.resources["tools"]), _building_counts(city)]
	}

# A simple, reasonable player: a wood source first, then shelter, food, tools, and room to grow.
# Workplaces are only built when a family has labor free to work them.
func _choose_build(city) -> String:
	var counts: Dictionary = _count_types(city)
	var houses: int = int(counts.get("house", 0))
	var woodcutters: int = int(counts.get("woodcutter", 0))
	var toolmakers: int = int(counts.get("toolmaker", 0))
	var idle_labor: bool = int(city.resources["idle_workers"]) > 0
	if woodcutters == 0:
		return "woodcutter"
	if houses < city.households.size():
		return "house"
	var food_needed: int = city.get_food_consumption_for_population(city.get_total_population())
	if idle_labor and HouseholdMigrationScript.estimate_daily_food_production(city) < float(food_needed) * 1.15:
		return "farm"
	if idle_labor and toolmakers == 0 and int(city.resources["tools"]) < 10:
		return "toolmaker"
	if idle_labor and int(city.resources["wood"]) < 10 and woodcutters < 1 + toolmakers:
		return "woodcutter"
	if houses < city.households.size() + 2:
		return "house"
	return ""

func _try_build(city, building_type: String) -> bool:
	var cost: Dictionary = EconomyBalanceScript.get_build_cost(building_type)
	if not city.can_afford_cost(cost):
		return false
	city.pay_cost(cost)
	city.add_building(Building.new(-1, building_type))
	return true

func _count_types(city) -> Dictionary:
	var counts: Dictionary = {}
	for building: Building in city.buildings:
		counts[building.type] = int(counts.get(building.type, 0)) + 1
	return counts

func _building_counts(city) -> String:
	return str(_count_types(city))

func _report(line: String) -> void:
	print("[OPEN] " + line)
