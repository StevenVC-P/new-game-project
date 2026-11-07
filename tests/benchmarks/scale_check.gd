extends SceneTree

# S19 scale check (master roadmap Phase 1; replaces the stale docs/HOUSEHOLD_SIM_BENCHMARK.md): what a
# day of today's game costs as a town grows. Towns of 10 to 800 households, families leading, social
# life on, a private compact with its market and commons, on a town map, with plenty in store so the
# size holds; each plays 60 days. Reports the ordinary day, the month's turn (the 1st), memory, and how
# cost grows with size (the exponent between sizes: 1 is linear). Also the Stage C observers' cost.
# Run (write to a file; the household log is long): <godot> --headless --path . --script
#   res://tests/benchmarks/scale_check.gd > scale.log, then filter for [SCALE].

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const SIZES: Array[int] = [10, 25, 50, 100, 200, 400, 800]
const DAYS: int = 60

func _init() -> void:
	call_deferred("run")

func say(line: String) -> void:
	print("[SCALE] " + line)

func run() -> void:
	say("households,people,day_ms,month_turn_ms,first_day_ms,memory_mb,observe_ms")
	var previous: Array = []
	for size: int in SIZES:
		var result: Array = measure(size)
		say("%d,%d,%.2f,%.2f,%.2f,%.1f,%.2f" % result)
		if not previous.is_empty():
			say("  growth %d -> %d households: day x%.2f (exponent %.2f), month turn x%.2f (exponent %.2f)" % [previous[0], size, result[2] / previous[2], log(result[2] / previous[2]) / log(float(size) / previous[0]), result[3] / previous[3], log(result[3] / previous[3]) / log(float(size) / previous[0])])
		previous = result
	quit()

func measure(size: int) -> Array:
	var memory_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var city: City = City.new("Scale", Vector2(20, 20), City.ROLE_PLAYER, size, 20261107)
	city.local_map = ConstructionTest.make_map()
	city.influence.enabled = true
	city.set_hand_method_fallback(true)
	city.social.set_enabled(true)
	HomeSites.ensure_starting_land(city)
	TownCompact.set_preset(city, "private")
	TownCommons.set_reserve_days(city, 30)
	for good: String in ["food", "wood", "tools"]:
		city.resources[good] = size * 2000
	var ordinary: Array[float] = []
	var turns: Array[float] = []
	var first_day: float = 0.0
	for day in range(DAYS):
		var turn: bool = (city.get_day_of_year() - 1) % Calendar.DAYS_PER_MONTH == 0
		var started: int = Time.get_ticks_usec()
		city.tick()
		var ms: float = (Time.get_ticks_usec() - started) / 1000.0
		# The first day builds the town's routes and caches once.
		if day == 0:
			first_day = ms
		elif turn:
			turns.append(ms)
		else:
			ordinary.append(ms)
	var observed: int = Time.get_ticks_usec()
	TownDemographics.labour_table(city)
	CultureObserver.pairs(city)
	var observe_ms: float = (Time.get_ticks_usec() - observed) / 1000.0
	return [city.households.size(), city.get_total_population(), median(ordinary), median(turns) if not turns.is_empty() else 0.0, first_day, (Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before) / 1048576.0, observe_ms]

static func median(values: Array[float]) -> float:
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
