class_name WorldFieldBuilder
extends RefCounted

# Turns an authored world definition (see FixedWorldDefinition) into WorldMapData:
# geography fields, the region partition, settlement placement, and road geometry.
# Deterministic: the same definition always produces the same world.

const COAST_BLUR_RADIUS: int = 3
const COAST_NOISE_AMPLITUDE: float = 0.8
const COAST_WARP_CELLS: float = 16.0
const RIVER_MEANDER_WORLD: float = 5.0
# How far (in 4-unit steps) a river may be carried on to find the sea.
const RIVER_MOUTH_SEARCH_STEPS: int = 40
# King moves plus knight moves: grid distance close to straight-line distance, so
# regions on open ground grow round instead of into octagons and boxes.
const REGION_GROWTH_STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
]

# Climate bands by absolute latitude: wet tropics, dry subtropics, wet mid-latitudes, dry poles.
const LATITUDE_MOISTURE: Array = [
	Vector2(0, 0.82), Vector2(10, 0.72), Vector2(18, 0.42), Vector2(26, 0.22), Vector2(34, 0.36),
	Vector2(44, 0.58), Vector2(55, 0.64), Vector2(65, 0.52), Vector2(75, 0.36), Vector2(90, 0.22)
]

var data: WorldMapData
var definition: Dictionary
var tw: int
var th: int
var pw: int
var ph: int

# Terrain-resolution working fields.
var coast: PackedFloat32Array
var land_binary: PackedFloat32Array
var interior: PackedFloat32Array
var hills: PackedFloat32Array
var elevation: PackedFloat32Array
var relief: PackedFloat32Array
var river_valley: PackedFloat32Array

# Political-resolution fields.
var political_land: PackedByteArray
var political_relief: PackedFloat32Array
var political_elevation: PackedFloat32Array
var political_river: PackedByteArray
var political_roughness: PackedFloat32Array

var heap_keys: PackedFloat32Array
var heap_values: PackedInt32Array
var heap_size: int = 0

static func build(world_definition: Dictionary) -> WorldMapData:
	var builder: WorldFieldBuilder = WorldFieldBuilder.new()
	return builder.build_world(world_definition)

func build_world(world_definition: Dictionary) -> WorldMapData:
	begin_world(world_definition)
	return finish_world()

# The build in two halves, so a world generator can read the land (land_binary, elevation)
# and fill in the definition's rivers, regions, settlements, and roads before finish_world().
func begin_world(world_definition: Dictionary) -> void:
	definition = world_definition
	data = WorldMapData.new()
	data.world_size = definition["world_size"]
	data.terrain_size = definition["terrain_size"]
	data.political_size = definition["political_size"]
	data.world_seed = int(definition.get("world_seed", -1))
	tw = data.terrain_size.x
	th = data.terrain_size.y
	pw = data.political_size.x
	ph = data.political_size.y

	build_coast()
	build_elevation()

func finish_world() -> WorldMapData:
	build_rivers()
	build_climate_and_store_terrain()
	trim_river_mouths()
	build_political_fields()
	build_kingdoms()
	build_regions()
	build_settlements()
	build_roads()
	build_labels()
	return data

# --- Coordinates -----------------------------------------------------------

func deg_to_world(deg: Vector2) -> Vector2:
	return Vector2(deg.x / 360.0 * data.world_size.x, (90.0 - deg.y) / 180.0 * data.world_size.y)

func deg_to_terrain(deg: Vector2) -> Vector2:
	return Vector2(deg.x / 360.0 * tw, (90.0 - deg.y) / 180.0 * th)

func world_to_terrain(world_pos: Vector2) -> Vector2:
	return Vector2(world_pos.x / data.world_size.x * tw, world_pos.y / data.world_size.y * th)

func terrain_index(x: int, y: int) -> int:
	return clampi(y, 0, th - 1) * tw + posmod(x, tw)

func political_index(x: int, y: int) -> int:
	return clampi(y, 0, ph - 1) * pw + posmod(x, pw)

func latitude_of_terrain_row(y: int) -> float:
	return 90.0 - (y + 0.5) / th * 180.0

static func temperature(latitude: float, land_elevation: float) -> float:
	# Same formula as the terrain shader, so derived forests agree with drawn biomes.
	# The far south runs a little colder than the far north. Kept small and close to the pole:
	# a strong southern chill turned everything beyond 60 degrees south into an ice cap.
	var southern_cold: float = smoothstep(60.0, 80.0, -latitude) * 0.12
	return clampf(1.0 - pow(absf(latitude) / 90.0, 1.45) * 1.02 - land_elevation * 0.4 - southern_cold, 0.0, 1.0)

# --- Coast and elevation ---------------------------------------------------

func build_coast() -> void:
	var mask: PackedFloat32Array = make_field(tw, th)
	for landmass: Dictionary in definition["landmasses"]:
		var outline: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in landmass["outline"]:
			outline.append(deg_to_terrain(point))
		fill_polygon(mask, tw, th, outline, 1.0)

	# Domain warp: sample the authored mask through a slow displacement field, which bends
	# straight authored edges into bays and headlands without changing the overall shape.
	var seed_base: int = int(definition["coastline_noise_seed"])
	var warp_x: PackedFloat32Array = noise_field(seed_base + 10, 0.02, 4)
	var warp_y: PackedFloat32Array = noise_field(seed_base + 11, 0.02, 4)
	var warped: PackedFloat32Array = make_field(tw, th)
	for y in range(th):
		for x in range(tw):
			var i: int = y * tw + x
			var sx: int = x + int(round((warp_x[i] - 0.5) * 2.0 * COAST_WARP_CELLS))
			var sy: int = y + int(round((warp_y[i] - 0.5) * 2.0 * COAST_WARP_CELLS))
			warped[i] = mask[terrain_index(sx, sy)]

	coast = blur(warped, tw, th, COAST_BLUR_RADIUS, 2)
	var coast_noise: PackedFloat32Array = noise_field(seed_base, 0.04, 5)
	for i in range(tw * th):
		coast[i] += (coast_noise[i] - 0.5) * COAST_NOISE_AMPLITUDE

	for lake: Dictionary in definition["lakes"]:
		var center: Vector2 = deg_to_terrain(lake["center"])
		var radius: Vector2 = lake["radius"] as Vector2
		var rx: float = radius.x / 360.0 * tw
		var ry: float = radius.y / 180.0 * th
		var world_lake: WorldMapData.Lake = WorldMapData.Lake.new()
		world_lake.name = lake["name"]
		world_lake.center = deg_to_world(lake["center"])
		world_lake.radius = Vector2(radius.x / 360.0 * data.world_size.x, radius.y / 180.0 * data.world_size.y)
		data.lakes.append(world_lake)
		for y in range(int(center.y - ry * 1.3), int(center.y + ry * 1.3) + 1):
			for x in range(int(center.x - rx * 1.3), int(center.x + rx * 1.3) + 1):
				var q: float = Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry).length()
				if q >= 1.25:
					continue
				# Shoreline near q = 1; beyond it the lake no longer lowers the land.
				var i: int = terrain_index(x, y)
				coast[i] = minf(coast[i], lerpf(0.15, 0.62, smoothstep(0.5, 1.25, q)))

	land_binary = make_field(tw, th)
	for i in range(tw * th):
		land_binary[i] = 1.0 if coast[i] > 0.5 else 0.0

func build_elevation() -> void:
	interior = blur(land_binary, tw, th, 14, 2)
	hills = noise_field(int(definition["coastline_noise_seed"]) + 1, 0.012, 4)
	relief = make_field(tw, th)
	var range_height: PackedFloat32Array = make_field(tw, th)
	var highland: PackedFloat32Array = make_field(tw, th)

	for mountain_range: Dictionary in definition["mountain_ranges"]:
		stamp_range(mountain_range, range_height)
	for raised: Dictionary in definition["highlands"]:
		stamp_highland(raised, highland)

	elevation = make_field(tw, th)
	for i in range(tw * th):
		var c: float = coast[i]
		var landness: float = smoothstep(0.5, 0.62, c)
		var seaness: float = 1.0 - smoothstep(0.38, 0.5, c)
		# A steep ramp at the shoreline (crisp coasts) that levels off so inland plains stay low.
		var e: float = minf((c - 0.5) * 0.3, 0.05)
		e += landness * (0.02 + interior[i] * 0.06 + hills[i] * 0.06 + highland[i] + range_height[i] * 0.85)
		# Basins and rises keep the open ocean from reading as one flat color.
		e -= seaness * (0.06 + (1.0 - interior[i]) * 0.7 + (hills[i] - 0.5) * 0.25)
		elevation[i] = clampf(e, -1.0, 1.0)
		relief[i] *= landness

func stamp_range(mountain_range: Dictionary, range_height: PackedFloat32Array) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in mountain_range["path"]:
		points.append(deg_to_terrain(point))
	var width: float = float(mountain_range["width"]) / 360.0 * tw
	var height: float = float(mountain_range["height"])

	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	var total_length: float = maxf(lengths[lengths.size() - 1], 0.001)

	for segment in range(points.size() - 1):
		var a: Vector2 = points[segment]
		var b: Vector2 = points[segment + 1]
		var ab: Vector2 = b - a
		var ab_length_squared: float = maxf(ab.length_squared(), 0.0001)
		var reach: float = width * 2.6
		for y in range(int(minf(a.y, b.y) - reach), int(maxf(a.y, b.y) + reach) + 1):
			for x in range(int(minf(a.x, b.x) - reach), int(maxf(a.x, b.x) + reach) + 1):
				var p: Vector2 = Vector2(x + 0.5, y + 0.5)
				var t: float = clampf((p - a).dot(ab) / ab_length_squared, 0.0, 1.0)
				var i: int = terrain_index(x, y)
				# Noise varies crest width and peak height so ranges grow spurs instead of reading as tubes.
				var distance: float = p.distance_to(a + ab * t) * (0.8 + 0.4 * hills[i])
				var along: float = (lengths[segment] + t * sqrt(ab_length_squared)) / total_length
				var taper: float = 0.35 + 0.65 * smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.88, 1.0, along))
				var profile: float = exp(-pow(distance / width, 2.0)) * taper
				range_height[i] = maxf(range_height[i], height * profile * (0.75 + 0.5 * hills[i]))
				relief[i] = maxf(relief[i], exp(-pow(distance / (width * 1.4), 2.0)) * taper)

func stamp_highland(raised: Dictionary, highland: PackedFloat32Array) -> void:
	var center: Vector2 = deg_to_terrain(raised["center"])
	var radius: Vector2 = raised["radius"] as Vector2
	var rx: float = radius.x / 360.0 * tw
	var ry: float = radius.y / 180.0 * th
	var height: float = float(raised["height"])
	for y in range(int(center.y - ry * 1.5), int(center.y + ry * 1.5) + 1):
		for x in range(int(center.x - rx * 1.5), int(center.x + rx * 1.5) + 1):
			var q: float = Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry).length()
			var value: float = height * (1.0 - smoothstep(0.5, 1.4, q))
			var i: int = terrain_index(x, y)
			highland[i] += value
			relief[i] = maxf(relief[i], value * 0.6)

# --- Rivers ----------------------------------------------------------------

func build_rivers() -> void:
	river_valley = make_field(tw, th)
	var river_index: int = 0
	for river_definition: Dictionary in definition["rivers"]:
		var authored: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in river_definition["path"]:
			authored.append(deg_to_world(point))
		var river: WorldMapData.River = WorldMapData.River.new()
		river.name = river_definition["name"]
		river.is_major = bool(river_definition["major"])
		river.points = chaikin(meander(densify(authored, 8.0), river_index), 2)
		var width: Vector2 = river_definition["width"] as Vector2
		river.widths = widths_along(river.points, width.x, width.y)
		carve_river(river)
		data.rivers.append(river)
		river_index += 1

func meander(points: PackedVector2Array, river_index: int) -> PackedVector2Array:
	# Fixed sine meanders (phase from the river's index) keep authored paths from looking ruled.
	var result: PackedVector2Array = points.duplicate()
	var travelled: float = 0.0
	var total: float = polyline_length(points)
	for i in range(1, points.size() - 1):
		travelled += points[i - 1].distance_to(points[i])
		var tangent: Vector2 = (points[i + 1] - points[i - 1]).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var amplitude: float = RIVER_MEANDER_WORLD * smoothstep(0.0, 0.25, travelled / total) * (1.0 - smoothstep(0.9, 1.0, travelled / total))
		var offset: float = sin(travelled / 37.0 + river_index * 1.7) * amplitude + sin(travelled / 13.0 + river_index * 0.9) * amplitude * 0.35
		result[i] = points[i] + normal * offset
	return result

func widths_along(points: PackedVector2Array, start_width: float, end_width: float) -> PackedFloat32Array:
	var widths: PackedFloat32Array = PackedFloat32Array()
	var total: float = maxf(polyline_length(points), 0.001)
	var travelled: float = 0.0
	for i in range(points.size()):
		if i > 0:
			travelled += points[i - 1].distance_to(points[i])
		widths.append(lerpf(start_width, end_width, pow(travelled / total, 0.8)))
	return widths

func carve_river(river: WorldMapData.River) -> void:
	for point: Vector2 in river.points:
		var cell: Vector2 = world_to_terrain(point)
		for y in range(int(cell.y) - 3, int(cell.y) + 4):
			for x in range(int(cell.x) - 3, int(cell.x) + 4):
				var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(cell)
				if distance > 3.0:
					continue
				var i: int = terrain_index(x, y)
				river_valley[i] = maxf(river_valley[i], 1.0 - distance / 3.0)
				if distance <= 1.6 and elevation[i] > 0.0:
					# Rivers cut shallow valleys but never drop land below sea level.
					elevation[i] = maxf(elevation[i] - 0.012 * (1.0 - distance / 1.6), minf(elevation[i], 0.006))

func trim_river_mouths() -> void:
	# Coastline noise moves the coast from the authored outline, so a mouth may land
	# offshore or inland. Cut rivers back to where they first meet the sea, or carry
	# them on along their last heading until they reach it.
	var river_definitions: Array = definition["rivers"]
	for river_index in range(data.rivers.size()):
		var river: WorldMapData.River = data.rivers[river_index]
		if river_definitions[river_index].has("joins"):
			continue
		while river.points.size() > 3 and data.elevation_at(river.points[river.points.size() - 2]) < -0.002:
			river.points.remove_at(river.points.size() - 1)
			river.widths.remove_at(river.widths.size() - 1)
		var last: int = river.points.size() - 1
		var heading: Vector2 = (river.points[last] - river.points[last - 1]).normalized()
		var mouth_width: float = river.widths[last]
		var steps: int = 0
		while data.elevation_at(river.points[river.points.size() - 1]) >= -0.002 and steps < RIVER_MOUTH_SEARCH_STEPS:
			river.points.append(river.points[river.points.size() - 1] + heading * 4.0)
			river.widths.append(mouth_width)
			steps += 1
		if steps == RIVER_MOUTH_SEARCH_STEPS:
			data.build_warnings.append("River does not reach the sea: " + river.name)

# --- Climate ---------------------------------------------------------------

func build_climate_and_store_terrain() -> void:
	var interior_medium: PackedFloat32Array = blur(land_binary, tw, th, 6, 2)
	var moisture_zones: PackedFloat32Array = make_field(tw, th)
	var forest_zones: PackedFloat32Array = make_field(tw, th)
	for zone: Dictionary in definition["moisture_zones"]:
		stamp_zone(zone, moisture_zones)
	for zone: Dictionary in definition["forest_zones"]:
		stamp_zone(zone, forest_zones)
	var forest_noise: PackedFloat32Array = noise_field(int(definition["coastline_noise_seed"]) + 2, 0.025, 4)

	var texels: PackedFloat32Array = PackedFloat32Array()
	texels.resize(tw * th * 4)
	for y in range(th):
		var latitude: float = latitude_of_terrain_row(y)
		for x in range(tw):
			var i: int = y * tw + x
			var e: float = elevation[i]
			# Wavy climate bands: without this, jungle and desert belts end on ruler-straight latitudes.
			var climate_latitude: float = latitude + (hills[i] - 0.5) * 16.0 + (forest_noise[i] - 0.5) * 8.0
			var moisture: float = latitude_moisture(absf(climate_latitude))
			moisture += 0.18 * (1.0 - interior_medium[i])
			moisture -= 0.1 * smoothstep(0.6, 0.97, interior[i])
			moisture += moisture_zones[i] + 0.16 * river_valley[i] + (hills[i] - 0.5) * 0.12
			moisture = clampf(moisture, 0.0, 1.0)

			var forest: float = 0.0
			if e > 0.0:
				var t: float = temperature(latitude, e)
				# Climate alone gives open woodland; dense forest needs very wet ground or an authored forest.
				forest = smoothstep(0.45, 0.86, moisture) * smoothstep(0.2, 0.34, t) * (1.0 - smoothstep(0.38, 0.62, e))
				# Noise scales authored forests too, so their edges fray instead of tracing an ellipse.
				forest += forest_zones[i] * smoothstep(0.15, 0.3, t) * (0.5 + forest_noise[i]) + (forest_noise[i] - 0.5) * 0.5
				forest = clampf(forest, 0.0, 1.0)

			texels[i * 4] = e
			texels[i * 4 + 1] = moisture
			texels[i * 4 + 2] = forest
			texels[i * 4 + 3] = clampf(relief[i], 0.0, 1.0)

	data.terrain_image = Image.create_from_data(tw, th, false, Image.FORMAT_RGBAF, texels.to_byte_array())

func stamp_zone(zone: Dictionary, field: PackedFloat32Array) -> void:
	var center: Vector2 = deg_to_terrain(zone["center"])
	var radius: Vector2 = zone["radius"] as Vector2
	var rx: float = radius.x / 360.0 * tw
	var ry: float = radius.y / 180.0 * th
	var amount: float = float(zone["amount"])
	for y in range(int(center.y - ry * 1.3), int(center.y + ry * 1.3) + 1):
		for x in range(int(center.x - rx * 1.3), int(center.x + rx * 1.3) + 1):
			var q: float = Vector2((x + 0.5 - center.x) / rx, (y + 0.5 - center.y) / ry).length()
			field[terrain_index(x, y)] += amount * (1.0 - smoothstep(0.4, 1.2, q))

func latitude_moisture(absolute_latitude: float) -> float:
	for i in range(1, LATITUDE_MOISTURE.size()):
		var upper: Vector2 = LATITUDE_MOISTURE[i]
		if absolute_latitude <= upper.x:
			var lower: Vector2 = LATITUDE_MOISTURE[i - 1]
			return lerpf(lower.y, upper.y, (absolute_latitude - lower.x) / (upper.x - lower.x))
	return (LATITUDE_MOISTURE[LATITUDE_MOISTURE.size() - 1] as Vector2).y

# --- Political grid and regions -------------------------------------------

func build_political_fields() -> void:
	var scale_x: int = tw / pw
	var scale_y: int = th / ph
	var samples: float = float(scale_x * scale_y)
	political_land = PackedByteArray()
	political_land.resize(pw * ph)
	political_relief = make_field(pw, ph)
	political_elevation = make_field(pw, ph)
	political_river = PackedByteArray()
	political_river.resize(pw * ph)
	for y in range(ph):
		for x in range(pw):
			var e_sum: float = 0.0
			var r_sum: float = 0.0
			for sy in range(scale_y):
				for sx in range(scale_x):
					var i: int = (y * scale_y + sy) * tw + x * scale_x + sx
					e_sum += elevation[i]
					r_sum += relief[i]
			var pi: int = y * pw + x
			political_elevation[pi] = e_sum / samples
			political_relief[pi] = r_sum / samples
			political_land[pi] = 1 if e_sum > 0.0 else 0

	for river: WorldMapData.River in data.rivers:
		for point: Vector2 in river.points:
			var cell: Vector2i = data.political_cell_at(point)
			political_river[cell.y * pw + cell.x] = 1

	# Uneven travel cost over open ground; without it, regions on flat land grow into
	# boxes because grid distance is octagonal.
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(definition["coastline_noise_seed"]) + 20
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	var image: Image = noise.get_seamless_image(pw, ph, false, false, 0.1, true)
	image.convert(Image.FORMAT_L8)
	var bytes: PackedByteArray = image.get_data()
	political_roughness = make_field(pw, ph)
	for i in range(pw * ph):
		political_roughness[i] = bytes[i] / 255.0

func build_kingdoms() -> void:
	for kingdom_definition: Dictionary in definition["kingdoms"]:
		var kingdom: WorldMapData.Kingdom = WorldMapData.Kingdom.new()
		kingdom.id = data.kingdoms.size()
		kingdom.key = kingdom_definition["key"]
		kingdom.name = kingdom_definition["name"]
		kingdom.color = kingdom_definition["color"]
		kingdom.label_position = deg_to_world(kingdom_definition["label_at"])
		data.kingdoms.append(kingdom)

func kingdom_id_for_key(key: String) -> int:
	for kingdom: WorldMapData.Kingdom in data.kingdoms:
		if kingdom.key == key:
			return kingdom.id
	if key != "":
		data.build_warnings.append("Unknown kingdom key: " + key)
	return -1

func build_regions() -> void:
	var seed_cells: Array[int] = []
	for region_definition: Dictionary in definition["regions"]:
		var region: WorldMapData.Region = WorldMapData.Region.new()
		region.id = data.regions.size()
		region.name = region_definition["name"]
		region.seed_position = deg_to_world(region_definition["at"])
		region.owner_kingdom_id = kingdom_id_for_key(region_definition.get("owner", ""))
		for claim_key: String in region_definition.get("claims", []):
			region.claimant_kingdom_ids.append(kingdom_id_for_key(claim_key))
		region.regional_map_seed = absi(region.name.hash())
		data.regions.append(region)

		var seed_cell: Vector2i = nearest_political_land(data.political_cell_at(region.seed_position), 10)
		if seed_cell.x < 0:
			data.build_warnings.append("Region seed is not near land: " + region.name)
			seed_cells.append(-1)
			continue
		var seed_index: int = seed_cell.y * pw + seed_cell.x
		if seed_cells.has(seed_index):
			data.build_warnings.append("Region seed shares a cell with another region: " + region.name)
			seed_cells.append(-1)
			continue
		seed_cells.append(seed_index)

	var owner: PackedInt32Array
	if definition.has("region_grid"):
		# A generator that already grew the regions (WorldGenerator) hands its partition over.
		# Carving rivers can turn a shore cell to water since then; water belongs to no region.
		owner = (definition["region_grid"] as PackedInt32Array).duplicate()
		for i in range(pw * ph):
			if political_land[i] == 0:
				owner[i] = -1
	else:
		owner = grow_regions(seed_cells)
		assign_unreached_land(owner)
	data.region_grid = owner
	summarize_regions()

# Region i grows from political cell seed_cells[i] (-1: no seed). Needs build_political_fields().
func grow_regions(seed_cells: Array[int]) -> PackedInt32Array:
	var owner: PackedInt32Array = PackedInt32Array()
	owner.resize(pw * ph)
	owner.fill(-1)
	var cost: PackedFloat32Array = make_field(pw, ph)
	cost.fill(INF)
	heap_reset()
	for region_id in range(seed_cells.size()):
		var seed_index: int = seed_cells[region_id]
		if seed_index < 0:
			continue
		cost[seed_index] = 0.0
		owner[seed_index] = region_id
		heap_push(0.0, seed_index)

	# Regions grow over land; ranges, high ground, and rivers are expensive to cross,
	# so neighboring regions meet along watersheds and rivers.
	while heap_size > 0:
		var current_cost: float = heap_keys[0]
		var current: int = heap_pop()
		if current_cost > cost[current]:
			continue
		var cx: int = current % pw
		var cy: int = current / pw
		for offset: Vector2i in REGION_GROWTH_STEPS:
			var ny: int = cy + offset.y
			if ny < 0 or ny >= ph:
				continue
			var neighbor: int = ny * pw + posmod(cx + offset.x, pw)
			if political_land[neighbor] == 0:
				continue
			var step: float = Vector2(offset).length()
			step *= 0.3 + 1.4 * political_roughness[neighbor] + political_relief[neighbor] * 9.0 + maxf(0.0, political_elevation[neighbor] - 0.3) * 6.0
			if political_river[neighbor] == 1:
				step += 4.0
			var next_cost: float = current_cost + step
			if next_cost < cost[neighbor]:
				cost[neighbor] = next_cost
				owner[neighbor] = owner[current]
				heap_push(next_cost, neighbor)
	return owner

func assign_unreached_land(owner: PackedInt32Array) -> void:
	# Islets with no authored region join the nearest region across the water.
	var frontier: PackedInt32Array = PackedInt32Array()
	var nearest: PackedInt32Array = owner.duplicate()
	for i in range(pw * ph):
		if nearest[i] != -1:
			frontier.append(i)
	var head: int = 0
	while head < frontier.size():
		var current: int = frontier[head]
		head += 1
		var cx: int = current % pw
		var cy: int = current / pw
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ny: int = cy + offset.y
			if ny < 0 or ny >= ph:
				continue
			var neighbor: int = ny * pw + posmod(cx + offset.x, pw)
			if nearest[neighbor] == -1:
				nearest[neighbor] = nearest[current]
				frontier.append(neighbor)
	for i in range(pw * ph):
		if political_land[i] == 1 and owner[i] == -1:
			owner[i] = nearest[i]

func summarize_regions() -> void:
	var count: int = data.regions.size()
	var sums: Array[PackedFloat32Array] = []
	for _field in range(7):
		var field: PackedFloat32Array = PackedFloat32Array()
		field.resize(count)
		sums.append(field)
	var cell_size: Vector2 = Vector2(data.world_size.x / pw, data.world_size.y / ph)

	for y in range(ph):
		for x in range(pw):
			var i: int = y * pw + x
			var region_id: int = data.region_grid[i]
			if region_id < 0:
				continue
			var region: WorldMapData.Region = data.regions[region_id]
			region.cell_count += 1
			var center: Vector2 = Vector2((x + 0.5) * cell_size.x, (y + 0.5) * cell_size.y)
			sums[0][region_id] += data.wrapped_delta_x(region.seed_position.x, center.x)
			sums[1][region_id] += center.y
			var terrain: Color = data.terrain_image.get_pixel(clampi(x * tw / pw, 0, tw - 1), clampi(y * th / ph, 0, th - 1))
			sums[2][region_id] += maxf(terrain.r, 0.0)
			sums[3][region_id] += terrain.g
			sums[4][region_id] += terrain.b
			sums[5][region_id] += terrain.a
			sums[6][region_id] += temperature(data.latitude_at(center.y), maxf(terrain.r, 0.0))
			if political_river[i] == 1:
				region.has_river = true
			if not region.has_coast:
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if political_land[political_index(x + offset.x, y + offset.y)] == 0:
						region.has_coast = true
						break

	for region: WorldMapData.Region in data.regions:
		if region.cell_count == 0:
			region.centroid = region.seed_position
			continue
		var n: float = float(region.cell_count)
		region.centroid = Vector2(data.wrap_x(region.seed_position.x + sums[0][region.id] / n), sums[1][region.id] / n)
		region.climate = describe_climate(sums[6][region.id] / n, sums[3][region.id] / n)
		region.landscape = describe_landscape(sums[2][region.id] / n, sums[3][region.id] / n, sums[4][region.id] / n, sums[5][region.id] / n, sums[6][region.id] / n)

func describe_climate(mean_temperature: float, mean_moisture: float) -> String:
	var band: String = "Tropical"
	if mean_temperature < 0.2:
		band = "Polar"
	elif mean_temperature < 0.33:
		band = "Subarctic"
	elif mean_temperature < 0.55:
		band = "Cool temperate"
	elif mean_temperature < 0.74:
		band = "Warm temperate"
	if mean_moisture < 0.25:
		return band + ", arid"
	if mean_moisture < 0.4:
		return band + ", dry"
	if mean_moisture > 0.72:
		return band + ", wet"
	return band

func describe_landscape(mean_elevation: float, mean_moisture: float, mean_forest: float, mean_relief: float, mean_temperature: float) -> String:
	if mean_temperature < 0.14:
		return "Ice and snowfield"
	# Open lowland averages about 0.12 elevation; ranges and plateaus sit well above it.
	var ground: String = "Plains"
	if mean_relief > 0.45:
		ground = "Mountains"
	elif mean_elevation > 0.34:
		ground = "Highlands"
	elif mean_relief > 0.2 or mean_elevation > 0.22:
		ground = "Hills"

	var cover: String = "grassland"
	if mean_temperature < 0.3:
		cover = "tundra"
	elif mean_forest > 0.45:
		cover = "jungle" if mean_temperature > 0.75 else "forest"
	elif mean_moisture < 0.25:
		cover = "desert"
	elif mean_moisture < 0.42:
		cover = "savanna" if mean_temperature > 0.7 else "steppe"
	elif mean_forest > 0.25:
		cover = "woodland"
	return ground + " and " + cover

# --- Settlements and roads -------------------------------------------------

func build_settlements() -> void:
	for settlement_definition: Dictionary in definition["settlements"]:
		var settlement: WorldMapData.Settlement = WorldMapData.Settlement.new()
		settlement.id = data.settlements.size()
		settlement.name = settlement_definition["name"]
		settlement.tier = int(settlement_definition["tier"])
		settlement.population = int(settlement_definition["population"])
		settlement.is_port = bool(settlement_definition.get("port", false))
		settlement.position = deg_to_world(settlement_definition["at"])

		var authored_cell: Vector2i = data.political_cell_at(settlement.position)
		if political_land[authored_cell.y * pw + authored_cell.x] == 0:
			var land_cell: Vector2i = nearest_political_land(authored_cell, 8)
			if land_cell.x < 0:
				data.build_warnings.append("Settlement is at sea: " + settlement.name)
			else:
				settlement.position = data.political_cell_center(land_cell)

		var cell: Vector2i = data.political_cell_at(settlement.position)
		settlement.region_id = data.region_grid[cell.y * pw + cell.x]
		var region: WorldMapData.Region = data.get_region(settlement.region_id)
		if region != null:
			settlement.kingdom_id = region.owner_kingdom_id

		var capital_key: String = settlement_definition.get("capital_of", "")
		if capital_key != "":
			var kingdom_id: int = kingdom_id_for_key(capital_key)
			if kingdom_id >= 0:
				settlement.is_capital = true
				data.kingdoms[kingdom_id].capital_settlement_id = settlement.id
				if settlement.kingdom_id != kingdom_id:
					data.build_warnings.append("Capital lies outside its kingdom: " + settlement.name)
		data.settlements.append(settlement)

func build_roads() -> void:
	var astar: AStarGrid2D = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, pw, ph)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in range(ph):
		for x in range(pw):
			var i: int = y * pw + x
			if political_land[i] == 0:
				astar.set_point_solid(Vector2i(x, y), true)
				continue
			var weight: float = 1.0 + political_relief[i] * 14.0 + maxf(0.0, political_elevation[i] - 0.25) * 10.0
			if political_river[i] == 1:
				weight += 2.5
			astar.set_point_weight_scale(Vector2i(x, y), weight)

	# Major routes are laid first; later roads find the existing roadbed cheaper and join it.
	# Within a class, authored order decides (sort_custom is not stable, so compare indices too).
	var road_definitions: Array = definition["roads"]
	var order: Array[int] = []
	for i in range(road_definitions.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var class_a: int = int(road_definitions[a][2])
		var class_b: int = int(road_definitions[b][2])
		return class_a > class_b or (class_a == class_b and a < b))
	var cell_world: float = data.world_size.x / pw

	for road_index: int in order:
		var road_definition: Array = road_definitions[road_index]
		var from_settlement: WorldMapData.Settlement = data.find_settlement_by_name(road_definition[0])
		var to_settlement: WorldMapData.Settlement = data.find_settlement_by_name(road_definition[1])
		if from_settlement == null or to_settlement == null:
			data.build_warnings.append("Road names an unknown settlement: " + str(road_definition))
			continue
		var path: Array[Vector2i] = astar.get_id_path(data.political_cell_at(from_settlement.position), data.political_cell_at(to_settlement.position))
		if path.is_empty():
			data.build_warnings.append("Road cannot be routed over land: " + str(road_definition))
			continue

		var points: PackedVector2Array = PackedVector2Array()
		for cell: Vector2i in path:
			points.append(data.political_cell_center(cell))
			astar.set_point_weight_scale(cell, maxf(0.45, astar.get_point_weight_scale(cell) * 0.6))
		points[0] = from_settlement.position
		points[points.size() - 1] = to_settlement.position

		var road: WorldMapData.Road = WorldMapData.Road.new()
		road.id = data.roads.size()
		road.from_settlement_id = from_settlement.id
		road.to_settlement_id = to_settlement.id
		road.road_class = int(road_definition[2])
		road.points = chaikin(simplify(points, cell_world * 0.6), 2)
		data.roads.append(road)

func build_labels() -> void:
	for label_definition: Dictionary in definition["geo_labels"]:
		var label: WorldMapData.GeoLabel = WorldMapData.GeoLabel.new()
		label.text = label_definition["text"]
		label.kind = label_definition["kind"]
		label.position = deg_to_world(label_definition["at"])
		label.angle = deg_to_rad(float(label_definition.get("angle", 0.0)))
		data.geo_labels.append(label)

func nearest_political_land(cell: Vector2i, max_radius: int) -> Vector2i:
	if political_land[political_index(cell.x, cell.y)] == 1:
		return Vector2i(posmod(cell.x, pw), clampi(cell.y, 0, ph - 1))
	for radius in range(1, max_radius + 1):
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: float = INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var y: int = cell.y + dy
				if y < 0 or y >= ph:
					continue
				var x: int = posmod(cell.x + dx, pw)
				var distance: float = Vector2(dx, dy).length()
				if political_land[y * pw + x] == 1 and distance < best_distance:
					best_distance = distance
					best = Vector2i(x, y)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

# --- Field helpers ---------------------------------------------------------

static func make_field(width: int, height: int) -> PackedFloat32Array:
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(width * height)
	return field

# Scanline fill; x wraps around the planet so shapes may cross the date line.
static func fill_polygon(field: PackedFloat32Array, width: int, height: int, points: PackedVector2Array, value: float) -> void:
	var min_y: float = INF
	var max_y: float = -INF
	for point: Vector2 in points:
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	var count: int = points.size()
	for y in range(clampi(int(floor(min_y)), 0, height - 1), clampi(int(ceil(max_y)), 0, height - 1) + 1):
		var row_center: float = y + 0.5
		var crossings: PackedFloat32Array = PackedFloat32Array()
		for i in range(count):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % count]
			if (a.y <= row_center) != (b.y <= row_center):
				crossings.append(a.x + (row_center - a.y) * (b.x - a.x) / (b.y - a.y))
		crossings.sort()
		var k: int = 0
		while k + 1 < crossings.size():
			for x in range(int(ceil(crossings[k] - 0.5)), int(floor(crossings[k + 1] - 0.5)) + 1):
				field[y * width + posmod(x, width)] = value
			k += 2

# Repeated running-sum box blur: wraps horizontally, clamps at the poles.
static func blur(source: PackedFloat32Array, width: int, height: int, radius: int, passes: int) -> PackedFloat32Array:
	var a: PackedFloat32Array = source.duplicate()
	var b: PackedFloat32Array = make_field(width, height)
	var inverse: float = 1.0 / float(2 * radius + 1)
	for _pass in range(passes):
		for y in range(height):
			var row: int = y * width
			var sum: float = 0.0
			for k in range(-radius, radius + 1):
				sum += a[row + posmod(k, width)]
			for x in range(width):
				b[row + x] = sum * inverse
				sum += a[row + posmod(x + radius + 1, width)] - a[row + posmod(x - radius, width)]
		for x in range(width):
			var sum: float = 0.0
			for k in range(-radius, radius + 1):
				sum += b[clampi(k, 0, height - 1) * width + x]
			for y in range(height):
				a[y * width + x] = sum * inverse
				sum += b[mini(y + radius + 1, height - 1) * width + x] - b[maxi(y - radius, 0) * width + x]
	return a

func noise_field(noise_seed: int, frequency: float, octaves: int) -> PackedFloat32Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	var image: Image = noise.get_seamless_image(tw, th, false, false, 0.1, true)
	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)
	var bytes: PackedByteArray = image.get_data()
	var field: PackedFloat32Array = make_field(tw, th)
	for i in range(tw * th):
		field[i] = bytes[i] / 255.0
	return field

func heap_reset() -> void:
	heap_keys = PackedFloat32Array()
	heap_values = PackedInt32Array()
	heap_size = 0

func heap_push(key: float, value: int) -> void:
	if heap_size == heap_keys.size():
		heap_keys.resize(maxi(64, heap_size * 2))
		heap_values.resize(maxi(64, heap_size * 2))
	var i: int = heap_size
	heap_size += 1
	while i > 0:
		var parent: int = (i - 1) / 2
		if heap_keys[parent] <= key:
			break
		heap_keys[i] = heap_keys[parent]
		heap_values[i] = heap_values[parent]
		i = parent
	heap_keys[i] = key
	heap_values[i] = value

func heap_pop() -> int:
	var top: int = heap_values[0]
	heap_size -= 1
	if heap_size == 0:
		return top
	var key: float = heap_keys[heap_size]
	var value: int = heap_values[heap_size]
	var i: int = 0
	while true:
		var child: int = i * 2 + 1
		if child >= heap_size:
			break
		if child + 1 < heap_size and heap_keys[child + 1] < heap_keys[child]:
			child += 1
		if heap_keys[child] >= key:
			break
		heap_keys[i] = heap_keys[child]
		heap_values[i] = heap_values[child]
		i = child
	heap_keys[i] = key
	heap_values[i] = value
	return top

# --- Polyline helpers ------------------------------------------------------

static func polyline_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total

static func densify(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var pieces: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in range(pieces):
			result.append(a.lerp(b, float(k) / pieces))
	result.append(points[points.size() - 1])
	return result

static func chaikin(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result: PackedVector2Array = points
	for _iteration in range(iterations):
		if result.size() < 3:
			return result
		var smoothed: PackedVector2Array = PackedVector2Array([result[0]])
		for i in range(result.size() - 1):
			smoothed.append(result[i].lerp(result[i + 1], 0.25))
			smoothed.append(result[i].lerp(result[i + 1], 0.75))
		smoothed.append(result[result.size() - 1])
		result = smoothed
	return result

# Ramer-Douglas-Peucker: drop grid staircase points that stay within tolerance.
static func simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var a: Vector2 = points[span.x]
		var b: Vector2 = points[span.y]
		var farthest: int = -1
		var farthest_distance: float = tolerance
		for i in range(span.x + 1, span.y):
			var distance: float = Geometry2D.get_closest_point_to_segment(points[i], a, b).distance_to(points[i])
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = i
		if farthest >= 0:
			keep[farthest] = 1
			stack.append(Vector2i(span.x, farthest))
			stack.append(Vector2i(farthest, span.y))
	var result: PackedVector2Array = PackedVector2Array()
	for i in range(points.size()):
		if keep[i] == 1:
			result.append(points[i])
	return result
