extends SceneTree

# The continuous regional terrain (RegionalTerrain): chunks join without seams, including
# across the date line; generation is deterministic on any thread; the land matches the world
# atlas (coasts, rivers, high ground, settlements); and the tile data keeps the rules the
# regional map's decoration relies on. Prints [PERF] chunk generation times.

const SHOWCASE_REGIONS: Array[String] = ["Meander Plains", "Thornspine North", "Crownspine Heights", "Tessaly", "Siwan Oases", "Taigard"]
# Every frontier region must leave the player plenty of choice: buildable tiles of the region
# within the 3x3 chunks (180x180 tiles) around its main settlement. The old 80x50 regional
# maps were required to offer 300 founding sites.
const MIN_BUILDABLE_TILES: int = 900
const AROUND: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var failure_count: int = 0
var world: WorldMapData = null
var terrain: RegionalTerrain = null

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	world = FixedWorldDefinition.build()
	var setup_start: int = Time.get_ticks_msec()
	terrain = RegionalTerrain.new(world)
	print("[PERF] regional terrain setup: %d ms" % (Time.get_ticks_msec() - setup_start))
	_check(terrain.size_tiles == Vector2i(6000, 3000), "the planet should be 6000x3000 tiles")
	_check(terrain.size_tiles.x % RegionalTerrain.CHUNK_TILES == 0 and terrain.size_tiles.y % RegionalTerrain.CHUNK_TILES == 0, "chunks should tile the planet exactly")

	test_chunks_join_without_seams()
	test_generation_is_deterministic()
	test_land_matches_the_world()
	test_rivers_follow_the_world()
	test_high_ground_follows_the_world()
	test_settlements_stand_on_buildable_land()
	test_tile_data_rules()
	test_frontier_regions_are_playable()
	test_region_lookup_matches_the_world()
	test_window_extraction()
	measure_generation()
	await test_view_coordinates()
	terrain.wait_for_tasks()

	if failure_count > 0:
		push_error("Regional terrain validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Regional terrain validation passed.")
	quit()

func showcase_chunk(region_name: String) -> Vector2i:
	var region: WorldMapData.Region = world.find_region_by_name(region_name)
	return terrain.chunk_of_tile(terrain.world_to_tile_index(region.centroid))

func generate(chunk: Vector2i) -> RegionalChunk:
	return RegionalChunkGenerator.new(terrain).generate(Vector2i(posmod(chunk.x, terrain.chunk_counts.x), chunk.y))

# Every tile two chunks both hold (their stored margins overlap) must agree in every field.
func compare_overlap(a: RegionalChunk, b: RegionalChunk) -> int:
	var mismatches: int = 0
	var compared: int = 0
	for y in range(a.stored_size):
		for x in range(a.stored_size):
			var tile: Vector2i = a.stored_origin + Vector2i(x, y)
			var j: int = b.index_of(tile)
			if j < 0:
				continue
			var i: int = y * a.stored_size + x
			compared += 1
			if a.types[i] != b.types[j] or a.flags[i] != b.flags[j] or a.resources[i] != b.resources[j] or a.regions[i] != b.regions[j] or a.shore_depth[i] != b.shore_depth[j] or a.temperature[i] != b.temperature[j] or a.moisture[i] != b.moisture[j]:
				mismatches += 1
	_check(compared > 0, "neighbouring chunks %s and %s should share margin tiles" % [a.coords, b.coords])
	return mismatches

func test_chunks_join_without_seams() -> void:
	for region_name: String in SHOWCASE_REGIONS:
		var chunk: Vector2i = showcase_chunk(region_name)
		var center: RegionalChunk = generate(chunk)
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var neighbour: RegionalChunk = generate(chunk + offset)
			var mismatches: int = compare_overlap(center, neighbour)
			_check(mismatches == 0, "%s: chunk %s and its neighbour %s should agree on shared tiles (%d differ)" % [region_name, chunk, chunk + offset, mismatches])
	# Across the date line, on every row of chunks that holds land there.
	var last_column: int = terrain.chunk_counts.x - 1
	var rows_checked: int = 0
	for row in range(terrain.chunk_counts.y):
		var east: RegionalChunk = generate(Vector2i(last_column, row))
		var west: RegionalChunk = generate(Vector2i(0, row))
		var has_land: bool = false
		for value: int in east.types:
			if not RegionalChunk.is_water_type(value):
				has_land = true
				break
		if not has_land and row % 10 != 0:
			continue
		rows_checked += 1
		var mismatches: int = compare_overlap(east, west)
		_check(mismatches == 0, "chunks on either side of the date line (row %d) should agree (%d differ)" % [row, mismatches])
	print("Date line rows checked: ", rows_checked)

func test_generation_is_deterministic() -> void:
	var chunk: Vector2i = showcase_chunk("Tessaly")
	var first: RegionalChunk = generate(chunk)
	var second: RegionalChunk = generate(chunk)
	_check(first.types == second.types and first.flags == second.flags and first.resources == second.resources and first.regions == second.regions, "generating a chunk twice should give identical tiles")
	var threaded_terrain: RegionalTerrain = RegionalTerrain.new(world)
	threaded_terrain.request_chunk(chunk)
	while not threaded_terrain.pending_tasks.is_empty():
		threaded_terrain.poll()
		OS.delay_msec(1)
	var threaded: RegionalChunk = threaded_terrain.get_chunk_if_ready(chunk)
	_check(threaded != null, "a requested chunk should be ready once its task finishes")
	if threaded != null:
		_check(threaded.types == first.types and threaded.flags == first.flags and threaded.resources == first.resources, "a chunk made on a worker thread should match one made on the main thread")

# Coasts lie where the atlas draws them: well inland is land, well offshore is water.
func test_land_matches_the_world() -> void:
	for region_name: String in SHOWCASE_REGIONS:
		var chunk: RegionalChunk = generate(showcase_chunk(region_name))
		var wrong_land: int = 0
		var wrong_water: int = 0
		for y in range(chunk.stored_size):
			for x in range(chunk.stored_size):
				var tile: Vector2i = chunk.stored_origin + Vector2i(x, y)
				var world_elevation: float = terrain.sample_elevation_smooth(terrain.tile_center_to_world(tile))
				var tile_type: int = chunk.types[y * chunk.stored_size + x]
				var open_water: bool = tile_type == RegionalChunk.TYPE_SEA or tile_type == RegionalChunk.TYPE_LAKE
				if world_elevation > 0.02 and open_water:
					wrong_water += 1
				if world_elevation < -0.02 and not open_water:
					wrong_land += 1
		_check(wrong_water == 0 and wrong_land == 0, "%s: coasts should follow the world (%d water on land, %d land at sea)" % [region_name, wrong_water, wrong_land])

# Every world river point over land has river water close by on the regional map.
func test_rivers_follow_the_world() -> void:
	var checked: int = 0
	var missing: int = 0
	for river_index in range(world.rivers.size()):
		var river: WorldMapData.River = world.rivers[river_index]
		# Every fifth point keeps the check quick while covering the whole course.
		for i in range(0, river.points.size(), 5):
			var point: Vector2 = river.points[i]
			if terrain.sample_elevation_smooth(point) < 0.02 or world.lake_at(point, 1.6) != null:
				continue
			var tile: Vector2i = terrain.world_to_tile_index(point)
			var chunk: RegionalChunk = terrain.get_chunk_now(terrain.chunk_of_tile(tile))
			checked += 1
			var found: bool = false
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var near: Vector2i = tile + Vector2i(dx, dy)
					if chunk.has_tile(near) and chunk.type_at(near) == RegionalChunk.TYPE_RIVER:
						found = true
			if not found:
				missing += 1
		if checked > 600:
			break
	print("River points checked: ", checked, ", missing: ", missing)
	_check(checked > 100, "the river check should cover many points")
	_check(missing == 0, "every world river point over land should have river water within 4 tiles (%d missing)" % missing)

func share_of(chunk: RegionalChunk, tile_type: int) -> float:
	var land: int = 0
	var matching: int = 0
	for value: int in chunk.types:
		if RegionalChunk.is_water_type(value):
			continue
		land += 1
		if value == tile_type:
			matching += 1
	return float(matching) / maxf(land, 1.0)

func test_high_ground_follows_the_world() -> void:
	var plains: RegionalChunk = generate(showcase_chunk("Meander Plains"))
	var heights: RegionalChunk = generate(showcase_chunk("Crownspine Heights"))
	print("Mountain share: plains %.3f, heights %.3f" % [share_of(plains, RegionalChunk.TYPE_MOUNTAIN), share_of(heights, RegionalChunk.TYPE_MOUNTAIN)])
	_check(share_of(heights, RegionalChunk.TYPE_MOUNTAIN) > share_of(plains, RegionalChunk.TYPE_MOUNTAIN) + 0.05, "mountain country should have more mountains than river plains")
	_check(share_of(plains, RegionalChunk.TYPE_MOUNTAIN) < 0.02, "river plains should be nearly free of mountains")

func test_settlements_stand_on_buildable_land() -> void:
	for settlement: WorldMapData.Settlement in world.settlements:
		terrain.request_chunk(terrain.chunk_of_tile(terrain.world_to_tile_index(settlement.position)))
	while not terrain.pending_tasks.is_empty():
		terrain.poll()
		OS.delay_msec(1)
	var stranded: PackedStringArray = PackedStringArray()
	for settlement: WorldMapData.Settlement in world.settlements:
		var tile: Vector2i = terrain.settlement_tile(settlement)
		var chunk: RegionalChunk = terrain.get_chunk_now(terrain.chunk_of_tile(tile))
		if not chunk.is_buildable(tile):
			stranded.append(settlement.name)
		var moved: float = Vector2(terrain.world_to_tile(settlement.position)).distance_to(Vector2(tile))
		var wrapped_moved: float = minf(moved, absf(moved - terrain.size_tiles.x))
		if wrapped_moved > RegionalTerrain.SETTLEMENT_SNAP_TILES * 1.5:
			stranded.append(settlement.name + " (moved %.0f tiles)" % wrapped_moved)
	_check(stranded.is_empty(), "every world settlement should stand on buildable land near its world position: " + ", ".join(stranded))

# The rules the regional map's decoration and the founding rules rely on.
func test_tile_data_rules() -> void:
	for region_name: String in SHOWCASE_REGIONS:
		var chunk: RegionalChunk = generate(showcase_chunk(region_name))
		var broken: int = 0
		for i in range(chunk.types.size()):
			var tile_type: int = chunk.types[i]
			var tile_flags: int = chunk.flags[i]
			var open_land: bool = tile_type == RegionalChunk.TYPE_GRASS or tile_type == RegionalChunk.TYPE_HILL
			if tile_flags & RegionalChunk.FLAG_FOREST != 0 and not open_land:
				broken += 1
			if tile_flags & RegionalChunk.FLAG_FERTILE != 0 and not open_land:
				broken += 1
			if chunk.resources[i] != RegionalChunk.RESOURCE_NONE and (not open_land or tile_flags & RegionalChunk.FLAG_FOREST != 0):
				broken += 1
			if tile_flags & RegionalChunk.FLAG_FORD != 0 and (tile_type != RegionalChunk.TYPE_RIVER or tile_flags & RegionalChunk.FLAG_ROAD == 0):
				broken += 1
			if tile_flags & RegionalChunk.FLAG_ROAD != 0 and (tile_type == RegionalChunk.TYPE_LAKE or tile_type == RegionalChunk.TYPE_SEA or tile_type == RegionalChunk.TYPE_MOUNTAIN):
				broken += 1
		_check(broken == 0, "%s: forest, farmland, deposits, roads, and fords should only sit where the rules allow (%d broken)" % [region_name, broken])

func test_frontier_regions_are_playable() -> void:
	var anchors: Dictionary = {}
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id != -1:
			continue
		var settlements: Array[WorldMapData.Settlement] = world.get_settlements_in_region(region.id)
		var anchor: Vector2 = settlements[0].position if not settlements.is_empty() else region.centroid
		anchors[region.id] = terrain.world_to_tile_index(anchor)
		for offset: Vector2i in AROUND:
			terrain.request_chunk(terrain.chunk_of_tile(anchors[region.id]) + offset)
	while not terrain.pending_tasks.is_empty():
		terrain.poll()
		OS.delay_msec(1)
	var fewest: int = 1 << 30
	var fewest_name: String = ""
	for region_id: int in anchors:
		var buildable: int = 0
		for offset: Vector2i in AROUND:
			var chunk: RegionalChunk = terrain.get_chunk_now(terrain.chunk_of_tile(anchors[region_id]) + offset)
			if chunk == null:
				continue
			var keep: int = RegionalTerrain.KEEP_APRON_TILES
			for y in range(keep, chunk.stored_size - keep):
				for x in range(keep, chunk.stored_size - keep):
					var tile: Vector2i = chunk.stored_origin + Vector2i(x, y)
					if chunk.is_buildable(tile) and chunk.region_at(tile) == region_id:
						buildable += 1
		if buildable < fewest:
			fewest = buildable
			fewest_name = world.get_region(region_id).name
		_check(buildable >= MIN_BUILDABLE_TILES, "%s should offer at least %d buildable tiles around its main settlement (%d)" % [world.get_region(region_id).name, MIN_BUILDABLE_TILES, buildable])
	print("Fewest buildable tiles around a frontier region's main settlement: %d (%s)" % [fewest, fewest_name])

# Deep inside a region (all political cells around agree), the tile's region is that region.
func test_region_lookup_matches_the_world() -> void:
	var checked: int = 0
	var wrong: int = 0
	var width: int = world.political_size.x
	for cell_y in range(0, world.political_size.y, 7):
		for cell_x in range(0, width, 11):
			if terrain.uniform_vote[cell_y * width + cell_x] == 0:
				continue
			var region_id: int = world.region_grid[cell_y * width + cell_x]
			if region_id < 0:
				continue
			# The vote over cells (x-1..x+2) is uniform, so the middle of cell (x, y) is safely inside.
			var world_pos: Vector2 = world.political_cell_center(Vector2i(cell_x, cell_y)) + world.world_size / Vector2(world.political_size) * 0.5
			checked += 1
			if terrain.region_vote_at(world_pos) != region_id:
				wrong += 1
	_check(checked > 50 and wrong == 0, "region lookups should match the world's regions (%d of %d wrong)" % [wrong, checked])

func test_window_extraction() -> void:
	var chunk: Vector2i = showcase_chunk("Thornspine North")
	var origin: Vector2i = chunk * RegionalTerrain.CHUNK_TILES + Vector2i(37, 41)
	var tiles: Array = terrain.extract_window(origin, Vector2i(80, 50))
	_check(tiles.size() == 50 and (tiles[0] as Array).size() == 80, "an extracted window should have the requested size")
	var mismatches: int = 0
	for y in range(0, 50, 7):
		for x in range(0, 80, 9):
			var expected: Dictionary = terrain.tile_at(origin + Vector2i(x, y))
			var actual: Dictionary = tiles[y][x]
			if expected != actual:
				mismatches += 1
	_check(mismatches == 0, "window tiles should match single-tile lookups (%d differ)" % mismatches)
	var sample: Dictionary = tiles[25][40]
	for key: String in ["type", "has_forest", "is_fertile", "resource", "has_road", "has_ford"]:
		_check(sample.has(key), "window tiles should carry the regional tile field " + key)
	# A window across the date line comes out continuous.
	var seam_tiles: Array = terrain.extract_window(Vector2i(-40, 1200), Vector2i(80, 20))
	_check(seam_tiles[5][0] == terrain.tile_at(Vector2i(terrain.size_tiles.x - 40, 1205)), "a window across the date line should wrap")

func measure_generation() -> void:
	var times: Array[float] = []
	for region_name: String in SHOWCASE_REGIONS:
		var start: int = Time.get_ticks_usec()
		generate(showcase_chunk(region_name) + Vector2i(0, 1))
		times.append((Time.get_ticks_usec() - start) / 1000.0)
	times.sort()
	print("[PERF] chunk generation on the main thread: median %.1f ms, worst %.1f ms" % [times[times.size() / 2], times[times.size() - 1]])

# The continuous view keeps the owner's coordinates: neighbourhood tiles map to the screen
# and back, global tiles wrap at the date line, and chunks stream in around the camera.
func test_view_coordinates() -> void:
	var view: RegionMapView = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2(0.0, 42.0), Vector2(1300.0, 858.0)))
	view.set_terrain(terrain)
	# A neighbourhood straddling the date line.
	var origin: Vector2i = Vector2i(terrain.size_tiles.x - 30, 1400)
	var size: Vector2i = Vector2i(60, 40)
	var cities: Array[City] = []
	var roads: Array[Array] = []
	view.set_neighbourhood(terrain.extract_window(origin, size), cities, roads, origin)
	view.focus_on_global_tile(Vector2(2.0, 1420.0), 1.5)
	var local: Vector2i = Vector2i(31, 20)
	var screen: Vector2 = view.map_to_screen(RegionMapGeometry.tile_center(Vector2(local)))
	_check(view.screen_to_tile(screen) == local, "a neighbourhood tile should map to the screen and back (%s)" % str(view.screen_to_tile(screen)))
	_check(view.screen_to_global_tile(screen) == Vector2i(1, 1420), "the neighbourhood tile east of the date line should be global tile (1, 1420), got %s" % str(view.screen_to_global_tile(screen)))
	var west: Vector2 = view.map_to_screen(RegionMapGeometry.tile_center(Vector2(29, 20)))
	_check(view.screen_to_global_tile(west) == Vector2i(terrain.size_tiles.x - 1, 1420), "the tile west of the date line should wrap to the planet's last column")
	_check(view.global_tile_to_local(Vector2i(1, 1420)) == local, "global tiles should convert to neighbourhood tiles across the date line")
	view.camera_center.x -= RegionMapStyle.TILE * 10.0
	view.apply_camera()
	_check(view.camera_center.x >= 0.0 and view.camera_center.x < terrain.size_tiles.x * RegionMapStyle.TILE, "the camera should wrap around the planet")
	var moved_screen: Vector2 = view.map_to_screen(RegionMapGeometry.tile_center(Vector2(local)))
	_check(view.screen_to_tile(moved_screen) == local, "neighbourhood tiles should still map to the screen and back after the camera wraps (%s)" % str(view.screen_to_tile(moved_screen)))
	var started: int = Time.get_ticks_msec()
	while not view.streamer.is_ready() and Time.get_ticks_msec() - started < 30000:
		await process_frame
	print("[PERF] streaming a view in headless: %d ms" % (Time.get_ticks_msec() - started))
	_check(view.streamer.is_ready(), "chunks around the camera should stream in")
	_check(view.streamer.visuals.size() >= 4, "several chunks should be drawn around the camera (%d)" % view.streamer.visuals.size())
	_check(view.hud_region_text != "", "the view should name the region under the camera")
	view.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
