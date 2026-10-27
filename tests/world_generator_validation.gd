extends SceneTree

# Generated worlds (WorldGenerator): every seed must build cleanly and keep the design rules of
# the authored world: continents in open ocean, little polar land, kingdoms with capitals inside
# their borders, unclaimed and contested frontier, routed roads, rivers that reach the sea.
# Pass seeds after "--" to check others: --script res://tests/world_generator_validation.gd -- 7 8

const MainScript = preload("res://scripts/main.gd")
const DEFAULT_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6]
# Polar land: share of all land beyond these latitudes.
const POLAR_LATITUDE_NORTH: float = 72.0
const POLAR_LATITUDE_SOUTH: float = -60.0
const MAX_POLAR_LAND_SHARE: float = 0.02
# A continent: a landmass of at least this share of the planet's political cells.
const CONTINENT_SHARE: float = 0.015

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	var seeds: Array[int] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			seeds.append(int(arg))
	if seeds.is_empty():
		seeds = DEFAULT_SEEDS

	for world_seed: int in seeds:
		var started_usec: int = Time.get_ticks_usec()
		var world: WorldMapData = WorldGenerator.build(world_seed)
		var contested: int = 0
		var unclaimed: int = 0
		for region: WorldMapData.Region in world.regions:
			contested += 1 if region.is_contested() else 0
			unclaimed += 1 if region.is_unclaimed() else 0
		print("[GEN] seed %d built in %.0f ms: %d regions (%d unclaimed, %d contested), %d kingdoms, %d settlements, %d roads, %d rivers, %d lakes, land %.2f, continents %d, polar land %.3f" % [
			world_seed, (Time.get_ticks_usec() - started_usec) / 1000.0, world.regions.size(), unclaimed, contested,
			world.kingdoms.size(), world.settlements.size(), world.roads.size(), world.rivers.size(), world.lakes.size(),
			land_fraction(world), continent_count(world), polar_land_share(world)])
		check_world(world, world_seed, unclaimed, contested)

	test_same_seed_same_world(seeds[0])
	test_different_seeds_differ(seeds[0])
	await test_game_plays_on_a_generated_world(seeds[0])

	if failure_count > 0:
		push_error("World generator validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("World generator validation passed.")
	quit()

func check_world(world: WorldMapData, world_seed: int, unclaimed: int, contested: int) -> void:
	var tag: String = " (seed %d)" % world_seed
	for warning: String in world.build_warnings:
		print("[GEN] warning", tag, ": ", warning)
	_check(world.build_warnings.is_empty(), "a generated world should build without warnings" + tag)
	_check(world.world_seed == world_seed, "the world should remember its seed" + tag)

	var land: float = land_fraction(world)
	_check(land > 0.2 and land < 0.4, "the planet should be mostly ocean with substantial land" + tag)
	_check(continent_count(world) >= 3, "the land should form several continents" + tag)
	_check(polar_land_share(world) <= MAX_POLAR_LAND_SHARE, "little land should lie in the polar seas" + tag)

	_check(world.kingdoms.size() >= 3, "the world should start with several kingdoms" + tag)
	_check(world.regions.size() <= 254, "the political texture holds at most 254 regions" + tag)
	_check(world.rivers.size() >= 8, "the world should have river systems" + tag)
	_check(unclaimed >= 10, "the world should leave unclaimed frontier" + tag)
	_check(contested >= 2, "some regions should be contested" + tag)

	for kingdom: WorldMapData.Kingdom in world.kingdoms:
		var capital: WorldMapData.Settlement = world.get_settlement(kingdom.capital_settlement_id)
		_check(capital != null and capital.kingdom_id == kingdom.id, "a kingdom's capital should lie inside it: " + kingdom.name + tag)
		_check(world.get_kingdom_regions(kingdom.id).size() >= 2, "a kingdom should hold more than one region: " + kingdom.name + tag)

	var region_names: Dictionary = {}
	var map_seeds: Dictionary = {}
	for region: WorldMapData.Region in world.regions:
		_check(region.cell_count > 0, "every region should own land: " + region.name + tag)
		_check(not region_names.has(region.name), "region names should be unique: " + region.name + tag)
		_check(not map_seeds.has(region.regional_map_seed), "regional map seeds should be distinct: " + region.name + tag)
		region_names[region.name] = true
		map_seeds[region.regional_map_seed] = true

	var settlement_names: Dictionary = {}
	for settlement: WorldMapData.Settlement in world.settlements:
		_check(not settlement_names.has(settlement.name), "settlement names should be unique: " + settlement.name + tag)
		settlement_names[settlement.name] = true
		_check(world.is_land_at(settlement.position), "a settlement should stand on land: " + settlement.name + tag)
		var region: WorldMapData.Region = world.get_region(settlement.region_id)
		_check(region != null and settlement.kingdom_id == region.owner_kingdom_id, "settlement allegiance should follow its region: " + settlement.name + tag)

	var classes: Dictionary = {}
	for road: WorldMapData.Road in world.roads:
		classes[road.road_class] = true
	_check(classes.size() == 3, "local, regional, and major roads should all exist" + tag)

func test_same_seed_same_world(world_seed: int) -> void:
	var first: WorldMapData = WorldGenerator.build(world_seed)
	var second: WorldMapData = WorldGenerator.build(world_seed)
	_check(first.terrain_image.get_data() == second.terrain_image.get_data(), "the same seed should give the same terrain")
	_check(first.region_grid == second.region_grid, "the same seed should give the same regions")
	var same_names: bool = first.settlements.size() == second.settlements.size()
	for i in range(mini(first.settlements.size(), second.settlements.size())):
		same_names = same_names and first.settlements[i].name == second.settlements[i].name
	_check(same_names, "the same seed should give the same settlements")

# The real game on a generated planet: it opens there, and a frontier region with a village
# opens on the regional map with that village in it and sites to found a town.
func test_game_plays_on_a_generated_world(world_seed: int) -> void:
	root.size = Vector2i(1600, 900)
	var main: Node2D = MainScript.new()
	main.world_seed = world_seed
	root.add_child(main)
	for _frame in range(3):
		await process_frame
	_check(main.world_map_data.world_seed == world_seed, "the game should play on the requested generated world")
	var frontier: WorldMapData.Region = null
	for region: WorldMapData.Region in main.world_map_data.regions:
		if region.owner_kingdom_id == -1 and not main.world_map_data.get_settlements_in_region(region.id).is_empty():
			frontier = region
			break
	_check(frontier != null, "a generated world should have a settled frontier region")
	if frontier != null:
		var status: Dictionary = main.world_map_view.get_region_entry_status(frontier)
		_check(bool(status["can_settle"]), "frontier on a generated world should be settleable: " + frontier.name)
		main.world_map_view.request_region_entry(frontier.id)
		main.wait_for_neighbourhood_job()
		_check(main.current_view == MainScript.VIEW_REGION, "entering a generated region should open the regional map")
		_check(not main.region_founding_sites.is_empty(), "a generated frontier region should offer founding sites: " + frontier.name)
		var village: String = main.world_map_data.get_settlements_in_region(frontier.id)[0].name
		_check(main.cities.any(func(city: City) -> bool: return city.name == village), "the region's village should be a town of the neighbourhood: " + village)
	main.queue_free()
	for _frame in range(3):
		await process_frame

func test_different_seeds_differ(world_seed: int) -> void:
	var first: WorldMapData = WorldGenerator.build(world_seed)
	var other: WorldMapData = WorldGenerator.build(world_seed + 1000)
	_check(first.region_grid != other.region_grid, "different seeds should give different worlds")

func land_fraction(world: WorldMapData) -> float:
	var land: int = 0
	for region_id: int in world.region_grid:
		if region_id >= 0:
			land += 1
	return float(land) / world.region_grid.size()

func polar_land_share(world: WorldMapData) -> float:
	var land: int = 0
	var polar: int = 0
	var size: Vector2i = world.political_size
	for y in range(size.y):
		var latitude: float = 90.0 - (y + 0.5) / size.y * 180.0
		for x in range(size.x):
			if world.region_grid[y * size.x + x] >= 0:
				land += 1
				if latitude > POLAR_LATITUDE_NORTH or latitude < POLAR_LATITUDE_SOUTH:
					polar += 1
	return float(polar) / maxf(land, 1.0)

# Landmasses (8-connected, wrapping) of at least CONTINENT_SHARE of the planet.
func continent_count(world: WorldMapData) -> int:
	var size: Vector2i = world.political_size
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(size.x * size.y)
	var count: int = 0
	for start in range(size.x * size.y):
		if seen[start] == 1 or world.region_grid[start] < 0:
			continue
		seen[start] = 1
		var queue: PackedInt32Array = PackedInt32Array([start])
		var head: int = 0
		while head < queue.size():
			var current: int = queue[head]
			head += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var y: int = current / size.x + dy
					if y < 0 or y >= size.y:
						continue
					var n: int = y * size.x + posmod(current % size.x + dx, size.x)
					if seen[n] == 0 and world.region_grid[n] >= 0:
						seen[n] = 1
						queue.append(n)
		if queue.size() >= CONTINENT_SHARE * size.x * size.y:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
