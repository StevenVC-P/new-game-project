class_name RegionChunkFeatureLayer
extends RegionFeatureLayer

# Natural features of one chunk of the continuous regional map (see RegionalTerrain): the
# same trees, peaks, and boulders as a bounded region, read from the chunk's packed tiles.
# The node sits at the chunk's first core tile; per-tile variation is hashed from global
# tiles, so a tree stands in the same place whenever its chunk is drawn.

var chunk: RegionalChunk = null
# Answers whether a map position (global map units) is kept clear of trees.
var clearance: Callable = Callable()

func setup_chunk(map_view: RegionMapView, regional_chunk: RegionalChunk, cleared: Callable) -> void:
	setup(map_view)
	chunk = regional_chunk
	clearance = cleared

func setup_style() -> void:
	apply_climate_style(chunk.mean_temperature, chunk.climate_family)

func source_size() -> Vector2i:
	return Vector2i(RegionalTerrain.CHUNK_TILES, RegionalTerrain.CHUNK_TILES)

func stored_index(x: int, y: int) -> int:
	var keep: int = RegionalTerrain.KEEP_APRON_TILES
	return (y + keep) * chunk.stored_size + x + keep

# The stored margin around the chunk counts as part of the source, so woods and ranges
# continue across chunk edges.
func is_in_source(x: int, y: int) -> bool:
	var keep: int = RegionalTerrain.KEEP_APRON_TILES
	return x >= -keep and y >= -keep and x < RegionalTerrain.CHUNK_TILES + keep and y < RegionalTerrain.CHUNK_TILES + keep

func tile_type_at(x: int, y: int) -> String:
	return RegionalChunk.TYPE_NAMES[chunk.types[stored_index(x, y)]]

func forest_at(x: int, y: int) -> bool:
	return chunk.flags[stored_index(x, y)] & RegionalChunk.FLAG_FOREST != 0

func fertile_at(x: int, y: int) -> bool:
	return chunk.flags[stored_index(x, y)] & RegionalChunk.FLAG_FERTILE != 0

func resource_at(x: int, y: int) -> String:
	return RegionalChunk.RESOURCE_NAMES[chunk.resources[stored_index(x, y)]]

func hash_tile(x: int, y: int) -> Vector2i:
	return chunk.core_origin + Vector2i(x, y)

func is_cleared_at(position: Vector2) -> bool:
	return clearance.is_valid() and clearance.call(position + Vector2(chunk.core_origin) * RegionMapStyle.TILE)

func tile_temperature(x: int, y: int) -> float:
	return chunk.temperature[stored_index(x, y)] / 255.0
