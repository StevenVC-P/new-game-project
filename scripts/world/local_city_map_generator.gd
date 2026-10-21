class_name LocalCityMapGenerator
extends RefCounted

var rng: RandomNumberGenerator
var city_map_width: int = 64
var city_map_height: int = 44
var region_map_width: int = 80
var region_map_height: int = 50
var river_near_range: int = 5
var city_resource_range: int = 7

func _init(random_source: RandomNumberGenerator, local_width: int, local_height: int, regional_width: int, regional_height: int, river_range: int, resource_range: int):
	rng = random_source
	city_map_width = local_width
	city_map_height = local_height
	region_map_width = regional_width
	region_map_height = regional_height
	river_near_range = river_range
	city_resource_range = resource_range

func generate(city: City, regional_tiles: Array, city_index: int) -> Array:
	var local_map: Array = []
	var context: Dictionary = get_city_site_context(city, regional_tiles)
	var morphology: String = get_settlement_morphology(city.site_profile)
	print("Generating local map for ", city.name, ": ", city.site_profile.get_tag_text(), "; anchor=", city.tile, ", river=", city.site_profile.format_ratio(city.site_profile.river_influence), " dir=", city.site_profile.format_vector(city.site_profile.river_direction), " dist=", city.site_profile.nearest_river_distance, ", fertility=", city.site_profile.format_ratio(city.site_profile.fertility), ", forest=", city.site_profile.format_ratio(city.site_profile.forest_density), " dir=", city.site_profile.format_vector(city.site_profile.forest_direction), ", rough=", city.site_profile.format_ratio(city.site_profile.roughness), " dir=", city.site_profile.format_vector(city.site_profile.rough_direction), ", stone=", city.site_profile.format_ratio(city.site_profile.stone_access), ", iron=", city.site_profile.format_ratio(city.site_profile.iron_access))
	print("Local map sample diagnostics for ", city.name, ": ", city.site_profile.get_directional_debug_summary())

	for y in range(city_map_height):
		var row: Array = []
		for x in range(city_map_width):
			row.append({
				"type": "ground",
				"has_trees": false,
				"is_fertile": false,
				"occupied": false
			})
		local_map.append(row)

	if context["near_river"] == true:
		add_city_water_feature(local_map, context["river_direction"] as Vector2, int(context["river_distance"]))
		add_city_fertile_bank(local_map, context["river_direction"] as Vector2)

	apply_settlement_morphology(local_map, city_index, context, morphology)

	if context["rough_score"] > 0:
		add_city_rough_patches(local_map, city_index, int(context["rough_score"]), context["rough_direction"] as Vector2)

	if context["stone_score"] > 0:
		add_city_stone_clusters(local_map, city_index, int(context["stone_score"]), context["resource_direction"] as Vector2)

	add_city_tree_patches(local_map, city_index, int(context["forest_score"]), context["forest_direction"] as Vector2)
	ensure_minimum_settlement_pockets(local_map, morphology)
	print("Settlement morphology for ", city.name, ": ", morphology, "; buildable=", count_buildable_tiles(local_map), ", fertile=", count_fertile_tiles(local_map), ", blocked=", count_blocked_tiles(local_map))

	return local_map

func get_city_site_context(city: City, regional_tiles: Array) -> Dictionary:
	if city.site_profile != null and is_site_profile_analyzed(city.site_profile):
		return get_context_from_site_profile(city.site_profile)

	var region_tile: Vector2 = city.tile
	return get_city_region_context(regional_tiles, int(region_tile.x), int(region_tile.y))

func is_site_profile_analyzed(profile: SettlementSiteProfile) -> bool:
	var total_influence: float = profile.river_influence + profile.fertility + profile.forest_density + profile.roughness + profile.stone_access + profile.iron_access + profile.openness + profile.trade_position
	return total_influence > 0.0

func get_context_from_site_profile(profile: SettlementSiteProfile) -> Dictionary:
	var sample_area: int = get_profile_sample_area()
	var forest_score: int = int(round(profile.forest_density * float(sample_area)))
	var rough_score: int = int(round(profile.roughness * float(sample_area)))
	var stone_score: int = int(round(profile.stone_access * float(sample_area)))
	var iron_score: int = int(round(profile.iron_access * float(sample_area)))
	var plains_score: int = int(round(profile.openness * float(sample_area)))

	return {
		"near_river": profile.river_influence > 0.0 or profile.tags.has("river_settlement"),
		"forest_score": forest_score,
		"plains_score": plains_score,
		"rough_score": rough_score,
		"stone_score": stone_score + iron_score,
		"iron_score": iron_score,
		"river_direction": profile.river_direction,
		"forest_direction": profile.forest_direction,
		"rough_direction": profile.rough_direction,
		"resource_direction": profile.resource_direction,
		"river_distance": profile.nearest_river_distance
	}

func get_profile_sample_area() -> int:
	return int(round(PI * float(city_resource_range) * float(city_resource_range)))

func get_settlement_morphology(profile: SettlementSiteProfile) -> String:
	if profile.tags.has("river_settlement"):
		return "linear_riverside_build_area"
	if profile.tags.has("forest_settlement"):
		return "fragmented_woodland_clearings"
	if profile.tags.has("mining_region") or profile.tags.has("mountain_edge") or profile.tags.has("hill_settlement"):
		return "constrained_plateau_pockets"
	if profile.tags.has("open_plains"):
		return "broad_open_site"

	return "mixed_borderland_pockets"

func apply_settlement_morphology(local_map: Array, city_index: int, context: Dictionary, morphology: String):
	if morphology == "linear_riverside_build_area":
		add_riverside_settlement_clearings(local_map, city_index, context["river_direction"] as Vector2)
	elif morphology == "fragmented_woodland_clearings":
		add_fragmented_forest_clearings(local_map, city_index)
	elif morphology == "constrained_plateau_pockets":
		add_constrained_plateau_clearings(local_map, city_index, context["rough_direction"] as Vector2)
	elif morphology == "broad_open_site":
		add_open_plains_clearings(local_map, city_index)
	else:
		add_mixed_borderland_clearings(local_map, city_index)

func add_riverside_settlement_clearings(local_map: Array, city_index: int, river_direction: Vector2):
	var direction: Vector2 = get_direction_or_default(river_direction, Vector2(-1.0, 0.0))
	var first_center: Vector2 = get_river_parallel_center(direction, 17.0, -7.0 + float(city_index * 2))
	var second_center: Vector2 = get_river_parallel_center(direction, 24.0, 8.0 - float(city_index * 2))
	make_organic_city_patch(local_map, first_center, 9, "clearing", 0.78, 0.48)
	make_organic_city_patch(local_map, second_center, 7, "clearing", 0.66, 0.42)

func add_fragmented_forest_clearings(local_map: Array, city_index: int):
	var centers: Array[Vector2] = [
		get_city_site_center() + Vector2(-8.0 + float(city_index * 2), -5.0),
		get_city_site_center() + Vector2(9.0, 7.0 - float(city_index * 2)),
		get_city_site_center() + Vector2(-2.0, 12.0)
	]

	for center: Vector2 in centers:
		make_organic_city_patch(local_map, center, rng.randi_range(5, 8), "clearing", 0.62, 0.55)

func add_constrained_plateau_clearings(local_map: Array, city_index: int, rough_direction: Vector2):
	var away_from_rough: Vector2 = -get_direction_or_default(rough_direction, Vector2(1.0, 0.0))
	var first_center: Vector2 = get_city_site_center() + away_from_rough * 6.0 + Vector2(float(city_index * 2), -4.0)
	var second_center: Vector2 = get_city_site_center() + away_from_rough * 12.0 + Vector2(-6.0, 8.0)
	make_organic_city_patch(local_map, first_center, 7, "clearing", 0.68, 0.40)
	make_organic_city_patch(local_map, second_center, 5, "clearing", 0.56, 0.35)

func add_open_plains_clearings(local_map: Array, city_index: int):
	make_organic_city_patch(local_map, get_city_site_center() + Vector2(float(city_index * 2), 0.0), 12, "clearing", 0.82, 0.35)
	make_organic_city_patch(local_map, get_city_site_center() + Vector2(-13.0, -6.0), 7, "clearing", 0.64, 0.32)
	make_organic_city_patch(local_map, get_city_site_center() + Vector2(12.0, 8.0), 6, "clearing", 0.58, 0.32)

func add_mixed_borderland_clearings(local_map: Array, city_index: int):
	make_organic_city_patch(local_map, get_city_site_center() + Vector2(-6.0 + float(city_index * 2), -3.0), 8, "clearing", 0.68, 0.44)
	make_organic_city_patch(local_map, get_city_site_center() + Vector2(10.0, 8.0), 6, "clearing", 0.54, 0.40)

func make_organic_city_patch(local_map: Array, center: Vector2, radius: int, tile_type: String, chance: float, raggedness: float):
	for y in range(int(center.y) - radius, int(center.y) + radius + 1):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			if not is_inside_city_map(x, y):
				continue

			var position: Vector2 = Vector2(x, y)
			var distance: float = center.distance_to(position)
			var local_noise: float = get_position_noise(x, y, radius)
			var edge_variation: float = 1.0 + (local_noise - 0.5) * raggedness
			if distance > float(radius) * edge_variation:
				continue

			var falloff: float = 1.0 - (distance / max(1.0, float(radius))) * 0.45
			if rng.randf() > chance * falloff:
				continue

			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["type"] == "water":
				continue
			tile["type"] = tile_type
			if tile_type == "clearing":
				tile["has_trees"] = false
				tile["is_fertile"] = true

func get_position_noise(x: int, y: int, salt: int) -> float:
	var value: int = abs(x * 73856093 + y * 19349663 + salt * 83492791)
	return float(value % 1000) / 1000.0

func get_city_region_context(regional_tiles: Array, region_x: int, region_y: int) -> Dictionary:
	var forest_score: int = 0
	var plains_score: int = 0
	var rough_score: int = 0
	var stone_score: int = 0
	var iron_score: int = 0
	var near_river: bool = is_near_river(regional_tiles, region_x, region_y)
	var search_range: int = city_resource_range

	for y in range(max(0, region_y - search_range), min(region_map_height, region_y + search_range + 1)):
		for x in range(max(0, region_x - search_range), min(region_map_width, region_x + search_range + 1)):
			var tile: Dictionary = regional_tiles[y][x] as Dictionary
			if tile["has_forest"] == true:
				forest_score += 1
			if tile["type"] == "grass" and tile["has_forest"] == false:
				plains_score += 1
			if tile["type"] == "hill" or tile["type"] == "mountain":
				rough_score += 1
			if tile["resource"] == "stone":
				stone_score += 1
			if tile["resource"] == "iron":
				iron_score += 1

	return {
		"near_river": near_river,
		"forest_score": forest_score,
		"plains_score": plains_score,
		"rough_score": rough_score,
		"stone_score": stone_score,
		"iron_score": iron_score,
		"river_direction": get_nearest_terrain_direction(regional_tiles, region_x, region_y, "river", search_range),
		"forest_direction": get_nearest_feature_direction(regional_tiles, region_x, region_y, "forest", search_range),
		"rough_direction": get_nearest_feature_direction(regional_tiles, region_x, region_y, "rough", search_range),
		"resource_direction": get_nearest_feature_direction(regional_tiles, region_x, region_y, "resource", search_range),
		"river_distance": get_nearest_terrain_distance(regional_tiles, region_x, region_y, "river", search_range)
	}

func make_city_patch(local_map: Array, center: Vector2, radius: int, tile_type: String, chance: float):
	for y in range(int(center.y) - radius, int(center.y) + radius + 1):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			if not is_inside_city_map(x, y):
				continue

			var distance: float = center.distance_to(Vector2(x, y))
			if distance > radius:
				continue

			var falloff: float = 1.0 - (distance / float(radius)) * 0.35
			if rng.randf() > chance * falloff:
				continue

			var tile: Dictionary = local_map[y][x] as Dictionary
			tile["type"] = tile_type
			if tile_type == "water" or tile_type == "rough" or tile_type == "clearing":
				tile["has_trees"] = false
			if tile_type == "clearing":
				tile["is_fertile"] = true
			elif tile_type == "water" or tile_type == "rough":
				tile["is_fertile"] = false

func add_city_water_feature(local_map: Array, river_direction: Vector2, river_distance: int):
	# River-adjacent cities get a local riverbank or creek edge, not a regional river band.
	var direction: Vector2 = get_direction_or_default(river_direction, Vector2(-1.0, 0.0))
	var water_width: int = get_local_water_width(river_distance)

	if abs(direction.x) >= abs(direction.y):
		add_vertical_edge_water(local_map, direction.x < 0.0, water_width)
	else:
		add_horizontal_edge_water(local_map, direction.y < 0.0, water_width)

func get_local_water_width(river_distance: int) -> int:
	if river_distance >= 0 and river_distance <= 1:
		return 11
	if river_distance >= 0 and river_distance <= 3:
		return 8

	return 5

func add_vertical_edge_water(local_map: Array, use_west_edge: bool, water_width: int):
	var bank_x: float = float(water_width)
	if not use_west_edge:
		bank_x = float(city_map_width - water_width)

	for y in range(city_map_height):
		bank_x += rng.randf_range(-0.25, 0.25)
		if use_west_edge:
			bank_x = clamp(bank_x, 2.0, 15.0)
			for x in range(0, int(bank_x)):
				set_local_water_tile(local_map, x, y)
			set_local_fertile_bank_tile(local_map, int(bank_x) + 1, y)
		else:
			bank_x = clamp(bank_x, float(city_map_width - 15), float(city_map_width - 2))
			for x in range(int(bank_x), city_map_width):
				set_local_water_tile(local_map, x, y)
			set_local_fertile_bank_tile(local_map, int(bank_x) - 1, y)

func add_horizontal_edge_water(local_map: Array, use_north_edge: bool, water_width: int):
	var bank_y: float = float(water_width)
	if not use_north_edge:
		bank_y = float(city_map_height - water_width)

	for x in range(city_map_width):
		bank_y += rng.randf_range(-0.25, 0.25)
		if use_north_edge:
			bank_y = clamp(bank_y, 2.0, 12.0)
			for y in range(0, int(bank_y)):
				set_local_water_tile(local_map, x, y)
			set_local_fertile_bank_tile(local_map, x, int(bank_y) + 1)
		else:
			bank_y = clamp(bank_y, float(city_map_height - 12), float(city_map_height - 2))
			for y in range(int(bank_y), city_map_height):
				set_local_water_tile(local_map, x, y)
			set_local_fertile_bank_tile(local_map, x, int(bank_y) - 1)

func set_local_water_tile(local_map: Array, x: int, y: int):
	if not is_inside_city_map(x, y):
		return

	var water_tile: Dictionary = local_map[y][x] as Dictionary
	water_tile["type"] = "water"
	water_tile["has_trees"] = false
	water_tile["is_fertile"] = false

func set_local_fertile_bank_tile(local_map: Array, x: int, y: int):
	if not is_inside_city_map(x, y):
		return

	var bank_tile: Dictionary = local_map[y][x] as Dictionary
	if bank_tile["type"] != "water":
		bank_tile["type"] = "ground"
		bank_tile["is_fertile"] = true

func add_city_fertile_bank(local_map: Array, river_direction: Vector2):
	var direction: Vector2 = get_direction_or_default(river_direction, Vector2(-1.0, 0.0))
	for y in range(city_map_height):
		for x in range(city_map_width):
			if not is_inside_city_map(x, y):
				continue
			if is_near_city_center(x, y, 10):
				continue
			if not is_near_directional_edge(x, y, direction, 20):
				continue

			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["type"] == "ground" and rng.randf() < 0.45:
				tile["type"] = "clearing"
				tile["has_trees"] = false
				tile["is_fertile"] = true

func get_river_parallel_center(direction: Vector2, distance_from_edge: float, lane_offset: float) -> Vector2:
	if abs(direction.x) >= abs(direction.y):
		var x: float = distance_from_edge
		if direction.x > 0.0:
			x = float(city_map_width) - distance_from_edge
		return Vector2(x, clamp(float(city_map_height) * 0.5 + lane_offset, 5.0, float(city_map_height - 5)))

	var y: float = distance_from_edge
	if direction.y > 0.0:
		y = float(city_map_height) - distance_from_edge
	return Vector2(clamp(float(city_map_width) * 0.5 + lane_offset, 5.0, float(city_map_width - 5)), y)

func add_city_rough_patches(local_map: Array, city_index: int, rough_score: int, rough_direction: Vector2):
	var extra_radius: int = int(clamp(rough_score / 12, 0, 3))
	var first_center: Vector2 = get_edge_center_from_direction(rough_direction, Vector2(1.0, 0.0), 8.0, city_index)
	var second_center: Vector2 = get_edge_center_from_direction(rough_direction, Vector2(1.0, 1.0), 13.0, city_index + 2)
	make_city_patch(local_map, first_center, 6 + extra_radius, "rough", 0.64)
	make_city_patch(local_map, second_center, 5 + extra_radius, "rough", 0.52)

func add_city_stone_clusters(local_map: Array, city_index: int, stone_score: int, resource_direction: Vector2):
	var cluster_count: int = int(clamp(1 + stone_score / 4, 1, 4))

	for cluster_index in range(cluster_count):
		var center: Vector2 = get_edge_center_from_direction(resource_direction, Vector2(1.0, 0.0), 7.0 + float(cluster_index * 4), city_index + cluster_index)
		make_city_patch(local_map, center, rng.randi_range(2, 4), "rough", 0.62)

func add_city_tree_patches(local_map: Array, city_index: int, forest_score: int, forest_direction: Vector2):
	var forest_bonus: int = int(clamp(forest_score / 10, 0, 4))
	var tree_chance: float = 0.48 + float(forest_bonus) * 0.05
	var directional_center: Vector2 = get_edge_center_from_direction(forest_direction, Vector2(-1.0, 0.0), 8.0, city_index)
	var tree_centers: Array[Vector2] = [
		directional_center,
		get_edge_center_from_direction(forest_direction, Vector2(-1.0, -1.0), 12.0, city_index + 1),
		Vector2(8 + city_index * 8, city_map_height - 7),
		Vector2(city_map_width - 15, city_map_height - 8)
	]

	for tree_center: Vector2 in tree_centers:
		add_city_tree_patch(local_map, tree_center, rng.randi_range(6, 10 + forest_bonus), tree_chance)

func add_city_tree_patch(local_map: Array, center: Vector2, radius: int, chance: float):
	for y in range(int(center.y) - radius, int(center.y) + radius + 1):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			if not is_inside_city_map(x, y):
				continue

			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["type"] == "water" or tile["type"] == "rough":
				continue
			if is_near_city_center(x, y, 13):
				continue

			var distance: float = center.distance_to(Vector2(x, y))
			if distance > radius:
				continue

			var falloff: float = 1.0 - (distance / float(radius)) * 0.55
			if rng.randf() < chance * falloff:
				tile["has_trees"] = true
				if tile["type"] == "clearing" and rng.randf() < 0.80:
					tile["has_trees"] = false

func ensure_minimum_settlement_pockets(local_map: Array, morphology: String):
	var buildable_tiles: int = count_buildable_tiles(local_map)
	var fertile_tiles: int = count_fertile_tiles(local_map)

	if buildable_tiles < 180:
		make_organic_city_patch(local_map, get_city_site_center(), 6, "clearing", 0.72, 0.55)

	if fertile_tiles < 18 and morphology != "constrained_plateau_pockets":
		make_organic_city_patch(local_map, get_city_site_center() + Vector2(-5.0, 4.0), 4, "clearing", 0.58, 0.50)

func count_buildable_tiles(local_map: Array) -> int:
	var count: int = 0
	for y in range(city_map_height):
		for x in range(city_map_width):
			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["type"] != "water" and tile["type"] != "rough" and tile["has_trees"] == false:
				count += 1

	return count

func count_fertile_tiles(local_map: Array) -> int:
	var count: int = 0
	for y in range(city_map_height):
		for x in range(city_map_width):
			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["is_fertile"] == true:
				count += 1

	return count

func count_blocked_tiles(local_map: Array) -> int:
	var count: int = 0
	for y in range(city_map_height):
		for x in range(city_map_width):
			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["type"] == "water" or tile["type"] == "rough" or tile["has_trees"] == true:
				count += 1

	return count

func get_city_site_center() -> Vector2:
	return Vector2(city_map_width * 0.5, city_map_height * 0.5)

func is_near_city_center(x: int, y: int, radius: int) -> bool:
	return get_city_site_center().distance_to(Vector2(x, y)) <= radius

func is_inside_city_map(x: int, y: int) -> bool:
	return x >= 0 and x < city_map_width and y >= 0 and y < city_map_height

func get_direction_or_default(direction: Vector2, fallback: Vector2) -> Vector2:
	if direction.length() <= 0.001:
		return fallback.normalized()

	return direction.normalized()

func is_near_directional_edge(x: int, y: int, direction: Vector2, edge_depth: int) -> bool:
	if abs(direction.x) >= abs(direction.y):
		if direction.x < 0.0:
			return x <= edge_depth
		return x >= city_map_width - edge_depth

	if direction.y < 0.0:
		return y <= edge_depth
	return y >= city_map_height - edge_depth

func get_edge_center_from_direction(direction: Vector2, fallback: Vector2, edge_offset: float, lane_seed: int) -> Vector2:
	var resolved_direction: Vector2 = get_direction_or_default(direction, fallback)
	var center: Vector2 = get_city_site_center()
	var lane_shift: float = float((lane_seed % 5) - 2) * 4.0

	if abs(resolved_direction.x) >= abs(resolved_direction.y):
		var x: float = edge_offset
		if resolved_direction.x > 0.0:
			x = float(city_map_width) - edge_offset
		return Vector2(x, clamp(center.y + lane_shift, 6.0, float(city_map_height - 6)))

	var y: float = edge_offset
	if resolved_direction.y > 0.0:
		y = float(city_map_height) - edge_offset
	return Vector2(clamp(center.x + lane_shift, 6.0, float(city_map_width - 6)), y)

func is_near_river(regional_tiles: Array, x: int, y: int) -> bool:
	return is_near_terrain_with_range(regional_tiles, x, y, "river", river_near_range)

func is_near_terrain_with_range(regional_tiles: Array, x: int, y: int, terrain_type: String, search_range: int) -> bool:
	for yy in range(max(0, y - search_range), min(region_map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(region_map_width, x + search_range + 1)):
			if regional_tiles[yy][xx]["type"] == terrain_type:
				return true

	return false

func get_nearest_terrain_direction(regional_tiles: Array, x: int, y: int, terrain_type: String, search_range: int) -> Vector2:
	var nearest_offset: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF

	for yy in range(max(0, y - search_range), min(region_map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(region_map_width, x + search_range + 1)):
			if regional_tiles[yy][xx]["type"] != terrain_type:
				continue

			var offset: Vector2 = Vector2(xx - x, yy - y)
			var distance: float = offset.length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_offset = offset

	return get_direction_or_default(nearest_offset, Vector2.ZERO)

func get_nearest_terrain_distance(regional_tiles: Array, x: int, y: int, terrain_type: String, search_range: int) -> int:
	var nearest_distance: float = INF

	for yy in range(max(0, y - search_range), min(region_map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(region_map_width, x + search_range + 1)):
			if regional_tiles[yy][xx]["type"] != terrain_type:
				continue

			var distance: float = Vector2(xx - x, yy - y).length()
			nearest_distance = min(nearest_distance, distance)

	if is_inf(nearest_distance):
		return -1

	return int(round(nearest_distance))

func get_nearest_feature_direction(regional_tiles: Array, x: int, y: int, feature_type: String, search_range: int) -> Vector2:
	var nearest_offset: Vector2 = Vector2.ZERO
	var nearest_distance: float = INF

	for yy in range(max(0, y - search_range), min(region_map_height, y + search_range + 1)):
		for xx in range(max(0, x - search_range), min(region_map_width, x + search_range + 1)):
			var tile: Dictionary = regional_tiles[yy][xx] as Dictionary
			if not tile_matches_feature(tile, feature_type):
				continue

			var offset: Vector2 = Vector2(xx - x, yy - y)
			var distance: float = offset.length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_offset = offset

	return get_direction_or_default(nearest_offset, Vector2.ZERO)

func tile_matches_feature(tile: Dictionary, feature_type: String) -> bool:
	if feature_type == "forest":
		return tile["has_forest"] == true
	if feature_type == "rough":
		return tile["type"] == "hill" or tile["type"] == "mountain"
	if feature_type == "resource":
		return tile["resource"] == "stone" or tile["resource"] == "iron"

	return false
