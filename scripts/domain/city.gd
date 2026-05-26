class_name City
extends RefCounted

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
const FARM_BASE_OUTPUT: int = 2
const WOODCUTTER_BASE_OUTPUT: int = 2
const TOOLMAKER_BASE_OUTPUT: int = 1
const TOOLMAKER_WOOD_INPUT: int = 2
const EXPANDED_GOODS_BASE_OUTPUT: int = 1
const STARTER_NEUTRAL_WORKERS: int = 0
const STARTING_EXTERNAL_POPULATION_POOL: int = 20
const STARTING_HOUSEHOLD_COUNT: int = 3
const STARTING_HOUSEHOLD_POPULATION: int = 4
const STARTING_POPULATION: int = STARTING_HOUSEHOLD_COUNT * STARTING_HOUSEHOLD_POPULATION
const HOUSE_CAPACITY: int = 4
const FOOD_PER_POPULATION_DIVISOR: int = 2
const OLDER_CHILD_SUPPORT_TICK_INTERVAL: int = 4
const FOOD_SURPLUS_TICKS_FOR_GROWTH: int = 8
const STARTING_MAINTENANCE_GRACE_TICKS: int = 20
const RESOURCE_HISTORY_LIMIT: int = 16
const BIRTH_FOOD_SURPLUS_DAYS: float = 10.0
const BIRTH_MIN_FOOD_DAYS: float = 5.0
const BIRTH_FOOD_SURPLUS_BONUS: int = 5
const BIRTH_HOUSING_HEADROOM_BONUS: int = 5
const BIRTH_REQUIRED_HOUSING_HEADROOM: int = 2
const OLD_COUPLE_MIN_MORTALITY_MONTHS: int = 12
const ENABLE_HOUSEHOLD_LIFECYCLE_LOGS: bool = true

var name: String = "City"
var tile: Vector2 = Vector2.ZERO
var local_map: Array = []
var buildings: Array[Building] = []
var households: Array[Household] = []
var resources: Dictionary = {}
var resource_history: Array = []
var site_profile: SettlementSiteProfile = SettlementSiteProfile.new()

func _init(city_name: String = "City", city_tile: Vector2 = Vector2.ZERO):
	name = city_name
	tile = city_tile
	resources = make_starting_resources()
	create_starter_households()
	recalculate_household_succession_pressures()
	update_shelter_counts()
	record_resource_history()

func make_starting_resources() -> Dictionary:
	return {
		"food": 60,
		"wood": 45,
		"tools": 14,
		"stone_blocks": 0,
		"cut_stone": 0,
		"bricks": 0,
		"masonry": 0,
		"lime": 0,
		"mortar": 0,
		"statues": 0,
		"carved_goods": 0,
		"tiles": 0,
		"paving_stones": 0,
		"house_shelter_capacity": 0,
		"temporary_shelter_capacity": STARTING_POPULATION,
		"housing_capacity": STARTING_POPULATION,
		"housed_population": 0,
		"temporary_sheltered_population": STARTING_POPULATION,
		"sheltered_population": STARTING_POPULATION,
		"unsheltered_population": 0,
		"total_population": 0,
		"household_count": 0,
		"total_labor_capacity": 0,
		"assigned_workers": 0,
		"idle_workers": 0,
		"food_consumption_rate": 2,
		"food_shortage": false,
		"production_tick_count": 0,
		"food_surplus_ticks": 0,
		"external_population_pool": STARTING_EXTERNAL_POPULATION_POOL,
		"maintenance_grace_ticks": STARTING_MAINTENANCE_GRACE_TICKS
	}

func create_starter_households():
	var preferences: Array[String] = [WORK_PREF_AGRARIAN, WORK_PREF_INDUSTRIAL, WORK_PREF_NEUTRAL]

	for household_index in range(STARTING_HOUSEHOLD_COUNT):
		var preference: String = preferences[household_index % preferences.size()]
		var household: Household = Household.new(household_index, -1, preference, STARTING_HOUSEHOLD_POPULATION, Household.RESIDENCE_TEMPORARY)
		seed_starter_household_lifecycle(household, household_index)
		households.append(household)

func seed_starter_household_lifecycle(household: Household, household_index: int):
	var seed_index: int = household_index % 5
	household.family_trade = get_seeded_family_trade(household.preference, household_index)
	household.parent_household_id = -1
	household.origin_household_id = household.id
	household.generation = 0
	household.succession_pressure = 0

	if seed_index == 0:
		household.lifecycle_stage = "young_family"
		household.young_children = 2
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 1
	elif seed_index == 1:
		household.lifecycle_stage = "established_family"
		household.young_children = 1
		household.older_children = 1
		household.adult_children = 0
		household.age_in_stage = 2
	elif seed_index == 2:
		household.lifecycle_stage = "mature_family"
		household.young_children = 0
		household.older_children = 1
		household.adult_children = 1
		household.age_in_stage = 3
	elif seed_index == 3:
		household.lifecycle_stage = "newlywed"
		household.young_children = 0
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 0
	else:
		household.lifecycle_stage = "old_couple"
		household.young_children = 0
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 4

	household.recalculate_succession_pressure()

func get_seeded_family_trade(preference: String, household_index: int) -> String:
	if preference == WORK_PREF_AGRARIAN:
		return "farming"
	if preference == WORK_PREF_INDUSTRIAL:
		if household_index % 2 == 0:
			return "woodcraft"
		return "stonework"

	return "general"

func advance_household_lifecycle_month(city_index: int = 0):
	log_household_lifecycle_event(city_index, -1, "MonthAgingPass", "households=" + str(households.size()))
	for household: Household in households:
		var before_state: Dictionary = get_household_lifecycle_log_state(household)
		household.advance_lifecycle_month()
		log_household_lifecycle_event(city_index, household.id, "MonthAged", "age_in_stage=" + str(household.age_in_stage) + " child_age_months=" + str(household.child_age_months))
		log_household_lifecycle_state_changes(city_index, household, before_state)
	recalculate_household_succession_pressures(city_index)
	advance_new_family_formation_month(city_index)
	recalculate_household_succession_pressures(city_index)
	advance_old_couple_lifecycle_completion_month(city_index)
	recalculate_household_succession_pressures(city_index)
	update_shelter_counts()
	update_worker_counts()

func recalculate_household_succession_pressures(city_index: int = 0):
	for household: Household in households:
		var previous_pressure: int = household.succession_pressure
		household.recalculate_succession_pressure()
		if household.succession_pressure != previous_pressure:
			log_household_lifecycle_event(city_index, household.id, "SuccessionPressureRecalculated", "from=" + str(previous_pressure) + " to=" + str(household.succession_pressure) + " potential_new_families=" + str(household.get_potential_new_family_count()))
		elif household.has_succession_pressure():
			log_household_lifecycle_event(city_index, household.id, "SuccessionReady", "potential_new_families=" + str(household.get_potential_new_family_count()))

func advance_new_family_formation_month(city_index: int = 0):
	var parent_households: Array[Household] = households.duplicate()
	for parent: Household in parent_households:
		if not parent.can_form_new_family():
			continue

		log_household_lifecycle_event(city_index, parent.id, "NewFamilyFormationAttempted", "adult_children=" + str(parent.adult_children) + " potential_new_families=" + str(parent.get_potential_new_family_count()))
		var house_id: int = find_empty_house_building_id()
		if house_id < 0:
			log_household_lifecycle_event(city_index, parent.id, "NewFamilyFormationBlocked", "reason=no_empty_house adult_children=" + str(parent.adult_children))
			return

		form_new_family_from_parent(parent, house_id, city_index)

func find_empty_house_building_id() -> int:
	var open_house_ids: Array[int] = get_empty_house_building_ids()
	if open_house_ids.is_empty():
		return -1

	return int(open_house_ids[0])

func form_new_family_from_parent(parent: Household, house_id: int, city_index: int = 0):
	var parent_adult_children_before: int = parent.adult_children
	var parent_population_before: int = parent.total_population
	parent.spend_adult_children_for_new_family()
	log_household_lifecycle_event(city_index, parent.id, "NewFamilyParentUpdated", "adult_children=" + str(parent_adult_children_before) + "->" + str(parent.adult_children) + " total_population=" + str(parent_population_before) + "->" + str(parent.total_population))

	var household_id: int = households.size()
	var new_household: Household = Household.new(household_id, house_id, parent.preference, 2, Household.RESIDENCE_HOUSED)
	new_household.lifecycle_stage = Household.LIFECYCLE_NEWLYWED
	new_household.young_children = 0
	new_household.older_children = 0
	new_household.adult_children = 0
	new_household.age_in_stage = 0
	new_household.child_age_months = 0
	new_household.working_adults = 2
	new_household.parent_household_id = parent.id
	if parent.origin_household_id >= 0:
		new_household.origin_household_id = parent.origin_household_id
	else:
		new_household.origin_household_id = parent.id
	new_household.generation = parent.generation + 1
	new_household.family_trade = get_inherited_family_trade(parent, new_household, city_index)
	new_household.succession_pressure = 0
	new_household.move_to_house(house_id)
	new_household.update_labor_capacity()
	households.append(new_household)
	log_household_lifecycle_event(city_index, parent.id, "NewFamilyFormed", "child_household=" + str(new_household.id) + " house=" + str(house_id) + " parent_adult_children=" + str(parent.adult_children))
	log_household_lifecycle_event(city_index, new_household.id, "NewHouseholdCreated", "parent=" + str(parent.id) + " house=" + str(house_id) + " stage=" + new_household.lifecycle_stage + " total_population=" + str(new_household.total_population) + " working_adults=" + str(new_household.working_adults) + " family_trade=" + new_household.family_trade)
	log_household_lifecycle_event(city_index, new_household.id, "LineageAssigned", "parent=" + str(new_household.parent_household_id) + " origin=" + str(new_household.origin_household_id) + " generation=" + str(new_household.generation) + " family_trade=" + new_household.family_trade)

func get_inherited_family_trade(parent: Household, child: Household, city_index: int = 0) -> String:
	var parent_trade: String = parent.family_trade
	if parent_trade.strip_edges() == "":
		parent_trade = "general"

	var related_trades: Array[String] = get_related_family_trades(parent_trade)
	var roll: int = get_family_trade_inheritance_roll(parent, child, city_index)
	if roll < 75:
		return parent_trade
	if roll < 95 and related_trades.size() > 0:
		return related_trades[roll % related_trades.size()]

	return "general"

func get_family_trade_inheritance_roll(parent: Household, child: Household, city_index: int = 0) -> int:
	var seed_value: int = parent.id * 43
	seed_value += child.id * 97
	seed_value += city_index * 131
	seed_value += child.generation * 29
	seed_value += int(tile.x) * 17
	seed_value += int(tile.y) * 19
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func get_related_family_trades(family_trade: String) -> Array[String]:
	if family_trade == "farming":
		return ["food_processing"]
	if family_trade == "woodcraft":
		return ["construction", "toolmaking"]
	if family_trade == "stonework":
		return ["construction", "masonry"]
	if family_trade == "claywork":
		return ["construction"]
	if family_trade == "textile":
		return []
	if family_trade == "food_processing":
		return ["farming"]
	if family_trade == "toolmaking":
		return ["woodcraft", "stonework"]
	if family_trade == "construction":
		return ["woodcraft", "stonework"]

	return []

func advance_old_couple_lifecycle_completion_month(city_index: int = 0):
	var active_households: Array[Household] = households.duplicate()
	for household: Household in active_households:
		if household.lifecycle_stage != Household.LIFECYCLE_OLD_COUPLE:
			continue
		if household.adult_children > 0:
			log_household_lifecycle_event(city_index, household.id, "OldCoupleRemovalBlocked", "reason=adult_children_remaining adult_children=" + str(household.adult_children))
			continue
		var chance: int = get_old_couple_lifecycle_completion_chance(household)
		if chance <= 0:
			continue
		var roll: int = get_old_couple_lifecycle_completion_roll(household, city_index)
		log_household_lifecycle_event(city_index, household.id, "OldCoupleMortalityRoll", "roll=" + str(roll) + " chance=" + str(chance) + " age_in_stage=" + str(household.age_in_stage))
		if roll >= chance:
			continue

		complete_old_couple_lifecycle(household, city_index)

func get_old_couple_lifecycle_completion_chance(household: Household) -> int:
	if household.age_in_stage < OLD_COUPLE_MIN_MORTALITY_MONTHS:
		return 0
	if household.age_in_stage < 24:
		return 5
	if household.age_in_stage < 36:
		return 10
	if household.age_in_stage < 48:
		return 20

	return 35

func get_old_couple_lifecycle_completion_roll(household: Household, city_index: int = 0) -> int:
	var seed_value: int = household.id * 41
	seed_value += city_index * 109
	seed_value += household.age_in_stage * 31
	seed_value += int(tile.x) * 11
	seed_value += int(tile.y) * 17
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func complete_old_couple_lifecycle(household: Household, city_index: int = 0):
	var house_id: int = household.residence_building_id
	log_household_lifecycle_event(city_index, household.id, "OldCoupleLifecycleComplete", "age_in_stage=" + str(household.age_in_stage))
	cleanup_removed_household_assignments(household, city_index)
	if house_id >= 0:
		log_household_lifecycle_event(city_index, household.id, "HouseFreed", "house=" + str(house_id))
	households.erase(household)
	log_household_lifecycle_event(city_index, household.id, "HouseholdRemoved", "reason=old_couple_lifecycle_complete")

func cleanup_removed_household_assignments(household: Household, city_index: int = 0):
	for building: Building in buildings:
		if building.assigned_household_id != household.id:
			continue

		log_household_lifecycle_event(city_index, household.id, "AssignmentCleared", "building=" + str(building.id))
		building.unassign_worker(true)
		record_work_succession_vacancy(household, building, city_index)
	household.assigned_workers = 0
	household.assigned_building_ids.clear()

func record_work_succession_vacancy(removed_household: Household, building: Building, city_index: int = 0):
	if building == null or not building.is_production_building():
		return

	building.succession_source_household_id = removed_household.id
	building.preferred_successor_household_id = -1
	log_household_lifecycle_event(city_index, removed_household.id, "WorkSuccessionVacancy", "building=" + str(building.id) + " trade=" + removed_household.family_trade)

	var preferred_candidate: Dictionary = get_preferred_work_successor(removed_household, building)
	if preferred_candidate.is_empty():
		return

	var successor: Household = preferred_candidate["household"] as Household
	var priority: String = preferred_candidate["priority"] as String
	building.preferred_successor_household_id = successor.id
	log_household_lifecycle_event(city_index, successor.id, "WorkSuccessionCandidate", "building=" + str(building.id) + " source_household=" + str(removed_household.id) + " priority=" + priority)
	log_household_lifecycle_event(city_index, successor.id, "WorkSuccessionPreferred", "building=" + str(building.id) + " reason=" + priority)

func get_household_descendants(household_id: int) -> Array[Household]:
	var result: Array[Household] = []
	for household: Household in households:
		if household.parent_household_id == household_id:
			result.append(household)

	return result

func get_work_succession_candidates(removed_household: Household, building: Building) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for household: Household in households:
		if household.id == removed_household.id:
			continue
		if not is_household_available_for_work_succession(household):
			continue

		var priority: String = get_work_succession_priority(removed_household, household)
		if priority == "":
			continue

		result.append({
			"household": household,
			"priority": priority,
			"score": get_work_succession_priority_score(priority)
		})

	sort_work_succession_candidates(result)
	return result

func get_preferred_work_successor(removed_household: Household, building: Building) -> Dictionary:
	var candidates: Array[Dictionary] = get_work_succession_candidates(removed_household, building)
	if candidates.is_empty():
		return {}

	return candidates[0]

func is_household_available_for_work_succession(household: Household) -> bool:
	if household.housing_status != Household.RESIDENCE_HOUSED:
		return false
	if household.get_available_workers() <= 0:
		return false
	for building: Building in buildings:
		if building.assigned_household_id == household.id:
			return false

	return true

func get_work_succession_priority(removed_household: Household, candidate: Household) -> String:
	var same_trade: bool = candidate.family_trade == removed_household.family_trade
	if candidate.parent_household_id == removed_household.id:
		if same_trade:
			return "direct_child_same_trade"
		return "direct_child"
	if removed_household.origin_household_id >= 0 and candidate.origin_household_id == removed_household.origin_household_id and candidate.generation > removed_household.generation:
		if same_trade:
			return "origin_descendant_same_trade"
		return "origin_descendant"
	if same_trade:
		return "same_family_trade"

	return ""

func get_work_succession_priority_score(priority: String) -> int:
	if priority == "direct_child_same_trade":
		return 0
	if priority == "direct_child":
		return 1
	if priority == "origin_descendant_same_trade":
		return 2
	if priority == "origin_descendant":
		return 3
	if priority == "same_family_trade":
		return 4

	return 99

func sort_work_succession_candidates(candidates: Array[Dictionary]):
	for outer_index in range(candidates.size()):
		for inner_index in range(outer_index + 1, candidates.size()):
			var outer_candidate: Dictionary = candidates[outer_index]
			var inner_candidate: Dictionary = candidates[inner_index]
			if should_swap_work_succession_candidates(outer_candidate, inner_candidate):
				candidates[outer_index] = inner_candidate
				candidates[inner_index] = outer_candidate

func should_swap_work_succession_candidates(left: Dictionary, right: Dictionary) -> bool:
	var left_score: int = int(left["score"])
	var right_score: int = int(right["score"])
	if right_score < left_score:
		return true
	if right_score > left_score:
		return false

	var left_household: Household = left["household"] as Household
	var right_household: Household = right["household"] as Household
	return right_household.id < left_household.id

func get_household_succession_status(household: Household) -> String:
	if household == null:
		return "none"
	if not household.has_succession_pressure():
		return "none"
	if get_empty_house_building_ids().size() > 0:
		return "ready_for_new_family"

	return "blocked_no_house"

func get_household_succession_status_text(household: Household) -> String:
	var status: String = get_household_succession_status(household)
	if status == "ready_for_new_family":
		var family_count: int = household.get_potential_new_family_count()
		if family_count == 1:
			return "Succession: 1 future family ready"
		return "Succession: " + str(family_count) + " future families ready"
	if status == "blocked_no_house":
		return "Succession: Blocked - no empty house"

	return "Succession: No pressure"

func advance_household_birth_rolls_season(calendar: Calendar, city_index: int = 0):
	update_shelter_counts()
	for household: Household in households:
		if has_birth_blocker(household):
			log_household_lifecycle_event(city_index, household.id, "BirthBlocked", "reason=" + get_birth_blocker_reason(household))
			continue

		var chance: int = get_birth_roll_chance(household)
		if chance <= 0:
			continue

		var roll: int = get_birth_roll_for_household(household, calendar, city_index)
		log_household_lifecycle_event(city_index, household.id, "BirthRollEvaluated", "roll=" + str(roll) + " chance=" + str(chance) + " season=" + calendar.get_current_season() + " year=" + str(calendar.current_year))
		if roll < chance:
			household.add_young_child_from_birth()
			log_household_lifecycle_event(city_index, household.id, "BirthSucceeded", "young_children=" + str(household.young_children) + " total_population=" + str(household.total_population) + " working_adults=" + str(household.working_adults) + " labor_capacity=" + str(household.labor_capacity))

	update_shelter_counts()
	update_worker_counts()

func get_birth_roll_for_household(household: Household, calendar: Calendar, city_index: int = 0) -> int:
	var seed_value: int = household.id * 37
	seed_value += city_index * 101
	seed_value += calendar.current_year * 503
	seed_value += calendar.current_month * 29
	seed_value += int(tile.x) * 7
	seed_value += int(tile.y) * 13
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func get_birth_roll_chance(household: Household) -> int:
	if has_birth_blocker(household):
		return 0

	var chance: int = household.get_birth_base_chance()
	if get_food_days_stored() >= BIRTH_FOOD_SURPLUS_DAYS:
		chance += BIRTH_FOOD_SURPLUS_BONUS
	if get_housing_headroom() >= BIRTH_REQUIRED_HOUSING_HEADROOM:
		chance += BIRTH_HOUSING_HEADROOM_BONUS

	return clampi(chance, 0, 30)

func has_birth_blocker(household: Household) -> bool:
	return get_birth_blocker_reason(household) != ""

func get_birth_blocker_reason(household: Household) -> String:
	if household == null:
		return "unknown_birth_blocker"
	if resources["food_shortage"] == true:
		return "food_shortage"
	if household.lifecycle_stage == Household.LIFECYCLE_OLD_COUPLE:
		return "old_couple"
	if household.housing_status != Household.RESIDENCE_HOUSED:
		if household.housing_status == Household.RESIDENCE_TEMPORARY:
			return "temporary_housing"
		return "not_housed"
	if get_total_population() >= int(resources["housing_capacity"]):
		return "housing_full"
	if household.young_children >= 2:
		return "too_many_young_children"
	if household.get_total_child_count() >= 4:
		return "too_many_total_children"
	if get_food_days_stored() < BIRTH_MIN_FOOD_DAYS:
		return "food_stored_below_5_days"
	if not household.can_receive_birth():
		if household.get_birth_base_chance() <= 0:
			return "stage_not_eligible"
		return "unknown_birth_blocker"

	return ""

func get_family_growth_status_text(household: Household) -> String:
	var blocker: String = get_birth_blocker_reason(household)
	if blocker != "":
		return "Family growth: " + get_birth_blocker_player_text(blocker)

	return "Family growth: possible"

func get_birth_blocker_player_text(blocker: String) -> String:
	if blocker == "old_couple" or blocker == "stage_not_eligible":
		return "blocked by age"
	if blocker == "food_shortage" or blocker == "food_stored_below_5_days":
		return "blocked by food"
	if blocker == "not_housed" or blocker == "temporary_housing" or blocker == "housing_full" or blocker == "no_housing_headroom":
		return "blocked by housing"
	if blocker == "too_many_young_children" or blocker == "too_many_total_children":
		return "child limit reached"

	return "not eligible"

func get_food_days_stored() -> float:
	var consumption_rate: int = max(1, int(resources["food_consumption_rate"]))
	return float(int(resources["food"])) / float(consumption_rate)

func get_housing_headroom() -> int:
	return int(resources["housing_capacity"]) - get_total_population()

func get_household_lifecycle_log_state(household: Household) -> Dictionary:
	return {
		"lifecycle_stage": household.lifecycle_stage,
		"age_in_stage": household.age_in_stage,
		"child_age_months": household.child_age_months,
		"young_children": household.young_children,
		"older_children": household.older_children,
		"adult_children": household.adult_children,
		"succession_pressure": household.succession_pressure,
		"total_population": household.total_population
	}

func log_household_lifecycle_state_changes(city_index: int, household: Household, before_state: Dictionary):
	var before_stage: String = before_state["lifecycle_stage"] as String
	if before_stage != household.lifecycle_stage:
		log_household_lifecycle_event(city_index, household.id, "StageTransition", "from=" + before_stage + " to=" + household.lifecycle_stage)

	var before_young: int = int(before_state["young_children"])
	var before_older: int = int(before_state["older_children"])
	var before_adult: int = int(before_state["adult_children"])
	if before_young != household.young_children or before_older != household.older_children or before_adult != household.adult_children:
		log_household_lifecycle_event(city_index, household.id, "ChildCohortsMoved", "young=" + str(before_young) + "->" + str(household.young_children) + " older=" + str(before_older) + "->" + str(household.older_children) + " adult=" + str(before_adult) + "->" + str(household.adult_children))

func log_household_lifecycle_event(city_index: int, household_id: int, event_name: String, detail: String = ""):
	if not ENABLE_HOUSEHOLD_LIFECYCLE_LOGS:
		return

	var line: String = "[HouseholdLifecycle] City=" + str(city_index) + " Household=" + str(household_id) + " Event=" + event_name
	if detail.strip_edges() != "":
		line += " " + detail
	print(line)

func add_building(building: Building, household: Household = null):
	building.id = buildings.size()
	buildings.append(building)
	if building.is_house():
		assign_households_to_housing()

	update_shelter_counts()
	update_worker_counts()
	auto_assign_workers()

func tick():
	update_shelter_counts()
	if int(resources["maintenance_grace_ticks"]) > 0:
		resources["maintenance_grace_ticks"] = int(resources["maintenance_grace_ticks"]) - 1
	resources["production_tick_count"] = int(resources["production_tick_count"]) + 1
	update_worker_counts()
	consume_food()

	for building: Building in buildings:
		if building.is_house():
			continue
		if int(resources["maintenance_grace_ticks"]) <= 0:
			update_building_maintenance(building)
		if building.can_produce():
			apply_building_production(building)

	update_population_from_external_pool()

func update_worker_counts():
	update_shelter_counts()
	var total_labor_capacity: int = get_total_labor_capacity()
	var assigned_workers: int = 0

	for building: Building in buildings:
		if building.is_house():
			continue

		assigned_workers += building.assigned_workers

	if assigned_workers > total_labor_capacity:
		assigned_workers = total_labor_capacity
	resources["total_labor_capacity"] = total_labor_capacity
	resources["assigned_workers"] = assigned_workers
	resources["idle_workers"] = max(0, total_labor_capacity - assigned_workers)
	update_household_worker_capacities()
	update_household_assignments()

func get_available_neutral_workers() -> int:
	var neutral_workers: int = min(STARTER_NEUTRAL_WORKERS, int(resources["total_population"]))

	for building: Building in buildings:
		if building.assigned_workers <= 0:
			continue
		if building.assigned_household_id == -1:
			neutral_workers -= building.assigned_workers

	return max(0, neutral_workers)

func get_household_by_id(household_id: int) -> Household:
	for household: Household in households:
		if household.id == household_id:
			return household

	return null

func get_household_for_building_id(building_id: int) -> Household:
	for household: Household in households:
		if household.residence_building_id == building_id:
			return household

	return null

func update_household_worker_capacities():
	for household: Household in households:
		household.update_labor_capacity()
		household.worker_capacity = household.labor_capacity

func update_household_assignments():
	for household: Household in households:
		household.assigned_workers = 0
		household.assigned_building_ids.clear()

	for building: Building in buildings:
		if building.assigned_household_id < 0:
			continue

		var household: Household = get_household_by_id(building.assigned_household_id)
		if household != null:
			household.assign_to_building(building.id, building.assigned_workers)

func get_house_worker_capacity(house_index: int) -> int:
	update_household_worker_capacities()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.worker_capacity

func get_assigned_workers_from_house(house_index: int) -> int:
	update_household_assignments()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.assigned_workers

func get_available_workers_from_house(house_index: int) -> int:
	update_household_worker_capacities()
	update_household_assignments()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.get_available_workers()

func get_available_workers_from_household(household_id: int) -> int:
	update_household_worker_capacities()
	update_household_assignments()
	var household: Household = get_household_by_id(household_id)
	if household == null:
		return 0

	return household.get_available_workers()

func get_available_households() -> Array[Household]:
	update_household_worker_capacities()
	update_household_assignments()
	var result: Array[Household] = []

	for household: Household in households:
		if household.is_available():
			result.append(household)

	return result

func get_household_counts_by_preference() -> Dictionary:
	var result: Dictionary = {
		WORK_PREF_AGRARIAN: 0,
		WORK_PREF_INDUSTRIAL: 0,
		WORK_PREF_NEUTRAL: 0
	}

	for household: Household in households:
		result[household.preference] = int(result[household.preference]) + 1

	return result

func get_household_preference_for_building(house_index: int) -> String:
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return WORK_PREF_NEUTRAL

	return household.preference

func get_household_label(household_id: int) -> String:
	var household: Household = get_household_by_id(household_id)
	if household == null:
		return "Household ?"

	return "Household " + str(household.id + 1)

func get_assigned_building_ids_for_house(house_index: int) -> Array[int]:
	update_household_assignments()
	var result: Array[int] = []
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return result

	for building_id: int in household.assigned_building_ids:
		result.append(building_id)

	return result

func get_assigned_house_building_id(building: Building) -> int:
	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return -1

	return household.residence_building_id

func get_household_preference_for_worker_modifier(building: Building) -> String:
	if building.assigned_household_id < 0:
		return WORK_PREF_NEUTRAL

	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return WORK_PREF_NEUTRAL

	return household.preference

func assign_household_to_building(building_index: int, house_index: int):
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return

	assign_household_by_id_to_building(building_index, household.id)

func assign_household_by_id_to_building(building_index: int, household_id: int):
	if building_index < 0 or building_index >= buildings.size():
		return

	var household: Household = get_household_by_id(household_id)
	if household == null:
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return
	if building.assigned_workers > 0:
		return
	if get_available_workers_from_household(household_id) <= 0:
		return

	building.assign_household(household, Building.ASSIGNMENT_PLAYER)
	update_worker_counts()

func assign_neutral_worker_to_building(building_index: int):
	if building_index < 0 or building_index >= buildings.size():
		return
	if get_available_neutral_workers() <= 0:
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return
	if building.assigned_workers > 0:
		return

	building.assign_neutral_worker()
	update_worker_counts()

func unassign_building_worker(building_index: int, player_override: bool = true):
	if building_index < 0 or building_index >= buildings.size():
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return

	building.unassign_worker(player_override)
	update_worker_counts()
	if not player_override:
		auto_assign_workers()

func toggle_building_maintenance(building_index: int):
	if building_index < 0 or building_index >= buildings.size():
		return

	var building: Building = buildings[building_index]
	building.toggle_maintenance()

func consume_food():
	update_shelter_counts()
	var population: int = get_total_population()
	var consumption_rate: int = int(ceil(float(population) / float(FOOD_PER_POPULATION_DIVISOR)))
	resources["food_consumption_rate"] = consumption_rate

	if int(resources["food"]) >= consumption_rate:
		resources["food"] = int(resources["food"]) - consumption_rate
		resources["food_shortage"] = false
	else:
		resources["food"] = 0
		resources["food_shortage"] = true

func should_skip_for_food_shortage() -> bool:
	if resources["food_shortage"] != true:
		return false

	return int(resources["production_tick_count"]) % 2 == 1

func apply_building_production(building: Building):
	if should_skip_for_food_shortage():
		return

	var building_type: String = building.type
	var output_amount: int = get_current_building_output_amount(building)
	if output_amount <= 0:
		return

	if building_type == BUILDING_FARM:
		resources["food"] = int(resources["food"]) + output_amount
	elif building_type == BUILDING_WOODCUTTER:
		resources["wood"] = int(resources["wood"]) + output_amount
	elif building_type == BUILDING_TOOLMAKER:
		var max_tool_output_from_wood: int = int(floor(float(int(resources["wood"])) / float(TOOLMAKER_WOOD_INPUT)))
		if max_tool_output_from_wood > 0:
			var tool_output: int = min(output_amount, max_tool_output_from_wood)
			resources["wood"] = int(resources["wood"]) - tool_output * TOOLMAKER_WOOD_INPUT
			resources["tools"] = int(resources["tools"]) + tool_output
	elif building_type == BUILDING_QUARRY:
		resources["stone_blocks"] = int(resources["stone_blocks"]) + output_amount
	elif building_type == BUILDING_STONECUTTER:
		apply_input_output_production("cut_stone", output_amount, {"stone_blocks": 1})
	elif building_type == BUILDING_BRICKWORKS:
		apply_input_output_production("bricks", output_amount, {"wood": 1})
	elif building_type == BUILDING_LIME_KILN:
		apply_input_output_production("lime", output_amount, {"stone_blocks": 1, "wood": 1})
	elif building_type == BUILDING_MORTAR_YARD:
		apply_input_output_production("mortar", output_amount, {"lime": 1, "stone_blocks": 1})
	elif building_type == BUILDING_MASON_YARD:
		apply_input_output_production("masonry", output_amount, {"cut_stone": 1, "mortar": 1})
	elif building_type == BUILDING_SCULPTOR:
		apply_input_output_production("statues", output_amount, {"cut_stone": 1, "tools": 1})
	elif building_type == BUILDING_CARVER:
		apply_input_output_production("carved_goods", output_amount, {"wood": 1, "tools": 1})
	elif building_type == BUILDING_TILEWORKS:
		apply_input_output_production("tiles", output_amount, {"bricks": 1, "wood": 1})
	elif building_type == BUILDING_PAVER_YARD:
		apply_input_output_production("paving_stones", output_amount, {"stone_blocks": 1})

func apply_input_output_production(output_key: String, output_amount: int, input_costs: Dictionary):
	var capped_output: int = output_amount
	for input_key: String in input_costs.keys():
		var input_cost: int = int(input_costs[input_key])
		if input_cost <= 0:
			continue
		capped_output = min(capped_output, int(floor(float(int(resources[input_key])) / float(input_cost))))

	if capped_output <= 0:
		return

	for input_key: String in input_costs.keys():
		var input_cost: int = int(input_costs[input_key])
		if input_cost > 0:
			resources[input_key] = int(resources[input_key]) - capped_output * input_cost

	resources[output_key] = int(resources[output_key]) + capped_output

func get_current_building_output_amount(building: Building) -> int:
	var maintenance_level: int = building.maintenance_level
	var tick_count: int = int(resources["production_tick_count"])
	var base_output: int = get_base_building_output_amount(building.type)

	if maintenance_level <= 0:
		return 0
	if maintenance_level >= 100:
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 75:
		if tick_count % 4 == 0:
			return 0
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 50:
		if tick_count % 2 == 1:
			return 0
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 25:
		if tick_count % 4 == 0:
			return apply_building_output_modifiers(base_output, tick_count, building)
		return 0

	return 0

func get_base_building_output_amount(building_type: String) -> int:
	if building_type == BUILDING_FARM:
		return FARM_BASE_OUTPUT
	if building_type == BUILDING_WOODCUTTER:
		return WOODCUTTER_BASE_OUTPUT
	if building_type == BUILDING_TOOLMAKER:
		return TOOLMAKER_BASE_OUTPUT
	if building_type == BUILDING_QUARRY:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_STONECUTTER:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_BRICKWORKS:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_LIME_KILN:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_MORTAR_YARD:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_MASON_YARD:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_SCULPTOR:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_CARVER:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_TILEWORKS:
		return EXPANDED_GOODS_BASE_OUTPUT
	if building_type == BUILDING_PAVER_YARD:
		return EXPANDED_GOODS_BASE_OUTPUT

	return 0

func apply_building_output_modifiers(base_output: int, tick_count: int, building: Building) -> int:
	var output_amount: int = apply_worker_preference_output_modifier(base_output, tick_count, building)
	return apply_older_child_support_output_modifier(output_amount, tick_count, building)

func apply_worker_preference_output_modifier(base_output: int, tick_count: int, building: Building) -> int:
	var assigned_preference: String = get_household_preference_for_worker_modifier(building)
	var preferred_worker: String = get_preferred_worker_for_building(building.type)

	if assigned_preference == WORK_PREF_NEUTRAL:
		return base_output
	if assigned_preference == preferred_worker:
		if should_apply_preference_adjustment(base_output, tick_count):
			return base_output + 1
		return base_output
	if should_apply_preference_adjustment(base_output, tick_count):
		return max(0, base_output - 1)

	return base_output

func apply_older_child_support_output_modifier(output_amount: int, tick_count: int, building: Building) -> int:
	if output_amount <= 0:
		return output_amount
	if building.assigned_household_id < 0:
		return output_amount
	if tick_count % OLDER_CHILD_SUPPORT_TICK_INTERVAL != 0:
		return output_amount

	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return output_amount

	return output_amount + household.get_older_child_support_bonus()

func should_apply_preference_adjustment(base_output: int, tick_count: int) -> bool:
	if base_output >= 2:
		return tick_count % 2 == 0

	return tick_count % 4 == 0

func get_preferred_worker_for_building(building_type: String) -> String:
	if building_type == BUILDING_FARM:
		return WORK_PREF_AGRARIAN
	if building_type == BUILDING_WOODCUTTER or building_type == BUILDING_TOOLMAKER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_QUARRY:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_STONECUTTER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_BRICKWORKS:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_LIME_KILN:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_MORTAR_YARD:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_MASON_YARD:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_SCULPTOR:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_CARVER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_TILEWORKS:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_PAVER_YARD:
		return WORK_PREF_INDUSTRIAL

	return WORK_PREF_NEUTRAL

func update_population_from_external_pool():
	update_shelter_counts()
	if resources["food_shortage"] == true:
		resources["food_surplus_ticks"] = 0
		return
	if get_total_population() >= int(resources["housing_capacity"]):
		resources["food_surplus_ticks"] = 0
		return
	if int(resources["external_population_pool"]) <= 0:
		resources["food_surplus_ticks"] = 0
		return
	if int(resources["food"]) <= int(resources["food_consumption_rate"]):
		resources["food_surplus_ticks"] = 0
		return

	resources["food_surplus_ticks"] = int(resources["food_surplus_ticks"]) + 1
	if int(resources["food_surplus_ticks"]) < FOOD_SURPLUS_TICKS_FOR_GROWTH:
		return

	resources["food_surplus_ticks"] = 0
	add_population_from_external_pool()
	resources["external_population_pool"] = int(resources["external_population_pool"]) - 1
	update_shelter_counts()
	update_worker_counts()
	auto_assign_workers()

func count_housing_capacity() -> int:
	var capacity: int = 0

	for building: Building in buildings:
		if building.is_house():
			capacity += HOUSE_CAPACITY

	return capacity

func get_total_population() -> int:
	var total_population: int = 0

	for household: Household in households:
		total_population += household.total_population

	return total_population

func get_total_labor_capacity() -> int:
	var capacity: int = 0

	for household: Household in households:
		capacity += household.labor_capacity

	return capacity

func update_shelter_counts():
	assign_households_to_housing()
	var house_shelter_capacity: int = count_housing_capacity()
	var temporary_shelter_capacity: int = int(resources["temporary_shelter_capacity"])
	var total_shelter_capacity: int = house_shelter_capacity + temporary_shelter_capacity
	var total_population: int = get_total_population()
	var housed_population: int = get_population_by_residence(Household.RESIDENCE_HOUSED)
	var temporary_sheltered_population: int = get_population_by_residence(Household.RESIDENCE_TEMPORARY)
	var unsheltered_population: int = get_population_by_residence(Household.RESIDENCE_UNSHELTERED)

	for household: Household in households:
		household.update_labor_capacity()

	resources["house_shelter_capacity"] = house_shelter_capacity
	resources["housing_capacity"] = total_shelter_capacity
	resources["household_count"] = households.size()
	resources["total_population"] = total_population
	resources["total_labor_capacity"] = get_total_labor_capacity()
	resources["housed_population"] = housed_population
	resources["temporary_sheltered_population"] = temporary_sheltered_population
	resources["sheltered_population"] = housed_population + temporary_sheltered_population
	resources["unsheltered_population"] = unsheltered_population

func assign_households_to_housing():
	var open_house_ids: Array[int] = get_empty_house_building_ids()
	if open_house_ids.is_empty():
		return

	var candidates: Array[Household] = get_unhoused_households_by_size()
	for household: Household in candidates:
		if open_house_ids.is_empty():
			return

		var building_id: int = int(open_house_ids.pop_front())
		household.move_to_house(building_id)

func get_empty_house_building_ids() -> Array[int]:
	var result: Array[int] = []

	for building: Building in buildings:
		if not building.is_house():
			continue
		if get_household_for_building_id(building.id) == null:
			result.append(building.id)

	return result

func get_unhoused_households_by_size() -> Array[Household]:
	var result: Array[Household] = []

	for household: Household in households:
		if household.housing_status == Household.RESIDENCE_TEMPORARY or household.housing_status == Household.RESIDENCE_UNSHELTERED:
			result.append(household)

	sort_households_by_population_desc(result)
	return result

func sort_households_by_population_desc(household_list: Array[Household]):
	for outer_index in range(household_list.size()):
		for inner_index in range(outer_index + 1, household_list.size()):
			var outer_household: Household = household_list[outer_index]
			var inner_household: Household = household_list[inner_index]
			if inner_household.total_population > outer_household.total_population:
				household_list[outer_index] = inner_household
				household_list[inner_index] = outer_household

func get_population_by_residence(residence_status: String) -> int:
	var population: int = 0

	for household: Household in households:
		if household.housing_status == residence_status:
			population += household.total_population

	return population

func add_population_from_external_pool():
	var target: Household = get_growth_target_household()
	if target == null:
		var household_id: int = households.size()
		var household: Household = Household.new(household_id, -1, WORK_PREF_NEUTRAL, 1, Household.RESIDENCE_TEMPORARY)
		households.append(household)
		return

	target.add_external_population()

func auto_assign_workers():
	update_worker_counts()

	for building_index in range(buildings.size()):
		var building: Building = buildings[building_index]
		if not building.is_production_building():
			continue
		if building.assigned_workers > 0:
			continue
		if building.auto_assignment_blocked:
			continue

		var household: Household = find_auto_assignment_household(building)
		if household == null:
			continue

		building.assign_household(household, Building.ASSIGNMENT_AUTO)
		update_worker_counts()

func find_auto_assignment_household(building: Building) -> Household:
	var best_household: Household = null
	var best_score: int = -9999

	for household: Household in get_available_households():
		var available_workers: int = household.get_available_workers()
		if available_workers <= 0:
			continue

		var score: int = get_auto_assignment_score(household, building)
		if best_household == null or score > best_score:
			best_household = household
			best_score = score

	return best_household

func get_auto_assignment_score(household: Household, building: Building) -> int:
	var score: int = 0
	var match_quality: String = household.get_match_quality(building.type)

	if match_quality == "good match":
		score += 30
	elif match_quality == "neutral":
		score += 10
	else:
		score -= 10

	if household.housing_status == Household.RESIDENCE_HOUSED:
		score += 6
	elif household.housing_status == Household.RESIDENCE_TEMPORARY:
		score += 3

	score += household.get_available_workers() * 2
	score -= household.id
	return score

func get_growth_target_household() -> Household:
	for household: Household in households:
		if household.housing_status == Household.RESIDENCE_HOUSED and household.total_population < household.population_capacity:
			return household

	for household: Household in households:
		if household.housing_status == Household.RESIDENCE_TEMPORARY and household.total_population < household.population_capacity:
			return household

	return null

func update_building_maintenance(building: Building):
	var interval: int = building.get_maintenance_interval()
	var cost: int = building.get_maintenance_tool_cost()

	building.maintenance_timer += 1
	if building.maintenance_timer < interval:
		return

	building.maintenance_timer = 0
	if building.receives_maintenance and int(resources["tools"]) >= cost:
		resources["tools"] = int(resources["tools"]) - cost
		building.maintenance_level = min(100, building.maintenance_level + 25)
	else:
		building.maintenance_level = max(0, building.maintenance_level - 25)

func record_resource_history():
	resource_history.append({
		"food": int(resources["food"]),
		"wood": int(resources["wood"]),
		"tools": int(resources["tools"])
	})

	while resource_history.size() > RESOURCE_HISTORY_LIMIT:
		resource_history.pop_front()

func get_resource_trends() -> Dictionary:
	var result: Dictionary = {"food": 0.0, "wood": 0.0, "tools": 0.0}
	if resource_history.size() < 2:
		return result

	var first_sample: Dictionary = resource_history[0] as Dictionary
	var last_sample: Dictionary = resource_history[resource_history.size() - 1] as Dictionary
	var tick_span: float = float(resource_history.size() - 1)

	result["food"] = float(int(last_sample["food"]) - int(first_sample["food"])) / tick_span
	result["wood"] = float(int(last_sample["wood"]) - int(first_sample["wood"])) / tick_span
	result["tools"] = float(int(last_sample["tools"]) - int(first_sample["tools"])) / tick_span
	return result

func get_pressure_summary() -> Dictionary:
	update_shelter_counts()
	update_worker_counts()
	var trends: Dictionary = get_resource_trends()

	return {
		"food": get_food_pressure(float(trends["food"])),
		"shelter": get_shelter_pressure(),
		"labor": get_labor_pressure(),
		"tools": get_tool_pressure(float(trends["tools"])),
		"maintenance": get_maintenance_pressure()
	}

func make_pressure(status: String, severity: String, detail: String = "", values: Dictionary = {}) -> Dictionary:
	return {
		"status": status,
		"severity": severity,
		"detail": detail,
		"values": values
	}

func get_food_pressure(food_trend: float) -> Dictionary:
	var food: int = int(resources["food"])
	var consumption_rate: int = max(1, int(resources["food_consumption_rate"]))
	var days_of_food: float = float(food) / float(consumption_rate)
	var detail: String = get_food_pressure_detail(food, days_of_food, food_trend)
	var values: Dictionary = {
		"food": food,
		"consumption_rate": consumption_rate,
		"days_stored": days_of_food,
		"trend": food_trend
	}

	if resources["food_shortage"] == true or food <= 0:
		return make_pressure("Shortage", "danger", "Food empty; shortage penalty active", values)
	if food_trend < -0.25 and days_of_food < 8.0:
		return make_pressure("Declining", "warning", detail, values)
	if food_trend > 0.25 and days_of_food >= 4.0:
		return make_pressure("Surplus", "positive", detail, values)
	if days_of_food < 4.0:
		return make_pressure("Declining", "warning", detail, values)

	return make_pressure("Stable", "neutral", detail, values)

func get_shelter_pressure() -> Dictionary:
	var unsheltered_population: int = int(resources["unsheltered_population"])
	var temporary_population: int = int(resources["temporary_sheltered_population"])
	var housed_population: int = int(resources["housed_population"])
	var detail: String = str(housed_population) + " housed, " + str(temporary_population) + " temporary, " + str(unsheltered_population) + " unsheltered"
	var values: Dictionary = {
		"housed": housed_population,
		"temporary": temporary_population,
		"unsheltered": unsheltered_population
	}

	if unsheltered_population > 0:
		return make_pressure("Housing Shortage", "danger", str(unsheltered_population) + " people unsheltered", values)
	if temporary_population > 0:
		return make_pressure("Temporary Shelter", "warning", detail, values)

	return make_pressure("Stable", "positive", detail, values)

func get_labor_pressure() -> Dictionary:
	var total_labor_capacity: int = int(resources["total_labor_capacity"])
	var assigned_workers: int = int(resources["assigned_workers"])
	var idle_workers: int = int(resources["idle_workers"])
	var unassigned_jobs: int = count_unassigned_production_buildings()
	var production_buildings: int = get_production_building_count()
	var detail: String = str(assigned_workers) + "/" + str(total_labor_capacity) + " labor assigned, " + str(idle_workers) + " idle"
	var values: Dictionary = {
		"assigned": assigned_workers,
		"capacity": total_labor_capacity,
		"idle": idle_workers,
		"unassigned_jobs": unassigned_jobs,
		"production_buildings": production_buildings
	}

	if total_labor_capacity <= 0 and production_buildings > 0:
		return make_pressure("Labor Shortage", "danger", str(production_buildings) + " workplaces, no labor available", values)
	if unassigned_jobs > 0 and idle_workers <= 0:
		return make_pressure("Overextended", "danger", str(unassigned_jobs) + " production buildings unstaffed", values)
	if unassigned_jobs > 0:
		return make_pressure("Labor Shortage", "warning", str(unassigned_jobs) + " production buildings unstaffed", values)
	if idle_workers >= 2:
		return make_pressure("Idle Labor", "neutral", detail, values)
	if assigned_workers >= total_labor_capacity and total_labor_capacity > 0:
		return make_pressure("Balanced", "positive", detail, values)

	return make_pressure("Balanced", "neutral", detail, values)

func get_tool_pressure(tool_trend: float) -> Dictionary:
	var tools: int = int(resources["tools"])
	var maintenance_demand: int = get_maintenance_tool_demand_estimate()
	var critical_buildings: int = count_buildings_below_maintenance(50)
	var detail: String = str(tools) + " tools stored, upkeep demand " + str(maintenance_demand)
	var values: Dictionary = {
		"tools": tools,
		"trend": tool_trend,
		"maintenance_demand": maintenance_demand,
		"critical_buildings": critical_buildings
	}

	if tools <= 0 or critical_buildings > 0:
		return make_pressure("Upkeep Risk", "danger", "Tools empty or buildings degrading", values)
	if tools < max(3, maintenance_demand) or tool_trend < -0.25:
		return make_pressure("Low Tools", "warning", detail + ", trend " + format_signed_decimal(tool_trend) + "/day", values)

	return make_pressure("Stable", "positive", detail + ", trend " + format_signed_decimal(tool_trend) + "/day", values)

func get_maintenance_pressure() -> Dictionary:
	var disabled_count: int = count_disabled_maintenance_buildings()
	var critical_count: int = count_buildings_below_maintenance(50)
	var worn_count: int = count_buildings_below_maintenance(100)
	var values: Dictionary = {
		"disabled": disabled_count,
		"critical": critical_count,
		"worn": worn_count
	}

	if critical_count > 0:
		return make_pressure("Critical", "danger", str(critical_count) + " buildings below 50%", values)
	if worn_count > 0 or disabled_count > 0:
		return make_pressure("Worn", "warning", str(worn_count) + " below full, " + str(disabled_count) + " disabled", values)

	return make_pressure("Good", "positive", "All production buildings maintained", values)

func get_food_pressure_detail(food: int, days_of_food: float, food_trend: float) -> String:
	return str(food) + " food, " + format_decimal(days_of_food) + " days stored, trend " + format_signed_decimal(food_trend) + "/day"

func format_decimal(value: float) -> String:
	return str(snapped(value, 0.1))

func format_signed_decimal(value: float) -> String:
	var rounded_value: float = snapped(value, 0.1)
	if rounded_value > 0.0:
		return "+" + str(rounded_value)

	return str(rounded_value)

func get_production_building_count() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building():
			count += 1

	return count

func count_unassigned_production_buildings() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.assigned_workers <= 0:
			count += 1

	return count

func count_disabled_maintenance_buildings() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and not building.receives_maintenance:
			count += 1

	return count

func count_buildings_below_maintenance(threshold: int) -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.maintenance_level < threshold:
			count += 1

	return count

func get_maintenance_tool_demand_estimate() -> int:
	var demand: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.receives_maintenance:
			demand += building.get_maintenance_tool_cost()

	return demand

func can_transfer(resource_name: String, amount: int) -> bool:
	return int(resources[resource_name]) >= amount

func remove_resource(resource_name: String, amount: int):
	resources[resource_name] = int(resources[resource_name]) - amount

func add_resource(resource_name: String, amount: int):
	resources[resource_name] = int(resources[resource_name]) + amount

func can_afford_cost(cost: Dictionary) -> bool:
	for resource_name: String in cost.keys():
		if int(resources[resource_name]) < int(cost[resource_name]):
			return false

	return true

func pay_cost(cost: Dictionary):
	for resource_name: String in cost.keys():
		remove_resource(resource_name, int(cost[resource_name]))
