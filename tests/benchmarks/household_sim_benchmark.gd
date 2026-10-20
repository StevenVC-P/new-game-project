extends SceneTree

# Measures simulation cost per household at increasing settlement sizes, to replace
# the estimates in docs/SIMULATION_SCALE_MODEL.md with real numbers.
# Run: <godot> --headless --path . --script res://tests/benchmarks/household_sim_benchmark.gd
# Lifecycle logging prints heavily at scale; filter output for "[BENCH]".

const CityScript = preload("res://scripts/domain/city.gd")

const SIZES: Array[int] = [10, 100, 250, 500, 1000, 2000]
const MAX_DAYS: int = 30
const MAX_MONTHS: int = 6
# Stop sampling a size once this much wall time is spent, so quadratic sizes stay bounded.
const TIME_CAP_USEC: int = 3000000

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	_report("size,setup_ms,day_ms,days_sampled,month_ms,months_sampled,household_only_month_ms")
	for size: int in SIZES:
		_run_size(size)
	_report("done")
	quit()

func _run_size(household_count: int) -> void:
	var setup_start: int = Time.get_ticks_usec()
	var city = _make_city(household_count)
	var setup_ms: float = float(Time.get_ticks_usec() - setup_start) / 1000.0

	var day_ms: float = 0.0
	var days: int = 0
	var day_start: int = Time.get_ticks_usec()
	while days < MAX_DAYS and Time.get_ticks_usec() - day_start < TIME_CAP_USEC:
		city.tick()
		days += 1
	day_ms = float(Time.get_ticks_usec() - day_start) / 1000.0 / float(max(1, days))

	var months: int = 0
	var month_start: int = Time.get_ticks_usec()
	while months < MAX_MONTHS and Time.get_ticks_usec() - month_start < TIME_CAP_USEC:
		city.advance_household_lifecycle_month(0)
		months += 1
	var month_ms: float = float(Time.get_ticks_usec() - month_start) / 1000.0 / float(max(1, months))

	# Per-household work alone, without city-level scans, to separate inherent cost from algorithm cost.
	var household_start: int = Time.get_ticks_usec()
	for household: Household in city.households:
		household.advance_lifecycle_month()
	var household_only_ms: float = float(Time.get_ticks_usec() - household_start) / 1000.0

	_report("%d,%.1f,%.3f,%d,%.3f,%d,%.3f" % [household_count, setup_ms, day_ms, days, month_ms, months, household_only_ms])

func _make_city(household_count: int):
	var city = CityScript.new("Bench", Vector2.ZERO, CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = household_count * 10000
	city.resources["wood"] = household_count * 10000
	city.resources["tools"] = household_count * 10000
	city.resources["external_population_pool"] = 0

	# Bypass add_building(): it re-runs housing and assignment scans per call, which would
	# make setup itself quadratic-squared and hide the per-day numbers being measured.
	for index in range(household_count):
		var house: Building = Building.new(city.buildings.size(), Building.BUILDING_HOUSE)
		city.buildings.append(house)
		var preference: String = [CityScript.WORK_PREF_AGRARIAN, CityScript.WORK_PREF_INDUSTRIAL, CityScript.WORK_PREF_NEUTRAL][index % 3]
		var household: Household = Household.new(index, house.id, preference, 4, Household.RESIDENCE_HOUSED)
		city.seed_starter_household_lifecycle(household, index)
		household.move_to_house(house.id)
		city.households.append(household)

	# Roughly one workplace per household's two labor units, weighted toward food.
	var workplace_count: int = household_count
	for index in range(workplace_count):
		var building_type: String = Building.BUILDING_FARM if index % 2 == 0 else Building.BUILDING_WOODCUTTER
		city.buildings.append(Building.new(city.buildings.size(), building_type))

	city.update_shelter_counts()
	city.auto_assign_workers()
	return city

func _report(line: String) -> void:
	print("[BENCH] " + line)
