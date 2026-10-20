extends SceneTree

# Headless multi-year settlement run for checking growth and decline over time
# (docs/IMPLEMENTATION_ROADMAP.md, M2 done criteria). Not a pass/fail test: it prints a yearly report.
# Run: <godot> --headless --path . --script res://tests/sim/settlement_growth_run.gd
# Lifecycle logging is verbose; filter output for "[SIM]".
#
# Scenarios:
#   steady   - ample houses and farms; growth should continue past the first few years
#   famine   - farms stop for half of year 6 (when stores are low), then restart

const CityScript = preload("res://scripts/domain/city.gd")

const YEARS: int = 10
const HOUSES: int = 40
const FARMS: int = 10
const WOODCUTTERS: int = 2
# Maintenance consumes tools, so a town without a toolmaker loses its farms within months.
# One toolmaker (~1 tool/day) only just covers ~13 buildings; a poorly suited heir tips it into decline.
const TOOLMAKERS: int = 2
const FAMINE_START_DAY: int = 360 * 5
const FAMINE_END_DAY: int = 360 * 5 + 180

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	_run_scenario("steady", false)
	_run_scenario("famine", true)
	quit()

func _run_scenario(label: String, with_famine: bool) -> void:
	var city = CityScript.new("Player Town", Vector2(20, 20), CityScript.ROLE_PLAYER, 4)
	for index in range(HOUSES):
		city.add_building(Building.new(-1, Building.BUILDING_HOUSE))
	# Tools and wood first, so auto-assignment staffs them before the farms take all labor.
	for index in range(TOOLMAKERS):
		city.add_building(Building.new(-1, Building.BUILDING_TOOLMAKER))
	for index in range(WOODCUTTERS):
		city.add_building(Building.new(-1, Building.BUILDING_WOODCUTTER))
	for index in range(FARMS):
		city.add_building(Building.new(-1, Building.BUILDING_FARM))

	var calendar: Calendar = Calendar.new()
	_report(label, "year,households,population,food,tools,food_shortage,max_generation,departed,arrived,idle_workplaces")
	for day in range(YEARS * Calendar.DAYS_PER_YEAR):
		if with_famine and day == FAMINE_START_DAY:
			_set_farms_working(city, false)
		if with_famine and day == FAMINE_END_DAY:
			_set_farms_working(city, true)

		var month_before: int = calendar.current_month
		var season_before: String = calendar.get_current_season()
		calendar.advance_day()
		city.tick()
		city.record_resource_history()
		if calendar.current_month != month_before:
			city.advance_household_lifecycle_month(0)
		if calendar.get_current_season() != season_before:
			city.advance_household_birth_rolls_season(calendar, 0)
		if calendar.current_month == 1 and calendar.current_day == 1:
			_report_year(label, city, calendar.current_year - 1)

func _set_farms_working(city, working: bool) -> void:
	for building: Building in city.buildings:
		if building.type == Building.BUILDING_FARM:
			# Upkeep would otherwise repair the farms within weeks.
			building.receives_maintenance = working
			building.maintenance_level = 100 if working else 0

func _report_year(label: String, city, year: int) -> void:
	var max_generation: int = 0
	for household: Household in city.households:
		max_generation = max(max_generation, household.generation)
	_report(label, "%d,%d,%d,%d,%d,%s,%d,%d,%d,%d" % [
		year,
		city.households.size(),
		city.get_total_population(),
		int(city.resources["food"]),
		int(city.resources["tools"]),
		str(city.resources["food_shortage"]),
		max_generation,
		int(city.resources.get("departed_households", 0)),
		int(city.resources.get("arrived_households", 0)),
		_count_idle_workplaces(city)
	])

func _count_idle_workplaces(city) -> int:
	var idle: int = 0
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers == 0:
			idle += 1
	return idle

func _report(label: String, line: String) -> void:
	print("[SIM] " + label + " " + line)
