extends SceneTree

# Map luck check: can a town get off the ground at any valid founding site? Generates real worlds,
# founds towns at valid sites, generates their town maps exactly as the game does, and plays two
# years with the stand-in player placing every building on the real map.
# Run: <godot> --headless --path . --script res://tests/sim/map_luck_check.gd   (filter for [MAP])
# Add "-- --world-seed=N" to play only the continuous map of a generated world (WorldGenerator).
#
# Reports how many farms and gatherer's camps each site's map can hold before play, and which
# kinds of sites (by site profile tag) struggle.

const MainScript = preload("res://scripts/main.gd")
const CityScript = preload("res://scripts/domain/city.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const BuildingPlacementScript = preload("res://scripts/ui/building_placement.gd")

const WORLDS: int = 8
const SITES_PER_WORLD: int = 6
# The continuous regional map: frontier regions spread across the world's climates, each a
# founding neighbourhood around its main settlement, as the game shows it.
const CONTINUOUS_REGIONS: int = 14
const SITES_PER_REGION: int = 3
const DAYS: int = 720
# Capacity counting stops here; more than this is plenty for a first village.
const CAPACITY_CAP: int = 12

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--world-seed="):
			var world_seed: int = int(arg.trim_prefix("--world-seed="))
			_summarize(_play_continuous_map(WorldGenerator.build(world_seed)), "continuous regional map of generated world %d, %d frontier regions" % [world_seed, CONTINUOUS_REGIONS])
			quit()
			return
	var results: Array[Dictionary] = []
	for world in range(WORLDS):
		results.append_array(_play_world(1000 + world))
	_summarize(results, "original regional maps, %d worlds" % WORLDS)
	_summarize(_play_continuous_map(FixedWorldDefinition.build()), "continuous regional map, %d frontier regions" % CONTINUOUS_REGIONS)
	quit()

func _summarize(results: Array[Dictionary], label: String) -> void:
	var made_it: int = 0
	var by_tag: Dictionary = {}
	for result: Dictionary in results:
		if result["off_the_ground"]:
			made_it += 1
		for tag: String in result["tags"]:
			if not by_tag.has(tag):
				by_tag[tag] = [0, 0]
			by_tag[tag][1] += 1
			if result["off_the_ground"]:
				by_tag[tag][0] += 1

	_report("%d/%d towns off the ground on the %s (%d founding families, sensible opening, real town maps)" % [made_it, results.size(), label, EconomyBalanceScript.FOUNDING_FAMILIES])
	var min_farms: int = CAPACITY_CAP
	var min_camps: int = CAPACITY_CAP
	for result: Dictionary in results:
		min_farms = min(min_farms, int(result["farm_capacity"]))
		min_camps = min(min_camps, int(result["camp_capacity"]))
	_report("room on the worst site: %d farms, %d gatherer's camps (counted up to %d)" % [min_farms, min_camps, CAPACITY_CAP])
	for tag in by_tag.keys():
		_report("  %-18s %d/%d" % [tag, by_tag[tag][0], by_tag[tag][1]])
	for result: Dictionary in results:
		if not result["off_the_ground"]:
			_report("  failed %s site %s [%s]: farms room %d, camps room %d, people %d; %s" % [
				str(result["world"]), str(result["site"]), ", ".join(result["tags"]), result["farm_capacity"], result["camp_capacity"], result["population"], ", ".join(result["reasons"])])

func _play_continuous_map(world: WorldMapData) -> Array[Dictionary]:
	var terrain: RegionalTerrain = RegionalTerrain.new(world)
	var frontier: Array[WorldMapData.Region] = []
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id == -1 and not world.is_frozen_region(region):
			frontier.append(region)
	# Spread the picks across climates: sort by climate, then take evenly spaced regions.
	frontier.sort_custom(func(a: WorldMapData.Region, b: WorldMapData.Region) -> bool: return a.climate + a.name < b.climate + b.name)
	var size: Vector2i = MainScript.NEIGHBOURHOOD_SIZE
	var results: Array[Dictionary] = []
	for pick in range(CONTINUOUS_REGIONS):
		var region: WorldMapData.Region = frontier[pick * frontier.size() / CONTINUOUS_REGIONS]
		var focus: Vector2i = terrain.world_to_tile_index(terrain.region_focus(region))
		var origin: Vector2i = Vector2i(terrain.wrap_tile_x(focus.x - size.x / 2), clampi(focus.y - size.y / 2, 0, terrain.size_tiles.y - size.y))
		var tiles: Array = terrain.extract_window(origin, size)
		var cities: Array[City] = []
		var town_tiles: PackedVector2Array = PackedVector2Array()
		for pair: Array in terrain.settlements_in_window(origin, size):
			cities.append(City.new((pair[0] as WorldMapData.Settlement).name, Vector2((pair[1] as Vector2i) - origin), City.ROLE_NEUTRAL))
			town_tiles.append(Vector2((pair[1] as Vector2i) - origin))
		# The game's own rules: the tile rules, no frozen ground, no kingdom land.
		var valid_sites: Array[Vector2i] = MainScript.scan_founding_sites(tiles, town_tiles, terrain.region_ids_in_window(origin, size), terrain.frozen_in_window(origin, size), world, size)
		_report("%s (%s): %d valid founding sites in the neighbourhood" % [region.name, region.climate, valid_sites.size()])
		if valid_sites.is_empty():
			continue
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 5000 + region.id
		for _site in range(SITES_PER_REGION):
			var site: Vector2i = valid_sites[rng.randi_range(0, valid_sites.size() - 1)]
			results.append(_play_site(region.name, rng, tiles, cities, site, size, terrain, origin))
	terrain.wait_for_tasks()
	return results

func _play_world(world_seed: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	var region: Dictionary = RegionMapGenerator.new(rng, MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT, MainScript.MIN_CITY_DISTANCE, MainScript.RIVER_NEAR_RANGE, MainScript.CITY_RESOURCE_RANGE).generate_region()
	var tiles: Array = region["tiles"]
	var cities: Array[City] = region["cities"]

	var valid_sites: Array[Vector2i] = []
	for y in range(MainScript.MAP_HEIGHT):
		for x in range(MainScript.MAP_WIDTH):
			if FoundingSiteHelper.is_valid_founding_tile(tiles, cities, Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
				valid_sites.append(Vector2i(x, y))

	var results: Array[Dictionary] = []
	if valid_sites.is_empty():
		_report("world %d has no valid founding site" % world_seed)
		return results
	for pick in range(SITES_PER_WORLD):
		var site: Vector2i = valid_sites[rng.randi_range(0, valid_sites.size() - 1)]
		results.append(_play_site(world_seed, rng, tiles, cities, site, Vector2i(MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT)))
	return results

# terrain and origin are given on the continuous map (origin: the neighbourhood's global tile).
func _play_site(world: Variant, rng: RandomNumberGenerator, tiles: Array, cities: Array[City], site: Vector2i, _map_size: Vector2i, terrain: RegionalTerrain = null, origin: Vector2i = Vector2i.ZERO) -> Dictionary:
	var city = CityScript.new("Player Town", Vector2(site), CityScript.ROLE_PLAYER, EconomyBalanceScript.FOUNDING_FAMILIES, rng.randi())
	city.site_profile = SettlementSiteProfile.analyze(city.tile, tiles, MainScript.CITY_RESOURCE_RANGE)
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	if terrain != null:
		var global_site: Vector2i = Vector2i(terrain.wrap_tile_x(origin.x + site.x), origin.y + site.y)
		city.site_profile.climate = terrain.climate_at(global_site)
		city.local_map = generator.generate_from_terrain(terrain, global_site, city.site_profile.climate)
	else:
		city.local_map = generator.generate(site, tiles, Vector2i.ZERO, city.site_profile.climate)

	var farm_capacity: int = _count_capacity(city.local_map, "farm")
	var camp_capacity: int = _count_capacity(city.local_map, "gatherer_camp")
	var result: Dictionary = StandInPlayerScript.new().play(city, {}, DAYS)
	result["world"] = world
	result["site"] = site
	result["tags"] = city.site_profile.tags.duplicate() if not city.site_profile.tags.is_empty() else ["ordinary_site"]
	result["farm_capacity"] = farm_capacity
	result["camp_capacity"] = camp_capacity
	return result

# How many of a building fit side by side on a fresh copy of the map.
func _count_capacity(local_map: Array, building_type: String) -> int:
	var scratch_map: Array = local_map.duplicate(true)
	var scratch_city = CityScript.new("Scratch", Vector2.ZERO, CityScript.ROLE_PLAYER, 0)
	scratch_city.resources["wood"] = 100000
	scratch_city.resources["tools"] = 100000
	var placement = BuildingPlacementScript.new()
	var size: Vector2i = placement.get_building_size(building_type)
	var count: int = 0
	for y in range(scratch_map.size()):
		for x in range((scratch_map[0] as Array).size()):
			if count >= CAPACITY_CAP:
				return count
			if placement.validate(scratch_city, scratch_map, building_type, Vector2i(x, y))["is_valid"] != true:
				continue
			for fy in range(y, y + size.y):
				for fx in range(x, x + size.x):
					(scratch_map[fy][fx] as Dictionary)["occupied"] = true
			count += 1
	return count

func _report(line: String) -> void:
	print("[MAP] " + line)
