class_name CityPressureHintHelper
extends RefCounted

const FALLBACK_HINT: String = "No urgent action hints."
const MAX_HINTS: int = 3

static func get_hints(pressure_summary: Dictionary, resources: Dictionary, need_pressure_summary: Dictionary = {}) -> Array[String]:
	var action_hint_lines: Array[String] = []

	_add_food_need_hint(action_hint_lines, need_pressure_summary)
	_add_household_goods_need_hint(action_hint_lines, need_pressure_summary)
	_add_pressure_hint(action_hint_lines, pressure_summary, "food", "Assign a household to food production or build another farm.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "shelter", "Build housing or reduce unhoused shelter pressure.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "labor", "Assign idle household labor to production buildings.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "tools", "Produce or trade for tools to support maintenance.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "maintenance", "Enable maintenance and ensure tools are available.")

	if action_hint_lines.is_empty():
		action_hint_lines.append(FALLBACK_HINT)

	return action_hint_lines

static func _add_food_need_hint(action_hint_lines: Array[String], need_pressure_summary: Dictionary) -> void:
	if action_hint_lines.size() >= MAX_HINTS:
		return
	if not need_pressure_summary.has("food"):
		return

	var food_need = need_pressure_summary["food"]
	if not (food_need is Dictionary):
		return

	var status: String = _read_string(food_need, "status")
	if status == "shortage":
		action_hint_lines.append("Food shortage: assign households to farms or import food.")
	elif status == "low":
		action_hint_lines.append("Food demand rising: increase food production or trade for food.")

static func _add_household_goods_need_hint(action_hint_lines: Array[String], need_pressure_summary: Dictionary) -> void:
	if action_hint_lines.size() >= MAX_HINTS:
		return
	if not need_pressure_summary.has("household_goods"):
		return

	var household_goods_need = need_pressure_summary["household_goods"]
	if not (household_goods_need is Dictionary):
		return

	var status: String = _read_string(household_goods_need, "status")
	if status == "unmet":
		action_hint_lines.append("Household goods demand unmet: produce domestic goods.")
	elif status == "low":
		action_hint_lines.append("Household goods low: produce carved goods, tiles, or statues.")

static func _add_pressure_hint(action_hint_lines: Array[String], pressure_summary: Dictionary, key: String, hint: String) -> void:
	if action_hint_lines.size() >= MAX_HINTS:
		return
	if not pressure_summary.has(key):
		return

	var pressure_entry = pressure_summary[key]
	if not (pressure_entry is Dictionary):
		return

	var severity: String = _read_string(pressure_entry, "severity")
	var status: String = _read_string(pressure_entry, "status")
	if severity != "danger" and severity != "warning":
		return

	if status.is_empty():
		action_hint_lines.append(hint)
	else:
		action_hint_lines.append(status + ": " + hint)

static func _read_string(values: Dictionary, key: String) -> String:
	if not values.has(key):
		return ""
	if values[key] == null:
		return ""

	return str(values[key])
