class_name HouseholdDemandDisplayHelper
extends RefCounted

const RESIDENCE_HOUSED: String = "housed"
const RESIDENCE_TEMPORARY: String = "temporary"
const RESIDENCE_UNSHELTERED: String = "unsheltered"

static func get_demand_lines(city, household) -> Array[String]:
	if household == null:
		return ["No family demand details."]

	var lines: Array[String] = []
	var total_population: int = int(_read_household_property(household, "total_population", 0))
	var housing_status: String = str(_read_household_property(household, "housing_status", RESIDENCE_UNSHELTERED))

	lines.append("Food: " + str(total_population) + " population")
	lines.append(_get_household_goods_text(housing_status))
	lines.append("Clothing: " + str(total_population) + " population pressure, not supplied yet")
	lines.append("Shelter: " + _get_shelter_text(housing_status))

	return lines

static func _get_household_goods_text(housing_status: String) -> String:
	if housing_status == RESIDENCE_HOUSED:
		return "Household goods: contributes 1 home-life demand"

	return "Household goods: no full home-life demand while " + _get_shelter_text(housing_status)

static func _get_shelter_text(housing_status: String) -> String:
	if housing_status == RESIDENCE_HOUSED:
		return "housed"
	if housing_status == RESIDENCE_TEMPORARY:
		return "temporary shelter"
	if housing_status == RESIDENCE_UNSHELTERED:
		return "unsheltered"

	return housing_status.replace("_", " ")

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
