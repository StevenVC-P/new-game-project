class_name SelectedBuildingActionHintHelper
extends RefCounted

static func get_hints(building, city) -> Array[String]:
	var hints: Array[String] = []

	if building == null:
		hints.append("No selected building action hints.")
		return hints

	# Check if building is production or housing
	if building.is_production_building():
		if building.assigned_household_id == -1:
			hints.append("Assign an idle household to start production.")
		else:
			hints.append("This building has assigned labor.")

		# Check maintenance status
		if not building.receives_maintenance:
			hints.append("Maintenance is disabled; production may degrade when tools are needed.")
		elif building.maintenance_level < 50:
			hints.append("Maintenance level is low; production may be affected.")

		# Check tool resources
		if city.resources.has("tools") and city.resources["tools"] < 10:
			hints.append("Tools are low; maintenance may become unreliable.")
	elif building.is_house():
		# For housing, check if it has assigned households
		if building.assigned_household_id == -1:
			hints.append("No household assigned to this housing unit.")
		else:
			hints.append("This housing unit is occupied.")
	else:
		hints.append("No selected building action hints.")

	return hints
