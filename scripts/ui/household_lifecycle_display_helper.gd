class_name HouseholdLifecycleDisplayHelper

static func get_lifecycle_lines(household, city = null) -> Array[String]:
	if household == null:
		return ["No household lifecycle details."]

	var lines: Array[String] = []

	var lifecycle_stage = _read_household_property(household, "lifecycle_stage", "")
	var family_trade = _read_household_property(household, "family_trade", "")
	var succession_pressure: int = int(_read_household_property(household, "succession_pressure", 0))
	var age_in_stage: int = int(_read_household_property(household, "age_in_stage", 0))
	var young_children: int = int(_read_household_property(household, "young_children", 0))
	var older_children: int = int(_read_household_property(household, "older_children", 0))
	var adult_children: int = int(_read_household_property(household, "adult_children", 0))

	if lifecycle_stage == "" and family_trade == "":
		return ["No household lifecycle details."]

	lines.append("Stage: " + _format_lifecycle_label(str(lifecycle_stage), "Unknown"))
	lines.append("Children: " + str(young_children) + " young, " + str(older_children) + " older, " + str(adult_children) + " adult")
	if older_children > 0:
		lines.append("Family support: " + _get_family_support_text(household))
	lines.append("Family trade: " + _format_lifecycle_label(str(family_trade), "General"))
	lines.append(_get_family_growth_text(household, city))

	if succession_pressure > 0:
		lines.append("Succession: Pressure " + str(succession_pressure))
	else:
		lines.append("Succession: No pressure")

	lines.append("Age in stage: " + str(age_in_stage))

	return lines

static func _get_family_growth_text(household, city) -> String:
	if city is Object and city.has_method("get_family_growth_status_text"):
		return str(city.get_family_growth_status_text(household))

	return "Family growth: not eligible"

static func _get_family_support_text(household) -> String:
	if household is Object and household.has_method("get_older_child_support_bonus"):
		var support_bonus: int = int(household.get_older_child_support_bonus())
		if support_bonus > 0:
			return "+" + str(support_bonus) + " periodic output"

	return "older children helping production"

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

static func _format_lifecycle_label(value: String, fallback: String) -> String:
	if value.strip_edges() == "":
		return fallback

	var words: PackedStringArray = value.replace("_", " ").split(" ")
	for index in range(words.size()):
		if words[index].length() > 0:
			words[index] = words[index].substr(0, 1).to_upper() + words[index].substr(1).to_lower()

	return " ".join(words)
