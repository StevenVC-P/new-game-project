class_name TownLogistics
extends RefCounted

# How goods move around a town. Goods are kept in stores: the founders' stockpile at the town's
# heart and any storehouses built since. A workplace's family carries its output to the nearest
# store and its inputs back, and walks from home to work; that travel takes part of its day, so a
# workplace far from a store or from its family's home produces less. Builders carry materials
# from the nearest store to a site the same way (TownConstruction).
#
# Travel is aggregated, not simulated per item: routes are found once per town layout and each
# workplace's daily trips become a share of its family's working day. All stores share one
# stock, City.resources; separate inventories per store are later work.
#
# Routes run on a grid at half-tile spacing (cells): a cell in each tile's middle, one on each
# line between two tiles, and one at each corner where four meet. So people can walk through a
# tile or along its edge: between two fields, or along a fence, without stepping on either.
# Weighted by ground (roads fast; woods, hills, and rock slow; water impassable), and found with
# AStarGrid2D.
#
# The trips wear the cells they cross. Wear builds up where people walk and fades where they
# stop; enough of it makes a trail, then a path, which are quicker to walk, so routes bend toward
# them and wear them further (desire paths). Nobody walks through a building, a building site, or
# the stockpile, only along the strips between them; walking through someone's field tramples its
# crops, and a fenced field is walked around.
# Design: docs/TOWN_BUILDING_MODEL.md. A town without a town map (balance tools) has no travel.

const STOCKPILE_SIZE: Vector2i = Vector2i(2, 2)
const DIAGONAL_STEP: float = 1.41421356
# Cell steps are half a tile.
const CELL_STEP: float = 0.5
const CELL_DIAGONAL_STEP: float = 0.70710678
# How worn a cell is.
const PATH_NONE: int = 0
const PATH_TRAIL: int = 1
const PATH_WORN: int = 2
# Wear this small is gone.
const WEAR_FLOOR: float = 0.5
# Footprint owner ids (per tile): buildings by their id, then the other things that occupy land.
const OWNER_NONE: int = -1
const OWNER_PROJECT: int = 1000000
const OWNER_PLOT: int = 2000000
const OWNER_STOCKPILE: int = 3000000
const OWNER_OTHER: int = 4000000
const TILE_WOODED: int = 1
const TILE_WATER: int = 2
const TILE_ROAD: int = 4
const CELL_WEARABLE: int = 1
const CELL_IN_WOODS: int = 2
const CELL_BETWEEN_BUILDINGS: int = 4

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
# Bumped whenever routes may change: layout changes and path levels changing.
var routes_version: int = 0
var grid_version: int = -1
var grid: AStarGrid2D = null
# Per grid build: each cell's effort (INF where it cannot be crossed) and the footprint it lies
# inside, each tile's footprint owner and values, and the cells a fence closes, by building id.
var cell_effort: PackedFloat32Array = PackedFloat32Array()
var tile_owner: PackedInt32Array = PackedInt32Array()
var cell_inside: PackedInt32Array = PackedInt32Array()
var tile_base: PackedFloat32Array = PackedFloat32Array()
var tile_margin: PackedFloat32Array = PackedFloat32Array()
var tile_open: PackedByteArray = PackedByteArray()
# Per tile: 1 wooded, 2 water, 4 road. Per cell: CELL_WEARABLE and CELL_IN_WOODS.
var tile_kind: PackedByteArray = PackedByteArray()
var cell_flags: PackedByteArray = PackedByteArray()
# Cells closed to every route that does not start or end in their footprint, by footprint owner.
var closed_cells: Dictionary = {}
# Travel figures for the current routes: building id -> store route, [building id, household
# id] -> walk to work. Cleared when routes change.
var cache_version: int = -1
var store_cache: Dictionary = {}
var commute_cache: Dictionary = {}
var site_cache: Dictionary = {}
# Foot traffic: cell -> wear, only for cells walked recently; cell -> path level, for worn ones.
var cell_wear: Dictionary = {}
var cell_levels: Dictionary = {}
# Bumped whenever a cell's path level changes, so views redraw the ground.
var paths_version: int = 0
# Trips a day that crossed each field (building id), counted today, and yesterday's, which the
# field's harvest pays for (City.apply_building_output_modifiers).
var trampling_today: Dictionary = {}
var trampled_trips: Dictionary = {}

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func map_size() -> Vector2i:
	if not has_map():
		return Vector2i.ZERO
	return Vector2i((city.local_map[0] as Array).size(), city.local_map.size())

func cell_size() -> Vector2i:
	return map_size() * 2 + Vector2i.ONE

func mark_layout_changed() -> void:
	layout_version += 1
	routes_version += 1

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

# --- Cells -------------------------------------------------------------------------------------

static func tile_cell(tile: Vector2i) -> Vector2i:
	return tile * 2 + Vector2i.ONE

static func is_tile_cell(cell: Vector2i) -> bool:
	return cell.x % 2 == 1 and cell.y % 2 == 1

# The tile a cell lies in or on the edge of, rounding toward the top left: for drawing and for
# reading tile data.
static func cell_tile(cell: Vector2i) -> Vector2i:
	return Vector2i((cell.x - 1) / 2 if cell.x % 2 == 1 else cell.x / 2, (cell.y - 1) / 2 if cell.y % 2 == 1 else cell.y / 2)

# Where a cell sits on the map, in tiles.
static func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell) * 0.5

# The tiles a cell touches: one for a tile's middle, two for a line, up to four for a corner
# (fewer at the map's edge).
func cell_tiles(cell: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = map_size()
	var span: Rect2i = cell_tile_span(cell)
	var tiles: Array[Vector2i] = []
	for y in range(span.position.y, span.end.y):
		for x in range(span.position.x, span.end.x):
			if x >= 0 and y >= 0 and x < size.x and y < size.y:
				tiles.append(Vector2i(x, y))
	return tiles

# The tiles around a cell, before clipping to the map: 1x1, 2x1, 1x2, or 2x2.
static func cell_tile_span(cell: Vector2i) -> Rect2i:
	var x0: int = (cell.x - 1) / 2 if cell.x % 2 == 1 else cell.x / 2 - 1
	var y0: int = (cell.y - 1) / 2 if cell.y % 2 == 1 else cell.y / 2 - 1
	return Rect2i(x0, y0, 1 if cell.x % 2 == 1 else 2, 1 if cell.y % 2 == 1 else 2)

func tile_data(tile: Vector2i) -> Dictionary:
	return city.local_map[tile.y][tile.x]

# --- Effort ------------------------------------------------------------------------------------

# Effort to cross a tile's middle, in effort-tiles; INF where it cannot be crossed. Terrain, then
# cover, then wear.
static func tile_effort(tile: Dictionary, path_level: int = PATH_NONE) -> float:
	if tile["type"] == "water":
		return INF
	if tile.get("has_road", false) == true:
		return EconomyBalance.ROAD_EFFORT
	if tile["occupied"] == true:
		return EconomyBalance.BUILT_EFFORT
	return ground_effort(tile) * path_factor(path_level)

# The ground's own effort, without wear: terrain times cover.
static func ground_effort(tile: Dictionary) -> float:
	var effort: float = terrain_effort(tile)
	if tile["has_trees"] == true:
		effort *= EconomyBalance.WOODS_EFFORT
	return effort

static func terrain_effort(tile: Dictionary) -> float:
	if tile["type"] == "rough":
		return EconomyBalance.ROUGH_EFFORT
	if tile.get("is_hill", false) == true:
		return EconomyBalance.HILL_EFFORT
	return 1.0

static func path_factor(level: int) -> float:
	match level:
		PATH_TRAIL:
			return EconomyBalance.TRAIL_EFFORT_FACTOR
		PATH_WORN:
			return EconomyBalance.PATH_EFFORT_FACTOR
	return 1.0

# What walking along a tile's edge costs, from that side: built land and fields have an open
# margin as easy as their bare ground; other ground costs what crossing it does.
static func margin_effort(tile: Dictionary) -> float:
	if tile["type"] == "water":
		return INF
	if tile.get("has_road", false) == true:
		return EconomyBalance.ROAD_EFFORT
	if tile["occupied"] == true:
		return terrain_effort(tile)
	return ground_effort(tile)

static func cheapest_effort() -> float:
	return minf(EconomyBalance.ROAD_EFFORT, EconomyBalance.PATH_EFFORT_FACTOR)

# The footprint a cell lies inside, or OWNER_NONE: a tile's middle on built land, or a line or
# corner with the same footprint on every side.
func cell_inside_owner(cell: Vector2i) -> int:
	ensure_grid()
	return cell_inside[cell.y * cell_size().x + cell.x]

func owner_of(tile: Vector2i) -> int:
	return tile_owner[tile.y * map_size().x + tile.x] if not tile_owner.is_empty() else OWNER_NONE

# Cells foot traffic wears: open ground, and the lines and corners between things, but not water,
# roads, built land, or the inside of a footprint. Worked out per cell with the grid
# (compute_cell), as wear is laid on thousands of cells a day.
func is_cell_wearable(cell: Vector2i) -> bool:
	ensure_grid()
	return cell_flags[cell.y * cell_size().x + cell.x] & CELL_WEARABLE != 0

# A cell in woods: every tile it touches is wooded. Paths there wear slowly and stay trails.
func is_cell_in_woods(cell: Vector2i) -> bool:
	ensure_grid()
	return cell_flags[cell.y * cell_size().x + cell.x] & CELL_IN_WOODS != 0

# A line or corner with built land on every side: a strip between buildings. People walk it,
# but it stays a trail (owner, 2026-10-27); a line between a building and open land is open land.
func is_cell_between_buildings(cell: Vector2i) -> bool:
	ensure_grid()
	return cell_flags[cell.y * cell_size().x + cell.x] & CELL_BETWEEN_BUILDINGS != 0

# Kept per tile so a full rebuild reads each tile once: who occupies it.
func build_tile_owners() -> void:
	var size: Vector2i = map_size()
	tile_owner = PackedInt32Array()
	tile_owner.resize(size.x * size.y)
	tile_owner.fill(OWNER_NONE)
	for building: Building in city.buildings:
		set_owner(building.tile, building.size, building.id)
	for project: ConstructionProject in city.construction.projects:
		if project.kind == ConstructionProject.KIND_BUILDING and project.plot_id < 0:
			set_owner(project.tile, project.size, OWNER_PROJECT + project.id)
	for plot: Dictionary in city.construction.plots:
		set_owner(plot["tile"], plot["size"], OWNER_PLOT + int(plot["id"]))
	if stockpile_tile.x >= 0:
		set_owner(stockpile_tile, STOCKPILE_SIZE, OWNER_STOCKPILE)
	for y in range(size.y):
		for x in range(size.x):
			var i: int = y * size.x + x
			if tile_owner[i] == OWNER_NONE and (city.local_map[y][x] as Dictionary)["occupied"] == true:
				tile_owner[i] = OWNER_OTHER + i

func set_owner(origin: Vector2i, size: Vector2i, owner: int) -> void:
	var map: Vector2i = map_size()
	for tile: Vector2i in footprint(origin, size):
		if tile.x >= 0 and tile.y >= 0 and tile.x < map.x and tile.y < map.y:
			tile_owner[tile.y * map.x + tile.x] = owner

# Per tile, once per rebuild: the effort of its middle without wear, of its margin, and whether
# wear counts there (open land). A building's footprint is built land even where the tile was
# never marked occupied (tests and tools add buildings directly).
func build_tile_values() -> void:
	var size: Vector2i = map_size()
	tile_base.resize(size.x * size.y)
	tile_margin.resize(size.x * size.y)
	tile_open.resize(size.x * size.y)
	tile_kind.resize(size.x * size.y)
	for y in range(size.y):
		for x in range(size.x):
			var i: int = y * size.x + x
			var tile: Dictionary = city.local_map[y][x]
			tile_kind[i] = (TILE_WOODED if tile["has_trees"] == true else 0) | (TILE_WATER if tile["type"] == "water" else 0) | (TILE_ROAD if tile.get("has_road", false) == true else 0)
			if tile_owner[i] != OWNER_NONE and tile["occupied"] != true and tile["type"] != "water" and tile.get("has_road", false) != true:
				tile = tile.duplicate()
				tile["occupied"] = true
			tile_base[i] = tile_effort(tile)
			tile_margin[i] = margin_effort(tile)
			tile_open[i] = 1 if tile["type"] != "water" and tile.get("has_road", false) != true and tile["occupied"] != true else 0

# One cell's effort and the footprint it lies inside, from the per-tile values. A tile's middle
# costs the tile; a line or corner inside one footprint costs that footprint; any other line or
# corner costs the cheapest margin beside it. Wear lowers both, except on roads.
func compute_cell(cx: int, cy: int) -> void:
	var size: Vector2i = map_size()
	var span: Rect2i = cell_tile_span(Vector2i(cx, cy))
	var index: int = cy * (size.x * 2 + 1) + cx
	var level: int = PATH_NONE if cell_levels.is_empty() else int(cell_levels.get(Vector2i(cx, cy), PATH_NONE))
	if span.size == Vector2i.ONE:
		var i: int = span.position.y * size.x + span.position.x
		cell_inside[index] = tile_owner[i]
		cell_effort[index] = tile_base[i] * (path_factor(level) if tile_open[i] == 1 else 1.0)
		cell_flags[index] = (CELL_WEARABLE if tile_open[i] == 1 else 0) | (CELL_IN_WOODS if tile_kind[i] & TILE_WOODED != 0 else 0)
		return
	var effort: float = INF
	var owner: int = OWNER_NONE
	var one_footprint: bool = true
	var first: bool = true
	var all_wooded: bool = true
	var all_owned: bool = true
	var tiles_in_map: int = 0
	var any_land: bool = false
	var any_road: bool = false
	for ty in range(span.position.y, span.end.y):
		for tx in range(span.position.x, span.end.x):
			if tx < 0 or ty < 0 or tx >= size.x or ty >= size.y:
				one_footprint = false
				continue
			var i: int = ty * size.x + tx
			if first:
				owner = tile_owner[i]
				first = false
			elif tile_owner[i] != owner:
				one_footprint = false
			effort = minf(effort, tile_margin[i])
			all_wooded = all_wooded and tile_kind[i] & TILE_WOODED != 0
			all_owned = all_owned and tile_owner[i] != OWNER_NONE
			tiles_in_map += 1
			any_land = any_land or tile_kind[i] & TILE_WATER == 0
			any_road = any_road or tile_kind[i] & TILE_ROAD != 0
	var woods: int = CELL_IN_WOODS if all_wooded and not first else 0
	if one_footprint and owner != OWNER_NONE:
		cell_inside[index] = owner
		cell_effort[index] = EconomyBalance.BUILT_EFFORT
		cell_flags[index] = woods
		return
	cell_inside[index] = OWNER_NONE
	var between: int = CELL_BETWEEN_BUILDINGS if all_owned and tiles_in_map >= 2 else 0
	cell_flags[index] = woods | between | (CELL_WEARABLE if any_land and not any_road else 0)
	if not is_inf(effort) and effort != EconomyBalance.ROAD_EFFORT:
		effort *= path_factor(level)
	cell_effort[index] = effort

# Grid weights are efforts divided by the cheapest effort (a road), so no cell weighs less than a
# step: the grid's distance estimate then never overshoots, and A* finds the cheapest route
# rather than one that merely looks direct. Buildings, sites, the stockpile, and fenced fields are
# closed (solid); find_route opens the ones a route starts or ends in.
func ensure_grid() -> void:
	if grid_version == layout_version and grid != null:
		return
	grid_version = layout_version
	build_tile_owners()
	build_tile_values()
	var size: Vector2i = cell_size()
	grid = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	cell_effort.resize(size.x * size.y)
	cell_inside.resize(size.x * size.y)
	cell_flags.resize(size.x * size.y)
	closed_cells.clear()
	var closed: Dictionary = get_closed_owners()
	var cheapest: float = cheapest_effort()
	for y in range(size.y):
		for x in range(size.x):
			compute_cell(x, y)
			var index: int = y * size.x + x
			var effort: float = cell_effort[index]
			if is_inf(effort):
				grid.set_point_solid(Vector2i(x, y), true)
				continue
			grid.set_point_weight_scale(Vector2i(x, y), effort / cheapest)
			if closed.has(cell_inside[index]):
				var owner: int = cell_inside[index]
				grid.set_point_solid(Vector2i(x, y), true)
				if not closed_cells.has(owner):
					closed_cells[owner] = []
				(closed_cells[owner] as Array).append(Vector2i(x, y))
	close_fence_lines()

# A fence stands on a field's edge, so a fenced field closes its whole square: the lines and
# corners round it as well as its inside (owner, 2026-10-27). Two fenced fields side by side
# leave no way between them. Its own routes still open all of it (the gate).
func close_fence_lines() -> void:
	for building: Building in city.buildings:
		if not building.fenced:
			continue
		var cells: Array = []
		for y in range(building.tile.y * 2, (building.tile.y + building.size.y) * 2 + 1):
			for x in range(building.tile.x * 2, (building.tile.x + building.size.x) * 2 + 1):
				var cell: Vector2i = Vector2i(x, y)
				if not is_inf(cell_effort[y * cell_size().x + x]):
					grid.set_point_solid(cell, true)
					cells.append(cell)
		closed_cells[building.id] = cells

# Footprints people do not walk through (owner, 2026-10-27): every building but an unfenced field
# (a field can be crossed, at a cost to its harvest), every building site (a home rising on a
# plot too), and the stockpile. Open plots stay open.
func get_closed_owners() -> Dictionary:
	var closed: Dictionary = {}
	for building: Building in city.buildings:
		if building.fenced or not is_field(building):
			closed[building.id] = true
	for project: ConstructionProject in city.construction.projects:
		if project.kind == ConstructionProject.KIND_BUILDING and project.plot_id < 0:
			closed[OWNER_PROJECT + project.id] = true
	for plot: Dictionary in city.construction.plots:
		if int(plot["project_id"]) >= 0:
			closed[OWNER_PLOT + int(plot["id"])] = true
	if stockpile_tile.x >= 0:
		closed[OWNER_STOCKPILE] = true
	return closed

# A path level changed: the cell's weight follows, without rebuilding the grid.
func refresh_cell(cell: Vector2i) -> void:
	if grid == null or grid_version != layout_version:
		return
	compute_cell(cell.x, cell.y)
	var effort: float = cell_effort[cell.y * cell_size().x + cell.x]
	if not is_inf(effort):
		grid.set_point_weight_scale(cell, effort / cheapest_effort())

func get_cell_effort(cell: Vector2i) -> float:
	ensure_grid()
	return cell_effort[cell.y * cell_size().x + cell.x]

# --- Routes ------------------------------------------------------------------------------------

# The cells of the easiest route between two tiles' middles, both included; empty when none
# exists. A closed footprint (a building, a site, a fenced field) the route starts or ends in is
# open to it: the family goes in at its own door or gate, and builders onto their own site.
func find_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not has_map():
		return route
	ensure_grid()
	var start: Vector2i = tile_cell(from)
	var goal: Vector2i = tile_cell(to)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal):
		return route
	var opened: Array = []
	for tile: Vector2i in [from, to]:
		var owner: int = owner_of(tile)
		if closed_cells.has(owner) and not opened.has(owner):
			opened.append(owner)
	for owner: int in opened:
		for cell: Vector2i in closed_cells[owner]:
			grid.set_point_solid(cell, false)
	if not grid.is_point_solid(start) and not grid.is_point_solid(goal):
		for cell: Vector2i in grid.get_id_path(start, goal):
			route.append(cell)
	for owner: int in opened:
		for cell: Vector2i in closed_cells[owner]:
			grid.set_point_solid(cell, true)
	return route

# Effort along a route: each step costs its length times the effort of the cell it enters.
func route_effort(route: Array) -> float:
	var effort: float = 0.0
	for i in range(1, route.size()):
		var step: Vector2i = route[i] - route[i - 1]
		var length: float = CELL_DIAGONAL_STEP if step.x != 0 and step.y != 0 else CELL_STEP
		effort += length * get_cell_effort(route[i])
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
	if cache_version == routes_version:
		return
	cache_version = routes_version
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

# --- Paths and trampling -----------------------------------------------------------------------

# Adds foot traffic along a route: trips are one-way walks (there and back is 2). Woods wear
# slowly. Fields the route crosses, other than ones it starts or ends in, are trampled.
func add_traffic(route: Array, trips: float) -> void:
	if trips <= 0.0 or route.is_empty():
		return
	ensure_grid()
	var crossed: Dictionary = {}
	var ends: Array[int] = [owner_of(cell_tile(route[0])), owner_of(cell_tile(route[route.size() - 1]))]
	# Read straight from the per-cell arrays: wear is laid on thousands of cells a day.
	var width: int = cell_size().x
	var in_woods: float = trips * EconomyBalance.FOREST_WEAR_FACTOR
	for cell: Vector2i in route:
		var index: int = cell.y * width + cell.x
		var flags: int = cell_flags[index]
		if flags & CELL_WEARABLE != 0:
			cell_wear[cell] = float(cell_wear.get(cell, 0.0)) + (in_woods if flags & CELL_IN_WOODS != 0 else trips)
			continue
		var inside: int = cell_inside[index]
		if inside >= 0 and inside < OWNER_PROJECT and not ends.has(inside) and is_field(city.buildings[inside]):
			crossed[inside] = true
	for field: int in crossed.keys():
		trampling_today[field] = float(trampling_today.get(field, 0.0)) + trips

static func is_field(building: Building) -> bool:
	return BuildingTiers.get_base_type(building.type) == Building.BUILDING_FARM

# A builder carried one unit of material from the nearest store to a site and walked back.
func record_site_delivery(site_tile: Vector2i) -> void:
	if has_map():
		add_traffic(get_site_store_route(site_tile)["route"], 2.0 / EconomyBalance.CARRY_LOAD)

# End of a day: every workplace that worked lays its family's walk from home (there and back)
# and its carrying trips to the store, the same travel get_travel charges it for, and every
# family lays its errands (TownErrands), which cost no one's work. Then wear
# fades, cells whose wear crossed a threshold change path level (and their routes with them),
# and today's trampling becomes what the fields' harvests pay for tomorrow.
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
		add_traffic(get_commute(building)["route"], 2.0)
		add_traffic(get_store_route(building)["route"], get_daily_units(city, building) / EconomyBalance.CARRY_LOAD * 2.0)
	city.errands.add_daily_traffic()
	trampled_trips = trampling_today
	trampling_today = {}
	var changed: Array[Vector2i] = update_path_levels()
	if not changed.is_empty():
		paths_version += 1
		routes_version += 1
		for cell: Vector2i in changed:
			refresh_cell(cell)

# Applies a day's fading and sets each worn cell's path level; returns the cells whose level
# changed.
func update_path_levels() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	ensure_grid()
	var width: int = cell_size().x
	for cell: Vector2i in cell_wear.keys():
		var flags: int = cell_flags[cell.y * width + cell.x]
		var amount: float = float(cell_wear[cell]) if flags & CELL_WEARABLE != 0 else 0.0
		var current: int = int(cell_levels.get(cell, PATH_NONE))
		var level: int = get_path_level_for(amount, current)
		if flags & (CELL_IN_WOODS | CELL_BETWEEN_BUILDINGS) != 0:
			level = mini(level, PATH_TRAIL)
		if level != current:
			set_cell_path_level(cell, level)
			changed.append(cell)
		amount *= 1.0 - EconomyBalance.PATH_WEAR_DECAY
		if amount < WEAR_FLOOR and level == PATH_NONE:
			cell_wear.erase(cell)
		else:
			cell_wear[cell] = amount
	return changed

# The level a cell with this wear settles at: up a level at its threshold, down only below half.
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

func get_cell_path_level(cell: Vector2i) -> int:
	return int(cell_levels.get(cell, PATH_NONE))

func get_tile_path_level(tile: Vector2i) -> int:
	return get_cell_path_level(tile_cell(tile))

# Sets a level directly (tests and tools); play sets levels from wear.
func set_cell_path_level(cell: Vector2i, level: int) -> void:
	if level == PATH_NONE:
		cell_levels.erase(cell)
	else:
		cell_levels[cell] = level

func set_tile_path_level(tile: Vector2i, level: int) -> void:
	set_cell_path_level(tile_cell(tile), level)
	routes_version += 1
	refresh_cell(tile_cell(tile))

# Share of a field's harvest lost to people walking through it: yesterday's trips across it.
func get_field_trample_loss(building: Building) -> float:
	var trips: float = float(trampled_trips.get(building.id, 0.0))
	return minf(EconomyBalance.FIELD_TRAMPLE_MAX_LOSS, trips * EconomyBalance.FIELD_TRAMPLE_LOSS_PER_TRIP)

# Share of the cells a workplace's routes cross (to the store, from home) that are trail, path,
# or road; for its card.
func get_trodden_share(building: Building) -> float:
	var total: int = 0
	var trodden: int = 0
	for route: Array in [get_store_route(building)["route"], get_commute(building)["route"]]:
		for i in range(1, route.size()):
			var cell: Vector2i = route[i]
			total += 1
			if get_cell_path_level(cell) != PATH_NONE or is_equal_approx(get_cell_effort(cell), EconomyBalance.ROAD_EFFORT):
				trodden += 1
	return float(trodden) / float(total) if total > 0 else 0.0
