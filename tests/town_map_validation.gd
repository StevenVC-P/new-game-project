extends SceneTree

# Town maps magnify the regional land around their site (LocalCityMapGenerator): the same
# site always gives the same town; deep inside a regional feature the town has that feature;
# every town keeps room to start; the town's heart is clear.

const MainScript = preload("res://scripts/main.gd")

const SHOWCASE_REGIONS: Array[String] = ["Meander Plains", "Thornspine North", "Crownspine Heights", "Tessaly", "Siwan Oases", "Taigard"]
const SITES_PER_REGION: int = 4

var failure_count: int = 0
var world: WorldMapData = null
var terrain: RegionalTerrain = null
var generator: LocalCityMapGenerator = null
# [global site, town map] for every probed site.
var probed: Array = []

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	world = FixedWorldDefinition.build()
	terrain = RegionalTerrain.new(world)
	generator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	collect_sites()
	test_generation_is_deterministic()
	test_town_follows_the_region()
	test_every_town_can_start()
	test_original_maps_still_work()
	terrain.wait_for_tasks()

	if failure_count > 0:
		push_error("Town map validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town map validation passed.")
	quit()

# Valid founding sites around the showcase regions' main settlements, as the game finds them.
func collect_sites() -> void:
	var size: Vector2i = MainScript.NEIGHBOURHOOD_SIZE
	var no_cities: Array[City] = []
	for region_name: String in SHOWCASE_REGIONS:
		var region: WorldMapData.Region = world.find_region_by_name(region_name)
		var focus: Vector2i = terrain.world_to_tile_index(terrain.region_focus(region))
		var origin: Vector2i = Vector2i(terrain.wrap_tile_x(focus.x - size.x / 2), clampi(focus.y - size.y / 2, 0, terrain.size_tiles.y - size.y))
		var tiles: Array = terrain.extract_window(origin, size)
		var sites: Array[Vector2i] = []
		for y in range(size.y):
			for x in range(size.x):
				if FoundingSiteHelper.is_valid_founding_tile(tiles, no_cities, Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
					sites.append(Vector2i(x, y))
		_check(not sites.is_empty(), region_name + " should offer founding sites")
		for k in range(SITES_PER_REGION):
			if sites.is_empty():
				break
			var site: Vector2i = sites[(k * 7919 + 13) % sites.size()]
			var global_site: Vector2i = Vector2i(terrain.wrap_tile_x(origin.x + site.x), origin.y + site.y)
			probed.append([global_site, generator.generate_from_terrain(terrain, global_site, terrain.climate_at(global_site))])

func test_generation_is_deterministic() -> void:
	for entry: Array in probed.slice(0, 6):
		var global_site: Vector2i = entry[0]
		var again: Array = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT).generate_from_terrain(terrain, global_site, terrain.climate_at(global_site))
		_check(again == entry[1], "the same site should always give the same town map " + str(global_site))

# Where all four regional tiles a town tile blends between agree, the town tile has their
# feature, whatever the edge noise does. Town-scale detail is allowed on top: glades in woods,
# copses on open land, outcrops on hills, and the cleared heart of the town.
func test_town_follows_the_region() -> void:
	var tally: Dictionary = {"water": [0, 0], "mountain": [0, 0], "forest": [0, 0], "open": [0, 0]}
	var reach: Vector2i = generator.regional_reach()
	var center: Vector2 = Vector2(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) * 0.5
	for entry: Array in probed:
		var global_site: Vector2i = entry[0]
		var local_map: Array = entry[1]
		var window: Array = terrain.extract_window(global_site - reach, reach * 2 + Vector2i.ONE)
		for y in range(MainScript.CITY_MAP_HEIGHT):
			for x in range(MainScript.CITY_MAP_WIDTH):
				if Vector2(x + 0.5, y + 0.5).distance_to(center) <= LocalCityMapGenerator.CENTER_CLEAR_RADIUS + 1.0:
					continue
				var category: String = interior_category(window, reach, x, y)
				if not tally.has(category):
					continue
				var tile: Dictionary = local_map[y][x]
				var agrees: bool = false
				match category:
					"water":
						agrees = tile["type"] == "water"
					"mountain":
						agrees = tile["type"] == "rough"
					"forest":
						agrees = tile["has_trees"] == true
					"open":
						agrees = tile["type"] == "ground" and not tile["has_trees"]
				tally[category][0] += 1 if agrees else 0
				tally[category][1] += 1
	print("[TOWN] agreement with the region (agreeing / interior tiles): ", tally)
	_check(tally["water"][1] >= 100 and tally["forest"][1] >= 100 and tally["open"][1] >= 1000, "the probed sites should cover water, woods, and open land")
	_check(tally["water"][0] == tally["water"][1], "deep regional water should always be water in town")
	_check(tally["mountain"][0] == tally["mountain"][1], "deep regional mountains should always be rock in town")
	_check(tally["forest"][0] >= tally["forest"][1] * (1.0 - LocalCityMapGenerator.GLADE_SHARE - 0.02), "deep regional woods should be wooded in town, apart from glades")
	_check(tally["open"][0] >= tally["open"][1] * 0.9, "open regional land should be open in town, apart from copses")

# The category the 3x3 regional tiles around a town tile's sample share, or "" where they
# differ. The generator blends the four tiles around a sample it may move by up to
# WARP_TILES (under half a tile), and those always lie in this block.
func interior_category(window: Array, reach: Vector2i, x: int, y: int) -> String:
	var regional: Vector2 = Vector2(reach) + Vector2(0.5, 0.5) + (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) * 0.5) / LocalCityMapGenerator.TOWN_TILES_PER_REGIONAL_TILE
	var center: Vector2i = Vector2i(regional.floor())
	var shared: String = ""
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var category: String = regional_category(window[center.y + dy][center.x + dx])
			if shared == "":
				shared = category
			elif category != shared:
				return ""
	return shared

static func regional_category(tile: Dictionary) -> String:
	var tile_type: String = tile["type"]
	if tile_type == "river" or tile_type == "lake" or tile_type == "sea":
		return "water"
	if tile["resource"] != "none" or tile["has_road"] == true:
		return "mixed"
	if tile_type == "mountain":
		return "mountain"
	if tile_type == "hill":
		return "mixed"
	if tile["has_forest"] == true:
		return "forest"
	return "open"

func test_every_town_can_start() -> void:
	var center: Vector2i = Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) / 2
	for entry: Array in probed:
		check_floors(entry[1], str(entry[0]))
		var heart: Dictionary = entry[1][center.y][center.x]
		_check(heart["type"] != "rough" and not heart["has_trees"], "the town's heart should be clear " + str(entry[0]))

func check_floors(local_map: Array, label: String) -> void:
	var buildable: int = 0
	var fertile: int = 0
	var trees: int = 0
	for row: Array in local_map:
		for tile: Dictionary in row:
			buildable += 1 if LocalCityMapGenerator.is_buildable(tile) else 0
			fertile += 1 if tile["is_fertile"] else 0
			trees += 1 if tile["has_trees"] else 0
			if tile["type"] == "water":
				_check(tile["water_kind"] in ["river", "lake", "sea"], "water should say what kind it is " + label)
				_check(not tile["has_trees"] and not tile["is_fertile"], "water should hold no trees or farmland " + label)
			if tile["resource"] != "none":
				_check(tile["type"] == "rough", "deposits should be rough ground " + label)
			if tile["is_fertile"]:
				_check(LocalCityMapGenerator.is_buildable(tile), "farmland should be open ground " + label)
	_check(buildable >= LocalCityMapGenerator.MIN_BUILDABLE_TILES, "a town should have room to build " + label)
	_check(fertile >= LocalCityMapGenerator.MIN_FERTILE_TILES, "a town should have some farmland " + label)
	_check(trees >= LocalCityMapGenerator.MIN_TREE_TILES, "a town should have woods in reach " + label)

# Bounded regional maps (no world) still get town maps, the same for the same site.
func test_original_maps_still_work() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1001
	var region: Dictionary = RegionMapGenerator.new(rng, MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT, MainScript.MIN_CITY_DISTANCE, MainScript.RIVER_NEAR_RANGE, MainScript.CITY_RESOURCE_RANGE).generate_region()
	var tiles: Array = region["tiles"]
	var checked: int = 0
	for y in range(0, MainScript.MAP_HEIGHT, 7):
		for x in range(0, MainScript.MAP_WIDTH, 9):
			if not FoundingSiteHelper.is_valid_founding_tile(tiles, region["cities"], Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
				continue
			var local_map: Array = generator.generate(Vector2i(x, y), tiles, Vector2i.ZERO, LocalCityMapGenerator.DEFAULT_CLIMATE)
			check_floors(local_map, "original map " + str(Vector2i(x, y)))
			_check(local_map == generator.generate(Vector2i(x, y), tiles, Vector2i.ZERO, LocalCityMapGenerator.DEFAULT_CLIMATE), "original maps should give the same town for the same site")
			checked += 1
	_check(checked >= 5, "the original map should offer sites to check")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
