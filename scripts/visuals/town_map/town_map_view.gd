class_name TownMapView
extends Node2D

# The town map: the player's town as a model landscape under a pan and zoom camera, in the
# regional map's style. main.gd owns the town and every game rule; this view draws the town it
# is given (City.local_map and City.buildings), keeps the player's interaction state it is told
# about, and reports where the player clicked. The camera is a transform on map_root rather
# than a Camera2D, so main.gd's screen-space panels are unaffected.
#
# Layers, bottom to top: table (screen space), board, ground (shader), natural features,
# buildings and camp, overlay. Ground and features are recorded once per town map; buildings
# again only when the development signature changes; the overlay every frame.

signal map_clicked(screen_position: Vector2, shift_pressed: bool)

var city: City = null
var map_size: Vector2i = Vector2i.ZERO
var climate: Dictionary = LocalCityMapGenerator.DEFAULT_CLIMATE.duplicate()
# Per-site offsets, so neighbouring towns do not share their texture or tree placement.
var noise_offset: Vector2 = Vector2.ZERO
var hash_origin: Vector2i = Vector2i.ZERO
# The town map array last built from: a new town map (another site) rebuilds everything.
var built_map: Array = []
var development_signature: int = 0
# TownConstruction.roads_version and TownLogistics.paths_version the ground was last drawn
# with: finished roads and worn paths redraw it. TownWoodland.land_version the trees were last
# drawn with: felled and spread woods redraw the ground and the trees.
var ground_roads_version: int = -1
var ground_paths_version: int = -1
var land_version: int = -1
var camp_spot_cache: Array[Vector2i] = []
var camp_spot_signature: int = -1

var table: TownFeatureLayer.Canvas = null
var map_root: Node2D = null
var board_layer: TownBoardLayer = null
var ground_layer: TownGroundLayer = null
var feature_layer: TownFeatureLayer = null
var structure_layer: TownStructureLayer = null
var overlay_layer: TownOverlayLayer = null
var layers: Array[TownMapLayer] = []
var shown: bool = true

# Camera. Zoom is screen pixels per map unit; screen_rect is where the map shows through.
var screen_rect: Rect2 = Rect2(0.0, 0.0, 960.0, 600.0)
var camera_center: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var target_zoom: float = 1.0
var zoom_anchor_screen: Vector2 = Vector2.ZERO
var press_button: int = MOUSE_BUTTON_NONE
var press_position: Vector2 = Vector2.ZERO
var press_shift: bool = false
var is_dragging: bool = false
var last_mouse: Vector2 = Vector2.ZERO

# Interaction state, set by the owner (main.gd sync_town_map_view).
var hovered_tile: Vector2i = Vector2i(-1, -1)
var preview_type: String = ""
var preview_size: Vector2i = Vector2i.ONE
var preview_valid: bool = false
var inspected_index: int = -1
var selected_house_index: int = -1
var inspected_project_id: int = -1
var inspected_plot_id: int = -1
var linked_indices: Array[int] = []
# The block of woods the clearing tool would mark, while the player picks its second corner.
var clear_preview: Rect2i = Rect2i()
var walker_time: float = 0.0
var walker_cycle_seconds: float = 12.0

func _init() -> void:
	table = TownFeatureLayer.Canvas.new()
	table.name = "Table"
	table.painter = func(canvas: CanvasItem) -> void: canvas.draw_rect(screen_rect, RegionMapStyle.COLOR_TABLE)
	add_child(table)
	map_root = Node2D.new()
	map_root.name = "MapRoot"
	add_child(map_root)
	board_layer = add_layer(TownBoardLayer.new(), "Board")
	ground_layer = add_layer(TownGroundLayer.new(), "Ground")
	feature_layer = add_layer(TownFeatureLayer.new(), "Features")
	structure_layer = add_layer(TownStructureLayer.new(), "Structures")
	overlay_layer = add_layer(TownOverlayLayer.new(), "Overlay")

func add_layer(layer: TownMapLayer, layer_name: String) -> TownMapLayer:
	layer.name = layer_name
	map_root.add_child(layer)
	layer.setup(self)
	layers.append(layer)
	return layer

# Entering the tree makes the canvas item visible again; restore the state set before, or the
# hidden town (its table covers the map area) would hide the regional map on the same layer.
func _ready() -> void:
	RenderingServer.canvas_item_set_visible(get_canvas_item(), shown)

# Shows or hides the whole view in the rendering server; toggling `visible` would re-record
# every layer each time the town is opened.
func set_shown(show: bool) -> void:
	if show == shown:
		return
	shown = show
	RenderingServer.canvas_item_set_visible(get_canvas_item(), show)

# The town to draw. A different town, or a new town map, rebuilds everything and fits the
# camera; the same town only refreshes what changed.
func set_city(town: City) -> void:
	if town == city and town != null and is_same(town.local_map, built_map):
		return
	city = town
	built_map = town.local_map if town != null else []
	map_size = Vector2i.ZERO
	if town != null and not town.local_map.is_empty():
		map_size = Vector2i((town.local_map[0] as Array).size(), town.local_map.size())
		climate = town.site_profile.climate if town.site_profile != null else LocalCityMapGenerator.DEFAULT_CLIMATE.duplicate()
		hash_origin = Vector2i(town.tile) * 64
		# Small offsets: the shader's finest noise octaves divide by wavelengths of a tenth of a
		# tile, and large coordinates lose the precision their slopes need (thin lines appear).
		noise_offset = Vector2(posmod(hash_origin.x, 97), posmod(hash_origin.y, 89))
	development_signature = 0
	ground_roads_version = town.construction.roads_version if town != null else -1
	ground_paths_version = town.logistics.paths_version if town != null else -1
	land_version = town.woodland.land_version if town != null else -1
	camp_spot_signature = -1
	for layer: TownMapLayer in layers:
		layer.rebuild()
	reset_camera()

# Tile coordinates that per-tile variation is hashed from, unique to the town.
func hash_tile(x: int, y: int) -> Vector2i:
	return hash_origin + Vector2i(x, y)

# --- Development -------------------------------------------------------------------------------

static func upkeep_band(building: Building) -> int:
	return clampi(building.maintenance_level / 10, 0, 10)

# Housing status of every family without a house, in household order.
static func camped_households(town: City) -> Array[String]:
	var camped: Array[String] = []
	for household: Household in town.households:
		if household.residence_building_id < 0:
			camped.append(household.housing_status)
	return camped

func compute_development_signature() -> int:
	var parts: Array = [city.buildings.size()]
	for building: Building in city.buildings:
		parts.append([building.type, building.tile, upkeep_band(building) if building.needs_maintenance() else 10, building.assigned_workers > 0])
	parts.append(camped_households(city))
	parts.append(construction_signature())
	return hash(parts)

# Sites change look as materials arrive (thirds) and as the frame rises (tenths).
func construction_signature() -> Array:
	var parts: Array = [city.logistics.stockpile_tile]
	for project: ConstructionProject in city.construction.projects:
		parts.append([project.id, project.get_stage(), int(project.get_progress() * 10.0), int(project.get_supply_fraction() * 3.0)])
	for plot: Dictionary in city.construction.plots:
		parts.append([plot["id"], plot["project_id"]])
	return parts

func refresh_development() -> void:
	if city == null or map_size == Vector2i.ZERO:
		return
	var trees_changed: bool = city.woodland.land_version != land_version
	var ground_changed: bool = trees_changed or city.construction.roads_version != ground_roads_version or city.logistics.paths_version != ground_paths_version
	if ground_changed:
		ground_roads_version = city.construction.roads_version
		ground_paths_version = city.logistics.paths_version
		land_version = city.woodland.land_version
		ground_layer.rebuild()
	if trees_changed:
		feature_layer.queue_redraw()
	var signature: int = compute_development_signature()
	if signature == development_signature:
		if ground_changed:
			# Grass tufts and stones keep off trodden ground.
			feature_layer.rebuild_details()
		return
	development_signature = signature
	structure_layer.rebuild()
	feature_layer.rebuild_details()

# Open ground near the town's heart for the camp, nearest first, a tile apart.
func camp_spots(count: int) -> Array[Vector2i]:
	var signature: int = hash([count, development_signature])
	if signature == camp_spot_signature:
		return camp_spot_cache
	camp_spot_signature = signature
	camp_spot_cache = []
	if city == null or map_size == Vector2i.ZERO:
		return camp_spot_cache
	var center: Vector2 = Vector2(map_size) * 0.5
	var cells: Array[Vector2i] = []
	for y in range(map_size.y):
		for x in range(map_size.x):
			if Vector2(x, y).distance_to(center) < 12.0:
				cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
	for cell: Vector2i in cells:
		if camp_spot_cache.size() >= count:
			break
		var tile: Dictionary = city.local_map[cell.y][cell.x]
		if not LocalCityMapGenerator.is_buildable(tile) or tile["occupied"] == true:
			continue
		var crowded: bool = false
		for spot: Vector2i in camp_spot_cache:
			if absi(spot.x - cell.x) <= 1 and absi(spot.y - cell.y) <= 1:
				crowded = true
				break
		if not crowded:
			camp_spot_cache.append(cell)
	return camp_spot_cache

# --- Camera ------------------------------------------------------------------------------------

func set_screen_rect(rect: Rect2) -> void:
	if rect == screen_rect:
		return
	var was_fit: bool = is_equal_approx(zoom, min_zoom())
	screen_rect = rect
	table.queue_redraw()
	if was_fit:
		zoom = min_zoom()
		target_zoom = zoom
	apply_camera()

func map_extent() -> Vector2:
	return Vector2(map_size) * TownMapStyle.TILE

# Fully zoomed out, the whole town and its board fit the map area.
func min_zoom() -> float:
	var extent: Vector2 = map_extent() + Vector2(0.0, TownMapStyle.BOARD_THICKNESS)
	if extent.x <= 0.0 or screen_rect.size.x <= 0.0:
		return 1.0
	var available: Vector2 = screen_rect.size - Vector2.ONE * TownMapStyle.FIT_MARGIN_PX * 2.0
	return maxf(0.1, minf(available.x / extent.x, available.y / extent.y))

func reset_camera() -> void:
	zoom = min_zoom()
	target_zoom = zoom
	camera_center = map_extent() * 0.5 + Vector2(0.0, TownMapStyle.BOARD_THICKNESS * 0.5)
	apply_camera()

func focus_on(map_position: Vector2, new_zoom: float) -> void:
	camera_center = map_position
	zoom = new_zoom
	target_zoom = new_zoom
	apply_camera()

func apply_camera() -> void:
	zoom = clampf(zoom, min_zoom(), TownMapStyle.MAX_ZOOM)
	target_zoom = clampf(target_zoom, min_zoom(), TownMapStyle.MAX_ZOOM)
	var half_view: Vector2 = screen_rect.size * 0.5 / zoom
	var extent: Vector2 = map_extent() + Vector2(0.0, TownMapStyle.BOARD_THICKNESS)
	# The map may not leave the screen: its center stays within the visible half-extent.
	for axis in range(2):
		if half_view[axis] * 2.0 >= extent[axis]:
			camera_center[axis] = extent[axis] * 0.5
		else:
			camera_center[axis] = clampf(camera_center[axis], half_view[axis], extent[axis] - half_view[axis])
	map_root.scale = Vector2(zoom, zoom)
	map_root.position = (screen_rect.get_center() - camera_center * zoom).round()
	for layer: TownMapLayer in layers:
		layer.set_view_zoom(zoom)
	overlay_layer.refresh()

func screen_to_map(screen_position: Vector2) -> Vector2:
	return (screen_position - map_root.position) / zoom

func map_to_screen(map_position: Vector2) -> Vector2:
	return map_root.position + map_position * zoom

# The town tile under a screen position, or (-1, -1) outside the map area or the town.
func screen_to_tile(screen_position: Vector2) -> Vector2i:
	if not screen_rect.has_point(screen_position):
		return Vector2i(-1, -1)
	var tile: Vector2i = Vector2i((screen_to_map(screen_position) / TownMapStyle.TILE).floor())
	if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
		return Vector2i(-1, -1)
	return tile

# Screen rectangle of a footprint of tiles.
func tile_rect_to_screen(tile: Vector2i, size: Vector2i = Vector2i.ONE) -> Rect2:
	var rect: Rect2 = TownMapStyle.tile_rect(tile, size)
	return Rect2(map_to_screen(rect.position), rect.size * zoom)

func zoom_toward(factor: float, screen_position: Vector2) -> void:
	target_zoom = clampf(target_zoom * factor, min_zoom(), TownMapStyle.MAX_ZOOM)
	zoom_anchor_screen = screen_position

func _process(delta: float) -> void:
	if not shown or city == null:
		return
	refresh_development()
	var pan: Vector2 = Vector2.ZERO
	# Arrow keys only: letters and digits choose buildings in the town.
	if Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	var moved: bool = false
	if pan != Vector2.ZERO:
		camera_center += pan.normalized() * TownMapStyle.KEY_PAN_SPEED_PX * delta / zoom
		moved = true
	if not is_equal_approx(zoom, target_zoom):
		# Keep the map point under the cursor fixed while the zoom eases in. Taken from the
		# camera rather than map_root, whose position is rounded to whole pixels: the rounding
		# would otherwise add up over the frames of the ease and the point would drift.
		var anchor_map: Vector2 = camera_center + (zoom_anchor_screen - screen_rect.get_center()) / zoom
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-TownMapStyle.ZOOM_SMOOTHING * delta))
		if absf(zoom - target_zoom) / target_zoom < 0.002:
			zoom = target_zoom
		camera_center = anchor_map - (zoom_anchor_screen - screen_rect.get_center()) / zoom
		moved = true
	if moved:
		apply_camera()
	else:
		overlay_layer.refresh()

# --- Input -------------------------------------------------------------------------------------

# Camera and click handling for the map area. The owner calls this for mouse events that are
# not over its panels. A left press and release without dragging emits map_clicked. Returns
# true when the event was used.
func handle_mouse_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		var position: Vector2 = button.position
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if not screen_rect.has_point(position):
				return false
			zoom_toward(TownMapStyle.ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / TownMapStyle.ZOOM_STEP, position)
			return true
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_MIDDLE:
			return false
		if button.pressed:
			if not screen_rect.has_point(position):
				return false
			press_button = button.button_index
			press_position = position
			press_shift = button.shift_pressed
			last_mouse = position
			is_dragging = false
			return true
		if button.button_index != press_button:
			return false
		var was_click: bool = not is_dragging and press_button == MOUSE_BUTTON_LEFT
		press_button = MOUSE_BUTTON_NONE
		is_dragging = false
		if was_click:
			map_clicked.emit(position, press_shift)
		return true
	if event is InputEventMouseMotion and press_button != MOUSE_BUTTON_NONE:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not is_dragging and motion.position.distance_to(press_position) > TownMapStyle.DRAG_THRESHOLD_PX:
			is_dragging = true
		if is_dragging:
			camera_center -= (motion.position - last_mouse) / zoom
			apply_camera()
		last_mouse = motion.position
		return is_dragging
	return false

# Trackpad pinch zooms and two-finger pans. Returns true when used.
func handle_gesture(event: InputEvent) -> bool:
	if event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		if not screen_rect.has_point(magnify.position):
			return false
		zoom_toward(magnify.factor, magnify.position)
		return true
	if event is InputEventPanGesture:
		var pan: InputEventPanGesture = event as InputEventPanGesture
		if not screen_rect.has_point(pan.position):
			return false
		camera_center += pan.delta * 12.0 / zoom
		apply_camera()
		return true
	return false

func handle_key(event: InputEventKey) -> bool:
	if event.pressed and not event.echo and event.keycode == KEY_HOME:
		reset_camera()
		return true
	return false
