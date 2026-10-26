class_name RegionMapGenerator
extends RefCounted

var rng: RandomNumberGenerator
var map_width: int = 80
var map_height: int = 50
var min_city_distance: int = 24
var river_near_range: int = 5
var city_resource_range: int = 7
var tiles: Array = []
# When set, the map follows a world region (water, high ground, woods, roads, and town from the
# world map). Without it the generator makes the original generic river valley, unchanged.
var geography: RegionGeography = null

# Open water. Rivers are the original type; lakes and sea come only from world geography.
const WATER_TYPES: Array[String] = ["river", "lake", "sea"]

# Road routing cost per tile type in world-geography maps; lakes and sea are impassable.
const ROAD_COST_OPEN: float = 1.0
const ROAD_COST_FOREST: float = 2.0
const ROAD_COST_HILL: float = 2.6
const ROAD_COST_MOUNTAIN: float = 8.0
const ROAD_COST_RIVER: float = 6.0
const ROAD_COST_EXISTING_ROAD: float = 0.5
# World road exits closer than this along the map edge share one regional road.
const ROAD_EXIT_MERGE_TILES: float = 8.0
const MAX_ROAD_EXITS: int = 3

func _init(random_source: RandomNumberGenerator, width: int, height: int, city_distance: int, river_range: int, resource_range: int):
	rng = random_source
	map_width = width
	map_height = height
	min_city_distance = city_distance
	river_near_range = river_range
	city_resource_range = resource_range

func generate_region() -> Dictionary:
	tiles = make_base_tiles()

	if geography != null:
		generate_world_geography()
	else:
		# This is still one local river valley, just drawn with smaller tiles.
		generate_river()
		generate_fertile_land()
		generate_foothill_belt()
		generate_large_woods()
		generate_deposits()

	var generated_cities: Array[City] = place_cities()
	return {
		"tiles": tiles,
		"cities": generated_cities
	}

func generate_roads_for_cities(generated_cities: Array[City]) -> Array[Array]:
	var generated_roads: Array[Array] = []

	if geography != null:
		return generate_world_roads(generated_cities)

	if generated_cities.size() < 2:
		return generated_roads

	var city_a_tile: Vector2 = generated_cities[0].tile
	var city_b_tile: Vector2 = generated_cities[1].tile
	var road_between_cities: Array[Vector2] = make_road_path(city_a_tile, city_b_tile)
	generated_roads.append(road_between_cities)
	mark_road_path(road_between_cities)

	var outside_target: Vector2 = choose_nearest_edge_target(city_a_tile)
	var outside_road: Array[Vector2] = make_road_path(city_a_tile, outside_target)
	generated_roads.append(outside_road)
	mark_road_path(outside_road)

	return generated_roads

func make_base_tiles() -> Array:
	var generated_tiles: Array = []

	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append({
				"type": "grass",
				"has_forest": false,
				"is_fertile": false,
				"resource": "none",
				"has_road": false,
				"has_ford": false
			})
		generated_tiles.append(row)

	return generated_tiles

func place_cities() -> Array[City]:
	var generated_cities: Array[City] = []

	var world_town: City = place_world_town()
	if world_town != null:
		generated_cities.append(world_town)
		return generated_cities

	var neutral_town_pos: Vector2 = find_city_position("fertile")
	if neutral_town_pos.x >= 0:
		generated_cities.append(City.new("Neutral Town", neutral_town_pos, City.ROLE_NEUTRAL))
		print("Neutral Town tile position: ", neutral_town_pos)

	return generated_cities

func find_city_position(city_goal: String, other_city: Vector2 = Vector2(-1, -1)) -> Vector2:
	var best_score: int = -999
	var best_candidates: Array[Vector2] = []

	for y in range(map_height):
		for x in range(map_width):
			if not is_valid_city_tile(x, y):
				continue
			if other_city.x >= 0:
				var distance: float = other_city.distance_to(Vector2(x, y))
				if distance < min_city_distance:
					continue

			var score: int = score_city_tile(x, y, city_goal)
			if score > best_score:
				best_score = score
				best_candidates.clear()
				best_candidates.append(Vector2(x, y))
			elif score == best_score:
				best_candidates.append(Vector2(x, y))

	if best_candidates.is_empty():
		return Vector2(-1, -1)

	return best_candidates[rng.randi_range(0, best_candidates.size() - 1)]

func score_city_tile(x: int, y: int, city_goal: String) -> int:
	var score: int = 0
	var river_distance: int = distance_to_terrain(x, y, "river", 10)

	if tiles[y][x]["is_fertile"]:
		score += 4
	if river_distance >= 0:
		score += max(0, 10 - river_distance)
	if tiles[y][x]["type"] == "hill":
		score += 1

	if city_goal == "fertile":
		if tiles[y][x]["is_fertile"]:
			score += 14
		if river_distance >= 0 and river_distance <= river_near_range:
			score += 12

	if city_goal == "resources":
		score += count_nearby_resources(x, y) * 6
		score += count_nearby_forests(x, y) * 2
		score += count_nearby_terrain(x, y, "hill") * 2

	return score

func is_valid_city_tile(x: int, y: int) -> bool:
	if is_water_tile(x, y):
		return false
	if tiles[y][x]["type"] == "mountain":
		return false
	if tiles[y][x]["has_forest"]:
		return false
	if tiles[y][x]["resource"] != "none":
		return false
	return true

func generate_river():
	# The river enters and exits the screen, but the smaller tiles make it less blocky.
	var river_x: float = rng.randf_range(22.0, 58.0)
	var drift: float = rng.randf_range(-0.25, 0.25)

	for y in range(map_height):
		drift += rng.randf_range(-0.08, 0.08)
		drift = clamp(drift, -0.55, 0.55)
		river_x += drift + sin(float(y) * 0.23) * 0.18
		river_x = clamp(river_x, 8.0, float(map_width - 9))

		var river_radius: int = 1
		if y % 9 == 0 or rng.randf() < 0.18:
			river_radius = 2

		for x in range(int(floor(river_x)) - river_radius - 1, int(ceil(river_x)) + river_radius + 2):
			if not is_inside_map(x, y):
				continue

			var distance_from_center: float = abs(float(x) - river_x)
			if distance_from_center <= float(river_radius) + 0.35:
				clear_tile_for_river(x, y)

func clear_tile_for_river(x: int, y: int):
	tiles[y][x]["type"] = "river"
	tiles[y][x]["has_forest"] = false
	tiles[y][x]["is_fertile"] = false
	tiles[y][x]["resource"] = "none"
	tiles[y][x]["has_road"] = false
	tiles[y][x]["has_ford"] = false

func generate_fertile_land():
	for y in range(map_height):
		for x in range(map_width):
			if is_water_tile(x, y):
				continue

			var river_distance: int = distance_to_terrain(x, y, "river", 10)
			var chance: float = 0.025

			if river_distance >= 0 and river_distance <= 3:
				chance = 0.74
			elif river_distance >= 0 and river_distance <= 6:
				chance = 0.45
			elif river_distance >= 0 and river_distance <= 9:
				chance = 0.16

			if rng.randf() < chance:
				tiles[y][x]["is_fertile"] = true

func generate_foothill_belt():
	# Rough land leans in from the east edge, like the visible edge of a larger range.
	for y in range(-6, map_height + 6):
		var wave: float = sin(float(y) * 0.18) * 5.0 + sin(float(y) * 0.07) * 4.0
		var belt_center_x: int = map_width - 13 + int(round(wave))

		for x in range(belt_center_x - 10, map_width + 8):
			if not is_inside_map(x, y):
				continue
			if is_water_tile(x, y):
				continue

			var distance_from_edge: int = map_width - 1 - x
			var mountain_chance: float = 0.04
			var hill_chance: float = 0.30

			if distance_from_edge <= 5:
				mountain_chance = 0.18
				hill_chance = 0.58
			elif distance_from_edge <= 11:
				mountain_chance = 0.08
				hill_chance = 0.42

			var roll: float = rng.randf()
			if roll < mountain_chance:
				set_rough_terrain(x, y, "mountain")
			elif roll < hill_chance:
				set_rough_terrain(x, y, "hill")

	for _hill_patch in range(8):
		var hill_center: Vector2i = Vector2i(rng.randi_range(map_width - 28, map_width + 5), rng.randi_range(-4, map_height + 4))
		make_terrain_patch(hill_center, rng.randi_range(5, 9), "hill", 0.56)

	for _mountain_patch in range(6):
		var mountain_center: Vector2i = Vector2i(rng.randi_range(map_width - 17, map_width + 4), rng.randi_range(-5, map_height + 5))
		make_terrain_patch(mountain_center, rng.randi_range(3, 6), "mountain", 0.50)

func set_rough_terrain(x: int, y: int, terrain_type: String):
	tiles[y][x]["type"] = terrain_type
	tiles[y][x]["has_forest"] = false
	tiles[y][x]["resource"] = "none"

	if terrain_type == "mountain":
		tiles[y][x]["is_fertile"] = false

func make_terrain_patch(center: Vector2i, radius: int, terrain_type: String, chance: float):
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not is_inside_map(x, y):
				continue
			if is_water_tile(x, y):
				continue

			var distance: float = Vector2(center.x, center.y).distance_to(Vector2(x, y))
			if distance > radius:
				continue

			var edge_falloff: float = 1.0 - (distance / float(radius)) * 0.45
			if rng.randf() > chance * edge_falloff:
				continue

			set_rough_terrain(x, y, terrain_type)

func generate_large_woods():
	# Several woods begin outside the visible area, so this still reads as a cropped region.
	make_forest_cluster(Vector2i(-4, 10), 15, 0.76)
	make_forest_cluster(Vector2i(17, -5), 13, 0.68)
	make_forest_cluster(Vector2i(8, map_height + 5), 15, 0.70)

	for _forest_patch in range(7):
		var center: Vector2i = Vector2i(rng.randi_range(-6, map_width - 16), rng.randi_range(-5, map_height + 5))
		var radius: int = rng.randi_range(7, 12)
		make_forest_cluster(center, radius, 0.58)

func make_forest_cluster(center: Vector2i, radius: int, chance: float):
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not is_inside_map(x, y):
				continue
			if is_water_tile(x, y):
				continue
			if tiles[y][x]["type"] == "mountain":
				continue

			var distance: float = Vector2(center.x, center.y).distance_to(Vector2(x, y))
			if distance > radius:
				continue

			var edge_falloff: float = 1.0 - (distance / float(radius)) * 0.55
			var local_chance: float = chance * edge_falloff
			if is_near_river(x, y):
				local_chance += 0.10
			if tiles[y][x]["type"] == "hill":
				local_chance -= 0.14
			if rng.randf() < 0.04:
				local_chance -= 0.35

			if rng.randf() < local_chance:
				tiles[y][x]["has_forest"] = true

func generate_deposits(iron_clusters: int = 4, stone_clusters: int = 6):
	# Deposits are clustered so they stay meaningful instead of becoming visual noise.
	for _iron_cluster in range(iron_clusters):
		var iron_center: Vector2 = find_resource_cluster_center("iron")
		if iron_center.x >= 0:
			make_resource_cluster(iron_center, rng.randi_range(2, 4), "iron", 0.48)

	for _stone_cluster in range(stone_clusters):
		var stone_center: Vector2 = find_resource_cluster_center("stone")
		if stone_center.x >= 0:
			make_resource_cluster(stone_center, rng.randi_range(2, 5), "stone", 0.52)

func find_resource_cluster_center(resource_type: String) -> Vector2:
	var candidates: Array[Vector2] = []

	for y in range(map_height):
		for x in range(map_width):
			if is_water_tile(x, y):
				continue
			if tiles[y][x]["type"] == "mountain":
				continue
			if tiles[y][x]["resource"] != "none":
				continue

			if resource_type == "iron":
				if is_near_terrain_with_range(x, y, "mountain", 4):
					candidates.append(Vector2(x, y))
			elif resource_type == "stone":
				if is_near_terrain_with_range(x, y, "hill", 4) or is_near_terrain_with_range(x, y, "mountain", 5):
					candidates.append(Vector2(x, y))

	if candidates.is_empty():
		return Vector2(-1, -1)

	return candidates[rng.randi_range(0, candidates.size() - 1)]

func make_resource_cluster(center: Vector2, radius: int, resource_type: String, chance: float):
	for y in range(int(center.y) - radius, int(center.y) + radius + 1):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			if not is_inside_map(x, y):
				continue
			if is_water_tile(x, y):
				continue
			if tiles[y][x]["type"] == "mountain":
				continue
			if Vector2(center.x, center.y).distance_to(Vector2(x, y)) > radius:
				continue
			if rng.randf() > chance:
				continue

			tiles[y][x]["resource"] = resource_type
			tiles[y][x]["has_forest"] = false

func make_road_path(start_tile: Vector2, end_tile: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current: Vector2 = Vector2(start_tile.x, start_tile.y)
	path.append(current)

	while int(current.x) != int(end_tile.x) or int(current.y) != int(end_tile.y):
		var dx: float = abs(end_tile.x - current.x)
		var dy: float = abs(end_tile.y - current.y)
		var move_horizontal: bool = dx > dy

		if rng.randf() < 0.28:
			move_horizontal = not move_horizontal
		if int(current.x) == int(end_tile.x):
			move_horizontal = false
		elif int(current.y) == int(end_tile.y):
			move_horizontal = true

		if move_horizontal:
			current.x += sign(end_tile.x - current.x)
		else:
			current.y += sign(end_tile.y - current.y)

		path.append(Vector2(current.x, current.y))

	return path

func choose_nearest_edge_target(tile_pos: Vector2) -> Vector2:
	var left_distance: float = tile_pos.x
	var right_distance: float = map_width - 1 - tile_pos.x
	var top_distance: float = tile_pos.y
	var bottom_distance: float = map_height - 1 - tile_pos.y
	var best_distance: float = min(min(left_distance, right_distance), min(top_distance, bottom_distance))

	if best_distance == left_distance:
		return Vector2(0, tile_pos.y)
	if best_distance == right_distance:
		return Vector2(map_width - 1, tile_pos.y)
	if best_distance == top_distance:
		return Vector2(tile_pos.x, 0)

	return Vector2(tile_pos.x, map_height - 1)

func mark_road_path(path: Array[Vector2]):
	for tile_pos: Vector2 in path:
		var x: int = int(tile_pos.x)
		var y: int = int(tile_pos.y)
		if not is_inside_map(x, y):
			continue

		tiles[y][x]["has_road"] = true
		if tiles[y][x]["type"] == "river":
			tiles[y][x]["has_ford"] = true

func is_inside_map(x: int, y: int) -> bool:
	return x >= 0 and x < map_width and y >= 0 and y < map_height

func is_water_tile(x: int, y: int) -> bool:
	return WATER_TYPES.has(tiles[y][x]["type"])

func is_near_river(x: int, y: int) -> bool:
	return is_near_terrain_with_range(x, y, "river", river_near_range)

func is_near_terrain_with_range(x: int, y: int, terrain_type: String, search_range: int) -> bool:
	for yy in range(max(0, y - search_range), min(map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(map_width, x + search_range + 1)):
			if tiles[yy][xx]["type"] == terrain_type:
				return true
	return false

func distance_to_terrain(x: int, y: int, terrain_type: String, search_range: int) -> int:
	var best_distance: int = search_range + 1

	for yy in range(max(0, y - search_range), min(map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(map_width, x + search_range + 1)):
			if tiles[yy][xx]["type"] != terrain_type:
				continue

			var distance: int = int(round(Vector2(x, y).distance_to(Vector2(xx, yy))))
			if distance < best_distance:
				best_distance = distance

	if best_distance > search_range:
		return -1

	return best_distance

func count_nearby_resources(x: int, y: int) -> int:
	var count: int = 0

	for yy in range(max(0, y - city_resource_range), min(map_height, y + city_resource_range + 1)):
		for xx in range(max(0, x - city_resource_range), min(map_width, x + city_resource_range + 1)):
			if tiles[yy][xx]["resource"] != "none":
				count += 1

	return count

func count_nearby_forests(x: int, y: int) -> int:
	var count: int = 0

	for yy in range(max(0, y - city_resource_range), min(map_height, y + city_resource_range + 1)):
		for xx in range(max(0, x - city_resource_range), min(map_width, x + city_resource_range + 1)):
			if tiles[yy][xx]["has_forest"]:
				count += 1

	return count

func count_nearby_terrain(x: int, y: int, terrain_type: String) -> int:
	var count: int = 0

	for yy in range(max(0, y - city_resource_range), min(map_height, y + city_resource_range + 1)):
		for xx in range(max(0, x - city_resource_range), min(map_width, x + city_resource_range + 1)):
			if tiles[yy][xx]["type"] == terrain_type:
				count += 1

	return count

# --- World geography -----------------------------------------------------------
# Used only when `geography` is set. These steps keep the original tile model and resource
# rules; they decide where the world says water, high ground, woods, and roads belong.
# Noise here only shapes edges (coastlines, patch outlines); amounts come from the world.

# World elevation noise that shifts the coastline by up to about two tiles.
const COAST_NOISE_ELEVATION: float = 0.02
# Below this mean temperature the ground is frozen: no stream, no farmland.
const FROZEN_TEMPERATURE: float = 0.08
const STREAM_HALF_WIDTH: float = 1.15
const RIVER_MEANDER_TILES: float = 2.6

func generate_world_geography() -> void:
	var noise_seed: int = rng.randi()
	apply_world_water(noise_seed)
	if not draw_world_rivers() and geography.mean_temperature > FROZEN_TEMPERATURE:
		# The world map shows only major rivers; a region without one still has a stream.
		generate_stream()
	var high_ground: Vector2 = generate_world_relief(noise_seed + 1)
	generate_world_fertile_land(noise_seed + 2)
	generate_world_woods(noise_seed + 3)
	generate_deposits(2 + int(round(high_ground.x * 12.0)), 3 + int(round(high_ground.y * 10.0)))

func tile_of_index(i: int) -> Vector2i:
	return Vector2i(i % map_width, floori(float(i) / map_width))

func make_noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise

# Noise rank (0..1, evenly spread) for each eligible tile, -1 elsewhere. Thresholding a rank
# instead of raw noise gives coherent patches while keeping exact amounts.
func noise_ranks(noise_seed: int, frequency: float, eligible: PackedByteArray) -> PackedFloat32Array:
	var noise: FastNoiseLite = make_noise(noise_seed, frequency, 3)
	var ranks: PackedFloat32Array = PackedFloat32Array()
	ranks.resize(map_width * map_height)
	ranks.fill(-1.0)
	var values: PackedVector2Array = PackedVector2Array()
	for i in range(eligible.size()):
		if eligible[i] == 1:
			var tile: Vector2i = tile_of_index(i)
			values.append(Vector2(noise.get_noise_2d(tile.x, tile.y), i))
	values.sort()
	for order in range(values.size()):
		ranks[int(values[order].y)] = (order + 0.5) / values.size()
	return ranks

# Tiles of the given types count as 0; others get an approximate straight-line distance in tiles.
func water_distance_field(types: Array[String]) -> PackedFloat32Array:
	var distance: PackedFloat32Array = PackedFloat32Array()
	distance.resize(map_width * map_height)
	for y in range(map_height):
		for x in range(map_width):
			distance[y * map_width + x] = 0.0 if types.has(tiles[y][x]["type"]) else 9999.0
	# Two-pass chamfer transform.
	for y in range(map_height):
		for x in range(map_width):
			var i: int = y * map_width + x
			if x > 0:
				distance[i] = minf(distance[i], distance[i - 1] + 1.0)
			if y > 0:
				distance[i] = minf(distance[i], distance[i - map_width] + 1.0)
				if x > 0:
					distance[i] = minf(distance[i], distance[i - map_width - 1] + 1.414)
				if x < map_width - 1:
					distance[i] = minf(distance[i], distance[i - map_width + 1] + 1.414)
	for y in range(map_height - 1, -1, -1):
		for x in range(map_width - 1, -1, -1):
			var i: int = y * map_width + x
			if x < map_width - 1:
				distance[i] = minf(distance[i], distance[i + 1] + 1.0)
			if y < map_height - 1:
				distance[i] = minf(distance[i], distance[i + map_width] + 1.0)
				if x < map_width - 1:
					distance[i] = minf(distance[i], distance[i + map_width + 1] + 1.414)
				if x > 0:
					distance[i] = minf(distance[i], distance[i + map_width - 1] + 1.414)
	return distance

func apply_world_water(noise_seed: int) -> void:
	var noise: FastNoiseLite = make_noise(noise_seed, 0.08, 3)
	for y in range(map_height):
		for x in range(map_width):
			var i: int = geography.tile_index(x, y)
			if geography.elevation[i] + noise.get_noise_2d(x, y) * COAST_NOISE_ELEVATION > 0.0:
				continue
			tiles[y][x]["type"] = "lake" if is_near_world_lake(x, y) else "sea"
	remove_stray_water_and_islets()

func is_near_world_lake(x: int, y: int) -> bool:
	for yy in range(maxi(0, y - 3), mini(map_height, y + 4)):
		for xx in range(maxi(0, x - 3), mini(map_width, x + 4)):
			if geography.water_at(xx, yy) == RegionGeography.WATER_LAKE:
				return true
	return false

# The coastline noise can open puddles inland or leave specks of land offshore; water that
# the world does not have and land too small to stand on are both removed.
func remove_stray_water_and_islets() -> void:
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(map_width * map_height)
	for y in range(map_height):
		for x in range(map_width):
			if visited[y * map_width + x] == 1:
				continue
			var is_water: bool = is_water_tile(x, y)
			var component: Array[Vector2i] = flood_component(Vector2i(x, y), is_water, visited)
			if is_water:
				var in_world: bool = false
				for tile: Vector2i in component:
					if geography.water_at(tile.x, tile.y) != RegionGeography.WATER_NONE:
						in_world = true
						break
				if not in_world:
					for tile: Vector2i in component:
						tiles[tile.y][tile.x]["type"] = "grass"
			elif component.size() < 6:
				var fill_type: String = "lake" if is_near_world_lake(x, y) else "sea"
				for tile: Vector2i in component:
					tiles[tile.y][tile.x]["type"] = fill_type

func flood_component(start: Vector2i, water: bool, visited: PackedByteArray) -> Array[Vector2i]:
	var component: Array[Vector2i] = [start]
	visited[start.y * map_width + start.x] = 1
	var next: int = 0
	while next < component.size():
		var tile: Vector2i = component[next]
		next += 1
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor: Vector2i = tile + offset
			if not is_inside_map(neighbor.x, neighbor.y):
				continue
			var i: int = neighbor.y * map_width + neighbor.x
			if visited[i] == 1 or is_water_tile(neighbor.x, neighbor.y) != water:
				continue
			visited[i] = 1
			component.append(neighbor)
	return component

# Stamps the world's rivers into the map, adding regional meanders: across one window the
# world's course is nearly straight. Returns false when no river crosses the map.
func draw_world_rivers() -> bool:
	var drew_river: bool = false
	for river: RegionGeography.RiverPath in geography.rivers:
		var phase: float = rng.randf() * TAU
		var travelled: float = 0.0
		for segment in range(river.points.size() - 1):
			var a: Vector2 = river.points[segment]
			var b: Vector2 = river.points[segment + 1]
			var length: float = a.distance_to(b)
			var normal: Vector2 = (b - a).normalized().orthogonal()
			var steps: int = maxi(1, ceili(length * 2.0))
			for step in range(steps):
				var t: float = float(step) / steps
				var center: Vector2 = a.lerp(b, t) + normal * meander_offset(travelled + length * t, phase)
				var half_width: float = lerpf(river.half_widths[segment], river.half_widths[segment + 1], t)
				if stamp_river(center, half_width):
					drew_river = true
			travelled += length
	return drew_river

# Sideways offset (tiles) of a meandering river at a distance along its course.
func meander_offset(along: float, phase: float) -> float:
	return RIVER_MEANDER_TILES * (sin(along / 9.0 + phase) * 0.75 + sin(along / 3.6 + phase * 1.7) * 0.25)

func stamp_river(center: Vector2, half_width: float) -> bool:
	var stamped: bool = false
	for y in range(int(floor(center.y - half_width)), int(ceil(center.y + half_width)) + 1):
		for x in range(int(floor(center.x - half_width)), int(ceil(center.x + half_width)) + 1):
			if not is_inside_map(x, y):
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > half_width:
				continue
			# A river ends where it meets a lake or the sea.
			if tiles[y][x]["type"] == "lake" or tiles[y][x]["type"] == "sea":
				continue
			clear_tile_for_river(x, y)
			stamped = true
	return stamped

# A minor stream that flows downhill (or toward the sea) across the map, with the same
# drifting meander as the original valley river.
func generate_stream() -> void:
	var center: Vector2 = Vector2(map_width, map_height) * 0.5
	var direction: Vector2 = -geography.uphill if geography.uphill != Vector2.ZERO else Vector2(0.0, 1.0)
	var sea_center: Vector2 = Vector2.ZERO
	var sea_tiles: int = 0
	for y in range(map_height):
		for x in range(map_width):
			if tiles[y][x]["type"] == "sea":
				sea_center += Vector2(x + 0.5, y + 0.5)
				sea_tiles += 1
	if sea_tiles > 0:
		direction = (sea_center / sea_tiles - center).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var origin: Vector2 = center + side * rng.randf_range(-0.2, 0.2) * map_height
	var start: Vector2 = ray_to_edge(origin, -direction)
	var finish: Vector2 = ray_to_edge(origin, direction)
	var length: int = int(start.distance_to(finish))
	var lateral: float = 0.0
	var drift: float = rng.randf_range(-0.25, 0.25)
	var phase: float = rng.randf() * TAU
	var on_land: bool = false
	for step in range(length + 1):
		drift = clampf(drift + rng.randf_range(-0.08, 0.08), -0.55, 0.55)
		lateral = clampf(lateral + drift + sin(step * 0.23) * 0.18, -map_height * 0.3, map_height * 0.3)
		var point: Vector2 = start + direction * step + side * (lateral + meander_offset(step, phase))
		var tile: Vector2i = Vector2i(point.floor())
		if is_inside_map(tile.x, tile.y) and (tiles[tile.y][tile.x]["type"] == "lake" or tiles[tile.y][tile.x]["type"] == "sea"):
			# The stream rises at the first land it reaches and ends where it meets open water.
			if on_land:
				break
			continue
		var half_width: float = STREAM_HALF_WIDTH + (0.35 if step % 9 == 0 else 0.0)
		if stamp_river(point, half_width):
			on_land = true

# Where a ray from inside the map leaves it.
func ray_to_edge(origin: Vector2, direction: Vector2) -> Vector2:
	var reach: float = INF
	if direction.x > 0.001:
		reach = minf(reach, (map_width - 0.5 - origin.x) / direction.x)
	elif direction.x < -0.001:
		reach = minf(reach, (0.5 - origin.x) / direction.x)
	if direction.y > 0.001:
		reach = minf(reach, (map_height - 0.5 - origin.y) / direction.y)
	elif direction.y < -0.001:
		reach = minf(reach, (0.5 - origin.y) / direction.y)
	return origin + direction * reach

# Hills and mountains on the land the world shows as high, with valleys along rivers.
# Returns the (mountain, hill) fractions of land used.
func generate_world_relief(noise_seed: int) -> Vector2:
	var mountain_fraction: float = clampf((geography.mean_relief - 0.3) * 0.6, 0.0, 0.3) + clampf((geography.mean_elevation - 0.35) * 0.3, 0.0, 0.1)
	var hill_fraction: float = clampf(0.07 + geography.mean_relief * 0.35 + maxf(geography.mean_elevation - 0.13, 0.0) * 0.8, 0.07, 0.4)
	var noise: FastNoiseLite = make_noise(noise_seed, 0.07, 4)
	var river_distance: PackedFloat32Array = water_distance_field(["river"])
	var ranked: PackedVector2Array = PackedVector2Array()
	for y in range(map_height):
		for x in range(map_width):
			if is_water_tile(x, y):
				continue
			var i: int = geography.tile_index(x, y)
			var height: float = (geography.elevation[i] - geography.mean_elevation) * 2.0 + geography.relief[i] * 0.8 + noise.get_noise_2d(x, y) * 0.5
			height -= 0.6 * (1.0 - smoothstep(0.0, 5.0, river_distance[i]))
			ranked.append(Vector2(-height, i))
	ranked.sort()
	var mountains: int = int(ranked.size() * mountain_fraction)
	var rough: int = mini(ranked.size(), mountains + int(ranked.size() * hill_fraction))
	for order in range(rough):
		var i: int = int(ranked[order].y)
		var tile: Vector2i = tile_of_index(i)
		set_rough_terrain(tile.x, tile.y, "mountain" if order < mountains else "hill")
	return Vector2(mountain_fraction, hill_fraction)

# Same distance-to-water chances as the original valley, scaled by climate and grouped into patches.
func generate_world_fertile_land(noise_seed: int) -> void:
	if geography.mean_temperature <= FROZEN_TEMPERATURE:
		return
	var near_scale: float = 1.0
	var far_scale: float = 1.0
	match geography.climate_family:
		RegionGeography.CLIMATE_ARID:
			near_scale = 0.85
			far_scale = 0.15
		RegionGeography.CLIMATE_COLD:
			near_scale = 0.55
			far_scale = 0.55
		RegionGeography.CLIMATE_TROPICAL:
			near_scale = 0.9
			far_scale = 0.9
	var fresh_water: PackedFloat32Array = water_distance_field(["river", "lake"])
	var ranks: PackedFloat32Array = noise_ranks(noise_seed, 0.11, eligible_land_mask())
	for y in range(map_height):
		for x in range(map_width):
			var i: int = y * map_width + x
			if ranks[i] < 0.0:
				continue
			var distance: float = fresh_water[i]
			var chance: float = 0.025 * far_scale
			if distance <= 3.0:
				chance = 0.74 * near_scale
			elif distance <= 6.0:
				chance = 0.45 * near_scale
			elif distance <= 9.0:
				chance = 0.16 * far_scale
			if tiles[y][x]["type"] == "hill":
				chance *= 0.6
			if ranks[i] < chance:
				tiles[y][x]["is_fertile"] = true

func generate_world_woods(noise_seed: int) -> void:
	var target: float = clampf(geography.mean_forest * 0.75 + 0.06, 0.05, 0.7)
	if geography.climate_family == RegionGeography.CLIMATE_ARID:
		target = minf(target, 0.07)
	if geography.mean_temperature < 0.2:
		target = minf(target, 0.04)
	if geography.mean_temperature <= FROZEN_TEMPERATURE:
		return
	var arid: bool = geography.climate_family == RegionGeography.CLIMATE_ARID
	var eligible: PackedByteArray = eligible_land_mask()
	var ranks: PackedFloat32Array = noise_ranks(noise_seed, 0.09, eligible)
	var fresh_water: PackedFloat32Array = water_distance_field(["river", "lake"])
	var scored: PackedVector2Array = PackedVector2Array()
	for y in range(map_height):
		for x in range(map_width):
			var i: int = y * map_width + x
			if ranks[i] < 0.0:
				continue
			var score: float = ranks[i] * 0.75 + geography.forest_cover[i] * 0.25
			if tiles[y][x]["type"] == "hill":
				score -= 0.15
			if fresh_water[i] <= 3.0:
				# Dry country keeps its trees along the water.
				score += 0.3 if arid else 0.08
			scored.append(Vector2(-score, i))
	scored.sort()
	for order in range(int(round(target * scored.size()))):
		var i: int = int(scored[order].y)
		var tile: Vector2i = tile_of_index(i)
		tiles[tile.y][tile.x]["has_forest"] = true

# Land that is neither water nor mountain.
func eligible_land_mask() -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(map_width * map_height)
	for y in range(map_height):
		for x in range(map_width):
			if not is_water_tile(x, y) and tiles[y][x]["type"] != "mountain":
				mask[y * map_width + x] = 1
	return mask

# The world settlement inside the map becomes the regional town, at the nearest buildable tile.
func place_world_town() -> City:
	if geography == null or geography.settlements.is_empty():
		return null
	var site: RegionGeography.SettlementSite = geography.settlements[0]
	var tile: Vector2i = nearest_valid_city_tile(Vector2i(site.tile.floor()), 14)
	if tile.x < 0:
		return null
	return City.new(site.name, Vector2(tile), City.ROLE_NEUTRAL)

func nearest_valid_city_tile(origin: Vector2i, max_radius: int) -> Vector2i:
	for radius in range(max_radius + 1):
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: float = INF
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != radius:
					continue
				if not is_inside_map(x, y) or not is_valid_city_tile(x, y):
					continue
				var distance: float = Vector2(x - origin.x, y - origin.y).length()
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(x, y)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

# Roads between the towns and out to where the world's roads leave the map, routed around
# rough ground and across rivers at short crossings.
func generate_world_roads(generated_cities: Array[City]) -> Array[Array]:
	var generated_roads: Array[Array] = []
	if generated_cities.is_empty():
		return generated_roads
	var astar: AStarGrid2D = make_road_astar()
	var hub: Vector2i = Vector2i(generated_cities[0].tile)
	for city_index in range(1, generated_cities.size()):
		add_routed_road(astar, hub, Vector2i(generated_cities[city_index].tile), generated_roads)
	for target: Vector2i in get_road_edge_targets(hub):
		add_routed_road(astar, hub, target, generated_roads)
	return generated_roads

func add_routed_road(astar: AStarGrid2D, from_tile: Vector2i, to_tile: Vector2i, generated_roads: Array[Array]) -> void:
	var id_path: Array[Vector2i] = astar.get_id_path(from_tile, to_tile)
	if id_path.size() < 2:
		return
	var path: Array[Vector2] = []
	for tile: Vector2i in id_path:
		path.append(Vector2(tile))
		# Later roads reuse this roadbed, so the network merges instead of running in parallel.
		astar.set_point_weight_scale(tile, ROAD_COST_EXISTING_ROAD)
	generated_roads.append(path)
	mark_road_path(path)

func make_road_astar() -> AStarGrid2D:
	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, map_width, map_height)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in range(map_height):
		for x in range(map_width):
			var tile: Dictionary = tiles[y][x]
			var tile_type: String = tile["type"]
			if tile_type == "lake" or tile_type == "sea":
				astar.set_point_solid(Vector2i(x, y), true)
				continue
			var cost: float = ROAD_COST_OPEN
			if tile["has_road"] == true:
				cost = ROAD_COST_EXISTING_ROAD
			elif tile_type == "mountain":
				cost = ROAD_COST_MOUNTAIN
			elif tile_type == "river":
				cost = ROAD_COST_RIVER
			elif tile_type == "hill":
				cost = ROAD_COST_HILL
			elif tile["has_forest"] == true:
				cost = ROAD_COST_FOREST
			astar.set_point_weight_scale(Vector2i(x, y), cost)
	return astar

# Map-edge tiles where the regional roads leave: the world's road exits, merged when close,
# or the nearest edge when no world road passes (the track the settlers came in on).
func get_road_edge_targets(hub: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	for exit: RegionGeography.RoadExit in geography.road_exits:
		var tile: Vector2i = nearest_land_edge_tile(exit.tile)
		if tile.x < 0:
			continue
		var merged: bool = false
		for target: Vector2i in targets:
			if Vector2(target).distance_to(Vector2(tile)) < ROAD_EXIT_MERGE_TILES:
				merged = true
				break
		if not merged:
			targets.append(tile)
		if targets.size() >= MAX_ROAD_EXITS:
			break
	if targets.is_empty():
		var fallback: Vector2i = nearest_land_edge_tile(Vector2i(choose_nearest_edge_target(Vector2(hub))))
		if fallback.x >= 0:
			targets.append(fallback)
	return targets

func nearest_land_edge_tile(edge_tile: Vector2i) -> Vector2i:
	var along_x: bool = edge_tile.y == 0 or edge_tile.y == map_height - 1
	for step in range(16):
		for direction in [1, -1]:
			var tile: Vector2i = edge_tile + (Vector2i(step * direction, 0) if along_x else Vector2i(0, step * direction))
			if is_inside_map(tile.x, tile.y) and not is_water_tile(tile.x, tile.y) and tiles[tile.y][tile.x]["type"] != "mountain":
				return tile
	return Vector2i(-1, -1)
