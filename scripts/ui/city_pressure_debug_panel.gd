extends Control

var city: City = null
var title_label: Label
var source_values_label: Label
var pressure_labels: Dictionary = {}

func _ready() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.position = Vector2(18, 174)
	panel.custom_minimum_size = Vector2(380, 340)
	panel.size = Vector2(380, 340)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin_container)

	var scroll_container := ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(356, 316)
	scroll_container.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin_container.add_child(scroll_container)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	root_box.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll_container.add_child(root_box)

	title_label = Label.new()
	title_label.text = "City Pressure Diagnostics"
	title_label.add_theme_font_size_override("font_size", 16)
	root_box.add_child(title_label)

	source_values_label = Label.new()
	source_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_values_label.text = "Source values: unavailable"
	root_box.add_child(source_values_label)

	_add_pressure_label(root_box, "food", "Food")
	_add_pressure_label(root_box, "shelter", "Shelter")
	_add_pressure_label(root_box, "labor", "Labor")
	_add_pressure_label(root_box, "tools", "Tools")
	_add_pressure_label(root_box, "maintenance", "Maintenance")

	visible = false

func set_city(p_city: City) -> void:
	city = p_city
	update_from_city()

func update_from_city() -> void:
	if not is_instance_valid(city):
		_set_fallback_labels()
		return

	var resources: Dictionary = _get_city_resources(city)
	source_values_label.text = _format_source_values(resources)

	var pressure_summary = {}
	if city.has_method("get_pressure_summary"):
		var summary = city.get_pressure_summary()
		if summary is Dictionary:
			pressure_summary = summary

	_update_pressure_label("food", "Food", pressure_summary)
	_update_pressure_label("shelter", "Shelter", pressure_summary)
	_update_pressure_label("labor", "Labor", pressure_summary)
	_update_pressure_label("tools", "Tools", pressure_summary)
	_update_pressure_label("maintenance", "Maintenance", pressure_summary)

func _add_pressure_label(root_box: VBoxContainer, key: String, display_name: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = display_name + ": unavailable"
	root_box.add_child(label)
	pressure_labels[key] = label

func _update_pressure_label(key: String, display_name: String, pressure_summary: Dictionary) -> void:
	if not pressure_labels.has(key):
		return

	pressure_labels[key].text = _format_pressure_entry(display_name, pressure_summary.get(key, "unavailable"))

func _format_pressure_entry(display_name: String, entry) -> String:
	if not (entry is Dictionary):
		return display_name + ": " + _format_value(entry)

	var status: String = _format_value(entry.get("status", "unavailable"))
	var severity: String = _format_value(entry.get("severity", "unavailable"))
	var detail: String = _format_value(entry.get("detail", ""))
	var line: String = display_name + ": " + status

	if severity != "unavailable":
		line += " [" + severity + "]"
	if detail != "unavailable":
		line += "\n  " + detail

	return line

func _format_source_values(resources: Dictionary) -> String:
	if resources.is_empty():
		return "Source values: unavailable"

	var parts := PackedStringArray([
		"food " + _format_value(_read_resource(resources, "food")),
		"wood " + _format_value(_read_resource(resources, "wood")),
		"tools " + _format_value(_read_resource(resources, "tools")),
		"population " + _format_value(_read_resource(resources, "total_population")),
		"labor " + _format_value(_read_resource(resources, "assigned_workers")) + "/" + _format_value(_read_resource(resources, "total_labor_capacity")),
		"idle " + _format_value(_read_resource(resources, "idle_workers")),
		"housing " + _format_value(_read_resource(resources, "housing_capacity"))
	])
	return "Source values: " + ", ".join(parts)

func _set_fallback_labels() -> void:
	source_values_label.text = "Source values: unavailable"
	for key: String in pressure_labels.keys():
		var label: Label = pressure_labels[key] as Label
		label.text = key.capitalize() + ": unavailable"

func _get_city_resources(target_city: City) -> Dictionary:
	if not is_instance_valid(target_city):
		return {}

	var value = target_city.get("resources")
	if value is Dictionary:
		return value

	return {}

func _read_resource(resources: Dictionary, key: String, fallback = "unavailable"):
	if not resources.has(key):
		return fallback
	if resources[key] == null:
		return fallback

	return resources[key]

func _format_value(value, fallback: String = "unavailable") -> String:
	if value == null:
		return fallback
	if value is String and value == "":
		return fallback

	return str(value)
