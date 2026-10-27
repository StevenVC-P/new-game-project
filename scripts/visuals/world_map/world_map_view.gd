class_name WorldMapView
extends Node2D

# The world map screen. Owns the atlas layers, the camera (pan, zoom toward the cursor,
# horizontal wrap, vertical clamp), hover and selection, and the HUD. It reads
# WorldMapData and redraws layers when the data announces a change; it never edits
# the world. What "entering a region" means is up to the owner (main.gd or a demo).
#
# The camera is a transform on world_root rather than a Camera2D so the map can live
# on its own CanvasLayer without disturbing the screen-space drawing in main.gd.

signal region_entry_requested(region_id: int)
# The zoom eased in to the atlas's closest view while the player was still zooming in: the
# regional map takes over there. remaining_factor is the zoom still to go (above 1), so the
# regional map can carry on without a jump.
signal zoom_in_past_max(world_position: Vector2, screen_position: Vector2, remaining_factor: float)

# How far past the closest view a zoom-in may aim; the part beyond it is handed to the regional map.
const HANDOFF_OVERSHOOT: float = 8.0
# While zooming, layers are re-recorded once the zoom has changed this much (see refresh_layer_recordings).
const REDRAW_ZOOM_DRIFT: float = 1.15

var recorded_zoom: float = -1.0
var recorded_area: Rect2 = Rect2()
signal return_requested
# The top bar's Menu button: save, load, quit (scripts/app.gd).
signal menu_requested

const ZOOM_STEP: float = 1.25
const ZOOM_SMOOTHING: float = 14.0
const KEY_PAN_SPEED_PX: float = 750.0
const DRAG_THRESHOLD_PX: float = 4.0
# Longitude the camera opens on: the old kingdoms of the Heartland.
const START_LONGITUDE: float = 195.0

var data: WorldMapData = null
var world_root: Node2D = null
var terrain_layer: WorldTerrainLayer = null
var river_layer: WorldRiverLayer = null
var footprint_layer: WorldSettlementLayer = null
var road_layer: WorldRoadLayer = null
var icon_layer: WorldSettlementLayer = null
var label_layer: WorldLabelLayer = null
var panel: WorldMapPanel = null
var layers: Array[WorldMapLayer] = []

var camera_center: Vector2 = Vector2.ZERO
var zoom: float = 0.2
var target_zoom: float = 0.2
var zoom_anchor_screen: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_button: int = MOUSE_BUTTON_NONE
var drag_distance: float = 0.0
var last_mouse: Vector2 = Vector2.ZERO

var hovered_region_id: int = -1
var selected_region_id: int = -1
var hovered_settlement_id: int = -1
var selected_settlement_id: int = -1

# Set by the owner: the region the player already lives in, and whether settling a
# different region is blocked (only one player settlement is supported today).
var home_region_id: int = -1
var other_regions_locked: bool = false

var show_borders: bool = true
var show_roads: bool = true
var show_settlements: bool = true
var show_labels: bool = true

func setup(world_data: WorldMapData) -> void:
	data = world_data
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	terrain_layer = WorldTerrainLayer.new()
	river_layer = WorldRiverLayer.new()
	footprint_layer = WorldSettlementLayer.new()
	footprint_layer.pass_kind = WorldSettlementLayer.Pass.FOOTPRINTS
	road_layer = WorldRoadLayer.new()
	icon_layer = WorldSettlementLayer.new()
	icon_layer.pass_kind = WorldSettlementLayer.Pass.ICONS
	label_layer = WorldLabelLayer.new()
	# Bottom to top: footprints sit under roads so roads visibly run into towns.
	add_layer(terrain_layer, "Terrain")
	add_layer(river_layer, "Rivers")
	add_layer(footprint_layer, "Footprints")
	add_layer(road_layer, "Roads")
	add_layer(icon_layer, "Settlements")
	add_layer(label_layer, "Labels")

	panel = WorldMapPanel.new()
	panel.name = "Panel"
	panel.view = self
	add_child(panel)

	data.changed.connect(on_world_data_changed)
	get_viewport().size_changed.connect(on_viewport_resized)
	reset_camera()

func add_layer(layer: WorldMapLayer, layer_name: String) -> void:
	layer.name = layer_name
	world_root.add_child(layer)
	layer.setup(data)
	layers.append(layer)

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active:
		apply_camera()
		panel.queue_redraw()

func set_home_region(region_id: int, lock_other_regions: bool) -> void:
	home_region_id = region_id
	other_regions_locked = lock_other_regions
	panel.queue_redraw()

func _draw() -> void:
	# Backdrop for the strip under the top bar and any frame before the map draws.
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), WorldMapStyle.COLOR_BACKGROUND)

# --- Camera ----------------------------------------------------------------

# The part of the screen the map shows through: everything below the top bar.
func map_screen_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var top: float = minf(WorldMapPanel.TOP_BAR_HEIGHT, viewport_size.y * 0.5)
	return Rect2(Vector2(0.0, top), Vector2(viewport_size.x, viewport_size.y - top))

func min_zoom() -> float:
	var map_size: Vector2 = map_screen_rect().size
	if data == null or map_size.x <= 0.0 or map_size.y <= 0.0:
		return WorldMapStyle.MIN_ZOOM_FALLBACK
	# Zoomed fully out, pole to pole fills the screen height. The sides need no fit
	# because the map wraps east-west.
	return map_size.y / data.world_size.y

func reset_camera() -> void:
	zoom = min_zoom()
	target_zoom = zoom
	camera_center = Vector2(START_LONGITUDE / 360.0 * data.world_size.x, data.world_size.y * 0.5)
	apply_camera()

func focus_on(world_position: Vector2, new_zoom: float) -> void:
	camera_center = world_position
	zoom = new_zoom
	target_zoom = new_zoom
	apply_camera()

func apply_camera() -> void:
	if data == null:
		return
	var map_rect: Rect2 = map_screen_rect()
	zoom = clampf(zoom, min_zoom(), WorldMapStyle.MAX_ZOOM)
	target_zoom = clampf(target_zoom, min_zoom(), WorldMapStyle.MAX_ZOOM * HANDOFF_OVERSHOOT)
	camera_center.x = data.wrap_x(camera_center.x)
	var half_height: float = map_rect.size.y * 0.5 / zoom
	if half_height * 2.0 >= data.world_size.y:
		camera_center.y = data.world_size.y * 0.5
	else:
		camera_center.y = clampf(camera_center.y, half_height, data.world_size.y - half_height)
	world_root.scale = Vector2(zoom, zoom)
	world_root.position = map_rect.get_center() - camera_center * zoom
	var copies: Array[int] = visible_wrap_copies(get_viewport_rect().size)
	refresh_layer_recordings()
	for layer: WorldMapLayer in layers:
		layer.set_visible_copies(copies)
	queue_redraw()

# Layers record their drawing for an area around the view at one zoom. Re-recording all of
# them costs tens of milliseconds, so while the zoom animates they are re-recorded only once
# it has drifted REDRAW_ZOOM_DRIFT (strokes and icons are briefly a little off their exact
# screen size), and once more when it settles; panning re-records only on leaving the area.
func refresh_layer_recordings() -> void:
	terrain_layer.set_view_zoom(zoom)
	var view_rect: Rect2 = Rect2(camera_center - map_screen_rect().size * 0.5 / zoom, map_screen_rect().size / zoom)
	var settled: bool = is_equal_approx(zoom, target_zoom)
	var drifted: bool = recorded_zoom <= 0.0 or maxf(zoom / recorded_zoom, recorded_zoom / zoom) > REDRAW_ZOOM_DRIFT
	var stale: bool = drifted or (settled and not is_equal_approx(zoom, recorded_zoom)) or not recorded_area.encloses(view_rect)
	if not stale:
		return
	recorded_zoom = zoom
	# A screen's margin on every side: labels just off screen still keep room for those on it.
	recorded_area = view_rect.grow_individual(view_rect.size.x, view_rect.size.y, view_rect.size.x, view_rect.size.y)
	for layer: WorldMapLayer in layers:
		if layer == terrain_layer:
			continue
		layer.set_cull_rect(recorded_area)
		layer.set_view_zoom(zoom)

# Wrap copies (one world-width apart) that overlap the screen, with a margin so labels
# and icons hanging over the seam are not clipped.
func visible_wrap_copies(viewport_size: Vector2) -> Array[int]:
	var margin: float = 240.0 / zoom
	var half_width: float = viewport_size.x * 0.5 / zoom + margin
	var copies: Array[int] = []
	for copy in [-1, 0, 1]:
		var copy_left: float = copy * data.world_size.x
		if camera_center.x + half_width > copy_left and camera_center.x - half_width < copy_left + data.world_size.x:
			copies.append(copy)
	return copies

func screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - world_root.position) / zoom

func zoom_toward(factor: float, screen_position: Vector2) -> void:
	target_zoom = clampf(target_zoom * factor, min_zoom(), WorldMapStyle.MAX_ZOOM * HANDOFF_OVERSHOOT)
	zoom_anchor_screen = screen_position

func on_viewport_resized() -> void:
	apply_camera()
	panel.queue_redraw()

func _process(delta: float) -> void:
	var moved: bool = false
	var pan: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		camera_center += pan.normalized() * KEY_PAN_SPEED_PX * delta / zoom
		moved = true

	if target_zoom > WorldMapStyle.MAX_ZOOM and zoom >= WorldMapStyle.MAX_ZOOM * 0.999:
		# Eased in to the closest view with zoom still to go: the regional map carries on.
		var remaining: float = target_zoom / WorldMapStyle.MAX_ZOOM
		target_zoom = WorldMapStyle.MAX_ZOOM
		var world_position: Vector2 = screen_to_world(zoom_anchor_screen)
		zoom_in_past_max.emit(Vector2(data.wrap_x(world_position.x), world_position.y), zoom_anchor_screen, remaining)
	elif not is_equal_approx(zoom, target_zoom):
		# Keep the world point under the cursor fixed while the zoom eases in.
		var anchor_world: Vector2 = screen_to_world(zoom_anchor_screen)
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-ZOOM_SMOOTHING * delta))
		if absf(zoom - target_zoom) / target_zoom < 0.002:
			zoom = target_zoom
		# A target past the closest view (the regional map takes the rest) never pulls the zoom past it.
		zoom = clampf(zoom, min_zoom(), WorldMapStyle.MAX_ZOOM)
		camera_center = anchor_world - (zoom_anchor_screen - map_screen_rect().get_center()) / zoom
		moved = true

	if moved:
		apply_camera()
		update_hover(get_local_mouse_position())

# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if data == null:
		return
	if event is InputEventMouseButton:
		handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if is_dragging:
			var delta: Vector2 = motion.position - last_mouse
			last_mouse = motion.position
			drag_distance += delta.length()
			camera_center -= delta / zoom
			apply_camera()
		update_hover(motion.position)
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		zoom_toward(magnify.factor, magnify.position)
	elif event is InputEventPanGesture:
		camera_center += (event as InputEventPanGesture).delta * 12.0 / zoom
		apply_camera()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if handle_key((event as InputEventKey).keycode):
			get_viewport().set_input_as_handled()
		return
	else:
		return
	get_viewport().set_input_as_handled()

func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and panel.handle_mouse_button(event):
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_toward(ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_toward(1.0 / ZOOM_STEP, event.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_button = event.button_index
				drag_distance = 0.0
				last_mouse = event.position
				if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
					select_at(event.position)
					request_region_entry(selected_region_id)
			elif event.button_index == drag_button:
				is_dragging = false
				if drag_distance < DRAG_THRESHOLD_PX:
					if event.button_index == MOUSE_BUTTON_LEFT:
						select_at(event.position)
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						clear_selection()
				panel.queue_redraw()

func handle_key(keycode: int) -> bool:
	match keycode:
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			zoom_toward(ZOOM_STEP, map_screen_rect().get_center())
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_toward(1.0 / ZOOM_STEP, map_screen_rect().get_center())
		KEY_HOME:
			reset_camera()
		KEY_ENTER, KEY_KP_ENTER:
			request_region_entry(selected_region_id)
		KEY_ESCAPE:
			clear_selection()
		KEY_B:
			apply_hud_action("toggle_borders")
		KEY_R:
			apply_hud_action("toggle_roads")
		KEY_T:
			apply_hud_action("toggle_settlements")
		KEY_L:
			apply_hud_action("toggle_labels")
		_:
			return false
	return true

func apply_hud_action(action: String) -> void:
	match action:
		"toggle_borders":
			show_borders = not show_borders
			terrain_layer.set_borders_visible(show_borders)
		"toggle_roads":
			show_roads = not show_roads
			road_layer.visible = show_roads
		"toggle_settlements":
			show_settlements = not show_settlements
			icon_layer.visible = show_settlements
			footprint_layer.visible = show_settlements
		"toggle_labels":
			show_labels = not show_labels
			label_layer.visible = show_labels
		"toggle_legend":
			panel.show_legend = not panel.show_legend
		"enter_region":
			request_region_entry(selected_region_id)
		"return":
			return_requested.emit()
		"open_menu":
			menu_requested.emit()
	panel.queue_redraw()

# --- Hover and selection ---------------------------------------------------

func update_hover(screen_position: Vector2) -> void:
	var settlement_id: int = -1
	var region_id: int = -1
	if not panel.is_over_hud(screen_position):
		settlement_id = settlement_at(screen_position)
		region_id = data.region_id_at(screen_to_world(screen_position))
	if settlement_id != hovered_settlement_id or region_id != hovered_region_id:
		hovered_settlement_id = settlement_id
		hovered_region_id = region_id
		refresh_highlights()
	panel.queue_redraw()

func settlement_at(screen_position: Vector2) -> int:
	if not show_settlements:
		return -1
	var best_id: int = -1
	var best_distance: float = INF
	var world_width_px: float = data.world_size.x * zoom
	for settlement: WorldMapData.Settlement in data.settlements:
		if WorldMapStyle.settlement_visibility(settlement, zoom) < 0.3:
			continue
		var reach: float = WorldMapStyle.settlement_icon_radius(settlement, zoom) * 1.2
		var screen: Vector2 = world_root.position + settlement.position * zoom
		for copy in [-1, 0, 1]:
			var distance: float = (screen + Vector2(copy * world_width_px, 0.0)).distance_to(screen_position)
			if distance < reach and distance < best_distance:
				best_distance = distance
				best_id = settlement.id
	return best_id

func select_at(screen_position: Vector2) -> void:
	var settlement_id: int = settlement_at(screen_position)
	if settlement_id >= 0:
		selected_settlement_id = settlement_id
		selected_region_id = data.settlements[settlement_id].region_id
	else:
		selected_settlement_id = -1
		selected_region_id = data.region_id_at(screen_to_world(screen_position))
	refresh_highlights()

func select_region(region_id: int) -> void:
	selected_settlement_id = -1
	selected_region_id = region_id
	refresh_highlights()

func clear_selection() -> void:
	selected_settlement_id = -1
	selected_region_id = -1
	refresh_highlights()

func refresh_highlights() -> void:
	terrain_layer.set_region_highlight(hovered_region_id, selected_region_id)
	icon_layer.set_highlight(hovered_settlement_id, selected_settlement_id)
	panel.queue_redraw()

# --- Entering regions ------------------------------------------------------

# Every region can be looked at on the regional map. The player starts as free settlers, so
# only land no kingdom holds can be settled, and only one settlement is supported today.
func get_region_entry_status(region: WorldMapData.Region) -> Dictionary:
	if region == null:
		return {"allowed": false, "button": "Enter region", "reason": "", "can_settle": false}
	if region.id == home_region_id and other_regions_locked:
		return {"allowed": true, "button": "Return to region", "reason": "Your people live here.", "can_settle": false}
	var kingdom: WorldMapData.Kingdom = data.get_kingdom(region.owner_kingdom_id)
	if kingdom != null:
		return {"allowed": true, "button": "View region", "reason": "Held by " + kingdom.name + ". Free settlers can only found towns on land no kingdom holds.", "can_settle": false}
	if other_regions_locked and home_region_id >= 0:
		var home: WorldMapData.Region = data.get_region(home_region_id)
		return {"allowed": true, "button": "View region", "reason": "Your settlement is in " + home.name + ". Settling a second region is not possible yet.", "can_settle": false}
	var reason: String = "Open frontier. Enter to survey founding sites."
	if region.is_contested():
		reason = "Contested frontier: claimed by kingdoms but held by none. Enter to survey founding sites."
	return {"allowed": true, "button": "Enter region", "reason": reason, "can_settle": true}

func request_region_entry(region_id: int) -> void:
	var region: WorldMapData.Region = data.get_region(region_id)
	if region == null or not bool(get_region_entry_status(region)["allowed"]):
		return
	region_entry_requested.emit(region_id)

# --- World changes ---------------------------------------------------------

func on_world_data_changed(layer: String) -> void:
	match layer:
		WorldMapData.LAYER_TERRAIN:
			terrain_layer.rebuild_terrain()
			river_layer.queue_redraw()
		WorldMapData.LAYER_POLITICAL:
			terrain_layer.rebuild_political()
			icon_layer.queue_redraw()
			label_layer.queue_redraw()
		WorldMapData.LAYER_SETTLEMENTS:
			terrain_layer.rebuild_development()
			footprint_layer.queue_redraw()
			icon_layer.queue_redraw()
			label_layer.queue_redraw()
		WorldMapData.LAYER_ROADS:
			footprint_layer.rebuild_road_angles()
			footprint_layer.queue_redraw()
			road_layer.queue_redraw()
	panel.queue_redraw()
