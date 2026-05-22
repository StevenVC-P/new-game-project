class_name Calendar
extends RefCounted

signal day_advanced(calendar: Calendar)
signal month_changed(calendar: Calendar)
signal season_changed(calendar: Calendar)
signal year_changed(calendar: Calendar)

const DAYS_PER_MONTH: int = 30
const MONTHS_PER_YEAR: int = 12
const DAYS_PER_YEAR: int = DAYS_PER_MONTH * MONTHS_PER_YEAR

var month_names: Array[String] = [
	"Month 1",
	"Month 2",
	"Month 3",
	"Month 4",
	"Month 5",
	"Month 6",
	"Month 7",
	"Month 8",
	"Month 9",
	"Month 10",
	"Month 11",
	"Month 12"
]
var season_names: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
var current_day: int = 1
var current_month: int = 1
var current_year: int = 1
var total_days_elapsed: int = 0

func advance_day():
	var previous_month: int = current_month
	var previous_season: String = get_current_season()
	var previous_year: int = current_year

	total_days_elapsed += 1
	current_day += 1

	if current_day > DAYS_PER_MONTH:
		current_day = 1
		current_month += 1

	if current_month > MONTHS_PER_YEAR:
		current_month = 1
		current_year += 1

	day_advanced.emit(self)

	if current_month != previous_month:
		month_changed.emit(self)

	if get_current_season() != previous_season:
		season_changed.emit(self)

	if current_year != previous_year:
		year_changed.emit(self)

func get_current_season() -> String:
	var season_index: int = int(floor(float(current_month - 1) / 3.0))
	return season_names[season_index]

func get_current_month_name() -> String:
	return month_names[current_month - 1]

func get_day_of_year() -> int:
	return (current_month - 1) * DAYS_PER_MONTH + current_day

func get_elapsed_years() -> int:
	return int(floor(float(total_days_elapsed) / float(DAYS_PER_YEAR)))

func get_formatted_date() -> String:
	return get_current_season() + ", " + get_current_month_name() + ", Day " + str(current_day) + ", Year " + str(current_year)

func get_short_date() -> String:
	return get_current_season() + " Y" + str(current_year) + " M" + str(current_month) + " D" + str(current_day)
