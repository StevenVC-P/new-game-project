class_name WorldMapData
extends RefCounted

# The planet as data: geography fields, political regions, settlements, and infrastructure.
# Nothing here knows how it is drawn. Whatever changes the world later (simulation,
# a world generator, a save file) edits these objects and calls notify_changed(), and
# the world map renderer rebuilds only the affected layer.

signal changed(layer: String)

const LAYER_TERRAIN: String = "terrain"
const LAYER_POLITICAL: String = "political"
const LAYER_SETTLEMENTS: String = "settlements"
const LAYER_ROADS: String = "roads"

# Settlement development tiers. Capital status is separate (Settlement.is_capital):
# a small town can be a capital, and a commercial city can outgrow its capital.
const TIER_VILLAGE: int = 1
const TIER_TOWN: int = 2
const TIER_CITY: int = 3
const TIER_GREAT_CITY: int = 4

# Road classes describe the physical road, not how much trade currently uses it.
const ROAD_LOCAL: int = 0
const ROAD_REGIONAL: int = 1
const ROAD_MAJOR: int = 2

const LABEL_OCEAN: String = "ocean"
const LABEL_SEA: String = "sea"
const LABEL_LANDFORM: String = "landform"
const LABEL_CONTINENT: String = "continent"

class Kingdom:
	var id: int = -1
	var key: String = ""
	var name: String = ""
	var color: Color = Color.WHITE
	var capital_settlement_id: int = -1
	var label_position: Vector2 = Vector2.ZERO

class Region:
	var id: int = -1
	var name: String = ""
	var seed_position: Vector2 = Vector2.ZERO
	# Political control. -1 means no kingdom holds it.
	var owner_kingdom_id: int = -1
	# Kingdoms that claim the region without holding it.
	var claimant_kingdom_ids: PackedInt32Array = PackedInt32Array()
	# Same region, same regional map: the existing region generator is seeded from this.
	var regional_map_seed: int = 0
	# Derived from the geography when the world is built.
	var centroid: Vector2 = Vector2.ZERO
	var cell_count: int = 0
	var climate: String = ""
	var landscape: String = ""
	var has_river: bool = false
	var has_coast: bool = false

	func is_unclaimed() -> bool:
		return owner_kingdom_id == -1 and claimant_kingdom_ids.is_empty()

	func is_contested() -> bool:
		return owner_kingdom_id == -1 and not claimant_kingdom_ids.is_empty()

class Settlement:
	var id: int = -1
	var name: String = ""
	var position: Vector2 = Vector2.ZERO
	var tier: int = TIER_VILLAGE
	var population: int = 0
	var is_capital: bool = false
	var is_port: bool = false
	var region_id: int = -1
	# -1 for independent settlements.
	var kingdom_id: int = -1

class Road:
	var id: int = -1
	var from_settlement_id: int = -1
	var to_settlement_id: int = -1
	var road_class: int = ROAD_LOCAL
	var points: PackedVector2Array = PackedVector2Array()

class River:
	var name: String = ""
	var is_major: bool = true
	var points: PackedVector2Array = PackedVector2Array()
	# World-unit width at each point; rivers widen toward the mouth.
	var widths: PackedFloat32Array = PackedFloat32Array()

class Lake:
	var name: String = ""
	var center: Vector2 = Vector2.ZERO
	# World-unit radii of the shoreline ellipse.
	var radius: Vector2 = Vector2.ONE

class GeoLabel:
	var text: String = ""
	var kind: String = LABEL_LANDFORM
	var position: Vector2 = Vector2.ZERO
	var angle: float = 0.0

var world_size: Vector2 = Vector2(7200.0, 3600.0)
# The seed a generated world was built from (WorldGenerator); -1 for the authored world.
var world_seed: int = -1

# Geography fields at terrain resolution, one texel per cell:
# R elevation (0 = sea level, land up to 1, sea down to -1), G moisture, B forest, A mountain relief.
var terrain_size: Vector2i = Vector2i.ZERO
var terrain_image: Image = null

# Region index per political cell, -1 for water.
var political_size: Vector2i = Vector2i.ZERO
var region_grid: PackedInt32Array = PackedInt32Array()

var kingdoms: Array[Kingdom] = []
var regions: Array[Region] = []
var settlements: Array[Settlement] = []
var roads: Array[Road] = []
var rivers: Array[River] = []
var lakes: Array[Lake] = []
var geo_labels: Array[GeoLabel] = []

# Problems found while building from a definition (unroutable roads, settlements at sea).
var build_warnings: PackedStringArray = PackedStringArray()

func notify_changed(layer: String) -> void:
	changed.emit(layer)

func wrap_x(x: float) -> float:
	return fposmod(x, world_size.x)

func wrap_position(world_pos: Vector2) -> Vector2:
	return Vector2(wrap_x(world_pos.x), clampf(world_pos.y, 0.0, world_size.y))

# Signed horizontal offset from a to b along the shorter way around the planet.
func wrapped_delta_x(from_x: float, to_x: float) -> float:
	var delta: float = fposmod(to_x - from_x, world_size.x)
	if delta > world_size.x * 0.5:
		delta -= world_size.x
	return delta

func wrapped_distance(a: Vector2, b: Vector2) -> float:
	return Vector2(wrapped_delta_x(a.x, b.x), b.y - a.y).length()

func latitude_at(world_y: float) -> float:
	return 90.0 - world_y / world_size.y * 180.0

func longitude_at(world_x: float) -> float:
	return wrap_x(world_x) / world_size.x * 360.0

func political_cell_at(world_pos: Vector2) -> Vector2i:
	var wrapped: Vector2 = wrap_position(world_pos)
	var cell_x: int = int(floor(wrapped.x / world_size.x * political_size.x)) % political_size.x
	var cell_y: int = clampi(int(floor(wrapped.y / world_size.y * political_size.y)), 0, political_size.y - 1)
	return Vector2i(cell_x, cell_y)

func political_cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * world_size.x / political_size.x, (cell.y + 0.5) * world_size.y / political_size.y)

func elevation_at(world_pos: Vector2) -> float:
	return terrain_at(world_pos).r

# All four geography fields, bilinearly interpolated (see terrain_image for the channels).
func terrain_at(world_pos: Vector2) -> Color:
	if terrain_image == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var wrapped: Vector2 = wrap_position(world_pos)
	var fx: float = wrapped.x / world_size.x * terrain_size.x - 0.5
	var fy: float = clampf(wrapped.y / world_size.y * terrain_size.y - 0.5, 0.0, terrain_size.y - 1.0)
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - x0
	var ty: float = fy - y0
	var x1: int = posmod(x0 + 1, terrain_size.x)
	x0 = posmod(x0, terrain_size.x)
	var y1: int = mini(y0 + 1, terrain_size.y - 1)
	var top: Color = terrain_image.get_pixel(x0, y0).lerp(terrain_image.get_pixel(x1, y0), tx)
	var bottom: Color = terrain_image.get_pixel(x0, y1).lerp(terrain_image.get_pixel(x1, y1), tx)
	return top.lerp(bottom, ty)

func is_land_at(world_pos: Vector2) -> bool:
	return elevation_at(world_pos) > 0.0

# The lake whose shoreline ellipse, scaled by reach, contains the position; null if none.
func lake_at(world_pos: Vector2, reach: float = 1.0) -> Lake:
	for lake: Lake in lakes:
		var offset: Vector2 = Vector2(wrapped_delta_x(lake.center.x, world_pos.x), world_pos.y - lake.center.y)
		if (offset / lake.radius).length() <= reach:
			return lake
	return null

# Region under a world position, or -1 over water.
func region_id_at(world_pos: Vector2) -> int:
	if region_grid.is_empty() or not is_land_at(world_pos):
		return -1
	var cell: Vector2i = political_cell_at(world_pos)
	return region_grid[cell.y * political_size.x + cell.x]

# Region grid where water cells take the region of the nearest land, so borders drawn from
# it (the atlas shader, the regional map) appear only where two regions meet on land.
func region_grid_spread_into_water() -> PackedInt32Array:
	var width: int = political_size.x
	var height: int = political_size.y
	var spread: PackedInt32Array = region_grid.duplicate()
	var frontier: PackedInt32Array = PackedInt32Array()
	for i in range(width * height):
		if spread[i] >= 0:
			frontier.append(i)
	var head: int = 0
	while head < frontier.size():
		var current: int = frontier[head]
		head += 1
		var x: int = current % width
		var y: int = current / width
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ny: int = y + offset.y
			if ny < 0 or ny >= height:
				continue
			var neighbor: int = ny * width + posmod(x + offset.x, width)
			if spread[neighbor] == -1:
				spread[neighbor] = spread[current]
				frontier.append(neighbor)
	return spread

func get_region(region_id: int) -> Region:
	if region_id < 0 or region_id >= regions.size():
		return null
	return regions[region_id]

func get_kingdom(kingdom_id: int) -> Kingdom:
	if kingdom_id < 0 or kingdom_id >= kingdoms.size():
		return null
	return kingdoms[kingdom_id]

func get_settlement(settlement_id: int) -> Settlement:
	if settlement_id < 0 or settlement_id >= settlements.size():
		return null
	return settlements[settlement_id]

func find_settlement_by_name(settlement_name: String) -> Settlement:
	for settlement: Settlement in settlements:
		if settlement.name == settlement_name:
			return settlement
	return null

func find_region_by_name(region_name: String) -> Region:
	for region: Region in regions:
		if region.name == region_name:
			return region
	return null

func get_settlements_in_region(region_id: int) -> Array[Settlement]:
	var result: Array[Settlement] = []
	for settlement: Settlement in settlements:
		if settlement.region_id == region_id:
			result.append(settlement)
	result.sort_custom(func(a: Settlement, b: Settlement) -> bool: return a.population > b.population)
	return result

func get_kingdom_regions(kingdom_id: int) -> Array[Region]:
	var result: Array[Region] = []
	for region: Region in regions:
		if region.owner_kingdom_id == kingdom_id:
			result.append(region)
	return result

func get_tier_name(tier: int) -> String:
	match tier:
		TIER_VILLAGE:
			return "Village"
		TIER_TOWN:
			return "Town"
		TIER_CITY:
			return "City"
		TIER_GREAT_CITY:
			return "Great city"
	return "Settlement"

func get_road_class_name(road_class: int) -> String:
	match road_class:
		ROAD_MAJOR:
			return "Major route"
		ROAD_REGIONAL:
			return "Regional road"
	return "Local road"
