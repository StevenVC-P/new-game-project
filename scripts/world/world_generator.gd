class_name WorldGenerator
extends RefCounted

# A new planet from a seed, in the same shape as FixedWorldDefinition: continents, ranges,
# climate, lakes, rivers, kingdoms, regions, settlements, roads, and labels.
# WorldFieldBuilder builds it in two halves. The first half (coast and elevation) comes from
# the planned continents, ranges, and lakes; this generator then reads that real land to drain
# rivers to the sea and to put regions, towns, and roads on it, and the builder finishes.
# The same seed always gives the same world.

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

# Continents stay in settled latitudes; the far north and south are open (and partly frozen)
# sea, so no ice cap of land spans the planet.
const NORTH_LAND_LIMIT: float = 72.0
const SOUTH_LAND_LIMIT: float = -58.0
const LAND_FRACTION_RANGE: Vector2 = Vector2(0.27, 0.32)
# Open ocean between continents, in degrees. Coastline warp moves coasts by up to ~6 degrees,
# so smaller gaps let neighbouring continents grow together.
const CONTINENT_GAP: float = 7.0
const LOBE_POINTS: int = 28

# Water bodies at least this many political cells are sea; smaller ones are lakes.
const MIN_OCEAN_CELLS: int = 200
# Drainage: flow is rain-weighted cells upstream (a wet cell adds about 0.5).
const MIN_MOUTH_FLOW: float = 40.0
const MAJOR_RIVER_FLOW: float = 160.0
const SOURCE_FLOW: float = 4.0
const TRIBUTARY_FLOW: float = 28.0
const MIN_RIVER_CELLS: int = 12
const MAX_RIVERS: int = 26

const CELLS_PER_REGION: float = 420.0
const MAX_REGIONS: int = 180
const MIN_ISLAND_REGION_CELLS: int = 20
# Below this temperature land is frozen: no towns, no kingdoms.
const FROZEN_TEMPERATURE: float = 0.12

const KINGDOM_COLORS: Array[Color] = [
	Color(0.72, 0.16, 0.14), Color(0.18, 0.38, 0.66), Color(0.70, 0.22, 0.52), Color(0.80, 0.56, 0.08),
	Color(0.08, 0.52, 0.40), Color(0.46, 0.30, 0.72), Color(0.88, 0.45, 0.10), Color(0.22, 0.52, 0.18),
	Color(0.10, 0.46, 0.62), Color(0.55, 0.34, 0.18),
]

var rng: RandomNumberGenerator
var names: WorldNameGenerator
var builder: WorldFieldBuilder
var definition: Dictionary
var pw: int
var ph: int
var cell_degrees: float

# Planning, before the builder runs: the authored-style continent outlines on the political grid.
var continents: Array[Dictionary] = []
var plan_owner: PackedFloat32Array
var plan_coast_distance: PackedInt32Array
var continent_cell_lists: Array[PackedInt32Array] = []
var ranges: Array[Dictionary] = []
var desert_zones: Array[Dictionary] = []

# The built land, read back from the builder's first half.
var land: PackedByteArray
var is_ocean: PackedByteArray
var coast_distance: PackedInt32Array
var landmass: PackedInt32Array
var landmass_sizes: PackedInt32Array
var landmass_cultures: PackedInt32Array
var road_component: PackedInt32Array
var moisture: PackedFloat32Array
var temperature: PackedFloat32Array
var river_cells: PackedByteArray

# Regions, by index in definition["regions"].
var region_seeds: Array[int] = []
var region_owner: PackedInt32Array
var region_stats: Array[Dictionary] = []
var region_neighbors: Array[Dictionary] = []
var region_kingdom: PackedInt32Array
var region_claims: Array[Array] = []
var region_culture: PackedInt32Array
var kingdom_capital_region: Array[int] = []
var kingdom_culture: Array[int] = []
var settlement_cells: Array[int] = []

static func build(world_seed: int) -> WorldMapData:
	return WorldGenerator.new().generate(world_seed)

func generate(world_seed: int) -> WorldMapData:
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	names = WorldNameGenerator.new(rng)
	pw = FixedWorldDefinition.POLITICAL_SIZE.x
	ph = FixedWorldDefinition.POLITICAL_SIZE.y
	cell_degrees = 360.0 / pw
	definition = {
		"world_seed": world_seed,
		"world_size": FixedWorldDefinition.WORLD_SIZE,
		"terrain_size": FixedWorldDefinition.TERRAIN_SIZE,
		"political_size": FixedWorldDefinition.POLITICAL_SIZE,
		"coastline_noise_seed": rng.randi_range(1, 999999),
		"landmasses": [], "lakes": [], "mountain_ranges": [], "highlands": [],
		"moisture_zones": [], "forest_zones": [], "rivers": [], "kingdoms": [],
		"regions": [], "settlements": [], "roads": [], "geo_labels": [],
	}

	plan_continents()
	plan_relief()
	plan_climate()
	plan_lakes()

	builder = WorldFieldBuilder.new()
	builder.begin_world(definition)
	builder.build_political_fields()
	read_land()
	plan_rivers()
	plan_regions()
	plan_kingdoms()
	plan_region_names()
	plan_settlements()
	plan_roads()
	plan_labels()
	return builder.finish_world()

# --- Coordinates -----------------------------------------------------------

func cell_to_degrees(cell: int) -> Vector2:
	return Vector2((cell % pw + 0.5) * cell_degrees, 90.0 - (cell / pw + 0.5) * cell_degrees)

func degrees_to_cell(deg: Vector2) -> int:
	var x: int = posmod(int(floor(deg.x / cell_degrees)), pw)
	var y: int = clampi(int(floor((90.0 - deg.y) / cell_degrees)), 0, ph - 1)
	return y * pw + x

func degrees_to_grid(deg: Vector2) -> Vector2:
	return Vector2(deg.x / cell_degrees, (90.0 - deg.y) / cell_degrees)

func latitude_of_cell(cell: int) -> float:
	return 90.0 - (cell / pw + 0.5) * cell_degrees

static func wrapped_dx(from_lon: float, to_lon: float) -> float:
	return fposmod(to_lon - from_lon + 180.0, 360.0) - 180.0

static func degree_distance(a: Vector2, b: Vector2) -> float:
	return Vector2(wrapped_dx(a.x, b.x), b.y - a.y).length()

func neighbor(cell: int, offset: Vector2i) -> int:
	var y: int = cell / pw + offset.y
	if y < 0 or y >= ph:
		return -1
	return y * pw + posmod(cell % pw + offset.x, pw)

func random_item(list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]

# --- Continents ------------------------------------------------------------

func plan_continents() -> void:
	var target: float = rng.randf_range(LAND_FRACTION_RANGE.x, LAND_FRACTION_RANGE.y)
	var majors: int = rng.randi_range(4, 6)
	for _continent in range(majors):
		try_add_continent(true, 80)
	for _continent in range(rng.randi_range(1, 3)):
		try_add_continent(false, 40)
	# Continents then grow lobe by lobe at their edges until the planet has its land.
	var attempts: int = 0
	while land_fraction() < target and attempts < 600:
		try_grow_continent()
		attempts += 1

	for continent_index in range(continents.size()):
		if bool(continents[continent_index]["major"]) and rng.randf() < 0.6:
			add_archipelago(continent_index)
	for _island in range(rng.randi_range(5, 9)):
		try_add_island(Vector2(rng.randf_range(0.0, 360.0), rng.randf_range(-48.0, 66.0)), rng.randf_range(1.0, 2.8), 4.0, -1)

	move_seam_into_ocean()
	for continent: Dictionary in continents:
		for lobe: Dictionary in continent["lobes"]:
			definition["landmasses"].append({"name": "", "outline": lobe["outline"]})
	plan_coast_distance = grid_distance(plan_water_mask(), 1)
	for _continent in range(continents.size()):
		continent_cell_lists.append(PackedInt32Array())
	for i in range(pw * ph):
		if plan_owner[i] > 0.0:
			continent_cell_lists[int(plan_owner[i]) - 1].append(i)

func try_add_continent(major: bool, attempts: int) -> void:
	for _attempt in range(attempts):
		var candidate: Dictionary = make_continent(major)
		if continent_fits(candidate, CONTINENT_GAP, -1):
			add_continent(candidate)
			return

func try_grow_continent() -> void:
	var continent_index: int = rng.randi_range(0, continents.size() - 1)
	var continent: Dictionary = continents[continent_index]
	if continent["lobes"].size() == 1 and not bool(continent["major"]):
		return
	var base: Dictionary = random_item(continent["lobes"])
	# Outward from the continent's middle, so new lobes add land instead of covering old.
	var middle: Vector2 = continent_middle(continent)
	var outward: Vector2 = Vector2(wrapped_dx(middle.x, (base["center"] as Vector2).x), (base["center"] as Vector2).y - middle.y)
	var direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	if outward.length() > 1.0:
		direction = outward.normalized().rotated(rng.randf_range(-1.1, 1.1))
	var radius: float = float(continent["radius"]) * rng.randf_range(0.5, 0.95)
	var center: Vector2 = base["center"] + direction * (float(base["radius"]) + radius * rng.randf_range(0.2, 0.6))
	if center.y > 60.0 or center.y < -48.0:
		return
	var lobe: Dictionary = make_lobe(center, radius)
	if continent_fits({"lobes": [lobe]}, CONTINENT_GAP, continent_index):
		continent["lobes"].append(lobe)
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in lobe["outline"]:
			points.append(degrees_to_grid(point))
		WorldFieldBuilder.fill_polygon(plan_owner, pw, ph, points, continent_index + 1.0)

func make_continent(major: bool) -> Dictionary:
	var radius: float = rng.randf_range(11.0, 16.0) if major else rng.randf_range(5.0, 8.0)
	var lobe_count: int = rng.randi_range(3, 6) if major else rng.randi_range(1, 3)
	var position: Vector2 = Vector2(rng.randf_range(0.0, 360.0), rng.randf_range(-38.0, 50.0))
	var heading: float = rng.randf_range(0.0, TAU)
	var lobes: Array[Dictionary] = []
	for _lobe in range(lobe_count):
		lobes.append(make_lobe(position, radius * rng.randf_range(0.65, 1.1)))
		heading += rng.randf_range(-0.8, 0.8)
		position += Vector2(cos(heading), sin(heading)) * radius * rng.randf_range(0.95, 1.35)
		# The spine turns back before it reaches the polar seas.
		if position.y > 56.0 or position.y < -46.0:
			heading = atan2(-sin(heading), cos(heading))
			position.y = clampf(position.y, -46.0, 56.0)
	var axis: float = heading
	if lobes.size() > 1:
		var spine: Vector2 = lobes[lobes.size() - 1]["center"] - lobes[0]["center"]
		axis = atan2(spine.y, spine.x)
	for _peninsula in range(rng.randi_range(1, 3) if major else rng.randi_range(0, 1)):
		var base: Dictionary = random_item(lobes)
		var direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
		var small: float = float(base["radius"]) * rng.randf_range(0.3, 0.5)
		lobes.append(make_lobe(base["center"] + direction * (float(base["radius"]) * 0.95 + small * 0.5), small))
	return {"lobes": lobes, "major": major, "axis": axis, "radius": radius}

func continent_middle(continent: Dictionary) -> Vector2:
	var lobes: Array = continent["lobes"]
	var anchor: Vector2 = lobes[0]["center"]
	var sum: Vector2 = Vector2.ZERO
	for lobe: Dictionary in lobes:
		var center: Vector2 = lobe["center"]
		sum += Vector2(anchor.x + wrapped_dx(anchor.x, center.x), center.y)
	return sum / lobes.size()

# One rounded, stretched, wobbly blob; continents are chains of them.
func make_lobe(center: Vector2, radius: float) -> Dictionary:
	var stretch: float = rng.randf_range(0.75, 1.35)
	var rotation: float = rng.randf_range(0.0, PI)
	var harmonics: Array[Vector3] = []
	var wobble: float = 0.0
	for k in range(2, 6):
		var amplitude: float = rng.randf_range(0.0, 0.3 / k)
		harmonics.append(Vector3(k, amplitude, rng.randf_range(0.0, TAU)))
		wobble += amplitude
	var outline: Array[Vector2] = []
	for i in range(LOBE_POINTS):
		var angle: float = TAU * i / LOBE_POINTS
		var r: float = 1.0
		for harmonic: Vector3 in harmonics:
			r += harmonic.y * sin(harmonic.x * angle + harmonic.z)
		var point: Vector2 = center + (Vector2(cos(angle) * stretch, sin(angle) / stretch) * radius * r).rotated(rotation)
		# Land reaching past the limits is squashed back rather than cut, so no coast runs along a latitude.
		if point.y > NORTH_LAND_LIMIT:
			point.y = NORTH_LAND_LIMIT + (point.y - NORTH_LAND_LIMIT) * 0.25
		elif point.y < SOUTH_LAND_LIMIT:
			point.y = SOUTH_LAND_LIMIT + (point.y - SOUTH_LAND_LIMIT) * 0.25
		outline.append(point)
	# "reach" is a typical radius, used for spacing; the wobble rarely peaks in every direction.
	return {"center": center, "radius": radius, "reach": radius * (1.0 + wobble * 0.5) * (1.0 + absf(stretch - 1.0) * 0.5), "outline": outline}

# Keeps `gap` degrees of sea to every other continent. Lobes may overlap their own continent
# (own_gap < 0) or keep a narrow strait to it (islands off its coast).
func continent_fits(candidate: Dictionary, gap: float, own_continent: int, own_gap: float = -1.0) -> bool:
	for lobe: Dictionary in candidate["lobes"]:
		var center: Vector2 = lobe["center"]
		for continent_index in range(continents.size()):
			var lobe_gap: float = own_gap if continent_index == own_continent else gap
			if lobe_gap < 0.0:
				continue
			for other: Dictionary in continents[continent_index]["lobes"]:
				if degree_distance(center, other["center"]) < float(lobe["reach"]) + float(other["reach"]) + lobe_gap:
					return false
	return true

func add_continent(continent: Dictionary) -> void:
	continent["culture"] = rng.randi_range(0, names.culture_count() - 1)
	continents.append(continent)
	if plan_owner.is_empty():
		plan_owner = WorldFieldBuilder.make_field(pw, ph)
	rasterize_continent(continents.size() - 1)

func add_archipelago(continent_index: int) -> void:
	var lobe: Dictionary = random_item(continents[continent_index]["lobes"])
	var direction: Vector2 = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	var position: Vector2 = lobe["center"] + direction * (float(lobe["reach"]) + 3.5)
	var heading: float = direction.angle() + (PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5)
	for _island in range(rng.randi_range(3, 6)):
		try_add_island(position, rng.randf_range(0.9, 2.2), 4.0, continent_index)
		heading += rng.randf_range(-0.5, 0.5)
		position += Vector2(cos(heading), sin(heading)) * rng.randf_range(2.8, 4.5)

func try_add_island(center: Vector2, radius: float, gap: float, near_continent: int) -> void:
	if center.y > NORTH_LAND_LIMIT + 2.0 or center.y < SOUTH_LAND_LIMIT:
		return
	var island: Dictionary = {"lobes": [make_lobe(center, radius)], "major": false, "axis": 0.0, "radius": radius}
	if continent_fits(island, gap, near_continent, 1.0):
		add_continent(island)

func rasterize_continent(continent_index: int) -> void:
	for lobe: Dictionary in continents[continent_index]["lobes"]:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in lobe["outline"]:
			points.append(degrees_to_grid(point))
		WorldFieldBuilder.fill_polygon(plan_owner, pw, ph, points, continent_index + 1.0)

func land_fraction() -> float:
	if continents.is_empty():
		return 0.0
	return 1.0 - float(plan_owner.count(0.0)) / float(pw * ph)

func plan_water_mask() -> PackedByteArray:
	var water: PackedByteArray = PackedByteArray()
	water.resize(pw * ph)
	for i in range(pw * ph):
		water[i] = 1 if plan_owner[i] == 0.0 else 0
	return water

# The planet wraps; put the date line in the emptiest ocean so few coasts, rivers, or roads cross it.
func move_seam_into_ocean() -> void:
	var column_land: PackedInt32Array = PackedInt32Array()
	column_land.resize(pw)
	for i in range(pw * ph):
		if plan_owner[i] != 0.0:
			column_land[i % pw] += 1
	var best_x: int = 0
	var best_sum: int = 1 << 30
	for x in range(pw):
		var sum: int = 0
		for k in range(-8, 9):
			sum += column_land[posmod(x + k, pw)]
		if sum < best_sum:
			best_sum = sum
			best_x = x
	var shift: float = (best_x + 0.5) * cell_degrees
	for continent: Dictionary in continents:
		for lobe: Dictionary in continent["lobes"]:
			var center: Vector2 = lobe["center"]
			# The outline moves with its center, by the same whole turn, so it stays in one piece.
			var moved: float = fposmod(center.x - shift, 360.0) - center.x
			lobe["center"] = center + Vector2(moved, 0.0)
			var outline: Array[Vector2] = lobe["outline"]
			for i in range(outline.size()):
				outline[i] += Vector2(moved, 0.0)
	plan_owner = WorldFieldBuilder.make_field(pw, ph)
	for continent_index in range(continents.size()):
		rasterize_continent(continent_index)

func wrap_degrees(deg: Vector2) -> Vector2:
	return Vector2(fposmod(deg.x, 360.0), deg.y)

func continent_cells(continent_index: int, min_coast_distance: int) -> PackedInt32Array:
	var cells: PackedInt32Array = PackedInt32Array()
	for cell: int in continent_cell_lists[continent_index]:
		if plan_coast_distance[cell] >= min_coast_distance:
			cells.append(cell)
	return cells

# --- Relief, climate, and lakes (planned on the continents) ---------------

func plan_relief() -> void:
	for continent_index in range(continents.size()):
		var continent: Dictionary = continents[continent_index]
		var major: bool = continent["major"]
		var interior: PackedInt32Array = continent_cells(continent_index, 5)
		if interior.is_empty():
			continue
		var range_count: int = rng.randi_range(1, 3) if major else (1 if rng.randf() < 0.5 else 0)
		for range_index in range(range_count):
			var tallest: bool = major and range_index == 0
			plan_range(continent_index, interior, rng.randf_range(0.75, 1.0) if tallest else rng.randf_range(0.35, 0.75))
		for _highland in range(rng.randi_range(0, 2) if major else 0):
			var center: Vector2 = cell_to_degrees(interior[rng.randi_range(0, interior.size() - 1)])
			definition["highlands"].append({"center": center, "radius": Vector2(rng.randf_range(4.0, 9.0), rng.randf_range(3.0, 6.0)), "height": rng.randf_range(0.08, 0.4)})

func plan_range(continent_index: int, interior: PackedInt32Array, height: float) -> void:
	var value: float = continent_index + 1.0
	for _attempt in range(12):
		var position: Vector2 = cell_to_degrees(interior[rng.randi_range(0, interior.size() - 1)])
		var heading: float = float(continents[continent_index]["axis"]) + rng.randf_range(-0.6, 0.6)
		var path: Array[Vector2] = [position]
		for _step in range(rng.randi_range(3, 7)):
			heading += rng.randf_range(-0.35, 0.35)
			var next: Vector2 = position + Vector2(cos(heading), sin(heading)) * rng.randf_range(3.5, 6.0)
			var cell: int = degrees_to_cell(next)
			if plan_owner[cell] != value or plan_coast_distance[cell] < 2:
				break
			path.append(next)
			position = next
		if path.size() < 3:
			continue
		var mountain_range: Dictionary = {"name": names.range_name(int(continents[continent_index]["culture"])),
			"height": height, "width": rng.randf_range(1.5, 2.8), "path": path}
		definition["mountain_ranges"].append(mountain_range)
		ranges.append(mountain_range)
		return

func plan_climate() -> void:
	# Rain shadows: prevailing winds blow from the east in the tropics and polar zones and
	# from the west in mid-latitudes, so the lee side of a range is dry and the windward side wet.
	for mountain_range: Dictionary in ranges:
		var path: Array[Vector2] = mountain_range["path"]
		var low: Vector2 = path[0]
		var high: Vector2 = path[0]
		for point: Vector2 in path:
			low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
			high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
		var middle: Vector2 = (low + high) * 0.5
		var lee: float = 1.0 if absf(middle.y) >= 30.0 and absf(middle.y) < 60.0 else -1.0
		var reach: Vector2 = Vector2(maxf(5.0, (high.x - low.x) * 0.5 + 3.0), maxf(5.0, (high.y - low.y) * 0.5 + 3.0))
		var offset: float = float(mountain_range["width"]) + 5.0
		var strength: float = float(mountain_range["height"])
		definition["moisture_zones"].append({"center": middle + Vector2(lee * offset, 0.0), "radius": reach, "amount": -0.35 * strength})
		definition["moisture_zones"].append({"center": middle - Vector2(lee * offset, 0.0), "radius": reach * 0.8, "amount": 0.3 * strength})

	for continent_index in range(continents.size()):
		var continent: Dictionary = continents[continent_index]
		if continent["lobes"].size() == 1 and not bool(continent["major"]):
			continue
		var interior: PackedInt32Array = continent_cells(continent_index, 4)
		var subtropical: Array[int] = []
		var wet_belts: Array[int] = []
		for cell: int in interior:
			var latitude: float = absf(latitude_of_cell(cell))
			if latitude >= 14.0 and latitude <= 34.0:
				subtropical.append(cell)
			elif latitude < 12.0 or (latitude >= 40.0 and latitude <= 62.0):
				wet_belts.append(cell)
		if not subtropical.is_empty() and bool(continent["major"]):
			# The latitude bands already dry the subtropics; one great desert per continent at most.
			for _desert in range(1 if rng.randf() < 0.7 else 0):
				var zone: Dictionary = {"center": cell_to_degrees(random_item(subtropical)), "radius": Vector2(rng.randf_range(8.0, 14.0), rng.randf_range(5.0, 8.0)), "amount": rng.randf_range(-0.6, -0.35)}
				definition["moisture_zones"].append(zone)
				zone["culture"] = continent["culture"]
				desert_zones.append(zone)
		if not wet_belts.is_empty():
			for _wet in range(rng.randi_range(1, 3)):
				definition["moisture_zones"].append({"center": cell_to_degrees(random_item(wet_belts)), "radius": Vector2(rng.randf_range(8.0, 14.0), rng.randf_range(5.0, 8.0)), "amount": rng.randf_range(0.15, 0.35)})
			for _forest in range(rng.randi_range(2, 4)):
				definition["forest_zones"].append({"center": cell_to_degrees(random_item(wet_belts)), "radius": Vector2(rng.randf_range(6.0, 14.0), rng.randf_range(4.0, 6.0)), "amount": rng.randf_range(0.25, 0.45)})

func plan_lakes() -> void:
	for continent_index in range(continents.size()):
		if not bool(continents[continent_index]["major"]):
			continue
		var interior: PackedInt32Array = continent_cells(continent_index, 10)
		if interior.is_empty():
			continue
		for _lake in range(rng.randi_range(0, 2)):
			var center: Vector2 = cell_to_degrees(interior[rng.randi_range(0, interior.size() - 1)])
			if near_a_range(center, 4.0):
				continue
			var culture: int = continents[continent_index]["culture"]
			definition["lakes"].append({"name": names.unique("Lake " + names.base_name(culture)), "center": center,
				"radius": Vector2(rng.randf_range(1.6, 3.5), rng.randf_range(1.0, 2.0))})

func near_a_range(point: Vector2, distance: float) -> bool:
	for mountain_range: Dictionary in ranges:
		for crest: Vector2 in mountain_range["path"]:
			if degree_distance(point, crest) < distance + float(mountain_range["width"]):
				return true
	return false

# --- The built land ---------------------------------------------------------

func read_land() -> void:
	var size: int = pw * ph
	land = builder.political_land
	var water: PackedByteArray = PackedByteArray()
	water.resize(size)
	for i in range(size):
		water[i] = 1 - land[i]
	var water_components: Array = label_components(water, false, true)
	var water_ids: PackedInt32Array = water_components[0]
	var water_sizes: PackedInt32Array = water_components[1]
	is_ocean = PackedByteArray()
	is_ocean.resize(size)
	for i in range(size):
		if water_ids[i] >= 0 and water_sizes[water_ids[i]] >= MIN_OCEAN_CELLS:
			is_ocean[i] = 1
	coast_distance = grid_distance(water, 1)

	var landmasses: Array = label_components(land, true, true)
	landmass = landmasses[0]
	landmass_sizes = landmasses[1]
	landmass_cultures = PackedInt32Array()
	for _landmass in range(landmass_sizes.size()):
		landmass_cultures.append(-1)
	# A landmass takes the culture of a planned continent it covers.
	for i in range(size):
		var id: int = landmass[i]
		if id >= 0 and landmass_cultures[id] < 0 and plan_owner[i] > 0.0:
			landmass_cultures[id] = continents[int(plan_owner[i]) - 1]["culture"]
	for id in range(landmass_cultures.size()):
		if landmass_cultures[id] < 0:
			landmass_cultures[id] = rng.randi_range(0, names.culture_count() - 1)
	# Roads are pathfound without wrapping and without squeezing diagonally between water cells.
	road_component = label_components(land, false, false)[0]

	moisture = WorldFieldBuilder.make_field(pw, ph)
	temperature = WorldFieldBuilder.make_field(pw, ph)
	for i in range(size):
		var latitude: float = latitude_of_cell(i)
		moisture[i] = builder.latitude_moisture(absf(latitude))
		temperature[i] = WorldFieldBuilder.temperature(latitude, maxf(builder.political_elevation[i], 0.0))
	for zone: Dictionary in definition["moisture_zones"]:
		stamp_zone(zone, moisture)

# Same falloff as WorldFieldBuilder.stamp_zone, on the political grid.
func stamp_zone(zone: Dictionary, field: PackedFloat32Array) -> void:
	var center: Vector2 = degrees_to_grid(zone["center"])
	var radius: Vector2 = (zone["radius"] as Vector2) / cell_degrees
	var amount: float = float(zone["amount"])
	for y in range(int(center.y - radius.y * 1.3), int(center.y + radius.y * 1.3) + 1):
		if y < 0 or y >= ph:
			continue
		for x in range(int(center.x - radius.x * 1.3), int(center.x + radius.x * 1.3) + 1):
			var q: float = Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y).length()
			field[y * pw + posmod(x, pw)] += amount * (1.0 - smoothstep(0.4, 1.2, q))

func is_coastal(cell: int) -> bool:
	for offset: Vector2i in NEIGHBORS_8:
		var n: int = neighbor(cell, offset)
		if n >= 0 and is_ocean[n] == 1:
			return true
	return false

func is_frozen(cell: int) -> bool:
	return temperature[cell] < FROZEN_TEMPERATURE

# --- Rivers ----------------------------------------------------------------

func plan_rivers() -> void:
	var size: int = pw * ph
	var elevation: PackedFloat32Array = builder.political_elevation
	var downstream: PackedInt32Array = PackedInt32Array()
	downstream.resize(size)
	downstream.fill(-1)
	var outlet: PackedInt32Array = downstream.duplicate()
	var level: PackedFloat32Array = WorldFieldBuilder.make_field(pw, ph)
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(size)
	var order: PackedInt32Array = PackedInt32Array()

	# Priority flood from the sea: every land cell drains to the neighbour it was reached
	# from, so water always finds the sea, through lakes and out of hollows, never stuck in a pit.
	builder.heap_reset()
	for i in range(size):
		if is_ocean[i] == 1:
			continue
		for offset: Vector2i in NEIGHBORS_8:
			var n: int = neighbor(i, offset)
			if n >= 0 and is_ocean[n] == 1:
				outlet[i] = n
				visited[i] = 1
				level[i] = elevation[i]
				builder.heap_push(level[i], i)
				break
	while builder.heap_size > 0:
		var current: int = builder.heap_pop()
		order.append(current)
		for offset: Vector2i in NEIGHBORS_8:
			var n: int = neighbor(current, offset)
			if n < 0 or visited[n] == 1 or is_ocean[n] == 1:
				continue
			visited[n] = 1
			downstream[n] = current
			# Jitter on flats keeps filled hollows from draining in ruler-straight lines.
			level[n] = maxf(elevation[n], level[current] + 0.00001 * (0.5 + rng.randf()))
			builder.heap_push(level[n], n)

	var flow: PackedFloat32Array = WorldFieldBuilder.make_field(pw, ph)
	for i in range(size):
		if land[i] == 1:
			var rain: float = clampf(moisture[i], 0.05, 1.0)
			flow[i] = rain * rain * (0.2 if is_frozen(i) else 1.0)
	for k in range(order.size() - 1, -1, -1):
		var cell: int = order[k]
		if downstream[cell] >= 0:
			flow[downstream[cell]] += flow[cell]

	var mouths: Array[int] = []
	for i in range(size):
		if outlet[i] >= 0 and land[i] == 1 and flow[i] >= MIN_MOUTH_FLOW:
			mouths.append(i)
	mouths.sort_custom(func(a: int, b: int) -> bool: return flow[a] > flow[b] or (flow[a] == flow[b] and a < b))

	river_cells = PackedByteArray()
	river_cells.resize(size)
	var max_flow: float = flow[mouths[0]] if not mouths.is_empty() else 1.0
	var trunks: int = 0
	for mouth: int in mouths:
		if trunks >= MAX_RIVERS:
			break
		var course: PackedInt32Array = trace_upstream(mouth, downstream, flow)
		if course.size() < MIN_RIVER_CELLS or mean_temperature(course) < FROZEN_TEMPERATURE:
			continue
		var culture: int = landmass_cultures[landmass[mouth]]
		var river_name: String = names.base_name(culture)
		var major: bool = flow[mouth] >= MAJOR_RIVER_FLOW
		var mouth_width: float = lerpf(1.6, 5.0, sqrt(flow[mouth] / max_flow))
		var path: PackedInt32Array = reversed(course)
		path.append(outlet[mouth])
		add_river(river_name, major, path, Vector2(rng.randf_range(0.6, 1.0), mouth_width), "")
		trunks += 1
		if major:
			add_tributaries(river_name, course, downstream, flow)

func trace_upstream(start: int, downstream: PackedInt32Array, flow: PackedFloat32Array) -> PackedInt32Array:
	var course: PackedInt32Array = PackedInt32Array([start])
	var current: int = start
	while true:
		var best: int = -1
		var best_flow: float = SOURCE_FLOW
		for offset: Vector2i in NEIGHBORS_8:
			var n: int = neighbor(current, offset)
			if n >= 0 and downstream[n] == current and flow[n] >= best_flow:
				best = n
				best_flow = flow[n]
		if best < 0:
			break
		course.append(best)
		current = best
	return course

func add_tributaries(trunk_name: String, course: PackedInt32Array, downstream: PackedInt32Array, flow: PackedFloat32Array) -> void:
	var added: int = 0
	var k: int = 4
	while k < course.size() - 6 and added < 2:
		var junction: int = course[k]
		var found: bool = false
		for offset: Vector2i in NEIGHBORS_8:
			var n: int = neighbor(junction, offset)
			if n < 0 or n == course[k + 1] or downstream[n] != junction:
				continue
			if flow[n] < maxf(TRIBUTARY_FLOW, flow[junction] * 0.25):
				continue
			var branch: PackedInt32Array = trace_upstream(n, downstream, flow)
			if branch.size() < 8 or mean_temperature(branch) < FROZEN_TEMPERATURE:
				continue
			var path: PackedInt32Array = reversed(branch)
			path.append(junction)
			var culture: int = landmass_cultures[landmass[junction]]
			add_river(names.base_name(culture), false, path, Vector2(rng.randf_range(0.6, 0.8), rng.randf_range(1.2, 2.0)), trunk_name)
			added += 1
			found = true
			break
		k += 7 if found else 1

func add_river(river_name: String, major: bool, path: PackedInt32Array, width: Vector2, joins: String) -> void:
	var points: Array[Vector2] = []
	for cell: int in path:
		var point: Vector2 = cell_to_degrees(cell)
		if not points.is_empty():
			var previous: Vector2 = points[points.size() - 1]
			point.x = previous.x + wrapped_dx(previous.x, point.x)
		points.append(point)
		if land[cell] == 1:
			river_cells[cell] = 1
	var river: Dictionary = {"name": river_name, "major": major, "width": width, "path": points}
	if joins != "":
		river["joins"] = joins
	definition["rivers"].append(river)

func mean_temperature(cells: PackedInt32Array) -> float:
	var sum: float = 0.0
	for cell: int in cells:
		sum += temperature[cell]
	return sum / maxf(cells.size(), 1.0)

static func reversed(cells: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = cells.duplicate()
	result.reverse()
	return result

# --- Regions ---------------------------------------------------------------

func plan_regions() -> void:
	var size: int = pw * ph
	var candidates: PackedInt32Array = PackedInt32Array()
	var land_count: int = 0
	for i in range(size):
		if land[i] == 1:
			land_count += 1
			if coast_distance[i] >= 2:
				candidates.append(i)
	shuffle(candidates)
	var target: int = clampi(int(land_count / CELLS_PER_REGION), 40, MAX_REGIONS)
	var spacing: float = sqrt(float(land_count) / target) * 0.92

	# Dart throwing with a bucket grid: seeds at least `spacing` cells apart.
	var bucket: int = int(ceil(spacing))
	var bucket_columns: int = int(ceil(float(pw) / bucket))
	var buckets: Dictionary = {}
	var taken: Dictionary = {}
	for cell: int in candidates:
		if region_seeds.size() >= MAX_REGIONS:
			break
		if seed_is_clear(cell, spacing, bucket, bucket_columns, buckets):
			add_seed(cell, bucket, bucket_columns, buckets, taken)

	# Islands too small for a dart still get a region of their own if they have room.
	var best_cell: PackedInt32Array = PackedInt32Array()
	best_cell.resize(landmass_sizes.size())
	best_cell.fill(-1)
	var seeded: PackedByteArray = PackedByteArray()
	seeded.resize(landmass_sizes.size())
	for cell: int in region_seeds:
		seeded[landmass[cell]] = 1
	for i in range(size):
		var id: int = landmass[i]
		if id >= 0 and (best_cell[id] < 0 or coast_distance[i] > coast_distance[best_cell[id]]):
			best_cell[id] = i
	for id in range(landmass_sizes.size()):
		if seeded[id] == 0 and landmass_sizes[id] >= MIN_ISLAND_REGION_CELLS and region_seeds.size() < MAX_REGIONS:
			add_seed(best_cell[id], bucket, bucket_columns, buckets, taken)

	nudge_seeds_to_good_ground(taken)
	builder.political_river = river_cells
	region_owner = builder.grow_regions(region_seeds)
	builder.assign_unreached_land(region_owner)
	definition["region_grid"] = region_owner
	summarize_planned_regions()

func seed_is_clear(cell: int, spacing: float, bucket: int, bucket_columns: int, buckets: Dictionary) -> bool:
	var x: int = cell % pw
	var y: int = cell / pw
	var bx: int = x / bucket
	var by: int = y / bucket
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var key: int = (by + dy) * bucket_columns + posmod(bx + dx, bucket_columns)
			if not buckets.has(key):
				continue
			for other: int in buckets[key]:
				var ox: int = other % pw
				var wrapped: int = absi(posmod(ox - x + pw / 2, pw) - pw / 2)
				if Vector2(wrapped, other / pw - y).length() < spacing:
					return false
	return true

func add_seed(cell: int, bucket: int, bucket_columns: int, buckets: Dictionary, taken: Dictionary) -> void:
	var key: int = (cell / pw / bucket) * bucket_columns + (cell % pw) / bucket
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(cell)
	region_seeds.append(cell)
	taken[cell] = true

# A region's seed is where its main town will stand, so move it a little toward a river,
# a coast, or easy ground.
func nudge_seeds_to_good_ground(taken: Dictionary) -> void:
	for index in range(region_seeds.size()):
		var origin: int = region_seeds[index]
		var best: int = origin
		var best_score: float = ground_score(origin)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var cell: int = neighbor(origin, Vector2i(dx, dy))
				if cell < 0 or land[cell] == 0 or taken.has(cell):
					continue
				var score: float = ground_score(cell) + rng.randf() * 0.2
				if score > best_score:
					best = cell
					best_score = score
		if best != origin:
			taken.erase(origin)
			taken[best] = true
			region_seeds[index] = best

func ground_score(cell: int) -> float:
	return 1.5 * river_cells[cell] + (0.8 if is_coastal(cell) else 0.0) - 4.0 * builder.political_relief[cell]

func summarize_planned_regions() -> void:
	var count: int = region_seeds.size()
	var cells: PackedInt32Array = PackedInt32Array()
	cells.resize(count)
	var warmth: PackedFloat32Array = WorldFieldBuilder.make_field(count, 1)
	var wetness: PackedFloat32Array = WorldFieldBuilder.make_field(count, 1)
	var roughness: PackedFloat32Array = WorldFieldBuilder.make_field(count, 1)
	var river: PackedByteArray = PackedByteArray()
	river.resize(count)
	var coast: PackedByteArray = river.duplicate()
	for _region in range(count):
		region_neighbors.append({})
	var relief: PackedFloat32Array = builder.political_relief
	for i in range(pw * ph):
		var region_id: int = region_owner[i]
		if region_id < 0 or land[i] == 0:
			continue
		cells[region_id] += 1
		warmth[region_id] += temperature[i]
		wetness[region_id] += moisture[i]
		roughness[region_id] += relief[i]
		river[region_id] |= river_cells[i]
		var x: int = i % pw
		var y: int = i / pw
		for n: int in [y * pw + (x + 1) % pw, (y + 1) * pw + x if y < ph - 1 else -1]:
			if n < 0:
				continue
			coast[region_id] |= is_ocean[n]
			var other: int = region_owner[n]
			if other >= 0 and other != region_id and land[n] == 1:
				region_neighbors[region_id][other] = int(region_neighbors[region_id].get(other, 0)) + 1
				region_neighbors[other][region_id] = int(region_neighbors[other].get(region_id, 0)) + 1
	for region_id in range(count):
		var n: float = maxf(float(cells[region_id]), 1.0)
		var stats: Dictionary = {"cells": cells[region_id], "temperature": warmth[region_id] / n, "moisture": wetness[region_id] / n,
			"relief": roughness[region_id] / n, "river": river[region_id] == 1, "coast": coast[region_id] == 1}
		stats["score"] = habitability(stats)
		region_stats.append(stats)

# How well a region could carry an old, settled kingdom: temperate, watered, not mountainous.
func habitability(stats: Dictionary) -> float:
	var t: float = stats["temperature"]
	var m: float = stats["moisture"]
	var warmth: float = smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(0.85, 0.98, t))
	var water: float = smoothstep(0.15, 0.45, m)
	var score: float = warmth * water * (1.0 - 0.6 * minf(float(stats["relief"]), 1.0))
	return score + (0.15 if stats["river"] else 0.0) + (0.1 if stats["coast"] else 0.0)

# --- Kingdoms --------------------------------------------------------------

func plan_kingdoms() -> void:
	var count: int = region_seeds.size()
	region_kingdom = PackedInt32Array()
	region_kingdom.resize(count)
	region_kingdom.fill(-1)
	for _region in range(count):
		region_claims.append([])

	# Capitals: the most habitable regions, kept apart so each kingdom has room to grow.
	var landmass_regions: Dictionary = {}
	for region_id in range(count):
		var id: int = landmass[region_seeds[region_id]]
		landmass_regions[id] = int(landmass_regions.get(id, 0)) + 1
	var by_score: Array[int] = []
	for region_id in range(count):
		by_score.append(region_id)
	by_score.sort_custom(func(a: int, b: int) -> bool:
		var sa: float = region_stats[a]["score"]
		var sb: float = region_stats[b]["score"]
		return sa > sb or (sa == sb and a < b))
	var wanted: int = rng.randi_range(5, 8)
	var capital_hops: Array[PackedInt32Array] = []
	for region_id: int in by_score:
		if kingdom_capital_region.size() >= wanted or float(region_stats[region_id]["score"]) < 0.35:
			break
		if int(landmass_regions[landmass[region_seeds[region_id]]]) < 5:
			continue
		var clear: bool = true
		for hops: PackedInt32Array in capital_hops:
			if hops[region_id] >= 0 and hops[region_id] < 4:
				clear = false
		if not clear:
			continue
		kingdom_capital_region.append(region_id)
		capital_hops.append(region_hops(region_id))

	# Kingdoms grow region by region toward their size; what none takes is frontier.
	var sizes: Array[int] = []
	for k in range(kingdom_capital_region.size()):
		sizes.append(rng.randi_range(9, 14) if k == 0 else rng.randi_range(3, 8))
		region_kingdom[kingdom_capital_region[k]] = k
	var grew: bool = true
	while grew:
		grew = false
		for k in range(kingdom_capital_region.size()):
			if kingdom_region_count(k) >= sizes[k]:
				continue
			var best: int = -1
			var best_score: float = 0.12
			for region_id in range(count):
				if region_kingdom[region_id] != k:
					continue
				for other: int in region_neighbors[region_id]:
					if region_kingdom[other] != -1:
						continue
					var score: float = float(region_stats[other]["score"]) + 0.02 * int(region_neighbors[region_id][other])
					if score > best_score or (score == best_score and other < best):
						best = other
						best_score = score
			if best >= 0:
				region_kingdom[best] = k
				grew = true

	plan_contested_borders()
	# A kingdom left with a single region is only a town; it becomes frontier.
	var kept: Array[int] = []
	for k in range(kingdom_capital_region.size()):
		if kingdom_region_count(k) >= 2:
			kept.append(k)
	var remap: Dictionary = {}
	for k in range(kingdom_capital_region.size()):
		remap[k] = kept.find(k)
	for region_id in range(count):
		if region_kingdom[region_id] >= 0:
			region_kingdom[region_id] = remap[region_kingdom[region_id]]
		var claims: Array = []
		for claimant: int in region_claims[region_id]:
			if int(remap[claimant]) >= 0:
				claims.append(remap[claimant])
		region_claims[region_id] = claims
	var capitals: Array[int] = []
	for k: int in kept:
		capitals.append(kingdom_capital_region[k])
	kingdom_capital_region = capitals

	var cultures: Array[int] = []
	for culture in range(names.culture_count()):
		cultures.append(culture)
	shuffle_ints(cultures)
	var colors: Array[Color] = KINGDOM_COLORS.duplicate()
	for k in range(kingdom_capital_region.size()):
		kingdom_culture.append(cultures[k % cultures.size()])
		var kingdom_name: String = names.realm_name(kingdom_culture[k])
		var color: Color = colors.pop_at(rng.randi_range(0, colors.size() - 1)) if not colors.is_empty() else Color.from_hsv(rng.randf(), 0.7, 0.7)
		definition["kingdoms"].append({"key": kingdom_name.to_lower(), "name": kingdom_name, "color": color, "label_at": kingdom_label_position(k)})

func plan_contested_borders() -> void:
	var count: int = region_seeds.size()
	var kingdoms: int = kingdom_capital_region.size()
	for a in range(kingdoms):
		for b in range(a + 1, kingdoms):
			if rng.randf() > 0.7:
				continue
			var best: int = -1
			var best_score: float = INF
			for region_id in range(count):
				var holder: int = region_kingdom[region_id]
				if (holder != a and holder != b) or kingdom_capital_region.has(region_id) or kingdom_region_count(holder) <= 2:
					continue
				var rival: int = b if holder == a else a
				var borders_rival: bool = false
				for other: int in region_neighbors[region_id]:
					borders_rival = borders_rival or region_kingdom[other] == rival
				if borders_rival and float(region_stats[region_id]["score"]) < best_score:
					best = region_id
					best_score = region_stats[region_id]["score"]
			if best >= 0:
				region_claims[best] = [region_kingdom[best], b if region_kingdom[best] == a else a]
				region_kingdom[best] = -1

	# Kingdoms also claim some of the frontier on their borders.
	var contested: int = 0
	for region_id in range(count):
		if not region_claims[region_id].is_empty():
			contested += 1
	for region_id in range(count):
		if region_kingdom[region_id] != -1 or not region_claims[region_id].is_empty():
			continue
		var claimant: int = -1
		var longest: int = 0
		for other: int in region_neighbors[region_id]:
			var holder: int = region_kingdom[other]
			if holder >= 0 and int(region_neighbors[region_id][other]) > longest:
				claimant = holder
				longest = region_neighbors[region_id][other]
		if claimant >= 0 and (rng.randf() < 0.2 or contested < 2):
			region_claims[region_id] = [claimant]
			contested += 1

func kingdom_region_count(kingdom: int) -> int:
	return region_kingdom.count(kingdom)

# Region steps from one region to every other on the same land (-1: unreachable).
func region_hops(start: int) -> PackedInt32Array:
	var hops: PackedInt32Array = PackedInt32Array()
	hops.resize(region_seeds.size())
	hops.fill(-1)
	hops[start] = 0
	var queue: Array[int] = [start]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for other: int in region_neighbors[current]:
			if hops[other] < 0:
				hops[other] = hops[current] + 1
				queue.append(other)
	return hops

func kingdom_label_position(kingdom: int) -> Vector2:
	var anchor: Vector2 = cell_to_degrees(region_seeds[kingdom_capital_region[kingdom]])
	var sum: Vector2 = Vector2.ZERO
	var n: int = 0
	for region_id in range(region_seeds.size()):
		if region_kingdom[region_id] == kingdom:
			var at: Vector2 = cell_to_degrees(region_seeds[region_id])
			sum += Vector2(anchor.x + wrapped_dx(anchor.x, at.x), at.y)
			n += 1
	return wrap_degrees(sum / maxf(n, 1.0))

# --- Names for regions -----------------------------------------------------

func plan_region_names() -> void:
	region_culture = PackedInt32Array()
	for region_id in range(region_seeds.size()):
		var kingdom: int = region_kingdom[region_id]
		if kingdom < 0 and not region_claims[region_id].is_empty():
			kingdom = region_claims[region_id][0]
		region_culture.append(kingdom_culture[kingdom] if kingdom >= 0 else nearest_culture(region_id))
	for region_id in range(region_seeds.size()):
		var region: Dictionary = {"name": names.region_name(region_culture[region_id], region_feature(region_id)),
			"at": cell_to_degrees(region_seeds[region_id]), "owner": kingdom_key(region_kingdom[region_id])}
		if not region_claims[region_id].is_empty():
			var claims: Array[String] = []
			for claimant: int in region_claims[region_id]:
				claims.append(kingdom_key(claimant))
			region["claims"] = claims
		definition["regions"].append(region)

# Frontier takes the culture of the nearest kingdom on the same land, or its continent's.
func nearest_culture(region_id: int) -> int:
	var seed_cell: int = region_seeds[region_id]
	var at: Vector2 = cell_to_degrees(seed_cell)
	var best: int = landmass_cultures[landmass[seed_cell]]
	var best_distance: float = 40.0
	for k in range(kingdom_capital_region.size()):
		var capital_cell: int = region_seeds[kingdom_capital_region[k]]
		var distance: float = degree_distance(at, cell_to_degrees(capital_cell))
		if landmass[capital_cell] == landmass[seed_cell] and distance < best_distance:
			best = kingdom_culture[k]
			best_distance = distance
	return best

func region_feature(region_id: int) -> String:
	var stats: Dictionary = region_stats[region_id]
	var t: float = stats["temperature"]
	var m: float = stats["moisture"]
	var relief: float = stats["relief"]
	if t < 0.22:
		return "cold"
	if relief > 0.45:
		return "mountains"
	if relief > 0.2:
		return "hills"
	if m < 0.25:
		return "desert" if t > 0.5 else "steppe"
	if m < 0.4:
		return "steppe"
	if bool(stats["river"]) and rng.randf() < 0.5:
		return "river"
	if bool(stats["coast"]) and rng.randf() < 0.5:
		return "coast"
	if m > 0.6:
		return "forest"
	return "plain"

func kingdom_key(kingdom: int) -> String:
	return definition["kingdoms"][kingdom]["key"] if kingdom >= 0 else ""

# --- Settlements -----------------------------------------------------------

func plan_settlements() -> void:
	var count: int = region_seeds.size()
	var kingdom_sizes: Array[int] = []
	for k in range(kingdom_capital_region.size()):
		kingdom_sizes.append(kingdom_region_count(k))

	for region_id in range(count):
		var kingdom: int = region_kingdom[region_id]
		var seed_cell: int = region_seeds[region_id]
		var culture: int = region_culture[region_id]
		var score: float = region_stats[region_id]["score"]
		if kingdom >= 0 and kingdom_capital_region[kingdom] == region_id:
			var size: int = kingdom_sizes[kingdom]
			# Capital status is separate from size: small kingdoms have town capitals.
			var tier: int = WorldMapData.TIER_GREAT_CITY if size >= 9 else (WorldMapData.TIER_CITY if size >= 5 else WorldMapData.TIER_TOWN)
			var settlement: Dictionary = add_settlement(seed_cell, culture, tier)
			settlement["capital_of"] = kingdom_key(kingdom)
		elif kingdom >= 0:
			if is_frozen(seed_cell):
				continue
			add_settlement(seed_cell, culture, WorldMapData.TIER_CITY if score > 0.55 and rng.randf() < 0.35 else WorldMapData.TIER_TOWN)
		else:
			if is_frozen(seed_cell) or rng.randf() > (0.5 if score > 0.15 else 0.2):
				continue
			add_settlement(seed_cell, culture, WorldMapData.TIER_TOWN if rng.randf() < 0.12 else WorldMapData.TIER_VILLAGE)

	# Villages fill in the settled land, by preference on rivers and coasts.
	var region_cells: Array[PackedInt32Array] = []
	for _region in range(count):
		region_cells.append(PackedInt32Array())
	for i in range(pw * ph):
		if land[i] == 1 and region_owner[i] >= 0 and not is_frozen(i):
			region_cells[region_owner[i]].append(i)
	for region_id in range(count):
		if region_kingdom[region_id] < 0 or region_cells[region_id].is_empty():
			continue
		var villages: int = [0, 1, 1, 2][rng.randi_range(0, 3)]
		for _village in range(villages):
			var best: int = -1
			var best_score: float = -INF
			for _try in range(24):
				var cell: int = region_cells[region_id][rng.randi_range(0, region_cells[region_id].size() - 1)]
				if not far_from_settlements(cell, 4.0):
					continue
				var village_score: float = 1.2 * river_cells[cell] + (0.7 if is_coastal(cell) else 0.0) - 3.0 * builder.political_relief[cell] + rng.randf() * 0.5
				if village_score > best_score:
					best = cell
					best_score = village_score
			if best >= 0:
				add_settlement(best, region_culture[region_id], WorldMapData.TIER_VILLAGE)

	# Some kingdoms' largest city is a trading port rather than the capital.
	for k in range(kingdom_capital_region.size()):
		if kingdom_sizes[k] < 7 or rng.randf() > 0.6:
			continue
		var capital_population: int = 0
		var port: Dictionary = {}
		for settlement: Dictionary in definition["settlements"]:
			var cell: int = degrees_to_cell(settlement["at"])
			if region_kingdom[region_owner[cell]] != k:
				continue
			if settlement.has("capital_of"):
				capital_population = settlement["population"]
			elif bool(settlement["port"]) and int(settlement["tier"]) >= WorldMapData.TIER_TOWN and (port.is_empty() or int(settlement["population"]) > int(port["population"])):
				port = settlement
		if not port.is_empty():
			port["tier"] = WorldMapData.TIER_GREAT_CITY
			port["population"] = int(capital_population * rng.randf_range(1.15, 1.5))

func add_settlement(cell: int, culture: int, tier: int) -> Dictionary:
	var population: int
	match tier:
		WorldMapData.TIER_GREAT_CITY:
			population = rng.randi_range(42000, 95000)
		WorldMapData.TIER_CITY:
			population = rng.randi_range(13000, 30000)
		WorldMapData.TIER_TOWN:
			population = rng.randi_range(2600, 9000)
		_:
			population = rng.randi_range(250, 1600)
	var settlement: Dictionary = {"name": names.place_name(culture), "at": cell_to_degrees(cell), "tier": tier,
		"population": population, "port": is_coastal(cell)}
	definition["settlements"].append(settlement)
	settlement_cells.append(cell)
	return settlement

func far_from_settlements(cell: int, cells_apart: float) -> bool:
	var at: Vector2 = cell_to_degrees(cell)
	for other: int in settlement_cells:
		if degree_distance(at, cell_to_degrees(other)) < cells_apart * cell_degrees:
			return false
	return true

# --- Roads -----------------------------------------------------------------

func plan_roads() -> void:
	var settlements: Array = definition["settlements"]
	var count: int = settlements.size()
	var kingdom_of: PackedInt32Array = PackedInt32Array()
	for i in range(count):
		kingdom_of.append(region_kingdom[region_owner[settlement_cells[i]]])
	var linked: Dictionary = {}

	# Major routes join each kingdom's cities and capital (a spanning tree per stretch of land).
	for k in range(kingdom_capital_region.size()):
		var hubs: Array[int] = []
		for i in range(count):
			if kingdom_of[i] == k and (int(settlements[i]["tier"]) >= WorldMapData.TIER_CITY or settlements[i].has("capital_of")):
				hubs.append(i)
		for edge: Vector2i in spanning_tree(hubs, 32.0):
			add_road(edge.x, edge.y, WorldMapData.ROAD_MAJOR, linked)

	# Regional roads tie towns to the nearest town or city; local roads tie villages in.
	for i in range(count):
		var tier: int = settlements[i]["tier"]
		if tier >= WorldMapData.TIER_CITY or settlements[i].has("capital_of"):
			continue
		var target: int = nearest_settlement(i, WorldMapData.TIER_TOWN, 14.0 if tier == WorldMapData.TIER_TOWN else 9.0)
		if target < 0:
			target = nearest_settlement(i, WorldMapData.TIER_VILLAGE, 7.0)
		if target >= 0:
			add_road(i, target, WorldMapData.ROAD_REGIONAL if tier == WorldMapData.TIER_TOWN and int(settlements[target]["tier"]) >= WorldMapData.TIER_TOWN else WorldMapData.ROAD_LOCAL, linked)

	# Neighbouring kingdoms trade over one road between their closest towns.
	var towns: Array[Array] = []
	for _kingdom in range(kingdom_capital_region.size()):
		towns.append([])
	for i in range(count):
		if kingdom_of[i] >= 0 and int(settlements[i]["tier"]) >= WorldMapData.TIER_TOWN:
			towns[kingdom_of[i]].append(i)
	for a in range(kingdom_capital_region.size()):
		for b in range(a + 1, kingdom_capital_region.size()):
			var best: Vector2i = Vector2i(-1, -1)
			var best_distance: float = 16.0
			for i: int in towns[a]:
				for j: int in towns[b]:
					if not same_road_land(i, j):
						continue
					var distance: float = road_distance(i, j)
					if distance < best_distance:
						best = Vector2i(i, j)
						best_distance = distance
			if best.x >= 0:
				add_road(best.x, best.y, WorldMapData.ROAD_REGIONAL, linked)

func spanning_tree(nodes: Array[int], max_length: float) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	var in_tree: Dictionary = {}
	for start: int in nodes:
		if in_tree.has(start):
			continue
		in_tree[start] = true
		var grown: bool = true
		while grown:
			grown = false
			var best: Vector2i = Vector2i(-1, -1)
			var best_distance: float = max_length
			for a: int in nodes:
				if not in_tree.has(a):
					continue
				for b: int in nodes:
					if in_tree.has(b) or not same_road_land(a, b):
						continue
					var distance: float = road_distance(a, b)
					if distance < best_distance:
						best = Vector2i(a, b)
						best_distance = distance
			if best.x >= 0:
				in_tree[best.y] = true
				edges.append(best)
				grown = true
	return edges

func nearest_settlement(from: int, min_tier: int, max_distance: float) -> int:
	var settlements: Array = definition["settlements"]
	var best: int = -1
	var best_distance: float = max_distance
	for i in range(settlements.size()):
		if i == from or int(settlements[i]["tier"]) < min_tier or not same_road_land(from, i):
			continue
		var distance: float = road_distance(from, i)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

func same_road_land(a: int, b: int) -> bool:
	return road_component[settlement_cells[a]] == road_component[settlement_cells[b]] and road_component[settlement_cells[a]] >= 0

# Roads are routed without wrapping, so distance ignores the date line too.
func road_distance(a: int, b: int) -> float:
	return (definition["settlements"][a]["at"] as Vector2).distance_to(definition["settlements"][b]["at"])

func add_road(a: int, b: int, road_class: int, linked: Dictionary) -> void:
	var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
	if linked.has(key):
		return
	linked[key] = true
	var settlements: Array = definition["settlements"]
	definition["roads"].append([settlements[a]["name"], settlements[b]["name"], road_class])

# --- Labels ----------------------------------------------------------------

func plan_labels() -> void:
	var labels: Array = definition["geo_labels"]
	# Continents: at the point farthest from any coast.
	var best_cell: PackedInt32Array = PackedInt32Array()
	best_cell.resize(landmass_sizes.size())
	best_cell.fill(-1)
	for i in range(pw * ph):
		var id: int = landmass[i]
		if id >= 0 and (best_cell[id] < 0 or coast_distance[i] > coast_distance[best_cell[id]]):
			best_cell[id] = i
	for id in range(landmass_sizes.size()):
		if landmass_sizes[id] >= 1500:
			labels.append({"text": names.base_name(landmass_cultures[id]), "kind": WorldMapData.LABEL_CONTINENT, "at": cell_to_degrees(best_cell[id])})

	var water_distance: PackedInt32Array = grid_distance(land, 1)
	plan_ocean_labels(labels, water_distance)
	plan_sea_labels(labels, water_distance)

	for mountain_range: Dictionary in ranges:
		if float(mountain_range["height"]) < 0.5:
			continue
		var path: Array[Vector2] = mountain_range["path"]
		var middle: int = path.size() / 2
		var direction: Vector2 = path[mini(middle + 1, path.size() - 1)] - path[maxi(middle - 1, 0)]
		var angle: float = rad_to_deg(atan2(direction.y, direction.x))
		if angle > 90.0:
			angle -= 180.0
		elif angle < -90.0:
			angle += 180.0
		labels.append({"text": mountain_range["name"], "kind": WorldMapData.LABEL_LANDFORM, "at": wrap_degrees(path[middle]), "angle": angle})

	for zone: Dictionary in desert_zones:
		var cell: int = degrees_to_cell(zone["center"])
		if land[cell] == 1 and moisture[cell] < 0.25:
			var word: String = ["Erg", "Desert", "Waste"][rng.randi_range(0, 2)]
			labels.append({"text": names.unique("The " + names.base_name(int(zone["culture"])) + " " + word), "kind": WorldMapData.LABEL_LANDFORM, "at": zone["center"]})

func plan_ocean_labels(labels: Array, water_distance: PackedInt32Array) -> void:
	var candidates: Array[int] = []
	for y in range(0, ph, 2):
		for x in range(0, pw, 2):
			var i: int = y * pw + x
			if is_ocean[i] == 1 and water_distance[i] >= 14 and absf(latitude_of_cell(i)) < 55.0:
				candidates.append(i)
	candidates.sort_custom(func(a: int, b: int) -> bool: return water_distance[a] > water_distance[b] or (water_distance[a] == water_distance[b] and a < b))
	var placed: Array[Vector2] = []
	for cell: int in candidates:
		if placed.size() >= 4:
			break
		var at: Vector2 = cell_to_degrees(cell)
		if not far_from_points(at, placed, 70.0):
			continue
		placed.append(at)
		labels.append({"text": names.unique("The " + names.base_name(rng.randi_range(0, names.culture_count() - 1)) + " Ocean"), "kind": WorldMapData.LABEL_OCEAN, "at": at})

# Seas and gulfs: water mostly closed in by land.
func plan_sea_labels(labels: Array, water_distance: PackedInt32Array) -> void:
	var candidates: Array[int] = []
	for y in range(0, ph, 3):
		for x in range(0, pw, 3):
			var cell: int = y * pw + x
			if is_ocean[cell] == 1 and water_distance[cell] >= 4 and water_distance[cell] <= 10 and enclosure(cell) >= 5:
				candidates.append(cell)
	shuffle_ints(candidates)
	var placed: Array[Vector2] = []
	for cell: int in candidates:
		if placed.size() >= 4:
			break
		var at: Vector2 = cell_to_degrees(cell)
		if not far_from_points(at, placed, 30.0):
			continue
		placed.append(at)
		var text: String = ""
		var port: int = nearest_settlement_to(at, 12.0)
		if port >= 0 and rng.randf() < 0.5:
			text = names.unique("Gulf of " + String(definition["settlements"][port]["name"]))
		else:
			text = names.unique("The " + names.base_name(rng.randi_range(0, names.culture_count() - 1)) + " Sea")
		labels.append({"text": text, "kind": WorldMapData.LABEL_SEA, "at": at})

# How many of eight rays from a water cell meet land within about 20 degrees.
func enclosure(cell: int) -> int:
	var hits: int = 0
	var x0: int = cell % pw
	var y0: int = cell / pw
	for offset: Vector2i in NEIGHBORS_8:
		for step in range(1, 29):
			var y: int = y0 + offset.y * step
			if y < 0 or y >= ph:
				break
			if land[y * pw + posmod(x0 + offset.x * step, pw)] == 1:
				hits += 1
				break
	return hits

func nearest_settlement_to(at: Vector2, max_distance: float) -> int:
	var best: int = -1
	var best_distance: float = max_distance
	for i in range(settlement_cells.size()):
		var distance: float = degree_distance(at, definition["settlements"][i]["at"])
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

static func far_from_points(at: Vector2, points: Array[Vector2], distance: float) -> bool:
	for point: Vector2 in points:
		if degree_distance(at, point) < distance:
			return false
	return true

# --- Grid helpers ----------------------------------------------------------

# The grid walks below are the generator's hot loops (131k cells each), so neighbours are
# computed inline rather than through neighbor().

# Steps (8-neighbour, wrapping) from the nearest cell with sources[i] == source_value.
func grid_distance(sources: PackedByteArray, source_value: int) -> PackedInt32Array:
	var size: int = pw * ph
	var distance: PackedInt32Array = PackedInt32Array()
	distance.resize(size)
	distance.fill(-1)
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(size)
	var tail: int = 0
	for i in range(size):
		if sources[i] == source_value:
			distance[i] = 0
			queue[tail] = i
			tail += 1
	var head: int = 0
	while head < tail:
		var current: int = queue[head]
		head += 1
		var x: int = current % pw
		var y: int = current / pw
		var next_distance: int = distance[current] + 1
		var left: int = x - 1 if x > 0 else pw - 1
		var right: int = x + 1 if x < pw - 1 else 0
		for ny in range(maxi(y - 1, 0), mini(y + 1, ph - 1) + 1):
			var row: int = ny * pw
			for n: int in [row + left, row + x, row + right]:
				if distance[n] < 0:
					distance[n] = next_distance
					queue[tail] = n
					tail += 1
	return distance

# Connected cells with mask[i] == 1: [ids per cell (-1 outside the mask), size per id].
func label_components(mask: PackedByteArray, diagonal: bool, wrap: bool) -> Array:
	var size: int = pw * ph
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(size)
	ids.fill(-1)
	var sizes: PackedInt32Array = PackedInt32Array()
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(size)
	var neighbors: Array[int] = []
	for start in range(size):
		if mask[start] == 0 or ids[start] >= 0:
			continue
		var id: int = sizes.size()
		ids[start] = id
		queue[0] = start
		var tail: int = 1
		var head: int = 0
		while head < tail:
			var current: int = queue[head]
			head += 1
			var x: int = current % pw
			var y: int = current / pw
			var left: int = x - 1 if x > 0 else (pw - 1 if wrap else -1)
			var right: int = x + 1 if x < pw - 1 else (0 if wrap else -1)
			neighbors.clear()
			for ny in range(maxi(y - 1, 0), mini(y + 1, ph - 1) + 1):
				var row: int = ny * pw
				if ny == y or diagonal:
					if left >= 0:
						neighbors.append(row + left)
					if right >= 0:
						neighbors.append(row + right)
				if ny != y:
					neighbors.append(row + x)
			for n: int in neighbors:
				if mask[n] == 1 and ids[n] < 0:
					ids[n] = id
					queue[tail] = n
					tail += 1
		sizes.append(tail)
	return [ids, sizes]

func shuffle(cells: PackedInt32Array) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = cells[i]
		cells[i] = cells[j]
		cells[j] = swap

func shuffle_ints(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = values[i]
		values[i] = values[j]
		values[j] = swap
