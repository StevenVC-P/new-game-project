extends SceneTree

# Settlement stages and the chronicle (docs/FIRST_STAGE_LOOP.md, milestone 6;
# docs/SETTLEMENT_GROWTH_SCALE_MODEL.md): Founding Camp until every family is housed, Hamlet until
# ten households, a family formed here, a stable season, and a winter survived, then Village.
# Titles never drop back; a shrunken village is shown as declining. Firsts go in the chronicle.
# A herder's fold grazes open land (hills best) and its wool, spun at home, clothes the town.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_camp_to_village()
	test_chronicle_records_events()
	test_wool_clothes_the_town()

	if failure_count > 0:
		push_error("Settlement stage validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Settlement stage validation passed.")
	quit()

func house_everyone(city: City) -> void:
	var x: int = 26
	for household: Household in city.households:
		if household.housing_status != Household.RESIDENCE_HOUSED:
			city.add_building(Building.new(-1, "house", Vector2i(x, 20), Vector2i.ONE), household)
			x += 2

func run_year(city: City) -> void:
	for day in range(1, Calendar.DAYS_PER_YEAR + 1):
		city.day_of_year = day
		city.resources["food"] = 5000
		city.tick()

func test_camp_to_village() -> void:
	var city: City = ConstructionTest.make_city()
	city.day_of_year = 1
	city.tick()
	_check(city.settlement.stage == SettlementStage.CAMP, "a new town is a founding camp")
	_check(city.settlement.get_display_lines()[0].begins_with("Founding Camp"), "the sidebar names the stage")
	house_everyone(city)
	city.tick()
	_check(city.settlement.stage == SettlementStage.HAMLET, "with every family housed, it is a hamlet")
	_check(city.settlement.recorded.has("housed"), "the chronicle records every family housed")
	run_year(city)
	city.day_of_year = 1
	city.tick()
	_check(city.settlement.winters_survived == 1 and city.settlement.stable_seasons >= 1, "a winter survived and stable seasons counted: %d winters, %d stable" % [city.settlement.winters_survived, city.settlement.stable_seasons])
	_check(city.settlement.stage == SettlementStage.HAMLET, "too few households for a village yet")
	_check(city.settlement.get_display_lines().any(func(line: String) -> bool: return line.contains("[x] winter") and line.contains("[ ] households")), "the sidebar shows what is met and what is not: %s" % str(city.settlement.get_display_lines()))
	# Ten households, one formed here.
	while city.households.size() < SettlementStage.VILLAGE_HOUSEHOLDS:
		var household: Household = Household.new(city.households.size() + 100)
		city.households.append(household)
	city.households[-1].generation = 1
	house_everyone(city)
	city.tick()
	_check(city.settlement.stage == SettlementStage.VILLAGE, "ten households, one formed here, a stable season, and a winter: a village")
	_check(city.settlement.recorded.has("stage_2") and city.settlement.recorded.has("new_family"), "the chronicle records the village and the first family formed here")
	# Titles never drop back.
	city.households.resize(5)
	city.tick()
	_check(city.settlement.stage == SettlementStage.VILLAGE and city.settlement.get_display_lines()[0].begins_with("A declining village"), "a shrunken village keeps its title and shows its decline")
	# Saved and restored.
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.settlement.stage == SettlementStage.VILLAGE and restored.settlement.chronicle.size() == city.settlement.chronicle.size(), "the stage and chronicle are saved")

func test_chronicle_records_events() -> void:
	var city: City = ConstructionTest.make_city()
	city.trade.first_trade_day = 5
	city.trade.partner_name = "Callow Ford"
	city.defense.raids = 2
	city.defense.raids_driven_off = 1
	city.settlement.advance_day()
	var texts: Array = city.settlement.chronicle.map(func(entry: Dictionary) -> String: return entry["text"])
	_check(texts.has("The first trade, with Callow Ford") and texts.has("Bandits driven off") and texts.has("Bandits raided the stores"), "trade and raids go in the chronicle: %s" % str(texts))
	city.settlement.advance_day()
	_check(city.settlement.chronicle.size() == texts.size(), "each first is written once")
	_check(city.settlement.get_chronicle_lines()[0].begins_with("Year 1, "), "entries are dated from the founding")

func test_wool_clothes_the_town() -> void:
	var city: City = ConstructionTest.make_city()
	_check(city.get_clothing_need_demand() == 1, "a founding town needs a garment a day, not one per person: %d" % city.get_clothing_need_demand())
	_check(city.construction.get_size(Building.BUILDING_HERDER) == Vector2i(3, 3), "a fold is a pasture of three by three")
	var spot: Vector2i = Vector2i(30, 18)
	_check(city.construction.validate(Building.BUILDING_HERDER, spot)["is_valid"] == true, "a fold can stand on open ground")
	var open_factor: float = city.land.get_reach_factor_at(Building.BUILDING_HERDER, spot, Vector2i(3, 3))
	for y in range(spot.y - 3, spot.y + 6):
		for x in range(spot.x - 3, spot.x + 6):
			city.local_map[y][x]["is_hill"] = true
	var hill_factor: float = city.land.get_reach_factor_at(Building.BUILDING_HERDER, spot, Vector2i(3, 3))
	print("[WOOL] a fold's grazing: %.0f%% on open land, %.0f%% on hill pasture" % [open_factor * 100.0, hill_factor * 100.0])
	_check(hill_factor > open_factor, "hill pasture grazes better than open land")
	city.add_building(Building.new(-1, Building.BUILDING_HERDER, spot, Vector2i(3, 3)), city.households[0])
	city.resources["tools"] = 500
	var wool_made: int = 0
	for day in range(1, 61):
		city.day_of_year = 120
		var before: int = int(city.resources["wool"])
		city.tick()
		wool_made += maxi(0, int(city.resources["wool"]) - before)
	var clothing: Dictionary = city.soft_need_results.get(GoodsNeedBucketHelper.BUCKET_CLOTHING, {})
	_check(str(clothing.get("status", "")) == "met", "wool from the fold meets the clothing need: %s" % str(clothing))
	# Wolves at the woods' edge in winter, unless the fold is fenced.
	var edge: City = ConstructionTest.make_city()
	edge.add_building(Building.new(-1, Building.BUILDING_HERDER, Vector2i(52, 20), Vector2i(3, 3)), edge.households[0])
	edge.day_of_year = 300
	_check(edge.land.is_wolf_exposed(edge.buildings[0]), "wolves threaten a fold at the woods' edge")
	edge.buildings[0].fenced = true
	_check(not edge.land.is_wolf_exposed(edge.buildings[0]), "a fence keeps them from the flock")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
