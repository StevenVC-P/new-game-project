extends SceneTree

# Map luck check: can a town get off the ground at any valid founding site? Generates real worlds,
# founds towns at valid sites, generates their town maps exactly as the game does, and plays two
# years with the stand-in player placing every building on the real map.
# Run: <godot> --headless --path . --script res://tests/sim/map_luck_check.gd   (filter for [MAP])
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
const DAYS: int = 720
# Capacity counting stops here; more than this is plenty for a first village.
const CAPACITY_CAP: int = 12

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	var results: Array[Dictionary] = []
	for world in range(WORLDS):
		results.append_array(_play_world(1000 + world))

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

	_report("%d/%d towns off the ground across %d worlds (%d founding families, sensible opening, real town maps)" % [made_it, results.size(), WORLDS, EconomyBalanceScript.FOUNDING_FAMILIES])
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
			_report("  failed world %d site %s [%s]: farms room %d, camps room %d, people %d; %s" % [
				result["world"], str(result["site"]), ", ".join(result["tags"]), result["farm_capacity"], result["camp_capacity"], result["population"], ", ".join(result["reasons"])])
	quit()

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
		results.append(_play_site(world_seed, rng, tiles, cities, site))
	return results

func _play_site(world_seed: int, rng: RandomNumberGenerator, tiles: Array, cities: Array[City], site: Vector2i) -> Dictionary:
	var city = CityScript.new("Player Town", Vector2(site), CityScript.ROLE_PLAYER, EconomyBalanceScript.FOUNDING_FAMILIES, rng.randi())
	city.site_profile = SettlementSiteProfile.analyze(city.tile, tiles, MainScript.CITY_RESOURCE_RANGE)
	city.local_map = LocalCityMapGenerator.new(rng, MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT, MainScript.MAP_WIDTH, MainScript.MAP_HEIGHT, MainScript.RIVER_NEAR_RANGE, MainScript.CITY_RESOURCE_RANGE).generate(city, tiles, cities.size())

	var farm_capacity: int = _count_capacity(city.local_map, "farm")
	var camp_capacity: int = _count_capacity(city.local_map, "gatherer_camp")
	var result: Dictionary = StandInPlayerScript.new().play(city, {}, DAYS)
	result["world"] = world_seed
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
