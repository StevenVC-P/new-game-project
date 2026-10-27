class_name TownGroundLayer
extends TownMapLayer

# The ground: one shader quad over the town map, fed by per-tile data textures built from the
# town's tiles and its site's climate (see shaders/town_terrain.gdshader).

const TERRAIN_SHADER: Shader = preload("res://shaders/town_terrain.gdshader")
# Water deeper than this many tiles from shore draws at full depth.
const DEPTH_TILES: float = 6.0

var shader_material: ShaderMaterial = null

func setup(map_view: TownMapView) -> void:
	super.setup(map_view)
	shader_material = ShaderMaterial.new()
	shader_material.shader = TERRAIN_SHADER
	material = shader_material
	shader_material.set_shader_parameter("tile_units", TownMapStyle.TILE)

func set_view_zoom(new_zoom: float) -> void:
	super.set_view_zoom(new_zoom)
	shader_material.set_shader_parameter("zoom", new_zoom)

func rebuild() -> void:
	var size: Vector2i = view.map_size
	if size == Vector2i.ZERO:
		return
	var count: int = size.x * size.y
	var masks_a: PackedByteArray = PackedByteArray()
	var masks_b: PackedByteArray = PackedByteArray()
	var masks_c: PackedByteArray = PackedByteArray()
	masks_a.resize(count * 4)
	masks_b.resize(count * 4)
	masks_c.resize(count * 4)
	var is_water: PackedByteArray = PackedByteArray()
	is_water.resize(count)
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(count)
	var tiles: Array = local_map()
	for y in range(size.y):
		for x in range(size.x):
			var i: int = y * size.x + x
			var tile: Dictionary = tiles[y][x]
			var water: bool = tile["type"] == "water"
			var resource: String = tile.get("resource", "none")
			var rough: bool = tile["type"] == "rough"
			is_water[i] = 1 if water else 0
			masks_a[i * 4] = 255 if rough and resource == "none" else 0
			masks_a[i * 4 + 1] = 255 if water else 0
			masks_a[i * 4 + 2] = 255 if tile["is_fertile"] == true else 0
			masks_a[i * 4 + 3] = 255 if tile["has_trees"] == true else 0
			masks_b[i * 4] = 255 if resource == "stone" else 0
			masks_b[i * 4 + 1] = 255 if resource == "iron" else 0
			masks_b[i * 4 + 2] = 255 if tile.get("has_road", false) == true else 0
			masks_b[i * 4 + 3] = 255 if tile.get("water_kind", "") == "sea" else 0
			masks_c[i * 4] = 255 if tile.get("water_kind", "") == "lake" else 0
			# Ground height for the light: water low, open land, rock standing proud.
			height[i] = 0.0 if water else (0.85 if rough else 0.3)
	var depth: PackedFloat32Array = RegionTerrainLayer.distance_to_land(is_water, size)
	height = RegionTerrainLayer.blur3(RegionTerrainLayer.blur3(height, size), size)
	for i in range(count):
		masks_c[i * 4 + 1] = int(clampf(depth[i] / DEPTH_TILES, 0.0, 1.0) * 255.0)
		masks_c[i * 4 + 2] = int(clampf(height[i], 0.0, 1.0) * 255.0)
		masks_c[i * 4 + 3] = 255

	set_mask("masks_a", masks_a, size)
	set_mask("masks_b", masks_b, size)
	set_mask("masks_c", masks_c, size)
	shader_material.set_shader_parameter("map_tiles", Vector2(size))
	var climate: Dictionary = view.climate
	shader_material.set_shader_parameter("site_temperature", float(climate.get("temperature", 0.55)))
	shader_material.set_shader_parameter("site_moisture", float(climate.get("moisture", 0.6)))
	var floor_color: Color = RegionMapStyle.forest_floor_color(float(climate.get("tree_temperature", 0.55)), str(climate.get("family", RegionalTerrain.CLIMATE_TEMPERATE)))
	shader_material.set_shader_parameter("forest_floor", Vector3(floor_color.r, floor_color.g, floor_color.b))
	shader_material.set_shader_parameter("noise_offset", view.noise_offset)
	queue_redraw()

func set_mask(parameter: String, bytes: PackedByteArray, size: Vector2i) -> void:
	var image: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
	shader_material.set_shader_parameter(parameter, ImageTexture.create_from_image(image))

func _draw() -> void:
	if view == null or view.map_size == Vector2i.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, map_extent()), Color.WHITE)
