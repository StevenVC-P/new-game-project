class_name HouseholdHomeWorkLinkHelper
extends RefCounted

const FALLBACK_TEXT: String = "No household link details."

static func get_links(city: City, building_index: int) -> Array[String]:
	var lines: Array[String] = []
	if city == null:
		lines.append(FALLBACK_TEXT)
		return lines
	if building_index < 0 or building_index >= city.buildings.size():
		lines.append(FALLBACK_TEXT)
		return lines

	var building: Building = city.buildings[building_index]
	if building.is_house():
		_add_home_links(lines, city, building_index)
	else:
		_add_production_links(lines, city, building)

	if lines.is_empty():
		lines.append(FALLBACK_TEXT)

	return lines

static func get_related_building_indices(city: City, building_index: int) -> Array[int]:
	var related_building_indices: Array[int] = []
	if city == null:
		return related_building_indices
	if building_index < 0 or building_index >= city.buildings.size():
		return related_building_indices

	var building: Building = city.buildings[building_index]
	if building.is_house():
		return city.get_assigned_building_ids_for_house(building_index)

	if building.assigned_workers <= 0:
		return related_building_indices
	if building.assigned_household_id < 0:
		return related_building_indices

	var home_building_index: int = city.get_assigned_house_building_id(building)
	if home_building_index >= 0:
		related_building_indices.append(home_building_index)

	return related_building_indices

static func _add_home_links(lines: Array[String], city: City, house_index: int) -> void:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null:
		lines.append("Home: empty residence")
		return

	lines.append("Home: " + city.get_household_label(household.id))
	lines.append("Household: pop " + str(household.total_population) + ", " + household.preference + ", labor " + str(household.assigned_workers) + "/" + str(household.labor_capacity))

	var assigned_production_ids: Array[int] = city.get_assigned_building_ids_for_house(house_index)
	if assigned_production_ids.is_empty():
		lines.append("Assigned production: none")
	else:
		lines.append("Assigned production: " + _format_building_list(city, assigned_production_ids))

static func _add_production_links(lines: Array[String], city: City, building: Building) -> void:
	if building.assigned_workers <= 0:
		lines.append("Assigned household: none")
		return
	if building.assigned_household_id < 0:
		lines.append("Assigned household: starter neutral")
		lines.append("Home: temporary/unknown")
		return

	var household: Household = city.get_household_by_id(building.assigned_household_id)
	if household == null:
		lines.append("Assigned household: unknown")
		return

	lines.append("Assigned household: " + city.get_household_label(household.id))
	lines.append("Household: pop " + str(household.total_population) + ", " + household.preference + ", " + household.housing_status)
	if household.residence_building_id >= 0:
		lines.append("Home: " + _format_building_label(city, household.residence_building_id))
	else:
		lines.append("Home: " + household.housing_status)

static func _format_building_list(city: City, building_ids: Array[int]) -> String:
	var labels: Array[String] = []
	for building_id: int in building_ids:
		labels.append(_format_building_label(city, building_id))

	return ", ".join(labels)

static func _format_building_label(city: City, building_index: int) -> String:
	if building_index < 0 or building_index >= city.buildings.size():
		return "unknown production"

	var building: Building = city.buildings[building_index]
	return _capitalize_building_type(building.type) + " " + str(_count_buildings_of_type_through_index(city.buildings, building.type, building_index))

static func _count_buildings_of_type_through_index(buildings: Array[Building], building_type: String, target_index: int) -> int:
	var count: int = 0
	for building_index in range(target_index + 1):
		if buildings[building_index].type == building_type:
			count += 1

	return count

static func _capitalize_building_type(building_type: String) -> String:
	if building_type == Building.BUILDING_HOUSE:
		return "House"
	if building_type == Building.BUILDING_FARM:
		return "Farm"
	if building_type == Building.BUILDING_WOODCUTTER:
		return "Woodcutter"
	if building_type == Building.BUILDING_TOOLMAKER:
		return "Toolmaker"

	return building_type
