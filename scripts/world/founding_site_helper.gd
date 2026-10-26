class_name FoundingSiteHelper
extends RefCounted

const VALID_FOUNDING_SITE: String = "Valid founding site"
const REASON_OUTSIDE_REGION: String = "Outside region"
const REASON_RIVER: String = "Cannot found on river"
const REASON_WATER: String = "Cannot found on open water"
const REASON_MOUNTAIN: String = "Cannot found on mountain"
const REASON_FOREST: String = "Cannot found in forest"
const REASON_RESOURCE: String = "Cannot found on resource deposit"
const REASON_OCCUPIED: String = "Tile already occupied"
const REASON_TOO_CLOSE_NEUTRAL: String = "Too close to neutral town"
const REASON_TOO_CLOSE_TOWN: String = "Too close to existing town"

static func is_valid_founding_tile(tiles: Array, cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> bool:
	return get_founding_tile_invalid_reason(tiles, cities, tile_pos, min_city_distance) == VALID_FOUNDING_SITE

static func get_founding_tile_invalid_reason(tiles: Array, cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> String:
	if not is_inside_tiles(tiles, tile_pos):
		return REASON_OUTSIDE_REGION

	if is_city_at_tile(cities, tile_pos):
		return REASON_OCCUPIED

	var tile: Dictionary = tiles[tile_pos.y][tile_pos.x] as Dictionary
	if tile.get("type", "") == "river":
		return REASON_RIVER
	if tile.get("type", "") == "lake" or tile.get("type", "") == "sea":
		return REASON_WATER
	if tile.get("type", "") == "mountain":
		return REASON_MOUNTAIN
	if tile.get("has_forest", false) == true:
		return REASON_FOREST
	if tile.get("resource", "none") != "none":
		return REASON_RESOURCE
	if is_too_close_to_city(cities, tile_pos, min_city_distance):
		if is_too_close_to_neutral_city(cities, tile_pos, min_city_distance):
			return REASON_TOO_CLOSE_NEUTRAL
		return REASON_TOO_CLOSE_TOWN

	return VALID_FOUNDING_SITE

static func is_inside_tiles(tiles: Array, tile_pos: Vector2i) -> bool:
	if tile_pos.y < 0 or tile_pos.y >= tiles.size():
		return false
	var row: Array = tiles[tile_pos.y] as Array
	return tile_pos.x >= 0 and tile_pos.x < row.size()

static func is_city_at_tile(cities: Array[City], tile_pos: Vector2i) -> bool:
	for city: City in cities:
		if city == null:
			continue
		var founding_position: Vector2 = Vector2(tile_pos.x, tile_pos.y)
		if founding_position.distance_to(city.tile) == 0.0:
			return true
	return false

static func is_too_close_to_city(cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> bool:
	for city: City in cities:
		if city == null:
			continue
		var founding_position: Vector2 = Vector2(tile_pos.x, tile_pos.y)
		if founding_position.distance_to(city.tile) < float(min_city_distance):
			return true
	return false

static func is_too_close_to_neutral_city(cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> bool:
	for city: City in cities:
		if city == null:
			continue
		if not city.is_neutral_city():
			continue
		var founding_position: Vector2 = Vector2(tile_pos.x, tile_pos.y)
		if founding_position.distance_to(city.tile) < float(min_city_distance):
			return true
	return false
