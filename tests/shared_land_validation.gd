extends SceneTree

# Shared fishing water and pasture (docs/AUTONOMOUS_OCCUPATIONS.md, sixth round, owner 2026-11-02).
# Before, each fisher's hut counted all the water in its reach and each herder's fold all the
# pasture, however many others worked the same water or land: what they brought in was counted
# twice, as woods were for hunting lodges (tests/hunting_grounds_validation.gd). Now every tile is
# divided among the workplaces of its kind whose reach holds it (TownLand.count_share), in what they
# bring in and in what families expect. For each kind: uncontested, the same land, partial overlap,
# separate land, the shares never adding up to more than the land, families' judgement, and the old
# counting behind its comparison meta. Production rates are unchanged.

const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const ConstructionTest = preload("res://tests/town_construction_validation.gd")

# A lake of 12 tiles: a full catch for one hut beside it.
const LAKE: Rect2i = Rect2i(20, 14, 4, 3)
const HUT: Vector2i = Vector2i(21, 17)
const FOLD: Vector2i = Vector2i(20, 20)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_water_uncontested()
	test_water_same()
	test_water_overlapping()
	test_water_apart()
	test_pasture_uncontested()
	test_pasture_same()
	test_pasture_overlapping()
	test_pasture_apart()
	test_hill_pasture_shared()
	test_never_more_than_the_land()
	test_families_judge_shared_land()
	test_kinds_do_not_compete()
	if failure_count > 0:
		push_error("Shared land validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Shared land validation passed.")
	quit()

# Open ground (no trees, farmland or water), with water where asked.
func town(water: Array[Rect2i] = []) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map([])
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			if water.any(func(r: Rect2i) -> bool: return r.has_point(Vector2i(x, y))):
				city.local_map[y][x]["type"] = "water"
				city.local_map[y][x]["water_kind"] = "lake"
	city.logistics.mark_layout_changed()
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func kind_of(building: Building) -> String:
	return TownLand.get_reach_kind(building.type)

func share(city: City, building: Building) -> float:
	return city.land.count_share(kind_of(building), building.tile, building.size, city.land.get_rival_reaches(building.type, building.tile, false))

func alone(city: City, building: Building) -> float:
	return float(city.land.count_near(building.tile, building.size, TownLand.get_reach_distance(kind_of(building)), kind_of(building)))

# What the land in the reaches of these workplaces is worth, each tile once.
func land_worth(city: City, buildings: Array[Building]) -> float:
	var total: float = 0.0
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			for building: Building in buildings:
				if TownLand.get_reach_rect(building.type, building.tile, building.size).has_point(Vector2i(x, y)):
					total += TownLand.get_tile_worth(city.local_map[y][x], kind_of(building))
					break
	return total

# --- Fishing water -------------------------------------------------------------------------------

func test_water_uncontested() -> void:
	var city: City = town([LAKE])
	var hut: Building = give(city, city.households[0], "fisher", HUT)
	_check(share(city, hut) == 12.0 and city.land.get_reach_factor(hut) == 1.0, "a hut alone counts the whole lake (%.1f): a full catch" % share(city, hut))

func test_water_same() -> void:
	var city: City = town([LAKE])
	var a: Building = give(city, city.households[0], "fisher", HUT)
	var before: float = city.land.get_output_factor(a)
	var b: Building = give(city, city.households[1], "fisher", HUT + Vector2i(1, 0))
	_check(share(city, a) == 6.0 and share(city, b) == 6.0, "two huts on the same lake take half each (%.1f, %.1f)" % [share(city, a), share(city, b)])
	_check(is_equal_approx(city.land.get_reach_factor(a), 0.5) and is_equal_approx(city.land.get_output_factor(a), before * 0.5), "so each brings in half a catch, in real output too (%.2f -> %.2f)" % [before, city.land.get_output_factor(a)])
	city.set_meta("water_not_shared", true)
	_check(city.land.get_reach_factor(a) == 1.0 and city.land.get_reach_factor(b) == 1.0, "before the fix (meta water_not_shared) each caught the whole lake's fish")
	city.remove_meta("water_not_shared")

func test_water_overlapping() -> void:
	var city: City = town([LAKE])
	var a: Building = give(city, city.households[0], "fisher", HUT)
	var c: Building = give(city, city.households[1], "fisher", HUT + Vector2i(5, 0))
	var expected_a: float = alone(city, a) - 0.5 * (alone(city, a) + alone(city, c) - land_worth(city, [a, c]))
	_check(is_equal_approx(share(city, a), expected_a) and share(city, a) < alone(city, a) and share(city, a) > alone(city, a) * 0.5, "partly overlapping reaches halve only the overlap (%.1f of %.0f)" % [share(city, a), alone(city, a)])

func test_water_apart() -> void:
	var city: City = town([LAKE, Rect2i(LAKE.position + Vector2i(20, 0), LAKE.size)])
	var a: Building = give(city, city.households[0], "fisher", HUT)
	var d: Building = give(city, city.households[1], "fisher", HUT + Vector2i(20, 0))
	_check(share(city, a) == 12.0 and share(city, d) == 12.0, "huts on separate lakes keep their own (%.1f, %.1f)" % [share(city, a), share(city, d)])

# --- Pasture -------------------------------------------------------------------------------------

func test_pasture_uncontested() -> void:
	var city: City = town()
	var fold: Building = give(city, city.households[0], "herder", FOLD)
	_check(share(city, fold) == alone(city, fold) and share(city, fold) > 0.0, "a fold alone grazes all the open land in reach (%.0f)" % share(city, fold))

func test_pasture_same() -> void:
	var city: City = town()
	var a: Building = give(city, city.households[0], "herder", FOLD)
	var whole: float = city.land.get_reach_factor(a)
	var b: Building = give(city, city.households[1], "herder", FOLD + Vector2i(0, -4))
	_check(share(city, a) < alone(city, a) and share(city, b) < alone(city, b), "two folds on the same pasture each graze less than all of it (%.1f of %.0f)" % [share(city, a), alone(city, a)])
	_check(city.land.get_reach_factor(a) < whole and is_equal_approx(city.land.get_output_factor(a), city.land.get_reach_factor(a)), "and bring in less wool, in real output too (%.2f -> %.2f)" % [whole, city.land.get_output_factor(a)])
	city.set_meta("pasture_not_shared", true)
	_check(is_equal_approx(city.land.get_reach_factor(a), clampf(alone(city, a) / EconomyBalance.HERDER_FULL_PASTURE_TILES, EconomyBalance.LAND_YIELD_FLOOR, 1.0)), "before the fix (meta pasture_not_shared) each grazed all of it")
	city.remove_meta("pasture_not_shared")

func test_pasture_overlapping() -> void:
	var city: City = town()
	var a: Building = give(city, city.households[0], "herder", FOLD)
	var c: Building = give(city, city.households[1], "herder", FOLD + Vector2i(7, 0))
	_check(share(city, a) < alone(city, a) and share(city, a) > alone(city, a) * 0.5, "partly overlapping folds halve only the overlap (%.1f of %.0f)" % [share(city, a), alone(city, a)])
	_check(is_equal_approx(share(city, a) + share(city, c), land_worth(city, [a, c])), "and between them graze exactly the land in their reaches (%.1f)" % land_worth(city, [a, c]))

func test_pasture_apart() -> void:
	var city: City = town()
	var a: Building = give(city, city.households[0], "herder", FOLD)
	var d: Building = give(city, city.households[1], "herder", FOLD + Vector2i(20, 0))
	_check(share(city, a) == alone(city, a) and share(city, d) == alone(city, d), "folds far apart keep their own pasture")

# A hill tile counts double, and its double is shared like any other.
func test_hill_pasture_shared() -> void:
	var city: City = town()
	var a: Building = give(city, city.households[0], "herder", FOLD)
	var b: Building = give(city, city.households[1], "herder", FOLD + Vector2i(0, -4))
	var flat: float = share(city, a)
	var overlap: Rect2i = TownLand.get_reach_rect(a.type, a.tile, a.size).intersection(TownLand.get_reach_rect(b.type, b.tile, b.size))
	var hill: Vector2i = Vector2i(-1, -1)
	for y in range(overlap.position.y, overlap.end.y):
		for x in range(overlap.position.x, overlap.end.x):
			if hill.x < 0 and TownLand.get_tile_worth(city.local_map[y][x], "pasture") == 1:
				hill = Vector2i(x, y)
	city.local_map[hill.y][hill.x]["is_hill"] = true
	city.logistics.mark_layout_changed()
	_check(is_equal_approx(share(city, a), flat + 0.5) and is_equal_approx(share(city, a) + share(city, b), land_worth(city, [a, b])), "a flat tile in the shared pasture turned hill counts 2 instead of 1: half the gain to each fold (%.1f -> %.1f)" % [flat, share(city, a)])

# --- No duplication ------------------------------------------------------------------------------

# Three of each kind, every pair overlapping some: the shares add up to the land, each tile once.
func test_never_more_than_the_land() -> void:
	var city: City = town([LAKE])
	var huts: Array[Building] = [give(city, city.households[0], "fisher", HUT), give(city, city.households[1], "fisher", HUT + Vector2i(2, 0)), give(city, city.households[2], "fisher", HUT + Vector2i(-3, -5))]
	var total: float = 0.0
	for hut: Building in huts:
		total += share(city, hut)
	_check(is_equal_approx(total, land_worth(city, huts)), "three huts' shares add up to the water in their reaches, counted once (%.2f, %.0f)" % [total, land_worth(city, huts)])
	var pasture: City = town()
	var folds: Array[Building] = [give(pasture, pasture.households[0], "herder", FOLD), give(pasture, pasture.households[1], "herder", FOLD + Vector2i(4, 2)), give(pasture, pasture.households[2], "herder", FOLD + Vector2i(-2, 5))]
	total = 0.0
	for fold: Building in folds:
		total += share(pasture, fold)
	_check(is_equal_approx(total, land_worth(pasture, folds)), "three folds' shares add up to the pasture in their reaches, counted once (%.2f, %.0f)" % [total, land_worth(pasture, folds)])
	var woods: City = town()
	for y in range(10, 20):
		for x in range(14, 30):
			woods.local_map[y][x]["has_trees"] = true
	woods.logistics.mark_layout_changed()
	var lodges: Array[Building] = [give(woods, woods.households[0], "hunter", Vector2i(16, 20)), give(woods, woods.households[1], "hunter", Vector2i(22, 20)), give(woods, woods.households[2], "hunter", Vector2i(28, 8))]
	total = 0.0
	for lodge: Building in lodges:
		total += share(woods, lodge)
	_check(is_equal_approx(total, land_worth(woods, lodges)), "three lodges' shares add up to the woods in their reaches, counted once (%.2f, %.0f)" % [total, land_worth(woods, lodges)])

# A family weighing a hut on water two huts already fish expects its share, as for hunting.
func test_families_judge_shared_land() -> void:
	var city: City = town([LAKE])
	give(city, city.households[0], "fisher", HUT)
	give(city, city.households[1], "fisher", HUT + Vector2i(1, 0))
	var judged: float = city.land.get_reach_factor_at("fisher", HUT + Vector2i(2, 0), city.construction.get_size("fisher"))
	_check(is_equal_approx(judged, 4.0 / 12.0), "a third hut on the lake is judged at a third of a catch (%.2f)" % judged)
	var shared_food: float = FamilyInitiative.get_working_output(city, "food")
	city.set_meta("water_not_shared", true)
	var whole_food: float = FamilyInitiative.get_working_output(city, "food")
	city.remove_meta("water_not_shared")
	_check(is_equal_approx(shared_food, whole_food * 0.5), "the food the town's fishing brings in is the shares, half of counting the lake twice (%.2f, %.2f)" % [shared_food, whole_food])

# Only workplaces of the same kind share: a hut beside a fold and a lodge loses nothing to them.
func test_kinds_do_not_compete() -> void:
	var city: City = town([LAKE])
	var hut: Building = give(city, city.households[0], "fisher", HUT)
	give(city, city.households[1], "herder", HUT + Vector2i(-1, 2))
	give(city, city.households[2], "hunter", HUT + Vector2i(3, 1))
	_check(share(city, hut) == 12.0 and city.land.get_reach_factor(hut) == 1.0, "a fold and a lodge beside the hut take none of its water")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
