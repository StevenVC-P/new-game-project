class_name WorldTerrainLayer
extends WorldMapLayer

# Geography, cultivated land, and political borders, all drawn by one shader from data
# textures. Camera changes only update uniforms; world changes re-upload one texture.

const TERRAIN_SHADER: Shader = preload("res://shaders/world_terrain.gdshader")
const MAX_KINGDOMS: int = 64
# Region ids travel through one 8-bit channel (0 means none).
const MAX_REGIONS: int = 254

var shader_material: ShaderMaterial = null

func setup(world_data: WorldMapData) -> void:
	data = world_data
	shader_material = ShaderMaterial.new()
	shader_material.shader = TERRAIN_SHADER
	material = shader_material
	shader_material.set_shader_parameter("world_size", data.world_size)
	shader_material.set_shader_parameter("terrain_size", Vector2(data.terrain_size))
	shader_material.set_shader_parameter("political_size", Vector2(data.political_size))
	rebuild_terrain()
	rebuild_political()
	rebuild_development()
	queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	zoom = new_zoom
	if shader_material != null:
		shader_material.set_shader_parameter("zoom", new_zoom)

func set_region_highlight(hovered_region_id: int, selected_region_id: int) -> void:
	shader_material.set_shader_parameter("hovered_region", hovered_region_id)
	shader_material.set_shader_parameter("selected_region", selected_region_id)

func set_borders_visible(borders_visible: bool) -> void:
	shader_material.set_shader_parameter("show_borders", 1.0 if borders_visible else 0.0)

func rebuild_terrain() -> void:
	var image: Image = data.terrain_image.duplicate()
	# Half floats keep elevation smooth for hillshading and are filterable on every renderer.
	image.convert(Image.FORMAT_RGBAH)
	shader_material.set_shader_parameter("terrain_tex", ImageTexture.create_from_image(image))

func rebuild_political() -> void:
	var width: int = data.political_size.x
	var height: int = data.political_size.y
	var spread: PackedInt32Array = data.region_grid_spread_into_water()
	if data.regions.size() > MAX_REGIONS:
		push_warning("World map draws at most %d regions; extra regions share ids." % MAX_REGIONS)

	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(width * height * 4)
	for i in range(width * height):
		var region: WorldMapData.Region = data.get_region(spread[i])
		if region == null:
			continue
		bytes[i * 4] = region.owner_kingdom_id + 1
		bytes[i * 4 + 1] = mini(region.id + 1, 255)
		bytes[i * 4 + 2] = 255 if region.is_contested() else 0
		bytes[i * 4 + 3] = 255
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	shader_material.set_shader_parameter("political_tex", ImageTexture.create_from_image(image))

	var palette: Image = Image.create(MAX_KINGDOMS, 1, false, Image.FORMAT_RGBA8)
	for kingdom: WorldMapData.Kingdom in data.kingdoms:
		if kingdom.id < MAX_KINGDOMS:
			palette.set_pixel(kingdom.id, 0, kingdom.color)
	shader_material.set_shader_parameter("kingdom_palette", ImageTexture.create_from_image(palette))

# Cultivated land around each settlement grows with its population.
func rebuild_development() -> void:
	var width: int = data.terrain_size.x
	var height: int = data.terrain_size.y
	var cell: float = data.world_size.x / width
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(width * height)
	for settlement: WorldMapData.Settlement in data.settlements:
		var radius: float = WorldMapStyle.cultivation_radius(settlement) / cell
		var center: Vector2 = settlement.position / cell
		var intensity: float = 0.55 + 0.1 * settlement.tier
		for y in range(maxi(0, int(center.y - radius)), mini(height, int(center.y + radius) + 1)):
			for x in range(int(center.x - radius), int(center.x + radius) + 1):
				var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
				if distance >= 1.0:
					continue
				var i: int = y * width + posmod(x, width)
				field[i] = maxf(field[i], intensity * (1.0 - smoothstep(0.35, 1.0, distance)))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(width * height)
	for i in range(width * height):
		bytes[i] = int(clampf(field[i], 0.0, 1.0) * 255.0)
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_L8, bytes)
	shader_material.set_shader_parameter("development_tex", ImageTexture.create_from_image(image))

func _draw() -> void:
	if data == null:
		return
	# One quad covering three planet widths; the shader samples with horizontal repeat.
	draw_rect(Rect2(Vector2(-data.world_size.x, 0.0), Vector2(data.world_size.x * 3.0, data.world_size.y)), Color.WHITE)
