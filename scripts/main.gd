extends Node2D

const TILE_SIZE: int = 12
const MAP_WIDTH: int = 80
const MAP_HEIGHT: int = 50
const MIN_CITY_DISTANCE: int = 24
const RIVER_NEAR_RANGE: int = 5
const CITY_RESOURCE_RANGE: int = 7
const PANEL_MARGIN: int = VisualStyle.PANEL_MARGIN
const PANEL_WIDTH: int = 260
const PANEL_PADDING: int = VisualStyle.SIDEBAR_PADDING
const VIEW_REGION: String = "region"
const VIEW_CITY: String = "city"
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
const WOODCUTTER_TREE_RADIUS: int = 5
const CITY_WALKER_CYCLE_SECONDS: float = 12.0
const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
const CITY_TREND_STABLE_THRESHOLD: float = 0.15

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tiles: Array = []
var cities: Array[City] = []
var roads: Array[Array] = []
var trade_routes: Array[TradeRoute] = []
var top_bar_action_options: Array[Dictionary] = []
var region_action_options: Array[Dictionary] = []
var city_action_options: Array[Dictionary] = []
var hovered_tile: Vector2i = Vector2i(-1, -1)
var hovered_city_index: int = -1
var city_hovered_tile: Vector2i = Vector2i(-1, -1)
var current_view: String = VIEW_REGION
var selected_city_index: int = -1
var household_debug_inspector: Control = null
var trade_menu: TradeMenu = TradeMenu.new()
var selected_building_type: String = BUILDING_HOUSE
var is_placing_building: bool = true
var city_walker_time: float = 0.0
var world_calendar: Calendar = Calendar.new()
var simulation_clock: SimulationClock = SimulationClock.new()
var building_placement: BuildingPlacement = BuildingPlacement.new(CITY_MAP_WIDTH, CITY_MAP_HEIGHT, WOODCUTTER_TREE_RADIUS)
var city_building_overlay: CityBuildingOverlay = CityBuildingOverlay.new(CITY_TILE_SIZE, CITY_VIEW_TOP, CITY_MAP_WIDTH, CITY_MAP_HEIGHT)

var city_pressure_debug_panel: Control = null

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
	world_calendar.season_changed.connect(on_calendar_season_changed)
	generate_map()
	place_cities()
	analyze_city_site_profiles()
	generate_city_local_maps()
	generate_roads()
	analyze_city_site_profiles()
	_ensure_household_debug_inspector()
	queue_redraw()

func _process(_delta: float):
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
	else:
		update_city_hovered_tile(get_local_mouse_position())
		if hovered_tile != Vector2i(-1, -1):
			hovered_tile = Vector2i(-1, -1)
			queue_redraw()
		if hovered_city_index != -1:
			hovered_city_index = -1
			queue_redraw()
		queue_redraw()

func _input(event: InputEvent):
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
		household_debug_inspector.visible = not household_debug_inspector.visible
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var local_mouse_pos: Vector2 = get_local_mouse_position()
		if current_view == VIEW_REGION and trade_menu.handle_mouse_button(mouse_event, local_mouse_pos):
			queue_redraw()
			return

		if not mouse_event.pressed:
			return

		if current_view == VIEW_REGION and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			trade_menu.close()
			queue_redraw()
			return
		if current_view == VIEW_CITY and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			is_placing_building = false
			clear_selected_household()
			queue_redraw()
			return

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if try_handle_top_bar_click(local_mouse_pos):
			queue_redraw()
			return

		if current_view == VIEW_REGION:
			if try_handle_region_action_click(local_mouse_pos):
				queue_redraw()
			elif trade_menu.is_open():
				try_handle_trade_city_click(local_mouse_pos)
			else:
				try_open_city_at_position(local_mouse_pos)
		elif current_view == VIEW_CITY:
			if try_handle_city_action_click(local_mouse_pos):
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
	elif event is InputEventKey:
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
		if handle_building_selection_key_event(key_event):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent):
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
		if handle_building_selection_key_event(key_event):
			get_viewport().set_input_as_handled()

func update_hovered_tile(mouse_pos: Vector2):
	var tile_x: int = int(floor(mouse_pos.x / TILE_SIZE))
	var tile_y: int = int(floor(mouse_pos.y / TILE_SIZE))
	var new_hovered_tile: Vector2i = Vector2i(-1, -1)

	if is_inside_map(tile_x, tile_y):
		new_hovered_tile = Vector2i(tile_x, tile_y)

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

func generate_map():
	var generator: RegionMapGenerator = make_region_map_generator()
	var result: Dictionary = generator.generate_region()
	tiles = result["tiles"] as Array
	cities = result["cities"] as Array[City]
	roads.clear()

func place_cities():
	trade_routes.clear()
	trade_menu.close()

func generate_roads():
	var generator: RegionMapGenerator = make_region_map_generator()
	generator.tiles = tiles
	roads = generator.generate_roads_for_cities(cities)

func make_region_map_generator() -> RegionMapGenerator:
	return RegionMapGenerator.new(rng, MAP_WIDTH, MAP_HEIGHT, MIN_CITY_DISTANCE, RIVER_NEAR_RANGE, CITY_RESOURCE_RANGE)

func analyze_city_site_profiles():
	for city: City in cities:
		city.site_profile = SettlementSiteProfile.analyze(city.tile, tiles, CITY_RESOURCE_RANGE)
		print(city.name, " site profile: ", city.site_profile.get_debug_summary())

func generate_city_local_maps():
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(rng, CITY_MAP_WIDTH, CITY_MAP_HEIGHT, MAP_WIDTH, MAP_HEIGHT, RIVER_NEAR_RANGE, CITY_RESOURCE_RANGE)
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		city.local_map = generator.generate(city, tiles, city_index)

func is_inside_map(x: int, y: int) -> bool:
	return x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_HEIGHT

func try_open_city_at_position(mouse_pos: Vector2):
	var city_index: int = get_city_index_at_position(mouse_pos)
	if city_index == -1:
		return

	selected_city_index = city_index
	current_view = VIEW_CITY
	hovered_tile = Vector2i(-1, -1)
	hovered_city_index = -1
	queue_redraw()

func get_city_index_at_position(mouse_pos: Vector2) -> int:
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		var tile_pos: Vector2 = city.tile
		var center: Vector2 = tile_to_center(tile_pos)

		if center.distance_to(mouse_pos) <= TILE_SIZE * 1.2:
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
		else:
			apply_time_control_action(action)
		return true

	return false

func apply_region_action(option_data: Dictionary):
	var action: String = option_data["action"] as String

	if action == "new_trade_route":
		trade_menu.open(cities)
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

	trade_menu.handle_city_selection(city_index)

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
	clear_selected_household()
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
		selected_building_type = BUILDING_HOUSE
		is_placing_building = true
		clear_selected_household()
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_2, 50):
		selected_building_type = BUILDING_FARM
		is_placing_building = true
		clear_selected_household()
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_3, 51):
		selected_building_type = BUILDING_WOODCUTTER
		is_placing_building = true
		clear_selected_household()
	elif is_building_key(keycode, physical_keycode, unicode_value, KEY_4, 52):
		selected_building_type = BUILDING_TOOLMAKER
		is_placing_building = true
		clear_selected_household()
	else:
		return false

	queue_redraw()
	return true

func is_building_key(keycode: int, physical_keycode: int, unicode_value: int, number_key: int, expected_unicode: int) -> bool:
	if keycode == number_key or physical_keycode == number_key:
		return true
	if unicode_value == expected_unicode:
		return true

	return false

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
		city.tick()

	apply_trade_routes()
	for city: City in cities:
		city.record_resource_history()

	if current_view == VIEW_CITY:
		queue_redraw()

func on_calendar_season_changed(calendar: Calendar):
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
		route.transfer_tick(source_city, destination_city)

func get_preferred_worker_for_building(building_type: String) -> String:
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

func get_household_debug_city():
	if current_view != VIEW_CITY:
		return null
	if selected_city_index >= 0 and selected_city_index < cities.size():
		return cities[selected_city_index]

	return null

func _draw():
	if current_view == VIEW_CITY:
		draw_city_view()
		return

	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			draw_tile(x, y)

	draw_roads()
	draw_trade_routes()
	draw_fords()
	draw_cities()
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
		var source_center: Vector2 = tile_to_center(source_tile)
		var destination_center: Vector2 = tile_to_center(destination_tile)

		MapElementVisuals.draw_trade_route(self, source_center, destination_center)

func draw_fords():
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			if not tiles[y][x]["has_ford"]:
				continue

			var pos: Vector2 = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var tile_rect: Rect2 = Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
			MapElementVisuals.draw_ford(self, tile_rect)

func draw_cities():
	for city_index in range(cities.size()):
		var city: City = cities[city_index]
		var tile_pos: Vector2 = city.tile
		var center: Vector2 = tile_to_center(tile_pos)
		MapElementVisuals.draw_city_marker(self, center, TILE_SIZE, city_index == hovered_city_index, city_index == selected_city_index)

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
	y = draw_sidebar_label_value(font, font_size, "External", str(resources["external_population_pool"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Labor", str(resources["assigned_workers"]) + " / " + str(resources["total_labor_capacity"]) + " used", text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y = draw_sidebar_label_value(font, font_size, "Idle", str(resources["idle_workers"]), text_x, y, VisualStyle.COLOR_POPULATION_LABOR)
	y += 4.0

	y = draw_sidebar_section_title(font, "Selected Object", text_x, y)
	y = draw_selected_object_summary(font, font_size, city, text_x, y)
	y += 4.0

	y = draw_sidebar_section_title(font, "Build Controls", text_x, y)
	if is_placing_building:
		y = draw_sidebar_label_value(font, font_size, "Building", selected_building_type, text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
		y = draw_sidebar_label_value(font, font_size, "Cost", building_placement.get_cost_text(building_placement.get_building_cost(selected_building_type)), text_x, y, VisualStyle.COLOR_MUTED)
	else:
		y = draw_sidebar_label_value(font, font_size, "Building", "none", text_x, y, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_sidebar_line(font, font_size, "1 house, 2 farm", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "3 woodcutter, 4 toolmaker", text_x, y, VisualStyle.COLOR_MUTED)
	y = draw_sidebar_line(font, font_size, "Right click/Esc: clear", text_x, y, VisualStyle.COLOR_MUTED)
	if int(resources["maintenance_grace_ticks"]) > 0:
		y = draw_sidebar_line(font, font_size, "Grace: " + str(resources["maintenance_grace_ticks"]) + " ticks", text_x, y, VisualStyle.COLOR_MUTED)
	y += 4.0
	draw_sidebar_line(font, font_size, placement_status, text_x, y, placement_color)

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

func draw_pressure_row(font: Font, font_size: int, label: String, pressure: Dictionary, x: float, y: float) -> float:
	var status: String = pressure["status"] as String
	var severity: String = pressure["severity"] as String
	var detail: String = pressure["detail"] as String
	y = draw_sidebar_label_value(font, font_size, label, status, x, y, get_pressure_color(severity))
	if not detail.is_empty():
		y = draw_sidebar_detail_line(font, font_size, detail, x + 12.0, y - 1.0)

	return y

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
			y = draw_sidebar_label_value(font, font_size, "Preference", household.preference, x, y, VisualStyle.get_preference_color(household.preference))
	else:
		y = draw_sidebar_label_value(font, font_size, "Worker", get_selected_building_worker_summary(city, building), x, y, VisualStyle.COLOR_POPULATION_LABOR)
		y = draw_sidebar_label_value(font, font_size, "Upkeep", str(building.maintenance_level) + "%", x, y, get_maintenance_summary_color(building))

	return y

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

	var panel_pos: Vector2 = Vector2(MAP_WIDTH * TILE_SIZE + PANEL_MARGIN, TOP_BAR_HEIGHT)
	var panel_size: Vector2 = Vector2(PANEL_WIDTH, MAP_HEIGHT * TILE_SIZE - TOP_BAR_HEIGHT)
	var panel_rect: Rect2 = Rect2(panel_pos, panel_size)
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
	if is_inside_map(hovered_tile.x, hovered_tile.y):
		y = draw_region_hover_summary(font, font_size, text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2)
	else:
		y = draw_sidebar_like_line(font, font_size, "Hover a tile to inspect.", text_pos.x, y, PANEL_WIDTH - PANEL_PADDING * 2, VisualStyle.COLOR_MUTED)

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
	var resource: String = tile["resource"] as String
	var city_name: String = get_city_name_at_tile(hovered_tile.x, hovered_tile.y)

	y = draw_region_label_value(font, font_size, "Tile", str(hovered_tile.x) + ", " + str(hovered_tile.y), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_region_label_value(font, font_size, "Terrain", str(tile["type"]), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	if city_name != "none":
		y = draw_region_label_value(font, font_size, "City", city_name, x, y, width, VisualStyle.COLOR_UI_TITLE)
		var city: City = get_city_at_tile(hovered_tile.x, hovered_tile.y)
		if city != null:
			y = draw_region_label_value(font, font_size, "Site", city.site_profile.get_tag_text(), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_region_label_value(font, font_size, "Forest", yes_no(tile["has_forest"] == true), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	y = draw_region_label_value(font, font_size, "Fertile", yes_no(tile["is_fertile"] == true), x, y, width, VisualStyle.COLOR_UI_TEXT_NORMAL)
	if resource != "none":
		y = draw_region_label_value(font, font_size, "Resource", resource, x, y, width, VisualStyle.COLOR_RESOURCE_TOOLS)

	return y

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
	var max_x: float = MAP_WIDTH * TILE_SIZE - tooltip_size.x - 4.0
	var max_y: float = MAP_HEIGHT * TILE_SIZE - tooltip_size.y - 4.0
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
