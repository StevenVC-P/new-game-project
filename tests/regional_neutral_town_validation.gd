extends SceneTree

const RegionMapGeneratorScript = preload("res://scripts/world/region_map_generator.gd")
const CityScript = preload("res://scripts/domain/city.gd")
const TradeMenuScript = preload("res://scripts/ui/trade_menu.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_region_generation_creates_one_neutral_town()
	test_neutral_town_is_not_controllable_or_ticking()
	test_trade_menu_does_not_select_neutral_town()

	if failure_count > 0:
		push_error("Regional neutral town validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Regional neutral town validation passed.")
	quit()

func test_region_generation_creates_one_neutral_town() -> void:
	var result: Dictionary = _generate_region()
	var cities: Array[City] = result["cities"] as Array[City]

	_check(cities.size() == 1, "normal regional start should create one neutral town")
	_check(cities[0].name == "Neutral Town", "generated regional town should use neutral-town label")
	_check(cities[0].role == CityScript.ROLE_NEUTRAL, "generated regional town should have neutral role")

func test_neutral_town_is_not_controllable_or_ticking() -> void:
	var result: Dictionary = _generate_region()
	var cities: Array[City] = result["cities"] as Array[City]
	var neutral_town: City = cities[0]

	_check(neutral_town.is_neutral_city(), "generated town should report neutral")
	_check(not neutral_town.is_controllable_city(), "neutral town should not be controllable")
	_check(not neutral_town.should_tick_simulation(), "neutral town should not run full simulation ticks")

func test_trade_menu_does_not_select_neutral_town() -> void:
	var result: Dictionary = _generate_region()
	var cities: Array[City] = result["cities"] as Array[City]
	var trade_menu = TradeMenuScript.new()

	trade_menu.open(cities)
	trade_menu.handle_city_selection(0, cities)

	_check(trade_menu.source_city_index == -1, "trade menu should not select neutral town as source")
	_check(not trade_menu.has_pending_route(), "trade menu should not create pending neutral-town route")

func _generate_region() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var generator = RegionMapGeneratorScript.new(rng, 80, 50, 24, 5, 7)
	return generator.generate_region()

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
