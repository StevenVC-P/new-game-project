extends SceneTree

# Terrain and woodland on the town map (docs/TOWN_BUILDING_MODEL.md, Terrain and Woodland):
# woods, hills, and rock slow travel and routes go around them; woodcutters fell the woods the
# player marks; felled land grows back from the woods' edge over years, unless people keep
# walking it or something is built on it.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_terrain_costs()
	test_routes_avoid_woods()
	test_woodcutters_clear_marked_woods()
	test_marking_toggles()
	test_only_woodcutters_fell()
	test_felled_land_grows_back_from_the_edge()
	test_paths_hold_the_land_open()
	test_built_land_stays_open()

	if failure_count > 0:
		push_error("Town woodland validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town woodland validation passed.")
	quit()

static func ground(extra: Dictionary = {}) -> Dictionary:
	var tile: Dictionary = {"type": "ground", "has_trees": false, "is_fertile": false, "occupied": false, "water_kind": "", "resource": "none", "has_road": false}
	tile.merge(extra, true)
	return tile

func test_terrain_costs() -> void:
	_check(is_equal_approx(TownLogistics.tile_effort(ground()), 1.0), "open ground costs 1")
	_check(is_equal_approx(TownLogistics.tile_effort(ground({"is_hill": true})), EconomyBalance.HILL_EFFORT), "hill land costs more")
	_check(is_equal_approx(TownLogistics.tile_effort(ground({"has_trees": true})), EconomyBalance.WOODS_EFFORT), "woods cost more")
	_check(is_equal_approx(TownLogistics.tile_effort(ground({"has_trees": true, "is_hill": true})), EconomyBalance.HILL_EFFORT * EconomyBalance.WOODS_EFFORT), "a wooded hillside costs both")
	_check(is_equal_approx(TownLogistics.tile_effort(ground({"type": "rough"})), EconomyBalance.ROUGH_EFFORT), "rock costs most")
	_check(is_inf(TownLogistics.tile_effort(ground({"type": "water"}))), "water cannot be crossed")
	_check(TownLogistics.tile_effort(ground({"has_trees": true, "path_level": TownLogistics.PATH_WORN})) < EconomyBalance.WOODS_EFFORT, "a path through woods is quicker than the woods")

# A short wood five tiles deep across the straight line: going around is quicker.
func test_routes_avoid_woods() -> void:
	var city: City = ConstructionTest.make_city()
	for y in range(20, 25):
		for x in range(30, 35):
			city.local_map[y][x]["has_trees"] = true
	city.logistics.mark_layout_changed()
	var route: Array[Vector2i] = city.logistics.find_route(Vector2i(28, 22), Vector2i(36, 22))
	var through_woods: int = 0
	for tile: Vector2i in route:
		through_woods += 1 if city.local_map[tile.y][tile.x]["has_trees"] == true else 0
	print("[WOOD] route past a small wood: %d tiles, %d of them wooded, effort %.1f" % [route.size(), through_woods, city.logistics.route_effort(route)])
	_check(route.size() > 0 and through_woods == 0, "the route should go around the woods")

func test_woodcutters_clear_marked_woods() -> void:
	var city: City = ConstructionTest.make_city()
	city.logistics.ensure_ready()
	city.add_building(Building.new(-1, "woodcutter", Vector2i(52, 20), Vector2i(2, 2)))
	var woodcutter: Building = city.buildings[0]
	_check(woodcutter.can_produce(), "the woodcutter should be worked")
	var marked: int = city.woodland.mark_block(Vector2i(56, 18), Vector2i(58, 22))
	_check(marked == 15, "every wooded tile in the block should be marked, got %d" % marked)
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).has("Woods to clear: 15 tiles"), "the sidebar should count the marked woods")
	var effort_before: float = city.logistics.effort_between(Vector2i(55, 20), Vector2i(59, 20))
	var wood_before: int = int(city.resources["wood"])
	ConstructionTest.run_days(city, 6)
	var first: Vector2i = Vector2i(56, 20)
	_check(city.local_map[first.y][first.x]["has_trees"] == false, "the woodcutter fells the marked woods nearest it first")
	_check(not city.woodland.is_marked(first) and city.woodland.regrowth.has(first), "a felled tile is no longer marked, and can grow back")
	_check(LocalCityMapGenerator.is_buildable(city.local_map[first.y][first.x]), "felled land is open ground")
	var days: int = 6
	while not city.woodland.marked.is_empty() and days < 120:
		city.tick()
		days += 1
	print("[WOOD] one woodcutter cleared 15 tiles in %d days; wood %d -> %d" % [days, wood_before, int(city.resources["wood"])])
	_check(city.woodland.marked.is_empty() and city.woodland.felled_count == 15, "the woodcutter should clear the whole block")
	_check(city.logistics.effort_between(Vector2i(55, 20), Vector2i(59, 20)) < effort_before, "cleared woods are quicker to cross")
	_check(int(city.resources["wood"]) > wood_before, "the woodcutter keeps producing wood while it clears")

func test_marking_toggles() -> void:
	var city: City = ConstructionTest.make_city()
	_check(city.woodland.mark_block(Vector2i(60, 5), Vector2i(61, 6)) == 4, "a 2x2 block of woods marks 4 tiles")
	_check(city.woodland.mark_block(Vector2i(61, 6), Vector2i(60, 5)) == 4 and city.woodland.marked.is_empty(), "marking an all-marked block again takes the marks off")
	_check(city.woodland.mark_block(Vector2i(20, 20), Vector2i(24, 24)) == 0, "open ground has nothing to mark")
	city.woodland.mark_block(Vector2i(56, 0), Vector2i(63, 43))
	_check(city.woodland.marked.size() == 8 * TownWoodland.MAX_MARK_SIDE, "one marking covers at most %d tiles a side" % TownWoodland.MAX_MARK_SIDE)

func test_only_woodcutters_fell() -> void:
	var city: City = ConstructionTest.make_city()
	city.logistics.ensure_ready()
	city.add_building(Building.new(-1, "gatherer_camp", Vector2i(52, 20), Vector2i(2, 2)))
	city.woodland.mark_block(Vector2i(56, 20), Vector2i(56, 20))
	ConstructionTest.run_days(city, 10)
	_check(city.woodland.felled_count == 0, "a gatherer's camp does not fell woods")
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).has("Woods to clear: 1 tile (needs a working woodcutter)"), "the sidebar says marked woods wait for a woodcutter")

# Day by day without anyone walking: logistics fades wear, woodland grows.
static func run_land_days(city: City, days: int, keep_worn: Dictionary = {}) -> void:
	for _day in range(days):
		for tile: Vector2i in keep_worn.keys():
			city.logistics.wear[tile] = float(keep_worn[tile])
		city.logistics.advance_day()
		city.woodland.advance_day()

static func days_until_wooded(city: City, tile: Vector2i, max_days: int) -> int:
	for day in range(1, max_days + 1):
		run_land_days(city, 1)
		if city.local_map[tile.y][tile.x]["has_trees"] == true:
			return day
	return -1

func test_felled_land_grows_back_from_the_edge() -> void:
	var city: City = ConstructionTest.make_city()
	# A 3x3 clearing two tiles into the woods: its middle has no woods beside it.
	for y in range(20, 23):
		for x in range(58, 61):
			city.woodland.fell(Vector2i(x, y))
	var middle: Vector2i = Vector2i(59, 21)
	var corner: Vector2i = Vector2i(58, 20)
	run_land_days(city, 100)
	_check(city.local_map[corner.y][corner.x].get("saplings", false) != true, "nothing shows after a hundred days")
	var saplings_day: int = -1
	for day in range(101, 900):
		run_land_days(city, 1)
		if city.local_map[corner.y][corner.x].get("saplings", false) == true:
			saplings_day = day
			break
	var corner_day: int = saplings_day + days_until_wooded(city, corner, 900)
	var middle_day: int = corner_day + days_until_wooded(city, middle, 1500)
	print("[WOOD] a 3x3 clearing in the woods: saplings on its corner by day %d, woods there by day %d, its middle by day %d" % [saplings_day, corner_day, middle_day])
	_check(saplings_day > 100 and corner_day > saplings_day, "felled land shows saplings before it is woods again")
	_check(corner_day > 300 and middle_day > corner_day, "woods take back a clearing from its edge inward, over years")
	_check(city.woodland.regrowth.is_empty() and city.woodland.regrown_count == 9, "the whole clearing should grow back")
	var meadow: Vector2i = Vector2i(40, 20)
	_check(city.local_map[meadow.y][meadow.x]["has_trees"] == false, "land that was never wooded stays open")

func test_paths_hold_the_land_open() -> void:
	var city: City = ConstructionTest.make_city()
	var tile: Vector2i = Vector2i(56, 30)
	city.woodland.fell(tile)
	run_land_days(city, 900, {tile: EconomyBalance.TRAIL_WEAR})
	_check(city.local_map[tile.y][tile.x]["has_trees"] == false and float(city.woodland.regrowth[tile]) == 0.0, "a trail in daily use holds felled land open")
	var regrown: int = days_until_wooded(city, tile, 1500)
	print("[WOOD] a trail at the woods' edge, abandoned, is woods again after %d days" % regrown)
	_check(regrown > 0, "once nobody walks it, the woods take the trail back")

func test_built_land_stays_open() -> void:
	var city: City = ConstructionTest.make_city()
	var tile: Vector2i = Vector2i(56, 34)
	city.woodland.fell(tile)
	city.local_map[tile.y][tile.x]["occupied"] = true
	run_land_days(city, 900)
	_check(city.local_map[tile.y][tile.x]["has_trees"] == false, "woods do not grow back over built or reserved land")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
