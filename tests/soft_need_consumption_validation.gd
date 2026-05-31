extends SceneTree

const CityScript = preload("res://scripts/domain/city.gd")
const GoodsNeedBucketHelperScript = preload("res://scripts/domain/goods_need_bucket_helper.gd")
const HouseholdProsperityDisplayHelperScript = preload("res://scripts/ui/household_prosperity_display_helper.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_household_goods_consumption_met()
	test_household_goods_consumption_low()
	test_household_goods_consumption_unmet()
	test_clothing_consumption_met()
	test_clothing_consumption_low()
	test_clothing_consumption_unmet()
	test_unavailable_bucket_is_not_consumed()
	test_missing_resource_key_is_safe()
	test_soft_consumption_does_not_change_prosperity()
	test_wool_still_does_not_satisfy_clothing()

	if failure_count > 0:
		push_error("Soft need consumption validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Soft need consumption validation passed.")
	quit()

func test_household_goods_consumption_met() -> void:
	var city = _make_city_with_housed_households(3, 4)
	city.resources["carved_goods"] = 3

	var results: Dictionary = city.resolve_soft_needs()
	var result: Dictionary = results[GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS]

	_check(str(result["status"]) == "met", "household goods should be met when stock covers demand")
	_check(int(result["available"]) == 3, "household goods should report available stock before consumption")
	_check(int(result["remaining"]) == 0, "household goods should report remaining stock after consumption")
	_check(int(result["consumed_last_period"]) == 3, "household goods should consume up to demand")
	_check(_floats_match(float(result["satisfaction_ratio"]), 1.0), "household goods met ratio should be 1.0")
	_check(city.get_available_need_bucket_amount(GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS) == 0, "household goods stock should be reduced")

func test_household_goods_consumption_low() -> void:
	var city = _make_city_with_housed_households(3, 4)
	city.resources["carved_goods"] = 1

	var result: Dictionary = city.resolve_soft_needs()[GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS]

	_check(str(result["status"]) == "low", "household goods should be low when partially supplied")
	_check(int(result["consumed_last_period"]) == 1, "partial household goods should consume available stock")
	_check(int(result["shortage"]) == 2, "partial household goods should report shortage")
	_check(_floats_match(float(result["satisfaction_ratio"]), 1.0 / 3.0), "partial household goods ratio should match consumed over demand")
	_check(int(city.resources["carved_goods"]) == 0, "partial household goods should not go negative")

func test_household_goods_consumption_unmet() -> void:
	var city = _make_city_with_housed_households(3, 4)

	var result: Dictionary = city.resolve_soft_needs()[GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS]

	_check(str(result["status"]) == "unmet", "household goods should be unmet when no stock is supplied")
	_check(int(result["consumed_last_period"]) == 0, "unmet household goods should consume nothing")
	_check(int(result["shortage"]) == 3, "unmet household goods should report full shortage")
	_check(_floats_match(float(result["satisfaction_ratio"]), 0.0), "unmet household goods ratio should be 0")

func test_clothing_consumption_met() -> void:
	var city = _make_city_with_housed_households(3, 4)
	city.resources["clothing"] = 12

	var result: Dictionary = city.resolve_soft_needs()[GoodsNeedBucketHelperScript.BUCKET_CLOTHING]

	_check(str(result["status"]) == "met", "clothing should be met when stock covers population demand")
	_check(int(result["available"]) == 12, "clothing should report available stock before consumption")
	_check(int(result["remaining"]) == 0, "clothing should report remaining stock after consumption")
	_check(int(result["consumed_last_period"]) == 12, "clothing should consume up to demand")
	_check(_floats_match(float(result["satisfaction_ratio"]), 1.0), "clothing met ratio should be 1.0")
	_check(int(city.resources["clothing"]) == 0, "clothing stock should be reduced")

func test_clothing_consumption_low() -> void:
	var city = _make_city_with_housed_households(3, 4)
	city.resources["clothing"] = 5

	var result: Dictionary = city.resolve_soft_needs()[GoodsNeedBucketHelperScript.BUCKET_CLOTHING]

	_check(str(result["status"]) == "low", "clothing should be low when partially supplied")
	_check(int(result["consumed_last_period"]) == 5, "partial clothing should consume available stock")
	_check(int(result["shortage"]) == 7, "partial clothing should report shortage")
	_check(_floats_match(float(result["satisfaction_ratio"]), 5.0 / 12.0), "partial clothing ratio should match consumed over demand")
	_check(int(city.resources["clothing"]) == 0, "partial clothing should not go negative")

func test_clothing_consumption_unmet() -> void:
	var city = _make_city_with_housed_households(3, 4)

	var result: Dictionary = city.resolve_soft_needs()[GoodsNeedBucketHelperScript.BUCKET_CLOTHING]

	_check(str(result["status"]) == "unmet", "clothing should be unmet when recognized stock is zero")
	_check(int(result["consumed_last_period"]) == 0, "unmet clothing should consume nothing")
	_check(int(result["shortage"]) == 12, "unmet clothing should report full shortage")
	_check(_floats_match(float(result["satisfaction_ratio"]), 0.0), "unmet clothing ratio should be 0")

func test_unavailable_bucket_is_not_consumed() -> void:
	var city = _make_city_with_housed_households(1, 4)
	var food_before: int = int(city.resources["food"])

	var result: Dictionary = city.resolve_soft_need_bucket("future_soft_need", 3)

	_check(str(result["status"]) == "unavailable", "unknown bucket with demand should remain unavailable")
	_check(int(result["consumed_last_period"]) == 0, "unavailable bucket should consume nothing")
	_check(_floats_match(float(result["satisfaction_ratio"]), 0.0), "unavailable bucket ratio should be 0")
	_check(int(city.resources["food"]) == food_before, "unavailable bucket should not consume unrelated goods")

func test_missing_resource_key_is_safe() -> void:
	var city = _make_city_with_housed_households(1, 4)
	city.resources.erase("clothing")

	var result: Dictionary = city.resolve_soft_need_bucket(GoodsNeedBucketHelperScript.BUCKET_CLOTHING, city.get_clothing_need_demand())

	_check(str(result["status"]) == "unmet", "missing clothing key should be treated as zero stock, not unavailable")
	_check(int(result["consumed_last_period"]) == 0, "missing clothing key should consume nothing")
	_check(not city.resources.has("clothing"), "missing clothing key should not be recreated by consumption")

func test_soft_consumption_does_not_change_prosperity() -> void:
	var city = _make_city_with_housed_households(1, 4)
	city.resources["clothing"] = 4
	var before_status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	city.resolve_soft_needs()
	var after_status: String = HouseholdProsperityDisplayHelperScript.get_prosperity_status(city, city.households[0])

	_check(before_status == "stable", "baseline household should start stable")
	_check(after_status == before_status, "soft need consumption should not change prosperity status in v0")

func test_wool_still_does_not_satisfy_clothing() -> void:
	_check(not GoodsNeedBucketHelperScript.get_need_buckets_for_good("wool").has(GoodsNeedBucketHelperScript.BUCKET_CLOTHING), "wool should remain a future textile input, not final clothing")
	_check(not CityScript.new("Wool Safety City").resources.has("wool"), "wool should not be introduced as a stockpile key")

func _make_city_with_housed_households(household_count: int, population_per_household: int):
	var city = CityScript.new("Soft Need Consumption Test City")
	for household in city.households:
		household.housing_status = Household.RESIDENCE_UNSHELTERED
		household.total_population = population_per_household

	for index in range(min(household_count, city.households.size())):
		city.households[index].housing_status = Household.RESIDENCE_HOUSED

	while city.households.size() > household_count:
		city.households.pop_back()

	city.resources["carved_goods"] = 0
	city.resources["tiles"] = 0
	city.resources["statues"] = 0
	city.resources["clothing"] = 0
	city.resources["food_shortage"] = false
	return city

func _floats_match(left: float, right: float) -> bool:
	return abs(left - right) < 0.001

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
