extends SceneTree

# Town map probe: what real town maps hold. Generates town maps at valid founding sites on the
# continuous regional map (frontier regions of every climate) and on original regional maps,
# and prints the spread of farmland, trees, water, rock, deposits, roads, and buildable land,
# plus generation time. SiteSurvey's thresholds are set from this spread.
# Run: <godot> --headless --path . --script res://tests/sim/town_map_probe.gd   (filter for [TOWN])

const MainScript = preload("res://scripts/main.gd")

const FRONTIER_REGIONS: int = 20
const SITES_PER_REGION: int = 4
const WORLDS: int = 8
const SITES_PER_WORLD: int = 10
const MEASURES: Array[String] = ["fertile", "trees", "water", "rough", "deposit", "road", "buildable"]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	_report_spread("continuous map", _probe_continuous())
	_report_spread("original maps", _probe_original())
	quit()

func _probe_continuous() -> Array[Dictionary]:
	var world: WorldMapData = FixedWorldDefinition.build()
	var terrain: RegionalTerrain = RegionalTerrain.new(world)
	var frontier: Array[WorldMapData.Region] = []
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id == -1:
			frontier.append(region)
	frontier.sort_custom(func(a: WorldMapData.Region, b: WorldMapData.Region) -> bool: return a.climate + a.name < b.climate + b.name)
	var size: Vector2i = MainScript.NEIGHBOURHOOD_SIZE
	var results: Array[Dictionary] = []
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	for pick in range(mini(FRONTIER_REGIONS, frontier.size())):
		var region: WorldMapData.Region = frontier[pick * frontier.size() / mini(FRONTIER_REGIONS, frontier.size())]
		var focus: Vector2i = terrain.world_to_tile_index(terrain.region_focus(region))
		var origin: Vector2i = Vector2i(terrain.wrap_tile_x(focus.x - size.x / 2), clampi(focus.y - size.y / 2, 0, terrain.size_tiles.y - size.y))
		var tiles: Array = terrain.extract_window(origin, size)
		var sites: Array[Vector2i] = []
		var no_cities: Array[City] = []
		for y in range(size.y):
			for x in range(size.x):
				if FoundingSiteHelper.is_valid_founding_tile(tiles, no_cities, Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
					sites.append(Vector2i(x, y))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7000 + region.id
		for _site in range(SITES_PER_REGION):
			if sites.is_empty():
				break
			var site: Vector2i = sites[rng.randi_range(0, sites.size() - 1)]
			var global_site: Vector2i = Vector2i(terrain.wrap_tile_x(origin.x + site.x), origin.y + site.y)
			var climate: Dictionary = terrain.climate_at(global_site)
			var started: int = Time.get_ticks_usec()
			var local_map: Array = generator.generate_from_terrain(terrain, global_site, climate)
			var result: Dictionary = _measure(local_map)
			result["usec"] = Time.get_ticks_usec() - started
			result["label"] = "%s (%s, t%.2f m%.2f)" % [region.name, climate["family"], climate["temperature"], climate["moisture"]]
			results.append(result)
	terrain.wait_for_tasks()
	return results

func _probe_original() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	for world in range(WORLDS):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000 + world
		var region: Dictionary = RegionMapGenerator.new(rng, MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT, MainScript.MIN_CITY_DISTANCE, MainScript.RIVER_NEAR_RANGE, MainScript.CITY_RESOURCE_RANGE).generate_region()
		var tiles: Array = region["tiles"]
		var sites: Array[Vector2i] = []
		for y in range(MainScript.MAP_HEIGHT):
			for x in range(MainScript.MAP_WIDTH):
				if FoundingSiteHelper.is_valid_founding_tile(tiles, region["cities"], Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
					sites.append(Vector2i(x, y))
		for _site in range(SITES_PER_WORLD):
			var site: Vector2i = sites[rng.randi_range(0, sites.size() - 1)]
			var started: int = Time.get_ticks_usec()
			var local_map: Array = generator.generate(site, tiles, Vector2i.ZERO, LocalCityMapGenerator.DEFAULT_CLIMATE)
			var result: Dictionary = _measure(local_map)
			result["usec"] = Time.get_ticks_usec() - started
			result["label"] = "world %d %s" % [1000 + world, str(site)]
			results.append(result)
	return results

func _measure(local_map: Array) -> Dictionary:
	var counts: Dictionary = {}
	for measure: String in MEASURES:
		counts[measure] = 0
	for row: Array in local_map:
		for tile: Dictionary in row:
			if tile["is_fertile"]:
				counts["fertile"] += 1
			if tile["has_trees"]:
				counts["trees"] += 1
			if tile["type"] == "water":
				counts["water"] += 1
			elif tile["type"] == "rough":
				counts["rough"] += 1
			if tile["resource"] != "none":
				counts["deposit"] += 1
			if tile["has_road"]:
				counts["road"] += 1
			if LocalCityMapGenerator.is_buildable(tile):
				counts["buildable"] += 1
	return counts

func _report_spread(label: String, results: Array[Dictionary]) -> void:
	print("[TOWN] %s: %d town maps" % [label, results.size()])
	for measure: String in MEASURES:
		var values: Array = []
		for result: Dictionary in results:
			values.append(int(result[measure]))
		values.sort()
		print("[TOWN]   %-9s min %4d  p10 %4d  p25 %4d  median %4d  p75 %4d  p90 %4d  max %4d" % [measure, values[0], _pick(values, 0.1), _pick(values, 0.25), _pick(values, 0.5), _pick(values, 0.75), _pick(values, 0.9), values[-1]])
	var times: Array = []
	for result: Dictionary in results:
		times.append(int(result["usec"]))
	times.sort()
	print("[TOWN]   generation: median %.1f ms, worst %.1f ms" % [_pick(times, 0.5) / 1000.0, times[-1] / 1000.0])
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["fertile"] < b["fertile"])
	for result: Dictionary in results.slice(0, 4):
		print("[TOWN]   least farmland: %s fertile %d, trees %d, water %d, buildable %d" % [result["label"], result["fertile"], result["trees"], result["water"], result["buildable"]])

func _pick(values: Array, fraction: float) -> int:
	return values[clampi(int(fraction * (values.size() - 1)), 0, values.size() - 1)]
