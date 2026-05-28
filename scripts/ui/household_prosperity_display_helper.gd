class_name HouseholdProsperityDisplayHelper
extends RefCounted

const STATUS_STRUGGLING: String = "struggling"
const STATUS_STABLE: String = "stable"
const STATUS_COMFORTABLE: String = "comfortable"
const STATUS_PROSPEROUS: String = "prosperous"

const RESIDENCE_HOUSED: String = "housed"
const RESIDENCE_TEMPORARY: String = "temporary"
const RESIDENCE_UNSHELTERED: String = "unsheltered"

static func get_prosperity_status(city, household) -> String:
	if household == null:
		return ""

	var housing_status: String = str(_read_household_property(household, "housing_status", RESIDENCE_UNSHELTERED))
	if housing_status == RESIDENCE_UNSHELTERED or housing_status == RESIDENCE_TEMPORARY:
		return STATUS_STRUGGLING
	if city != null and _city_has_food_shortage(city):
		return STATUS_STRUGGLING
	if housing_status != RESIDENCE_HOUSED:
		return STATUS_STRUGGLING
	if _household_goods_pressure_is_met(city):
		return STATUS_COMFORTABLE

	return STATUS_STABLE

static func get_prosperity_lines(city, household) -> Array[String]:
	if household == null:
		return ["Prosperity: unknown"]

	var status: String = get_prosperity_status(city, household)
	return [
		"Prosperity: " + _format_status(status),
		_get_status_detail(status),
	]

static func _city_has_food_shortage(city) -> bool:
	if city == null:
		return false
	if not city.resources.has("food_shortage"):
		return false

	return bool(city.resources["food_shortage"])

static func _household_goods_pressure_is_met(city) -> bool:
	if city == null or not city.has_method("get_household_goods_need_pressure"):
		return false

	var household_goods_pressure: Dictionary = city.get_household_goods_need_pressure()
	return str(household_goods_pressure.get("status", "")) == "met"

static func _get_status_detail(status: String) -> String:
	if status == STATUS_STRUGGLING:
		return "Basic needs under pressure"
	if status == STATUS_COMFORTABLE:
		return "Basic needs met; household goods available"
	if status == STATUS_PROSPEROUS:
		return "Prosperity: future quality and variety status"

	return "Basic needs met"

static func _format_status(status: String) -> String:
	if status == "":
		return "Unknown"

	return status.substr(0, 1).to_upper() + status.substr(1).to_lower()

static func _read_household_property(household, property_name: String, fallback):
	if household == null:
		return fallback
	if household is Dictionary:
		if household.has(property_name):
			return household[property_name]
		return fallback
	if household is Object:
		var value = household.get(property_name)
		if value != null:
			return value

	return fallback
