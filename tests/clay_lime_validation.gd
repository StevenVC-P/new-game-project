extends SceneTree

# Clay and limestone (sprint S5, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md): the town map lays clay on open
# ground by rivers and lakes (never the sea) and makes whole stone outcrops limestone, by place, the
# same each time; a brickworks must stand on clay and works it out like a quarry its stone; a lime
# kiln must stand near limestone; brick is a building material that lasts and keeps warm; brickmaking
# is a trade families choose where there is clay; the survey says what the land holds.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_the_map_lays_clay_and_limestone()
	test_brickworks_stand_on_clay()
	test_lime_kilns_stand_near_limestone()
	test_brick_as_a_material()
	test_families_make_bricks_where_there_is_clay()
	test_the_survey_tells_it()
	if failure_count > 0:
		push_error("Clay and lime validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Clay and lime validation passed.")
	quit()

# Open ground with a lake in the west, the sea in the east, and two stone outcrops.
func land() -> Array:
	var map: Array = HuntingTest.open_map([])
	for y in range(map.size()):
		for x in range((map[y] as Array).size()):
			var tile: Dictionary = map[y][x]
			tile["resource"] = "none"
			if x >= 4 and x < 10 and y >= 10 and y < 16:
				tile["type"] = "water"
				tile["water_kind"] = "lake"
			elif x >= 58:
				tile["type"] = "water"
				tile["water_kind"] = "sea"
			elif (x >= 20 and x < 25 and y >= 4 and y < 8) or (x >= 30 and x < 34 and y >= 30 and y < 34):
				tile["type"] = "rough"
				tile["resource"] = "stone"
	return map

func town(map: Array) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = map
	city.logistics.mark_layout_changed()
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func clay_tiles(map: Array) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(map.size()):
		for x in range((map[y] as Array).size()):
			if map[y][x]["resource"] == "clay":
				tiles.append(Vector2i(x, y))
	return tiles

func test_the_map_lays_clay_and_limestone() -> void:
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(64, 44)
	var map: Array = land()
	generator.add_clay_and_limestone(map, Vector2(100, 200))
	var clay: Array[Vector2i] = clay_tiles(map)
	_check(not clay.is_empty(), "clay lies by the lake (%d tiles)" % clay.size())
	_check(clay.all(func(t: Vector2i) -> bool: return t.x >= 2 and t.x < 12 and t.y >= 8 and t.y < 18), "and only near it, never by the sea")
	_check(clay.all(func(t: Vector2i) -> bool: return map[t.y][t.x]["type"] == "ground"), "on open ground")
	var bank: bool = true
	for y in range(9, 17):
		for x in [3, 10]:
			bank = bank and map[y][x]["resource"] == "clay"
	_check(bank, "the bank itself is clay all along")
	for outcrop: Rect2i in [Rect2i(20, 4, 5, 4), Rect2i(30, 30, 4, 4)]:
		var kinds: Dictionary = {}
		for y in range(outcrop.position.y, outcrop.end.y):
			for x in range(outcrop.position.x, outcrop.end.x):
				kinds[str(map[y][x].get("stone_kind", ""))] = true
		_check(kinds.size() == 1, "an outcrop is limestone or not as a whole: %s" % str(kinds.keys()))
	var again: Array = land()
	generator.add_clay_and_limestone(again, Vector2(100, 200))
	_check(again == map, "the same place lays the same clay and limestone")
	var limestone_somewhere: bool = false
	for i in range(40):
		var other: Array = land()
		generator.add_clay_and_limestone(other, Vector2(1000 * i, 37 * i))
		limestone_somewhere = limestone_somewhere or str(other[5][21].get("stone_kind", "")) == "limestone"
	_check(limestone_somewhere, "some places' outcrops are limestone")

func test_brickworks_stand_on_clay() -> void:
	var map: Array = land()
	LocalCityMapGenerator.new(64, 44).add_clay_and_limestone(map, Vector2(100, 200))
	var city: City = town(map)
	_check(city.construction.validate("brickworks", Vector2i(30, 20))["is_valid"] == false, "a brickworks away from the clay is refused")
	_check(city.construction.validate("brickworks", Vector2i(10, 12))["is_valid"] == true, "one on the lake's clay is allowed")
	var works: Building = Building.new(-1, "brickworks", Vector2i(10, 12), Vector2i(2, 2))
	city.add_building(works, city.households[0])
	var left: int = TownDeposits.get_left_under(city, works)
	for _day in range(60):
		city.apply_building_production(works)
	var made: int = int((city._flows.get("bricks", {}) as Dictionary).get("made", 0))
	_check(made > 0 and TownDeposits.get_left_under(city, works) == left - made, "every brick made took clay from the pit (%d)" % made)

func test_lime_kilns_stand_near_limestone() -> void:
	var map: Array = land()
	for y in range(4, 8):
		for x in range(20, 25):
			map[y][x]["stone_kind"] = "limestone"
	var city: City = town(map)
	_check(city.construction.validate("lime_kiln", Vector2i(26, 4))["is_valid"] == true, "a kiln beside limestone is allowed")
	_check(city.construction.validate("lime_kiln", Vector2i(36, 28))["is_valid"] == false, "one by stone that isn't limestone is refused")

func test_brick_as_a_material() -> void:
	var cost: Dictionary = EconomyBalance.get_build_cost("house", EconomyBalance.MATERIAL_BRICK)
	_check(int(cost["wood"]) == 2 and int(cost["bricks"]) == 4, "a brick house takes bricks for most of its wood: %s" % str(cost))
	var building: Building = Building.new(-1, "toolmaker", Vector2i(2, 2), Vector2i(3, 3))
	building.material = EconomyBalance.MATERIAL_BRICK
	_check(building.is_stone() and building.get_maintenance_interval() > Building.new(-1, "toolmaker").get_maintenance_interval(), "brick lasts like stone")
	var city: City = town(land())
	city.resources["bricks"] = 100
	var options: Array = MaterialChoice.choose(city, city.households[0], "house")["options"]
	_check(options.any(func(o: Dictionary) -> bool: return str(o["material"]) == EconomyBalance.MATERIAL_BRICK), "with bricks in store a family may build of brick")

func test_families_make_bricks_where_there_is_clay() -> void:
	var map: Array = land()
	LocalCityMapGenerator.new(64, 44).add_clay_and_limestone(map, Vector2(100, 200))
	var city: City = town(map)
	_check(FamilyInitiative.get_occupations(city).has("brickworks"), "brickmaking is among the trades families choose")
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, city.households[0], "brickworks")
	_check(bool(desire.get("available", true)) and desire.has("site") and TownDeposits.get_footprint_factor(map, desire["site"], Vector2i(2, 2), TownDeposits.CLAY) > 0.0, "a family can take it up on the clay: %s" % str(desire.get("site", "no site")))
	var dry: City = town(HuntingTest.open_map([]))
	_check(not bool(FamilyInitiative.get_work_desire(dry, dry.households[0], "brickworks").get("available", true)), "with no clay it can't")

func test_the_survey_tells_it() -> void:
	var map: Array = land()
	for y in range(4, 8):
		for x in range(20, 25):
			map[y][x]["stone_kind"] = "limestone"
	LocalCityMapGenerator.new(64, 44).add_clay_and_limestone(map, Vector2(100, 200))
	var lines: String = str(SiteSurvey.get_lines(map, null))
	_check(lines.contains("Clay:") and not lines.contains("Clay: none"), "the survey names the clay: %s" % lines)
	_check(lines.contains("limestone"), "and the limestone")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
