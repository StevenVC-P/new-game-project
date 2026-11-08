extends SceneTree

# The land-use record (master roadmap Phase 1, LandUseRecord): per regional tile, what a town's
# tiles hold now against the land before founding. It counts every town tile once, follows felling,
# fields and building, reads the town without changing it, is the same each time, and the continuous
# regional view stops drawing woods the town has felled.

var failure_count: int = 0
var terrain: RegionalTerrain = null

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	terrain = RegionalTerrain.new(FixedWorldDefinition.build())
	var site: Vector2i = wooded_site()
	_check(site.x >= 0, "a world settlement should have woods around it")
	if site.x >= 0:
		await test_the_record(site)
	terrain.wait_for_tasks()
	if failure_count > 0:
		push_error("Land use record validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Land use record validation passed.")
	quit()

# A world settlement's site with plenty of woods on its town map.
func wooded_site() -> Vector2i:
	for settlement: WorldMapData.Settlement in terrain.world.settlements:
		var site: Vector2i = terrain.settlement_tile(settlement)
		var land: Array = LocalCityMapGenerator.new(64, 44).generate_base_from_terrain(terrain, site, terrain.climate_at(site))
		if count(land, func(t: Dictionary) -> bool: return t["has_trees"] == true) >= 400:
			return site
	return Vector2i(-1, -1)

func test_the_record(site: Vector2i) -> void:
	var climate: Dictionary = terrain.climate_at(site)
	var base: Array = LocalCityMapGenerator.new(64, 44).generate_base_from_terrain(terrain, site, climate)
	var city: City = City.new("Record Town", Vector2(20, 20), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES)
	city.local_map = LocalCityMapGenerator.new(64, 44).generate_from_terrain(terrain, site, climate)
	var planet: int = terrain.size_tiles.x
	var before: Array = city.local_map.duplicate(true)
	var started: int = Time.get_ticks_usec()
	var record: LandUseRecord = LandUseRecord.of_town(city, base, site, planet)
	print("[LAND] a town's record: %.2f ms, %d regional tiles" % [(Time.get_ticks_usec() - started) / 1000.0, record.tiles.size()])
	_check(city.local_map == before, "reading the town changes nothing")
	_check(LandUseRecord.of_town(city, base, site, planet).tiles == record.tiles, "the same town gives the same record")
	var trees: int = count(city.local_map, func(t: Dictionary) -> bool: return t["has_trees"] == true)
	var base_trees: int = count(base, func(t: Dictionary) -> bool: return t["has_trees"] == true)
	_check(record.get_total(LandUseRecord.WOODED) == trees, "every wooded tile is counted once (%d of %d)" % [record.get_total(LandUseRecord.WOODED), trees])
	_check(record.get_total(LandUseRecord.CLEARED) == base_trees - trees, "the woods founding cleared are counted (%d of %d)" % [record.get_total(LandUseRecord.CLEARED), base_trees - trees])
	var full: bool = true
	for counts: Array in record.tiles.values():
		var land: int = 0
		for kind in [LandUseRecord.BUILT, LandUseRecord.FARMLAND, LandUseRecord.STREET]:
			land += int(counts[kind])
		full = full and land <= LandUseRecord.PER_TILE and int(counts[LandUseRecord.WOODED]) + int(counts[LandUseRecord.CLEARED]) <= LandUseRecord.PER_TILE
	_check(full, "no regional tile counts more town tiles than it holds")
	# Fell a wooded block away from the heart: the record sees it, and its regional tiles read cleared.
	var block: Rect2i = wooded_block(city.local_map)
	_check(block.size.x > 0, "the town should have a wooded block to fell")
	var felled: int = 0
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			if city.local_map[y][x]["has_trees"] == true:
				city.local_map[y][x]["has_trees"] = false
				felled += 1
	var after: LandUseRecord = LandUseRecord.of_town(city, base, site, planet)
	_check(after.get_total(LandUseRecord.CLEARED) == record.get_total(LandUseRecord.CLEARED) + felled, "felling shows in the record (%d felled)" % felled)
	var origin: Vector2i = LandUseRecord.town_origin(site, Vector2i(64, 44))
	var inside: Vector2i = Vector2i(floori(float(origin.x + block.get_center().x) / 4.0), floori(float(origin.y + block.get_center().y) / 4.0))
	_check(after.is_cleared(Vector2i(posmod(inside.x, planet), inside.y)), "a regional tile whose woods are felled reads cleared")
	# Fields and buildings.
	var household: Household = city.households[0]
	var farm_at: Vector2i = open_spot(city.local_map, Vector2i(3, 3))
	city.add_building(Building.new(-1, "farm", farm_at, Vector2i(3, 3)), household)
	# Fields aren't marked occupied, so the home keeps off the farm by hand.
	var house_at: Vector2i = open_spot(city.local_map, Vector2i(2, 2), Rect2i(farm_at, Vector2i(3, 3)))
	city.add_building(Building.new(-1, "house", house_at, Vector2i(2, 2)), household)
	var built: LandUseRecord = LandUseRecord.of_town(city, base, site, planet)
	_check(built.get_total(LandUseRecord.FARMLAND) == 9 and built.get_total(LandUseRecord.BUILT) == 4, "a farm's fields and a home are counted (%d farmland, %d built)" % [built.get_total(LandUseRecord.FARMLAND), built.get_total(LandUseRecord.BUILT)])
	# The continuous regional view reads the record: it stops drawing the felled woods.
	var view: RegionMapView = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2(0.0, 42.0), Vector2(1300.0, 858.0)))
	view.set_terrain(terrain)
	var size: Vector2i = Vector2i(60, 40)
	var window: Vector2i = Vector2i(terrain.wrap_tile_x(site.x - size.x / 2), site.y - size.y / 2)
	city.tile = Vector2(site - window)
	var cities: Array[City] = [city]
	var roads: Array[Array] = []
	view.set_neighbourhood(terrain.extract_window(window, size), cities, roads, window)
	_check(view.land_use.tiles == built.tiles, "the view holds the town's record")
	var point: Vector2 = (Vector2(posmod(inside.x, planet), inside.y) + Vector2(0.5, 0.5)) * RegionMapStyle.TILE
	_check(view.is_cleared_by_neighbourhood(point), "the regional map keeps felled woods clear")
	view.queue_free()
	await process_frame

# The most wooded 12x12 block at least 10 tiles from the heart.
func wooded_block(local_map: Array) -> Rect2i:
	var best: Rect2i = Rect2i()
	var best_trees: int = 0
	for y in range(0, 44 - 12, 4):
		for x in range(0, 64 - 12, 4):
			var rect: Rect2i = Rect2i(x, y, 12, 12)
			if Vector2(rect.get_center()).distance_to(Vector2(32, 22)) < 16.0:
				continue
			var trees: int = 0
			for yy in range(y, y + 12):
				for xx in range(x, x + 12):
					trees += 1 if local_map[yy][xx]["has_trees"] == true else 0
			if trees > best_trees:
				best_trees = trees
				best = rect
	return best

# Open ground with nothing on it, nearest the heart.
func open_spot(local_map: Array, size: Vector2i, avoid: Rect2i = Rect2i()) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for y in range(44 - size.y):
		for x in range(64 - size.x):
			var free: bool = not avoid.intersects(Rect2i(x, y, size.x, size.y))
			for yy in range(y, y + size.y):
				for xx in range(x, x + size.x):
					var tile: Dictionary = local_map[yy][xx]
					free = free and LocalCityMapGenerator.is_buildable(tile) and tile["occupied"] != true
			var distance: float = Vector2(x, y).distance_to(Vector2(32, 22))
			if free and distance < best_distance:
				best_distance = distance
				best = Vector2i(x, y)
	return best

static func count(local_map: Array, predicate: Callable) -> int:
	var total: int = 0
	for row: Array in local_map:
		for tile: Dictionary in row:
			total += 1 if predicate.call(tile) else 0
	return total

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
