class_name RegionGeography
extends RefCounted

# What the world map says about one world region, translated into regional-map tiles.
#
# The regional map shows a fixed window of WINDOW_WORLD_SIZE world units inside the region,
# centered on a focus point chosen so the region's river, coast, and main settlement fall
# inside it. The window is a representative slice of the region, not a true-scale zoom:
# continuity of geography matters more than matching distances.
#
# RegionMapGenerator reads this to steer its existing steps (where water, high ground, and
# woods go, where the world's roads leave the map, which world settlement is the regional
# town). The region renderer reads the climate for its palette. Nothing here is random, so a
# region always yields the same geography.

const WINDOW_WORLD_SIZE: Vector2 = Vector2(96.0, 60.0)

const CLIMATE_TEMPERATE: String = "temperate"
const CLIMATE_COLD: String = "cold"
const CLIMATE_ARID: String = "arid"
const CLIMATE_TROPICAL: String = "tropical"

const WATER_NONE: int = 0
const WATER_LAKE: int = 1
const WATER_SEA: int = 2

# Lakes are carved into the world with a soft shore; this reach of the authored ellipse
# covers every water cell the carving produced.
const LAKE_REACH: float = 1.3
# Grid of samples used to judge how much sea a candidate window would show.
const FOCUS_SAMPLES: Vector2i = Vector2i(8, 5)
const FOCUS_MAX_CANDIDATES: int = 400

class RiverPath:
	var name: String = ""
	var is_major: bool = true
	# Tile coordinates; the path may run past the map edges.
	var points: PackedVector2Array = PackedVector2Array()
	var half_widths: PackedFloat32Array = PackedFloat32Array()

class RoadExit:
	# Edge tile where a world road leaves the regional map.
	var tile: Vector2i = Vector2i.ZERO
	var road_class: int = WorldMapData.ROAD_LOCAL
	# The world settlement the road leads to beyond the map edge.
	var toward: String = ""

class SettlementSite:
	var name: String = ""
	var tile: Vector2 = Vector2.ZERO
	var tier: int = WorldMapData.TIER_VILLAGE
	var population: int = 0
	var is_port: bool = false

var region_id: int = -1
var region_name: String = ""
var climate_label: String = ""
var landscape_label: String = ""
var climate_family: String = CLIMATE_TEMPERATE
var map_size: Vector2i = Vector2i(80, 50)
var world_origin: Vector2 = Vector2.ZERO
var world_per_tile: Vector2 = Vector2.ONE

# Per tile, row-major (index = y * map_size.x + x), sampled from the world at tile centers.
var elevation: PackedFloat32Array = PackedFloat32Array()
var moisture: PackedFloat32Array = PackedFloat32Array()
var forest_cover: PackedFloat32Array = PackedFloat32Array()
var relief: PackedFloat32Array = PackedFloat32Array()
var temperature: PackedFloat32Array = PackedFloat32Array()
var water: PackedByteArray = PackedByteArray()
var lake_name: String = ""

var rivers: Array[RiverPath] = []
var road_exits: Array[RoadExit] = []
var settlements: Array[SettlementSite] = []

# Land-tile averages; they scale how much high ground and woodland the map gets.
var mean_elevation: float = 0.0
var mean_relief: float = 0.0
var mean_forest: float = 0.0
var mean_moisture: float = 0.0
var mean_temperature: float = 0.0
var sea_fraction: float = 0.0
# Unit vector toward rising ground across the map, ZERO when the land is level.
var uphill: Vector2 = Vector2.ZERO

static func from_world(world: WorldMapData, world_region_id: int, size: Vector2i) -> RegionGeography:
	var geography: RegionGeography = RegionGeography.new()
	var region: WorldMapData.Region = world.get_region(world_region_id)
	geography.region_id = world_region_id
	geography.region_name = region.name
	geography.climate_label = region.climate
	geography.landscape_label = region.landscape
	geography.map_size = size
	geography.world_per_tile = WINDOW_WORLD_SIZE / Vector2(size)
	geography.world_origin = choose_focus(world, region) - WINDOW_WORLD_SIZE * 0.5
	geography.sample_fields(world)
	geography.collect_rivers(world)
	geography.collect_roads(world)
	geography.collect_settlements(world)
	geography.summarize()
	return geography

# --- Coordinates -------------------------------------------------------------

func tile_index(x: int, y: int) -> int:
	return y * map_size.x + x

func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func tile_center_to_world(x: int, y: int) -> Vector2:
	return world_origin + Vector2(x + 0.5, y + 0.5) * world_per_tile

# Tile coordinates (fractional) of a world position, measured the short way around the planet.
func world_to_tile(world: WorldMapData, world_pos: Vector2) -> Vector2:
	var offset: Vector2 = Vector2(world.wrapped_delta_x(world_origin.x, world_pos.x), world_pos.y - world_origin.y)
	return offset / world_per_tile

func water_at(x: int, y: int) -> int:
	return water[tile_index(x, y)]

# --- Choosing the window ----------------------------------------------------

# Picks the window center: close to the region's middle, with its river running through,
# some coast if the region has one, and the region's main settlement in view.
static func choose_focus(world: WorldMapData, region: WorldMapData.Region) -> Vector2:
	var candidates: Array[Vector2] = []
	for cell_y in range(world.political_size.y):
		for cell_x in range(world.political_size.x):
			if world.region_grid[cell_y * world.political_size.x + cell_x] == region.id:
				candidates.append(world.political_cell_center(Vector2i(cell_x, cell_y)))
	if candidates.is_empty():
		return region.centroid
	var stride: int = maxi(1, ceili(float(candidates.size()) / FOCUS_MAX_CANDIDATES))

	var river_points: PackedVector2Array = PackedVector2Array()
	for river: WorldMapData.River in world.rivers:
		for point: Vector2 in river.points:
			if world.region_id_at(point) == region.id:
				river_points.append(point)

	var settlements: Array[WorldMapData.Settlement] = world.get_settlements_in_region(region.id)
	var main_settlement: WorldMapData.Settlement = settlements[0] if not settlements.is_empty() else null

	var best: Vector2 = region.centroid
	var best_score: float = -INF
	for candidate_index in range(0, candidates.size(), stride):
		var center: Vector2 = candidates[candidate_index]
		if not world.is_land_at(center):
			continue
		var score: float = -world.wrapped_distance(center, region.centroid) / 120.0

		if not river_points.is_empty():
			var nearest_river: float = INF
			for point: Vector2 in river_points:
				nearest_river = minf(nearest_river, world.wrapped_distance(center, point))
			score += 2.5 * (1.0 - smoothstep(3.0, 24.0, nearest_river))

		var water_counts: Vector2 = sample_window_water(world, center)
		var sea: float = water_counts.x
		if region.has_coast:
			score += 1.5 * (1.0 - clampf(absf(sea - 0.2) / 0.2, 0.0, 1.0))
		else:
			score -= 2.0 * sea
		score -= 4.0 * maxf(sea - 0.4, 0.0)
		if water_counts.y > 0.0:
			score += 0.8

		if main_settlement != null:
			var offset: Vector2 = Vector2(world.wrapped_delta_x(center.x, main_settlement.position.x), main_settlement.position.y - center.y)
			if absf(offset.x) < WINDOW_WORLD_SIZE.x * 0.38 and absf(offset.y) < WINDOW_WORLD_SIZE.y * 0.38:
				score += 1.5

		if score > best_score:
			best_score = score
			best = center
	return best

# Fractions of a coarse sample grid over the window that are sea (x) and lake (y).
static func sample_window_water(world: WorldMapData, center: Vector2) -> Vector2:
	var sea: int = 0
	var lake: int = 0
	for sample_y in range(FOCUS_SAMPLES.y):
		for sample_x in range(FOCUS_SAMPLES.x):
			var fraction: Vector2 = Vector2((sample_x + 0.5) / FOCUS_SAMPLES.x, (sample_y + 0.5) / FOCUS_SAMPLES.y)
			var point: Vector2 = center + (fraction - Vector2(0.5, 0.5)) * WINDOW_WORLD_SIZE
			if world.is_land_at(point):
				continue
			if world.lake_at(point, LAKE_REACH) != null:
				lake += 1
			else:
				sea += 1
	var total: float = float(FOCUS_SAMPLES.x * FOCUS_SAMPLES.y)
	return Vector2(sea / total, lake / total)

# --- Sampling ---------------------------------------------------------------

func sample_fields(world: WorldMapData) -> void:
	var count: int = map_size.x * map_size.y
	elevation.resize(count)
	moisture.resize(count)
	forest_cover.resize(count)
	relief.resize(count)
	temperature.resize(count)
	water.resize(count)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var i: int = tile_index(x, y)
			var world_pos: Vector2 = tile_center_to_world(x, y)
			var terrain: Color = world.terrain_at(world_pos)
			elevation[i] = terrain.r
			moisture[i] = terrain.g
			forest_cover[i] = terrain.b
			relief[i] = terrain.a
			temperature[i] = WorldFieldBuilder.temperature(world.latitude_at(world.wrap_position(world_pos).y), maxf(terrain.r, 0.0))
			water[i] = WATER_NONE
			if terrain.r <= 0.0:
				var lake: WorldMapData.Lake = world.lake_at(world_pos, LAKE_REACH)
				water[i] = WATER_LAKE if lake != null else WATER_SEA
				if lake != null:
					lake_name = lake.name

func collect_rivers(world: WorldMapData) -> void:
	var bounds: Rect2 = Rect2(Vector2(-4.0, -4.0), Vector2(map_size) + Vector2(8.0, 8.0))
	for world_river: WorldMapData.River in world.rivers:
		var path: RiverPath = RiverPath.new()
		path.name = world_river.name
		path.is_major = world_river.is_major
		var touches_map: bool = false
		for i in range(world_river.points.size()):
			var tile_point: Vector2 = world_to_tile(world, world_river.points[i])
			path.points.append(tile_point)
			# Rivers are drawn a little wider than the world scale suggests so they stay readable.
			path.half_widths.append(clampf(0.9 + world_river.widths[i] / world_per_tile.x * 0.45, 1.0, 2.6))
			if bounds.has_point(tile_point):
				touches_map = true
		if touches_map:
			rivers.append(path)

func collect_roads(world: WorldMapData) -> void:
	var map_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(map_size))
	for world_road: WorldMapData.Road in world.roads:
		var start_name: String = world.get_settlement(world_road.from_settlement_id).name
		var end_name: String = world.get_settlement(world_road.to_settlement_id).name
		for i in range(world_road.points.size() - 1):
			var a: Vector2 = world_to_tile(world, world_road.points[i])
			var b: Vector2 = world_to_tile(world, world_road.points[i + 1])
			var a_inside: bool = map_rect.has_point(a)
			if a_inside == map_rect.has_point(b):
				continue
			var crossing: Vector2 = edge_crossing(a, b, map_rect)
			var exit: RoadExit = RoadExit.new()
			exit.tile = Vector2i(clampi(int(crossing.x), 0, map_size.x - 1), clampi(int(crossing.y), 0, map_size.y - 1))
			exit.road_class = world_road.road_class
			# Leaving the map toward b means the road continues to the road's end settlement.
			exit.toward = end_name if a_inside else start_name
			road_exits.append(exit)

# Where segment a-b (one end inside, one outside) crosses the rectangle's border.
static func edge_crossing(a: Vector2, b: Vector2, rect: Rect2) -> Vector2:
	var inside: Vector2 = a if rect.has_point(a) else b
	var outside: Vector2 = b if inside == a else a
	for _step in range(24):
		var middle: Vector2 = (inside + outside) * 0.5
		if rect.has_point(middle):
			inside = middle
		else:
			outside = middle
	return inside

func collect_settlements(world: WorldMapData) -> void:
	var inner: Rect2 = Rect2(Vector2(2.0, 2.0), Vector2(map_size) - Vector2(4.0, 4.0))
	for world_settlement: WorldMapData.Settlement in world.settlements:
		var tile_point: Vector2 = world_to_tile(world, world_settlement.position)
		if not inner.has_point(tile_point):
			continue
		var site: SettlementSite = SettlementSite.new()
		site.name = world_settlement.name
		site.tile = tile_point
		site.tier = world_settlement.tier
		site.population = world_settlement.population
		site.is_port = world_settlement.is_port
		settlements.append(site)
	settlements.sort_custom(func(a: SettlementSite, b: SettlementSite) -> bool: return a.population > b.population)

func summarize() -> void:
	var land: int = 0
	var center: Vector2 = Vector2(map_size) * 0.5
	for y in range(map_size.y):
		for x in range(map_size.x):
			var i: int = tile_index(x, y)
			if water[i] != WATER_NONE:
				continue
			land += 1
			mean_elevation += elevation[i]
			mean_relief += relief[i]
			mean_forest += forest_cover[i]
			mean_moisture += moisture[i]
			mean_temperature += temperature[i]
	var sea_tiles: int = 0
	for value: int in water:
		if value == WATER_SEA:
			sea_tiles += 1
	sea_fraction = float(sea_tiles) / float(water.size())
	if land == 0:
		return
	mean_elevation /= land
	mean_relief /= land
	mean_forest /= land
	mean_moisture /= land
	mean_temperature /= land

	# Least-squares slope of land elevation across the map gives the uphill direction.
	var slope: Vector2 = Vector2.ZERO
	var spread: Vector2 = Vector2.ZERO
	for y in range(map_size.y):
		for x in range(map_size.x):
			var i: int = tile_index(x, y)
			if water[i] != WATER_NONE:
				continue
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			slope += offset * (elevation[i] - mean_elevation)
			spread += offset * offset
	var gradient: Vector2 = Vector2(slope.x / maxf(spread.x, 1.0), slope.y / maxf(spread.y, 1.0))
	# Below about 0.04 elevation across the whole map the land reads as level.
	if gradient.length() * map_size.x > 0.04:
		uphill = gradient.normalized()

	if mean_temperature < 0.33:
		climate_family = CLIMATE_COLD
	elif mean_moisture < 0.4:
		climate_family = CLIMATE_ARID
	elif mean_temperature >= 0.74 and mean_moisture > 0.5:
		climate_family = CLIMATE_TROPICAL
	else:
		climate_family = CLIMATE_TEMPERATE

func get_debug_summary() -> String:
	return "%s: %s / %s -> %s | elev %.2f relief %.2f forest %.2f moist %.2f temp %.2f sea %.2f uphill %s | rivers %d exits %d settlements %d" % [
		region_name, climate_label, landscape_label, climate_family, mean_elevation, mean_relief, mean_forest, mean_moisture, mean_temperature,
		sea_fraction, str(uphill.snapped(Vector2(0.01, 0.01))), rivers.size(), road_exits.size(), settlements.size()]
