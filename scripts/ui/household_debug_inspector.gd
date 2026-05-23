extends Control

var root_box: VBoxContainer
var title_label: Label
var household_label: Label
var population_label: Label
var housing_label: Label
var food_label: Label
var responsibility_label: Label
var resource_label: Label

var current_city = null

func _ready():
	root_box = VBoxContainer.new()
	root_box.name = "RootBox"
	add_child(root_box)

	title_label = Label.new()
	title_label.text = "Household Settlement Debug Inspector"
	title_label.add_theme_style_override("font_size", 16)
	root_box.add_child(title_label)

	household_label = Label.new()
	household_label.text = "Households: unavailable"
	root_box.add_child(household_label)

	population_label = Label.new()
	population_label.text = "Population: unavailable"
	root_box.add_child(population_label)

	housing_label = Label.new()
	housing_label.text = "Housing: unavailable"
	root_box.add_child(housing_label)

	food_label = Label.new()
	food_label.text = "Food: unavailable"
	root_box.add_child(food_label)

	responsibility_label = Label.new()
	responsibility_label.text = "Responsibilities: unavailable"
	root_box.add_child(responsibility_label)

	resource_label = Label.new()
	resource_label.text = "Resources: unavailable"
	root_box.add_child(resource_label)

func set_city(city):
	current_city = city
	update_from_city(city)

func update_from_city(city):
	if not city:
		_set_fallback_labels()
		return

	var pressure_summary = _call_city_method(city, "get_pressure_summary", {})

	var household_count = _read_city_resource(city, "household_count")
	if household_count == "unavailable" and "households" in city:
		household_count = city.households.size()
	household_label.text = "Households: " + _format_value(household_count)

	var total_population = _call_city_method(city, "get_total_population")
	if total_population == "unavailable":
		total_population = _read_city_resource(city, "total_population")
	population_label.text = "Population: " + _format_value(total_population)

	var housing_capacity = _read_city_resource(city, "housing_capacity")
	var shelter_pressure = _read_pressure_status(pressure_summary, "shelter")
	housing_label.text = "Housing: capacity " + _format_value(housing_capacity) + _format_suffix(shelter_pressure)

	var food_amount = _read_city_resource(city, "food")
	var food_pressure = _read_pressure_status(pressure_summary, "food")
	food_label.text = "Food: " + _format_value(food_amount) + _format_suffix(food_pressure)

	var assigned_workers = _read_city_resource(city, "assigned_workers")
	var total_labor_capacity = _call_city_method(city, "get_total_labor_capacity")
	if total_labor_capacity == "unavailable":
		total_labor_capacity = _read_city_resource(city, "total_labor_capacity")
	var idle_workers = _read_city_resource(city, "idle_workers")
	responsibility_label.text = "Responsibilities: assigned " + _format_value(assigned_workers) + " / capacity " + _format_value(total_labor_capacity) + ", idle " + _format_value(idle_workers)

	var food = _read_city_resource(city, "food")
	var wood = _read_city_resource(city, "wood")
	var tools = _read_city_resource(city, "tools")
	resource_label.text = "Resources: food " + _format_value(food) + ", wood " + _format_value(wood) + ", tools " + _format_value(tools)

func _set_fallback_labels():
	household_label.text = "Households: unavailable"
	population_label.text = "Population: unavailable"
	housing_label.text = "Housing: unavailable"
	food_label.text = "Food: unavailable"
	responsibility_label.text = "Responsibilities: unavailable"
	resource_label.text = "Resources: unavailable"

func _read_city_resource(city, key: String, fallback = "unavailable"):
	if city == null:
		return fallback
	if not ("resources" in city):
		return fallback
	if not (city.resources is Dictionary):
		return fallback
	if not city.resources.has(key):
		return fallback

	return city.resources[key]

func _call_city_method(city, method_name: String, fallback = "unavailable"):
	if city == null:
		return fallback
	if not city.has_method(method_name):
		return fallback

	var value = city.call(method_name)
	if value == null:
		return fallback

	return value

func _read_pressure_status(pressure_summary, key: String, fallback = "unavailable"):
	if not (pressure_summary is Dictionary):
		return fallback
	if not pressure_summary.has(key):
		return fallback
	var pressure = pressure_summary[key]
	if not (pressure is Dictionary):
		return fallback
	if not pressure.has("status"):
		return fallback
	if pressure["status"] == null:
		return fallback
	return pressure["status"]

func _format_suffix(value, fallback = "unavailable"):
	if value == fallback:
		return ""

	return " (" + _format_value(value, fallback) + ")"

func _format_value(value, fallback = "unavailable"):
	if value == null:
		return fallback
	if value == "":
		return fallback

	return str(value)

func _safe_get(target, property_name, fallback = "unavailable"):
	if target == null:
		return fallback
	if target is Dictionary and target.has(property_name):
		return target[property_name]

	return fallback
