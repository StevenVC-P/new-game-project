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
# regional fertile flag only marks land near water), small copses on open land, glades, outcrops,
# clay and limestone.
#
# Land is a function of global position alone (master roadmap Phase 1, docs/MAP_SCALE_ARCHITECTURE.md):
# every window onto the planet, of any size or place, agrees on every tile. Shares of the land
# (arable pockets, outcrops, glades, copses) are thresholds on noise, read from a fixed sample of it,
# never ranks within a window. Founding is a change made to that land: its heart is cleared, and land
# it opens is judged for farming as any open land is. There are no floors (owner, 2026-11-07): a poor
# site stays poor, and nothing is added to rescue it.
#
# Town tiles: "type" (ground, water, rough), "has_trees", "is_fertile", "occupied", and
# "water_kind" (river, lake, sea, or ""), "resource" (none, stone, iron), "has_road", "is_hill"
# (sloping land on the regional map's hills). Play adds "path_level" (TownLogistics), and fells
# and spreads trees (TownWoodland).

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
# How far, in regional tiles, a town tile's sample of the regional land may be moved along a
# slow noise: straight regional edges bend into curves while interiors stay put. Kept under
# half a tile, so a feature never moves past the regional tiles around it.
const WARP_TILES: float = 0.45
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

# Founding clears its heart: the families' first ground.
const CENTER_CLEAR_RADIUS: float = 4.0

# Noise seed -> sorted sample of that noise, so a share of the planet's tiles becomes a threshold.
static var noise_quantiles: Dictionary = {}
const QUANTILE_SAMPLES: int = 400
const QUANTILE_STEP: float = 7.0
# Town tiles of land worked out around the map on each side, so rules that look at neighbours
# (clay by the bank) see the same land whatever the window.
const NEIGHBOUR_MARGIN: int = 2

var width: int = 64
var height: int = 44
var edge_noise: FastNoiseLite = make_noise(4101, 0.11)
var detail_noise: FastNoiseLite = make_noise(4102, 0.23)
var pocket_noise: FastNoiseLite = make_noise(4103, 0.055)
var copse_noise: FastNoiseLite = make_noise(4104, 0.16)
var warp_noise_x: FastNoiseLite = make_noise(4105, 0.045)
var warp_noise_y: FastNoiseLite = make_noise(4106, 0.045)

# Regional window read by generate(): fields per regional tile, and which kind of water and
# deposit each tile holds.
var window_tiles: Array = []
var window_size: Vector2i = Vector2i.ZERO
# Regional tile -> its fields, filled as the blend reads them.
var field_cache: Dictionary = {}
# The continuous map reads the climate per regional tile, not the site's (a site's single climate
# would differ along an edge two towns share). Bounded maps have none and use the site's.
var climate_terrain: RegionalTerrain = null
var arable_cache: Dictionary = {}

func _init(local_width: int = 64, local_height: int = 44):
	width = local_width
	height = local_height

static func make_noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	return noise

# Regional tiles the map reads around its site, each way: its half-extent, the neighbour margin,
# and a tile more for blending past a warped sample and for the nearest-kind look around it.
func regional_reach() -> Vector2i:
	var half: Vector2 = (Vector2(width, height) * 0.5 + Vector2(NEIGHBOUR_MARGIN, NEIGHBOUR_MARGIN)) / TOWN_TILES_PER_REGIONAL_TILE
	return Vector2i(ceili(half.x) + 3, ceili(half.y) + 3)

# The continuous map: reads a window cut around the site, so a site near the edge of the
# game's neighbourhood still gets the land beyond it.
func generate_from_terrain(terrain: RegionalTerrain, global_site: Vector2i, climate: Dictionary) -> Array:
	var reach: Vector2i = regional_reach()
	var window_origin: Vector2i = global_site - reach
	return generate(reach, terrain.extract_window(window_origin, reach * 2 + Vector2i.ONE), window_origin, climate, terrain)

# The land alone at a site, before any founding: what every window onto the planet agrees on.
func generate_base_from_terrain(terrain: RegionalTerrain, global_site: Vector2i, climate: Dictionary) -> Array:
	var reach: Vector2i = regional_reach()
	var window_origin: Vector2i = global_site - reach
	begin(terrain.extract_window(window_origin, reach * 2 + Vector2i.ONE), terrain)
	return land(reach, window_origin, climate)["map"]

# site: the town's regional tile in regional_tiles' coordinates. hash_origin: the global
# regional tile at regional_tiles' (0, 0), so noise follows the planet; outside the given
# tiles the nearest edge tile repeats. terrain, when given, supplies each regional tile's climate.
func generate(site: Vector2i, regional_tiles: Array, hash_origin: Vector2i, climate: Dictionary, terrain: RegionalTerrain = null) -> Array:
	begin(regional_tiles, terrain)
	var base: Dictionary = land(site, hash_origin, climate)
	apply_founding(base, climate)
	return base["map"]

func begin(regional_tiles: Array, terrain: RegionalTerrain) -> void:
	window_tiles = regional_tiles
	window_size = Vector2i((regional_tiles[0] as Array).size(), regional_tiles.size()) if not regional_tiles.is_empty() else Vector2i.ZERO
	field_cache.clear()
	arable_cache.clear()
	climate_terrain = terrain

# The town map's land: each tile from its own position, worked out NEIGHBOUR_MARGIN tiles past
# the map so clay sees the bank beyond the edge, then cut to the map. Returns the map and what
# founding reads (origin, and the hill, forest and fertile amounts per tile).
func land(site: Vector2i, hash_origin: Vector2i, climate: Dictionary) -> Dictionary:
	var town_origin: Vector2 = Vector2(hash_origin + site) * TOWN_TILES_PER_REGIONAL_TILE - Vector2(width, height) * 0.5 + Vector2(TOWN_TILES_PER_REGIONAL_TILE, TOWN_TILES_PER_REGIONAL_TILE) * 0.5
	var margin: int = NEIGHBOUR_MARGIN
	var wide: Vector2i = Vector2i(width + margin * 2, height + margin * 2)
	var wide_origin: Vector2 = town_origin - Vector2(margin, margin)
	var hill_amount: PackedFloat32Array = PackedFloat32Array()
	var forest_amount: PackedFloat32Array = PackedFloat32Array()
	var fertile_amount: PackedFloat32Array = PackedFloat32Array()
	hill_amount.resize(width * height)
	forest_amount.resize(width * height)
	fertile_amount.resize(width * height)
	var outcrop_above: float = noise_above(detail_noise, HILL_OUTCROP_SHARE)
	var glade_above: float = noise_above(copse_noise, GLADE_SHARE)
	var copse_above: float = noise_above(copse_noise, COPSE_SHARE)
	var wide_map: Array = []
	for y in range(wide.y):
		var row: Array = []
		for x in range(wide.x):
			var global: Vector2 = wide_origin + Vector2(x, y)
			# Worked out from global position in doubles: a Vector2 measured from the window's corner
			# rounds differently in each window, enough to flip a tile that sits on a threshold.
			var warp: Vector2 = Vector2(warp_noise_x.get_noise_2d(global.x, global.y), warp_noise_y.get_noise_2d(global.x, global.y)).limit_length(1.0) * WARP_TILES
			var rx: float = (float(global.x) + 0.5) / TOWN_TILES_PER_REGIONAL_TILE + float(warp.x)
			var ry: float = (float(global.y) + 0.5) / TOWN_TILES_PER_REGIONAL_TILE + float(warp.y)
			var cell: Vector2i = Vector2i(floori(rx - 0.5), floori(ry - 0.5)) - hash_origin
			var within: Vector2 = Vector2(rx - 0.5 - floorf(rx - 0.5), ry - 0.5 - floorf(ry - 0.5))
			var fields: PackedFloat32Array = blended_fields_at(cell, within)
			var edge: float = edge_noise.get_noise_2d(global.x, global.y) * EDGE_NOISE
			var tile: Dictionary = {"type": "ground", "has_trees": false, "is_fertile": false, "occupied": false, "water_kind": "", "resource": "none", "has_road": false, "is_hill": false}
			var near: Vector2i = Vector2i(floori(rx), floori(ry)) - hash_origin
			var near_within: Vector2 = Vector2(rx - floorf(rx), ry - floorf(ry))
			# Sloping land, slow to cross; its steepest share is rock (outcrops, below).
			tile["is_hill"] = fields[FIELD_HILL] > FEATURE_THRESHOLD
			var fertile: float = fields[FIELD_FERTILE] + edge
			if fields[FIELD_WATER] + edge > WATER_THRESHOLD:
				tile["type"] = "water"
				tile["water_kind"] = nearest_kind(near, near_within, "water", hash_origin)[0]
			elif fields[FIELD_MOUNTAIN] + edge > FEATURE_THRESHOLD:
				tile["type"] = "rough"
			elif fields[FIELD_DEPOSIT] + edge > DEPOSIT_THRESHOLD:
				tile["type"] = "rough"
				var found: Array = nearest_kind(near, near_within, "resource", hash_origin)
				tile["resource"] = found[0]
				# Limestone (sprint S5): whole deposits, LIMESTONE_SHARE of them, known by the regional
				# tile the stone comes from.
				var source: Vector2i = found[1]
				if found[0] == "stone" and float(absi(hash([source.x, source.y, "limestone"])) % 1000) / 1000.0 < EconomyBalance.LIMESTONE_SHARE:
					tile["stone_kind"] = "limestone"
			elif fields[FIELD_ROAD] - absf(edge) * 0.5 > ROAD_THRESHOLD:
				tile["has_road"] = true
			elif fields[FIELD_FOREST] + edge > FEATURE_THRESHOLD:
				tile["has_trees"] = true
			# Outcrops on hill land, glades in woods, copses on open land, then arable land.
			if tile["type"] == "ground" and not tile["has_road"] and tile["is_hill"] and detail_noise.get_noise_2d(global.x, global.y) >= outcrop_above:
				tile["type"] = "rough"
				tile["has_trees"] = false
			if tile["has_trees"] and copse_noise.get_noise_2d(global.x, global.y) >= glade_above:
				tile["has_trees"] = false
			if tile["type"] == "ground" and not tile["has_trees"] and not tile["has_road"] and fields[FIELD_FOREST] <= 0.3 and copse_noise.get_noise_2d(global.x + 500.0, global.y) >= copse_above:
				tile["has_trees"] = true
			if tile["type"] == "ground" and not tile["has_trees"] and not tile["has_road"]:
				tile["is_fertile"] = is_arable(global, fertile, fields[FIELD_HILL], climate)
			var inner: Vector2i = Vector2i(x - margin, y - margin)
			if inner.x >= 0 and inner.y >= 0 and inner.x < width and inner.y < height:
				var i: int = inner.y * width + inner.x
				hill_amount[i] = fields[FIELD_HILL]
				forest_amount[i] = fields[FIELD_FOREST]
				fertile_amount[i] = fertile
			row.append(tile)
		wide_map.append(row)
	add_clay(wide_map, wide_origin)
	var local_map: Array = []
	for y in range(height):
		local_map.append((wide_map[y + margin] as Array).slice(margin, margin + width))
	return {"map": local_map, "origin": town_origin, "hill": hill_amount, "forest": forest_amount, "fertile": fertile_amount}

# What a founding changes on the land: its heart is cleared (water stays water), and so is the ring
# of copses about it; land they open is judged for farming as any open land is. Nothing else.
func apply_founding(base: Dictionary, climate: Dictionary) -> void:
	var local_map: Array = base["map"]
	var town_origin: Vector2 = base["origin"]
	var center: Vector2 = Vector2(width, height) * 0.5
	clear_center(local_map)
	for y in range(height):
		for x in range(width):
			var tile: Dictionary = local_map[y][x]
			var i: int = y * width + x
			var opened: bool = Vector2(x + 0.5, y + 0.5).distance_to(center) <= CENTER_CLEAR_RADIUS
			if tile["has_trees"] and float(base["forest"][i]) <= 0.3 and Vector2(x, y).distance_to(center) < COPSE_CENTER_DISTANCE:
				tile["has_trees"] = false
				opened = true
			if opened and tile["type"] == "ground" and not tile["has_trees"] and not tile["has_road"]:
				tile["is_fertile"] = is_arable(town_origin + Vector2(x, y), base["fertile"][i], base["hill"][i], climate)


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

# Bilinear blend of the four regional tiles whose centers surround a position: base is the
# corner tile (window coordinates), f the position between it and the next.
func blended_fields_at(base: Vector2i, f: Vector2) -> PackedFloat32Array:
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
# tiles around a position, the nearest that has one, and that tile's global position:
# [kind, global regional tile]. center is in window coordinates, within the position inside it.
func nearest_kind(center: Vector2i, within: Vector2, what: String, hash_origin: Vector2i) -> Array:
	var best: String = ""
	var best_cell: Vector2i = center
	var best_distance: float = INF
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
			var distance: float = within.distance_to(Vector2(dx, dy) + Vector2(0.5, 0.5))
			if distance < best_distance:
				best_distance = distance
				best = kind
				best_cell = center + Vector2i(dx, dy)
	if best == "":
		best = "river" if what == "water" else "stone"
	return [best, best_cell + hash_origin]

# --- Town-scale detail ------------------------------------------------------------------------

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
				tile.erase("stone_kind")
			tile["has_trees"] = false

static func arable_share(climate: Dictionary) -> float:
	var warmth: float = smoothstep(0.2, 0.42, float(climate.get("temperature", 0.55)))
	var wetness: float = smoothstep(0.15, 0.5, float(climate.get("moisture", 0.6)))
	return lerpf(ARABLE_SHARE_POOR, ARABLE_SHARE_GOOD, warmth * wetness)

# Regional fertile land stays fertile; other open land is arable in pockets of a slow noise, so
# they form fields rather than speckles, the share set by the climate (half on hills).
func is_arable(global: Vector2, fertile_amount: float, hill_amount: float, climate: Dictionary) -> bool:
	if fertile_amount > FEATURE_THRESHOLD:
		return true
	var share: float = arable_share_at(global, climate)
	if hill_amount > FEATURE_THRESHOLD:
		share *= HILL_ARABLE_FACTOR
	return pocket_noise.get_noise_2d(global.x, global.y) >= noise_above(pocket_noise, share)

# The climate's arable share at a town tile: blended between regional tiles' climates on the
# continuous map; the site's own on a bounded one.
func arable_share_at(global: Vector2, climate: Dictionary) -> float:
	if climate_terrain == null:
		return arable_share(climate)
	var q: Vector2 = (global + Vector2(0.5, 0.5)) / TOWN_TILES_PER_REGIONAL_TILE - Vector2(0.5, 0.5)
	var base: Vector2i = Vector2i(q.floor())
	var f: Vector2 = q - Vector2(base)
	var result: float = 0.0
	for corner in range(4):
		var offset: Vector2i = Vector2i(corner % 2, corner / 2)
		var cell: Vector2i = base + offset
		if not arable_cache.has(cell):
			arable_cache[cell] = arable_share(climate_terrain.climate_at(cell))
		result += float(arable_cache[cell]) * (f.x if offset.x == 1 else 1.0 - f.x) * (f.y if offset.y == 1 else 1.0 - f.y)
	return result

# Clay (sprint S5), which changes nothing but the tiles' resource: open ground beside a river or
# lake (never the sea), the bank itself and, here and there, a tile further back. A tile's
# neighbours are read only where the map holds them, so callers work the land out past the edge
# they care about (land, NEIGHBOUR_MARGIN). A pure function of global position.
const CLAY_BANK_REACH: int = 2
const CLAY_BACK_SHARE: float = 0.5

func add_clay(local_map: Array, origin: Vector2) -> void:
	var rows: int = local_map.size()
	var columns: int = (local_map[0] as Array).size() if rows > 0 else 0
	var clay: Array[Vector2i] = []
	for y in range(rows):
		for x in range(columns):
			var tile: Dictionary = local_map[y][x]
			if tile["type"] != "ground" or tile["resource"] != "none":
				continue
			var nearest: int = CLAY_BANK_REACH + 1
			for dy in range(-CLAY_BANK_REACH, CLAY_BANK_REACH + 1):
				for dx in range(-CLAY_BANK_REACH, CLAY_BANK_REACH + 1):
					var ny: int = y + dy
					var nx: int = x + dx
					if ny < 0 or ny >= rows or nx < 0 or nx >= columns:
						continue
					var other: Dictionary = local_map[ny][nx]
					if other["type"] == "water" and other.get("water_kind", "") != "sea":
						nearest = mini(nearest, maxi(absi(dx), absi(dy)))
			var global: Vector2i = Vector2i(origin) + Vector2i(x, y)
			if nearest <= 1 or (nearest <= CLAY_BANK_REACH and float(absi(hash([global.x, global.y, "clay"])) % 1000) / 1000.0 < CLAY_BACK_SHARE):
				clay.append(Vector2i(x, y))
	for cell: Vector2i in clay:
		local_map[cell.y][cell.x]["resource"] = "clay"

static func is_buildable(tile: Dictionary) -> bool:
	return tile["type"] == "ground" and not tile["has_trees"] and not tile["has_road"]

# The noise value above which the given share of the planet's tiles lie. Noise is not uniform, so
# this reads a fixed sample of it; the sample, like the noise, is the same every run.
static func noise_above(noise: FastNoiseLite, share: float) -> float:
	if not noise_quantiles.has(noise.seed):
		var values: PackedFloat32Array = PackedFloat32Array()
		values.resize(QUANTILE_SAMPLES * QUANTILE_SAMPLES)
		for y in range(QUANTILE_SAMPLES):
			for x in range(QUANTILE_SAMPLES):
				values[y * QUANTILE_SAMPLES + x] = noise.get_noise_2d(x * QUANTILE_STEP, y * QUANTILE_STEP)
		values.sort()
		noise_quantiles[noise.seed] = values
	var sorted: PackedFloat32Array = noise_quantiles[noise.seed]
	return sorted[clampi(roundi((1.0 - clampf(share, 0.0, 1.0)) * (sorted.size() - 1)), 0, sorted.size() - 1)]
