extends Node2D

const TILE_SIZE: int = 12
const MAP_WIDTH: int = 80
const MAP_HEIGHT: int = 50
const MIN_CITY_DISTANCE: int = 24
const RIVER_NEAR_RANGE: int = 5
const CITY_RESOURCE_RANGE: int = 7
const PANEL_MARGIN: int = VisualStyle.PANEL_MARGIN
const PANEL_WIDTH: int = 290
const PANEL_PADDING: int = VisualStyle.SIDEBAR_PADDING
const VIEW_REGION: String = "region"
const VIEW_CITY: String = "city"
const VIEW_WORLD: String = "world"
const CITY_TILE_SIZE: int = 12
const CITY_MAP_WIDTH: int = 64
const CITY_MAP_HEIGHT: int = 44
const CITY_VIEW_TOP: int = 48
const TOP_BAR_HEIGHT: int = 42
const CITY_SIDEBAR_MARGIN: int = VisualStyle.PANEL_MARGIN
const CITY_SIDEBAR_WIDTH: int = 300
const CITY_SIDEBAR_PADDING: int = VisualStyle.SIDEBAR_PADDING
const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const WOODCUTTER_TREE_RADIUS: int = 5
const CITY_WALKER_CYCLE_SECONDS: float = 12.0
const FOUNDING_HOUSEHOLD_COUNT: int = EconomyBalance.FOUNDING_FAMILIES
const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
const CITY_TREND_STABLE_THRESHOLD: float = 0.15
# Gameplay neighbourhood on the continuous regional map: about four of the old regional maps.
const NEIGHBOURHOOD_SIZE: Vector2i = Vector2i(160, 100)
# Before founding, the neighbourhood follows the camera once it settles closer than this to
# the neighbourhood's edge, so founding sites are wherever the player looks.
const NEIGHBOURHOOD_MARGIN_TILES: int = 30
const REGION_ENTRY_ZOOM: float = 1.2
# Atlas zoom when the World button opens it from the regional map: the surrounding regions.
const WORLD_BUTTON_ATLAS_ZOOM: float = 1.2

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tiles: Array = []
var cities: Array[City] = []
var roads: Array[Array] = []
var trade_routes: Array[TradeRoute] = []
var top_bar_action_options: Array[Dictionary] = []
var region_action_options: Array[Dictionary] = []
var city_action_options: Array[Dictionary] = []
var build_menu_options: Array[Dictionary] = []
var hovered_tile: Vector2i = Vector2i(-1, -1)
var hovered_city_index: int = -1
var city_hovered_tile: Vector2i = Vector2i(-1, -1)
var pending_founding_tile: Vector2i = Vector2i(-1, -1)
# The town map for the pending site, generated when the site is picked so the survey shown to the
# player describes exactly the map the town will get; reused at founding.
var pending_site_profile: SettlementSiteProfile = null
var pending_local_map: Array = []
var pending_site_survey: Array[String] = []
var current_view: String = VIEW_REGION
var selected_city_index: int = -1
var household_debug_inspector: Control = null
var trade_menu: TradeMenu = TradeMenu.new()
var selected_building_type: String = BUILDING_HOUSE
var is_placing_building: bool = true
var is_build_menu_open: bool = false
var city_walker_time: float = 0.0
var world_calendar: Calendar = Calendar.new()
var simulation_clock: SimulationClock = SimulationClock.new()
var building_placement: BuildingPlacement = BuildingPlacement.new(CITY_MAP_WIDTH, CITY_MAP_HEIGHT, WOODCUTTER_TREE_RADIUS)
var city_building_overlay: CityBuildingOverlay = CityBuildingOverlay.new(CITY_TILE_SIZE, CITY_VIEW_TOP, CITY_MAP_WIDTH, CITY_MAP_HEIGHT)

var city_pressure_debug_panel: Control = null
# The world atlas draws on its own canvas layer above this node's screen-space drawing.
var world_map_layer: CanvasLayer = null
var world_map_view: WorldMapView = null
var world_map_data: WorldMapData = null
# World region the current regional map was generated for; -1 before any region is entered.
var entered_world_region_id: int = -1
# What the world says about the entered region; steers the generator and the landscape's
# palette. Null for regional maps made without the world (tests, the original valley).
var region_geography: RegionGeography = null
# The regional landscape draws on its own canvas layer under this node's panels. Without it
# (scripts that never enter the scene tree) the original tile drawing is used.
var region_map_layer: CanvasLayer = null
var region_map_view: RegionMapView = null
# Tiles where a town may be founded, refreshed when towns change rather than every frame.
var region_founding_sites: Array[Vector2i] = []
# The continuous regional map: the whole planet at regional scale, built on first use. Its
# game rules run on a neighbourhood of it: tiles, cities, and roads are the window of
# region_map_size tiles starting at the global tile neighbourhood_origin. Without it (scripts
# that build a bounded region directly) the window is the whole bounded map.
var regional_terrain: RegionalTerrain = null
var region_map_size: Vector2i = Vector2i(MAP_WIDTH, MAP_HEIGHT)
var neighbourhood_origin: Vector2i = Vector2i.ZERO
# The calendar waits until the regional map has been shown once.
var has_shown_region_map: bool = false
var last_region_in_view_id: int = -1

func get_city_pressure_debug_city() -> City:
	if selected_city_index >= 0 and selected_city_index < cities.size():
		return cities[selected_city_index]
	return null

func _ensure_city_pressure_debug_panel() -> void:
	if city_pressure_debug_panel == null:
		city_pressure_debug_panel = preload("res://scripts/ui/city_pressure_debug_panel.gd").new()
		add_child(city_pressure_debug_panel)
		city_pressure_debug_panel.visible = false
func _ready():
	rng.randomize()
	world_calendar.month_changed.connect(on_calendar_month_changed)
	world_calendar.season_changed.connect(on_calendar_season_changed)
	_ensure_household_debug_inspector()
	_ensure_region_map_view()
	# The game opens on the world atlas; the regional map is generated when a region is entered.
	open_world_map()

func _ensure_region_map_view() -> void:
	if region_map_view != null:
		return
	region_map_layer = CanvasLayer.new()
	region_map_layer.layer = -1
	add_child(region_map_layer)
	region_map_view = RegionMapView.new()
	region_map_view.visible = false
	region_map_layer.add_child(region_map_view)
	region_map_view.map_clicked.connect(on_region_map_clicked)
	region_map_view.zoom_out_past_min.connect(on_region_zoom_out_past_min)

# Called after towns or roads change (founding, growth, building in the town view).
func notify_region_map_changed() -> void:
	refresh_founding_sites()
	if region_map_view != null:
		region_map_view.notify_changed(RegionMapView.LAYER_DEVELOPMENT, cities, roads)

func refresh_founding_sites() -> void:
	region_founding_sites.clear()
	if has_player_city() or tiles.is_empty():
		return
	for y in range(region_map_size.y):
		for x in range(region_map_size.x):
			if is_valid_founding_tile(Vector2i(x, y)):
				region_founding_sites.append(Vector2i(x, y))

# Panels drawn over the regional map: the top bar, the inspector, and the trade menu.
func get_region_inspector_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var x: float = maxf(viewport_size.x - PANEL_WIDTH - PANEL_MARGIN, PANEL_MARGIN)
	return Rect2(Vector2(x, TOP_BAR_HEIGHT), Vector2(PANEL_WIDTH, maxf(viewport_size.y - TOP_BAR_HEIGHT - PANEL_MARGIN, 200.0)))

func get_region_map_screen_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var right: float = get_region_inspector_rect().position.x - PANEL_MARGIN * 0.5
	return Rect2(Vector2(0.0, TOP_BAR_HEIGHT), Vector2(maxf(right, 100.0), maxf(viewport_size.y - TOP_BAR_HEIGHT, 100.0)))

func is_over_region_panels(mouse_pos: Vector2) -> bool:
	if mouse_pos.y < TOP_BAR_HEIGHT or get_region_inspector_rect().has_point(mouse_pos):
		return true
	return trade_menu.is_open() and trade_menu.menu_rect.has_point(mouse_pos)

# Screen position to regional-map position (map units, TILE_SIZE per tile).
func region_screen_to_map(mouse_pos: Vector2) -> Vector2:
	if region_map_view == null:
		return mouse_pos
	return region_map_view.screen_to_map(mouse_pos)

func region_map_to_screen(map_pos: Vector2) -> Vector2:
	if region_map_view == null:
		return map_pos
	return region_map_view.map_to_screen(map_pos)

# Mouse events belong to the landscape when they are over it, or when it is mid-drag.
func is_region_map_input(mouse_pos: Vector2) -> bool:
	if region_map_view == null:
		return false
	return region_map_view.press_button != MOUSE_BUTTON_NONE or not is_over_region_panels(mouse_pos)

func on_region_map_clicked(mouse_pos: Vector2) -> void:
	if trade_menu.is_open():
		try_handle_trade_city_click(mouse_pos)
	elif not try_open_city_at_position(mouse_pos):
		try_select_founding_tile_at_position(mouse_pos)
	queue_redraw()

# Keeps the landscape's overlays in step with the founding state.
func sync_region_map_view() -> void:
	if region_map_view == null:
		return
	var choosing_site: bool = not has_player_city()
	region_map_view.set_founding_state(choosing_site, region_founding_sites, pending_founding_tile, MIN_CITY_DISTANCE, CITY_RESOURCE_RANGE)
	region_map_view.set_selected_city(selected_city_index)
	region_map_view.set_hover(hovered_tile, choosing_site and is_valid_founding_tile(hovered_tile), hovered_city_index)

func _ensure_world_map_view() -> void:
	if world_map_view != null:
		return
	world_map_data = FixedWorldDefinition.build()
	world_map_layer = CanvasLayer.new()
	world_map_layer.layer = 1
	add_child(world_map_layer)
	world_map_view = WorldMapView.new()
	world_map_layer.add_child(world_map_view)
	world_map_view.setup(world_map_data)
	world_map_view.region_entry_requested.connect(on_world_region_entry_requested)
	world_map_view.zoom_in_past_max.connect(on_world_zoom_in_past_max)
	world_map_view.return_requested.connect(close_world_map)

func open_world_map() -> void:
	_ensure_world_map_view()
	var coming_from_region: bool = current_view == VIEW_REGION and is_continuous_region_map()
	current_view = VIEW_WORLD
	hovered_tile = Vector2i(-1, -1)
	hovered_city_index = -1
	trade_menu.close()
	if household_debug_inspector != null:
		household_debug_inspector.visible = false
	if city_pressure_debug_panel != null:
		city_pressure_debug_panel.visible = false
	# Only one player settlement exists for now, so founding locks the player to its region.
	world_map_view.set_home_region(entered_world_region_id, has_player_city())
	world_map_layer.visible = true
	world_map_view.set_active(true)
	if coming_from_region and region_map_view != null:
		# The atlas opens over the place the regional map was showing.
		var world_position: Vector2 = region_map_view.screen_to_world(region_map_view.screen_rect.get_center())
		world_map_view.focus_on(world_position, WORLD_BUTTON_ATLAS_ZOOM)
		world_map_view.select_region(world_map_data.region_id_at(world_position))
	elif entered_world_region_id >= 0:
		world_map_view.select_region(entered_world_region_id)
	queue_redraw()

func close_world_map() -> void:
	if not has_shown_region_map:
		return
	world_map_layer.visible = false
	world_map_view.set_active(false)
	current_view = VIEW_REGION
	queue_redraw()

# Entering a region looks at its main settlement. Before founding, the founding
# neighbourhood moves there; after, the home town stays where it is and the region is only viewed.
func on_world_region_entry_requested(region_id: int) -> void:
	var region: WorldMapData.Region = world_map_data.get_region(region_id)
	if region == null:
		return
	_ensure_regional_terrain()
	var focus: Vector2 = regional_terrain.region_focus(region)
	var player_index: int = get_player_city_index()
	if player_index >= 0 and region_id == entered_world_region_id:
		focus = regional_terrain.tile_center_to_world(local_to_global_tile(Vector2i(cities[player_index].tile)))
	enter_regional_map_at(focus, REGION_ENTRY_ZOOM, Vector2(-1.0, -1.0))
	print("Entered world region: ", region.name, " (", region.climate, "; ", region.landscape, ")")

# Zooming into the atlas past its closest view lands on the regional map at the same
# place and scale. Open water has no regional map, so the atlas stays.
func on_world_zoom_in_past_max(world_position: Vector2, screen_position: Vector2) -> void:
	if not world_map_data.is_land_at(world_position):
		return
	enter_regional_map_at(world_position, RegionMapView.HANDOFF_ZOOM, screen_position)

# Zooming out of the regional map past its widest view lands on the atlas at the same place
# and scale, keeping the point under the cursor where it was.
func on_region_zoom_out_past_min(screen_position: Vector2) -> void:
	var world_position: Vector2 = region_map_view.screen_to_world(screen_position)
	open_world_map()
	var atlas_zoom: float = WorldMapStyle.MAX_ZOOM
	var atlas_center: Vector2 = world_position - (screen_position - world_map_view.map_screen_rect().get_center()) / atlas_zoom
	world_map_view.focus_on(atlas_center, atlas_zoom)
	world_map_view.select_region(world_map_data.region_id_at(world_position))
	get_viewport().set_input_as_handled()

# Shows the regional map with world_position under screen_position (the view's middle when
# screen_position is negative).
func enter_regional_map_at(world_position: Vector2, zoom: float, screen_position: Vector2) -> void:
	_ensure_regional_terrain()
	var tile: Vector2i = regional_terrain.wrap_tile(regional_terrain.world_to_tile_index(world_position))
	if not has_player_city():
		place_neighbourhood(tile)
	has_shown_region_map = true
	close_world_map()
	if region_map_view != null:
		region_map_view.set_screen_rect(get_region_map_screen_rect())
		var anchor: Vector2 = screen_position if screen_position.x >= 0.0 else region_map_view.screen_rect.get_center()
		var center_tile: Vector2 = regional_terrain.world_to_tile(world_position) - (anchor - region_map_view.screen_rect.get_center()) / (zoom * RegionMapStyle.TILE)
		region_map_view.focus_on_global_tile(center_tile, zoom)

func _ensure_regional_terrain() -> void:
	if regional_terrain != null:
		return
	_ensure_world_map_view()
	regional_terrain = RegionalTerrain.new(world_map_data)
	if region_map_view != null:
		region_map_view.set_terrain(regional_terrain)

func is_continuous_region_map() -> bool:
	return regional_terrain != null

func local_to_global_tile(tile: Vector2i) -> Vector2i:
	if regional_terrain == null:
		return tile
	return Vector2i(regional_terrain.wrap_tile_x(neighbourhood_origin.x + tile.x), neighbourhood_origin.y + tile.y)

func global_to_local_tile(tile: Vector2i) -> Vector2i:
	var dx: int = posmod(tile.x - neighbourhood_origin.x, regional_terrain.size_tiles.x)
	if dx > regional_terrain.size_tiles.x / 2:
		dx -= regional_terrain.size_tiles.x
	return Vector2i(dx, tile.y - neighbourhood_origin.y)

# The neighbourhood's origin when centered on a global tile, kept off the poles.
func neighbourhood_origin_around(center: Vector2i) -> Vector2i:
	var y: int = clampi(center.y - NEIGHBOURHOOD_SIZE.y / 2, 0, regional_terrain.size_tiles.y - NEIGHBOURHOOD_SIZE.y)
	return Vector2i(regional_terrain.wrap_tile_x(center.x - NEIGHBOURHOOD_SIZE.x / 2), y)

# Before founding: the gameplay neighbourhood becomes the window of the planet around a
# global tile, with the world's settlements in it as neutral towns. A chosen site inside the
# new window is kept.
func place_neighbourhood(center: Vector2i) -> void:
	var kept_site: Vector2i = local_to_global_tile(pending_founding_tile) if has_pending_founding_tile() else Vector2i(-1, -1)
	neighbourhood_origin = neighbourhood_origin_around(center)
	region_map_size = NEIGHBOURHOOD_SIZE
	tiles = regional_terrain.extract_window(neighbourhood_origin, region_map_size)
	var neighbourhood_cities: Array[City] = []
	for pair: Array in regional_terrain.settlements_in_window(neighbourhood_origin, region_map_size):
		var settlement: WorldMapData.Settlement = pair[0]
		neighbourhood_cities.append(City.new(settlement.name, Vector2((pair[1] as Vector2i) - neighbourhood_origin), City.ROLE_NEUTRAL))
	cities = neighbourhood_cities
	roads = []
	region_geography = null
	clear_pending_founding_tile()
	trade_routes.clear()
	trade_menu.close()
	selected_city_index = -1
	analyze_city_site_profiles()
	generate_city_local_maps()
	refresh_founding_sites()
	entered_world_region_id = world_map_data.region_id_at(regional_terrain.tile_center_to_world(center))
	if region_map_view != null:
		region_map_view.set_neighbourhood(tiles, cities, roads, neighbourhood_origin)
	if kept_site.x >= 0:
		var local_site: Vector2i = global_to_local_tile(kept_site)
		if is_inside_map(local_site.x, local_site.y):
			set_pending_founding_tile(local_site)

# Before founding, the neighbourhood follows the camera once it comes to rest near the
# neighbourhood's edge.
func follow_camera_with_neighbourhood() -> void:
	if not is_continuous_region_map() or has_player_city() or region_map_view == null:
		return
	if region_map_view.press_button != MOUSE_BUTTON_NONE or not is_equal_approx(region_map_view.zoom, region_map_view.target_zoom):
		return
	var center: Vector2i = Vector2i(region_map_view.camera_global_tile().floor())
	var local: Vector2i = global_to_local_tile(center)
	var margin: int = NEIGHBOURHOOD_MARGIN_TILES
	if local.x >= margin and local.y >= margin and local.x < region_map_size.x - margin and local.y < region_map_size.y - margin:
		return
	if neighbourhood_origin_around(center) == neighbourhood_origin:
		return
	place_neighbourhood(center)
	queue_redraw()

# Free settlers may not found towns on land a kingdom holds; null where none does.
func get_kingdom_holding_tile(tile_pos: Vector2i) -> WorldMapData.Kingdom:
	if regional_terrain == null:
		return null
	var region: WorldMapData.Region = world_map_data.get_region(regional_terrain.region_id_at_tile(local_to_global_tile(tile_pos)))
	if region == null:
		return null
	return world_map_data.get_kingdom(region.owner_kingdom_id)

# The world region the regional map is showing: the one under the camera.
func get_region_in_view() -> WorldMapData.Region:
	if regional_terrain == null or region_map_view == null:
		return world_map_data.get_region(entered_world_region_id) if world_map_data != null else null
	return world_map_data.get_region(regional_terrain.region_vote_at(region_map_view.camera_global_tile() * RegionalTerrain.TILE_WORLD_UNITS))

func _process(_delta: float):
	if region_map_view != null:
		region_map_view.visible = current_view == VIEW_REGION
		region_map_view.set_screen_rect(get_region_map_screen_rect())
	if current_view == VIEW_WORLD and not has_shown_region_map:
		# Nothing lives in the world simulation yet, so the calendar waits for the first region.
		return
	if current_view == VIEW_REGION:
		follow_camera_with_neighbourhood()
		# The title and inspector describe the region in view, which changes as the camera pans.
		var region_in_view: WorldMapData.Region = get_region_in_view() if world_map_data != null else null
		var region_in_view_id: int = region_in_view.id if region_in_view != null else -1
		if region_in_view_id != last_region_in_view_id:
			last_region_in_view_id = region_in_view_id
			queue_redraw()

	if not simulation_clock.is_paused:
		city_walker_time += _delta * max(1.0, simulation_clock.get_speed_multiplier())
		if city_walker_time >= CITY_WALKER_CYCLE_SECONDS:
			city_walker_time = fmod(city_walker_time, CITY_WALKER_CYCLE_SECONDS)

	var days_to_advance: int = simulation_clock.advance_realtime(_delta)
	for day_index in range(days_to_advance):
		run_simulation_day()

	if current_view == VIEW_REGION:
		var mouse_pos: Vector2 = get_local_mouse_position()
		update_hovered_tile(mouse_pos)
		update_hovered_city(mouse_pos)
		if hovered_city_index != -1:
			queue_redraw()
	elif current_view == VIEW_CITY:
		update_city_hovered_tile(get_local_mouse_position())
		if hovered_tile != Vector2i(-1, -1):
			hovered_tile = Vector2i(-1, -1)
			queue_redraw()
		if hovered_city_index != -1:
			hovered_city_index = -1
			queue_redraw()
		queue_redraw()

func _input(event: InputEvent):
	# The world map handles its own input.
	if current_view == VIEW_WORLD:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F4:
			if current_view != VIEW_CITY:
				if city_pressure_debug_panel != null:
					city_pressure_debug_panel.visible = false
				get_viewport().set_input_as_handled()
				return
			_ensure_city_pressure_debug_panel()
			city_pressure_debug_panel.set_city(get_city_pressure_debug_city())
			city_pressure_debug_panel.visible = not city_pressure_debug_panel.visible
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if current_view != VIEW_CITY:
			if household_debug_inspector != null:
				household_debug_inspector.visible = false
			print("Household debug inspector is only available in city view.")
			get_viewport().set_input_as_handled()
			return

		_ensure_household_debug_inspector()
		household_debug_inspector.set_city(get_household_debug_city())
		household_debug_inspector.set_selected_household(get_inspected_household())
		household_debug_inspector.visible = not household_debug_inspector.visible
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		# Where this click happened (this node sits at the screen origin, so it is local too).
		var local_mouse_pos: Vector2 = mouse_event.position
		if current_view == VIEW_REGION and trade_menu.handle_mouse_button(mouse_event, local_mouse_pos):
			queue_redraw()
			return
		# The landscape takes wheel zoom, drag panning, and clicks on the map itself; a click
		# comes back through on_region_map_clicked when the button is released without a drag.
		if current_view == VIEW_REGION and is_region_map_input(local_mouse_pos) and region_map_view.handle_mouse_event(mouse_event):
			queue_redraw()
			return

		if not mouse_event.pressed:
			return

		if current_view == VIEW_REGION and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			trade_menu.close()
			clear_pending_founding_tile()
			queue_redraw()
			return
		if current_view == VIEW_CITY and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			is_placing_building = false
			is_build_menu_open = false
			clear_selected_household()
			queue_redraw()
			return

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if try_handle_top_bar_click(local_mouse_pos):
			# The World button opens the atlas during this press; unhandled, the same press
			# would reach the atlas and hit its "Back to" button in the same spot.
			get_viewport().set_input_as_handled()
			queue_redraw()
			return

		if current_view == VIEW_REGION:
			if try_handle_region_action_click(local_mouse_pos):
				queue_redraw()
			elif region_map_view == null:
				on_region_map_clicked(local_mouse_pos)
		elif current_view == VIEW_CITY:
			if try_handle_build_menu_click(local_mouse_pos):
				queue_redraw()
			elif try_handle_city_action_click(local_mouse_pos):
				queue_redraw()
			elif try_handle_building_action_click(local_mouse_pos):
				queue_redraw()
			elif is_inside_city_sidebar(local_mouse_pos):
				if city_building_overlay.has_selection():
					clear_selected_household()
					queue_redraw()
				return
			else:
				if not try_handle_building_click_at_tile(city_hovered_tile, mouse_event.shift_pressed):
					if city_building_overlay.has_selection():
						clear_selected_household()
						queue_redraw()
					elif is_placing_building and not mouse_event.shift_pressed:
						try_place_selected_building()
	elif event is InputEventMouseMotion:
		if current_view == VIEW_REGION and trade_menu.handle_mouse_motion(get_local_mouse_position(), get_viewport_rect().size):
			queue_redraw()
		elif current_view == VIEW_REGION and region_map_view != null and region_map_view.handle_mouse_event(event):
			queue_redraw()
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if current_view == VIEW_REGION and region_map_view != null and region_map_view.handle_key(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_simulation_speed_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_region_trade_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_clear_selection_key(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_build_menu_toggle_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_building_selection_key_event(key_event):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
	if current_view == VIEW_WORLD:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if handle_simulation_speed_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_region_trade_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_clear_selection_key(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_build_menu_toggle_key_event(key_event):
			get_viewport().set_input_as_handled()
			return
		if handle_building_selection_key_event(key_event):
			get_viewport().set_input_as_handled()

func update_hovered_tile(mouse_pos: Vector2):
	var tile_pos: Vector2i = get_region_tile_at_position(mouse_pos)
	var new_hovered_tile: Vector2i = Vector2i(-1, -1)

	if is_inside_map(tile_pos.x, tile_pos.y):
		new_hovered_tile = tile_pos

	if new_hovered_tile != hovered_tile:
		hovered_tile = new_hovered_tile
		queue_redraw()

func update_hovered_city(mouse_pos: Vector2):
	var new_hovered_city_index: int = get_city_index_at_position(mouse_pos)

	if new_hovered_city_index != hovered_city_index:
		hovered_city_index = new_hovered_city_index
		queue_redraw()

func update_city_hovered_tile(mouse_pos: Vector2):
	var tile_x: int = int(floor(mouse_pos.x / CITY_TILE_SIZE))
	var tile_y: int = int(floor((mouse_pos.y - CITY_VIEW_TOP) / CITY_TILE_SIZE))
	var new_hovered_tile: Vector2i = Vector2i(-1, -1)

	if is_inside_city_map(tile_x, tile_y):
		new_hovered_tile = Vector2i(tile_x, tile_y)

	if new_hovered_tile != city_hovered_tile:
		city_hovered_tile = new_hovered_tile
		queue_redraw()

func generate_roads():
	var generator: RegionMapGenerator = make_region_map_generator()
	generator.tiles = tiles
	if is_continuous_region_map():
		roads = generate_spur_roads(generator)
	else:
		roads = generator.generate_roads_for_cities(cities)

# On the continuous map the world's roads are already on the land; the player's town gets a
# track to the nearest of them.
func generate_spur_roads(generator: RegionMapGenerator) -> Array[Array]:
	var spurs: Array[Array] = []
	var player_index: int = get_player_city_index()
	if player_index < 0:
		return spurs
	var town: Vector2i = Vector2i(cities[player_index].tile)
	var target: Vector2i = Vector2i(-1, -1)
	var best: float = INF
	for y in range(region_map_size.y):
		for x in range(region_map_size.x):
			if tiles[y][x]["has_road"] != true:
				continue
			var distance: float = Vector2(x - town.x, y - town.y).length_squared()
			if distance < best:
				best = distance
				target = Vector2i(x, y)
	if target.x < 0 or target == town:
		return spurs
	generator.add_routed_road(generator.make_road_astar(), town, target, spurs)
	return spurs

func make_region_map_generator() -> RegionMapGenerator:
	var generator: RegionMapGenerator = RegionMapGenerator.new(rng, region_map_size.x, region_map_size.y, MIN_CITY_DISTANCE, RIVER_NEAR_RANGE, CITY_RESOURCE_RANGE)
	generator.geography = region_geography
	return generator

func make_local_map_generator() -> LocalCityMapGenerator:
	return LocalCityMapGenerator.new(rng, CITY_MAP_WIDTH, CITY_MAP_HEIGHT, region_map_size.x, region_map_size.y, RIVER_NEAR_RANGE, CITY_RESOURCE_RANGE)

func analyze_city_site_profiles():
	for city: City in cities:
		city.site_profile = SettlementSiteProfile.analyze(city.tile, tiles, CITY_RESOURCE_RANGE)
		print(city.name, " site profile: ", city.site_profile.get_debug_summary())

func generate_city_local_maps():
	var generator: LocalCityMapGenerator = make_local_map_generator()
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		city.local_map = generator.generate(city, tiles, city_index)

func is_inside_map(x: int, y: int) -> bool:
	return x >= 0 and x < region_map_size.x and y >= 0 and y < region_map_size.y

func try_open_city_at_position(mouse_pos: Vector2) -> bool:
	var city_index: int = get_city_index_at_position(mouse_pos)
	if city_index == -1:
		return false
	var city: City = cities[city_index]
	if not city.is_controllable_city():
		print(city.name, " is neutral and cannot be controlled yet.")
		return true

	selected_city_index = city_index
	current_view = VIEW_CITY
	hovered_tile = Vector2i(-1, -1)
	hovered_city_index = -1
	queue_redraw()
	return true

func try_select_founding_tile_at_position(mouse_pos: Vector2) -> bool:
	var tile_pos: Vector2i = get_region_tile_at_position(mouse_pos)
	if not is_inside_map(tile_pos.x, tile_pos.y) and is_continuous_region_map() and not has_player_city() and not is_over_region_panels(mouse_pos):
		# A site beyond the neighbourhood: the neighbourhood moves there first.
		var global_tile: Vector2i = region_map_view.screen_to_global_tile(mouse_pos)
		if global_tile.x >= 0:
			place_neighbourhood(global_tile)
			tile_pos = get_region_tile_at_position(mouse_pos)
	if not is_inside_map(tile_pos.x, tile_pos.y):
		return false
	if set_pending_founding_tile(tile_pos):
		print("Pending founding site: ", tile_pos)
	else:
		print(get_founding_tile_invalid_reason(tile_pos))
	queue_redraw()
	return true

func get_region_tile_at_position(mouse_pos: Vector2) -> Vector2i:
	if region_map_view != null:
		if is_over_region_panels(mouse_pos):
			return Vector2i(-1, -1)
		return region_map_view.screen_to_tile(mouse_pos)
	return Vector2i(int(floor(mouse_pos.x / TILE_SIZE)), int(floor(mouse_pos.y / TILE_SIZE)))

func is_valid_founding_tile(tile_pos: Vector2i) -> bool:
	if not FoundingSiteHelper.is_valid_founding_tile(tiles, cities, tile_pos, MIN_CITY_DISTANCE):
		return false
	return get_kingdom_holding_tile(tile_pos) == null

func get_founding_tile_invalid_reason(tile_pos: Vector2i) -> String:
	var reason: String = FoundingSiteHelper.get_founding_tile_invalid_reason(tiles, cities, tile_pos, MIN_CITY_DISTANCE)
	if reason == FoundingSiteHelper.VALID_FOUNDING_SITE:
		var kingdom: WorldMapData.Kingdom = get_kingdom_holding_tile(tile_pos)
		if kingdom != null:
			return FoundingSiteHelper.kingdom_land_reason(kingdom.name)
	return reason

func set_pending_founding_tile(tile_pos: Vector2i) -> bool:
	if not is_valid_founding_tile(tile_pos):
		return false
	if tile_pos != pending_founding_tile:
		survey_pending_site(tile_pos)
	pending_founding_tile = tile_pos
	return true

func survey_pending_site(tile_pos: Vector2i) -> void:
	var preview_city: City = City.new("Player Town", Vector2(tile_pos.x, tile_pos.y), City.ROLE_PLAYER, 0)
	pending_site_profile = SettlementSiteProfile.analyze(preview_city.tile, tiles, CITY_RESOURCE_RANGE)
	preview_city.site_profile = pending_site_profile
	var generator: LocalCityMapGenerator = make_local_map_generator()
	# The founded town will take the next city index, which the map generator uses.
	pending_local_map = generator.generate(preview_city, tiles, cities.size())
	pending_site_survey = SiteSurvey.get_lines(pending_local_map, pending_site_profile)

func clear_pending_founding_tile() -> void:
	pending_founding_tile = Vector2i(-1, -1)
	pending_site_profile = null
	pending_local_map = []
	pending_site_survey.clear()

func has_pending_founding_tile() -> bool:
	return is_inside_map(pending_founding_tile.x, pending_founding_tile.y)

func can_found_player_city() -> bool:
	if not has_pending_founding_tile():
		return false
	if has_player_city():
		return false
	return is_valid_founding_tile(pending_founding_tile)

func has_player_city() -> bool:
	return get_player_city_index() != -1

func get_player_city_index() -> int:
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		if city.is_player_city():
			return city_index
	return -1

func found_player_city_at_pending_site() -> bool:
	if not can_found_player_city():
		return false

	var founded_city: City = create_player_city_at_tile(pending_founding_tile)
	cities.append(founded_city)
	var founded_city_index: int = cities.size() - 1
	if not pending_local_map.is_empty():
		founded_city.site_profile = pending_site_profile
		founded_city.local_map = pending_local_map
	else:
		configure_new_city_map(founded_city, founded_city_index)
	clear_pending_founding_tile()
	generate_roads()
	notify_region_map_changed()
	if is_continuous_region_map():
		# The town's region is home now: the neighbourhood stays around it.
		entered_world_region_id = regional_terrain.region_id_at_tile(local_to_global_tile(Vector2i(founded_city.tile)))

	selected_city_index = founded_city_index
	current_view = VIEW_CITY
	hovered_tile = Vector2i(-1, -1)
	hovered_city_index = -1
	# A new town starts paused so the player can plan the first buildings before time runs.
	simulation_clock.pause()
	queue_redraw()
	return true

func create_player_city_at_tile(tile_pos: Vector2i) -> City:
	return City.new("Player Town", Vector2(tile_pos.x, tile_pos.y), City.ROLE_PLAYER, FOUNDING_HOUSEHOLD_COUNT, rng.randi())

func configure_new_city_map(city: City, city_index: int) -> void:
	city.site_profile = SettlementSiteProfile.analyze(city.tile, tiles, CITY_RESOURCE_RANGE)
	var generator: LocalCityMapGenerator = make_local_map_generator()
	city.local_map = generator.generate(city, tiles, city_index)

func get_city_index_at_position(mouse_pos: Vector2) -> int:
	if region_map_view != null and is_over_region_panels(mouse_pos):
		return -1
	var map_pos: Vector2 = region_screen_to_map(mouse_pos)
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		var tile_pos: Vector2 = city.tile
		var center: Vector2 = tile_to_center(tile_pos)

		if center.distance_to(map_pos) <= TILE_SIZE * 1.2:
			return city_index

	return -1

func try_handle_region_action_click(mouse_pos: Vector2) -> bool:
	for option_data: Dictionary in region_action_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		apply_region_action(option_data)
		return true

	if trade_menu.handle_menu_click(mouse_pos, cities):
		create_trade_route_from_menu_if_ready()
		return true

	return false

func try_handle_top_bar_click(mouse_pos: Vector2) -> bool:
	for option_data: Dictionary in top_bar_action_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		var action: String = option_data["action"] as String
		if action == "back_to_region":
			try_return_to_region(mouse_pos)
		elif action == "open_world_map":
			open_world_map()
		else:
			apply_time_control_action(action)
		return true

	return false

func apply_region_action(option_data: Dictionary):
	var action: String = option_data["action"] as String

	if action == "new_trade_route":
		trade_menu.open(cities)
	elif action == "found_player_city":
		found_player_city_at_pending_site()
	else:
		apply_time_control_action(action)

func try_handle_city_action_click(mouse_pos: Vector2) -> bool:
	for option_data: Dictionary in city_action_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		var action: String = option_data["action"] as String
		apply_time_control_action(action)
		return true

	return false

func try_handle_build_menu_click(mouse_pos: Vector2) -> bool:
	if not is_build_menu_open:
		return false
	if not get_build_menu_rect().has_point(mouse_pos):
		return false

	for option_data: Dictionary in build_menu_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		var building_id: String = option_data["building_id"] as String
		select_building_type(building_id)
		is_build_menu_open = false
		return true

	return true

func apply_time_control_action(action: String):
	if action == "toggle_pause":
		simulation_clock.toggle_pause()
	elif action == "speed_1x":
		simulation_clock.set_speed_by_index(0)
	elif action == "speed_3x":
		simulation_clock.set_speed_by_index(1)
	elif action == "speed_10x":
		simulation_clock.set_speed_by_index(2)

func handle_simulation_speed_key_event(key_event: InputEventKey) -> bool:
	if not key_event.pressed or key_event.echo:
		return false

	var keycode: int = key_event.keycode
	var physical_keycode: int = key_event.physical_keycode
	var unicode_value: int = key_event.unicode

	if keycode == KEY_SPACE or physical_keycode == KEY_SPACE:
		simulation_clock.toggle_pause()
	elif current_view == VIEW_CITY:
		return false
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_1, 49):
		simulation_clock.set_speed_by_index(0)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_2, 50):
		simulation_clock.set_speed_by_index(1)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_3, 51):
		simulation_clock.set_speed_by_index(2)
	else:
		return false

	queue_redraw()
	return true

func handle_region_trade_key_event(key_event: InputEventKey) -> bool:
	if current_view != VIEW_REGION:
		return false

	if trade_menu.handle_key_event(key_event, cities):
		queue_redraw()
		return true

	return false

func try_handle_trade_city_click(mouse_pos: Vector2):
	var city_index: int = get_city_index_at_position(mouse_pos)
	if city_index == -1:
		queue_redraw()
		return

	trade_menu.handle_city_selection(city_index, cities)

	queue_redraw()

func create_trade_route_from_menu_if_ready():
	if not trade_menu.has_pending_route():
		return

	var route_data: Dictionary = trade_menu.consume_pending_route_data()
	var source_index: int = int(route_data["source"])
	var destination_index: int = int(route_data["destination"])
	var resource_name: String = route_data["resource"] as String
	var amount: int = int(route_data["amount"])
	var route: TradeRoute = TradeRoute.new(trade_routes.size(), source_index, destination_index, resource_name, amount)
	trade_routes.append(route)

func try_return_to_region(_mouse_pos: Vector2):
	current_view = VIEW_REGION
	selected_city_index = -1
	# Buildings added in the town view show on the regional map.
	notify_region_map_changed()
	city_building_overlay.clear()
	city_hovered_tile = Vector2i(-1, -1)
	if household_debug_inspector != null:
		household_debug_inspector.visible = false
	queue_redraw()

func is_inside_city_map(x: int, y: int) -> bool:
	return x >= 0 and x < CITY_MAP_WIDTH and y >= 0 and y < CITY_MAP_HEIGHT

func is_inside_city_sidebar(mouse_pos: Vector2) -> bool:
	var sidebar_x: int = CITY_MAP_WIDTH * CITY_TILE_SIZE + CITY_SIDEBAR_MARGIN
	var sidebar_rect: Rect2 = Rect2(Vector2(sidebar_x, CITY_VIEW_TOP), Vector2(CITY_SIDEBAR_WIDTH, CITY_MAP_HEIGHT * CITY_TILE_SIZE))
	return sidebar_rect.has_point(mouse_pos)

func try_handle_building_click_at_tile(tile_pos: Vector2i, toggle_maintenance: bool) -> bool:
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return false
	if not is_inside_city_map(tile_pos.x, tile_pos.y):
		return false

	var city: City = cities[selected_city_index]
	if city_building_overlay.select_building_at_tile(city, tile_pos, toggle_maintenance):
		is_placing_building = false
		queue_redraw()
		return true

	return false

func try_handle_building_action_click(mouse_pos: Vector2) -> bool:
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return false
	var city: City = cities[selected_city_index]
	return city_building_overlay.handle_action_click(mouse_pos, city)

func clear_selected_household():
	city_building_overlay.clear()

func handle_clear_selection_key(key_event: InputEventKey) -> bool:
	if current_view != VIEW_CITY:
		return false
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_ESCAPE and key_event.physical_keycode != KEY_ESCAPE:
		return false

	is_placing_building = false
	is_build_menu_open = false
	clear_selected_household()
	queue_redraw()
	return true

func handle_build_menu_toggle_key_event(key_event: InputEventKey) -> bool:
	if current_view != VIEW_CITY:
		return false
	if not key_event.pressed or key_event.echo:
		return false
	if not is_letter_key(key_event.keycode, key_event.physical_keycode, KEY_B):
		return false

	is_build_menu_open = not is_build_menu_open
	queue_redraw()
	return true

func handle_building_selection_key_event(key_event: InputEventKey) -> bool:
	if current_view != VIEW_CITY:
		return false
	if not key_event.pressed or key_event.echo:
		return false

	var keycode: int = key_event.keycode
	var physical_keycode: int = key_event.physical_keycode
	var unicode_value: int = key_event.unicode

	if is_building_key(keycode, physical_keycode, unicode_value, KEY_1, 49):
		select_building_type(BUILDING_HOUSE)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_2, 50):
		select_building_type(BUILDING_FARM)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_3, 51):
		select_building_type(BUILDING_WOODCUTTER)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_4, 52):
		select_building_type(BUILDING_TOOLMAKER)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_5, 53):
		select_building_type(BUILDING_QUARRY)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_6, 54):
		select_building_type(BUILDING_STONECUTTER)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_7, 55):
		select_building_type(BUILDING_BRICKWORKS)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_8, 56):
		select_building_type(BUILDING_LIME_KILN)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_9, 57):
		select_building_type(BUILDING_MORTAR_YARD)
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_0, 48):
		select_building_type(BUILDING_MASON_YARD)
	elif is_letter_key(keycode, physical_keycode, KEY_Q):
		select_building_type(BUILDING_SCULPTOR)
	elif is_letter_key(keycode, physical_keycode, KEY_W):
		select_building_type(BUILDING_CARVER)
	elif is_letter_key(keycode, physical_keycode, KEY_E):
		select_building_type(BUILDING_TILEWORKS)
	elif is_letter_key(keycode, physical_keycode, KEY_R):
		select_building_type(BUILDING_PAVER_YARD)
	else:
		return false

	queue_redraw()
	return true

func select_building_type(building_type: String):
	selected_building_type = building_type
	is_placing_building = true
	clear_selected_household()

func is_building_key(keycode: int, physical_keycode: int, unicode_value: int, number_key: int, expected_unicode: int) -> bool:
	if keycode == number_key or physical_keycode == number_key:
		return true
	if unicode_value == expected_unicode:
		return true

	return false

func is_letter_key(keycode: int, physical_keycode: int, letter_key: int) -> bool:
	return keycode == letter_key or physical_keycode == letter_key

func try_place_selected_building():
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return
	if not is_inside_city_map(city_hovered_tile.x, city_hovered_tile.y):
		return

	var placement_result: Dictionary = get_building_placement_result(selected_city_index, selected_building_type, city_hovered_tile)
	if placement_result["is_valid"] != true:
		print("Cannot place ", selected_building_type, ": ", placement_result["message"])
		return

	var size: Vector2i = get_building_size(selected_building_type)
	var city: City = cities[selected_city_index]
	var local_map: Array = city.local_map
	var cost: Dictionary = building_placement.get_building_cost(selected_building_type)

	for y in range(city_hovered_tile.y, city_hovered_tile.y + size.y):
		for x in range(city_hovered_tile.x, city_hovered_tile.x + size.x):
			var tile: Dictionary = local_map[y][x] as Dictionary
			tile["occupied"] = true

	city.pay_cost(cost)
	var building: Building = Building.new(-1, selected_building_type, Vector2i(city_hovered_tile.x, city_hovered_tile.y), size)
	var household: Household = null
	city.add_building(building, household)
	queue_redraw()

func run_simulation_day():
	world_calendar.advance_day()

	for city: City in cities:
		if city.should_tick_simulation():
			city.tick()

	apply_trade_routes()
	for city: City in cities:
		if city.should_tick_simulation():
			city.record_resource_history()

	if current_view == VIEW_CITY:
		queue_redraw()

func on_calendar_month_changed(_calendar: Calendar):
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		if city.should_tick_simulation():
			city.advance_household_lifecycle_month(city_index)
	# Growing towns change size on the regional map; it is redrawn only while shown.
	if current_view == VIEW_REGION:
		notify_region_map_changed()

func on_calendar_season_changed(calendar: Calendar):
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		if city.should_tick_simulation():
			city.advance_household_birth_rolls_season(calendar, city_index)

	print("Season changed: ", calendar.get_current_season(), " - Year ", calendar.current_year)

func apply_trade_routes():
	for route: TradeRoute in trade_routes:
		var source_index: int = route.source_city_id
		var destination_index: int = route.destination_city_id

		if source_index < 0 or source_index >= cities.size():
			continue
		if destination_index < 0 or destination_index >= cities.size():
			continue

		var source_city: City = cities[source_index]
		var destination_city: City = cities[destination_index]
		if not source_city.is_controllable_city() or not destination_city.is_controllable_city():
			continue
		route.transfer_tick(source_city, destination_city)

func get_preferred_worker_for_building(building_type: String) -> String:
	building_type = BuildingTiers.get_base_type(building_type)
	if building_type == BUILDING_FARM:
		return WORK_PREF_AGRARIAN
	if building_type == BUILDING_WOODCUTTER or building_type == BUILDING_TOOLMAKER:
		return WORK_PREF_INDUSTRIAL

	return WORK_PREF_NEUTRAL

func is_valid_building_placement(city_index: int, building_type: String, origin: Vector2i) -> bool:
	var result: Dictionary = get_building_placement_result(city_index, building_type, origin)
	return result["is_valid"] == true

func get_building_placement_status(city_index: int, building_type: String, origin: Vector2i) -> String:
	var result: Dictionary = get_building_placement_result(city_index, building_type, origin)
	return result["message"] as String

func get_building_placement_result(city_index: int, building_type: String, origin: Vector2i) -> Dictionary:
	var city: City = cities[city_index]
	return building_placement.validate(city, city.local_map, building_type, origin)

func get_building_size(building_type: String) -> Vector2i:
	return building_placement.get_building_size(building_type)

func get_new_house_work_preference(building_type: String) -> String:
	if building_type != BUILDING_HOUSE:
		return WORK_PREF_NEUTRAL
	if rng.randi_range(0, 1) == 0:
		return WORK_PREF_AGRARIAN
	return WORK_PREF_INDUSTRIAL

func _ensure_household_debug_inspector() -> void:
	if household_debug_inspector != null:
		return

	var inspector_script: Script = preload("res://scripts/ui/household_debug_inspector.gd")
	household_debug_inspector = inspector_script.new() as Control
	add_child(household_debug_inspector)
	household_debug_inspector.visible = false
	household_debug_inspector.set_city(get_household_debug_city())

func get_inspected_household() -> Household:
	var city: City = get_household_debug_city()
	if city == null:
		return null
	var building_index: int = city_building_overlay.inspected_building_index
	if building_index < 0 or building_index >= city.buildings.size():
		return null
	if not city.buildings[building_index].is_house():
		return null
	return city.get_household_for_building_id(building_index)

func get_household_debug_city():
	if current_view != VIEW_CITY:
		return null
	if selected_city_index >= 0 and selected_city_index < cities.size():
		return cities[selected_city_index]

	return null

func _draw():
	if current_view == VIEW_WORLD:
		return
	if current_view == VIEW_CITY:
		draw_city_view()
		return

	if region_map_view != null:
		# The landscape, towns, and founding marks are drawn by region_map_view.
		sync_region_map_view()
		draw_trade_routes()
	else:
		for y in range(region_map_size.y):
			for x in range(region_map_size.x):
				draw_tile(x, y)

		draw_roads()
		draw_trade_routes()
		draw_fords()
		draw_cities()
		draw_pending_founding_site()
		draw_hover()
	draw_inspector_panel()
	draw_trade_menu_popup()
	draw_city_resource_tooltip()
	draw_top_bar()

func draw_tile(x: int, y: int):
	var pos: Vector2 = Vector2(x * TILE_SIZE, y * TILE_SIZE)
	var rect: Rect2 = Rect2(pos, Vector2(TILE_SIZE - 1, TILE_SIZE - 1))
	var tile: Dictionary = tiles[y][x] as Dictionary

	TerrainVisuals.draw_region_tile(self, rect, tile, Vector2i(x, y))

func draw_roads():
	for road: Array in roads:
		var path: Array = road
		for i in range(path.size() - 1):
			var start_tile: Vector2 = path[i] as Vector2
			var end_tile: Vector2 = path[i + 1] as Vector2
			var start_center: Vector2 = tile_to_center(start_tile)
			var end_center: Vector2 = tile_to_center(end_tile)
			MapElementVisuals.draw_road_segment(self, start_center, end_center)

func draw_trade_routes():
	for route: TradeRoute in trade_routes:
		if not route.active:
			continue

		var source_index: int = route.source_city_id
		var destination_index: int = route.destination_city_id
		if source_index < 0 or source_index >= cities.size():
			continue
		if destination_index < 0 or destination_index >= cities.size():
			continue

		var source_city: City = cities[source_index]
		var destination_city: City = cities[destination_index]
		var source_tile: Vector2 = source_city.tile
		var destination_tile: Vector2 = destination_city.tile
		var source_center: Vector2 = region_map_to_screen(tile_to_center(source_tile))
		var destination_center: Vector2 = region_map_to_screen(tile_to_center(destination_tile))

		MapElementVisuals.draw_trade_route(self, source_center, destination_center)

func draw_fords():
	for y in range(region_map_size.y):
		for x in range(region_map_size.x):
			if not tiles[y][x]["has_ford"]:
				continue

			var pos: Vector2 = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var tile_rect: Rect2 = Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
			MapElementVisuals.draw_ford(self, tile_rect)

func draw_cities():
	var font: Font = ThemeDB.fallback_font
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		var tile_pos: Vector2 = city.tile
		var center: Vector2 = tile_to_center(tile_pos)
		MapElementVisuals.draw_city_marker(self, center, TILE_SIZE, city_index == hovered_city_index, city_index == selected_city_index, city.role)
		draw_city_marker_label(font, city, center)

func draw_city_marker_label(font: Font, city: City, center: Vector2) -> void:
	var label: String = "Neutral"
	var color: Color = VisualStyle.COLOR_MUTED
	if city.is_player_city():
		label = "Player"
		color = VisualStyle.COLOR_UI_TITLE
	elif city.is_debug_city():
		label = "Debug"
		color = VisualStyle.COLOR_WARNING

	draw_string(font, center + Vector2(-22.0, TILE_SIZE * 1.55), label, HORIZONTAL_ALIGNMENT_CENTER, 44.0, 11, color)

func draw_pending_founding_site():
	if not has_pending_founding_tile():
		return

	var marker_pos: Vector2 = Vector2(pending_founding_tile.x * TILE_SIZE, pending_founding_tile.y * TILE_SIZE)
	var marker_rect: Rect2 = Rect2(marker_pos, Vector2(TILE_SIZE, TILE_SIZE))
	MapElementVisuals.draw_founding_site_marker(self, marker_rect)

func draw_top_bar():
	top_bar_action_options.clear()

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var title_size: int = 16
	var viewport_width: float = max(1100.0, get_viewport_rect().size.x)
	var bar_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport_width, TOP_BAR_HEIGHT))
	var x: float = 12.0
	var y: float = 26.0

	draw_rect(bar_rect, VisualStyle.COLOR_UI_PANEL_BACKGROUND)
	draw_rect(Rect2(Vector2(0.0, TOP_BAR_HEIGHT - 2.0), Vector2(viewport_width, 2.0)), VisualStyle.COLOR_UI_PANEL_BORDER)

	if current_view == VIEW_CITY:
		x = draw_top_bar_button(font, font_size, "Back", x, y, 78.0, {"action": "back_to_region"}, VisualStyle.COLOR_UI_BUTTON_BACKGROUND)
		x += 14.0
	elif world_map_view != null:
		x = draw_top_bar_button(font, font_size, "World", x, y, 78.0, {"action": "open_world_map"}, VisualStyle.COLOR_UI_BUTTON_BACKGROUND)
		x += 14.0

	draw_string(font, Vector2(x, y), get_top_bar_title(), HORIZONTAL_ALIGNMENT_LEFT, 230.0, title_size, VisualStyle.COLOR_UI_TITLE)
	x += 250.0
	draw_string(font, Vector2(x, y), world_calendar.get_formatted_date(), HORIZONTAL_ALIGNMENT_LEFT, 330.0, font_size, VisualStyle.COLOR_POPULATION_LABOR)
	x += 350.0
	draw_string(font, Vector2(x, y), "Speed: " + simulation_clock.get_speed_label(), HORIZONTAL_ALIGNMENT_LEFT, 105.0, font_size, VisualStyle.COLOR_POPULATION_LABOR)
	x += 118.0

	x = draw_top_bar_button(font, font_size, "Pause", x, y, 60.0, {"action": "toggle_pause"}, get_time_control_color("Paused"))
	x = draw_top_bar_button(font, font_size, "1x", x, y, 42.0, {"action": "speed_1x"}, get_time_control_color("1x"))
	x = draw_top_bar_button(font, font_size, "3x", x, y, 42.0, {"action": "speed_3x"}, get_time_control_color("3x"))
	draw_top_bar_button(font, font_size, "10x", x, y, 48.0, {"action": "speed_10x"}, get_time_control_color("10x"))

func get_top_bar_title() -> String:
	if current_view == VIEW_CITY:
		return get_selected_city_name() + " Local Map"
	if world_map_data != null and (entered_world_region_id >= 0 or is_continuous_region_map()):
		var region: WorldMapData.Region = get_region_in_view()
		if region != null:
			return region.name

	return "Regional Map"

func draw_top_bar_button(font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color) -> float:
	var button_rect: Rect2 = Rect2(Vector2(x, y - 17.0), Vector2(width, 24.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = button_rect
	top_bar_action_options.append(stored_option)

	draw_rect(button_rect, color)
	draw_rect(button_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	draw_string(font, Vector2(x + 7.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, width - 14.0, font_size, VisualStyle.COLOR_UI_TEXT)
	return x + width + 6.0

func draw_city_view():
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14

	draw_rect(Rect2(Vector2.ZERO, Vector2(1100, 650)), VisualStyle.COLOR_UI_BACKGROUND)
	draw_city_sidebar(font, font_size)

	if selected_city_index < 0 or selected_city_index >= cities.size():
		draw_string(font, Vector2(24, 82), "No city map selected.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, VisualStyle.COLOR_UI_TEXT)
		draw_top_bar()
		return

	var local_map: Array = cities[selected_city_index].local_map
	for y in range(CITY_MAP_HEIGHT):
		for x in range(CITY_MAP_WIDTH):
			draw_city_tile(local_map, x, y)

	draw_city_buildings()
	draw_city_walkers()
	draw_building_preview()
	draw_building_overlay(font, font_size)
	draw_build_menu(font, font_size)
	draw_top_bar()

func get_placement_status_message() -> String:
	if not is_placing_building:
		return "Placement off"

	var message: String = "Move over the city map to place."

	if selected_city_index >= 0 and selected_city_index < cities.size() and is_inside_city_map(city_hovered_tile.x, city_hovered_tile.y):
		message = get_building_placement_status(selected_city_index, selected_building_type, city_hovered_tile)

	return message

func draw_city_sidebar(font: Font, font_size: int):
	city_action_options.clear()

	var sidebar_x: int = CITY_MAP_WIDTH * CITY_TILE_SIZE + CITY_SIDEBAR_MARGIN
	var sidebar_pos: Vector2 = Vector2(sidebar_x, CITY_VIEW_TOP)
	var sidebar_size: Vector2 = Vector2(CITY_SIDEBAR_WIDTH, CITY_MAP_HEIGHT * CITY_TILE_SIZE)
	var sidebar_rect: Rect2 = Rect2(sidebar_pos, sidebar_size)
	var text_x: float = sidebar_pos.x + CITY_SIDEBAR_PADDING
	var y: float = sidebar_pos.y + 18.0
	var title_size: int = 16

	draw_rect(sidebar_rect, VisualStyle.COLOR_UI_PANEL_BACKGROUND)
	draw_rect(sidebar_rect, VisualStyle.COLOR_UI_PANEL_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	draw_string(font, Vector2(text_x, y), "City Overview", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 22.0

	if selected_city_index < 0 or selected_city_index >= cities.size():
		return

	var city: City = cities[selected_city_index]
	var resources: Dictionary = city.resources
	var placement_status: String = get_placement_status_message()
	var pressure_summary: Dictionary = city.get_pressure_summary()
	var need_pressure_summary: Dictionary = city.get_need_pressure_summary()
	var placement_color: Color = VisualStyle.COLOR_MUTED
	if placement_status == "Valid placement":
		placement_color = VisualStyle.COLOR_POSITIVE
	elif placement_status != "Move over the city map to place." and placement_status != "Placement off":
		placement_color = VisualStyle.COLOR_WARNING

	y = draw_sidebar_section_title(font, "City Health", text_x, y)
	y = draw_pressure_row(font, font_size, "Food", pressure_summary["food"] as Dictionary, text_x, y)
	y = draw_pressure_row(font, font_size, "Shelter", pressure_summary["shelter"] as Dictionary, text_x, y)
	y = draw_pressure_row(font, font_size, "Labor", pressure_summary["labor"] as Dictionary, text_x, y)
	y = draw_pressure_row(font, font_size, "Tools", pressure_summary["tools"] as Dictionary, text_x, y)
	y = draw_pressure_row(font, font_size, "Maintenance", pressure_summary["maintenance"] as Dictionary, text_x, y)
	y += 4.0

	y = draw_sidebar_section_title(font, "Need Pressure", text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["food"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["household_goods"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["clothing"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["tools"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["construction_materials"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["maintenance_materials"] as Dictionary, text_x, y)
	y = draw_need_pressure_row(font, font_size, need_pressure_summary["civic_goods"] as Dictionary, text_x, y)
	y += 4.0

	y = draw_sidebar_section_title(font, "Action Hints", text_x, y)
	var action_hint_lines: Array[String] = CityPressureHintHelper.get_hints(pressure_summary, resources, need_pressure_summary)
	for action_hint: String in action_hint_lines:
		y = draw_sidebar_line(font, font_size, action_hint, text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y += 4.0

	y = draw_sidebar_section_title(font, "Resources", text_x, y)
	y = draw_sidebar_label_value(font, font_size, "Food", str(resources["food"]) + "  use " + str(resources["food_consumption_rate"]) + "/tick", text_x, y, VisualStyle.COLOR_RESOURCE_FOOD)
	y = draw_sidebar_label_value(font, font_size, "Wood", str(resources["wood"]), text_x, y, VisualStyle.COLOR_RESOURCE_WOOD)
	y = draw_sidebar_label_value(font, font_size, "Tools", str(resources["tools"]), text_x, y, VisualStyle.COLOR_RESOURCE_TOOLS)
	y += 4.0

	y = draw_sidebar_section_title(font, "Population", text_x, y)
	y = draw_sidebar_label_value(font, font_size, "People", str(resources["total_population"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Households", str(resources["household_count"]) + "  A/I " + get_house_preference_count_text(city), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Shelter", str(resources["housing_capacity"]) + " total", text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Housed", str(resources["housed_population"]) + " / " + str(resources["house_shelter_capacity"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Temporary", str(resources["temporary_sheltered_population"]) + " / " + str(resources["temporary_shelter_capacity"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	if int(resources["unsheltered_population"]) > 0:
		y = draw_sidebar_label_value(font, font_size, "Unsheltered", str(resources["unsheltered_population"]), text_x, y, VisualStyle.COLOR_WARNING)
	y = draw_sidebar_label_value(font, font_size, "Newcomers", HouseholdMigration.get_arrival_blocker_text(HouseholdMigration.get_arrival_blocker(city)), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	if int(resources["households_considering_departure"]) > 0:
		y = draw_sidebar_label_value(font, font_size, "Leaving?", str(resources["households_considering_departure"]) + " families", text_x, y, VisualStyle.COLOR_WARNING)
	y = draw_sidebar_label_value(font, font_size, "Labor", str(resources["assigned_workers"]) + " / " + str(resources["total_labor_capacity"]) + " used", text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Idle", str(resources["idle_workers"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y += 4.0

	y = draw_sidebar_section_title(font, "Selected Object", text_x, y)
	y = draw_selected_object_summary(font, font_size, city, text_x, y)
	y += 4.0

	y = draw_sidebar_section_title(font, "Build Controls", text_x, y)
	if is_placing_building:
		y = draw_sidebar_label_value(font, font_size, "Building", get_building_display_name(selected_building_type), text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
		y = draw_sidebar_label_value(font, font_size, "Cost", building_placement.get_cost_text(building_placement.get_building_cost(selected_building_type)), text_x, y, VisualStyle.COLOR_MUTED)
	else:
		y = draw_sidebar_label_value(font, font_size, "Building", "none", text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_sidebar_line(font, font_size, "1 house, 2 farm, 3 woodcutter", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "4 toolmaker, 5 quarry, 6 stonecutter", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "7 brickworks, 8 lime, 9 mortar", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "0 mason, Q sculptor, W carver", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "E tileworks, R paver yard", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "B: build menu, Right click/Esc: clear", text_x, y, VisualStyle.COLOR_MUTED)
	if int(resources["maintenance_grace_ticks"]) > 0:
		y = draw_sidebar_line(font, font_size, "Grace: " + str(resources["maintenance_grace_ticks"]) + " ticks", text_x, y, VisualStyle.COLOR_MUTED)
	y += 4.0
	draw_sidebar_line(font, font_size, placement_status, text_x, y, placement_color)

func get_build_menu_rect() -> Rect2:
	return Rect2(Vector2(16.0, CITY_VIEW_TOP + 16.0), Vector2(330.0, 460.0))

func draw_build_menu(font: Font, font_size: int):
	build_menu_options.clear()
	if not is_build_menu_open:
		return

	var menu_rect: Rect2 = get_build_menu_rect()
	var text_x: float = menu_rect.position.x + 12.0
	var y: float = menu_rect.position.y + 24.0
	var current_category: String = ""

	draw_rect(menu_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	draw_rect(menu_rect, VisualStyle.COLOR_UI_OVERLAY_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	draw_string(font, Vector2(text_x, y), "Build Menu", HORIZONTAL_ALIGNMENT_LEFT, menu_rect.size.x - 24.0, 16, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 24.0

	for building_data: Dictionary in BuildMenuHelper.get_building_catalog():
		var category: String = str(building_data["category"])
		if category != current_category:
			current_category = category
			draw_string(font, Vector2(text_x, y), category, HORIZONTAL_ALIGNMENT_LEFT, menu_rect.size.x - 24.0, max(10, font_size - 1), VisualStyle.COLOR_MUTED)
			y += 17.0

		var building_id: String = str(building_data["id"])
		var display_name: String = str(building_data["display_name"])
		var option_rect: Rect2 = Rect2(Vector2(text_x, y - 13.0), Vector2(menu_rect.size.x - 24.0, 19.0))
		var option_color: Color = VisualStyle.COLOR_UI_BUTTON_DISABLED
		var label_color: Color = VisualStyle.COLOR_UI_TEXT
		if building_id == selected_building_type and is_placing_building:
			option_color = VisualStyle.COLOR_UI_BUTTON_ACTIVE
			label_color = VisualStyle.COLOR_UI_TITLE

		var cost_text: String = building_placement.get_cost_text(building_placement.get_building_cost(building_id))
		var label: String = display_name + "  " + cost_text
		var stored_option: Dictionary = {"rect": option_rect, "building_id": building_id}
		build_menu_options.append(stored_option)

		draw_rect(option_rect, option_color)
		draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
		draw_string(font, Vector2(text_x + 5.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, menu_rect.size.x - 34.0, font_size, label_color)
		y += 22.0

func draw_sidebar_section_title(font: Font, text: String, x: float, y: float) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, VisualStyle.COLOR_UI_SECTION_HEADER)
	return y + 17.0

func draw_sidebar_line(font: Font, font_size: int, text: String, x: float, y: float, color: Color) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, CITY_SIDEBAR_WIDTH - CITY_SIDEBAR_PADDING * 2, font_size, color)
	return y + 15.0

func draw_sidebar_label_value(font: Font, font_size: int, label: String, value: String, x: float, y: float, color: Color) -> float:
	draw_string(font, Vector2(x, y), label + ":", HORIZONTAL_ALIGNMENT_LEFT, 86.0, font_size, VisualStyle.COLOR_MUTED)
	draw_string(font, Vector2(x + 88.0, y), value, HORIZONTAL_ALIGNMENT_LEFT, CITY_SIDEBAR_WIDTH - CITY_SIDEBAR_PADDING * 2 - 88.0, font_size, color)
	return y + 15.0

func get_building_display_name(building_type: String) -> String:
	if BuildingTiers.is_tier0(building_type):
		return BuildingTiers.get_display_name(building_type)
	if building_type == BUILDING_HOUSE:
		return "House"
	if building_type == BUILDING_FARM:
		return "Farm"
	if building_type == BUILDING_WOODCUTTER:
		return "Woodcutter"
	if building_type == BUILDING_TOOLMAKER:
		return "Toolmaker"
	if building_type == BUILDING_QUARRY:
		return "Quarry"
	if building_type == BUILDING_STONECUTTER:
		return "Stonecutter"
	if building_type == BUILDING_BRICKWORKS:
		return "Brickworks"
	if building_type == BUILDING_LIME_KILN:
		return "Lime Kiln"
	if building_type == BUILDING_MORTAR_YARD:
		return "Mortar Yard"
	if building_type == BUILDING_MASON_YARD:
		return "Mason Yard"
	if building_type == BUILDING_SCULPTOR:
		return "Sculptor"
	if building_type == BUILDING_CARVER:
		return "Carver"
	if building_type == BUILDING_TILEWORKS:
		return "Tileworks"
	if building_type == BUILDING_PAVER_YARD:
		return "Paver Yard"

	return building_type

func draw_pressure_row(font: Font, font_size: int, label: String, pressure: Dictionary, x: float, y: float) -> float:
	var status: String = pressure["status"] as String
	var severity: String = pressure["severity"] as String
	var detail: String = pressure["detail"] as String
	y = draw_sidebar_label_value(font, font_size, label, status, x, y, get_pressure_color(severity))
	if not detail.is_empty():
		y = draw_sidebar_detail_line(font, font_size, detail, x + 12.0, y - 1.0)

	return y

func draw_need_pressure_row(font: Font, font_size: int, need_pressure: Dictionary, x: float, y: float) -> float:
	var label: String = get_need_pressure_display_label(need_pressure)
	var status: String = str(need_pressure.get("status", "not_implemented"))
	var severity: String = str(need_pressure.get("severity", "neutral"))
	var available: int = int(need_pressure.get("available", 0))
	var demand: int = int(need_pressure.get("demand", 0))
	var active: bool = bool(need_pressure.get("active", false))

	if active:
		y = draw_sidebar_line(font, font_size, label + ": " + format_need_status_label(status), x, y, get_pressure_color(severity))
		return draw_sidebar_detail_line(font, font_size, str(available) + " available / " + str(demand) + " demand", x + 12.0, y - 1.0)

	var value_text: String = str(available) + " available, not active"
	return draw_sidebar_label_value(font, font_size, label, value_text, x, y, get_pressure_color(severity))

func get_need_pressure_display_label(need_pressure: Dictionary) -> String:
	var bucket: String = str(need_pressure.get("bucket", ""))
	var active: bool = bool(need_pressure.get("active", false))
	if active:
		return str(need_pressure.get("display_name", "Need"))
	if bucket == "construction_materials":
		return "Construct."
	if bucket == "maintenance_materials":
		return "Maint."
	if bucket == "civic_goods":
		return "Civic"

	return str(need_pressure.get("display_name", "Need"))

func format_need_status_label(status: String) -> String:
	var words: PackedStringArray = status.replace("_", " ").split(" ")
	for index in range(words.size()):
		if words[index].length() > 0:
			words[index] = words[index].substr(0, 1).to_upper() + words[index].substr(1).to_lower()

	return " ".join(words)

func get_pressure_color(severity: String) -> Color:
	if severity == "positive":
		return VisualStyle.COLOR_POSITIVE
	if severity == "warning":
		return VisualStyle.COLOR_MAINTENANCE_WARNING
	if severity == "danger":
		return VisualStyle.COLOR_WARNING

	return VisualStyle.COLOR_UI_TEXT_NORMAL

func draw_sidebar_detail_line(font: Font, font_size: int, text: String, x: float, y: float) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, CITY_SIDEBAR_WIDTH - CITY_SIDEBAR_PADDING * 2 - 12.0, max(10, font_size - 2), VisualStyle.COLOR_MUTED)
	return y + 12.0

func get_house_preference_count_text(city: City) -> String:
	var counts: Dictionary = city.get_household_counts_by_preference()
	var agrarian_houses: int = int(counts[WORK_PREF_AGRARIAN])
	var industrial_houses: int = int(counts[WORK_PREF_INDUSTRIAL])
	return str(agrarian_houses) + "/" + str(industrial_houses)

func draw_selected_object_summary(font: Font, font_size: int, city: City, x: float, y: float) -> float:
	var building_index: int = city_building_overlay.inspected_building_index
	if building_index < 0 or building_index >= city.buildings.size():
		return draw_sidebar_line(font, font_size, "None selected.", x, y, VisualStyle.COLOR_MUTED)

	var building: Building = city.buildings[building_index]
	y = draw_sidebar_label_value(font, font_size, "Type", city_building_overlay.get_building_label(city, building_index), x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)

	if building.is_house():
		var household: Household = city.get_household_for_building_id(building_index)
		if household == null:
			y = draw_sidebar_label_value(font, font_size, "Resident", "empty", x, y, VisualStyle.COLOR_MUTED)
		else:
			y = draw_sidebar_label_value(font, font_size, "Resident", city.get_household_label(household.id), x, y, VisualStyle.COLOR_POPULATION_LABOR)
			if household.has_values():
				y = draw_sidebar_label_value(font, font_size, "Calling", get_household_calling_text(household), x, y, VisualStyle.get_preference_color(household.preference))
				y = draw_sidebar_label_value(font, font_size, "Defining", get_household_defining_text(city, household), x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
				if HouseholdMigration.is_considering_departure(household):
					y = draw_sidebar_label_value(font, font_size, "Hardship", "thinking of leaving", x, y, VisualStyle.COLOR_WARNING)
			else:
				y = draw_sidebar_label_value(font, font_size, "Preference", household.preference, x, y, VisualStyle.get_preference_color(household.preference))
	else:
		y = draw_sidebar_label_value(font, font_size, "Worker", get_selected_building_worker_summary(city, building), x, y, VisualStyle.COLOR_POPULATION_LABOR)
		y = draw_sidebar_label_value(font, font_size, "Upkeep", str(building.maintenance_level) + "%", x, y, get_maintenance_summary_color(building))
	# Display selected building action hints
	var selected_building_hint_lines := SelectedBuildingActionHintHelper.get_hints(building, city)
	if selected_building_hint_lines.size() > 0:
		y = draw_sidebar_section_title(font, "Selected Building Hints", x, y)
		for hint_text in selected_building_hint_lines:
			y = draw_sidebar_line(font, font_size, hint_text, x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
	var household_link_lines: Array[String] = HouseholdHomeWorkLinkHelper.get_links(city, building_index)
	if household_link_lines.size() > 0:
		y = draw_sidebar_section_title(font, "Household Links", x, y)
		for household_link_text: String in household_link_lines:
			y = draw_sidebar_line(font, font_size, household_link_text, x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)

	return y

func get_household_calling_text(household: Household) -> String:
	var names: Array[String] = []
	for calling in household.values.get(CultureValues.CATEGORY_CALLING, []):
		names.append(CultureValues.get_display_name(calling))
	return ", ".join(names)

func get_household_defining_text(city: City, household: Household) -> String:
	var names: Array[String] = []
	for value_id: String in city.get_household_defining_values(household):
		names.append(CultureValues.get_display_name(value_id))
	return ", ".join(names)

func get_selected_building_worker_summary(city: City, building: Building) -> String:
	if building.assigned_workers <= 0:
		return "unassigned"

	var household: Household = city.get_household_by_id(building.assigned_household_id)
	if household == null:
		return "starter neutral"

	return city.get_household_label(household.id) + " (" + household.preference + ")"

func get_maintenance_summary_color(building: Building) -> Color:
	if not building.receives_maintenance:
		return VisualStyle.COLOR_MAINTENANCE_DISABLED
	if building.maintenance_level < 50:
		return VisualStyle.COLOR_MAINTENANCE_BAD
	if building.maintenance_level < 75:
		return VisualStyle.COLOR_MAINTENANCE_WARNING

	return VisualStyle.COLOR_MAINTENANCE_GOOD

func draw_house_preference_counts(font: Font, font_size: int, x: float, y: float) -> float:
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return y

	var counts: Dictionary = cities[selected_city_index].get_household_counts_by_preference()
	var agrarian_houses: int = int(counts[WORK_PREF_AGRARIAN])
	var industrial_houses: int = int(counts[WORK_PREF_INDUSTRIAL])

	y = draw_sidebar_line(font, font_size, "Household prefs: A " + str(agrarian_houses) + " / I " + str(industrial_houses), x, y, VisualStyle.COLOR_POPULATION_LABOR)
	return y

func draw_building_overlay(font: Font, font_size: int):
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return
	var city: City = cities[selected_city_index]
	city_building_overlay.draw(self, font, font_size, city)

func count_maintenance_needed_buildings(city_index: int) -> int:
	var count: int = 0
	if city_index < 0 or city_index >= cities.size():
		return count

	var buildings: Array = cities[city_index].buildings
	for building: Building in buildings:
		if building.is_production_building() and building.maintenance_level < 100:
			count += 1

	return count

func draw_city_tile(local_map: Array, x: int, y: int):
	var tile: Dictionary = local_map[y][x] as Dictionary
	var pos: Vector2 = Vector2(x * CITY_TILE_SIZE, CITY_VIEW_TOP + y * CITY_TILE_SIZE)
	var rect: Rect2 = Rect2(pos, Vector2(CITY_TILE_SIZE - 1, CITY_TILE_SIZE - 1))

	TerrainVisuals.draw_city_tile(self, rect, tile, Vector2i(x, y))

func draw_city_buildings():
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return

	var buildings: Array = cities[selected_city_index].buildings
	for building_index in range(buildings.size()):
		var building: Building = buildings[building_index]
		var tile_pos: Vector2i = building.tile
		var size: Vector2i = building.size
		var building_type: String = building.type
		var pos: Vector2 = Vector2(tile_pos.x * CITY_TILE_SIZE, CITY_VIEW_TOP + tile_pos.y * CITY_TILE_SIZE)
		var rect: Rect2 = Rect2(pos, Vector2(size.x * CITY_TILE_SIZE - 1, size.y * CITY_TILE_SIZE - 1))
		var maintenance_level: int = building.maintenance_level

		BuildingVisuals.draw_building(self, rect, building_type)
		if city_building_overlay.is_inspected(building_index):
			draw_rect(rect, VisualStyle.COLOR_BUILDING_SELECTED)
		elif city_building_overlay.is_selected_house(building_index):
			draw_rect(rect, VisualStyle.COLOR_BUILDING_SELECTED)
		if building_type == BUILDING_HOUSE:
			draw_house_preference_indicator(rect, cities[selected_city_index].get_household_preference_for_building(building_index))
		if building_type != BUILDING_HOUSE and maintenance_level < 100:
			var decay_alpha: float = 0.55 * (1.0 - float(maintenance_level) / 100.0)
			draw_rect(rect, Color(0.20, 0.20, 0.20, decay_alpha))
		elif building_type != BUILDING_HOUSE and building.assigned_workers == 0:
			draw_rect(rect, VisualStyle.COLOR_UNASSIGNED_BUILDING)
		draw_worker_indicator(rect, building_type, building.assigned_workers, building.assigned_preference)
		draw_maintenance_indicator(rect, building_type, maintenance_level, building.receives_maintenance)

	draw_household_work_link_overlay()

func draw_household_work_link_overlay():
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return

	var city: City = cities[selected_city_index]
	var selected_building_index: int = city_building_overlay.inspected_building_index
	if selected_building_index < 0 or selected_building_index >= city.buildings.size():
		return

	var related_building_indices: Array[int] = HouseholdHomeWorkLinkHelper.get_related_building_indices(city, selected_building_index)
	if related_building_indices.is_empty():
		return

	var selected_building: Building = city.buildings[selected_building_index]
	var start_pos: Vector2 = get_building_screen_center(selected_building)
	var link_shadow: Color = Color(0.05, 0.05, 0.05, 0.8)
	var link_color: Color = Color(0.95, 0.82, 0.28, 0.95)

	for related_building_index: int in related_building_indices:
		if related_building_index < 0 or related_building_index >= city.buildings.size():
			continue

		var related_building: Building = city.buildings[related_building_index]
		var end_pos: Vector2 = get_building_screen_center(related_building)
		draw_line(start_pos + Vector2(1, 1), end_pos + Vector2(1, 1), link_shadow, 4.0)
		draw_line(start_pos, end_pos, link_color, 2.0)
		draw_circle(start_pos, 4.0, link_color)
		draw_circle(end_pos, 5.0, link_color)

func draw_city_walkers():
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return

	var city: City = cities[selected_city_index]
	var buildings: Array[Building] = city.buildings

	for building_index in range(buildings.size()):
		var workplace: Building = buildings[building_index]
		if not workplace.is_production_building():
			continue
		if workplace.assigned_workers <= 0:
			continue
		if workplace.assigned_household_id < 0:
			continue

		var house_index: int = city.get_assigned_house_building_id(workplace)
		var home_pos: Vector2 = get_household_home_position(city, house_index, workplace.assigned_household_id)
		var work_pos: Vector2 = get_building_screen_center(workplace)
		var preference: String = city.get_household_preference_for_worker_modifier(workplace)
		var walker_count: int = workplace.assigned_workers

		for walker_index in range(walker_count):
			var walker_key: int = workplace.assigned_household_id * 10 + building_index
			var walker_pos: Vector2 = get_walker_position(home_pos, work_pos, walker_index, walker_key)
			draw_circle(walker_pos + Vector2(0.8, 0.8), 3.1, VisualStyle.COLOR_WALKER_SHADOW)
			draw_circle(walker_pos, 2.6, get_walker_color(preference))

func get_building_screen_center(building: Building) -> Vector2:
	var tile_pos: Vector2i = building.tile
	var size: Vector2i = building.size
	var center_x: float = (float(tile_pos.x) + float(size.x) * 0.5) * float(CITY_TILE_SIZE)
	var center_y: float = float(CITY_VIEW_TOP) + (float(tile_pos.y) + float(size.y) * 0.5) * float(CITY_TILE_SIZE)
	return Vector2(center_x, center_y)

func get_household_home_position(city: City, house_index: int, household_id: int) -> Vector2:
	var buildings: Array[Building] = city.buildings
	if house_index >= 0 and house_index < buildings.size():
		var house: Building = buildings[house_index]
		return get_building_screen_center(house)

	var lane: int = max(0, household_id)
	var camp_x: float = float(CITY_TILE_SIZE * 4) + float((lane % 4) * CITY_TILE_SIZE)
	var camp_y: float = float(CITY_VIEW_TOP + CITY_TILE_SIZE * 4) + float((lane / 4) * CITY_TILE_SIZE)
	return Vector2(camp_x, camp_y)

func get_walker_position(home_pos: Vector2, work_pos: Vector2, walker_index: int, household_id: int) -> Vector2:
	var cycle_progress: float = city_walker_time / CITY_WALKER_CYCLE_SECONDS
	var travel_progress: float = 0.0
	if cycle_progress < 0.5:
		travel_progress = cycle_progress * 2.0
	else:
		travel_progress = 1.0 - ((cycle_progress - 0.5) * 2.0)

	var position: Vector2 = home_pos.lerp(work_pos, travel_progress)
	var direction: Vector2 = work_pos - home_pos
	if direction.length() > 0.1:
		var unit_direction: Vector2 = direction.normalized()
		var side_direction: Vector2 = Vector2(-unit_direction.y, unit_direction.x)
		var lane_offset: float = (float(walker_index) - 0.5) * 4.0
		var walking_bob: float = sin(city_walker_time * 5.0 + float(household_id + walker_index)) * 1.1
		position += side_direction * (lane_offset + walking_bob)

	return position

func get_walker_color(preference: String) -> Color:
	if preference == WORK_PREF_AGRARIAN:
		return VisualStyle.COLOR_WALKER_AGRARIAN
	if preference == WORK_PREF_INDUSTRIAL:
		return VisualStyle.COLOR_WALKER_INDUSTRIAL

	return VisualStyle.COLOR_WALKER_NEUTRAL

func draw_worker_indicator(rect: Rect2, building_type: String, assigned_workers: int, assigned_preference: String):
	if building_type == BUILDING_HOUSE:
		return

	var indicator_color: Color = VisualStyle.COLOR_WARNING
	if assigned_workers > 0:
		indicator_color = get_preference_color(assigned_preference)

	draw_circle(rect.position + Vector2(rect.size.x - 5, 5), 3.0, indicator_color)

func draw_house_preference_indicator(rect: Rect2, preference: String):
	var color: Color = get_preference_color(preference)
	var stripe_rect: Rect2 = Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 4))
	draw_rect(stripe_rect, color)

func get_preference_color(preference: String) -> Color:
	if preference == WORK_PREF_AGRARIAN:
		return VisualStyle.COLOR_PREF_AGRARIAN
	if preference == WORK_PREF_INDUSTRIAL:
		return VisualStyle.COLOR_PREF_INDUSTRIAL

	return VisualStyle.COLOR_PREF_NEUTRAL

func draw_maintenance_indicator(rect: Rect2, building_type: String, maintenance_level: int, receives_maintenance: bool):
	if building_type == BUILDING_HOUSE:
		return

	var bar_width: float = rect.size.x - 4.0
	var filled_width: float = bar_width * float(maintenance_level) / 100.0
	var bar_pos: Vector2 = rect.position + Vector2(2, rect.size.y - 5)
	var bar_color: Color = VisualStyle.COLOR_MAINTENANCE_GOOD
	if maintenance_level < 75:
		bar_color = VisualStyle.COLOR_MAINTENANCE_WARNING
	if maintenance_level < 50:
		bar_color = VisualStyle.COLOR_MAINTENANCE_BAD
	if not receives_maintenance:
		bar_color = VisualStyle.COLOR_MAINTENANCE_DISABLED

	draw_rect(Rect2(bar_pos, Vector2(bar_width, 3)), VisualStyle.COLOR_MAINTENANCE_BAR_BACKGROUND)
	draw_rect(Rect2(bar_pos, Vector2(filled_width, 3)), bar_color)

func draw_building_preview():
	if not is_placing_building:
		return
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return
	if not is_inside_city_map(city_hovered_tile.x, city_hovered_tile.y):
		return

	var size: Vector2i = get_building_size(selected_building_type)
	var is_valid: bool = is_valid_building_placement(selected_city_index, selected_building_type, city_hovered_tile)
	var color: Color = VisualStyle.COLOR_VALID_PLACEMENT
	if not is_valid:
		color = VisualStyle.COLOR_INVALID_PLACEMENT

	var pos: Vector2 = Vector2(city_hovered_tile.x * CITY_TILE_SIZE, CITY_VIEW_TOP + city_hovered_tile.y * CITY_TILE_SIZE)
	var rect: Rect2 = Rect2(pos, Vector2(size.x * CITY_TILE_SIZE, size.y * CITY_TILE_SIZE))
	draw_rect(rect, color)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.95), false, 2.0)

func get_building_color(building_type: String) -> Color:
	return VisualStyle.get_building_color(building_type)

func get_selected_city_name() -> String:
	if selected_city_index < 0 or selected_city_index >= cities.size():
		return "City"

	var city: City = cities[selected_city_index]
	return city.name

func draw_hover():
	if not is_inside_map(hovered_tile.x, hovered_tile.y):
		return

	var hover_pos: Vector2 = Vector2(hovered_tile.x * TILE_SIZE, hovered_tile.y * TILE_SIZE)
	var hover_rect: Rect2 = Rect2(hover_pos, Vector2(TILE_SIZE, TILE_SIZE))
	MapElementVisuals.draw_tile_hover_outline(self, hover_rect)

func draw_inspector_panel():
	region_action_options.clear()

	var panel_rect: Rect2 = get_region_inspector_rect()
	var panel_pos: Vector2 = panel_rect.position
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var title_size: int = 16
	var text_pos: Vector2 = panel_pos + Vector2(PANEL_PADDING, PANEL_PADDING + 18)

	# This is a drawn inspector area, not a UI panel node yet.
	draw_rect(panel_rect, VisualStyle.COLOR_UI_PANEL_BACKGROUND)
	draw_rect(panel_rect, VisualStyle.COLOR_UI_PANEL_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	draw_string(font, text_pos, "Region Inspector", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, VisualStyle.COLOR_UI_SECTION_HEADER)

	var y: float = text_pos.y + 32.0
	y = draw_region_section_title(font, "Region Overview", text_pos.x, y)
	var region_in_view: WorldMapData.Region = get_region_in_view() if world_map_data != null else null
	if region_in_view != null:
		y = draw_region_label_value(font, font_size, "Climate", region_in_view.climate, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_SOFT)
		y = draw_region_label_value(font, font_size, "Land", region_in_view.landscape, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_SOFT)
		var kingdom: WorldMapData.Kingdom = world_map_data.get_kingdom(region_in_view.owner_kingdom_id)
		var status: String = "Held by " + kingdom.name if kingdom != null else ("Contested frontier" if region_in_view.is_contested() else "Open frontier")
		y = draw_region_label_value(font, font_size, "Status", status, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_SOFT)
		y += 4.0
	if is_inside_map(hovered_tile.x, hovered_tile.y):
		y = draw_region_hover_summary(font, font_size, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2)
	else:
		y = draw_sidebar_like_line(font, font_size, "Hover a tile to inspect.", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_MUTED)

	y += 12.0
	y = draw_region_section_title(font, "Founding", text_pos.x, y)
	y = draw_sidebar_like_line(font, font_size, get_founding_prompt_text(), text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, get_founding_prompt_color())
	if has_pending_founding_tile():
		y = draw_region_label_value(font, font_size, "Pending", str(pending_founding_tile.x) + ", " + str(pending_founding_tile.y), text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TITLE)
		y = draw_sidebar_like_line(font, font_size, RegionTileDisplayHelper.describe_site_character(pending_site_profile), text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_SOFT)
		for survey_line: String in pending_site_survey:
			y = draw_sidebar_like_line(font, font_size, survey_line, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_NORMAL)
		if region_map_view != null:
			y = draw_sidebar_like_line(font, font_size, "The gold circle is the town's land.", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_MUTED)
		y = draw_sidebar_like_line(font, font_size, "Right-click to clear.", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_MUTED)
		if can_found_player_city():
			y = draw_region_action_option(font, font_size, "Found Town", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, {"action": "found_player_city"}, VisualStyle.COLOR_UI_BUTTON_ACTIVE)

	y += 12.0
	y = draw_region_section_title(font, "Trade / Routes", text_pos.x, y)
	y = draw_region_action_option(font, font_size, "Trade", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, {"action": "new_trade_route"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)
	y += 8.0
	y = draw_trade_route_summaries(font, font_size, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2)

	y += 12.0
	y = draw_region_section_title(font, "Regional Signals", text_pos.x, y)
	draw_region_label_value(font, font_size, "Day", str(world_calendar.get_day_of_year()), text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_UI_TEXT_NORMAL)

func draw_trade_route_summaries(font: Font, font_size: int, x: float, y: float, width: float) -> float:
	if trade_routes.is_empty():
		return draw_sidebar_like_line(font, font_size, "No active routes.", x, y, width, VisualStyle.COLOR_MUTED)

	for route_index in range(trade_routes.size()):
		var route: TradeRoute = trade_routes[route_index]
		var summary: String = get_trade_route_summary(route)
		y = draw_sidebar_like_line(font, font_size, summary, x, y, width, VisualStyle.COLOR_RESOURCE_FOOD)
		if route_index >= 3:
			return draw_sidebar_like_line(font, font_size, "...", x, y, width, VisualStyle.COLOR_MUTED)

	return y

func draw_region_section_title(font: Font, text: String, x: float, y: float) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, VisualStyle.COLOR_UI_SECTION_HEADER)
	return y + 18.0

func draw_region_label_value(font: Font, font_size: int, label: String, value: String, x: float, y: float, width: float, color: Color) -> float:
	draw_string(font, Vector2(x, y), label + ":", HORIZONTAL_ALIGNMENT_LEFT, 74.0, font_size, VisualStyle.COLOR_MUTED)
	draw_string(font, Vector2(x + 76.0, y), value, HORIZONTAL_ALIGNMENT_LEFT, width - 76.0, font_size, color)
	return y + 18.0

func draw_region_hover_summary(font: Font, font_size: int, x: float, y: float, width: float) -> float:
	var tile: Dictionary = tiles[hovered_tile.y][hovered_tile.x] as Dictionary
	var city_name: String = get_city_name_at_tile(hovered_tile.x, hovered_tile.y)

	y = draw_region_label_value(font, font_size, "Tile", str(hovered_tile.x) + ", " + str(hovered_tile.y), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_region_label_value(font, font_size, "Terrain", RegionTileDisplayHelper.describe_terrain(tile), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	var offer: String = RegionTileDisplayHelper.describe_offer(tile)
	if offer != "":
		y = draw_region_label_value(font, font_size, "Offers", offer, x, y, width, VisualStyle.COLOR_RESOURCE_TOOLS)
	if city_name != "none":
		y = draw_region_label_value(font, font_size, "City", city_name, x, y, width, VisualStyle.COLOR_UI_TITLE)
		var city: City = get_city_at_tile(hovered_tile.x, hovered_tile.y)
		if city != null:
			y = draw_region_label_value(font, font_size, "Role", get_city_role_display_name(city), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
			y = draw_region_label_value(font, font_size, "Site", city.site_profile.get_tag_text(), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	var founding_status: String = get_founding_hover_status_text(hovered_tile)
	var founding_color: Color = VisualStyle.COLOR_UI_TEXT_NORMAL
	if is_valid_founding_tile(hovered_tile) and not has_player_city():
		founding_color = VisualStyle.COLOR_POSITIVE
	else:
		founding_color = VisualStyle.COLOR_WARNING
	y = draw_region_label_value(font, font_size, "Founding", founding_status, x, y, width, founding_color)

	return y

func get_founding_prompt_text() -> String:
	if has_player_city():
		return "Player town founded."
	if has_pending_founding_tile():
		return "Confirm the chosen site."
	return "Choose a founding site."

func get_founding_prompt_color() -> Color:
	if has_player_city():
		return VisualStyle.COLOR_POSITIVE
	if has_pending_founding_tile():
		return VisualStyle.COLOR_UI_TITLE
	return VisualStyle.COLOR_UI_TEXT_NORMAL

func get_founding_hover_status_text(tile_pos: Vector2i) -> String:
	if has_player_city():
		return "Player town already founded"
	var reason: String = get_founding_tile_invalid_reason(tile_pos)
	if reason == FoundingSiteHelper.VALID_FOUNDING_SITE:
		return "Valid founding site"
	return "Cannot found here: " + reason

func draw_time_control_options(font: Font, font_size: int, x: float, y: float, width: float) -> float:
	y = draw_region_action_option(font, font_size, "Pause", x, y, width, {"action": "toggle_pause"}, get_time_control_color("Paused"))
	y = draw_region_action_option(font, font_size, "1x", x, y, width, {"action": "speed_1x"}, get_time_control_color("1x"))
	y = draw_region_action_option(font, font_size, "3x", x, y, width, {"action": "speed_3x"}, get_time_control_color("3x"))
	y = draw_region_action_option(font, font_size, "10x", x, y, width, {"action": "speed_10x"}, get_time_control_color("10x"))
	return y

func draw_city_time_control_options(font: Font, font_size: int, x: float, y: float, width: float) -> float:
	var gap: float = 5.0
	var button_width: float = (width - gap * 3.0) / 4.0
	draw_city_action_button(font, font_size, "Pause", x, y, button_width, {"action": "toggle_pause"}, get_time_control_color("Paused"))
	draw_city_action_button(font, font_size, "1x", x + (button_width + gap), y, button_width, {"action": "speed_1x"}, get_time_control_color("1x"))
	draw_city_action_button(font, font_size, "3x", x + (button_width + gap) * 2.0, y, button_width, {"action": "speed_3x"}, get_time_control_color("3x"))
	draw_city_action_button(font, font_size, "10x", x + (button_width + gap) * 3.0, y, button_width, {"action": "speed_10x"}, get_time_control_color("10x"))
	return y + 21.0

func get_time_control_color(label: String) -> Color:
	if simulation_clock.get_speed_label() == label:
		return VisualStyle.COLOR_UI_BUTTON_ACTIVE

	return VisualStyle.COLOR_UI_BUTTON_DISABLED

func draw_trade_menu_popup():
	var font: Font = ThemeDB.fallback_font
	trade_menu.draw(self, font, cities, get_viewport_rect().size)

func draw_region_action_option(font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color) -> float:
	var option_rect: Rect2 = Rect2(Vector2(x - 4.0, y - 13.0), Vector2(width + 8.0, 18.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = option_rect
	region_action_options.append(stored_option)

	draw_rect(option_rect, color)
	draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, VisualStyle.COLOR_UI_TEXT)
	return y + 21.0

func draw_city_action_option(font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color) -> float:
	var option_rect: Rect2 = Rect2(Vector2(x - 4.0, y - 13.0), Vector2(width + 8.0, 18.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = option_rect
	city_action_options.append(stored_option)

	draw_rect(option_rect, color)
	draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, VisualStyle.COLOR_UI_TEXT)
	return y + 21.0

func draw_city_action_button(font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color):
	var option_rect: Rect2 = Rect2(Vector2(x, y - 13.0), Vector2(width, 18.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = option_rect
	city_action_options.append(stored_option)

	draw_rect(option_rect, color)
	draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	draw_string(font, Vector2(x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, width - 10.0, font_size, VisualStyle.COLOR_UI_TEXT)

func draw_sidebar_like_line(font: Font, font_size: int, text: String, x: float, y: float, width: float, color: Color) -> float:
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
	return y + 18.0

func get_trade_city_label(city_index: int) -> String:
	if city_index < 0 or city_index >= cities.size():
		return "click city"

	var city: City = cities[city_index]
	return city.name

func get_city_role_display_name(city: City) -> String:
	if city == null:
		return "unknown"
	if city.is_neutral_city():
		return "neutral town"
	if city.is_debug_city():
		return "debug city"

	return "player town"

func get_trade_route_summary(route: TradeRoute) -> String:
	var source_label: String = get_trade_city_label(route.source_city_id)
	var destination_label: String = get_trade_city_label(route.destination_city_id)
	return route.get_summary(source_label, destination_label)

func draw_city_resource_tooltip():
	if hovered_city_index < 0 or hovered_city_index >= cities.size():
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 13
	var mouse_pos: Vector2 = get_local_mouse_position()
	var tooltip_size: Vector2 = Vector2(230.0, 112.0)
	var tooltip_pos: Vector2 = mouse_pos + Vector2(18.0, 16.0)
	var map_rect: Rect2 = get_region_map_screen_rect()
	var max_x: float = map_rect.end.x - tooltip_size.x - 4.0
	var max_y: float = map_rect.end.y - tooltip_size.y - 4.0
	if max_x < 4.0:
		max_x = 4.0
	if max_y < 4.0:
		max_y = 4.0
	tooltip_pos.x = clamp(tooltip_pos.x, 4.0, max_x)
	tooltip_pos.y = clamp(tooltip_pos.y, 4.0, max_y)

	var city: City = cities[hovered_city_index]
	var resources: Dictionary = city.resources
	var trends: Dictionary = city.get_resource_trends()
	var tooltip_rect: Rect2 = Rect2(tooltip_pos, tooltip_size)
	var text_x: float = tooltip_pos.x + 10.0
	var y: float = tooltip_pos.y + 18.0

	draw_rect(tooltip_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	draw_rect(tooltip_rect, VisualStyle.COLOR_SELECTION_OUTLINE, false, VisualStyle.PANEL_BORDER_WIDTH)
	draw_string(font, Vector2(text_x, y), city.name, HORIZONTAL_ALIGNMENT_LEFT, tooltip_size.x - 20.0, font_size, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 22.0
	y = draw_city_resource_tooltip_line(font, font_size, "Food", int(resources["food"]), float(trends["food"]), text_x, y, tooltip_size.x)
	y = draw_city_resource_tooltip_line(font, font_size, "Wood", int(resources["wood"]), float(trends["wood"]), text_x, y, tooltip_size.x)
	draw_city_resource_tooltip_line(font, font_size, "Tools", int(resources["tools"]), float(trends["tools"]), text_x, y, tooltip_size.x)

func draw_city_resource_tooltip_line(font: Font, font_size: int, label: String, amount: int, trend: float, x: float, y: float, tooltip_width: float) -> float:
	var text: String = label + ": " + str(amount) + " (" + trend_text(trend) + ") - " + trend_status_text(trend)
	var color: Color = trend_status_color(trend)
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, tooltip_width - 20.0, font_size, color)
	return y + 20.0

func trend_text(trend: float) -> String:
	if abs(trend) < CITY_TREND_STABLE_THRESHOLD:
		return "trend stable"

	var rounded_trend: float = snapped(trend, 0.1)
	var text: String = str(rounded_trend)
	if rounded_trend > 0.0:
		text = "+" + text

	return "trend " + text + "/tick"

func trend_status_text(trend: float) -> String:
	if trend > CITY_TREND_STABLE_THRESHOLD:
		return "Rising"
	if trend < -CITY_TREND_STABLE_THRESHOLD:
		return "Falling"

	return "Stable"

func trend_status_color(trend: float) -> Color:
	if trend > CITY_TREND_STABLE_THRESHOLD:
		return VisualStyle.COLOR_POSITIVE
	if trend < -CITY_TREND_STABLE_THRESHOLD:
		return VisualStyle.COLOR_WARNING

	return VisualStyle.COLOR_UI_TEXT_SOFT

func get_hover_info_lines() -> Array[String]:
	var tile: Dictionary = tiles[hovered_tile.y][hovered_tile.x] as Dictionary
	var resource: String = tile["resource"] as String
	var city_name: String = get_city_name_at_tile(hovered_tile.x, hovered_tile.y)
	var lines: Array[String] = []

	lines.append("Tile: " + str(hovered_tile.x) + ", " + str(hovered_tile.y))
	lines.append("Terrain: " + str(tile["type"]))
	lines.append("Forest: " + yes_no(tile["has_forest"] == true))
	lines.append("Fertile: " + yes_no(tile["is_fertile"] == true))
	lines.append("Stone: " + yes_no(resource == "stone"))
	lines.append("Iron: " + yes_no(resource == "iron"))
	lines.append("City: " + city_name)
	lines.append("Founding: " + get_founding_hover_status_text(hovered_tile))

	return lines

func get_city_name_at_tile(x: int, y: int) -> String:
	var city: City = get_city_at_tile(x, y)
	if city != null:
		return city.name

	return "none"

func get_city_at_tile(x: int, y: int) -> City:
	for city: City in cities:
		var tile_pos: Vector2 = city.tile
		if int(tile_pos.x) == x and int(tile_pos.y) == y:
			return city

	return null

func yes_no(value: bool) -> String:
	if value:
		return "yes"
	return "no"

func tile_to_center(tile_pos: Vector2) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE) + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
