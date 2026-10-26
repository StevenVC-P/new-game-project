class_name RegionalChunk
extends RefCounted

# One generated chunk of the planet at regional scale (see RegionalTerrain). Tiles are kept
# as packed bytes; game rules get the usual tile dictionaries through tile_dictionary().
# The stored area is the chunk plus a margin of RegionalTerrain.KEEP_APRON_TILES, so the
# terrain shader can smooth across chunk edges.

const TYPE_GRASS: int = 0
const TYPE_HILL: int = 1
const TYPE_MOUNTAIN: int = 2
const TYPE_RIVER: int = 3
const TYPE_LAKE: int = 4
const TYPE_SEA: int = 5
const TYPE_NAMES: Array[String] = ["grass", "hill", "mountain", "river", "lake", "sea"]

const FLAG_FOREST: int = 1
const FLAG_FERTILE: int = 2
const FLAG_ROAD: int = 4
const FLAG_FORD: int = 8

const RESOURCE_NONE: int = 0
const RESOURCE_STONE: int = 1
const RESOURCE_IRON: int = 2
const RESOURCE_NAMES: Array[String] = ["none", "stone", "iron"]

var coords: Vector2i = Vector2i.ZERO
# Global tile of the chunk's first core tile, and of the first stored tile.
var core_origin: Vector2i = Vector2i.ZERO
var stored_origin: Vector2i = Vector2i.ZERO
var stored_size: int = 0
var planet_width: int = 0

# Per stored tile, row-major.
var types: PackedByteArray = PackedByteArray()
var flags: PackedByteArray = PackedByteArray()
var resources: PackedByteArray = PackedByteArray()
# 0..255 for 0..1.
var temperature: PackedByteArray = PackedByteArray()
var moisture: PackedByteArray = PackedByteArray()
# Water: tiles to the nearest land, scaled so 255 is DEPTH_TILES or more. Land: 0.
var shore_depth: PackedByteArray = PackedByteArray()
# Region id + 1 by the atlas's border vote (spread over water too); 0 for none.
var regions: PackedByteArray = PackedByteArray()

# Climate of the chunk as a whole (palette choices that are not per tile).
var climate_family: String = RegionGeography.CLIMATE_TEMPERATE
var mean_temperature: float = 0.5
var mean_moisture: float = 0.5

const DEPTH_TILES: float = 8.0

static func make_tile_dictionary(tile_type: int, tile_flags: int, resource: int) -> Dictionary:
	return {
		"type": TYPE_NAMES[tile_type],
		"has_forest": tile_flags & FLAG_FOREST != 0,
		"is_fertile": tile_flags & FLAG_FERTILE != 0,
		"resource": RESOURCE_NAMES[resource],
		"has_road": tile_flags & FLAG_ROAD != 0,
		"has_ford": tile_flags & FLAG_FORD != 0
	}

static func is_water_type(tile_type: int) -> bool:
	return tile_type >= TYPE_RIVER

# Stored index of a global tile (x may be unwrapped), or -1 when the chunk does not hold it.
func index_of(tile: Vector2i) -> int:
	var dx: int = posmod(tile.x - stored_origin.x, planet_width)
	var dy: int = tile.y - stored_origin.y
	if dx >= stored_size or dy < 0 or dy >= stored_size:
		return -1
	return dy * stored_size + dx

func has_tile(tile: Vector2i) -> bool:
	return index_of(tile) >= 0

func type_at(tile: Vector2i) -> int:
	return types[index_of(tile)]

func is_water(tile: Vector2i) -> bool:
	return is_water_type(types[index_of(tile)])

func region_at(tile: Vector2i) -> int:
	return regions[index_of(tile)] - 1

# A town could stand here: open or hill land without forest or a deposit.
func is_buildable(tile: Vector2i) -> bool:
	var i: int = index_of(tile)
	return types[i] <= TYPE_HILL and flags[i] & FLAG_FOREST == 0 and resources[i] == RESOURCE_NONE

func tile_dictionary(tile: Vector2i) -> Dictionary:
	var i: int = index_of(tile)
	return make_tile_dictionary(types[i], flags[i], resources[i])
