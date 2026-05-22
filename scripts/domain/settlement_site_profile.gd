class_name SettlementSiteProfile
extends RefCounted

# Persistent geographic identity for a settlement site.
# This is metadata only for now; future systems can use it for local maps,
# economic tendencies, migration attraction, values, and culture.

const ANALYSIS_RADIUS: int = 7

var river_influence: float = 0.0
var fertility: float = 0.0
var forest_density: float = 0.0
var roughness: float = 0.0
var mountain_pressure: float = 0.0
var stone_access: float = 0.0
var iron_access: float = 0.0
var trade_position: float = 0.0
var openness: float = 0.0
var nearest_river_distance: int = -1
var nearest_forest_distance: int = -1
var nearest_rough_distance: int = -1
var nearest_resource_distance: int = -1
var river_direction: Vector2 = Vector2.ZERO
var forest_direction: Vector2 = Vector2.ZERO
var rough_direction: Vector2 = Vector2.ZERO
var resource_direction: Vector2 = Vector2.ZERO
var sampled_bounds: Rect2i = Rect2i()
var directional_counts: Dictionary = {}
var tags: Array[String] = []

static func analyze(city_tile: Vector2, regional_tiles: Array, radius: int = ANALYSIS_RADIUS) -> SettlementSiteProfile:
	var profile: SettlementSiteProfile = SettlementSiteProfile.new()
	profile.analyze_site(city_tile, regional_tiles, radius)
	return profile

func analyze_site(city_tile: Vector2, regional_tiles: Array, radius: int = ANALYSIS_RADIUS):
	var map_height: int = regional_tiles.size()
	if map_height <= 0:
		return
	var first_row: Array = regional_tiles[0] as Array
	var map_width: int = first_row.size()
	if map_width <= 0:
		return

	var center_x: int = int(city_tile.x)
	var center_y: int = int(city_tile.y)
	var min_x: int = max(0, center_x - radius)
	var max_x: int = min(map_width - 1, center_x + radius)
	var min_y: int = max(0, center_y - radius)
	var max_y: int = min(map_height - 1, center_y + radius)
	var total_tiles: int = 0
	var river_tiles: int = 0
	var fertile_tiles: int = 0
	var forest_tiles: int = 0
	var hill_tiles: int = 0
	var mountain_tiles: int = 0
	var stone_tiles: int = 0
	var iron_tiles: int = 0
	var road_tiles: int = 0
	var open_tiles: int = 0
	var river_vector_sum: Vector2 = Vector2.ZERO
	var forest_vector_sum: Vector2 = Vector2.ZERO
	var rough_vector_sum: Vector2 = Vector2.ZERO
	var resource_vector_sum: Vector2 = Vector2.ZERO
	var nearest_river: float = INF
	var nearest_forest: float = INF
	var nearest_rough: float = INF
	var nearest_resource: float = INF

	sampled_bounds = Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))
	directional_counts = make_empty_directional_counts()

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var tile_pos: Vector2 = Vector2(x, y)
			var distance: float = tile_pos.distance_to(city_tile)
			if distance > float(radius):
				continue

			var tile: Dictionary = regional_tiles[y][x] as Dictionary
			var tile_type: String = tile["type"] as String
			var resource_type: String = tile["resource"] as String
			var offset: Vector2 = tile_pos - city_tile
			var weighted_offset: Vector2 = get_weighted_offset(offset)
			total_tiles += 1

			if tile_type == "river":
				river_tiles += 1
				river_vector_sum += weighted_offset
				nearest_river = min(nearest_river, distance)
				increment_directional_count("river", offset)
			if tile["is_fertile"] == true:
				fertile_tiles += 1
			if tile["has_forest"] == true:
				forest_tiles += 1
				forest_vector_sum += weighted_offset
				nearest_forest = min(nearest_forest, distance)
				increment_directional_count("forest", offset)
			if tile_type == "hill":
				hill_tiles += 1
				rough_vector_sum += weighted_offset
				nearest_rough = min(nearest_rough, distance)
				increment_directional_count("rough", offset)
			if tile_type == "mountain":
				mountain_tiles += 1
				rough_vector_sum += weighted_offset
				nearest_rough = min(nearest_rough, distance)
				increment_directional_count("rough", offset)
			if resource_type == "stone":
				stone_tiles += 1
				resource_vector_sum += weighted_offset
				nearest_resource = min(nearest_resource, distance)
				increment_directional_count("resource", offset)
			elif resource_type == "iron":
				iron_tiles += 1
				resource_vector_sum += weighted_offset
				nearest_resource = min(nearest_resource, distance)
				increment_directional_count("resource", offset)
			if tile["has_road"] == true:
				road_tiles += 1
			if tile_type == "grass" and tile["has_forest"] == false and resource_type == "none":
				open_tiles += 1

	if total_tiles <= 0:
		return

	river_influence = ratio(river_tiles, total_tiles)
	fertility = ratio(fertile_tiles, total_tiles)
	forest_density = ratio(forest_tiles, total_tiles)
	roughness = ratio(hill_tiles + mountain_tiles, total_tiles)
	mountain_pressure = ratio(mountain_tiles, total_tiles)
	stone_access = ratio(stone_tiles, total_tiles)
	iron_access = ratio(iron_tiles, total_tiles)
	trade_position = ratio(road_tiles, total_tiles)
	openness = ratio(open_tiles, total_tiles)
	river_direction = normalize_or_zero(river_vector_sum)
	forest_direction = normalize_or_zero(forest_vector_sum)
	rough_direction = normalize_or_zero(rough_vector_sum)
	resource_direction = normalize_or_zero(resource_vector_sum)
	nearest_river_distance = distance_to_int(nearest_river)
	nearest_forest_distance = distance_to_int(nearest_forest)
	nearest_rough_distance = distance_to_int(nearest_rough)
	nearest_resource_distance = distance_to_int(nearest_resource)
	update_tags()

func update_tags():
	tags.clear()

	if river_influence >= 0.04:
		tags.append("river_settlement")
	if fertility >= 0.16:
		tags.append("fertile_valley")
	if forest_density >= 0.16:
		tags.append("forest_settlement")
	if roughness >= 0.14:
		tags.append("hill_settlement")
	if mountain_pressure >= 0.06:
		tags.append("mountain_edge")
	if stone_access >= 0.025 or iron_access >= 0.025:
		tags.append("mining_region")
	if trade_position >= 0.08:
		tags.append("crossroads")
	if openness >= 0.44 and forest_density < 0.12 and roughness < 0.10:
		tags.append("open_plains")
	if trade_position < 0.02 and river_influence < 0.02:
		tags.append("isolated")

func get_tag_text() -> String:
	if tags.is_empty():
		return "ordinary_site"

	var text: String = tags[0]
	for tag_index in range(1, tags.size()):
		text += ", " + tags[tag_index]

	return text

func get_debug_summary() -> String:
	return get_tag_text() + " | river " + format_ratio(river_influence) + " dir " + format_vector(river_direction) + " dist " + str(nearest_river_distance) + ", fertile " + format_ratio(fertility) + ", forest " + format_ratio(forest_density) + " dir " + format_vector(forest_direction) + ", rough " + format_ratio(roughness) + " dir " + format_vector(rough_direction) + ", stone " + format_ratio(stone_access) + ", iron " + format_ratio(iron_access) + ", trade " + format_ratio(trade_position)

func get_directional_debug_summary() -> String:
	return "bounds " + str(sampled_bounds.position) + " size " + str(sampled_bounds.size) + " counts " + str(directional_counts)

func ratio(count: int, total: int) -> float:
	if total <= 0:
		return 0.0

	return float(count) / float(total)

func format_ratio(value: float) -> String:
	return str(snapped(value, 0.01))

func format_vector(value: Vector2) -> String:
	return "(" + str(snapped(value.x, 0.01)) + "," + str(snapped(value.y, 0.01)) + ")"

func get_weighted_offset(offset: Vector2) -> Vector2:
	var distance: float = max(1.0, offset.length())
	return offset / distance

func normalize_or_zero(value: Vector2) -> Vector2:
	if value.length() <= 0.001:
		return Vector2.ZERO

	return value.normalized()

func distance_to_int(value: float) -> int:
	if is_inf(value):
		return -1

	return int(round(value))

func make_empty_directional_counts() -> Dictionary:
	return {
		"river_n": 0,
		"river_e": 0,
		"river_s": 0,
		"river_w": 0,
		"forest_n": 0,
		"forest_e": 0,
		"forest_s": 0,
		"forest_w": 0,
		"rough_n": 0,
		"rough_e": 0,
		"rough_s": 0,
		"rough_w": 0,
		"resource_n": 0,
		"resource_e": 0,
		"resource_s": 0,
		"resource_w": 0
	}

func increment_directional_count(prefix: String, offset: Vector2):
	var suffix: String = get_direction_suffix(offset)
	var key: String = prefix + "_" + suffix
	if directional_counts.has(key):
		directional_counts[key] = int(directional_counts[key]) + 1

func get_direction_suffix(offset: Vector2) -> String:
	if abs(offset.x) >= abs(offset.y):
		if offset.x >= 0.0:
			return "e"
		return "w"

	if offset.y >= 0.0:
		return "s"
	return "n"
