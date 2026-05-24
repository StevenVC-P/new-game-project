class_name CityPressureHintHelper
extends RefCounted

const FALLBACK_HINT: String = "No urgent action hints."
const MAX_HINTS: int = 3

static func get_hints(pressure_summary: Dictionary, resources: Dictionary) -> Array[String]:
	var action_hint_lines: Array[String] = []

	_add_pressure_hint(action_hint_lines, pressure_summary, "food", "Assign a household to food production or build another farm.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "shelter", "Build housing or reduce unhoused shelter pressure.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "labor", "Assign idle household labor to production buildings.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "tools", "Produce or trade for tools to support maintenance.")
	_add_pressure_hint(action_hint_lines, pressure_summary, "maintenance", "Enable maintenance and ensure tools are available.")

	if action_hint_lines.is_empty():
		action_hint_lines.append(FALLBACK_HINT)

	return action_hint_lines

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
