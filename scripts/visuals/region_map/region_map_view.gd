class_name RegionMapView
extends Node2D

# The regional map's landscape: a model of the region drawn in layers under a pan and zoom
# camera. main.gd owns the region's data and every game rule; this view draws what it is
# given and reports where the player clicked. The camera is a transform on map_root rather
# than a Camera2D, so main.gd's screen-space panels are unaffected.
#
# Layers, bottom to top: board, terrain (shader), fields, natural features, structures,
# founding-site pegs, interaction overlay, labels. Permanent geography (terrain, features)
# is kept apart from development (fields, roads, settlements), so whatever changes the
# region later calls notify_changed() with the layer that changed and only that is redrawn.
#
# Two modes. A bounded region (set_region) is one board of tiles, as the original maps are.
# The continuous map (set_terrain, then set_neighbourhood) shows the whole planet at
# regional scale, streamed in chunks (RegionChunkStreamer) over a backdrop of the world
# atlas, and wraps east-west. The game's rules work on a bounded neighbourhood of it: the
# tiles, towns, and roads main.gd owns. The development layers draw that neighbourhood at
# its place on the planet, and the public coordinates (screen_to_map, screen_to_tile,
# map_to_screen) are the neighbourhood's, so the owner's rules see the same tile space in
# both modes.

signal map_clicked(screen_position: Vector2)
# The player zoomed out past the continuous map's widest view (where the world atlas's
# closest view takes over).
signal zoom_out_past_min(screen_position: Vector2)

const LAYER_GROUND: String = "ground"
const LAYER_DEVELOPMENT: String = "development"

const HUD_BUTTON_HEIGHT: float = 22.0
const HUD_MARGIN: float = 10.0
const LEGEND_SIZE: Vector2 = Vector2(214.0, 232.0)

# Map units per world unit (12 per tile, 1.2 world units per tile).
const MAP_UNITS_PER_WORLD: float = RegionMapStyle.TILE / RegionalTerrain.TILE_WORLD_UNITS
# The continuous map's widest view: the world atlas's closest view, at the same scale.
const HANDOFF_ZOOM: float = WorldMapStyle.MAX_ZOOM / MAP_UNITS_PER_WORLD
# Individual trees, peaks, and boulders are drawn from this zoom in; farther out the
# terrain shows woods as canopy.
const FEATURE_ZOOM: float = 1.0

var tiles: Array = []
var cities: Array[City] = []
var roads: Array[Array] = []
var geography: RegionGeography = null
var geometry: RegionMapGeometry = RegionMapGeometry.new()
var map_size: Vector2i = Vector2i.ZERO

var map_root: Node2D = null
var board_layer: RegionBoardLayer = null
var terrain_layer: RegionTerrainLayer = null
var field_layer: RegionFieldLayer = null
var feature_layer: RegionFeatureLayer = null
var structure_layer: RegionStructureLayer = null
var site_layer: RegionSiteLayer = null
var overlay_layer: RegionOverlayLayer = null
var label_layer: RegionLabelLayer = null
var layers: Array[RegionMapLayer] = []
var board_clip: HudCanvas = null
var hud: HudCanvas = null

# Continuous map.
var terrain: RegionalTerrain = null
var streamer: RegionChunkStreamer = null
var backdrop_root: Node2D = null
var backdrop: WorldTerrainLayer = null
var chunk_terrain_root: Node2D = null
var chunk_field_root: Node2D = null
var chunk_feature_root: Node2D = null
var chunk_structure_root: Node2D = null
var world_label_layer: RegionWorldLabelLayer = null
# Global tile of the neighbourhood's first tile, and where its layers are drawn now (map
# units, the copy of the planet nearest the camera).
var neighbourhood_origin: Vector2i = Vector2i.ZERO
var neighbourhood_offset: Vector2 = Vector2.ZERO
# World roads through the neighbourhood, in its map units; its towns line their streets along them.
var neighbourhood_context_roads: Array[RegionMapGeometry.RoadShape] = []
var show_borders: bool = true
var hud_region_text: String = ""

# Camera. Zoom is screen pixels per map unit; screen_rect is where the map shows through.
var screen_rect: Rect2 = Rect2(0.0, 0.0, 960.0, 600.0)
var camera_center: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var target_zoom: float = 1.0
var zoom_anchor_screen: Vector2 = Vector2.ZERO
var press_button: int = MOUSE_BUTTON_NONE
var press_position: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var last_mouse: Vector2 = Vector2.ZERO

# Interaction state, set by the owner.
var hovered_tile: Vector2i = Vector2i(-1, -1)
var hovered_tile_valid: bool = false
var hovered_city: int = -1
var selected_city: int = -1
var pending_tile: Vector2i = Vector2i(-1, -1)
var founding_active: bool = false
var founding_sites: Array[Vector2i] = []
var exclusion_radius_tiles: float = 24.0
var catchment_radius_tiles: float = 7.0

var show_sites: bool = true
var show_labels: bool = true
var show_legend: bool = false
var hud_buttons: Array[Dictionary] = []

class HudCanvas:
	extends Node2D
	var painter: Callable

	func _draw() -> void:
		painter.call(self)

func _init() -> void:
	map_root = Node2D.new()
	map_root.name = "MapRoot"
	add_child(map_root)
	backdrop_root = add_root("Backdrop")
	backdrop_root.scale = Vector2(MAP_UNITS_PER_WORLD, MAP_UNITS_PER_WORLD)
	board_layer = add_layer(RegionBoardLayer.new(), "Board")
	terrain_layer = add_layer(RegionTerrainLayer.new(), "Terrain")
	chunk_terrain_root = add_root("ChunkTerrain")
	chunk_field_root = add_root("ChunkFields")
	field_layer = add_layer(RegionFieldLayer.new(), "Fields")
	feature_layer = add_layer(RegionFeatureLayer.new(), "Features")
	chunk_feature_root = add_root("ChunkFeatures")
	# Chunk rows draw north to south, so trees near a chunk edge overlap correctly.
	chunk_feature_root.y_sort_enabled = true
	chunk_structure_root = add_root("ChunkStructures")
	structure_layer = add_layer(RegionStructureLayer.new(), "Structures")
	# Founding marks stay on the board: the clip node draws the board's shape as their mask.
	board_clip = HudCanvas.new()
	board_clip.name = "BoardClip"
	board_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	board_clip.painter = func(canvas: CanvasItem) -> void: canvas.draw_rect(Rect2(Vector2.ZERO, map_extent()), Color.WHITE)
	map_root.add_child(board_clip)
	site_layer = add_layer(RegionSiteLayer.new(), "Sites", board_clip)
	overlay_layer = add_layer(RegionOverlayLayer.new(), "Overlay", board_clip)
	world_label_layer = add_layer(RegionWorldLabelLayer.new(), "WorldLabels")
	label_layer = add_layer(RegionLabelLayer.new(), "Labels")
	hud = HudCanvas.new()
	hud.name = "Hud"
	hud.painter = draw_hud
	add_child(hud)

func add_layer(layer: RegionMapLayer, layer_name: String, parent: Node2D = null) -> RegionMapLayer:
	layer.name = layer_name
	(parent if parent != null else map_root).add_child(layer)
	layer.setup(self)
	layers.append(layer)
	return layer

func _exit_tree() -> void:
	if terrain != null:
		terrain.wait_for_tasks()

func add_root(root_name: String) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = root_name
	map_root.add_child(root)
	return root

func is_continuous() -> bool:
	return terrain != null

# Switches to the continuous map of the whole planet. The owner then places the gameplay
# neighbourhood with set_neighbourhood() and the camera with focus_on_global_tile().
func set_terrain(regional_terrain: RegionalTerrain) -> void:
	if terrain == regional_terrain:
		return
	if streamer != null:
		streamer.clear()
	terrain = regional_terrain
	if backdrop == null:
		backdrop = WorldTerrainLayer.new()
		backdrop.name = "AtlasBackdrop"
		backdrop_root.add_child(backdrop)
	backdrop.setup(terrain.world)
	var shared: Dictionary = {
		"political_tex": backdrop.shader_material.get_shader_parameter("political_tex"),
		"kingdom_palette": backdrop.shader_material.get_shader_parameter("kingdom_palette"),
		"political_size": Vector2(terrain.world.political_size),
	}
	var roots: Array[Node2D] = [chunk_terrain_root, chunk_field_root, chunk_feature_root, chunk_structure_root]
	streamer = RegionChunkStreamer.new(self, terrain, roots, shared)
	# The board and the bounded region's ground give way to the streamed chunks.
	board_layer.visible = false
	terrain_layer.visible = false
	feature_layer.visible = false
	geography = null
	apply_camera()

# --- Data ---------------------------------------------------------------------------

func set_region(region_tiles: Array, region_cities: Array[City], region_roads: Array[Array], region_geography: RegionGeography) -> void:
	tiles = region_tiles
	cities = region_cities
	roads = region_roads
	geography = region_geography
	map_size = Vector2i((tiles[0] as Array).size(), tiles.size()) if not tiles.is_empty() else Vector2i.ZERO
	hovered_tile = Vector2i(-1, -1)
	hovered_city = -1
	selected_city = -1
	pending_tile = Vector2i(-1, -1)
	geometry.build(tiles, cities, roads, geography)
	for layer: RegionMapLayer in layers:
		layer.rebuild()
	board_clip.queue_redraw()
	reset_camera()

# Continuous map: the gameplay neighbourhood, a window of the planet starting at the global
# tile origin. tiles, cities, and roads are in the window's tile coordinates. The camera
# stays where it is.
func set_neighbourhood(window_tiles: Array, window_cities: Array[City], window_roads: Array[Array], origin: Vector2i) -> void:
	var old_rect: Rect2 = neighbourhood_map_rect()
	tiles = window_tiles
	cities = window_cities
	roads = window_roads
	neighbourhood_origin = Vector2i(terrain.wrap_tile_x(origin.x), origin.y)
	map_size = Vector2i((tiles[0] as Array).size(), tiles.size()) if not tiles.is_empty() else Vector2i.ZERO
	hovered_tile = Vector2i(-1, -1)
	hovered_city = -1
	selected_city = -1
	pending_tile = Vector2i(-1, -1)
	neighbourhood_context_roads.clear()
	var window_map: Vector2 = Vector2(neighbourhood_origin) * RegionMapStyle.TILE
	for piece: RegionMapGeometry.RoadShape in streamer.world_road_pieces(Rect2i(neighbourhood_origin, map_size)):
		piece.is_context = true
		var local_points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in piece.points:
			local_points.append(point - window_map)
		piece.points = local_points
		neighbourhood_context_roads.append(piece)
	geometry.world_tiers.clear()
	for settlement: WorldMapData.Settlement in terrain.world.settlements:
		geometry.world_tiers[settlement.name] = settlement.tier
	geometry.build(tiles, cities, roads, geography, neighbourhood_context_roads)
	for layer: RegionMapLayer in [field_layer, structure_layer, site_layer, overlay_layer, label_layer]:
		layer.rebuild()
	board_clip.queue_redraw()
	streamer.on_neighbourhood_changed(old_rect, neighbourhood_map_rect())
	apply_camera()

# The neighbourhood in global map units (canonical x), or an empty rect without one.
func neighbourhood_map_rect() -> Rect2:
	if not is_continuous() or map_size == Vector2i.ZERO:
		return Rect2()
	return Rect2(Vector2(neighbourhood_origin) * RegionMapStyle.TILE, Vector2(map_size) * RegionMapStyle.TILE)

func is_global_tile_in_neighbourhood(tile: Vector2i) -> bool:
	if not is_continuous() or map_size == Vector2i.ZERO:
		return false
	var local: Vector2i = global_tile_to_local(tile)
	return is_tile_inside(local)

# A global tile in the neighbourhood's tile coordinates (taking the short way around the planet).
func global_tile_to_local(tile: Vector2i) -> Vector2i:
	var dx: int = posmod(tile.x - neighbourhood_origin.x, terrain.size_tiles.x)
	if dx > terrain.size_tiles.x / 2:
		dx -= terrain.size_tiles.x
	return Vector2i(dx, tile.y - neighbourhood_origin.y)

func local_tile_to_global(tile: Vector2i) -> Vector2i:
	return Vector2i(terrain.wrap_tile_x(tile.x + neighbourhood_origin.x), tile.y + neighbourhood_origin.y)

# Whether the neighbourhood's development keeps this spot (global map units) clear of trees.
func is_cleared_by_neighbourhood(map_point: Vector2) -> bool:
	if map_size == Vector2i.ZERO:
		return false
	var planet: float = terrain.size_tiles.x * RegionMapStyle.TILE
	var local: Vector2 = map_point - Vector2(neighbourhood_origin) * RegionMapStyle.TILE
	local.x -= roundf(local.x / planet) * planet
	return geometry.is_cleared(local)

# The owner calls this after changing tiles (LAYER_GROUND) or towns and roads
# (LAYER_DEVELOPMENT). The arrays are shared, so it may also pass replaced ones.
func notify_changed(layer: String, region_cities: Array[City] = cities, region_roads: Array[Array] = roads) -> void:
	if map_size == Vector2i.ZERO:
		return
	cities = region_cities
	roads = region_roads
	var previous_clearings: PackedByteArray = geometry.clear_grid
	geometry.build(tiles, cities, roads, geography, neighbourhood_context_roads)
	if is_continuous():
		# The chunks draw the ground; trees there make way for new development.
		if geometry.clear_grid != previous_clearings:
			streamer.mark_features_dirty_near(neighbourhood_map_rect())
	else:
		if layer == LAYER_GROUND:
			terrain_layer.rebuild()
		# Trees keep clear of roads and houses, so features are rebuilt when the cleared ground
		# changes; a town that only grew in population leaves them alone.
		if layer == LAYER_GROUND or geometry.clear_grid != previous_clearings:
			feature_layer.rebuild()
	for redrawn: RegionMapLayer in [field_layer, structure_layer, site_layer, overlay_layer, label_layer]:
		redrawn.rebuild()

func is_tile_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func has_pending_site() -> bool:
	return is_tile_inside(pending_tile)

# --- Interaction state ---------------------------------------------------------------

func set_hover(tile: Vector2i, tile_is_valid_site: bool, city_index: int) -> void:
	if tile == hovered_tile and tile_is_valid_site == hovered_tile_valid and city_index == hovered_city:
		return
	hovered_tile = tile
	hovered_tile_valid = tile_is_valid_site
	hovered_city = city_index
	overlay_layer.queue_redraw()

func set_founding_state(active: bool, sites: Array[Vector2i], site: Vector2i, exclusion_tiles: float, catchment_tiles: float) -> void:
	var sites_changed: bool = active != founding_active or sites != founding_sites
	founding_active = active
	founding_sites = sites
	exclusion_radius_tiles = exclusion_tiles
	catchment_radius_tiles = catchment_tiles
	if site != pending_tile:
		pending_tile = site
		overlay_layer.queue_redraw()
	if sites_changed:
		site_layer.queue_redraw()
		overlay_layer.queue_redraw()
		hud.queue_redraw()

func set_selected_city(city_index: int) -> void:
	if city_index != selected_city:
		selected_city = city_index
		overlay_layer.queue_redraw()

# --- Camera ----------------------------------------------------------------------------

func set_screen_rect(rect: Rect2) -> void:
	if rect == screen_rect:
		return
	var was_fit: bool = is_equal_approx(zoom, min_zoom())
	screen_rect = rect
	if was_fit:
		zoom = min_zoom()
		target_zoom = zoom
	apply_camera()

func map_extent() -> Vector2:
	return Vector2(map_size) * RegionMapStyle.TILE

# Fully zoomed out, the whole region fits the map area; the continuous map goes out as far
# as the world atlas's closest view.
func min_zoom() -> float:
	if is_continuous():
		return HANDOFF_ZOOM
	var extent: Vector2 = map_extent() + Vector2(0.0, RegionMapStyle.BOARD_THICKNESS)
	if extent.x <= 0.0 or screen_rect.size.x <= 0.0:
		return 1.0
	var available: Vector2 = screen_rect.size - Vector2.ONE * RegionMapStyle.FIT_MARGIN_PX * 2.0
	return maxf(0.1, minf(available.x / extent.x, available.y / extent.y))

func reset_camera() -> void:
	zoom = min_zoom()
	target_zoom = zoom
	camera_center = map_extent() * 0.5
	apply_camera()

# map_position is in the neighbourhood's map units (the whole map in bounded mode).
func focus_on(map_position: Vector2, new_zoom: float) -> void:
	camera_center = map_position + neighbourhood_offset
	zoom = new_zoom
	target_zoom = new_zoom
	apply_camera()

# Continuous map: centers the camera on a global tile (fractional tiles allowed).
func focus_on_global_tile(tile: Vector2, new_zoom: float) -> void:
	camera_center = tile * RegionMapStyle.TILE
	zoom = new_zoom
	target_zoom = new_zoom
	apply_camera()

# Continuous map: the global tile (fractional) at the middle of the view.
func camera_global_tile() -> Vector2:
	return Vector2(fposmod(camera_center.x / RegionMapStyle.TILE, terrain.size_tiles.x), camera_center.y / RegionMapStyle.TILE)

# Continuous map: the world position under a screen position.
func screen_to_world(screen_position: Vector2) -> Vector2:
	var map_point: Vector2 = screen_to_global_map(screen_position)
	return Vector2(fposmod(map_point.x / MAP_UNITS_PER_WORLD, terrain.world.world_size.x), map_point.y / MAP_UNITS_PER_WORLD)

func apply_camera() -> void:
	zoom = clampf(zoom, min_zoom(), RegionMapStyle.MAX_ZOOM)
	target_zoom = clampf(target_zoom, min_zoom(), RegionMapStyle.MAX_ZOOM)
	var half_view: Vector2 = screen_rect.size * 0.5 / zoom
	if is_continuous():
		# East-west the planet wraps; north-south the view stops at the poles.
		var planet: Vector2 = Vector2(terrain.size_tiles) * RegionMapStyle.TILE
		camera_center.x = fposmod(camera_center.x, planet.x)
		camera_center.y = clampf(camera_center.y, minf(half_view.y, planet.y * 0.5), maxf(planet.y - half_view.y, planet.y * 0.5))
		neighbourhood_offset = Vector2(neighbourhood_origin) * RegionMapStyle.TILE
		neighbourhood_offset.x += roundf((camera_center.x - neighbourhood_offset.x) / planet.x) * planet.x
		for layer: Node2D in [field_layer, structure_layer, board_clip, label_layer]:
			layer.position = neighbourhood_offset
		backdrop.set_view_zoom(zoom * MAP_UNITS_PER_WORLD)
		update_region_text()
	else:
		# The map may not leave the screen: its center stays within the visible half-extent.
		var extent: Vector2 = map_extent()
		for axis in range(2):
			if half_view[axis] * 2.0 >= extent[axis]:
				camera_center[axis] = extent[axis] * 0.5
			else:
				camera_center[axis] = clampf(camera_center[axis], half_view[axis], extent[axis] - half_view[axis])
	map_root.scale = Vector2(zoom, zoom)
	map_root.position = (screen_rect.get_center() - camera_center * zoom).round()
	for layer: RegionMapLayer in layers:
		layer.set_view_zoom(zoom)
	world_label_layer.queue_redraw()
	queue_redraw()
	hud.queue_redraw()

# The part of the map on screen, in global map units near the camera.
func visible_map_rect() -> Rect2:
	return Rect2(screen_to_global_map(screen_rect.position), screen_rect.size / zoom)

func screen_to_global_map(screen_position: Vector2) -> Vector2:
	return (screen_position - map_root.position) / zoom

# Screen position to the neighbourhood's map units (the whole map's in bounded mode).
func screen_to_map(screen_position: Vector2) -> Vector2:
	return screen_to_global_map(screen_position) - neighbourhood_offset

func map_to_screen(map_position: Vector2) -> Vector2:
	return map_root.position + (map_position + neighbourhood_offset) * zoom

# The neighbourhood tile under a screen position, or (-1, -1) outside the map area or the
# board (or, on the continuous map, outside the neighbourhood).
func screen_to_tile(screen_position: Vector2) -> Vector2i:
	if not screen_rect.has_point(screen_position):
		return Vector2i(-1, -1)
	var tile: Vector2i = Vector2i((screen_to_map(screen_position) / RegionMapStyle.TILE).floor())
	return tile if is_tile_inside(tile) else Vector2i(-1, -1)

# Continuous map: the global tile under a screen position (x wrapped), or (-1, -1) off the map area.
func screen_to_global_tile(screen_position: Vector2) -> Vector2i:
	if not screen_rect.has_point(screen_position):
		return Vector2i(-1, -1)
	var tile: Vector2i = Vector2i((screen_to_global_map(screen_position) / RegionMapStyle.TILE).floor())
	if not terrain.is_tile_on_planet(tile):
		return Vector2i(-1, -1)
	return terrain.wrap_tile(tile)

func update_region_text() -> void:
	var region_id: int = terrain.region_vote_at(camera_global_tile() * RegionalTerrain.TILE_WORLD_UNITS)
	var region: WorldMapData.Region = terrain.world.get_region(region_id)
	if region == null:
		hud_region_text = ""
		return
	var status: String = "unclaimed frontier"
	var kingdom: WorldMapData.Kingdom = terrain.world.get_kingdom(region.owner_kingdom_id)
	if kingdom != null:
		status = "held by " + kingdom.name
	elif region.is_contested():
		status = "contested frontier"
	hud_region_text = "%s, %s" % [region.name, status]

func zoom_toward(factor: float, screen_position: Vector2) -> void:
	target_zoom = clampf(target_zoom * factor, min_zoom(), RegionMapStyle.MAX_ZOOM)
	zoom_anchor_screen = screen_position

func _process(delta: float) -> void:
	if not visible:
		return
	var moved: bool = false
	var pan: Vector2 = Vector2.ZERO
	if not Input.is_key_pressed(KEY_CTRL):
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			pan.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			pan.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			pan.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			pan.y += 1.0
	if pan != Vector2.ZERO:
		camera_center += pan.normalized() * RegionMapStyle.KEY_PAN_SPEED_PX * delta / zoom
		moved = true
	if not is_equal_approx(zoom, target_zoom):
		# Keep the map point under the cursor fixed while the zoom eases in.
		var anchor_map: Vector2 = screen_to_map(zoom_anchor_screen)
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-RegionMapStyle.ZOOM_SMOOTHING * delta))
		if absf(zoom - target_zoom) / target_zoom < 0.002:
			zoom = target_zoom
		camera_center = anchor_map - (zoom_anchor_screen - screen_rect.get_center()) / zoom
		moved = true
	if moved:
		apply_camera()
	if is_continuous():
		streamer.update(visible_map_rect(), zoom, zoom >= FEATURE_ZOOM, show_borders)

# --- Input -----------------------------------------------------------------------------

# Camera and click handling for the map area. The owner calls this for mouse events that
# are not over its own panels. A left press and release without dragging emits map_clicked.
# Returns true when the event was used.
func handle_mouse_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		var position: Vector2 = button.position
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if not screen_rect.has_point(position):
				return false
			if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_continuous() and target_zoom <= min_zoom() * 1.001:
				# Already as far out as the regional map goes: the world atlas takes over.
				zoom_out_past_min.emit(position)
				return true
			zoom_toward(RegionMapStyle.ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / RegionMapStyle.ZOOM_STEP, position)
			return true
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_MIDDLE:
			return false
		if button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT and handle_hud_click(position):
				return true
			if not screen_rect.has_point(position):
				return false
			press_button = button.button_index
			press_position = position
			last_mouse = position
			is_dragging = false
			return true
		if button.button_index != press_button:
			return false
		var was_click: bool = not is_dragging and press_button == MOUSE_BUTTON_LEFT
		press_button = MOUSE_BUTTON_NONE
		is_dragging = false
		if was_click:
			map_clicked.emit(position)
		return true
	if event is InputEventMouseMotion and press_button != MOUSE_BUTTON_NONE:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not is_dragging and motion.position.distance_to(press_position) > RegionMapStyle.DRAG_THRESHOLD_PX:
			is_dragging = true
		if is_dragging:
			camera_center -= (motion.position - last_mouse) / zoom
			apply_camera()
		last_mouse = motion.position
		return is_dragging
	return false

func handle_key(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.keycode == KEY_F or event.physical_keycode == KEY_F:
		toggle_sites()
		return true
	if event.keycode == KEY_L or event.physical_keycode == KEY_L:
		toggle_labels()
		return true
	if is_continuous() and (event.keycode == KEY_B or event.physical_keycode == KEY_B):
		toggle_borders()
		return true
	return false

func toggle_sites() -> void:
	show_sites = not show_sites
	site_layer.queue_redraw()
	hud.queue_redraw()

func toggle_labels() -> void:
	show_labels = not show_labels
	label_layer.queue_redraw()
	world_label_layer.queue_redraw()
	hud.queue_redraw()

func toggle_borders() -> void:
	show_borders = not show_borders
	hud.queue_redraw()

func is_over_hud(screen_position: Vector2) -> bool:
	for button: Dictionary in hud_buttons:
		if (button["rect"] as Rect2).has_point(screen_position):
			return true
	return show_legend and legend_rect().has_point(screen_position)

func handle_hud_click(screen_position: Vector2) -> bool:
	for button: Dictionary in hud_buttons:
		if not (button["rect"] as Rect2).has_point(screen_position):
			continue
		match button["action"]:
			"sites":
				toggle_sites()
			"labels":
				toggle_labels()
			"borders":
				toggle_borders()
			"legend":
				show_legend = not show_legend
				hud.queue_redraw()
		return true
	return show_legend and legend_rect().has_point(screen_position)

# --- HUD ------------------------------------------------------------------------------

func _draw() -> void:
	# The table the board sits on, under everything else.
	draw_rect(screen_rect, RegionMapStyle.COLOR_TABLE)

func legend_rect() -> Rect2:
	var bottom: float = screen_rect.end.y - HUD_MARGIN - HUD_BUTTON_HEIGHT - 8.0
	return Rect2(Vector2(screen_rect.position.x + HUD_MARGIN, bottom - LEGEND_SIZE.y), LEGEND_SIZE)

func draw_hud(canvas: CanvasItem) -> void:
	hud_buttons.clear()
	if map_size == Vector2i.ZERO and not is_continuous():
		return
	var font: Font = RegionMapStyle.ui_font()
	var x: float = screen_rect.position.x + HUD_MARGIN
	var y: float = screen_rect.end.y - HUD_MARGIN - HUD_BUTTON_HEIGHT
	if founding_active:
		x = draw_hud_button(canvas, font, "Founding sites (F)", x, y, show_sites, "sites")
	x = draw_hud_button(canvas, font, "Labels (L)", x, y, show_labels, "labels")
	if is_continuous():
		x = draw_hud_button(canvas, font, "Borders (B)", x, y, show_borders, "borders")
	x = draw_hud_button(canvas, font, "Legend", x, y, show_legend, "legend")
	var hint: String = "Drag or WASD to pan, wheel to zoom" + (" (out to the world map)" if is_continuous() else "")
	canvas.draw_string(font, Vector2(x + 6.0, y + 15.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RegionMapStyle.COLOR_HUD_MUTED)
	if show_legend:
		draw_legend(canvas, font)
	if is_continuous() and hud_region_text != "":
		var text_size: Vector2 = font.get_string_size(hud_region_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var box: Rect2 = Rect2(screen_rect.position + Vector2(HUD_MARGIN, HUD_MARGIN), text_size + Vector2(16.0, 10.0))
		canvas.draw_rect(box, RegionMapStyle.COLOR_HUD)
		canvas.draw_rect(box, RegionMapStyle.COLOR_HUD_BORDER, false, 1.0)
		canvas.draw_string(font, box.position + Vector2(8.0, 5.0 + font.get_ascent(14)), hud_region_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RegionMapStyle.COLOR_HUD_TEXT)

# Temperature that colors the legend's woodland: the region's, or the chunk in view.
func legend_temperature() -> float:
	if is_continuous():
		var chunk: RegionalChunk = terrain.get_chunk_if_ready(terrain.chunk_of_tile(Vector2i(camera_global_tile().floor())))
		if chunk != null:
			return chunk.mean_temperature
	return RegionMapStyle.region_temperature(geography)

func draw_hud_button(canvas: CanvasItem, font: Font, text: String, x: float, y: float, active: bool, action: String) -> float:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
	var rect: Rect2 = Rect2(Vector2(x, y), Vector2(width, HUD_BUTTON_HEIGHT))
	canvas.draw_rect(rect, RegionMapStyle.COLOR_HUD_BUTTON_ON if active else RegionMapStyle.COLOR_HUD_BUTTON)
	canvas.draw_rect(rect, RegionMapStyle.COLOR_HUD_BORDER, false, 1.0)
	canvas.draw_string(font, Vector2(x + 8.0, y + 15.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RegionMapStyle.COLOR_HUD_TEXT)
	hud_buttons.append({"rect": rect, "action": action})
	return x + width + 6.0

func draw_legend(canvas: CanvasItem, font: Font) -> void:
	var rect: Rect2 = legend_rect()
	canvas.draw_rect(rect, RegionMapStyle.COLOR_HUD)
	canvas.draw_rect(rect, RegionMapStyle.COLOR_HUD_BORDER, false, 1.0)
	var forest: Color = RegionMapStyle.forest_color(legend_temperature())
	var rows: Array = [
		["Fertile land (farms)", Color(0.42, 0.58, 0.27)],
		["Open meadow", Color(0.62, 0.66, 0.43)],
		["Woodland (timber)", forest],
		["Hills", Color(0.62, 0.62, 0.40)],
		["Mountains (impassable)", RegionMapStyle.COLOR_ROCK],
		["Stone outcrop (quarry)", RegionMapStyle.COLOR_STONE_LIGHT],
		["Iron-bearing rock", RegionMapStyle.COLOR_IRON_RUST],
		["Water", Color(0.28, 0.52, 0.62)],
		["Road / track", RegionMapStyle.COLOR_ROAD],
		["Farm fields", RegionMapStyle.COLOR_FIELD_WHEAT],
	]
	var y: float = rect.position.y + 20.0
	canvas.draw_string(font, Vector2(rect.position.x + 10.0, y), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RegionMapStyle.COLOR_HUD_TEXT)
	y += 8.0
	for row: Array in rows:
		canvas.draw_rect(Rect2(Vector2(rect.position.x + 10.0, y + 4.0), Vector2(14.0, 11.0)), row[1])
		canvas.draw_string(font, Vector2(rect.position.x + 32.0, y + 14.0), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RegionMapStyle.COLOR_HUD_TEXT)
		y += 17.0
	canvas.draw_circle(Vector2(rect.position.x + 17.0, y + 9.5), 2.4, RegionMapStyle.COLOR_SITE_DOT)
	canvas.draw_string(font, Vector2(rect.position.x + 32.0, y + 14.0), "Can found a town here", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RegionMapStyle.COLOR_HUD_TEXT)
	y += 17.0
	canvas.draw_arc(Vector2(rect.position.x + 17.0, y + 9.5), 6.0, 0.0, TAU, 16, RegionMapStyle.COLOR_EXCLUSION, 1.5)
	canvas.draw_string(font, Vector2(rect.position.x + 32.0, y + 14.0), "Too close to a town", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RegionMapStyle.COLOR_HUD_TEXT)
