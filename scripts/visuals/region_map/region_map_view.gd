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

signal map_clicked(screen_position: Vector2)

const LAYER_GROUND: String = "ground"
const LAYER_DEVELOPMENT: String = "development"

const HUD_BUTTON_HEIGHT: float = 22.0
const HUD_MARGIN: float = 10.0
const LEGEND_SIZE: Vector2 = Vector2(214.0, 232.0)

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
	board_layer = add_layer(RegionBoardLayer.new(), "Board")
	terrain_layer = add_layer(RegionTerrainLayer.new(), "Terrain")
	field_layer = add_layer(RegionFieldLayer.new(), "Fields")
	feature_layer = add_layer(RegionFeatureLayer.new(), "Features")
	structure_layer = add_layer(RegionStructureLayer.new(), "Structures")
	# Founding marks stay on the board: the clip node draws the board's shape as their mask.
	board_clip = HudCanvas.new()
	board_clip.name = "BoardClip"
	board_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	board_clip.painter = func(canvas: CanvasItem) -> void: canvas.draw_rect(Rect2(Vector2.ZERO, map_extent()), Color.WHITE)
	map_root.add_child(board_clip)
	site_layer = add_layer(RegionSiteLayer.new(), "Sites", board_clip)
	overlay_layer = add_layer(RegionOverlayLayer.new(), "Overlay", board_clip)
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

# The owner calls this after changing tiles (LAYER_GROUND) or towns and roads
# (LAYER_DEVELOPMENT). The arrays are shared, so it may also pass replaced ones.
func notify_changed(layer: String, region_cities: Array[City] = cities, region_roads: Array[Array] = roads) -> void:
	if map_size == Vector2i.ZERO:
		return
	cities = region_cities
	roads = region_roads
	var previous_clearings: PackedByteArray = geometry.clear_grid
	geometry.build(tiles, cities, roads, geography)
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

# Fully zoomed out, the whole region fits the map area.
func min_zoom() -> float:
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

func focus_on(map_position: Vector2, new_zoom: float) -> void:
	camera_center = map_position
	zoom = new_zoom
	target_zoom = new_zoom
	apply_camera()

func apply_camera() -> void:
	zoom = clampf(zoom, min_zoom(), RegionMapStyle.MAX_ZOOM)
	target_zoom = clampf(target_zoom, min_zoom(), RegionMapStyle.MAX_ZOOM)
	# The map may not leave the screen: its center stays within the visible half-extent.
	var extent: Vector2 = map_extent()
	var half_view: Vector2 = screen_rect.size * 0.5 / zoom
	for axis in range(2):
		if half_view[axis] * 2.0 >= extent[axis]:
			camera_center[axis] = extent[axis] * 0.5
		else:
			camera_center[axis] = clampf(camera_center[axis], half_view[axis], extent[axis] - half_view[axis])
	map_root.scale = Vector2(zoom, zoom)
	map_root.position = (screen_rect.get_center() - camera_center * zoom).round()
	for layer: RegionMapLayer in layers:
		layer.set_view_zoom(zoom)
	queue_redraw()
	hud.queue_redraw()

func screen_to_map(screen_position: Vector2) -> Vector2:
	return (screen_position - map_root.position) / zoom

func map_to_screen(map_position: Vector2) -> Vector2:
	return map_root.position + map_position * zoom

# The tile under a screen position, or (-1, -1) outside the map area or the board.
func screen_to_tile(screen_position: Vector2) -> Vector2i:
	if not screen_rect.has_point(screen_position):
		return Vector2i(-1, -1)
	var tile: Vector2i = Vector2i((screen_to_map(screen_position) / RegionMapStyle.TILE).floor())
	return tile if is_tile_inside(tile) else Vector2i(-1, -1)

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
	return false

func toggle_sites() -> void:
	show_sites = not show_sites
	site_layer.queue_redraw()
	hud.queue_redraw()

func toggle_labels() -> void:
	show_labels = not show_labels
	label_layer.queue_redraw()
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
	if map_size == Vector2i.ZERO:
		return
	var font: Font = RegionMapStyle.ui_font()
	var x: float = screen_rect.position.x + HUD_MARGIN
	var y: float = screen_rect.end.y - HUD_MARGIN - HUD_BUTTON_HEIGHT
	if founding_active:
		x = draw_hud_button(canvas, font, "Founding sites (F)", x, y, show_sites, "sites")
	x = draw_hud_button(canvas, font, "Labels (L)", x, y, show_labels, "labels")
	x = draw_hud_button(canvas, font, "Legend", x, y, show_legend, "legend")
	canvas.draw_string(font, Vector2(x + 6.0, y + 15.0), "Drag or WASD to pan, wheel to zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RegionMapStyle.COLOR_HUD_MUTED)
	if show_legend:
		draw_legend(canvas, font)

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
	var t: float = RegionMapStyle.region_temperature(geography)
	var forest: Color = RegionMapStyle.forest_color(t)
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
