class_name RegionTerrainLayer
extends RegionMapLayer

# The ground: one shader quad over the board, fed by per-tile data textures built from the
# region's tiles and the world's climate (see shaders/region_terrain.gdshader).

const TERRAIN_SHADER: Shader = preload("res://shaders/region_terrain.gdshader")
# Water deeper than this many tiles from shore draws at full depth.
const DEPTH_TILES: float = 8.0
const HILL_HEIGHT: float = 0.45
const MOUNTAIN_HEIGHT: float = 1.0

var shader_material: ShaderMaterial = null

func setup(map_view: RegionMapView) -> void:
	super.setup(map_view)
	shader_material = ShaderMaterial.new()
	shader_material.shader = TERRAIN_SHADER
	material = shader_material
	shader_material.set_shader_parameter("tile_units", RegionMapStyle.TILE)

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
	var masks_d: PackedByteArray = PackedByteArray()
	masks_a.resize(count * 4)
	masks_b.resize(count * 4)
	masks_c.resize(count * 4)
	masks_d.resize(count * 4)
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(count)
	var depth: PackedFloat32Array = shore_distance(size)
	var geography: RegionGeography = view.geography
	var default_temperature: float = RegionMapStyle.region_temperature(geography)
	var default_moisture: float = RegionMapStyle.region_moisture(geography)

	for y in range(size.y):
		for x in range(size.x):
			var i: int = y * size.x + x
			var tile: Dictionary = view.tiles[y][x]
			var tile_type: String = tile["type"]
			var is_water: bool = tile_type == "river" or tile_type == "lake" or tile_type == "sea"
			masks_a[i * 4] = 255 if tile_type == "hill" else 0
			masks_a[i * 4 + 1] = 255 if tile_type == "mountain" else 0
			masks_a[i * 4 + 2] = 255 if is_water else 0
			masks_a[i * 4 + 3] = 255 if tile["is_fertile"] == true and not is_water else 0
			masks_b[i * 4] = 255 if tile["has_forest"] == true else 0
			masks_b[i * 4 + 1] = 255 if tile["resource"] == "stone" else 0
			masks_b[i * 4 + 2] = 255 if tile["resource"] == "iron" else 0
			masks_b[i * 4 + 3] = 255 if tile_type == "sea" else 0
			var temperature: float = geography.temperature[i] if geography != null else default_temperature
			var moisture: float = geography.moisture[i] if geography != null else default_moisture
			masks_c[i * 4] = int(clampf(temperature, 0.0, 1.0) * 255.0)
			masks_c[i * 4 + 1] = int(clampf(moisture, 0.0, 1.0) * 255.0)
			masks_c[i * 4 + 2] = int(clampf(depth[i] / DEPTH_TILES, 0.0, 1.0) * 255.0)
			masks_c[i * 4 + 3] = 255 if tile_type == "lake" else 0
			if tile_type == "hill":
				height[i] = HILL_HEIGHT
			elif tile_type == "mountain":
				height[i] = MOUNTAIN_HEIGHT

	# Blurred twice so hill country rolls instead of rising in tile-sized steps.
	height = blur3(blur3(height, size), size)
	for i in range(count):
		masks_d[i * 4] = int(clampf(height[i], 0.0, 1.0) * 255.0)
		masks_d[i * 4 + 1] = masks_a[i * 4 + 2]
		masks_d[i * 4 + 3] = 255

	set_mask("masks_a", masks_a, size)
	set_mask("masks_b", masks_b, size)
	set_mask("masks_c", masks_c, size)
	set_mask("masks_d", masks_d, size)
	shader_material.set_shader_parameter("map_tiles", Vector2(size))
	var tree_dark: Color = RegionMapStyle.tree_style(geography)["dark"]
	var floor_color: Color = tree_dark.lerp(Color(0.5, 0.48, 0.32), 0.25) if RegionMapStyle.climate_family(geography) == RegionGeography.CLIMATE_ARID else tree_dark.darkened(0.08)
	shader_material.set_shader_parameter("forest_floor", Vector3(floor_color.r, floor_color.g, floor_color.b))
	queue_redraw()

func set_mask(parameter: String, bytes: PackedByteArray, size: Vector2i) -> void:
	var image: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
	shader_material.set_shader_parameter(parameter, ImageTexture.create_from_image(image))

# Tiles from the nearest land, for water; 0 on land.
func shore_distance(size: Vector2i) -> PackedFloat32Array:
	var distance: PackedFloat32Array = PackedFloat32Array()
	distance.resize(size.x * size.y)
	for y in range(size.y):
		for x in range(size.x):
			var tile_type: String = view.tiles[y][x]["type"]
			distance[y * size.x + x] = 9999.0 if tile_type == "river" or tile_type == "lake" or tile_type == "sea" else 0.0
	for pass_index in range(2):
		var forward: bool = pass_index == 0
		for row in range(size.y):
			var y: int = row if forward else size.y - 1 - row
			for column in range(size.x):
				var x: int = column if forward else size.x - 1 - column
				var i: int = y * size.x + x
				# Two-pass chamfer: each pass looks only at neighbors it has already visited.
				var back: int = -1 if forward else 1
				for offset: Vector3 in [Vector3(back, 0, 1.0), Vector3(0, back, 1.0), Vector3(-1, back, 1.414), Vector3(1, back, 1.414)]:
					var nx: int = x + int(offset.x)
					var ny: int = y + int(offset.y)
					if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
						continue
					distance[i] = minf(distance[i], distance[ny * size.x + nx] + offset.z)
	return distance

static func blur3(values: PackedFloat32Array, size: Vector2i) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(values.size())
	for y in range(size.y):
		for x in range(size.x):
			var sum: float = 0.0
			var weight: float = 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx: int = clampi(x + ox, 0, size.x - 1)
					var ny: int = clampi(y + oy, 0, size.y - 1)
					var w: float = 2.0 if ox == 0 and oy == 0 else 1.0
					sum += values[ny * size.x + nx] * w
					weight += w
			result[y * size.x + x] = sum / weight
	return result

func _draw() -> void:
	if view == null or view.map_size == Vector2i.ZERO:
		return
	draw_rect(Rect2(Vector2.ZERO, map_extent()), Color.WHITE)
