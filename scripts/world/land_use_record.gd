class_name LandUseRecord
extends RefCounted

# What has happened on the land, per regional tile (master roadmap Phase 1; docs/MAP_SCALE_ARCHITECTURE.md):
# the town tiles under each regional tile (TOWN_TILES_PER_REGIONAL_TILE squared of them) counted by
# what they hold now. It is the one summary the regional and world maps read about a settlement's
# land, so a town's real development, felled woods and fields show at every scale.
#
# The record is derived, never stored: a town map is saved whole, and the land under it is a pure
# function of position, so the record is worked out again from them whenever it is needed. Reading
# it changes nothing in play.

const BUILT: int = 0
const FARMLAND: int = 1
const STREET: int = 2
# Woods the land had that are gone now (felled, cleared, built over).
const CLEARED: int = 3
const WOODED: int = 4
const KINDS: int = 5
const KIND_NAMES: Array[String] = ["built", "farmland", "street", "cleared", "wooded"]

const PER_SIDE: int = LocalCityMapGenerator.TOWN_TILES_PER_REGIONAL_TILE
const PER_TILE: int = PER_SIDE * PER_SIDE

# Global regional tile -> counts by kind (an Array of KINDS ints, each 0..PER_TILE; a plain Array so
# counts update in place).
var tiles: Dictionary = {}

# The global town tile at a town map's (0, 0), for a site and map size (as LocalCityMapGenerator.land).
static func town_origin(global_site: Vector2i, map_size: Vector2i) -> Vector2i:
	return global_site * PER_SIDE - map_size / 2 + Vector2i(PER_SIDE, PER_SIDE) / 2

# A town's record: its map now, against the land under it before founding (base_map, from
# LocalCityMapGenerator.generate_base_from_terrain at the same site). planet_width wraps regional x.
static func of_town(city: City, base_map: Array, global_site: Vector2i, planet_width: int) -> LandUseRecord:
	var record: LandUseRecord = LandUseRecord.new()
	var local_map: Array = city.local_map
	if local_map.is_empty():
		return record
	var size: Vector2i = Vector2i((local_map[0] as Array).size(), local_map.size())
	var origin: Vector2i = town_origin(global_site, size)
	var kind_at: Dictionary = {}
	for building: Building in city.buildings:
		var kind: int = FARMLAND if BuildingTiers.get_base_type(building.type) == Building.BUILDING_FARM else BUILT
		for y in range(building.tile.y, building.tile.y + building.size.y):
			for x in range(building.tile.x, building.tile.x + building.size.x):
				kind_at[Vector2i(x, y)] = kind
	# Worn paths, from the town's path cells (TownLogistics: cells at twice the tiles plus one).
	for cell: Vector2i in city.logistics.cell_levels.keys():
		if int(city.logistics.cell_levels[cell]) >= TownLogistics.PATH_WORN:
			var tile: Vector2i = Vector2i(mini(cell.x / 2, size.x - 1), mini(cell.y / 2, size.y - 1))
			if not kind_at.has(tile):
				kind_at[tile] = STREET
	for y in range(size.y):
		for x in range(size.x):
			var now: Dictionary = local_map[y][x]
			var at: Vector2i = Vector2i(x, y)
			var counts: Array = record.counts_at(origin + at, planet_width)
			if kind_at.has(at):
				counts[kind_at[at]] += 1
			elif now.get("has_road", false) == true:
				counts[STREET] += 1
			if now["has_trees"] == true:
				counts[WOODED] += 1
			elif y < base_map.size() and x < (base_map[y] as Array).size() and base_map[y][x]["has_trees"] == true:
				counts[CLEARED] += 1
	return record

# The counts for the regional tile holding a global town tile, made on first use.
func counts_at(global_town_tile: Vector2i, planet_width: int) -> Array:
	var regional: Vector2i = Vector2i(floori(float(global_town_tile.x) / PER_SIDE), floori(float(global_town_tile.y) / PER_SIDE))
	if planet_width > 0:
		regional.x = posmod(regional.x, planet_width)
	if not tiles.has(regional):
		var counts: Array = []
		counts.resize(KINDS)
		counts.fill(0)
		tiles[regional] = counts
	return tiles[regional]

# Adds another record's counts (two towns' maps can reach into the same regional tile).
func add(other: LandUseRecord) -> void:
	for regional: Vector2i in other.tiles:
		var theirs: Array = other.tiles[regional]
		if not tiles.has(regional):
			tiles[regional] = theirs.duplicate()
			continue
		var ours: Array = tiles[regional]
		for kind in range(KINDS):
			ours[kind] = mini(PER_TILE, ours[kind] + theirs[kind])

# The share of a regional tile's land that holds a kind, 0 to 1.
func get_share(regional_tile: Vector2i, kind: int) -> float:
	var counts: Variant = tiles.get(regional_tile, null)
	return float((counts as Array)[kind]) / PER_TILE if counts != null else 0.0

func get_total(kind: int) -> int:
	var total: int = 0
	for counts: Array in tiles.values():
		total += counts[kind]
	return total

# Woods the regional map should no longer draw: most of the tile's land that had trees has lost them.
func is_cleared(regional_tile: Vector2i) -> bool:
	var counts: Variant = tiles.get(regional_tile, null)
	if counts == null:
		return false
	var cleared: int = (counts as Array)[CLEARED]
	return cleared > 0 and cleared >= (counts as Array)[WOODED]
