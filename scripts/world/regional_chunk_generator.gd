class_name RegionalChunkGenerator
extends RefCounted

# Generates one chunk of the regional-scale planet (see RegionalTerrain). Everything is a
# function of global tile position and the world's data: noise is sampled at global tile
# coordinates with fixed seeds, and lines (rivers, streams, roads) are stamped from their
# world courses. So a tile comes out the same whichever chunk generates it, and chunks join
# without seams. Safe to run on a worker thread: it only reads the world and the terrain's
# precomputed fields.
#
# The rules are the world-geography rules of RegionMapGenerator, made local: where that
# generator measured a whole region (mean relief, mean forest) and ranked its tiles to hit
# exact amounts, this one reads the world's local averages around each tile and compares a
# noise rank against the amount the world asks for there.

const RIVER_MEANDER_TILES: float = 2.6
const ROAD_MEANDER_TILES: float = 0.8
# World elevation noise that shifts the coastline by a fraction of a world texel, matching
# the atlas's coast crinkle.
const COAST_NOISE_ELEVATION: float = 0.012
# Below this local temperature the ground is frozen: no farmland, no woods.
const FROZEN_TEMPERATURE: float = 0.08
const LAKE_REACH: float = 1.3
const DEPOSIT_CELL_TILES: int = 15

const NOISE_COAST: String = "coast"
const NOISE_RELIEF: String = "relief"
const NOISE_FARMLAND: String = "farmland"
const NOISE_WOODS: String = "woods"
# [seed, frequency per tile, octaves]
const NOISE_SETTINGS: Dictionary = {
	NOISE_COAST: [9101, 0.08, 3],
	NOISE_RELIEF: [9102, 0.07, 4],
	NOISE_FARMLAND: [9103, 0.11, 3],
	NOISE_WOODS: [9104, 0.09, 3],
}
const CDF_SAMPLES: int = 8192

var terrain: RegionalTerrain
var world: WorldMapData
var noises: Dictionary = {}

var width: int = 0
# Global tile of the window's first tile (x unwrapped).
var origin: Vector2i = Vector2i.ZERO

# Per window tile, row-major.
var elevation: PackedFloat32Array = PackedFloat32Array()
var moisture: PackedFloat32Array = PackedFloat32Array()
var forest_cover: PackedFloat32Array = PackedFloat32Array()
var relief: PackedFloat32Array = PackedFloat32Array()
var local_elevation: PackedFloat32Array = PackedFloat32Array()
var local_relief: PackedFloat32Array = PackedFloat32Array()
var local_forest: PackedFloat32Array = PackedFloat32Array()
var local_moisture: PackedFloat32Array = PackedFloat32Array()
var temperature: PackedFloat32Array = PackedFloat32Array()
var local_temperature: PackedFloat32Array = PackedFloat32Array()
var types: PackedByteArray = PackedByteArray()
var flags: PackedByteArray = PackedByteArray()
var resources: PackedByteArray = PackedByteArray()
# Priority of the deposit cluster holding each tile, -1 for none.
var deposit_priority: PackedFloat32Array = PackedFloat32Array()
# Points on the noise cylinder for each window column (x wraps around the planet).
var cylinder_x: PackedFloat32Array = PackedFloat32Array()
var cylinder_z: PackedFloat32Array = PackedFloat32Array()

func _init(regional_terrain: RegionalTerrain) -> void:
	terrain = regional_terrain
	world = terrain.world
	for kind: String in NOISE_SETTINGS:
		noises[kind] = make_noise(kind)

static func make_noise(kind: String) -> FastNoiseLite:
	var settings: Array = NOISE_SETTINGS[kind]
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = settings[0]
	noise.frequency = settings[1]
	noise.fractal_octaves = settings[2]
	return noise

# Sorted samples of each noise; the share of samples below a value is that value's rank, so
# comparing a rank with an amount gives that amount of coherent patches.
static func build_noise_cdfs() -> Dictionary:
	var cdfs: Dictionary = {}
	for kind: String in NOISE_SETTINGS:
		var noise: FastNoiseLite = make_noise(kind)
		var samples: PackedFloat32Array = PackedFloat32Array()
		samples.resize(CDF_SAMPLES)
		for i in range(CDF_SAMPLES):
			samples[i] = noise.get_noise_3d(hash01(i, 0, 1) * 4000.0, hash01(i, 0, 2) * 4000.0, hash01(i, 0, 3) * 4000.0)
		samples.sort()
		cdfs[kind] = samples
	return cdfs

static func hash01(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, salt)) & 0xFFFF) / 65535.0

func noise_at(kind: String, x: int, y: int) -> float:
	return (noises[kind] as FastNoiseLite).get_noise_3d(cylinder_x[x], origin.y + y, cylinder_z[x])

func rank(kind: String, value: float) -> float:
	var samples: PackedFloat32Array = terrain.noise_cdfs[kind]
	return float(samples.bsearch(value)) / samples.size()

func generate(chunk: Vector2i) -> RegionalChunk:
	width = RegionalTerrain.CHUNK_TILES + RegionalTerrain.APRON_TILES * 2
	origin = chunk * RegionalTerrain.CHUNK_TILES - Vector2i.ONE * RegionalTerrain.APRON_TILES
	var count: int = width * width
	types.resize(count)
	flags.resize(count)
	resources.resize(count)
	prepare_cylinder()
	sample_world()
	place_water()
	stamp_water_lines()
	stamp_roads()
	place_relief(distance_field(func(t: int) -> bool: return t == RegionalChunk.TYPE_RIVER))
	var fresh_water: PackedFloat32Array = distance_field(func(t: int) -> bool: return t == RegionalChunk.TYPE_RIVER or t == RegionalChunk.TYPE_LAKE)
	place_farmland(fresh_water)
	place_woods(fresh_water)
	place_deposits()
	return package(chunk)

func prepare_cylinder() -> void:
	cylinder_x.resize(width)
	cylinder_z.resize(width)
	var radius: float = terrain.size_tiles.x / TAU
	for x in range(width):
		var angle: float = TAU * float(origin.x + x) / terrain.size_tiles.x
		cylinder_x[x] = cos(angle) * radius
		cylinder_z[x] = sin(angle) * radius

# --- World fields -------------------------------------------------------------------------

func sample_world() -> void:
	elevation = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_elevation_smooth(world_pos))
	moisture = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.field_moisture, world_pos))
	forest_cover = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.field_forest, world_pos))
	relief = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.field_relief, world_pos))
	local_elevation = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.mean_elevation, world_pos))
	local_relief = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.mean_relief, world_pos))
	local_forest = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.mean_forest, world_pos))
	local_moisture = sample_lattice(func(world_pos: Vector2) -> float: return terrain.sample_field(terrain.mean_moisture, world_pos))
	temperature.resize(width * width)
	local_temperature.resize(width * width)
	for y in range(width):
		var latitude: float = world.latitude_at(terrain.tile_center_to_world(Vector2i(0, origin.y + y)).y)
		for x in range(width):
			var i: int = y * width + x
			temperature[i] = WorldFieldBuilder.temperature(latitude, maxf(elevation[i], 0.0))
			local_temperature[i] = WorldFieldBuilder.temperature(latitude, local_elevation[i])

# A world field sampled every LATTICE_TILES tiles (on global multiples, so neighbouring
# chunks share lattice points) and interpolated to every window tile.
func sample_lattice(sample: Callable) -> PackedFloat32Array:
	var step: int = RegionalTerrain.LATTICE_TILES
	var lattice: int = width / step + 1
	var points: PackedFloat32Array = PackedFloat32Array()
	points.resize(lattice * lattice)
	for ly in range(lattice):
		for lx in range(lattice):
			points[ly * lattice + lx] = sample.call(terrain.tile_center_to_world(origin + Vector2i(lx * step, ly * step)))
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(width * width)
	var row_values: PackedFloat32Array = PackedFloat32Array()
	row_values.resize(lattice)
	for y in range(width):
		var ly: int = y / step
		var fy: float = float(y % step) / step
		for lx in range(lattice):
			row_values[lx] = lerpf(points[ly * lattice + lx], points[(ly + 1) * lattice + lx], fy)
		for x in range(width):
			var lx: int = x / step
			values[y * width + x] = lerpf(row_values[lx], row_values[lx + 1], float(x % step) / step)
	return values

# --- Water ----------------------------------------------------------------------------------

func place_water() -> void:
	var nearby_lakes: Array[WorldMapData.Lake] = lakes_near_window()
	for y in range(width):
		for x in range(width):
			var i: int = y * width + x
			types[i] = RegionalChunk.TYPE_GRASS
			flags[i] = 0
			resources[i] = RegionalChunk.RESOURCE_NONE
			if elevation[i] + noise_at(NOISE_COAST, x, y) * COAST_NOISE_ELEVATION > 0.0:
				continue
			types[i] = RegionalChunk.TYPE_SEA
			if nearby_lakes.is_empty():
				continue
			var world_pos: Vector2 = terrain.tile_center_to_world(origin + Vector2i(x, y))
			for lake: WorldMapData.Lake in nearby_lakes:
				var offset: Vector2 = Vector2(world.wrapped_delta_x(lake.center.x, world_pos.x), world_pos.y - lake.center.y)
				if (offset / lake.radius).length() <= LAKE_REACH:
					types[i] = RegionalChunk.TYPE_LAKE
					break

func lakes_near_window() -> Array[WorldMapData.Lake]:
	var found: Array[WorldMapData.Lake] = []
	var center: Vector2 = terrain.tile_center_to_world(origin + Vector2i(width / 2, width / 2))
	var half: float = width * 0.5 * RegionalTerrain.TILE_WORLD_UNITS
	for lake: WorldMapData.Lake in world.lakes:
		var reach: Vector2 = lake.radius * LAKE_REACH + Vector2(half, half)
		if absf(world.wrapped_delta_x(center.x, lake.center.x)) <= reach.x and absf(lake.center.y - center.y) <= reach.y:
			found.append(lake)
	return found

# Sideways offset (tiles) of a meandering river at a distance along its course.
static func meander_offset(along: float, phase: float) -> float:
	return RIVER_MEANDER_TILES * (sin(along / 9.0 + phase) * 0.75 + sin(along / 3.6 + phase * 1.7) * 0.25)

func stamp_water_lines() -> void:
	var key: int = terrain.chunk_key(Vector2i(floori(float(origin.x + RegionalTerrain.APRON_TILES) / RegionalTerrain.CHUNK_TILES), floori(float(origin.y + RegionalTerrain.APRON_TILES) / RegionalTerrain.CHUNK_TILES)))
	for line_index: int in terrain.chunk_water_lines.get(key, PackedInt32Array()):
		var line: RegionalTerrain.Polyline = terrain.water_lines[line_index]
		walk_line(line, RIVER_MEANDER_TILES + 3.0, func(center: Vector2, half_width: float, along: float) -> void:
			if line.kind == RegionalTerrain.LINE_STREAM and posmod(floori(along), 9) == 0:
				half_width += 0.35
			stamp_river(center, half_width))

func stamp_river(center: Vector2, half_width: float) -> void:
	for y in range(floori(center.y - half_width), ceili(center.y + half_width) + 1):
		if y < 0 or y >= width:
			continue
		for x in range(floori(center.x - half_width), ceili(center.x + half_width) + 1):
			if x < 0 or x >= width:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(center) > half_width:
				continue
			var i: int = y * width + x
			# A river ends where it meets a lake or the sea.
			if types[i] == RegionalChunk.TYPE_LAKE or types[i] == RegionalChunk.TYPE_SEA:
				continue
			types[i] = RegionalChunk.TYPE_RIVER

# Calls visit(center, half_width, along) at half-tile steps along a line's meandering course,
# in window coordinates, for the stretches that come near the window.
func walk_line(line: RegionalTerrain.Polyline, reach: float, visit: Callable) -> void:
	var planet: float = terrain.size_tiles.x
	var window_center_x: float = origin.x + width * 0.5
	var bounds: Rect2 = Rect2(Vector2(-reach, -reach), Vector2(width, width) + Vector2(reach, reach) * 2.0)
	var is_road: bool = line.kind == RegionalTerrain.LINE_ROAD
	for segment in range(line.points.size() - 1):
		var a: Vector2 = line.points[segment]
		var b: Vector2 = line.points[segment + 1]
		# Move the segment to the copy of the planet nearest the window.
		var shift: float = roundf((window_center_x - (a.x + b.x) * 0.5) / planet) * planet
		a = Vector2(a.x + shift - origin.x, a.y - origin.y)
		b = Vector2(b.x + shift - origin.x, b.y - origin.y)
		var low: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var high: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		if not bounds.intersects(Rect2(low, high - low).grow(0.01)):
			continue
		var length: float = a.distance_to(b)
		if length < 1e-4:
			continue
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var steps: int = maxi(1, ceili(length * 2.5))
		for step in range(steps):
			var t: float = float(step) / steps
			var along: float = lerpf(line.along[segment], line.along[segment + 1], t)
			var offset: float = road_offset(along, line.phase) if is_road else meander_offset(along, line.phase)
			var center: Vector2 = a.lerp(b, t) + normal * offset
			visit.call(center, lerpf(line.half_widths[segment], line.half_widths[segment + 1], t), along)

# Roads wander less than rivers: they follow the world's course within about a tile.
static func road_offset(along: float, phase: float) -> float:
	return ROAD_MEANDER_TILES * (sin(along / 7.0 + phase) * 0.6 + sin(along / 2.9 + phase * 1.3) * 0.4)

# --- Roads ---------------------------------------------------------------------------------

# The world's roads, tile by tile. Roads never run over lakes or the sea, ford rivers, and
# keep mountain passes open (handled in place_relief).
func stamp_roads() -> void:
	var key: int = terrain.chunk_key(Vector2i(floori(float(origin.x + RegionalTerrain.APRON_TILES) / RegionalTerrain.CHUNK_TILES), floori(float(origin.y + RegionalTerrain.APRON_TILES) / RegionalTerrain.CHUNK_TILES)))
	for line_index: int in terrain.chunk_road_lines.get(key, PackedInt32Array()):
		var line: RegionalTerrain.Polyline = terrain.road_lines[line_index]
		walk_line(line, ROAD_MEANDER_TILES + 2.0, func(center: Vector2, _half_width: float, _along: float) -> void:
			var x: int = floori(center.x)
			var y: int = floori(center.y)
			if x < 0 or y < 0 or x >= width or y >= width:
				return
			var i: int = y * width + x
			if types[i] == RegionalChunk.TYPE_LAKE or types[i] == RegionalChunk.TYPE_SEA:
				return
			flags[i] |= RegionalChunk.FLAG_ROAD
			if types[i] == RegionalChunk.TYPE_RIVER:
				flags[i] |= RegionalChunk.FLAG_FORD)

# --- Land -------------------------------------------------------------------------------------

# Tiles matching is_source count 0; others get an approximate distance in tiles (chamfer).
func distance_field(is_source: Callable) -> PackedFloat32Array:
	var distance: PackedFloat32Array = PackedFloat32Array()
	distance.resize(width * width)
	for i in range(width * width):
		distance[i] = 0.0 if is_source.call(types[i]) else 9999.0
	for y in range(width):
		for x in range(width):
			var i: int = y * width + x
			var d: float = distance[i]
			if x > 0:
				d = minf(d, distance[i - 1] + 1.0)
			if y > 0:
				d = minf(d, distance[i - width] + 1.0)
				if x > 0:
					d = minf(d, distance[i - width - 1] + 1.414)
				if x < width - 1:
					d = minf(d, distance[i - width + 1] + 1.414)
			distance[i] = d
	for y in range(width - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			var i: int = y * width + x
			var d: float = distance[i]
			if x < width - 1:
				d = minf(d, distance[i + 1] + 1.0)
			if y < width - 1:
				d = minf(d, distance[i + width] + 1.0)
				if x < width - 1:
					d = minf(d, distance[i + width + 1] + 1.414)
				if x > 0:
					d = minf(d, distance[i + width - 1] + 1.414)
			distance[i] = d
	return distance

# Hills and mountains where the world is high or rough, with valleys along rivers. The local
# shares follow the formulas the earlier per-region maps applied region-wide.
func place_relief(river_distance: PackedFloat32Array) -> void:
	for y in range(width):
		for x in range(width):
			var i: int = y * width + x
			if types[i] != RegionalChunk.TYPE_GRASS:
				continue
			var mountain_share: float = clampf((local_relief[i] - 0.3) * 0.6, 0.0, 0.3) + clampf((local_elevation[i] - 0.35) * 0.3, 0.0, 0.1)
			var hill_share: float = clampf(0.07 + local_relief[i] * 0.35 + maxf(local_elevation[i] - 0.13, 0.0) * 0.8, 0.07, 0.4)
			var height: float = noise_at(NOISE_RELIEF, x, y)
			height += ((elevation[i] - local_elevation[i]) * 2.0 + (relief[i] - local_relief[i]) * 0.8) * 2.0
			height -= 1.2 * (1.0 - smoothstep(0.0, 5.0, river_distance[i]))
			var height_rank: float = rank(NOISE_RELIEF, height)
			if height_rank > 1.0 - mountain_share:
				# Roads keep their passes: a mountain on a road is crossed as a hill.
				types[i] = RegionalChunk.TYPE_HILL if flags[i] & RegionalChunk.FLAG_ROAD != 0 else RegionalChunk.TYPE_MOUNTAIN
			elif height_rank > 1.0 - mountain_share - hill_share:
				types[i] = RegionalChunk.TYPE_HILL

static func climate_family_of(local_temp: float, local_moist: float) -> String:
	if local_temp < 0.33:
		return RegionalTerrain.CLIMATE_COLD
	if local_moist < 0.4:
		return RegionalTerrain.CLIMATE_ARID
	if local_temp >= 0.74 and local_moist > 0.5:
		return RegionalTerrain.CLIMATE_TROPICAL
	return RegionalTerrain.CLIMATE_TEMPERATE

static func is_open_land(tile_type: int) -> bool:
	return tile_type == RegionalChunk.TYPE_GRASS or tile_type == RegionalChunk.TYPE_HILL

# Same distance-to-water chances as the original valley, scaled by climate.
func place_farmland(fresh_water: PackedFloat32Array) -> void:
	for y in range(width):
		for x in range(width):
			var i: int = y * width + x
			if not is_open_land(types[i]) or local_temperature[i] <= FROZEN_TEMPERATURE:
				continue
			var near_scale: float = 1.0
			var far_scale: float = 1.0
			match climate_family_of(local_temperature[i], local_moisture[i]):
				RegionalTerrain.CLIMATE_ARID:
					near_scale = 0.85
					far_scale = 0.15
				RegionalTerrain.CLIMATE_COLD:
					near_scale = 0.55
					far_scale = 0.55
				RegionalTerrain.CLIMATE_TROPICAL:
					near_scale = 0.9
					far_scale = 0.9
			var distance: float = fresh_water[i]
			var chance: float = 0.025 * far_scale
			if distance <= 3.0:
				chance = 0.74 * near_scale
			elif distance <= 6.0:
				chance = 0.45 * near_scale
			elif distance <= 9.0:
				chance = 0.16 * far_scale
			if types[i] == RegionalChunk.TYPE_HILL:
				chance *= 0.6
			if rank(NOISE_FARMLAND, noise_at(NOISE_FARMLAND, x, y)) < chance:
				flags[i] |= RegionalChunk.FLAG_FERTILE

# Woodland in the share the world's forest cover asks for, keeping to the water in dry country.
func place_woods(fresh_water: PackedFloat32Array) -> void:
	for y in range(width):
		for x in range(width):
			var i: int = y * width + x
			if not is_open_land(types[i]) or local_temperature[i] <= FROZEN_TEMPERATURE:
				continue
			var arid: bool = climate_family_of(local_temperature[i], local_moisture[i]) == RegionalTerrain.CLIMATE_ARID
			var share: float = clampf(local_forest[i] * 0.75 + 0.06, 0.05, 0.7)
			if arid:
				share = minf(share, 0.07)
			if local_temperature[i] < 0.2:
				share = minf(share, 0.04)
			share += (forest_cover[i] - local_forest[i]) * 0.6
			if types[i] == RegionalChunk.TYPE_HILL:
				share -= 0.12
			if fresh_water[i] <= 3.0:
				share += 0.3 if arid else 0.06
			if rank(NOISE_WOODS, noise_at(NOISE_WOODS, x, y)) < share:
				flags[i] |= RegionalChunk.FLAG_FOREST

# Stone and iron in clusters, one chance per DEPOSIT_CELL_TILES cell, likelier in high and
# rough country. Where clusters overlap, the one with the higher priority wins, so the result
# does not depend on which chunk lays them.
func place_deposits() -> void:
	var cell_size: int = DEPOSIT_CELL_TILES
	var cells_around: int = terrain.size_tiles.x / cell_size
	deposit_priority.resize(width * width)
	deposit_priority.fill(-1.0)
	var reach: int = 5
	for cell_y in range(floori(float(origin.y - reach) / cell_size), floori(float(origin.y + width + reach) / cell_size) + 1):
		for cell_x in range(floori(float(origin.x - reach) / cell_size), floori(float(origin.x + width + reach) / cell_size) + 1):
			var wrapped_x: int = posmod(cell_x, cells_around)
			var cell_center: Vector2 = terrain.tile_center_to_world(Vector2i(cell_x * cell_size + cell_size / 2, cell_y * cell_size + cell_size / 2))
			var area_relief: float = terrain.sample_field(terrain.mean_relief, cell_center)
			var area_elevation: float = terrain.sample_field(terrain.mean_elevation, cell_center)
			if area_elevation <= 0.0:
				continue
			var mountain_share: float = clampf((area_relief - 0.3) * 0.6, 0.0, 0.3) + clampf((area_elevation - 0.35) * 0.3, 0.0, 0.1)
			var hill_share: float = clampf(0.07 + area_relief * 0.35 + maxf(area_elevation - 0.13, 0.0) * 0.8, 0.07, 0.4)
			# Cluster counts per original 80x50 map, scaled to one cell.
			var cell_share: float = float(cell_size * cell_size) / 4000.0
			var iron_chance: float = (2.0 + 12.0 * mountain_share) * cell_share if mountain_share > 0.02 else 0.0
			var stone_chance: float = (3.0 + 10.0 * hill_share) * cell_share
			lay_cluster(wrapped_x, cell_x, cell_y, RegionalChunk.RESOURCE_IRON, iron_chance, 2, 4, 0.48)
			lay_cluster(wrapped_x, cell_x, cell_y, RegionalChunk.RESOURCE_STONE, stone_chance, 2, 5, 0.52)

func lay_cluster(wrapped_x: int, cell_x: int, cell_y: int, resource: int, chance: float, min_radius: int, max_radius: int, fill: float) -> void:
	var salt: int = 100 + resource * 10
	if hash01(wrapped_x, cell_y, salt) >= chance:
		return
	var cell_size: int = DEPOSIT_CELL_TILES
	var center: Vector2i = Vector2i(cell_x * cell_size + floori(hash01(wrapped_x, cell_y, salt + 1) * cell_size), cell_y * cell_size + floori(hash01(wrapped_x, cell_y, salt + 2) * cell_size))
	var radius: int = min_radius + floori(hash01(wrapped_x, cell_y, salt + 3) * (max_radius - min_radius + 1))
	var cluster_priority: float = hash01(wrapped_x, cell_y, salt + 4) + resource * 0.0001
	for gy in range(center.y - radius, center.y + radius + 1):
		var y: int = gy - origin.y
		if y < 0 or y >= width:
			continue
		for gx in range(center.x - radius, center.x + radius + 1):
			var x: int = gx - origin.x
			if x < 0 or x >= width:
				continue
			if Vector2(gx - center.x, gy - center.y).length() > radius:
				continue
			var i: int = y * width + x
			if not is_open_land(types[i]):
				continue
			if hash01(posmod(gx, terrain.size_tiles.x), gy, salt + 5) > fill:
				continue
			if cluster_priority <= deposit_priority[i]:
				continue
			deposit_priority[i] = cluster_priority
			resources[i] = resource
			flags[i] &= ~RegionalChunk.FLAG_FOREST

# --- Output ------------------------------------------------------------------------------------

func package(chunk_coords: Vector2i) -> RegionalChunk:
	var chunk: RegionalChunk = RegionalChunk.new()
	var keep: int = RegionalTerrain.KEEP_APRON_TILES
	var offset: int = RegionalTerrain.APRON_TILES - keep
	var size: int = RegionalTerrain.CHUNK_TILES + keep * 2
	chunk.coords = chunk_coords
	chunk.core_origin = chunk_coords * RegionalTerrain.CHUNK_TILES
	chunk.stored_origin = chunk.core_origin - Vector2i(keep, keep)
	chunk.stored_size = size
	chunk.planet_width = terrain.size_tiles.x
	var count: int = size * size
	var land_distance: PackedFloat32Array = distance_field(func(t: int) -> bool: return not RegionalChunk.is_water_type(t))
	var temperature_sum: float = 0.0
	var moisture_sum: float = 0.0
	var land_tiles: int = 0
	var types_out: PackedByteArray = PackedByteArray()
	var flags_out: PackedByteArray = PackedByteArray()
	var resources_out: PackedByteArray = PackedByteArray()
	var temperature_out: PackedByteArray = PackedByteArray()
	var moisture_out: PackedByteArray = PackedByteArray()
	var depth_out: PackedByteArray = PackedByteArray()
	var regions_out: PackedByteArray = PackedByteArray()
	types_out.resize(count)
	flags_out.resize(count)
	resources_out.resize(count)
	temperature_out.resize(count)
	moisture_out.resize(count)
	depth_out.resize(count)
	regions_out.resize(count)
	for y in range(size):
		for x in range(size):
			var i: int = (y + offset) * width + x + offset
			var o: int = y * size + x
			types_out[o] = types[i]
			flags_out[o] = flags[i]
			resources_out[o] = resources[i]
			temperature_out[o] = int(clampf(temperature[i], 0.0, 1.0) * 255.0)
			moisture_out[o] = int(clampf(moisture[i], 0.0, 1.0) * 255.0)
			depth_out[o] = int(clampf(land_distance[i] / RegionalChunk.DEPTH_TILES, 0.0, 1.0) * 255.0)
			var region_id: int = terrain.region_vote_at(terrain.tile_center_to_world(chunk.stored_origin + Vector2i(x, y)))
			regions_out[o] = region_id + 1 if region_id >= 0 and region_id < 255 else 0
			if x >= keep and y >= keep and x < size - keep and y < size - keep and not RegionalChunk.is_water_type(types[i]):
				temperature_sum += local_temperature[i]
				moisture_sum += local_moisture[i]
				land_tiles += 1
	chunk.types = types_out
	chunk.flags = flags_out
	chunk.resources = resources_out
	chunk.temperature = temperature_out
	chunk.moisture = moisture_out
	chunk.shore_depth = depth_out
	chunk.regions = regions_out
	if land_tiles > 0:
		chunk.mean_temperature = temperature_sum / land_tiles
		chunk.mean_moisture = moisture_sum / land_tiles
	else:
		var center: int = (width / 2) * width + width / 2
		chunk.mean_temperature = local_temperature[center]
		chunk.mean_moisture = local_moisture[center]
	chunk.climate_family = climate_family_of(chunk.mean_temperature, chunk.mean_moisture)
	return chunk
