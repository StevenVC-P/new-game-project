class_name RegionMapGenerator
extends RefCounted

var rng: RandomNumberGenerator
var map_width: int = 80
var map_height: int = 50
var min_city_distance: int = 24
var river_near_range: int = 5
var city_resource_range: int = 7
var tiles: Array = []

func _init(random_source: RandomNumberGenerator, width: int, height: int, city_distance: int, river_range: int, resource_range: int):
	rng = random_source
	map_width = width
	map_height = height
	min_city_distance = city_distance
	river_near_range = river_range
	city_resource_range = resource_range

func generate_region() -> Dictionary:
	tiles = make_base_tiles()

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

	var city_a_pos: Vector2 = find_city_position("fertile")
	if city_a_pos.x >= 0:
		generated_cities.append(City.new("City A", city_a_pos))
		print("City A tile position: ", city_a_pos)

	var city_b_pos: Vector2 = find_city_position("resources", city_a_pos)
	if city_b_pos.x >= 0:
		generated_cities.append(City.new("City B", city_b_pos))
		print("City B tile position: ", city_b_pos)

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
	if tiles[y][x]["type"] == "river":
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
			if tiles[y][x]["type"] == "river":
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
			if tiles[y][x]["type"] == "river":
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
			if tiles[y][x]["type"] == "river":
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
			if tiles[y][x]["type"] == "river":
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

func generate_deposits():
	# Deposits are clustered so they stay meaningful instead of becoming visual noise.
	for _iron_cluster in range(4):
		var iron_center: Vector2 = find_resource_cluster_center("iron")
		if iron_center.x >= 0:
			make_resource_cluster(iron_center, rng.randi_range(2, 4), "iron", 0.48)

	for _stone_cluster in range(6):
		var stone_center: Vector2 = find_resource_cluster_center("stone")
		if stone_center.x >= 0:
			make_resource_cluster(stone_center, rng.randi_range(2, 5), "stone", 0.52)

func find_resource_cluster_center(resource_type: String) -> Vector2:
	var candidates: Array[Vector2] = []

	for y in range(map_height):
		for x in range(map_width):
			if tiles[y][x]["type"] == "river":
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
			if tiles[y][x]["type"] == "river":
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
