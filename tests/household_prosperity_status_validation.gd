extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const HouseholdScript = preload("res://scripts/domain/household.gd")
const HouseholdProsperityDisplayHelperScript = preload("res://scripts/ui/household_prosperity_display_helper.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_unsheltered_household_is_struggling()
	test_temporary_household_is_struggling()
	test_housed_food_shortage_is_struggling()
	test_housed_basic_needs_met_is_stable()
	test_housed_household_goods_met_is_comfortable()
	test_clothing_unmet_does_not_change_prosperity()

	if failure_count > 0:
		push_error("Household prosperity status validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Household prosperity status validation passed.")
	quit()

func test_unsheltered_household_is_struggling() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_UNSHELTERED, false, 0)
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	_check(status == "struggling", "unsheltered household should be struggling")

func test_temporary_household_is_struggling() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_TEMPORARY, false, 0)
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	_check(status == "struggling", "temporary sheltered household should be struggling")

func test_housed_food_shortage_is_struggling() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_HOUSED, true, 10)
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	_check(status == "struggling", "housed household should be struggling during food shortage")

func test_housed_basic_needs_met_is_stable() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_HOUSED, false, 0)
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])
	var lines: Array[String] = HouseholdProsperityDisplayHelperScript.get_prosperity_lines(city, city.households[0])

	_check(status == "stable", "housed household with no food shortage and no household goods should be stable")
	_check(lines.has("Prosperity: Stable"), "stable prosperity line should be display-ready")
	_check(lines.has("Reason: Basic needs met"), "stable prosperity should explain basic needs are met")

func test_housed_household_goods_met_is_comfortable() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_HOUSED, false, 3)
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])
	var lines: Array[String] = HouseholdProsperityDisplayHelperScript.get_prosperity_lines(city, city.households[0])

	_check(status == "comfortable", "housed household should be comfortable when household goods pressure is met")
	_check(lines.has("Prosperity: Comfortable"), "comfortable prosperity line should be display-ready")
	_check(lines.has("Reason: Household goods available"), "comfortable prosperity should explain household goods availability")

func test_clothing_unmet_does_not_change_prosperity() -> void:
	var city = _make_city(HouseholdScript.RESIDENCE_HOUSED, false, 0)
	var clothing_pressure: Dictionary = city.get_clothing_need_pressure()
	var status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	_check(str(clothing_pressure["status"]) == "unmet", "clothing should be unmet when scaffolded but stockpile is zero")
	_check(status == "stable", "unmet clothing should not make housed households struggling in v0")

func _make_city(housing_status: String, food_shortage: bool, household_goods_amount: int):
	var city = CityScript.new("Prosperity Status Test City")
	for household in city.households:
		household.housing_status = HouseholdScript.RESIDENCE_UNSHELTERED

	city.households[0].housing_status = housing_status
	city.resources["food_shortage"] = food_shortage
	city.resources["carved_goods"] = household_goods_amount
	city.resources["tiles"] = 0
	city.resources["statues"] = 0
	return city

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
