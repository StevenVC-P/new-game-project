class_name WorkplaceStabilityDisplayHelper
extends RefCounted

const RESIDENCE_HOUSED: String = "housed"
const RESIDENCE_TEMPORARY: String = "temporary"
const RESIDENCE_UNSHELTERED: String = "unsheltered"

static func get_warning_lines(city, building) -> Array[String]:
	var household = get_unstable_assigned_household(city, building)
	if household == null:
		return []

	var shelter_text: String = get_shelter_text(str(household.housing_status))
	return [
		"Workplace stability: assigned household is " + shelter_text,
		"Housing instability may reduce reliability later",
	]

static func get_action_hints(city, building) -> Array[String]:
	var household = get_unstable_assigned_household(city, building)
	if household == null:
		return []

	return ["House the assigned household to stabilize this workplace."]

static func get_unstable_assigned_household(city, building):
	if city == null or building == null:
		return null
	if not building.is_production_building():
		return null
	if int(building.assigned_household_id) < 0:
		return null

	var household = city.get_household_by_id(int(building.assigned_household_id))
	if household == null:
		return null
	if str(household.housing_status) == RESIDENCE_HOUSED:
		return null
	if str(household.housing_status) == RESIDENCE_TEMPORARY or str(household.housing_status) == RESIDENCE_UNSHELTERED:
		return household

	return null

static func get_shelter_text(housing_status: String) -> String:
	if housing_status == RESIDENCE_TEMPORARY:
		return "temporarily sheltered"
	if housing_status == RESIDENCE_UNSHELTERED:
		return "unsheltered"

	return housing_status.replace("_", " ")
