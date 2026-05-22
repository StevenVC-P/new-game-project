class_name SimulationClock
extends RefCounted

const SPEED_PAUSED: String = "Paused"
const DEFAULT_DAY_SECONDS_AT_1X: float = 1.0

var speed_options: Array[Dictionary] = [
	{"label": "1x", "multiplier": 1.0},
	{"label": "3x", "multiplier": 3.0},
	{"label": "10x", "multiplier": 10.0}
]
var day_seconds_at_1x: float = DEFAULT_DAY_SECONDS_AT_1X
var speed_index: int = 0
var is_paused: bool = false
var day_accumulator: float = 0.0

func advance_realtime(delta_seconds: float) -> int:
	if is_paused:
		return 0

	day_accumulator += delta_seconds * get_speed_multiplier()
	var days_to_advance: int = 0

	while day_accumulator >= day_seconds_at_1x:
		day_accumulator -= day_seconds_at_1x
		days_to_advance += 1

	return days_to_advance

func set_speed_by_index(new_speed_index: int):
	if new_speed_index < 0 or new_speed_index >= speed_options.size():
		return

	speed_index = new_speed_index
	is_paused = false

func set_speed_by_multiplier(multiplier: float):
	for option_index in range(speed_options.size()):
		var option: Dictionary = speed_options[option_index]
		if float(option["multiplier"]) == multiplier:
			set_speed_by_index(option_index)
			return

func toggle_pause():
	is_paused = not is_paused

func pause():
	is_paused = true

func unpause():
	is_paused = false

func get_speed_multiplier() -> float:
	if is_paused:
		return 0.0

	var option: Dictionary = speed_options[speed_index]
	return float(option["multiplier"])

func get_speed_label() -> String:
	if is_paused:
		return SPEED_PAUSED

	var option: Dictionary = speed_options[speed_index]
	return option["label"] as String

func get_controls_text() -> String:
	return "Space pause, 1/2/3 speed"
