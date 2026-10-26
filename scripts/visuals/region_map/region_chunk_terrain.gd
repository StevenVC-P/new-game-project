class_name RegionChunkTerrain
extends Node2D

# The ground of one chunk of the continuous regional map: one quad drawn by
# shaders/region_terrain.gdshader from the chunk's per-tile masks. The masks include the
# chunk's stored margin, so the shader's smoothing and lighting join the neighbouring chunks
# without a seam. The node sits at the chunk's first core tile.

const TERRAIN_SHADER: Shader = preload("res://shaders/region_terrain.gdshader")
const HILL_HEIGHT: float = 0.45
const MOUNTAIN_HEIGHT: float = 1.0

var chunk: RegionalChunk = null
var shader_material: ShaderMaterial = null
# Zoom, canopy strength, and borders last given to the shader.
var view_state: Vector3 = Vector3(-1.0, -1.0, -1.0)

# Mask bytes for the shader (RGBA8, stored size squared): see the shader for the channels.
# Pure data, so RegionalTerrain runs it on the worker thread right after generation.
static func build_masks(regional_chunk: RegionalChunk) -> void:
	var size: int = regional_chunk.stored_size
	var count: int = size * size
	var masks_a: PackedByteArray = PackedByteArray()
	var masks_b: PackedByteArray = PackedByteArray()
	var masks_c: PackedByteArray = PackedByteArray()
	var masks_d: PackedByteArray = PackedByteArray()
	masks_a.resize(count * 4)
	masks_b.resize(count * 4)
	masks_c.resize(count * 4)
	masks_d.resize(count * 4)
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(count)
	for i in range(count):
		var tile_type: int = regional_chunk.types[i]
		var tile_flags: int = regional_chunk.flags[i]
		var resource: int = regional_chunk.resources[i]
		var is_water: bool = RegionalChunk.is_water_type(tile_type)
		masks_a[i * 4] = 255 if tile_type == RegionalChunk.TYPE_HILL else 0
		masks_a[i * 4 + 1] = 255 if tile_type == RegionalChunk.TYPE_MOUNTAIN else 0
		masks_a[i * 4 + 2] = 255 if is_water else 0
		masks_a[i * 4 + 3] = 255 if tile_flags & RegionalChunk.FLAG_FERTILE != 0 and not is_water else 0
		masks_b[i * 4] = 255 if tile_flags & RegionalChunk.FLAG_FOREST != 0 else 0
		masks_b[i * 4 + 1] = 255 if resource == RegionalChunk.RESOURCE_STONE else 0
		masks_b[i * 4 + 2] = 255 if resource == RegionalChunk.RESOURCE_IRON else 0
		masks_b[i * 4 + 3] = 255 if tile_type == RegionalChunk.TYPE_SEA else 0
		masks_c[i * 4] = regional_chunk.temperature[i]
		masks_c[i * 4 + 1] = regional_chunk.moisture[i]
		masks_c[i * 4 + 2] = regional_chunk.shore_depth[i]
		masks_c[i * 4 + 3] = 255 if tile_type == RegionalChunk.TYPE_LAKE else 0
		if tile_type == RegionalChunk.TYPE_HILL:
			height[i] = HILL_HEIGHT
		elif tile_type == RegionalChunk.TYPE_MOUNTAIN:
			height[i] = MOUNTAIN_HEIGHT
	# Blurred twice so hill country rolls instead of rising in tile-sized steps.
	var square: Vector2i = Vector2i(size, size)
	height = RegionTerrainLayer.blur3(RegionTerrainLayer.blur3(height, square), square)
	for i in range(count):
		masks_d[i * 4] = int(clampf(height[i], 0.0, 1.0) * 255.0)
		masks_d[i * 4 + 1] = masks_a[i * 4 + 2]
		masks_d[i * 4 + 3] = 255
	regional_chunk.shader_masks = [masks_a, masks_b, masks_c, masks_d]

func setup(regional_chunk: RegionalChunk, shared: Dictionary) -> void:
	chunk = regional_chunk
	shader_material = ShaderMaterial.new()
	shader_material.shader = TERRAIN_SHADER
	material = shader_material
	var size: int = chunk.stored_size
	for k in range(4):
		var image: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, chunk.shader_masks[k])
		shader_material.set_shader_parameter(["masks_a", "masks_b", "masks_c", "masks_d"][k], ImageTexture.create_from_image(image))
	shader_material.set_shader_parameter("map_tiles", Vector2(size, size))
	shader_material.set_shader_parameter("tile_units", RegionMapStyle.TILE)
	shader_material.set_shader_parameter("planet_tiles", float(chunk.planet_width))
	shader_material.set_shader_parameter("tile_origin", Vector2(chunk.core_origin))
	shader_material.set_shader_parameter("mask_offset", float(RegionalTerrain.KEEP_APRON_TILES))
	var floor_color: Color = RegionMapStyle.forest_floor_color(chunk.mean_temperature, chunk.climate_family)
	shader_material.set_shader_parameter("forest_floor", Vector3(floor_color.r, floor_color.g, floor_color.b))
	shader_material.set_shader_parameter("political_tex", shared["political_tex"])
	shader_material.set_shader_parameter("kingdom_palette", shared["kingdom_palette"])
	shader_material.set_shader_parameter("political_size", shared["political_size"])
	shader_material.set_shader_parameter("tile_world", RegionalTerrain.TILE_WORLD_UNITS)
	queue_redraw()

func set_view(zoom: float, canopy_strength: float, borders: bool) -> void:
	# Called every frame for every chunk; uniforms are set only when they change.
	var state: Vector3 = Vector3(zoom, canopy_strength, 1.0 if borders else 0.0)
	if state == view_state:
		return
	view_state = state
	shader_material.set_shader_parameter("zoom", zoom)
	shader_material.set_shader_parameter("canopy_strength", canopy_strength)
	shader_material.set_shader_parameter("show_borders", state.z)

func _draw() -> void:
	var extent: float = RegionalTerrain.CHUNK_TILES * RegionMapStyle.TILE
	draw_rect(Rect2(Vector2.ZERO, Vector2(extent, extent)), Color.WHITE)
