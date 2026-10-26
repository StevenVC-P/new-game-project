class_name RegionMapGeometry
extends RefCounted

# Drawable shapes derived from the region's data: smoothed roads, bridges where roads
# actually cross rivers, settlement footprints, and fields on fertile land. Built once per
# data change and shared by the layers (trees, for example, keep clear of roads and houses).
# Presentation only: nothing here feeds back into the simulation, and nothing is drawn that
# the data does not support (fields only on fertile tiles, buildings never on forest, water,
# mountains, or deposits, a quarry only when the player's town has one).

const ROAD_PATH: int = 0
const ROAD_ROAD: int = 1
const ROAD_MAJOR: int = 2

# Half widths in map units, by road class.
const ROAD_HALF_WIDTHS: Array[float] = [0.8, 1.35, 1.9]
# Trees stay this far (map units) beyond a road's edge, leaving a cleared verge.
const ROAD_VERGE: float = 1.6
# Resolution of the clearance grid used to keep trees off roads and out of settlements.
const CLEAR_CELLS_PER_TILE: int = 2

const BUILDING_SPACING: float = 5.2
const QUARRY_SEARCH_TILES: int = 7

class RoadShape:
	var points: PackedVector2Array = PackedVector2Array()
	var road_class: int = ROAD_PATH
	# Where the road leads beyond the map edge, "" for roads between towns.
	var toward: String = ""
	var edge_point: Vector2 = Vector2.ZERO
	# Drawn elsewhere (a world road the chunks draw); still lines streets and clears trees.
	var is_context: bool = false

class BridgeShape:
	var center: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var length: float = 0.0
	var width: float = 0.0
	var is_stone: bool = false

class BuildingShape:
	var position: Vector2 = Vector2.ZERO
	var size: Vector2 = Vector2(3.0, 2.0)
	var angle: float = 0.0
	var roof: Color = Color.WHITE
	# "house", "hall", or "church" (a hall with a tower).
	var kind: String = "house"

class SettlementShape:
	var city_index: int = -1
	var name: String = ""
	var center: Vector2 = Vector2.ZERO
	var tier: int = RegionMapStyle.TIER_HAMLET
	var is_player: bool = false
	var radius: float = 10.0
	var plaza_radius: float = 0.0
	# "", "palisade", or "wall"
	var enclosure: String = ""
	var enclosure_radius: float = 0.0
	var buildings: Array[BuildingShape] = []

class FieldShape:
	var corners: PackedVector2Array = PackedVector2Array()
	var color: Color = Color.WHITE
	var furrow_angle: float = 0.0

class QuarryShape:
	var center: Vector2 = Vector2.ZERO
	var radius: float = 5.0

var tiles: Array = []
var cities: Array[City] = []
var geography: RegionGeography = null
var map_size: Vector2i = Vector2i.ZERO
# Tile of tiles[0][0]. Shapes are in map units of this tile space: tile t covers
# t * TILE .. (t + 1) * TILE. Zero for a bounded region; a global tile on the continuous map.
var tile_origin: Vector2i = Vector2i.ZERO
# World tier by settlement name, for towns that are world settlements on the continuous map.
var world_tiers: Dictionary = {}

var roads: Array[RoadShape] = []
var bridges: Array[BridgeShape] = []
var settlements: Array[SettlementShape] = []
var fields: Array[FieldShape] = []
var quarries: Array[QuarryShape] = []
var clear_grid: PackedByteArray = PackedByteArray()

# context_roads: world roads drawn by the continuous map's chunks; settlements line their
# streets along them and trees keep clear of them, but this geometry does not draw them.
func build(region_tiles: Array, region_cities: Array[City], road_paths: Array[Array], region_geography: RegionGeography, context_roads: Array[RoadShape] = []) -> void:
	begin(region_tiles, Vector2i.ZERO)
	cities = region_cities
	geography = region_geography
	if map_size == Vector2i.ZERO:
		return
	build_roads(road_paths)
	add_context_roads(context_roads)
	build_bridges()
	for city_index in range(cities.size()):
		build_settlement(city_index)
	for settlement: SettlementShape in settlements:
		build_fields(settlement)
	build_quarries()

# Clears the shapes and takes a new window of tiles starting at the given tile. A window
# without tiles (size given) only clears ground for trees, as a chunk's roads do.
func begin(window_tiles: Array, window_origin: Vector2i, window_size: Vector2i = Vector2i.ZERO) -> void:
	tiles = window_tiles
	tile_origin = window_origin
	cities = []
	map_size = Vector2i((tiles[0] as Array).size(), tiles.size()) if not tiles.is_empty() else window_size
	roads.clear()
	bridges.clear()
	settlements.clear()
	fields.clear()
	quarries.clear()
	clear_grid = PackedByteArray()
	clear_grid.resize(map_size.x * map_size.y * CLEAR_CELLS_PER_TILE * CLEAR_CELLS_PER_TILE)

# Roads drawn elsewhere that still shape this geometry (see build()).
func add_context_roads(context_roads: Array[RoadShape]) -> void:
	for road: RoadShape in context_roads:
		roads.append(road)
		mark_road_cleared(road)

# --- Lookups -------------------------------------------------------------------

func tile_at(map_point: Vector2) -> Dictionary:
	var tile: Vector2i = Vector2i((map_point / RegionMapStyle.TILE).floor()) - tile_origin
	if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
		return {}
	return tiles[tile.y][tile.x]

static func tile_center(tile: Vector2) -> Vector2:
	return (tile + Vector2(0.5, 0.5)) * RegionMapStyle.TILE

func map_origin() -> Vector2:
	return Vector2(tile_origin) * RegionMapStyle.TILE

# Open land a building or field may stand on: not water, mountain, forest, or a deposit.
func is_open_land(map_point: Vector2) -> bool:
	var tile: Dictionary = tile_at(map_point)
	if tile.is_empty():
		return false
	var tile_type: String = tile["type"]
	if tile_type == "river" or tile_type == "lake" or tile_type == "sea" or tile_type == "mountain":
		return false
	return tile["has_forest"] == false and tile["resource"] == "none"

func is_cleared(map_point: Vector2) -> bool:
	var cell: Vector2i = Vector2i(((map_point - map_origin()) / RegionMapStyle.TILE * CLEAR_CELLS_PER_TILE).floor())
	var width: int = map_size.x * CLEAR_CELLS_PER_TILE
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= map_size.y * CLEAR_CELLS_PER_TILE:
		return false
	return clear_grid[cell.y * width + cell.x] == 1

func mark_cleared(map_center: Vector2, radius: float) -> void:
	var center: Vector2 = map_center - map_origin()
	var cell_size: float = RegionMapStyle.TILE / CLEAR_CELLS_PER_TILE
	var width: int = map_size.x * CLEAR_CELLS_PER_TILE
	var height: int = map_size.y * CLEAR_CELLS_PER_TILE
	for y in range(maxi(0, int((center.y - radius) / cell_size)), mini(height, int((center.y + radius) / cell_size) + 1)):
		for x in range(maxi(0, int((center.x - radius) / cell_size)), mini(width, int((center.x + radius) / cell_size) + 1)):
			var cell_center: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_size
			if cell_center.distance_to(center) <= radius + cell_size * 0.5:
				clear_grid[y * width + x] = 1

func distance_to_roads(map_point: Vector2) -> float:
	var best: float = INF
	for road: RoadShape in roads:
		for i in range(road.points.size() - 1):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(map_point, road.points[i], road.points[i + 1])
			best = minf(best, closest.distance_to(map_point) - ROAD_HALF_WIDTHS[road.road_class])
	return best

# --- Roads and bridges -------------------------------------------------------------

func build_roads(road_paths: Array[Array]) -> void:
	for path: Array in road_paths:
		if path.size() < 2:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for tile: Vector2 in path:
			points.append(tile_center(tile))
		var road: RoadShape = RoadShape.new()
		road.road_class = ROAD_ROAD
		var start_tile: Vector2 = path[0]
		var end_tile: Vector2 = path[path.size() - 1]
		var edge_end: int = -1
		if is_edge_tile(end_tile):
			edge_end = 1
		elif is_edge_tile(start_tile):
			edge_end = 0
		if edge_end >= 0:
			var edge_tile: Vector2 = end_tile if edge_end == 1 else start_tile
			# Run the road off the board so it visibly continues beyond the region.
			var outside: Vector2 = tile_center(edge_tile) + edge_outward(edge_tile) * RegionMapStyle.TILE * 0.6
			if edge_end == 1:
				points.append(outside)
			else:
				points.insert(0, outside)
			road.edge_point = outside
			road.road_class = ROAD_PATH
			var exit: RegionGeography.RoadExit = nearest_world_exit(edge_tile)
			if exit != null:
				road.road_class = ROAD_MAJOR if exit.road_class == WorldMapData.ROAD_MAJOR else ROAD_ROAD
				road.toward = exit.toward
		road.points = chaikin(points, 3)
		roads.append(road)
	# Wider roads draw last so they cover the paths that share their roadbed.
	roads.sort_custom(func(a: RoadShape, b: RoadShape) -> bool: return a.road_class < b.road_class)
	for road: RoadShape in roads:
		mark_road_cleared(road)

func mark_road_cleared(road: RoadShape) -> void:
	var map_bounds: Rect2 = Rect2(map_origin(), Vector2(map_size) * RegionMapStyle.TILE).grow(RegionMapStyle.TILE)
	for i in range(road.points.size() - 1):
		var a: Vector2 = road.points[i]
		var b: Vector2 = road.points[i + 1]
		if not map_bounds.has_point(a) and not map_bounds.has_point(b):
			continue
		var steps: int = maxi(1, ceili(a.distance_to(b) / 2.0))
		for step in range(steps + 1):
			mark_cleared(a.lerp(b, float(step) / steps), ROAD_HALF_WIDTHS[road.road_class] + ROAD_VERGE)

func is_edge_tile(tile: Vector2) -> bool:
	return tile.x <= 0 or tile.y <= 0 or tile.x >= map_size.x - 1 or tile.y >= map_size.y - 1

func edge_outward(tile: Vector2) -> Vector2:
	if tile.x <= 0:
		return Vector2.LEFT
	if tile.x >= map_size.x - 1:
		return Vector2.RIGHT
	if tile.y <= 0:
		return Vector2.UP
	return Vector2.DOWN

func nearest_world_exit(edge_tile: Vector2) -> RegionGeography.RoadExit:
	if geography == null:
		return null
	var best: RegionGeography.RoadExit = null
	var best_distance: float = 12.0
	for exit: RegionGeography.RoadExit in geography.road_exits:
		var distance: float = Vector2(exit.tile).distance_to(edge_tile)
		if distance < best_distance:
			best_distance = distance
			best = exit
	return best

# A bridge spans each stretch of road that lies over river tiles (the data's fords).
func build_bridges() -> void:
	build_bridges_where(func(point: Vector2) -> bool:
		var tile: Dictionary = tile_at(point)
		return not tile.is_empty() and tile["type"] == "river")

func build_bridges_where(is_over_river: Callable) -> void:
	for road: RoadShape in roads:
		if road.is_context:
			continue
		var run_start: int = -1
		for i in range(road.points.size()):
			var over_river: bool = is_over_river.call(road.points[i])
			if over_river and run_start < 0:
				run_start = i
			elif not over_river and run_start >= 0:
				add_bridge(road, maxi(run_start - 1, 0), i)
				run_start = -1
		if run_start >= 0:
			add_bridge(road, maxi(run_start - 1, 0), road.points.size() - 1)

func add_bridge(road: RoadShape, from_index: int, to_index: int) -> void:
	var a: Vector2 = road.points[from_index]
	var b: Vector2 = road.points[to_index]
	if a.distance_to(b) < 1.0:
		return
	var bridge: BridgeShape = BridgeShape.new()
	bridge.center = (a + b) * 0.5
	bridge.angle = (b - a).angle()
	bridge.length = a.distance_to(b) + 2.0
	bridge.width = ROAD_HALF_WIDTHS[road.road_class] * 2.0 + 0.8
	bridge.is_stone = road.road_class == ROAD_MAJOR
	bridges.append(bridge)

static func chaikin(points: PackedVector2Array, passes: int) -> PackedVector2Array:
	var result: PackedVector2Array = points
	for _pass in range(passes):
		if result.size() < 3:
			return result
		var smoothed: PackedVector2Array = PackedVector2Array([result[0]])
		for i in range(result.size() - 1):
			smoothed.append(result[i].lerp(result[i + 1], 0.25))
			smoothed.append(result[i].lerp(result[i + 1], 0.75))
		smoothed.append(result[result.size() - 1])
		result = smoothed
	return result

# --- Settlements ------------------------------------------------------------------

# Drawing tier: the simulated population, raised to the world map's tier when the town is
# a world settlement (the world map is the authority on how developed it looks).
func settlement_tier(city: City) -> int:
	var population: int = city.get_total_population()
	var tier: int = RegionMapStyle.TIER_HAMLET
	if population >= 400:
		tier = RegionMapStyle.TIER_LARGE_TOWN
	elif population >= 120:
		tier = RegionMapStyle.TIER_TOWN
	elif population >= 40:
		tier = RegionMapStyle.TIER_VILLAGE
	if geography != null:
		for site: RegionGeography.SettlementSite in geography.settlements:
			if site.name == city.name:
				tier = maxi(tier, mini(site.tier, RegionMapStyle.TIER_LARGE_TOWN))
	if world_tiers.has(city.name):
		tier = maxi(tier, mini(int(world_tiers[city.name]), RegionMapStyle.TIER_LARGE_TOWN))
	return tier

func building_target(city: City, tier: int) -> int:
	if city.is_player_city():
		# The player's town grows on the regional map as it is built up on the town map.
		return clampi(4 + city.buildings.size(), 4, 60)
	return [5, 11, 22, 38][tier]

func build_settlement(city_index: int) -> void:
	var city: City = cities[city_index]
	var tier: int = settlement_tier(city)
	add_settlement(city_index, city.name, city.tile, tier, city.is_player_city(), building_target(city, tier))

# A world settlement the simulation does not run, drawn from its world tier alone.
func add_world_settlement(settlement_name: String, tile: Vector2, world_tier: int) -> SettlementShape:
	var tier: int = mini(world_tier, RegionMapStyle.TIER_LARGE_TOWN)
	return add_settlement(-1, settlement_name, tile, tier, false, [5, 11, 22, 38][tier])

func add_settlement(city_index: int, settlement_name: String, tile: Vector2, tier: int, is_player: bool, target: int) -> SettlementShape:
	var shape: SettlementShape = SettlementShape.new()
	shape.city_index = city_index
	shape.name = settlement_name
	shape.center = tile_center(tile)
	shape.is_player = is_player
	shape.tier = tier
	shape.radius = [15.0, 24.0, 34.0, 46.0][shape.tier]
	if shape.tier >= RegionMapStyle.TIER_TOWN:
		shape.plaza_radius = 4.5 + shape.tier * 1.2
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(settlement_name + str(tile))
	var grid_angle: float = rng.randf_range(-0.6, 0.6)
	var roof_choices: Array[Color] = roof_palette(shape.tier)

	# The landmark: a hall in villages, a church with a tower in towns.
	if shape.tier >= RegionMapStyle.TIER_VILLAGE:
		var landmark: BuildingShape = BuildingShape.new()
		landmark.kind = "church" if shape.tier >= RegionMapStyle.TIER_TOWN else "hall"
		landmark.size = Vector2(7.6, 4.6) if landmark.kind == "church" else Vector2(6.4, 4.2)
		landmark.angle = grid_angle
		landmark.roof = COLOR_LANDMARK_ROOF
		landmark.position = shape.center + Vector2(0.0, -(shape.plaza_radius + 3.4)).rotated(grid_angle)
		if is_open_land(landmark.position):
			shape.buildings.append(landmark)

	for candidate: Vector3 in building_candidates(shape, grid_angle, rng):
		if shape.buildings.size() >= target:
			break
		var position: Vector2 = Vector2(candidate.x, candidate.y)
		if not can_place_building(shape, position):
			continue
		var building: BuildingShape = BuildingShape.new()
		building.position = position
		building.angle = candidate.z
		building.size = Vector2(rng.randf_range(4.0, 5.4), rng.randf_range(2.8, 3.4))
		building.roof = roof_choices[rng.randi_range(0, roof_choices.size() - 1)]
		shape.buildings.append(building)

	var reach: float = shape.plaza_radius
	for building: BuildingShape in shape.buildings:
		reach = maxf(reach, building.position.distance_to(shape.center) + 2.0)
		mark_cleared(building.position, 3.6)
	mark_cleared(shape.center, maxf(shape.plaza_radius, 3.0))
	if shape.tier == RegionMapStyle.TIER_TOWN:
		shape.enclosure = "palisade"
	elif shape.tier == RegionMapStyle.TIER_LARGE_TOWN:
		shape.enclosure = "wall"
	shape.enclosure_radius = reach + 1.5
	settlements.append(shape)
	return shape

const COLOR_LANDMARK_ROOF: Color = Color(0.45, 0.42, 0.44)

func roof_palette(tier: int) -> Array[Color]:
	match tier:
		RegionMapStyle.TIER_HAMLET:
			return [RegionMapStyle.COLOR_ROOF_THATCH, RegionMapStyle.COLOR_ROOF_THATCH, RegionMapStyle.COLOR_ROOF_TIMBER]
		RegionMapStyle.TIER_VILLAGE:
			return [RegionMapStyle.COLOR_ROOF_THATCH, RegionMapStyle.COLOR_ROOF_THATCH, RegionMapStyle.COLOR_ROOF_TIMBER, RegionMapStyle.COLOR_ROOF_TILE]
		RegionMapStyle.TIER_TOWN:
			return [RegionMapStyle.COLOR_ROOF_TILE, RegionMapStyle.COLOR_ROOF_TIMBER, RegionMapStyle.COLOR_ROOF_THATCH, RegionMapStyle.COLOR_ROOF_TILE]
	return [RegionMapStyle.COLOR_ROOF_TILE, RegionMapStyle.COLOR_ROOF_TILE, RegionMapStyle.COLOR_ROOF_SLATE, RegionMapStyle.COLOR_ROOF_TIMBER]

# Candidate spots (x, y, facing angle): first along the roads leading out of town, so houses
# line the streets, then rings around the center.
func building_candidates(shape: SettlementShape, grid_angle: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	for road: RoadShape in roads:
		var outward: PackedVector2Array = road_from_center(road, shape.center)
		if outward.is_empty():
			continue
		var travelled: float = 0.0
		var next_mark: float = shape.plaza_radius + 3.4
		for i in range(outward.size() - 1):
			var a: Vector2 = outward[i]
			var b: Vector2 = outward[i + 1]
			var segment: float = a.distance_to(b)
			while next_mark <= travelled + segment and next_mark <= shape.radius:
				var point: Vector2 = a.lerp(b, (next_mark - travelled) / maxf(segment, 0.001))
				var tangent: Vector2 = (b - a).normalized()
				var normal: Vector2 = Vector2(-tangent.y, tangent.x)
				var setback: float = ROAD_HALF_WIDTHS[road.road_class] + 3.0
				candidates.append(Vector3(point.x + normal.x * setback, point.y + normal.y * setback, tangent.angle()))
				candidates.append(Vector3(point.x - normal.x * setback, point.y - normal.y * setback, tangent.angle()))
				next_mark += BUILDING_SPACING + rng.randf_range(0.0, 1.2)
			travelled += segment
	var ring: float = maxf(shape.plaza_radius + 4.4, 5.5)
	while ring <= shape.radius:
		var count: int = maxi(5, int(TAU * ring / BUILDING_SPACING))
		var phase: float = rng.randf() * TAU
		for k in range(count):
			var angle: float = phase + TAU * k / count
			var point: Vector2 = shape.center + Vector2(cos(angle), sin(angle)) * (ring + rng.randf_range(-0.8, 0.8))
			var facing: float = grid_angle if rng.randf() < 0.6 else angle + PI * 0.5
			candidates.append(Vector3(point.x, point.y, facing))
		ring += 4.6
	return candidates

# The part of a road that leaves this settlement, ordered outward; empty if the road does not start here.
func road_from_center(road: RoadShape, center: Vector2) -> PackedVector2Array:
	if road.points[0].distance_to(center) < RegionMapStyle.TILE:
		return road.points
	if road.points[road.points.size() - 1].distance_to(center) < RegionMapStyle.TILE:
		var reversed: PackedVector2Array = road.points.duplicate()
		reversed.reverse()
		return reversed
	return PackedVector2Array()

func can_place_building(shape: SettlementShape, position: Vector2) -> bool:
	if position.distance_to(shape.center) < shape.plaza_radius + 1.6:
		return false
	if not is_open_land(position):
		return false
	if distance_to_roads(position) < 2.2:
		return false
	for other: SettlementShape in settlements:
		if other.center.distance_to(position) < other.radius:
			return false
	for building: BuildingShape in shape.buildings:
		if building.position.distance_to(position) < BUILDING_SPACING * 0.92:
			return false
	return true

# --- Fields and extraction ------------------------------------------------------------

func cultivation_radius(settlement: SettlementShape) -> float:
	if settlement.city_index < 0:
		return RegionMapStyle.TILE * [2.0, 3.5, 5.0, 6.5][settlement.tier]
	var city: City = cities[settlement.city_index]
	if city.is_player_city():
		var farms: int = 0
		for town_building in city.buildings:
			if BuildingTiers.get_base_type(town_building.type) == "farm":
				farms += 1
		return RegionMapStyle.TILE * clampf(1.5 + farms * 0.6, 1.5, 7.0)
	return RegionMapStyle.TILE * [2.0, 3.5, 5.0, 6.5][settlement.tier]

# A patchwork of parcels on the fertile tiles around a settlement.
func build_fields(settlement: SettlementShape) -> void:
	var radius: float = cultivation_radius(settlement)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(settlement.name + "fields")
	var angle: float = rng.randf_range(-0.5, 0.5)
	var axis: Vector2 = Vector2(cos(angle), sin(angle))
	var across: Vector2 = Vector2(-axis.y, axis.x)
	# Long strips in furlong-like blocks; every other row is offset so seams do not line up.
	var cell: Vector2 = Vector2(13.0, 5.6)
	var reach: int = int(radius / cell.y) + 1
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var local: Vector2 = Vector2((i + 0.5 * (j % 2)) * cell.x, j * cell.y)
			var center: Vector2 = settlement.center + axis * local.x + across * local.y
			if center.distance_to(settlement.center) > radius * rng.randf_range(0.75, 1.1):
				continue
			if center.distance_to(settlement.center) < settlement.plaza_radius + 3.0:
				continue
			var tile: Dictionary = tile_at(center)
			if tile.is_empty() or tile["is_fertile"] != true or not is_open_land(center):
				continue
			if is_cleared(center) and distance_to_roads(center) < 1.0:
				continue
			if is_under_building(settlement, center):
				continue
			var half: Vector2 = Vector2(cell.x * rng.randf_range(0.36, 0.48), cell.y * rng.randf_range(0.36, 0.46))
			var field: FieldShape = FieldShape.new()
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				field.corners.append(center + axis * corner.x * half.x + across * corner.y * half.y)
			field.color = pick_field_color(rng.randf())
			field.furrow_angle = angle if rng.randf() < 0.5 else angle + PI * 0.5
			fields.append(field)

func is_under_building(settlement: SettlementShape, point: Vector2) -> bool:
	for building: BuildingShape in settlement.buildings:
		if building.position.distance_to(point) < 4.6:
			return true
	return false

static func pick_field_color(roll: float) -> Color:
	if roll < 0.38:
		return RegionMapStyle.COLOR_FIELD_WHEAT
	if roll < 0.66:
		return RegionMapStyle.COLOR_FIELD_GREEN
	if roll < 0.84:
		return RegionMapStyle.COLOR_FIELD_PASTURE
	return RegionMapStyle.COLOR_FIELD_FALLOW

# A worked quarry on the stone deposit nearest the player's town, once the town has a quarry.
func build_quarries() -> void:
	for city: City in cities:
		if not city.is_player_city() or not has_building_type(city, "quarry"):
			continue
		var best: Vector2 = Vector2(-1.0, -1.0)
		var best_distance: float = INF
		for y in range(maxi(0, int(city.tile.y) - QUARRY_SEARCH_TILES), mini(map_size.y, int(city.tile.y) + QUARRY_SEARCH_TILES + 1)):
			for x in range(maxi(0, int(city.tile.x) - QUARRY_SEARCH_TILES), mini(map_size.x, int(city.tile.x) + QUARRY_SEARCH_TILES + 1)):
				if tiles[y][x]["resource"] != "stone":
					continue
				var distance: float = Vector2(x, y).distance_to(city.tile)
				if distance < best_distance:
					best_distance = distance
					best = Vector2(x, y)
		if best.x >= 0.0:
			var quarry: QuarryShape = QuarryShape.new()
			quarry.center = tile_center(best)
			quarries.append(quarry)

static func has_building_type(city: City, base_type: String) -> bool:
	for building in city.buildings:
		if BuildingTiers.get_base_type(building.type) == base_type:
			return true
	return false
