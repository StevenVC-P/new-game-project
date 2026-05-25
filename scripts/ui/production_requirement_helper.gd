class_name ProductionRequirementHelper

static func get_requirement_lines(city, building) -> Array[String]:
	var lines: Array[String] = []

	if city == null or building == null or not building.is_production_building():
		lines.append("No production requirement details.")
		return lines

	# Assigned labor status
	if building.assigned_workers > 0:
		lines.append("Assigned labor: satisfied")
	else:
		lines.append("Assigned labor: missing")

	# Maintenance level
	var maintenance_level = building.maintenance_level
	if maintenance_level <= 0:
		lines.append("Maintenance: worn")
	elif maintenance_level < 50:
		lines.append("Maintenance: worn")
	elif maintenance_level < 100:
		lines.append("Maintenance: stable")
	else:
		lines.append("Maintenance: stable")

	# Input requirements
	var required_inputs: Array[String] = []
	match building.type:
		"toolmaker":
			required_inputs = ["wood"]
		"stonecutter":
			required_inputs = ["stone_blocks"]
		"brickworks":
			required_inputs = ["wood"]
		"lime_kiln":
			required_inputs = ["stone_blocks", "wood"]
		"mortar_yard":
			required_inputs = ["lime", "stone_blocks"]
		"mason_yard":
			required_inputs = ["cut_stone", "mortar"]
		"sculptor":
			required_inputs = ["cut_stone", "tools"]
		"carver":
			required_inputs = ["wood", "tools"]
		"tileworks":
			required_inputs = ["bricks", "wood"]
		"paver_yard":
			required_inputs = ["stone_blocks"]

	var inputs_missing: bool = false
	for input_good in required_inputs:
		if not city.resources.has(input_good) or city.resources[input_good] <= 0:
			inputs_missing = true
			lines.append("Inputs: missing " + input_good)

	if not inputs_missing and required_inputs.size() > 0:
		lines.append("Inputs: satisfied")

	# Food shortage status
	if city.resources.has("food_shortage") and city.resources["food_shortage"]:
		lines.append("Food shortage: production may slow")

	# Household fit quality
	var household_id = building.assigned_household_id
	if household_id != -1:
		var household = city.get_household_by_id(household_id)
		if household:
			var match_quality = household.get_match_quality(building.type)
			if match_quality == "good match":
				lines.append("Fit: good match")
			elif match_quality == "neutral":
				lines.append("Fit: neutral")
			elif match_quality == "poor match":
				lines.append("Fit: poor match")

	return lines
