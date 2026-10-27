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
# Checked by the owner of the continuous regional map, which knows the climate.
const REASON_FROZEN: String = "Frozen ground: too cold to settle"

# Free settlers may not found towns on land a kingdom holds (checked by the owner of the
# continuous regional map, which knows the political map).
static func kingdom_land_reason(kingdom_name: String) -> String:
	return "Held by %s: free settlers cannot found here" % kingdom_name

static func is_valid_founding_tile(tiles: Array, cities: Array[City], tile_pos: Vector2i, min_city_distance: int) -> bool:
	var town_tiles: PackedVector2Array = PackedVector2Array()
	for city: City in cities:
		if city != null:
			town_tiles.append(city.tile)
	return is_valid_founding_site(tiles, town_tiles, tile_pos, min_city_distance)

# The same rule from town positions alone, so it can run where City objects are not at hand
# (preparing a regional neighbourhood on a worker thread). A town on the tile is closer than
# the minimum distance, so it needs no separate check.
static func is_valid_founding_site(tiles: Array, town_tiles: PackedVector2Array, tile_pos: Vector2i, min_city_distance: int) -> bool:
	if not is_inside_tiles(tiles, tile_pos):
		return false
	var tile: Dictionary = tiles[tile_pos.y][tile_pos.x] as Dictionary
	var tile_type: String = tile.get("type", "")
	if tile_type == "river" or tile_type == "lake" or tile_type == "sea" or tile_type == "mountain":
		return false
	if tile.get("has_forest", false) == true or tile.get("resource", "none") != "none":
		return false
	var site: Vector2 = Vector2(tile_pos)
	for town: Vector2 in town_tiles:
		if site.distance_to(town) < float(min_city_distance):
			return false
	return true

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
