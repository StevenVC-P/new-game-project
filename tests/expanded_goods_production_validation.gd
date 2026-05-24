extends RefCounted

var failure_count: int = 0

func run_all() -> void:
	test_existing_producers_still_work()
	test_quarry_outputs_stone_blocks()
	test_stonecutter_consumes_stone_blocks_and_outputs_cut_stone()
	test_brickworks_consumes_wood_and_outputs_bricks()
	test_lime_kiln_consumes_stone_blocks_and_wood_and_outputs_lime()
	test_mortar_yard_consumes_lime_and_stone_blocks_and_outputs_mortar()
	test_mason_yard_consumes_cut_stone_and_mortar_and_outputs_masonry()
	test_sculptor_consumes_cut_stone_and_tools_and_outputs_statues()
	test_carver_consumes_wood_and_tools_and_outputs_carved_goods()
	test_tileworks_consumes_bricks_and_wood_and_outputs_tiles()
	test_paver_yard_consumes_stone_blocks_and_outputs_paving_stones()
	test_insufficient_inputs_skip_without_negative_resources()

func test_existing_producers_still_work() -> void:
	var city: City = _make_city()
	var farm: Building = _make_working_building(Building.BUILDING_FARM)
	var woodcutter: Building = _make_working_building(Building.BUILDING_WOODCUTTER)
	var toolmaker: Building = _make_working_building(Building.BUILDING_TOOLMAKER)

	var start_food: int = int(city.resources["food"])
	var start_wood: int = int(city.resources["wood"])
	var start_tools: int = int(city.resources["tools"])

	city.apply_building_production(farm)
	city.apply_building_production(woodcutter)
	city.apply_building_production(toolmaker)

	_check(int(city.resources["food"]) == start_food + City.FARM_BASE_OUTPUT, "farm should still produce food")
	_check(int(city.resources["wood"]) == start_wood + City.WOODCUTTER_BASE_OUTPUT - City.TOOLMAKER_WOOD_INPUT, "woodcutter/toolmaker wood behavior should remain stable")
	_check(int(city.resources["tools"]) == start_tools + City.TOOLMAKER_BASE_OUTPUT, "toolmaker should still produce tools")

func test_quarry_outputs_stone_blocks() -> void:
	var city: City = _make_city()
	var building: Building = _make_working_building(Building.BUILDING_QUARRY)

	city.apply_building_production(building)

	_check(int(city.resources["stone_blocks"]) == 1, "quarry should produce stone_blocks")

func test_stonecutter_consumes_stone_blocks_and_outputs_cut_stone() -> void:
	_assert_chain(Building.BUILDING_STONECUTTER, {"stone_blocks": 2}, "cut_stone")

func test_brickworks_consumes_wood_and_outputs_bricks() -> void:
	_assert_chain(Building.BUILDING_BRICKWORKS, {"wood": 2}, "bricks")

func test_lime_kiln_consumes_stone_blocks_and_wood_and_outputs_lime() -> void:
	_assert_chain(Building.BUILDING_LIME_KILN, {"stone_blocks": 2, "wood": 2}, "lime")

func test_mortar_yard_consumes_lime_and_stone_blocks_and_outputs_mortar() -> void:
	_assert_chain(Building.BUILDING_MORTAR_YARD, {"lime": 2, "stone_blocks": 2}, "mortar")

func test_mason_yard_consumes_cut_stone_and_mortar_and_outputs_masonry() -> void:
	_assert_chain(Building.BUILDING_MASON_YARD, {"cut_stone": 2, "mortar": 2}, "masonry")

func test_sculptor_consumes_cut_stone_and_tools_and_outputs_statues() -> void:
	_assert_chain(Building.BUILDING_SCULPTOR, {"cut_stone": 2, "tools": 2}, "statues")

func test_carver_consumes_wood_and_tools_and_outputs_carved_goods() -> void:
	_assert_chain(Building.BUILDING_CARVER, {"wood": 2, "tools": 2}, "carved_goods")

func test_tileworks_consumes_bricks_and_wood_and_outputs_tiles() -> void:
	_assert_chain(Building.BUILDING_TILEWORKS, {"bricks": 2, "wood": 2}, "tiles")

func test_paver_yard_consumes_stone_blocks_and_outputs_paving_stones() -> void:
	_assert_chain(Building.BUILDING_PAVER_YARD, {"stone_blocks": 2}, "paving_stones")

func test_insufficient_inputs_skip_without_negative_resources() -> void:
	var city: City = _make_city()
	var building: Building = _make_working_building(Building.BUILDING_MASON_YARD)
	city.resources["cut_stone"] = 1
	city.resources["mortar"] = 0

	city.apply_building_production(building)

	_check(int(city.resources["cut_stone"]) == 1, "insufficient inputs should not consume partial cut_stone")
	_check(int(city.resources["mortar"]) == 0, "insufficient inputs should not make mortar negative")
	_check(int(city.resources["masonry"]) == 0, "insufficient inputs should not produce masonry")

func _assert_chain(building_type: String, input_values: Dictionary, output_key: String) -> void:
	var city: City = _make_city()
	var building: Building = _make_working_building(building_type)
	var before_inputs: Dictionary = {}

	for input_key: String in input_values.keys():
		city.resources[input_key] = int(input_values[input_key])
		before_inputs[input_key] = int(city.resources[input_key])

	city.apply_building_production(building)

	_check(int(city.resources[output_key]) == 1, building_type + " should produce " + output_key)
	for input_key: String in input_values.keys():
		_check(int(city.resources[input_key]) == int(before_inputs[input_key]) - 1, building_type + " should consume " + input_key)
		_check(int(city.resources[input_key]) >= 0, building_type + " should not make " + input_key + " negative")

func _make_city() -> City:
	var city: City = City.new("Test City")
	city.resources["food_shortage"] = false
	city.resources["production_tick_count"] = 0
	return city

func _make_working_building(building_type: String) -> Building:
	var building: Building = Building.new(-1, building_type)
	building.assigned_workers = 1
	building.maintenance_level = 100
	return building

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
