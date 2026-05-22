class_name Household
extends RefCounted

const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
const RESIDENCE_HOUSED: String = "housed"
const RESIDENCE_TEMPORARY: String = "temporary"
const RESIDENCE_UNSHELTERED: String = "unsheltered"

var id: int = -1
var house_building_id: int = -1
var residence_building_id: int = -1
var housing_status: String = RESIDENCE_TEMPORARY
var preference: String = WORK_PREF_NEUTRAL
var population_capacity: int = 4
var total_population: int = 4
var labor_capacity: int = 2
var worker_capacity: int = 2
var assigned_workers: int = 0
var assigned_building_ids: Array[int] = []

func _init(household_id: int = -1, building_id: int = -1, work_preference: String = WORK_PREF_NEUTRAL, population: int = 4, residence_status: String = RESIDENCE_TEMPORARY):
	id = household_id
	house_building_id = building_id
	residence_building_id = building_id
	preference = work_preference
	total_population = population
	housing_status = residence_status
	update_labor_capacity()

func is_available() -> bool:
	return get_available_workers() > 0

func get_available_workers() -> int:
	return max(0, worker_capacity - assigned_workers)

func assign_to_building(building_id: int, workers: int = 1):
	if assigned_building_ids.has(building_id):
		return

	assigned_building_ids.append(building_id)
	assigned_workers += workers

func unassign_from_building(building_id: int, workers: int = 1):
	if not assigned_building_ids.has(building_id):
		return

	assigned_building_ids.erase(building_id)
	assigned_workers = max(0, assigned_workers - workers)

func update_labor_capacity():
	if total_population <= 1:
		labor_capacity = 0
	elif total_population <= 3:
		labor_capacity = 1
	else:
		labor_capacity = 2

	worker_capacity = labor_capacity

func move_to_house(building_id: int):
	housing_status = RESIDENCE_HOUSED
	house_building_id = building_id
	residence_building_id = building_id

func move_to_temporary_shelter():
	housing_status = RESIDENCE_TEMPORARY
	house_building_id = -1
	residence_building_id = -1

func move_to_unsheltered():
	housing_status = RESIDENCE_UNSHELTERED
	house_building_id = -1
	residence_building_id = -1

func get_match_quality(building_type: String) -> String:
	if preference == WORK_PREF_NEUTRAL:
		return "neutral"

	var preferred_worker: String = get_preferred_worker_for_building(building_type)
	if preference == preferred_worker:
		return "good match"

	return "poor match"

func get_preferred_worker_for_building(building_type: String) -> String:
	if building_type == Building.BUILDING_FARM:
		return WORK_PREF_AGRARIAN
	if building_type == Building.BUILDING_WOODCUTTER or building_type == Building.BUILDING_TOOLMAKER:
		return WORK_PREF_INDUSTRIAL

	return WORK_PREF_NEUTRAL
