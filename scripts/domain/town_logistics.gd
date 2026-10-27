class_name TownLogistics
extends RefCounted

# How goods move around a town. Goods are kept in stores: the founders' stockpile at the town's
# heart and any storehouses built since. A workplace's family carries its output to the nearest
# store and its inputs back, and walks from home to work; that travel takes part of its day, so a
# workplace far from a store or from its family's home produces less. Builders carry materials
# from the nearest store to a site the same way (TownConstruction).
#
# Travel is aggregated, not simulated per item: routes are found once per town layout on the
# town map (AStarGrid2D, weighted by ground: roads fast, woods, hills, and rock slow, water
# impassable), and each workplace's daily trips become a share of its family's working day. All
# stores share one stock, City.resources; separate inventories per store are later work.
#
# Those same trips wear the ground they cross. Wear builds up where people walk and fades where
# they stop; enough of it makes a trail, then a path, which are quicker to walk, so routes bend
# toward them and wear them further (desire paths). Nobody builds them.
# Design: docs/TOWN_BUILDING_MODEL.md. A town without a town map (balance tools) has no travel.

const STOCKPILE_SIZE: Vector2i = Vector2i(2, 2)
const DIAGONAL_STEP: float = 1.41421356
# How worn a tile is, kept on its town map tile as "path_level".
const PATH_NONE: int = 0
const PATH_TRAIL: int = 1
const PATH_WORN: int = 2
# Wear this small is gone.
const WEAR_FLOOR: float = 0.5

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# Top-left tile of the founders' stockpile, placed when the town map is first used.
var stockpile_tile: Vector2i = Vector2i(-1, -1)
# Bumped whenever anything that changes routes is built, planned, or removed.
var layout_version: int = 0
var grid_version: int = -1
var grid: AStarGrid2D = null
# Travel figures for the current layout: building id -> store route, [building id, household
# id] -> walk to work. Cleared when the layout changes.
var cache_version: int = -1
var store_cache: Dictionary = {}
var commute_cache: Dictionary = {}
var site_cache: Dictionary = {}
# Foot traffic: tile -> wear, only for tiles walked recently. Saved with the town.
var wear: Dictionary = {}
# Bumped whenever a tile's path level changes, so views redraw the ground.
var paths_version: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func map_size() -> Vector2i:
	if not has_map():
		return Vector2i.ZERO
	return Vector2i((city.local_map[0] as Array).size(), city.local_map.size())

func mark_layout_changed() -> void:
	layout_version += 1

# Places the founders' stockpile on the open ground nearest the town's heart (kept clear by
# LocalCityMapGenerator), the first time the town map is used.
func ensure_ready() -> void:
	if not has_map() or stockpile_tile.x >= 0:
		return
	var size: Vector2i = map_size()
	var center: Vector2 = Vector2(size) * 0.5 - Vector2(STOCKPILE_SIZE) * 0.5
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for y in range(size.y - STOCKPILE_SIZE.y + 1):
		for x in range(size.x - STOCKPILE_SIZE.x + 1):
			var distance: float = Vector2(x, y).distance_squared_to(center)
			if distance >= best_distance or not is_open_footprint(Vector2i(x, y), STOCKPILE_SIZE):
				continue
			best = Vector2i(x, y)
			best_distance = distance
	if best.x < 0:
		return
	stockpile_tile = best
	for tile: Vector2i in footprint(best, STOCKPILE_SIZE):
		(city.local_map[tile.y][tile.x] as Dictionary)["occupied"] = true
	mark_layout_changed()

func is_open_footprint(origin: Vector2i, size: Vector2i) -> bool:
	for tile: Vector2i in footprint(origin, size):
		var data: Dictionary = city.local_map[tile.y][tile.x]
		if not LocalCityMapGenerator.is_buildable(data) or data["occupied"] == true or data.get("has_road", false) == true:
			return false
	return true

static func footprint(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			tiles.append(Vector2i(x, y))
	return tiles

# --- Routes ----------------------------------------------------------------------------------

# Effort to cross a tile, in effort-tiles; INF where it cannot be crossed.
static func tile_effort(tile: Dictionary) -> float:
	if tile["type"] == "water":
		return INF
	if tile.get("has_road", false) == true:
		return EconomyBalance.ROAD_EFFORT
	if tile["occupied"] == true:
		return EconomyBalance.BUILT_EFFORT
	# Terrain, then cover.
	var effort: float = 1.0
	if tile["type"] == "rough":
		effort = EconomyBalance.ROUGH_EFFORT
	elif tile.get("is_hill", false) == true:
		effort = EconomyBalance.HILL_EFFORT
	if tile["has_trees"] == true:
		effort *= EconomyBalance.WOODS_EFFORT
	match get_path_level(tile):
		PATH_TRAIL:
			effort *= EconomyBalance.TRAIL_EFFORT_FACTOR
		PATH_WORN:
			effort *= EconomyBalance.PATH_EFFORT_FACTOR
	return effort

static func cheapest_effort() -> float:
	return minf(EconomyBalance.ROAD_EFFORT, EconomyBalance.PATH_EFFORT_FACTOR)

# Ground that foot traffic wears: not water, roads, or anything built or reserved.
static func is_wearable(tile: Dictionary) -> bool:
	return tile["type"] != "water" and tile.get("has_road", false) != true and tile["occupied"] != true

# Grid weights are efforts divided by the cheapest effort (a road), so no tile weighs less than
# a step: the grid's distance estimate then never overshoots, and A* finds the cheapest route
# rather than one that merely looks direct.
func ensure_grid() -> void:
	if grid_version == layout_version and grid != null:
		return
	grid_version = layout_version
	var size: Vector2i = map_size()
	grid = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in range(size.y):
		for x in range(size.x):
			var effort: float = tile_effort(city.local_map[y][x])
			if is_inf(effort):
				grid.set_point_solid(Vector2i(x, y), true)
			else:
				grid.set_point_weight_scale(Vector2i(x, y), effort / cheapest_effort())

# The tiles of the easiest route between two tiles, both included; empty when none exists.
func find_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not has_map():
		return route
	ensure_grid()
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to) or grid.is_point_solid(from) or grid.is_point_solid(to):
		return route
	for tile: Vector2i in grid.get_id_path(from, to):
		route.append(tile)
	return route

# Effort along a route: each step costs its length times the effort of the tile it enters.
func route_effort(route: Array[Vector2i]) -> float:
	var effort: float = 0.0
	for i in range(1, route.size()):
		var step: Vector2i = route[i] - route[i - 1]
		var length: float = DIAGONAL_STEP if step.x != 0 and step.y != 0 else 1.0
		effort += length * tile_effort(city.local_map[route[i].y][route[i].x])
	return effort

# The easiest route between two tiles and its effort: {"route", "effort"}; effort INF when no
# route exists, 0 without a town map or between a tile and itself (route then empty).
func route_between(from: Vector2i, to: Vector2i) -> Dictionary:
	var result: Dictionary = {"route": [], "effort": 0.0}
	if not has_map() or from == to:
		return result
	var route: Array[Vector2i] = find_route(from, to)
	result["route"] = route
	result["effort"] = INF if route.is_empty() else route_effort(route)
	return result

func effort_between(from: Vector2i, to: Vector2i) -> float:
	return float(route_between(from, to)["effort"])

# Where goods are kept: the stockpile and every finished storehouse, as the tiles routes use.
func get_store_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if stockpile_tile.x >= 0:
		tiles.append(center_tile(stockpile_tile, STOCKPILE_SIZE))
	for building: Building in city.buildings:
		if building.is_store():
			tiles.append(center_tile(building.tile, building.size))
	return tiles

static func center_tile(origin: Vector2i, size: Vector2i) -> Vector2i:
	return origin + (size - Vector2i.ONE) / 2

# The nearest store by effort from a tile: {"tile", "effort", "route"}; effort INF when none is
# reachable.
func nearest_store(from: Vector2i) -> Dictionary:
	var best: Dictionary = {"tile": Vector2i(-1, -1), "effort": INF, "route": []}
	for store: Vector2i in get_store_tiles():
		var found: Dictionary = route_between(from, store)
		if float(found["effort"]) < float(best["effort"]):
			best = {"tile": store, "effort": found["effort"], "route": found["route"]}
	return best

func refresh_cache() -> void:
	if cache_version == layout_version:
		return
	cache_version = layout_version
	store_cache.clear()
	commute_cache.clear()
	site_cache.clear()

func get_store_route(building: Building) -> Dictionary:
	refresh_cache()
	if not store_cache.has(building.id):
		store_cache[building.id] = nearest_store(center_tile(building.tile, building.size))
	return store_cache[building.id]

# Where the family working a building sleeps: its house, or the camp by the stockpile.
func get_home_tile(household: Household) -> Vector2i:
	if household != null and household.residence_building_id >= 0 and household.residence_building_id < city.buildings.size():
		var home: Building = city.buildings[household.residence_building_id]
		return center_tile(home.tile, home.size)
	return stockpile_tile

# The walk from the working family's home to a workplace: {"route", "effort"}; effort 0 when
# nobody works it or the town has no map.
func get_commute(building: Building) -> Dictionary:
	var none: Dictionary = {"route": [], "effort": 0.0}
	if not has_map() or building.assigned_household_id < 0:
		return none
	var household: Household = city.get_household_by_id(building.assigned_household_id)
	var home: Vector2i = get_home_tile(household)
	if home.x < 0:
		return none
	refresh_cache()
	var key: Array = [building.id, household.id if household != null else -1, home]
	if not commute_cache.has(key):
		commute_cache[key] = route_between(home, center_tile(building.tile, building.size))
	return commute_cache[key]

func get_commute_effort(building: Building) -> float:
	return float(get_commute(building)["effort"])

# Goods a workplace moves in a full day: its output plus the inputs that output uses.
static func get_daily_units(city_ref: City, building: Building) -> float:
	var base_type: String = BuildingTiers.get_base_type(building.type)
	var chain: Dictionary = EconomyBalance.PRODUCTION.get(base_type, {})
	if chain.is_empty():
		return 0.0
	var output: float = city_ref.get_base_building_output_amount(building.type)
	var inputs: int = 0
	for material: String in (chain["inputs"] as Dictionary).keys():
		inputs += int(chain["inputs"][material])
	return output * float(1 + inputs)

# What travel costs a workplace's family each day: {"haul_effort", "commute_effort",
# "haul_share", "commute_share", "share", "reachable", "store_tile"}. Shares are of the working
# day; "share" is their sum, capped at MAX_TRAVEL_SHARE (also the share when no store can be
# reached).
func get_travel(building: Building) -> Dictionary:
	var result: Dictionary = {"haul_effort": 0.0, "commute_effort": 0.0, "haul_share": 0.0, "commute_share": 0.0, "share": 0.0, "reachable": true, "store_tile": Vector2i(-1, -1)}
	if not has_map() or not building.is_production_building():
		return result
	ensure_ready()
	var store: Dictionary = get_store_route(building)
	result["store_tile"] = store["tile"]
	var units: float = get_daily_units(city, building)
	var haul_effort: float = float(store["effort"])
	var commute_effort: float = get_commute_effort(building)
	if is_inf(haul_effort) or is_inf(commute_effort):
		result["reachable"] = false
		result["share"] = EconomyBalance.MAX_TRAVEL_SHARE
		return result
	result["haul_effort"] = haul_effort
	result["commute_effort"] = commute_effort
	result["haul_share"] = units / EconomyBalance.CARRY_LOAD * 2.0 * haul_effort / EconomyBalance.DAY_EFFORT_TILES
	result["commute_share"] = 2.0 * commute_effort / EconomyBalance.DAY_EFFORT_TILES
	result["share"] = minf(float(result["haul_share"]) + float(result["commute_share"]), EconomyBalance.MAX_TRAVEL_SHARE)
	return result

func get_travel_share(building: Building) -> float:
	return float(get_travel(building)["share"])

# Family-days to carry one unit of material from the nearest store to a site.
func get_site_haul_days_per_unit(site_tile: Vector2i) -> float:
	var days: float = EconomyBalance.HANDLING_DAYS_PER_UNIT
	if not has_map():
		return days
	var effort: float = float(get_site_store_route(site_tile)["effort"])
	if is_inf(effort):
		return INF
	return days + 2.0 * effort / (EconomyBalance.CARRY_LOAD * EconomyBalance.DAY_EFFORT_TILES)

# The route builders carry materials along to a site: nearest_store from the site.
func get_site_store_route(site_tile: Vector2i) -> Dictionary:
	ensure_ready()
	refresh_cache()
	if not site_cache.has(site_tile):
		site_cache[site_tile] = nearest_store(site_tile)
	return site_cache[site_tile]

# --- Paths -------------------------------------------------------------------------------------

# Adds foot traffic along a route: trips are one-way walks (there and back is 2).
func add_wear(route: Array, trips: float) -> void:
	if trips <= 0.0:
		return
	for tile: Vector2i in route:
		if is_wearable(city.local_map[tile.y][tile.x]):
			wear[tile] = float(wear.get(tile, 0.0)) + trips

# A builder carried one unit of material from the nearest store to a site and walked back.
func record_site_delivery(site_tile: Vector2i) -> void:
	if has_map():
		add_wear(get_site_store_route(site_tile)["route"], 2.0 / EconomyBalance.CARRY_LOAD)

# End of a day: every workplace that worked wears its family's walk from home (there and back)
# and its carrying trips to the store, the same travel get_travel charges it for; then wear
# fades, and tiles whose wear crossed a threshold change path level. A change of level changes
# routes, so it counts as a layout change.
func advance_day() -> void:
	if not has_map():
		return
	ensure_ready()
	for building: Building in city.buildings:
		if not building.can_produce():
			continue
		var travel: Dictionary = get_travel(building)
		if travel["reachable"] != true:
			continue
		add_wear(get_commute(building)["route"], 2.0)
		add_wear(get_store_route(building)["route"], get_daily_units(city, building) / EconomyBalance.CARRY_LOAD * 2.0)
	if update_path_levels():
		paths_version += 1
		mark_layout_changed()

# Applies a day's fading and sets each worn tile's path level; returns whether any level changed.
func update_path_levels() -> bool:
	var changed: bool = false
	for tile: Vector2i in wear.keys():
		var data: Dictionary = city.local_map[tile.y][tile.x]
		var amount: float = float(wear[tile]) if is_wearable(data) else 0.0
		var level: int = get_path_level_for(amount, get_path_level(data))
		if level != get_path_level(data):
			data["path_level"] = level
			changed = true
		amount *= 1.0 - EconomyBalance.PATH_WEAR_DECAY
		if amount < WEAR_FLOOR and level == PATH_NONE:
			wear.erase(tile)
		else:
			wear[tile] = amount
	return changed

# The level a tile with this wear settles at: up a level at its threshold, down only below half.
static func get_path_level_for(amount: float, current: int) -> int:
	if amount >= EconomyBalance.PATH_WEAR:
		return PATH_WORN
	if current == PATH_WORN and amount >= EconomyBalance.PATH_WEAR * 0.5:
		return PATH_WORN
	if amount >= EconomyBalance.TRAIL_WEAR:
		return PATH_TRAIL
	if current >= PATH_TRAIL and amount >= EconomyBalance.TRAIL_WEAR * 0.5:
		return PATH_TRAIL
	return PATH_NONE

static func get_path_level(tile: Dictionary) -> int:
	return int(tile.get("path_level", PATH_NONE))

# Share of the tiles a workplace's routes cross (to the store, from home) that are trail, path,
# or road; for its card.
func get_trodden_share(building: Building) -> float:
	var total: int = 0
	var trodden: int = 0
	for route: Array in [get_store_route(building)["route"], get_commute(building)["route"]]:
		for i in range(1, route.size()):
			var tile: Dictionary = city.local_map[route[i].y][route[i].x]
			total += 1
			if tile.get("has_road", false) == true or get_path_level(tile) != PATH_NONE:
				trodden += 1
	return float(trodden) / float(total) if total > 0 else 0.0
