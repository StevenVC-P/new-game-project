class_name RegionalTerrain
extends RefCounted

# The whole planet at regional-map scale: one tile is TILE_WORLD_UNITS world units, so the
# planet is 6000x3000 tiles and the regional map is the world atlas magnified. Tiles are a
# pure function of their global position, generated on demand in CHUNK_TILES chunks
# (RegionalChunkGenerator) and cached, so any two views of the same place agree and the map
# can be scrolled without edges.
#
# Coordinates: a global tile (gx, gy) has gx wrapping around the planet (0..size.x) and gy
# running from the north pole (0) to the south pole (size.y). Map units, as everywhere on
# the regional map, are RegionMapStyle.TILE (12) per tile, i.e. 10 per world unit.
#
# Game rules keep working on bounded tile arrays: extract_window() returns tiles in the
# format RegionMapGenerator produces, for any window of the planet.

const TILE_WORLD_UNITS: float = 1.2
const CHUNK_TILES: int = 60
# Generation margin around a chunk. Rules that look at neighbours (distance to rivers for
# valleys and farmland, shore depth, deposit clusters) reach at most this far, so a tile
# comes out the same whichever chunk generates it.
const APRON_TILES: int = 16
# Margin kept with each chunk so the terrain shader can smooth across chunk edges.
const KEEP_APRON_TILES: int = 4
# World fields are sampled on a lattice of this spacing and interpolated per tile; a world
# terrain texel spans almost six tiles, so nothing is lost.
const LATTICE_TILES: int = 4
# Blur (in world terrain texels) for the local averages that set how much high ground,
# woodland, and farmland an area gets.
const LOCAL_MEAN_TEXELS: int = 6
const MAX_CACHED_CHUNKS: int = 220
# How far a world settlement may move to stand on buildable ground (the old regional town's reach).
const SETTLEMENT_SNAP_TILES: int = 14

# Minor streams: the world map draws only major rivers. Sources sit on a jittered grid.
const STREAM_SOURCE_SPACING_WORLD: float = 150.0
const STREAM_STEP_WORLD: float = 2.5
const STREAM_MAX_STEPS: int = 180
const STREAM_MIN_LENGTH_WORLD: float = 30.0
const STREAM_RIVER_CLEARANCE_WORLD: float = 40.0
# A stream joins a river once it is within about this distance of it.
const STREAM_JOIN_WORLD: float = 4.0
const STREAM_HALF_WIDTH: float = 1.15

const LINE_RIVER: int = 0
const LINE_STREAM: int = 1
const LINE_ROAD: int = 2

class Polyline:
	var kind: int = LINE_RIVER
	var name: String = ""
	var road_class: int = WorldMapData.ROAD_LOCAL
	# Tile coordinates, unwrapped so consecutive points never jump across the planet.
	var points: PackedVector2Array = PackedVector2Array()
	# Distance along the line (tiles) at each point.
	var along: PackedFloat32Array = PackedFloat32Array()
	var half_widths: PackedFloat32Array = PackedFloat32Array()
	var phase: float = 0.0
	var world_road_id: int = -1

var world: WorldMapData = null
var size_tiles: Vector2i = Vector2i.ZERO
var chunk_counts: Vector2i = Vector2i.ZERO

# World fields copied out of the terrain image (row-major, terrain resolution), plus their
# local averages.
var field_size: Vector2i = Vector2i.ZERO
var field_elevation: PackedFloat32Array = PackedFloat32Array()
var field_moisture: PackedFloat32Array = PackedFloat32Array()
var field_forest: PackedFloat32Array = PackedFloat32Array()
var field_relief: PackedFloat32Array = PackedFloat32Array()
var mean_elevation: PackedFloat32Array = PackedFloat32Array()
var mean_relief: PackedFloat32Array = PackedFloat32Array()
var mean_forest: PackedFloat32Array = PackedFloat32Array()
var mean_moisture: PackedFloat32Array = PackedFloat32Array()

# Political grid with regions spread into the sea, voted on exactly like the atlas shader.
var spread_regions: PackedInt32Array = PackedInt32Array()
# 1 where all 4x4 cells of a vote starting one cell up-left are the same region.
var uniform_vote: PackedByteArray = PackedByteArray()

var water_lines: Array[Polyline] = []
var road_lines: Array[Polyline] = []
# Chunk key -> PackedInt32Array of line indices that may touch the chunk's generation window.
var chunk_water_lines: Dictionary = {}
var chunk_road_lines: Dictionary = {}

# Sorted noise samples per noise kind; a value's position in them is its rank (0..1).
var noise_cdfs: Dictionary = {}

var mutex: Mutex = Mutex.new()
var chunks: Dictionary = {}
var chunk_last_used: Dictionary = {}
var pending_tasks: Dictionary = {}
var use_counter: int = 0
var settlement_tiles: Dictionary = {}
# Chunk key -> ids of world settlements whose world position lies in that chunk.
var settlements_by_chunk: Dictionary = {}
# Called with each new chunk on the thread that made it (the renderer prepares its data).
var chunk_finisher: Callable = Callable()
# Road line index -> its meandering course in tiles (see road_course).
var road_courses: Dictionary = {}

func _init(world_data: WorldMapData) -> void:
	world = world_data
	size_tiles = Vector2i(roundi(world.world_size.x / TILE_WORLD_UNITS), roundi(world.world_size.y / TILE_WORLD_UNITS))
	chunk_counts = Vector2i(size_tiles.x / CHUNK_TILES, size_tiles.y / CHUNK_TILES)
	copy_world_fields()
	spread_regions = world.region_grid_spread_into_water()
	build_uniform_vote()
	noise_cdfs = RegionalChunkGenerator.build_noise_cdfs()
	build_water_lines()
	build_road_lines()
	for settlement: WorldMapData.Settlement in world.settlements:
		var key: int = chunk_key(chunk_of_tile(world_to_tile_index(settlement.position)))
		if not settlements_by_chunk.has(key):
			settlements_by_chunk[key] = []
		(settlements_by_chunk[key] as Array).append(settlement.id)

# --- Coordinates ---------------------------------------------------------------------

func wrap_tile_x(x: int) -> int:
	return posmod(x, size_tiles.x)

func wrap_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(posmod(tile.x, size_tiles.x), tile.y)

func is_tile_on_planet(tile: Vector2i) -> bool:
	return tile.y >= 0 and tile.y < size_tiles.y

# World position of a tile's center.
func tile_center_to_world(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_WORLD_UNITS

# Fractional tile coordinates of a world position (unwrapped: x follows the input).
func world_to_tile(world_pos: Vector2) -> Vector2:
	return world_pos / TILE_WORLD_UNITS

func world_to_tile_index(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_to_tile(world_pos).floor())

func chunk_of_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(wrap_tile_x(tile.x)) / CHUNK_TILES), floori(float(tile.y) / CHUNK_TILES))

func chunk_key(chunk: Vector2i) -> int:
	return chunk.y * chunk_counts.x + posmod(chunk.x, chunk_counts.x)

func is_chunk_on_planet(chunk: Vector2i) -> bool:
	return chunk.y >= 0 and chunk.y < chunk_counts.y

# --- World fields ---------------------------------------------------------------------

func copy_world_fields() -> void:
	field_size = world.terrain_size
	var count: int = field_size.x * field_size.y
	field_elevation.resize(count)
	field_moisture.resize(count)
	field_forest.resize(count)
	field_relief.resize(count)
	var texels: PackedFloat32Array = world.terrain_image.get_data().to_float32_array()
	for i in range(count):
		field_elevation[i] = texels[i * 4]
		field_moisture[i] = texels[i * 4 + 1]
		field_forest[i] = texels[i * 4 + 2]
		field_relief[i] = texels[i * 4 + 3]
	var land_elevation: PackedFloat32Array = PackedFloat32Array()
	land_elevation.resize(count)
	for i in range(count):
		land_elevation[i] = maxf(field_elevation[i], 0.0)
	mean_elevation = WorldFieldBuilder.blur(land_elevation, field_size.x, field_size.y, LOCAL_MEAN_TEXELS, 2)
	mean_relief = WorldFieldBuilder.blur(field_relief, field_size.x, field_size.y, LOCAL_MEAN_TEXELS, 2)
	mean_forest = WorldFieldBuilder.blur(field_forest, field_size.x, field_size.y, LOCAL_MEAN_TEXELS, 2)
	mean_moisture = WorldFieldBuilder.blur(field_moisture, field_size.x, field_size.y, LOCAL_MEAN_TEXELS, 2)

# Bilinear sample of a terrain-resolution field, matching WorldMapData.terrain_at.
func sample_field(field: PackedFloat32Array, world_pos: Vector2) -> float:
	var fx: float = fposmod(world_pos.x, world.world_size.x) / world.world_size.x * field_size.x - 0.5
	var fy: float = clampf(world_pos.y / world.world_size.y * field_size.y - 0.5, 0.0, field_size.y - 1.0)
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var tx: float = fx - x0
	var ty: float = fy - y0
	var x1: int = posmod(x0 + 1, field_size.x)
	x0 = posmod(x0, field_size.x)
	var y1: int = mini(y0 + 1, field_size.y - 1)
	var top: float = lerpf(field[y0 * field_size.x + x0], field[y0 * field_size.x + x1], tx)
	var bottom: float = lerpf(field[y1 * field_size.x + x0], field[y1 * field_size.x + x1], tx)
	return lerpf(top, bottom, ty)

# Cubic B-spline sample of elevation, the filter the atlas shader draws coasts with, so a
# coast lies in the same place on both maps.
func sample_elevation_smooth(world_pos: Vector2) -> float:
	var fx: float = fposmod(world_pos.x, world.world_size.x) / world.world_size.x * field_size.x - 0.5
	var fy: float = world_pos.y / world.world_size.y * field_size.y - 0.5
	var ix: int = floori(fx)
	var iy: int = floori(fy)
	var wx: Vector4 = bspline_weights(fx - ix)
	var wy: Vector4 = bspline_weights(fy - iy)
	var total: float = 0.0
	for j in range(4):
		var row: int = clampi(iy - 1 + j, 0, field_size.y - 1) * field_size.x
		var row_sum: float = 0.0
		for i in range(4):
			row_sum += field_elevation[row + posmod(ix - 1 + i, field_size.x)] * wx[i]
		total += row_sum * wy[j]
	return total

static func bspline_weights(f: float) -> Vector4:
	var f2: float = f * f
	var f3: float = f2 * f
	return Vector4((1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0, (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0, (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0, f3 / 6.0)

# --- Regions ----------------------------------------------------------------------------

func build_uniform_vote() -> void:
	var width: int = world.political_size.x
	var height: int = world.political_size.y
	uniform_vote.resize(width * height)
	for y in range(height):
		for x in range(width):
			var first: int = spread_regions[clampi(y - 1, 0, height - 1) * width + posmod(x - 1, width)]
			var same: bool = true
			for j in range(4):
				var row: int = clampi(y - 1 + j, 0, height - 1) * width
				for i in range(4):
					if spread_regions[row + posmod(x - 1 + i, width)] != first:
						same = false
						break
				if not same:
					break
			uniform_vote[y * width + x] = 1 if same else 0

# Region at a world position by the atlas shader's smooth vote over the 4x4 political cells
# around it, so a border lies where the atlas draws it. Over water this is the region the
# sea was spread from; use region_id_at_tile for land-only answers.
func region_vote_at(world_pos: Vector2) -> int:
	var width: int = world.political_size.x
	var height: int = world.political_size.y
	var pc: Vector2 = Vector2(fposmod(world_pos.x, world.world_size.x) / world.world_size.x * width, world_pos.y / world.world_size.y * height) - Vector2(0.5, 0.5)
	var base: Vector2i = Vector2i(pc.floor())
	var base_index: int = clampi(base.y, 0, height - 1) * width + posmod(base.x, width)
	if base.y >= 0 and base.y < height and uniform_vote[base_index] == 1:
		return spread_regions[clampi(base.y - 1, 0, height - 1) * width + posmod(base.x - 1, width)]
	var wx: Vector4 = bspline_weights(pc.x - base.x)
	var wy: Vector4 = bspline_weights(pc.y - base.y)
	var votes: Dictionary = {}
	for j in range(4):
		var row: int = clampi(base.y - 1 + j, 0, height - 1) * width
		for i in range(4):
			var region_id: int = spread_regions[row + posmod(base.x - 1 + i, width)]
			votes[region_id] = votes.get(region_id, 0.0) + wx[i] * wy[j]
	var best: int = -1
	var best_weight: float = -1.0
	for region_id: int in votes:
		# Ties go to the lower id so the answer never depends on dictionary order.
		var weight: float = votes[region_id]
		if weight > best_weight + 1e-6 or (absf(weight - best_weight) <= 1e-6 and region_id < best):
			best_weight = weight
			best = region_id
	return best

# Region under a tile, or -1 on water.
func region_id_at_tile(tile: Vector2i) -> int:
	var chunk: RegionalChunk = get_chunk_now(chunk_of_tile(tile))
	if chunk == null or chunk.is_water(tile):
		return -1
	return chunk.region_at(tile)

# Frontier land (no kingdom holds it) is where the player may settle.
func is_frontier_region(region_id: int) -> bool:
	var region: WorldMapData.Region = world.get_region(region_id)
	return region != null and region.owner_kingdom_id == -1

# --- Lines: rivers, streams, roads ---------------------------------------------------------

func build_water_lines() -> void:
	for river_index in range(world.rivers.size()):
		var river: WorldMapData.River = world.rivers[river_index]
		var line: Polyline = Polyline.new()
		line.kind = LINE_RIVER
		line.name = river.name
		line.phase = fposmod(river_index * 2.399, TAU)
		for i in range(river.points.size()):
			# Rivers are drawn a little wider than the world scale suggests so they stay readable.
			line.half_widths.append(clampf(0.9 + river.widths[i] / TILE_WORLD_UNITS * 0.45, 1.0, 2.6))
		set_line_points(line, river.points)
		water_lines.append(line)
	for stream_points: PackedVector2Array in trace_streams():
		var line: Polyline = Polyline.new()
		line.kind = LINE_STREAM
		line.phase = fposmod(water_lines.size() * 2.399, TAU)
		for _i in range(stream_points.size()):
			line.half_widths.append(STREAM_HALF_WIDTH)
		set_line_points(line, stream_points)
		water_lines.append(line)
	chunk_water_lines = index_lines(water_lines, RegionalChunkGenerator.RIVER_MEANDER_TILES + 3.0)

func build_road_lines() -> void:
	for road: WorldMapData.Road in world.roads:
		var line: Polyline = Polyline.new()
		line.kind = LINE_ROAD
		line.road_class = road.road_class
		line.world_road_id = road.id
		line.phase = fposmod(road.id * 1.618, TAU)
		for _i in range(road.points.size()):
			line.half_widths.append(0.0)
		set_line_points(line, road.points)
		road_lines.append(line)
	chunk_road_lines = index_lines(road_lines, RegionalChunkGenerator.ROAD_MEANDER_TILES + 2.0)

# The course a road is stamped along (RegionalChunkGenerator.walk_line), as tile points
# (unwrapped) about every 1.2 tiles, for drawing the road where its tiles are.
func road_course(line_index: int) -> PackedVector2Array:
	if road_courses.has(line_index):
		return road_courses[line_index]
	var line: Polyline = road_lines[line_index]
	var course: PackedVector2Array = PackedVector2Array()
	for segment in range(line.points.size() - 1):
		var a: Vector2 = line.points[segment]
		var b: Vector2 = line.points[segment + 1]
		var length: float = a.distance_to(b)
		if length < 1e-4:
			continue
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var steps: int = maxi(1, ceili(length / 1.2))
		for step in range(steps):
			var t: float = float(step) / steps
			var along: float = lerpf(line.along[segment], line.along[segment + 1], t)
			course.append(a.lerp(b, t) + normal * RegionalChunkGenerator.road_offset(along, line.phase))
	var last: int = line.points.size() - 1
	course.append(line.points[last] + (line.points[last] - line.points[last - 1]).normalized().orthogonal() * RegionalChunkGenerator.road_offset(line.along[last], line.phase))
	road_courses[line_index] = course
	return course

# World points to unwrapped tile points, with distances along the line.
func set_line_points(line: Polyline, world_points: PackedVector2Array) -> void:
	var previous_x: float = 0.0
	var travelled: float = 0.0
	for i in range(world_points.size()):
		var tile_point: Vector2 = world_to_tile(world_points[i])
		if i > 0:
			tile_point.x = previous_x + world.wrapped_delta_x(previous_x * TILE_WORLD_UNITS, world_points[i].x) / TILE_WORLD_UNITS
			travelled += line.points[i - 1].distance_to(tile_point)
		line.points.append(tile_point)
		line.along.append(travelled)
		previous_x = tile_point.x

# Chunk key -> indices of lines passing within reach of the chunk's generation window.
func index_lines(lines: Array[Polyline], reach_tiles: float) -> Dictionary:
	var buckets: Dictionary = {}
	var margin: float = reach_tiles + APRON_TILES + 3.0
	for line_index in range(lines.size()):
		var line: Polyline = lines[line_index]
		for i in range(line.points.size() - 1):
			var a: Vector2 = line.points[i]
			var b: Vector2 = line.points[i + 1]
			var low: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(margin, margin)
			var high: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(margin, margin)
			for cy in range(maxi(0, floori(low.y / CHUNK_TILES)), mini(chunk_counts.y - 1, floori(high.y / CHUNK_TILES)) + 1):
				for cx in range(floori(low.x / CHUNK_TILES), floori(high.x / CHUNK_TILES) + 1):
					var key: int = chunk_key(Vector2i(cx, cy))
					if not buckets.has(key):
						buckets[key] = {}
					(buckets[key] as Dictionary)[line_index] = true
	var result: Dictionary = {}
	for key: int in buckets:
		var indices: PackedInt32Array = PackedInt32Array((buckets[key] as Dictionary).keys())
		indices.sort()
		result[key] = indices
	return result

# Downhill paths on the world's elevation from sources on a jittered grid, ending at the sea,
# a lake, a river, or another stream (which makes them tributaries). Regions far from the
# world's rivers get their streams this way.
func trace_streams() -> Array[PackedVector2Array]:
	var streams: Array[PackedVector2Array] = []
	var river_cells: Dictionary = cells_near_lines(world.rivers, STREAM_RIVER_CLEARANCE_WORLD)
	var river_mouth_cells: Dictionary = cells_near_lines(world.rivers, STREAM_JOIN_WORLD)
	var visited: Dictionary = {}
	var spacing: float = STREAM_SOURCE_SPACING_WORLD
	var columns: int = roundi(world.world_size.x / spacing)
	var rows: int = roundi(world.world_size.y / spacing)
	for row in range(rows):
		for column in range(columns):
			var jitter: Vector2 = Vector2(RegionalChunkGenerator.hash01(column, row, 71), RegionalChunkGenerator.hash01(column, row, 72))
			var source: Vector2 = (Vector2(column, row) + Vector2(0.2, 0.2) + jitter * 0.6) * spacing
			if river_cells.has(grid_cell(source, STREAM_RIVER_CLEARANCE_WORLD)):
				continue
			var elevation: float = sample_field(field_elevation, source)
			var latitude: float = world.latitude_at(source.y)
			if elevation < 0.03 or sample_field(field_moisture, source) < 0.3:
				continue
			if WorldFieldBuilder.temperature(latitude, elevation) <= RegionalChunkGenerator.FROZEN_TEMPERATURE:
				continue
			var path: PackedVector2Array = trace_downhill(source, visited, streams.size(), river_mouth_cells)
			if WorldFieldBuilder.polyline_length(path) >= STREAM_MIN_LENGTH_WORLD:
				streams.append(path)
	return streams

func grid_cell(world_pos: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(fposmod(world_pos.x, world.world_size.x) / cell_size), floori(world_pos.y / cell_size))

# Cells of the given size that lie within about one cell of a world river.
func cells_near_lines(rivers: Array[WorldMapData.River], cell_size: float) -> Dictionary:
	var cells: Dictionary = {}
	var columns: int = roundi(world.world_size.x / cell_size)
	for river: WorldMapData.River in rivers:
		for point: Vector2 in river.points:
			var cell: Vector2i = grid_cell(point, cell_size)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					cells[Vector2i(posmod(cell.x + dx, columns), cell.y + dy)] = true
	return cells

func trace_downhill(source: Vector2, visited: Dictionary, stream_index: int, river_mouth_cells: Dictionary) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array([source])
	var position: Vector2 = source
	var heading: Vector2 = Vector2.ZERO
	var probe: float = STREAM_STEP_WORLD * 1.5
	var rising_steps: int = 0
	var previous_elevation: float = sample_field(field_elevation, source)
	for _step in range(STREAM_MAX_STEPS):
		var gradient: Vector2 = Vector2(
			sample_field(field_elevation, position + Vector2(probe, 0.0)) - sample_field(field_elevation, position - Vector2(probe, 0.0)),
			sample_field(field_elevation, position + Vector2(0.0, probe)) - sample_field(field_elevation, position - Vector2(0.0, probe)))
		var downhill: Vector2 = -gradient.normalized() if gradient.length() > 1e-6 else heading
		if downhill == Vector2.ZERO:
			break
		# Some inertia keeps the course from zig-zagging across flat ground.
		heading = (downhill + heading * 0.6).normalized() if heading != Vector2.ZERO else downhill
		position += heading * STREAM_STEP_WORLD
		path.append(position)
		var elevation: float = sample_field(field_elevation, position)
		if elevation <= 0.0:
			break
		var cell: Vector2i = Vector2i(floori(fposmod(position.x, world.world_size.x) / 6.0), floori(position.y / 6.0))
		var owner: int = visited.get(cell, -1)
		if owner >= 0 and owner != stream_index:
			break
		visited[cell] = stream_index
		if river_mouth_cells.has(grid_cell(position, STREAM_JOIN_WORLD)):
			# Close enough to a river to flow into it.
			break
		rising_steps = rising_steps + 1 if elevation >= previous_elevation else 0
		if rising_steps >= 4:
			# A hollow with no way down: the stream ends in it.
			break
		previous_elevation = elevation
	return path

# --- Chunks -----------------------------------------------------------------------------

# Starts generating a chunk on a worker thread unless it is cached or already under way.
func request_chunk(chunk: Vector2i) -> void:
	if not is_chunk_on_planet(chunk):
		return
	var key: int = chunk_key(chunk)
	mutex.lock()
	var known: bool = chunks.has(key) or pending_tasks.has(key)
	mutex.unlock()
	if known:
		return
	var canonical: Vector2i = Vector2i(posmod(chunk.x, chunk_counts.x), chunk.y)
	pending_tasks[key] = WorkerThreadPool.add_task(generate_task.bind(key, canonical), false, "Regional chunk")

func generate_task(key: int, chunk: Vector2i) -> void:
	var generated: RegionalChunk = make_chunk(chunk)
	mutex.lock()
	if not chunks.has(key):
		chunks[key] = generated
	mutex.unlock()

func make_chunk(chunk: Vector2i) -> RegionalChunk:
	var generated: RegionalChunk = RegionalChunkGenerator.new(self).generate(chunk)
	if chunk_finisher.is_valid():
		chunk_finisher.call(generated)
	return generated

# Finishes completed worker tasks and trims the cache. Call once per frame from the main thread.
func poll() -> void:
	for key: int in pending_tasks.keys():
		var task_id: int = pending_tasks[key]
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			pending_tasks.erase(key)
	trim_cache()

# Waits for every chunk still generating. Call before the terrain's owner goes away: a worker
# thread still running a task while the engine shuts down keeps the process from exiting.
func wait_for_tasks() -> void:
	for key: int in pending_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(pending_tasks[key])
	pending_tasks.clear()

func get_chunk_if_ready(chunk: Vector2i) -> RegionalChunk:
	if not is_chunk_on_planet(chunk):
		return null
	var key: int = chunk_key(chunk)
	mutex.lock()
	var found: RegionalChunk = chunks.get(key, null)
	mutex.unlock()
	if found != null:
		use_counter += 1
		chunk_last_used[key] = use_counter
	return found

# The chunk, generated on this thread if it is not cached yet.
func get_chunk_now(chunk: Vector2i) -> RegionalChunk:
	if not is_chunk_on_planet(chunk):
		return null
	var ready: RegionalChunk = get_chunk_if_ready(chunk)
	if ready != null:
		return ready
	var key: int = chunk_key(chunk)
	if pending_tasks.has(key):
		WorkerThreadPool.wait_for_task_completion(pending_tasks[key])
		pending_tasks.erase(key)
		return get_chunk_if_ready(chunk)
	var generated: RegionalChunk = make_chunk(Vector2i(posmod(chunk.x, chunk_counts.x), chunk.y))
	mutex.lock()
	chunks[key] = generated
	mutex.unlock()
	use_counter += 1
	chunk_last_used[key] = use_counter
	return generated

func trim_cache() -> void:
	# Worker threads add to chunks, so it is only read under the lock.
	mutex.lock()
	var cached: int = chunks.size()
	var keys: Array = chunks.keys() if cached > MAX_CACHED_CHUNKS else []
	mutex.unlock()
	if keys.is_empty():
		return
	var by_age: Array = []
	for key: int in keys:
		by_age.append(Vector2i(chunk_last_used.get(key, 0), key))
	by_age.sort()
	mutex.lock()
	for i in range(by_age.size() - MAX_CACHED_CHUNKS):
		var key: int = (by_age[i] as Vector2i).y
		chunks.erase(key)
		chunk_last_used.erase(key)
	mutex.unlock()

# --- Tiles for game rules -------------------------------------------------------------------

func tile_at(tile: Vector2i) -> Dictionary:
	var chunk: RegionalChunk = get_chunk_now(chunk_of_tile(tile))
	if chunk == null:
		return RegionalChunk.make_tile_dictionary(RegionalChunk.TYPE_SEA, 0, RegionalChunk.RESOURCE_NONE)
	return chunk.tile_dictionary(tile)

# Rows of tile dictionaries (RegionMapGenerator's format) for a window of the planet; row y,
# column x is the global tile origin + (x, y). Rows past the poles are sea.
func extract_window(origin: Vector2i, size: Vector2i) -> Array:
	var rows: Array = []
	for y in range(size.y):
		var row: Array = []
		row.resize(size.x)
		rows.append(row)
	var first_chunk: Vector2i = Vector2i(floori(float(origin.x) / CHUNK_TILES), floori(float(origin.y) / CHUNK_TILES))
	var last_chunk: Vector2i = Vector2i(floori(float(origin.x + size.x - 1) / CHUNK_TILES), floori(float(origin.y + size.y - 1) / CHUNK_TILES))
	for cy in range(first_chunk.y, last_chunk.y + 1):
		for cx in range(first_chunk.x, last_chunk.x + 1):
			var chunk: RegionalChunk = get_chunk_now(Vector2i(cx, cy))
			var low: Vector2i = Vector2i(maxi(origin.x, cx * CHUNK_TILES), maxi(origin.y, cy * CHUNK_TILES))
			var high: Vector2i = Vector2i(mini(origin.x + size.x, (cx + 1) * CHUNK_TILES), mini(origin.y + size.y, (cy + 1) * CHUNK_TILES))
			for gy in range(low.y, high.y):
				var row: Array = rows[gy - origin.y]
				for gx in range(low.x, high.x):
					if chunk == null:
						row[gx - origin.x] = RegionalChunk.make_tile_dictionary(RegionalChunk.TYPE_SEA, 0, RegionalChunk.RESOURCE_NONE)
					else:
						row[gx - origin.x] = chunk.tile_dictionary(Vector2i(gx, gy))
	return rows

# --- Settlements -------------------------------------------------------------------------------

# Tile of a world settlement: its world position moved to the nearest tile a town can stand
# on (not water, mountain, forest, or a deposit). Computed once per settlement.
func settlement_tile(settlement: WorldMapData.Settlement) -> Vector2i:
	mutex.lock()
	var known: Variant = settlement_tiles.get(settlement.id, null)
	mutex.unlock()
	if known != null:
		return known
	var authored: Vector2i = world_to_tile_index(settlement.position)
	var chunk: RegionalChunk = get_chunk_now(chunk_of_tile(authored))
	var best: Vector2i = wrap_tile(authored)
	var best_distance: float = INF
	if chunk != null:
		var reach: int = SETTLEMENT_SNAP_TILES
		for y in range(authored.y - reach, authored.y + reach + 1):
			for x in range(authored.x - reach, authored.x + reach + 1):
				var tile: Vector2i = Vector2i(x, y)
				if not chunk.has_tile(tile) or not chunk.is_buildable(tile):
					continue
				var distance: float = Vector2(tile - authored).length_squared() + RegionalChunkGenerator.hash01(x, y, 5) * 0.01
				if distance < best_distance:
					best_distance = distance
					best = wrap_tile(tile)
	mutex.lock()
	settlement_tiles[settlement.id] = best
	mutex.unlock()
	return best

# The settlement's tile if the chunk it depends on is ready (no generation on this thread).
func settlement_tile_if_ready(settlement: WorldMapData.Settlement) -> Variant:
	mutex.lock()
	var known: Variant = settlement_tiles.get(settlement.id, null)
	mutex.unlock()
	if known != null:
		return known
	if get_chunk_if_ready(chunk_of_tile(world_to_tile_index(settlement.position))) == null:
		return null
	return settlement_tile(settlement)

# World settlements whose tile lies inside a window (global origin, size), as
# [settlement, tile] pairs with tiles in the window's unwrapped coordinates.
func settlements_in_window(origin: Vector2i, size: Vector2i) -> Array:
	var found: Array = []
	var window: Rect2i = Rect2i(origin, size)
	for settlement: WorldMapData.Settlement in world.settlements:
		var approximate: Vector2 = world_to_tile(settlement.position)
		var dx: float = world.wrapped_delta_x(origin.x * TILE_WORLD_UNITS, settlement.position.x) / TILE_WORLD_UNITS
		if dx < -CHUNK_TILES or dx > size.x + CHUNK_TILES or approximate.y < origin.y - CHUNK_TILES or approximate.y > origin.y + size.y + CHUNK_TILES:
			continue
		var tile: Vector2i = settlement_tile(settlement)
		# Bring the wrapped tile next to the window.
		var unwrapped: Vector2i = Vector2i(origin.x + posmod(tile.x - origin.x, size_tiles.x), tile.y)
		if window.has_point(unwrapped):
			found.append([settlement, unwrapped])
	return found
