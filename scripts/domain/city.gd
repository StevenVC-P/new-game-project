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

func get_seeded_family_trade(preference: String, household_index: int) -> String:
	if preference == WORK_PREF_AGRARIAN:
		return "farming"
	if preference == WORK_PREF_INDUSTRIAL:
		if household_index % 2 == 0:
			return "woodcraft"
		return "stonework"

	return "general"

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

	target.total_population += 1
	target.update_labor_capacity()

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
