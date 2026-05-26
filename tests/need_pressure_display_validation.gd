extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const CityPressureHintHelperScript = preload("res://scripts/ui/city_pressure_hint_helper.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_food_need_pressure_met()
	test_food_need_pressure_low()
	test_food_need_pressure_shortage()
	test_need_pressure_summary_shape()
	test_inactive_buckets_do_not_generate_hints()
	test_food_need_hints_are_specific()

	if failure_count > 0:
		push_error("Need pressure display validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Need pressure display validation passed.")
	quit()

func test_food_need_pressure_met() -> void:
	var city = _make_city_with_food_state(12, 3, false)
	var food_need: Dictionary = city.get_food_need_pressure()

	_check(str(food_need["status"]) == "met", "food need should be met when available food covers demand")
	_check(str(food_need["severity"]) == "positive", "met food need should be positive")
	_check(int(food_need["available"]) == 12, "met food need should report available bucket stock")
	_check(int(food_need["demand"]) == 3, "met food need should report demand")
	_check(bool(food_need["active"]) == true, "food need should be active")

func test_food_need_pressure_low() -> void:
	var city = _make_city_with_food_state(2, 3, false)
	var food_need: Dictionary = city.get_food_need_pressure()

	_check(str(food_need["status"]) == "low", "food need should be low when available food is below demand before shortage flag")
	_check(str(food_need["severity"]) == "warning", "low food need should be warning")
	_check(int(food_need["available"]) == 2, "low food need should report available bucket stock")
	_check(int(food_need["demand"]) == 3, "low food need should report demand")

func test_food_need_pressure_shortage() -> void:
	var city = _make_city_with_food_state(0, 3, true)
	var food_need: Dictionary = city.get_food_need_pressure()

	_check(str(food_need["status"]) == "shortage", "food need should be shortage when food shortage flag is set")
	_check(str(food_need["severity"]) == "danger", "shortage food need should be danger")
	_check(int(food_need["available"]) == 0, "shortage food need should report zero available stock")
	_check(int(food_need["demand"]) == 3, "shortage food need should report demand")
	_check(int(food_need["shortage"]) == 3, "shortage food need should report shortage amount")

func test_need_pressure_summary_shape() -> void:
	var city = _make_city_with_food_state(12, 3, false)
	var summary: Dictionary = city.get_need_pressure_summary()
	var expected_keys: Array[String] = [
		"food",
		"tools",
		"construction_materials",
		"maintenance_materials",
		"household_goods",
		"civic_goods",
	]

	for key in expected_keys:
		_check(summary.has(key), "need pressure summary should include " + key)
		if summary.has(key):
			_assert_need_entry_shape(summary[key] as Dictionary, key)

func test_inactive_buckets_do_not_generate_hints() -> void:
	var city = _make_city_with_food_state(12, 3, false)
	var hints: Array[String] = CityPressureHintHelperScript.get_hints({}, city.resources, city.get_need_pressure_summary())

	_check(hints.size() == 1, "inactive buckets should not create urgent hints")
	_check(hints[0] == CityPressureHintHelperScript.FALLBACK_HINT, "inactive buckets should leave only the fallback hint")

func test_food_need_hints_are_specific() -> void:
	var low_city = _make_city_with_food_state(2, 3, false)
	var low_hints: Array[String] = CityPressureHintHelperScript.get_hints({}, low_city.resources, low_city.get_need_pressure_summary())
	_check(low_hints.has("Food demand rising: increase food production or trade for food."), "low food need should create a food demand hint")

	var shortage_city = _make_city_with_food_state(0, 3, true)
	var shortage_hints: Array[String] = CityPressureHintHelperScript.get_hints({}, shortage_city.resources, shortage_city.get_need_pressure_summary())
	_check(shortage_hints.has("Food shortage: assign households to farms or import food."), "shortage food need should create a shortage hint")

func _assert_need_entry_shape(entry: Dictionary, key: String) -> void:
	_check(entry.has("bucket"), key + " need entry should include bucket")
	_check(entry.has("display_name"), key + " need entry should include display_name")
	_check(entry.has("status"), key + " need entry should include status")
	_check(entry.has("severity"), key + " need entry should include severity")
	_check(entry.has("demand"), key + " need entry should include demand")
	_check(entry.has("available"), key + " need entry should include available")
	_check(entry.has("shortage"), key + " need entry should include shortage")
	_check(entry.has("active"), key + " need entry should include active")

	if key != "food":
		_check(str(entry["status"]) == "pressure_only", key + " should be pressure_only in v0")
		_check(bool(entry["active"]) == false, key + " should be inactive in v0")

func _make_city_with_food_state(food: int, consumption_rate: int, food_shortage: bool):
	var city = CityScript.new("Need Pressure Test City")
	city.resources["food"] = food
	city.resources["food_consumption_rate"] = consumption_rate
	city.resources["food_shortage"] = food_shortage
	return city

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
