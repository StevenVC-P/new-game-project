class_name GameState
extends RefCounted

# What a saved game holds, and how it is put back into main.gd.
#
# The planet is not saved: it is rebuilt from its seed (WorldGenerator), and the regional land
# around the player from the planet (RegionalTerrain.extract_window). A fingerprint of the
# world refuses a save whose planet this build would rebuild differently. Everything play
# changes is saved: every town in the neighbourhood (families, buildings, stores, town map,
# construction, woodland, farmland), the player's road spur, trade routes, the calendar, and where the player was
# looking. Town maps are saved whole rather than regenerated, so construction marks on them and
# changes to the town map generator cannot shift a town under its buildings.

# Bump when saved data changes shape in a way older builds cannot read.
const FORMAT: int = 1

# Travel caches are rebuilt from the layout on first use.
const LOGISTICS_SKIP: Array[String] = ["grid", "grid_version", "cell_effort", "cell_inside", "tile_owner", "tile_base", "tile_margin", "tile_open", "tile_kind", "cell_flags", "closed_cells", "cache_version", "store_cache", "commute_cache", "site_cache"]
# Fixed tables, not state.
const CALENDAR_SKIP: Array[String] = ["month_names", "season_names"]
const CLOCK_SKIP: Array[String] = ["speed_options"]

static func capture(main: Node) -> Dictionary:
	var state: Dictionary = {
		"world_seed": main.world_map_data.world_seed,
		"authored_world": main.use_authored_world,
		"world_fingerprint": world_fingerprint(main.world_map_data),
		"calendar": SaveCodec.capture(main.world_calendar, CALENDAR_SKIP),
		"clock": SaveCodec.capture(main.simulation_clock, CLOCK_SKIP),
		"has_shown_region_map": main.has_shown_region_map,
		"view": main.current_view,
	}
	if not main.has_shown_region_map or main.regional_terrain == null:
		return state
	var cities: Array = []
	for city: City in main.cities:
		cities.append(capture_city(city))
	var routes: Array = []
	for route: TradeRoute in main.trade_routes:
		routes.append(SaveCodec.capture(route))
	state["neighbourhood_origin"] = main.neighbourhood_origin
	state["entered_world_region_id"] = main.entered_world_region_id
	state["cities"] = cities
	state["roads"] = main.roads.duplicate(true)
	state["trade_routes"] = routes
	state["selected_city_index"] = main.selected_city_index
	if main.region_map_view != null:
		state["camera_tile"] = main.region_map_view.camera_global_tile()
		state["camera_zoom"] = main.region_map_view.zoom
	return state

# Puts a captured state into a main.gd whose world is built (after _ready's world setup).
# Returns an error message, or "" when the game was restored.
static func restore(main: Node, state: Dictionary) -> String:
	if int(state.get("world_fingerprint", 0)) != world_fingerprint(main.world_map_data):
		return "This save's world cannot be rebuilt: the world generator has changed since it was saved."
	SaveCodec.restore(main.world_calendar, state["calendar"])
	SaveCodec.restore(main.simulation_clock, state["clock"])
	if not bool(state["has_shown_region_map"]) or not state.has("cities"):
		return ""

	main._ensure_regional_terrain()
	var origin: Vector2i = state["neighbourhood_origin"]
	main.place_neighbourhood(origin + main.NEIGHBOURHOOD_SIZE / 2)
	var cities: Array[City] = []
	for city_data: Dictionary in state["cities"]:
		cities.append(restore_city(city_data))
	# A town where families lead, saved before residential land existed, gets its starting land
	# (HomeSites.ensure_starting_land: only once, and never over land the player marked).
	for city: City in cities:
		HomeSites.ensure_starting_land(city)
	main.cities = cities
	main.roads = state["roads"]
	# The player's spur road is marked on the neighbourhood's tiles, as founding marked it.
	var generator: RegionMapGenerator = main.make_region_map_generator()
	generator.tiles = main.tiles
	for road: Array in main.roads:
		generator.mark_road_path(road)
	var routes: Array[TradeRoute] = []
	for route_data: Dictionary in state["trade_routes"]:
		var route: TradeRoute = TradeRoute.new()
		SaveCodec.restore(route, route_data)
		routes.append(route)
	main.trade_routes = routes
	main.entered_world_region_id = state["entered_world_region_id"]
	main.refresh_founding_sites()
	if main.region_map_view != null:
		main.region_map_view.set_neighbourhood(main.tiles, main.cities, main.roads, main.neighbourhood_origin)
	main.notify_region_map_changed()

	var camera_tile: Vector2 = state.get("camera_tile", Vector2(origin + main.NEIGHBOURHOOD_SIZE / 2))
	main.enter_regional_map_at(camera_tile * RegionalTerrain.TILE_WORLD_UNITS, float(state.get("camera_zoom", main.REGION_ENTRY_ZOOM)), Vector2(-1.0, -1.0))
	main.selected_city_index = state["selected_city_index"] if int(state["selected_city_index"]) < main.cities.size() else -1
	var view: String = state["view"]
	if view == main.VIEW_CITY and main.selected_city_index >= 0 and main.cities[main.selected_city_index].is_controllable_city():
		main.current_view = main.VIEW_CITY
	elif view == main.VIEW_WORLD:
		main.open_world_map()
	main.queue_redraw()
	return ""

static func capture_city(city: City) -> Dictionary:
	var buildings: Array = []
	for building: Building in city.buildings:
		buildings.append(SaveCodec.capture(building))
	var households: Array = []
	for household: Household in city.households:
		households.append(SaveCodec.capture(household))
	var projects: Array = []
	for project: ConstructionProject in city.construction.projects:
		projects.append(SaveCodec.capture(project))
	return {
		"fields": SaveCodec.capture(city),
		"buildings": buildings,
		"households": households,
		"site_profile": SaveCodec.capture(city.site_profile),
		"logistics": SaveCodec.capture(city.logistics, LOGISTICS_SKIP),
		"construction": SaveCodec.capture(city.construction),
		"projects": projects,
		"woodland": SaveCodec.capture(city.woodland),
		"farmland": SaveCodec.capture(city.farmland),
		"land": SaveCodec.capture(city.land),
		"trade": SaveCodec.capture(city.trade),
		"defense": SaveCodec.capture(city.defense),
		"settlement": SaveCodec.capture(city.settlement),
		"influence": SaveCodec.capture(city.influence),
		"social": SaveCodec.capture(city.social),
		"errands": city.errands.get_saved(),
	}

static func restore_city(data: Dictionary) -> City:
	var fields: Dictionary = data["fields"]
	# No starter families: the saved ones replace them.
	var city: City = City.new(fields["name"], fields["tile"], fields["role"], 0, fields["founding_seed"])
	SaveCodec.restore(city, fields)
	var buildings: Array[Building] = []
	for building_data: Dictionary in data["buildings"]:
		var building: Building = Building.new()
		SaveCodec.restore(building, building_data)
		buildings.append(building)
	city.buildings = buildings
	var households: Array[Household] = []
	for household_data: Dictionary in data["households"]:
		var household: Household = Household.new()
		SaveCodec.restore(household, household_data)
		households.append(household)
	city.households = households
	# Saves from before obstacles were recorded apart: the obstacle is in the note's words.
	for household: Household in households:
		if household.home_site_obstacle == "" and household.home_site_note.contains(" cannot build a home: "):
			household.home_site_obstacle = household.home_site_note.get_slice(" cannot build a home: ", 1)
	city.site_profile = SettlementSiteProfile.new()
	SaveCodec.restore(city.site_profile, data["site_profile"])
	SaveCodec.restore(city.logistics, data["logistics"])
	SaveCodec.restore(city.construction, data["construction"])
	# Saves from before woodland have nothing marked or felled.
	SaveCodec.restore(city.woodland, data.get("woodland", {}))
	SaveCodec.restore(city.farmland, data.get("farmland", {}))
	SaveCodec.restore(city.land, data.get("land", {}))
	SaveCodec.restore(city.trade, data.get("trade", {}))
	SaveCodec.restore(city.defense, data.get("defense", {}))
	SaveCodec.restore(city.settlement, data.get("settlement", {}))
	SaveCodec.restore(city.influence, data.get("influence", {}))
	SaveCodec.restore(city.social, data.get("social", {}))
	# Saves from before errands were saved find their routes again (a month of slightly different wear).
	city.errands.restore_saved(data.get("errands", {}))
	var projects: Array[ConstructionProject] = []
	for project_data: Dictionary in data["projects"]:
		var project: ConstructionProject = ConstructionProject.new()
		SaveCodec.restore(project, project_data)
		projects.append(project)
	city.construction.projects = projects
	return city

# Changes whenever this build would rebuild a seed's planet differently.
static func world_fingerprint(world: WorldMapData) -> int:
	var names: PackedStringArray = PackedStringArray()
	for settlement: WorldMapData.Settlement in world.settlements:
		names.append(settlement.name)
	return hash([world.world_seed, world.region_grid, "|".join(names)])

# What the load list shows about a save, readable without loading the whole game.
static func describe(main: Node, slot_name: String) -> Dictionary:
	var header: Dictionary = {
		"format": FORMAT,
		"name": slot_name,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"world_seed": main.world_map_data.world_seed,
		"authored_world": main.use_authored_world,
		"date": main.world_calendar.get_formatted_date(),
		"place": "",
		"population": 0,
	}
	var player_index: int = main.get_player_city_index()
	if player_index >= 0:
		var town: City = main.cities[player_index]
		header["place"] = town.name
		header["population"] = town.get_total_population()
	elif main.has_shown_region_map:
		var region: WorldMapData.Region = main.get_region_in_view()
		header["place"] = "Exploring " + region.name if region != null else "Exploring"
	else:
		header["place"] = "World atlas"
	return header
