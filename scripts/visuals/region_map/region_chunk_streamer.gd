class_name RegionChunkStreamer
extends RefCounted

# Streams the continuous regional map: keeps drawn chunks (RegionalTerrain) around the
# camera, builds their nodes a few per frame, and frees the ones left behind. Each chunk
# has a terrain quad, then the world's roads and settlements on it, then (close up) its
# trees and peaks. World settlements inside the gameplay neighbourhood are left to the
# view's own layers, which draw the game's towns there.
#
# Positions: chunk data uses canonical global tiles (x in 0..planet width). A chunk shown
# across the date line from the camera is drawn one planet width away (its "shift"). Shapes
# are kept in coordinates local to their chunk or settlement window, with the node placed
# there: global map units reach tens of thousands, too coarse in single precision for the
# small polygons of houses.

const TERRAIN_BUILDS_PER_FRAME: int = 3
const DETAIL_BUILDS_PER_FRAME: int = 2
const FEATURE_BUILDS_PER_FRAME: int = 1
# Tree strips collected and repainted per frame. One strip (5 tile rows of a chunk) takes
# about 2-4 ms to collect and 1-2 ms to paint; with vsync, a frame that runs past 16.7 ms
# waits for the next refresh, so more than one per frame halves the frame rate while woods
# fill in. Strips nearest the middle of the view go first.
const STRIP_PAINTS_PER_FRAME: int = 1
# Tiles of land kept around a world settlement for its houses and fields.
const SETTLEMENT_WINDOW_RADIUS: int = 12

class ChunkVisual:
	var chunk: RegionalChunk = null
	var coords: Vector2i = Vector2i.ZERO
	# Map-unit offset (a multiple of the planet width) that brings the chunk next to the camera.
	var shift: float = 0.0
	var terrain: RegionChunkTerrain = null
	var features: RegionChunkFeatureLayer = null
	var features_dirty: bool = true
	var features_shown: bool = true
	var detail_built: bool = false
	# Roads and bridges, in map units from the chunk's first core tile.
	var road_geometry: RegionMapGeometry = null
	var road_layer: RegionStructureLayer = null
	# Per world settlement drawn on this chunk: [geometry, field layer, structure layer,
	# window origin in canonical global map units (the geometry's coordinates start there)].
	var settlements: Array = []
	var pending_settlements: Array[int] = []

	func origin() -> Vector2:
		return Vector2(chunk.core_origin) * RegionMapStyle.TILE

	func nodes() -> Array[Node]:
		var result: Array[Node] = []
		for node: Node in [terrain, features, road_layer]:
			if node != null:
				result.append(node)
		for entry: Array in settlements:
			result.append(entry[1])
			result.append(entry[2])
		return result

var view: RegionMapView = null
var terrain: RegionalTerrain = null
var terrain_root: Node2D = null
var field_root: Node2D = null
var feature_root: Node2D = null
var structure_root: Node2D = null
var shared_textures: Dictionary = {}
var visuals: Dictionary = {}
var features_visible: bool = false
# Tree strips waiting to be repainted (see paint_pending_strips).
var pending_strips: Array = []
var planet_map_width: float = 0.0
var chunk_map_size: float = RegionalTerrain.CHUNK_TILES * RegionMapStyle.TILE

func _init(map_view: RegionMapView, regional_terrain: RegionalTerrain, roots: Array[Node2D], textures: Dictionary) -> void:
	view = map_view
	terrain = regional_terrain
	terrain_root = roots[0]
	field_root = roots[1]
	feature_root = roots[2]
	structure_root = roots[3]
	shared_textures = textures
	planet_map_width = terrain.size_tiles.x * RegionMapStyle.TILE
	terrain.chunk_finisher = RegionChunkTerrain.build_masks

func clear() -> void:
	for key: int in visuals.keys():
		free_visual(visuals[key])
	visuals.clear()

# Called every frame with the visible map rectangle (global map units, unwrapped near the camera).
func update(visible: Rect2, zoom: float, show_features: bool, show_borders: bool) -> void:
	terrain.poll()
	var low: Vector2i = Vector2i(floori(visible.position.x / chunk_map_size) - 1, maxi(0, floori(visible.position.y / chunk_map_size) - 1))
	var high: Vector2i = Vector2i(floori(visible.end.x / chunk_map_size) + 1, mini(terrain.chunk_counts.y - 1, floori(visible.end.y / chunk_map_size) + 1))
	var wanted: Dictionary = {}
	for cy in range(low.y, high.y + 1):
		for cx in range(low.x, high.x + 1):
			var coords: Vector2i = Vector2i(cx, cy)
			var key: int = terrain.chunk_key(coords)
			wanted[key] = cx
			terrain.request_chunk(coords)
	for key: int in visuals.keys():
		if not wanted.has(key):
			free_visual(visuals[key])
			visuals.erase(key)

	features_visible = show_features
	var terrain_budget: int = TERRAIN_BUILDS_PER_FRAME
	var detail_budget: int = DETAIL_BUILDS_PER_FRAME
	var feature_budget: int = FEATURE_BUILDS_PER_FRAME
	# Build nearest chunks first.
	var center: Vector2 = visible.get_center() / chunk_map_size
	var order: Array = wanted.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(wanted[a] + 0.5, a / terrain.chunk_counts.x + 0.5).distance_squared_to(center) < Vector2(wanted[b] + 0.5, b / terrain.chunk_counts.x + 0.5).distance_squared_to(center))
	for key: int in order:
		var unwrapped_x: int = wanted[key]
		var coords: Vector2i = Vector2i(unwrapped_x, key / terrain.chunk_counts.x)
		var visual: ChunkVisual = visuals.get(key, null)
		if visual == null:
			if terrain_budget <= 0:
				continue
			var chunk: RegionalChunk = terrain.get_chunk_if_ready(coords)
			if chunk == null:
				continue
			visual = make_visual(chunk)
			visuals[key] = visual
			terrain_budget -= 1
		place_visual(visual, unwrapped_x)
		# Woods keep their canopy texture until the chunk's trees are all drawn, so they never look bare.
		var trees_drawn: bool = visual.features != null and not visual.features_dirty and visual.features.is_fully_drawn()
		visual.terrain.set_view(zoom, 0.0 if show_features and trees_drawn else 1.0, show_borders)
		if not visual.detail_built and detail_budget > 0:
			if build_detail(visual):
				detail_budget -= 1
		elif not visual.pending_settlements.is_empty() and detail_budget > 0:
			retry_settlements(visual)
		if visual.features != null and visual.features_shown != show_features:
			# Hidden in the rendering server, not through `visible`: showing a node queues a full
			# redraw, and repainting every chunk's trees at once stalled the frame for 0.2-0.3 s.
			visual.features_shown = show_features
			RenderingServer.canvas_item_set_visible(visual.features.get_canvas_item(), show_features)
		if show_features and visual.detail_built and visual.features_dirty and feature_budget > 0 and is_on_screen(visual, visible):
			build_features(visual)
			feature_budget -= 1
	paint_pending_strips(visible)
	for key: int in visuals:
		var visual: ChunkVisual = visuals[key]
		for node: Node in visual.nodes():
			if node is RegionMapLayer:
				(node as RegionMapLayer).set_view_zoom(zoom)

func is_on_screen(visual: ChunkVisual, visible: Rect2) -> bool:
	var origin: Vector2 = Vector2(visual.chunk.core_origin) * RegionMapStyle.TILE + Vector2(visual.shift, 0.0)
	return Rect2(origin, Vector2(chunk_map_size, chunk_map_size)).grow(chunk_map_size * 0.5).intersects(visible)

# Whether everything on screen is drawn: its chunks, roads, settlements, and (close up) trees.
func is_ready() -> bool:
	var visible: Rect2 = view.visible_map_rect()
	var low: Vector2i = Vector2i(floori(visible.position.x / chunk_map_size), maxi(0, floori(visible.position.y / chunk_map_size)))
	var high: Vector2i = Vector2i(floori(visible.end.x / chunk_map_size), mini(terrain.chunk_counts.y - 1, floori(visible.end.y / chunk_map_size)))
	for cy in range(low.y, high.y + 1):
		for cx in range(low.x, high.x + 1):
			var visual: ChunkVisual = visuals.get(terrain.chunk_key(Vector2i(cx, cy)), null)
			if visual == null or not visual.detail_built or not visual.pending_settlements.is_empty():
				return false
			if features_visible and visual.features_dirty:
				return false
	return not features_visible or pending_strips.is_empty()

func make_visual(chunk: RegionalChunk) -> ChunkVisual:
	var visual: ChunkVisual = ChunkVisual.new()
	visual.chunk = chunk
	visual.coords = chunk.coords
	visual.terrain = RegionChunkTerrain.new()
	visual.terrain.name = "Chunk%d_%d" % [chunk.coords.x, chunk.coords.y]
	visual.terrain.setup(chunk, shared_textures)
	terrain_root.add_child(visual.terrain)
	return visual

func free_visual(visual: ChunkVisual) -> void:
	for node: Node in visual.nodes():
		node.queue_free()

func place_visual(visual: ChunkVisual, unwrapped_x: int) -> void:
	visual.shift = (unwrapped_x - visual.coords.x) * chunk_map_size
	var origin: Vector2 = visual.origin() + Vector2(visual.shift, 0.0)
	if visual.terrain.position == origin:
		return
	for node: Node2D in [visual.terrain, visual.features, visual.road_layer]:
		if node != null:
			node.position = origin
	for entry: Array in visual.settlements:
		var window_origin: Vector2 = entry[3]
		(entry[1] as Node2D).position = window_origin + Vector2(visual.shift, 0.0)
		(entry[2] as Node2D).position = window_origin + Vector2(visual.shift, 0.0)

# --- Roads and settlements --------------------------------------------------------

# The world's roads, as drawable shapes in global map units near a tile rectangle: the runs of
# each road's course that pass through the rectangle (grown by a tile), one point beyond each end.
func world_road_pieces(rect: Rect2i) -> Array[RegionMapGeometry.RoadShape]:
	var pieces: Array[RegionMapGeometry.RoadShape] = []
	var grown: Rect2 = Rect2(rect).grow(2.0)
	var candidates: Dictionary = {}
	for cy in range(maxi(0, floori(float(rect.position.y) / RegionalTerrain.CHUNK_TILES)), mini(terrain.chunk_counts.y - 1, floori(float(rect.end.y) / RegionalTerrain.CHUNK_TILES)) + 1):
		for cx in range(floori(float(rect.position.x) / RegionalTerrain.CHUNK_TILES), floori(float(rect.end.x) / RegionalTerrain.CHUNK_TILES) + 1):
			for line_index: int in terrain.chunk_road_lines.get(terrain.chunk_key(Vector2i(cx, cy)), PackedInt32Array()):
				candidates[line_index] = true
	var planet: float = terrain.size_tiles.x
	for line_index: int in candidates:
		var line: RegionalTerrain.Polyline = terrain.road_lines[line_index]
		var course: PackedVector2Array = terrain.road_course(line_index)
		var run: PackedVector2Array = PackedVector2Array()
		var previous_inside: bool = false
		for i in range(course.size()):
			var point: Vector2 = course[i]
			point.x += roundf((grown.get_center().x - point.x) / planet) * planet
			var inside: bool = grown.has_point(point)
			if inside and not previous_inside and i > 0:
				var before: Vector2 = course[i - 1]
				run.append(Vector2(before.x + point.x - course[i].x, before.y) * RegionMapStyle.TILE)
			if inside or previous_inside:
				run.append(point * RegionMapStyle.TILE)
			if not inside and previous_inside:
				add_road_piece(pieces, run, line.road_class)
				run = PackedVector2Array()
			previous_inside = inside
		add_road_piece(pieces, run, line.road_class)
	return pieces

static func add_road_piece(pieces: Array[RegionMapGeometry.RoadShape], points: PackedVector2Array, world_class: int) -> void:
	if points.size() < 2:
		return
	var road: RegionMapGeometry.RoadShape = RegionMapGeometry.RoadShape.new()
	road.road_class = RegionMapGeometry.ROAD_MAJOR if world_class == WorldMapData.ROAD_MAJOR else RegionMapGeometry.ROAD_ROAD
	road.points = RegionMapGeometry.chaikin(points, 1)
	pieces.append(road)

# Roads, bridges, and world settlements of a chunk. Returns false while the land a
# settlement needs is not generated yet (it is retried later).
func build_detail(visual: ChunkVisual) -> bool:
	var chunk: RegionalChunk = visual.chunk
	var keep: int = RegionalTerrain.KEEP_APRON_TILES
	var geometry: RegionMapGeometry = RegionMapGeometry.new()
	geometry.begin([], Vector2i(-keep, -keep), Vector2i(chunk.stored_size, chunk.stored_size))
	var core: Rect2i = Rect2i(chunk.core_origin, Vector2i(RegionalTerrain.CHUNK_TILES, RegionalTerrain.CHUNK_TILES))
	var pieces: Array[RegionMapGeometry.RoadShape] = world_road_pieces(core)
	pieces.sort_custom(func(a: RegionMapGeometry.RoadShape, b: RegionMapGeometry.RoadShape) -> bool: return a.road_class < b.road_class)
	for road: RegionMapGeometry.RoadShape in pieces:
		road.points = translated(road.points, -visual.origin())
		geometry.roads.append(road)
		geometry.mark_road_cleared(road)
	geometry.build_bridges_where(func(point: Vector2) -> bool:
		var tile: Vector2i = Vector2i((point / RegionMapStyle.TILE).floor()) + chunk.core_origin
		return chunk.has_tile(tile) and chunk.type_at(tile) == RegionalChunk.TYPE_RIVER)
	var core_map: Rect2 = Rect2(Vector2.ZERO, Vector2(chunk_map_size, chunk_map_size))
	geometry.bridges = geometry.bridges.filter(func(bridge: RegionMapGeometry.BridgeShape) -> bool: return core_map.has_point(bridge.center))
	visual.road_geometry = geometry
	visual.road_layer = RegionStructureLayer.new()
	visual.road_layer.setup(view)
	visual.road_layer.geometry_override = geometry
	visual.road_layer.position = visual.origin() + Vector2(visual.shift, 0.0)
	structure_root.add_child(visual.road_layer)

	visual.pending_settlements = settlements_on_chunk(chunk)
	visual.detail_built = true
	retry_settlements(visual)
	return true

# World settlements whose tile lies on the chunk, except those the neighbourhood draws.
func settlements_on_chunk(chunk: RegionalChunk) -> Array[int]:
	var found: Array[int] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for settlement_id: int in terrain.settlements_by_chunk.get(terrain.chunk_key(chunk.coords + Vector2i(dx, dy)), []):
				found.append(settlement_id)
	return found

func retry_settlements(visual: ChunkVisual) -> void:
	var still_pending: Array[int] = []
	for settlement_id: int in visual.pending_settlements:
		var settlement: WorldMapData.Settlement = terrain.world.get_settlement(settlement_id)
		var tile_value: Variant = terrain.settlement_tile_if_ready(settlement)
		if tile_value == null:
			# Its tile depends on the chunk the world places it in, which may be off screen.
			terrain.request_chunk(terrain.chunk_of_tile(terrain.world_to_tile_index(settlement.position)))
			still_pending.append(settlement_id)
			continue
		var tile: Vector2i = tile_value
		if terrain.chunk_of_tile(tile) != visual.coords or view.is_global_tile_in_neighbourhood(tile):
			continue
		if not add_settlement_visual(visual, settlement, tile):
			still_pending.append(settlement_id)
	visual.pending_settlements = still_pending

func add_settlement_visual(visual: ChunkVisual, settlement: WorldMapData.Settlement, tile: Vector2i) -> bool:
	var radius: int = SETTLEMENT_WINDOW_RADIUS
	var window_origin: Vector2i = tile - Vector2i(radius, radius)
	var window_size: Vector2i = Vector2i(radius * 2 + 1, radius * 2 + 1)
	for cy in range(floori(float(window_origin.y) / RegionalTerrain.CHUNK_TILES), floori(float(window_origin.y + window_size.y - 1) / RegionalTerrain.CHUNK_TILES) + 1):
		for cx in range(floori(float(window_origin.x) / RegionalTerrain.CHUNK_TILES), floori(float(window_origin.x + window_size.x - 1) / RegionalTerrain.CHUNK_TILES) + 1):
			if terrain.is_chunk_on_planet(Vector2i(cx, cy)) and terrain.get_chunk_if_ready(Vector2i(cx, cy)) == null:
				terrain.request_chunk(Vector2i(cx, cy))
				return false
	var window_map: Vector2 = Vector2(window_origin) * RegionMapStyle.TILE
	var geometry: RegionMapGeometry = RegionMapGeometry.new()
	geometry.begin(terrain.extract_window(window_origin, window_size), Vector2i.ZERO)
	var context_roads: Array[RegionMapGeometry.RoadShape] = world_road_pieces(Rect2i(window_origin, window_size))
	for road: RegionMapGeometry.RoadShape in context_roads:
		road.is_context = true
		road.points = translated(road.points, -window_map)
	geometry.add_context_roads(context_roads)
	var shape: RegionMapGeometry.SettlementShape = geometry.add_world_settlement(settlement.name, Vector2(tile - window_origin), settlement.tier)
	geometry.build_fields(shape)
	var fields: RegionFieldLayer = RegionFieldLayer.new()
	fields.setup(view)
	fields.geometry_override = geometry
	fields.position = window_map + Vector2(visual.shift, 0.0)
	field_root.add_child(fields)
	var structures: RegionStructureLayer = RegionStructureLayer.new()
	structures.setup(view)
	structures.geometry_override = geometry
	structures.position = window_map + Vector2(visual.shift, 0.0)
	structure_root.add_child(structures)
	visual.settlements.append([geometry, fields, structures, window_map])
	# Trees near the new houses must make way.
	mark_features_dirty_near(Rect2(Vector2(window_origin) * RegionMapStyle.TILE, Vector2(window_size) * RegionMapStyle.TILE))
	return true

static func translated(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var moved: PackedVector2Array = PackedVector2Array()
	moved.resize(points.size())
	for i in range(points.size()):
		moved[i] = points[i] + offset
	return moved

# Settlement shapes drawn by the chunks, for labels, as [shape, offset to map units near the camera].
func settlement_shapes() -> Array:
	var shapes: Array = []
	for key: int in visuals:
		var visual: ChunkVisual = visuals[key]
		for entry: Array in visual.settlements:
			for shape: RegionMapGeometry.SettlementShape in (entry[0] as RegionMapGeometry).settlements:
				shapes.append([shape, (entry[3] as Vector2) + Vector2(visual.shift, 0.0)])
	return shapes

# --- Trees -------------------------------------------------------------------------------

func build_features(visual: ChunkVisual) -> void:
	if visual.features == null:
		visual.features = RegionChunkFeatureLayer.new()
		visual.features.setup_chunk(view, visual.chunk, func(map_point: Vector2) -> bool: return is_cleared(visual, map_point))
		visual.features.strip_scheduler = schedule_strip
		visual.features.position = Vector2(visual.chunk.core_origin) * RegionMapStyle.TILE + Vector2(visual.shift, 0.0)
		feature_root.add_child(visual.features)
	visual.features.rebuild()
	visual.features_dirty = false

func schedule_strip(strip: RegionMapLayer.Strip) -> void:
	if not pending_strips.has(strip):
		pending_strips.append(strip)

# Repaints the waiting tree strips nearest the middle of the view, a few per frame.
func paint_pending_strips(visible: Rect2) -> void:
	pending_strips = pending_strips.filter(func(strip: Variant) -> bool: return is_instance_valid(strip))
	if pending_strips.is_empty():
		return
	var center: Vector2 = visible.get_center()
	var strip_height: float = RegionMapStyle.STRIP_ROWS * RegionMapStyle.TILE
	pending_strips.sort_custom(func(a: RegionMapLayer.Strip, b: RegionMapLayer.Strip) -> bool:
		return strip_center(a, strip_height).distance_squared_to(center) < strip_center(b, strip_height).distance_squared_to(center))
	for _i in range(mini(STRIP_PAINTS_PER_FRAME, pending_strips.size())):
		var strip: RegionMapLayer.Strip = pending_strips.pop_front()
		strip.may_paint = true
		strip.queue_redraw()

static func strip_center(strip: RegionMapLayer.Strip, strip_height: float) -> Vector2:
	var layer: Node2D = strip.get_parent() as Node2D
	return layer.position + Vector2(RegionalTerrain.CHUNK_TILES * RegionMapStyle.TILE * 0.5, (strip.index + 0.5) * strip_height)

# Trees keep clear of roads, houses, and the neighbourhood's development. map_point is in
# canonical global map units of the chunk.
func is_cleared(visual: ChunkVisual, map_point: Vector2) -> bool:
	if visual.road_geometry != null and visual.road_geometry.is_cleared(map_point - visual.origin()):
		return true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbour: ChunkVisual = visuals.get(terrain.chunk_key(visual.coords + Vector2i(dx, dy)), null)
			if neighbour == null:
				continue
			for entry: Array in neighbour.settlements:
				var local: Vector2 = map_point - (entry[3] as Vector2)
				local.x -= roundf(local.x / planet_map_width) * planet_map_width
				if (entry[0] as RegionMapGeometry).is_cleared(local):
					return true
	return view.is_cleared_by_neighbourhood(map_point)

func mark_features_dirty_near(map_rect: Rect2) -> void:
	for key: int in visuals:
		var visual: ChunkVisual = visuals[key]
		var origin: Vector2 = Vector2(visual.chunk.core_origin) * RegionMapStyle.TILE
		var chunk_rect: Rect2 = Rect2(origin, Vector2(chunk_map_size, chunk_map_size))
		for offset: float in [0.0, planet_map_width, -planet_map_width]:
			if chunk_rect.intersects(Rect2(map_rect.position + Vector2(offset, 0.0), map_rect.size)):
				visual.features_dirty = true

# The neighbourhood moved or changed: its world settlements change hands and nearby trees
# must make way for new development.
func on_neighbourhood_changed(old_rect: Rect2, new_rect: Rect2) -> void:
	for key: int in visuals:
		var visual: ChunkVisual = visuals[key]
		var origin: Vector2 = Vector2(visual.chunk.core_origin) * RegionMapStyle.TILE
		var chunk_rect: Rect2 = Rect2(origin, Vector2(chunk_map_size, chunk_map_size)).grow(SETTLEMENT_WINDOW_RADIUS * RegionMapStyle.TILE)
		var touched: bool = false
		for rect: Rect2 in [old_rect, new_rect]:
			if rect.size == Vector2.ZERO:
				continue
			for offset: float in [0.0, planet_map_width, -planet_map_width]:
				if chunk_rect.intersects(Rect2(rect.position + Vector2(offset, 0.0), rect.size)):
					touched = true
		if not touched:
			continue
		for entry: Array in visual.settlements:
			(entry[1] as Node).queue_free()
			(entry[2] as Node).queue_free()
		visual.settlements.clear()
		visual.pending_settlements = settlements_on_chunk(visual.chunk)
		visual.features_dirty = true
