extends SceneTree

# Terrain and woodland on the town map (docs/TOWN_BUILDING_MODEL.md, Terrain and Woodland):
# woods, hills, and rock slow travel and routes go around them; woodcutters fell the woods the
# player marks; once a year woods spread onto open land beside them, more likely the more woods
# stand within three steps, never past a cap, never onto land something else holds, and all
# at once from the year's starting woods.

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
	test_single_wooded_tile()
	test_compact_forest()
	test_narrow_forest()
	test_far_woods_add_nothing()
	test_boundary_blocking()
	test_influence_cap()
	test_simultaneous_annual_update()
	test_lone_tile_spreads_slowly_and_irregularly()
	test_spreads_once_a_year_in_play()
	test_loaded_town_spreads_the_same()

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
	_check(not city.woodland.is_marked(first) and city.woodland.get_spread_candidates().has(first), "a felled tile is no longer marked, and woods may take it back")
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

# --- Spreading ---------------------------------------------------------------------------------

# A town on bare open ground, with woods only where a test plants them.
static func make_open_city() -> City:
	var city: City = ConstructionTest.make_city()
	for row: Array in city.local_map:
		for tile: Dictionary in row:
			tile["type"] = "ground"
			tile["water_kind"] = ""
			tile["has_trees"] = false
	return city

static func plant(city: City, tiles: Array[Vector2i]) -> void:
	for tile: Vector2i in tiles:
		city.local_map[tile.y][tile.x]["has_trees"] = true
	city.woodland.forget_frontier()

static func block(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	return TownLogistics.footprint(origin, size)

static func expected_spread(city: City) -> float:
	var total: float = 0.0
	for tile: Vector2i in city.woodland.get_spread_candidates():
		total += city.woodland.get_spread_chance(tile)
	return total

static func always(value: float) -> Callable:
	return func() -> float: return value

func test_single_wooded_tile() -> void:
	var city: City = make_open_city()
	plant(city, [Vector2i(30, 20)])
	var candidates: Array[Vector2i] = city.woodland.get_spread_candidates()
	var sides: Array[Vector2i] = [Vector2i(30, 19), Vector2i(29, 20), Vector2i(31, 20), Vector2i(30, 21)]
	_check(candidates == sides, "a lone wooded tile can spread to its four sides, not its corners: " + str(candidates))
	_check(is_equal_approx(city.woodland.get_forest_influence(Vector2i(31, 20)), 1.0), "a side neighbour adds influence 1")
	_check(is_equal_approx(city.woodland.get_spread_chance(Vector2i(31, 20)), EconomyBalance.FOREST_SPREAD_BASE_CHANCE), "beside a lone wooded tile the chance is the base chance")
	_check(is_equal_approx(city.woodland.get_forest_influence(Vector2i(31, 21)), 0.5) and is_equal_approx(city.woodland.get_forest_influence(Vector2i(32, 21)), 0.25), "a corner adds 0.5, three steps 0.25")

func test_compact_forest() -> void:
	var single: City = make_open_city()
	plant(single, [Vector2i(30, 20)])
	var compact: City = make_open_city()
	plant(compact, block(Vector2i(28, 18), Vector2i(5, 5)))
	var edge_influence: float = compact.woodland.get_forest_influence(Vector2i(30, 17))
	var edge_chance: float = compact.woodland.get_spread_chance(Vector2i(30, 17))
	print("[WOOD] 5x5 forest: %d candidates, edge-middle influence %.2f, chance %.4f; expected tiles a year %.3f (one tile: %.3f)" % [compact.woodland.get_spread_candidates().size(), edge_influence, edge_chance, expected_spread(compact), expected_spread(single)])
	_check(compact.woodland.get_spread_candidates().size() == 20, "a 5x5 forest has 20 tiles on its sides")
	_check(is_equal_approx(edge_influence, 3.75), "the middle of a 5x5 edge feels 1 + 3 x 0.5 + 5 x 0.25")
	_check(edge_chance > EconomyBalance.FOREST_SPREAD_BASE_CHANCE and edge_chance < EconomyBalance.FOREST_SPREAD_MAX_CHANCE, "forest mass behind an edge raises its chance, under the cap")
	_check(expected_spread(compact) > expected_spread(single) * 5.0, "a larger forest spreads faster in all")
	_check(compact.woodland.get_spread_chance(Vector2i(28, 17)) < edge_chance, "an edge's corner feels less forest than its middle")

func test_narrow_forest() -> void:
	var narrow: City = make_open_city()
	plant(narrow, block(Vector2i(26, 20), Vector2i(9, 1)))
	var side: Vector2i = Vector2i(30, 19)
	var influence: float = narrow.woodland.get_forest_influence(side)
	var longer: City = make_open_city()
	plant(longer, block(Vector2i(20, 20), Vector2i(21, 1)))
	var compact: City = make_open_city()
	plant(compact, block(Vector2i(28, 18), Vector2i(5, 5)))
	print("[WOOD] a 9-tile line: side influence %.2f, chance %.4f, expected tiles a year %.3f" % [influence, narrow.woodland.get_spread_chance(side), expected_spread(narrow)])
	_check(is_equal_approx(influence, 2.5), "beside a line of woods: 1 + 2 x 0.5 + 2 x 0.25")
	_check(is_equal_approx(longer.woodland.get_forest_influence(side), influence), "a longer line adds nothing beyond three steps")
	_check(influence < compact.woodland.get_forest_influence(Vector2i(30, 17)), "a narrow forest pushes its sides less than a compact one its edges")
	_check(narrow.woodland.get_spread_candidates().size() == 20, "a 9x1 line has 18 sides and 2 ends")

# Forest size alone gives no bonus: a big forest four steps away adds nothing.
func test_far_woods_add_nothing() -> void:
	var city: City = make_open_city()
	plant(city, [Vector2i(20, 20)])
	plant(city, block(Vector2i(24, 10), Vector2i(20, 20)))
	_check(is_equal_approx(city.woodland.get_forest_influence(Vector2i(19, 20)), 1.0), "a big forest beyond three steps adds nothing to a tile beside a lone tree")
	_check(is_equal_approx(city.woodland.get_spread_chance(Vector2i(19, 20)), EconomyBalance.FOREST_SPREAD_BASE_CHANCE), "so its chance stays the base chance")

# Woods take only land nothing holds; uncultivated farmland they may take.
func test_boundary_blocking() -> void:
	var city: City = make_open_city()
	plant(city, [Vector2i(30, 20), Vector2i(40, 20)])
	var water: Vector2i = Vector2i(30, 19)
	var field: Vector2i = Vector2i(29, 20)
	var road: Vector2i = Vector2i(31, 20)
	var trail: Vector2i = Vector2i(30, 21)
	var rock: Vector2i = Vector2i(40, 19)
	var farmland: Vector2i = Vector2i(39, 20)
	city.local_map[water.y][water.x]["type"] = "water"
	city.local_map[field.y][field.x]["occupied"] = true
	city.local_map[road.y][road.x]["has_road"] = true
	city.local_map[trail.y][trail.x]["path_level"] = TownLogistics.PATH_TRAIL
	city.local_map[rock.y][rock.x]["type"] = "rough"
	city.local_map[farmland.y][farmland.x]["is_fertile"] = true
	var grown: Array[Vector2i] = city.woodland.spread_forest(always(0.0))
	for blocked: Vector2i in [water, field, road, trail, rock]:
		_check(city.local_map[blocked.y][blocked.x]["has_trees"] == false, "woods should not take %s" % str(blocked))
	_check(grown.has(farmland), "woods may take fertile land nobody farms")
	_check(grown.size() == 3, "only the open tiles should become woods, got " + str(grown))
	# A trail nobody walks fades, and then the woods may take it.
	city.local_map[trail.y][trail.x]["path_level"] = TownLogistics.PATH_NONE
	_check(city.woodland.spread_forest(always(0.0)).has(trail), "an abandoned path is open land again")

func test_influence_cap() -> void:
	var previous: float = 0.0
	for influence: float in [0.25, 1.0, 2.0, 5.0, 11.0, 50.0, 1000.0]:
		var chance: float = TownWoodland.get_spread_chance_for(influence)
		_check(chance > previous and chance <= EconomyBalance.FOREST_SPREAD_MAX_CHANCE, "the chance rises with influence and never passes the cap (%.2f -> %.5f)" % [influence, chance])
		previous = chance
	_check(TownWoodland.get_spread_chance_for(1000.0) > EconomyBalance.FOREST_SPREAD_MAX_CHANCE * 0.999, "with overwhelming influence the chance approaches the cap")
	_check(TownWoodland.get_spread_chance_for(0.0) == 0.0, "no woods in reach, no chance")
	# The most a tile can feel: woods all around within three steps.
	var city: City = make_open_city()
	plant(city, block(Vector2i(27, 17), Vector2i(7, 7)))
	city.woodland.fell(Vector2i(30, 20))
	var ringed: float = city.woodland.get_forest_influence(Vector2i(30, 20))
	print("[WOOD] a tile ringed by woods: influence %.2f, chance %.4f" % [ringed, city.woodland.get_spread_chance(Vector2i(30, 20))])
	_check(is_equal_approx(ringed, 11.0), "ringed by woods: 4 + 8 x 0.5 + 12 x 0.25")
	_check(city.woodland.get_spread_chance(Vector2i(30, 20)) < EconomyBalance.FOREST_SPREAD_MAX_CHANCE, "even ringed by woods, under the cap")

# Every candidate judges the year's starting woods: woods never spread twice in a year.
func test_simultaneous_annual_update() -> void:
	var city: City = make_open_city()
	plant(city, [Vector2i(30, 20), Vector2i(34, 20)])
	var grown: Array[Vector2i] = city.woodland.spread_forest(always(0.0))
	_check(grown.size() == 8, "with every draw a success, exactly the 8 sides grow, got %d" % grown.size())
	_check(city.local_map[20][32]["has_trees"] == false, "a tile two steps out stays open this year, though its neighbours just became woods")
	_check(city.local_map[21][31]["has_trees"] == false, "corners stay open: they were not beside woods when the year began")
	var second: Array[Vector2i] = city.woodland.spread_forest(always(0.0))
	_check(second.has(Vector2i(32, 20)), "the next year the two patches meet")
	# Chances are the year's starting chances, not ones raised by woods won earlier in the pass:
	# a column of woods; its top end wins first, and the next candidate (a corner away from the
	# top end) draws just above its starting chance, which the top end's woods would have beaten.
	var check: City = make_open_city()
	plant(check, block(Vector2i(30, 20), Vector2i(1, 3)))
	var candidates: Array[Vector2i] = check.woodland.get_spread_candidates()
	_check(candidates[0] == Vector2i(30, 19) and candidates[1] == Vector2i(29, 20), "candidates draw in row order")
	var starting: float = check.woodland.get_spread_chance(Vector2i(29, 20))
	var draws: Array[float] = [0.0, starting + 0.0001]
	var raised: float = TownWoodland.get_spread_chance_for(check.woodland.get_forest_influence(Vector2i(29, 20)) + 0.5)
	_check(raised > starting + 0.0001, "the top end's woods would have raised the next chance")
	var next: Array[int] = [0]
	var grown_check: Array[Vector2i] = check.woodland.spread_forest(func() -> float:
		next[0] += 1
		return draws[next[0] - 1] if next[0] <= draws.size() else 1.0)
	var top_only: Array[Vector2i] = [Vector2i(30, 19)]
	_check(grown_check == top_only, "only the first draw wins: the pass judges the starting woods, got " + str(grown_check))

func test_lone_tile_spreads_slowly_and_irregularly() -> void:
	var city: City = make_open_city()
	plant(city, [Vector2i(30, 20)])
	var sizes: Array[int] = []
	for year in range(1, 101):
		var rng: RandomNumberGenerator = city.woodland.make_spread_rng(year)
		city.woodland.spread_forest(func() -> float: return rng.randf())
		if year % 25 == 0:
			sizes.append(1 + city.woodland.spread_count)
	var rect: Rect2i = Rect2i(Vector2i(30, 20), Vector2i.ONE)
	for y in range(44):
		for x in range(64):
			if city.local_map[y][x]["has_trees"] == true:
				rect = rect.expand(Vector2i(x, y))
	var wooded: int = 1 + city.woodland.spread_count
	print("[WOOD] a lone wooded tile over 100 years: %s tiles at 25-year steps, bounding box %dx%d" % [str(sizes), rect.size.x + 1, rect.size.y + 1])
	_check(sizes[0] < sizes[3], "a lone wooded tile slowly spreads")
	_check(wooded < (rect.size.x + 1) * (rect.size.y + 1), "the spread is irregular, not a filled block")

func test_spreads_once_a_year_in_play() -> void:
	var city: City = ConstructionTest.make_city()
	ConstructionTest.run_days(city, Calendar.DAYS_PER_YEAR - 1)
	_check(city.woodland.spread_years == 0, "woods do not spread before the year is out")
	var version: int = city.woodland.land_version
	ConstructionTest.run_days(city, 1)
	_check(city.woodland.spread_years == 1, "woods spread once a year")
	print("[WOOD] the test town's first year: %d tiles became woods" % city.woodland.spread_count)
	_check(city.woodland.spread_count == 0 or city.woodland.land_version > version, "views are told when woods spread")

# A loaded town finds its frontier again and draws the same numbers, so it spreads the same.
func test_loaded_town_spreads_the_same() -> void:
	var city: City = ConstructionTest.make_city()
	# The original keeps its frontier up as woods are felled; the loaded town finds it afresh.
	city.woodland.spread_forest(always(1.0))
	city.woodland.fell(Vector2i(57, 20))
	city.woodland.fell(Vector2i(58, 21))
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	var rng_a: RandomNumberGenerator = city.woodland.make_spread_rng(7)
	var rng_b: RandomNumberGenerator = loaded.woodland.make_spread_rng(7)
	var grown_a: Array[Vector2i] = city.woodland.spread_forest(func() -> float: return rng_a.randf())
	var grown_b: Array[Vector2i] = loaded.woodland.spread_forest(func() -> float: return rng_b.randf())
	_check(grown_a == grown_b, "a loaded town should spread exactly as the original: %s vs %s" % [str(grown_a), str(grown_b)])

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
