class_name LocalCityMapGenerator
extends RefCounted

# Town maps magnify the regional land around their site (owner decision 2026-10-26). Each
# regional tile becomes TOWN_TILES_PER_REGIONAL_TILE town tiles on a side, so the 64x44 town
# map covers the 16x11 regional tiles around the site, about its catchment: the river, lake or
# coast, woods, high ground, deposits, and roads the regional map shows there are the town's.
#
# Regional values are blended between tile centers and broken up with noise, so coasts, wood
# edges, and outcrops curve instead of showing their regional squares. Noise is sampled at
# global town coordinates, so a site always gives the same town.
#
# What a regional tile cannot say is decided at town scale: which open land is arable (the
# regional fertile flag only marks land near water), small copses on open land, and floors
# that give every town room to start.
#
# Town tiles: "type" (ground, water, rough), "has_trees", "is_fertile", "occupied", and
# "water_kind" (river, lake, sea, or ""), "resource" (none, stone, iron), "has_road".

const TOWN_TILES_PER_REGIONAL_TILE: int = 4
# Bounded regional maps carry no climate; they read as the temperate valley they always were.
const DEFAULT_CLIMATE: Dictionary = {"temperature": 0.55, "moisture": 0.6, "family": "temperate", "tree_temperature": 0.55}

const FIELD_WATER: int = 0
const FIELD_MOUNTAIN: int = 1
const FIELD_HILL: int = 2
const FIELD_FOREST: int = 3
const FIELD_FERTILE: int = 4
const FIELD_DEPOSIT: int = 5
const FIELD_ROAD: int = 6
const FIELD_COUNT: int = 7

# Blended fields run 0..1 between tile centers; a town tile takes a feature above its
# threshold, after EDGE_NOISE has moved the edge. Water's threshold is below one half so a
# river stamped diagonally on the regional map stays one connected stream.
const EDGE_NOISE: float = 0.2
const WATER_THRESHOLD: float = 0.42
const FEATURE_THRESHOLD: float = 0.5
const DEPOSIT_THRESHOLD: float = 0.55
# Roads are narrower than the regional tile they cross: about three town tiles.
const ROAD_THRESHOLD: float = 0.62
# Share of hill land that is rock too steep to build on.
const HILL_OUTCROP_SHARE: float = 0.22
# Inside woods, the share of tiles that are glades.
const GLADE_SHARE: float = 0.08

# Arable share of open land outside the regional fertile flag, by climate: wet temperate land
# is mostly farmable in pockets; dry, frozen, and steep land much less.
const ARABLE_SHARE_POOR: float = 0.06
const ARABLE_SHARE_GOOD: float = 0.34
const HILL_ARABLE_FACTOR: float = 0.5
# Copses on open land, away from the town's center.
const COPSE_SHARE: float = 0.03
const COPSE_CENTER_DISTANCE: float = 7.0

# Floors kept from the original generator: every town has room to start.
const CENTER_CLEAR_RADIUS: float = 4.0
const MIN_BUILDABLE_TILES: int = 180
const MIN_FERTILE_TILES: int = 18
# A town with no woods in reach cannot cut wood; the original maps never had fewer tree tiles.
const MIN_TREE_TILES: int = 90

var width: int = 64
var height: int = 44
var edge_noise: FastNoiseLite = make_noise(4101, 0.11)
var detail_noise: FastNoiseLite = make_noise(4102, 0.23)
var pocket_noise: FastNoiseLite = make_noise(4103, 0.055)
var copse_noise: FastNoiseLite = make_noise(4104, 0.16)

# Regional window read by generate(): fields per regional tile, and which kind of water and
# deposit each tile holds.
var window_tiles: Array = []
var window_size: Vector2i = Vector2i.ZERO
# Regional tile -> its fields, filled as the blend reads them.
var field_cache: Dictionary = {}

func _init(local_width: int = 64, local_height: int = 44):
	width = local_width
	height = local_height

static func make_noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	return noise

# Regional tiles the map reads around its site, each way: its half-extent plus one for blending.
func regional_reach() -> Vector2i:
	var half: Vector2 = Vector2(width, height) * 0.5 / TOWN_TILES_PER_REGIONAL_TILE
	return Vector2i(ceili(half.x) + 1, ceili(half.y) + 1)

# The continuous map: reads a window cut around the site, so a site near the edge of the
# game's neighbourhood still gets the land beyond it.
func generate_from_terrain(terrain: RegionalTerrain, global_site: Vector2i, climate: Dictionary) -> Array:
	var reach: Vector2i = regional_reach()
	var window_origin: Vector2i = global_site - reach
	return generate(reach, terrain.extract_window(window_origin, reach * 2 + Vector2i.ONE), window_origin, climate)

# site: the town's regional tile in regional_tiles' coordinates. hash_origin: the global
# regional tile at regional_tiles' (0, 0), so noise follows the planet; outside the given
# tiles the nearest edge tile repeats.
func generate(site: Vector2i, regional_tiles: Array, hash_origin: Vector2i, climate: Dictionary) -> Array:
	window_tiles = regional_tiles
	window_size = Vector2i((regional_tiles[0] as Array).size(), regional_tiles.size()) if not regional_tiles.is_empty() else Vector2i.ZERO
	field_cache.clear()
	var town_origin: Vector2 = Vector2(hash_origin + site) * TOWN_TILES_PER_REGIONAL_TILE - Vector2(width, height) * 0.5 + Vector2(TOWN_TILES_PER_REGIONAL_TILE, TOWN_TILES_PER_REGIONAL_TILE) * 0.5
	var local_map: Array = []
	var hill_amount: PackedFloat32Array = PackedFloat32Array()
	var forest_amount: PackedFloat32Array = PackedFloat32Array()
	var fertile_amount: PackedFloat32Array = PackedFloat32Array()
	hill_amount.resize(width * height)
	forest_amount.resize(width * height)
	fertile_amount.resize(width * height)

	for y in range(height):
		var row: Array = []
		for x in range(width):
			var regional: Vector2 = Vector2(site) + Vector2(0.5, 0.5) + (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(width, height) * 0.5) / TOWN_TILES_PER_REGIONAL_TILE
			var global: Vector2 = town_origin + Vector2(x, y)
			var fields: PackedFloat32Array = blended_fields(regional)
			var edge: float = edge_noise.get_noise_2d(global.x, global.y) * EDGE_NOISE
			var tile: Dictionary = {"type": "ground", "has_trees": false, "is_fertile": false, "occupied": false, "water_kind": "", "resource": "none", "has_road": false}
			var i: int = y * width + x
			hill_amount[i] = fields[FIELD_HILL]
			forest_amount[i] = fields[FIELD_FOREST]
			fertile_amount[i] = fields[FIELD_FERTILE] + edge
			if fields[FIELD_WATER] + edge > WATER_THRESHOLD:
				tile["type"] = "water"
				tile["water_kind"] = dominant_kind(regional, "water")
			elif fields[FIELD_MOUNTAIN] + edge > FEATURE_THRESHOLD:
				tile["type"] = "rough"
			elif fields[FIELD_DEPOSIT] + edge > DEPOSIT_THRESHOLD:
				tile["type"] = "rough"
				tile["resource"] = dominant_kind(regional, "resource")
			elif fields[FIELD_ROAD] - absf(edge) * 0.5 > ROAD_THRESHOLD:
				tile["has_road"] = true
			elif fields[FIELD_FOREST] + edge > FEATURE_THRESHOLD:
				tile["has_trees"] = true
			row.append(tile)
		local_map.append(row)

	add_hill_outcrops(local_map, hill_amount, town_origin)
	add_glades(local_map, town_origin)
	clear_center(local_map)
	add_copses(local_map, forest_amount, town_origin, COPSE_SHARE)
	add_arable_land(local_map, hill_amount, fertile_amount, town_origin, climate)
	ensure_floors(local_map, forest_amount, town_origin)
	return local_map

# --- Regional fields ------------------------------------------------------------------------

func regional_tile(x: int, y: int) -> Dictionary:
	return window_tiles[clampi(y, 0, window_size.y - 1)][clampi(x, 0, window_size.x - 1)]

static func tile_fields(tile: Dictionary) -> PackedFloat32Array:
	var fields: PackedFloat32Array = PackedFloat32Array()
	fields.resize(FIELD_COUNT)
	var tile_type: String = tile["type"]
	var is_water: bool = tile_type == "river" or tile_type == "lake" or tile_type == "sea"
	fields[FIELD_WATER] = 1.0 if is_water else 0.0
	fields[FIELD_MOUNTAIN] = 1.0 if tile_type == "mountain" else 0.0
	fields[FIELD_HILL] = 1.0 if tile_type == "hill" else 0.0
	fields[FIELD_FOREST] = 1.0 if tile["has_forest"] == true else 0.0
	fields[FIELD_FERTILE] = 1.0 if tile["is_fertile"] == true else 0.0
	fields[FIELD_DEPOSIT] = 1.0 if tile["resource"] != "none" else 0.0
	fields[FIELD_ROAD] = 1.0 if tile.get("has_road", false) == true and not is_water else 0.0
	return fields

# Bilinear blend of the four regional tiles whose centers surround a regional position.
func blended_fields(regional: Vector2) -> PackedFloat32Array:
	var q: Vector2 = regional - Vector2(0.5, 0.5)
	var base: Vector2i = Vector2i(q.floor())
	var f: Vector2 = q - Vector2(base)
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(FIELD_COUNT)
	for corner in range(4):
		var offset: Vector2i = Vector2i(corner % 2, corner / 2)
		var weight: float = (f.x if offset.x == 1 else 1.0 - f.x) * (f.y if offset.y == 1 else 1.0 - f.y)
		var cell: Vector2i = Vector2i(clampi(base.x + offset.x, 0, window_size.x - 1), clampi(base.y + offset.y, 0, window_size.y - 1))
		if not field_cache.has(cell):
			field_cache[cell] = tile_fields(regional_tile(cell.x, cell.y))
		var fields: PackedFloat32Array = field_cache[cell]
		for field in range(FIELD_COUNT):
			result[field] += fields[field] * weight
	return result

# The kind of water ("river", "lake", "sea") or deposit ("stone", "iron") among the regional
# tiles around a position: the nearest tile that has one.
func dominant_kind(regional: Vector2, what: String) -> String:
	var best: String = ""
	var best_distance: float = INF
	var center: Vector2i = Vector2i(regional.floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tile: Dictionary = regional_tile(center.x + dx, center.y + dy)
			var kind: String = ""
			if what == "water":
				var tile_type: String = tile["type"]
				if tile_type == "river" or tile_type == "lake" or tile_type == "sea":
					kind = tile_type
			elif tile["resource"] != "none":
				kind = tile["resource"]
			if kind == "":
				continue
			var distance: float = regional.distance_to(Vector2(center.x + dx, center.y + dy) + Vector2(0.5, 0.5))
			if distance < best_distance:
				best_distance = distance
				best = kind
	if best == "":
		return "river" if what == "water" else "stone"
	return best

# --- Town-scale detail ------------------------------------------------------------------------

# Steep rock on hill land: the highest-ranked share of a detail noise among hill tiles.
func add_hill_outcrops(local_map: Array, hill_amount: PackedFloat32Array, town_origin: Vector2) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var tile: Dictionary = local_map[y][x]
			if tile["type"] == "ground" and not tile["has_road"] and hill_amount[y * width + x] > FEATURE_THRESHOLD:
				candidates.append(Vector2i(x, y))
	for cell: Vector2i in top_ranked(candidates, detail_noise, town_origin, HILL_OUTCROP_SHARE):
		var tile: Dictionary = local_map[cell.y][cell.x]
		tile["type"] = "rough"
		tile["has_trees"] = false

# Small openings inside woods, so a forest edge site still reads as woodland with clearings.
func add_glades(local_map: Array, town_origin: Vector2) -> void:
	var wooded: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if local_map[y][x]["has_trees"] == true:
				wooded.append(Vector2i(x, y))
	for cell: Vector2i in top_ranked(wooded, copse_noise, town_origin, GLADE_SHARE):
		local_map[cell.y][cell.x]["has_trees"] = false

# The founding tile is open land, but blending can bring trees or rock onto it: the town's
# heart is kept clear (water stays water).
func clear_center(local_map: Array) -> void:
	var center: Vector2 = Vector2(width, height) * 0.5
	for y in range(height):
		for x in range(width):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > CENTER_CLEAR_RADIUS:
				continue
			var tile: Dictionary = local_map[y][x]
			if tile["type"] == "rough":
				tile["type"] = "ground"
				tile["resource"] = "none"
			tile["has_trees"] = false

# Copses: the highest-ranked share of open land outside the woods and away from the center.
func add_copses(local_map: Array, forest_amount: PackedFloat32Array, town_origin: Vector2, share: float) -> void:
	var center: Vector2 = Vector2(width, height) * 0.5
	var open_land: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var tile: Dictionary = local_map[y][x]
			if tile["type"] != "ground" or tile["has_trees"] or tile["has_road"]:
				continue
			if forest_amount[y * width + x] > 0.3 or Vector2(x, y).distance_to(center) < COPSE_CENTER_DISTANCE:
				continue
			open_land.append(Vector2i(x, y))
	for cell: Vector2i in top_ranked(open_land, copse_noise, town_origin + Vector2(500.0, 0.0), share):
		local_map[cell.y][cell.x]["has_trees"] = true
		# Copses added late (the tree floor) can fall on farmland; wooded land is not farmland.
		local_map[cell.y][cell.x]["is_fertile"] = false

static func arable_share(climate: Dictionary) -> float:
	var warmth: float = smoothstep(0.2, 0.42, float(climate.get("temperature", 0.55)))
	var wetness: float = smoothstep(0.15, 0.5, float(climate.get("moisture", 0.6)))
	return lerpf(ARABLE_SHARE_POOR, ARABLE_SHARE_GOOD, warmth * wetness)

# Regional fertile land stays fertile; other open land is arable in pockets, ranked by a slow
# noise so they form fields rather than speckles.
func add_arable_land(local_map: Array, hill_amount: PackedFloat32Array, fertile_amount: PackedFloat32Array, town_origin: Vector2, climate: Dictionary) -> void:
	var lowland: Array[Vector2i] = []
	var upland: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var tile: Dictionary = local_map[y][x]
			if tile["type"] != "ground" or tile["has_trees"] or tile["has_road"]:
				continue
			if fertile_amount[y * width + x] > FEATURE_THRESHOLD:
				tile["is_fertile"] = true
			elif hill_amount[y * width + x] > FEATURE_THRESHOLD:
				upland.append(Vector2i(x, y))
			else:
				lowland.append(Vector2i(x, y))
	var share: float = arable_share(climate)
	for cell: Vector2i in top_ranked(lowland, pocket_noise, town_origin, share):
		local_map[cell.y][cell.x]["is_fertile"] = true
	for cell: Vector2i in top_ranked(upland, pocket_noise, town_origin, share * HILL_ARABLE_FACTOR):
		local_map[cell.y][cell.x]["is_fertile"] = true

# Every town keeps room to build, a little farmland, and woods in reach. Shortfalls are made up
# nearest the center first: rock and trees cleared, open land made arable, copses added.
func ensure_floors(local_map: Array, forest_amount: PackedFloat32Array, town_origin: Vector2) -> void:
	var by_distance: Array[Vector2i] = tiles_by_center_distance()
	var buildable: int = count_tiles(local_map, func(t: Dictionary) -> bool: return is_buildable(t))
	for cell: Vector2i in by_distance:
		if buildable >= MIN_BUILDABLE_TILES:
			break
		var tile: Dictionary = local_map[cell.y][cell.x]
		if tile["type"] == "water" or tile["has_road"] or is_buildable(tile):
			continue
		tile["type"] = "ground"
		tile["resource"] = "none"
		tile["has_trees"] = false
		buildable += 1
	var fertile: int = count_tiles(local_map, func(t: Dictionary) -> bool: return t["is_fertile"] == true)
	for cell: Vector2i in by_distance:
		if fertile >= MIN_FERTILE_TILES:
			break
		var tile: Dictionary = local_map[cell.y][cell.x]
		if is_buildable(tile) and not tile["is_fertile"]:
			tile["is_fertile"] = true
			fertile += 1
	var share: float = COPSE_SHARE
	while count_tiles(local_map, func(t: Dictionary) -> bool: return t["has_trees"] == true) < MIN_TREE_TILES and share < 0.5:
		share += 0.02
		add_copses(local_map, forest_amount, town_origin, share)

static func is_buildable(tile: Dictionary) -> bool:
	return tile["type"] == "ground" and not tile["has_trees"] and not tile["has_road"]

func count_tiles(local_map: Array, predicate: Callable) -> int:
	var count: int = 0
	for row: Array in local_map:
		for tile: Dictionary in row:
			if predicate.call(tile):
				count += 1
	return count

func tiles_by_center_distance() -> Array[Vector2i]:
	var center: Vector2 = Vector2(width, height) * 0.5
	var cells: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(center) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(center))
	return cells

# The given share of cells with the highest noise; ranking rather than a fixed threshold keeps
# the share exact whatever the noise does locally. Ties break by position, so the result is
# deterministic.
func top_ranked(cells: Array[Vector2i], noise: FastNoiseLite, town_origin: Vector2, share: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var count: int = roundi(cells.size() * clampf(share, 0.0, 1.0))
	if count <= 0:
		return result
	var scored: Array = []
	for cell: Vector2i in cells:
		var global: Vector2 = town_origin + Vector2(cell)
		scored.append([noise.get_noise_2d(global.x, global.y), cell.y * width + cell.x, cell])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in range(count):
		result.append(scored[i][2])
	return result
