class_name Household
extends RefCounted

const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
const RESIDENCE_HOUSED: String = "housed"
const RESIDENCE_TEMPORARY: String = "temporary"
const RESIDENCE_UNSHELTERED: String = "unsheltered"
const LIFECYCLE_NEWLYWED: String = "newlywed"
const LIFECYCLE_YOUNG_FAMILY: String = "young_family"
const LIFECYCLE_ESTABLISHED_FAMILY: String = "established_family"
const LIFECYCLE_MATURE_FAMILY: String = "mature_family"
const LIFECYCLE_OLD_COUPLE: String = "old_couple"
const NEWLYWED_MONTHS_TO_YOUNG_FAMILY: int = 6
const YOUNG_FAMILY_MONTHS_TO_ESTABLISHED: int = 12
const ESTABLISHED_MONTHS_TO_MATURE: int = 24
const MATURE_MONTHS_TO_OLD_COUPLE: int = 36
const CHILD_COHORT_AGING_MONTHS: int = 36
const BIRTH_CHANCE_NEWLYWED: int = 15
const BIRTH_CHANCE_YOUNG_FAMILY: int = 20
const BIRTH_CHANCE_ESTABLISHED_FAMILY: int = 8
const BIRTH_CHANCE_MATURE_FAMILY: int = 2

var id: int = -1
var house_building_id: int = -1
var residence_building_id: int = -1
var housing_status: String = RESIDENCE_TEMPORARY
var preference: String = WORK_PREF_NEUTRAL
var population_capacity: int = 4
var total_population: int = 4
var working_adults: int = 2
var lifecycle_stage: String = LIFECYCLE_ESTABLISHED_FAMILY
var young_children: int = 0
var older_children: int = 0
var adult_children: int = 0
var family_trade: String = "general"
var parent_household_id: int = -1
var origin_household_id: int = -1
var generation: int = 0
var succession_pressure: int = 0
var age_in_stage: int = 0
var child_age_months: int = 0
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
	working_adults = get_compatibility_working_adults_for_population(population)
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
	labor_capacity = clampi(working_adults, 0, 2)
	worker_capacity = labor_capacity

func get_compatibility_working_adults_for_population(population: int) -> int:
	if population <= 1:
		return 0
	if population <= 3:
		return 1

	return 2

func add_external_population(amount: int = 1):
	total_population += max(0, amount)
	working_adults = max(working_adults, get_compatibility_working_adults_for_population(total_population))
	update_labor_capacity()

func can_receive_birth() -> bool:
	if lifecycle_stage == LIFECYCLE_OLD_COUPLE:
		return false
	if housing_status != RESIDENCE_HOUSED:
		return false
	if young_children >= 2:
		return false
	if get_total_child_count() >= 4:
		return false

	return get_birth_base_chance() > 0

func get_birth_base_chance() -> int:
	if lifecycle_stage == LIFECYCLE_NEWLYWED:
		return BIRTH_CHANCE_NEWLYWED
	if lifecycle_stage == LIFECYCLE_YOUNG_FAMILY:
		return BIRTH_CHANCE_YOUNG_FAMILY
	if lifecycle_stage == LIFECYCLE_ESTABLISHED_FAMILY:
		return BIRTH_CHANCE_ESTABLISHED_FAMILY
	if lifecycle_stage == LIFECYCLE_MATURE_FAMILY:
		return BIRTH_CHANCE_MATURE_FAMILY

	return 0

func add_young_child_from_birth():
	young_children += 1
	total_population += 1
	child_age_months = 0
	update_labor_capacity()

func get_total_child_count() -> int:
	return young_children + older_children + adult_children

func get_potential_new_family_count() -> int:
	return int(floor(float(adult_children) / 2.0))

func has_succession_pressure() -> bool:
	return get_potential_new_family_count() > 0

func get_succession_status() -> String:
	if has_succession_pressure():
		return "future_family_ready"

	return "none"

func recalculate_succession_pressure():
	succession_pressure = get_potential_new_family_count()

func can_form_new_family() -> bool:
	return adult_children >= 2

func spend_adult_children_for_new_family():
	adult_children = max(0, adult_children - 2)
	total_population = max(0, total_population - 2)
	recalculate_succession_pressure()
	update_labor_capacity()

func advance_lifecycle_month():
	age_in_stage += 1
	child_age_months += 1
	var did_stage_transition_age_children: bool = apply_lifecycle_transition_if_ready()
	if not did_stage_transition_age_children and child_age_months >= CHILD_COHORT_AGING_MONTHS:
		age_child_cohorts()
	recalculate_succession_pressure()

func apply_lifecycle_transition_if_ready() -> bool:
	if lifecycle_stage == LIFECYCLE_NEWLYWED and age_in_stage >= NEWLYWED_MONTHS_TO_YOUNG_FAMILY:
		transition_to_young_family()
		return false
	elif lifecycle_stage == LIFECYCLE_YOUNG_FAMILY and age_in_stage >= YOUNG_FAMILY_MONTHS_TO_ESTABLISHED:
		transition_to_established_family()
		return true
	elif lifecycle_stage == LIFECYCLE_ESTABLISHED_FAMILY and age_in_stage >= ESTABLISHED_MONTHS_TO_MATURE:
		transition_to_mature_family()
		return true
	elif lifecycle_stage == LIFECYCLE_MATURE_FAMILY and age_in_stage >= MATURE_MONTHS_TO_OLD_COUPLE:
		transition_to_old_couple()
		return true

	return false

func transition_to_young_family():
	lifecycle_stage = LIFECYCLE_YOUNG_FAMILY
	reset_lifecycle_stage_age()

func transition_to_established_family():
	lifecycle_stage = LIFECYCLE_ESTABLISHED_FAMILY
	older_children += young_children
	young_children = 0
	reset_child_cohort_age()
	reset_lifecycle_stage_age()

func transition_to_mature_family():
	lifecycle_stage = LIFECYCLE_MATURE_FAMILY
	adult_children += older_children
	older_children = young_children
	young_children = 0
	reset_child_cohort_age()
	reset_lifecycle_stage_age()

func transition_to_old_couple():
	lifecycle_stage = LIFECYCLE_OLD_COUPLE
	adult_children += older_children
	older_children = young_children
	young_children = 0
	reset_child_cohort_age()
	reset_lifecycle_stage_age()

func age_child_cohorts():
	adult_children += older_children
	older_children = young_children
	young_children = 0
	reset_child_cohort_age()

func reset_lifecycle_stage_age():
	age_in_stage = 0

func reset_child_cohort_age():
	child_age_months = 0

func get_family_support_power() -> int:
	return max(0, older_children)

func get_older_child_support_bonus() -> int:
	return int(floor(sqrt(float(get_family_support_power()))))

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
