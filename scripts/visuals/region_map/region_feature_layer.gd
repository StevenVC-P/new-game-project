class_name RegionFeatureLayer
extends RegionMapLayer

# Natural features standing on the ground: trees on forest tiles, peaks on mountain tiles,
# boulders on stone and iron deposits, and, up close, shrubs and wildflowers on open land.
# Trees grow only on tiles the game counts as forest, so woodland on the map is always
# woodland a woodcutter can use; shrubs and flowers are too small to read as woods.
# Features keep clear of roads and settlements (see RegionMapGeometry.is_cleared).

const ITEM_TREE: int = 0
const ITEM_CONIFER: int = 1
const ITEM_SCRUB: int = 2
const ITEM_PEAK: int = 3
const ITEM_STONE: int = 4
const ITEM_IRON: int = 5
const DETAIL_SHRUB: int = 0
const DETAIL_FLOWER: int = 1

# Below this tile temperature (lowered further on the biggest peaks) a peak carries snow.
const SNOW_TEMPERATURE: float = 0.36
const PEAK_DENSITY: float = 0.3

var strips: Array[Strip] = []
# Per strip: items [kind, x, y, size, variant], sorted by y so nearer things draw on top.
var strip_items: Array = []
# Per strip: ground details [kind, x, y, size, variant], drawn first and only up close.
var strip_details: Array = []
var tree_style: Dictionary = {}
var rock_light: Color = RegionMapStyle.COLOR_ROCK_LIGHT
var rock_dark: Color = RegionMapStyle.COLOR_ROCK_DARK
# Whether the recorded strips include the close-up ground details.
var details_drawn: bool = false
# Called with each strip to repaint, when painting is spread over frames (see redraw_strips).
var strip_scheduler: Callable = Callable()
# Strip index -> true for strips whose features must be collected again before they paint.
var stale_strips: Dictionary = {}

func rebuild() -> void:
	var size: Vector2i = source_size()
	var strip_count: int = ceili(float(size.y) / RegionMapStyle.STRIP_ROWS)
	while strips.size() < strip_count:
		var strip: Strip = Strip.new()
		strip.index = strips.size()
		strip.painter = paint_strip
		add_child(strip)
		strips.append(strip)
	setup_style()
	if strip_scheduler.is_valid():
		# Each strip collects its own rows just before it paints, a few strips per frame (see
		# paint_strip); until then it keeps showing what it last drew.
		while strip_items.size() < strips.size():
			strip_items.append([])
			strip_details.append([])
		stale_strips.clear()
		for i in range(strips.size()):
			stale_strips[i] = true
			strips[i].may_paint = false
	else:
		strip_items.clear()
		strip_details.clear()
		for _i in range(strips.size()):
			strip_items.append([])
			strip_details.append([])
		for y in range(size.y):
			for x in range(size.x):
				collect_tile_features(x, y)
		for items: Array in strip_items:
			items.sort_custom(func(a: PackedFloat32Array, b: PackedFloat32Array) -> bool: return a[2] < b[2])
	redraw_strips()
	details_drawn = lod >= 2

# Collects one strip's rows; features of a tile always fall in its own row's strip.
func collect_strip(index: int) -> void:
	strip_items[index] = []
	strip_details[index] = []
	var size: Vector2i = source_size()
	for y in range(index * RegionMapStyle.STRIP_ROWS, mini((index + 1) * RegionMapStyle.STRIP_ROWS, size.y)):
		for x in range(size.x):
			collect_tile_features(x, y)
	(strip_items[index] as Array).sort_custom(func(a: PackedFloat32Array, b: PackedFloat32Array) -> bool: return a[2] < b[2])
	stale_strips.erase(index)

func is_fully_drawn() -> bool:
	return stale_strips.is_empty()

# Painting a strip builds thousands of shapes, so a scheduler (the chunk streamer) may spread
# the strips over several frames; without one they all repaint next frame.
func redraw_strips() -> void:
	for strip: Strip in strips:
		if strip_scheduler.is_valid():
			strip_scheduler.call(strip)
		else:
			strip.queue_redraw()

func setup_style() -> void:
	apply_climate_style(RegionMapStyle.region_temperature(view.geography), RegionMapStyle.climate_family(view.geography))

func apply_climate_style(temperature: float, family: String) -> void:
	tree_style = RegionMapStyle.tree_style_for(temperature, family)
	var arid: bool = family == RegionGeography.CLIMATE_ARID
	rock_light = Color(0.74, 0.58, 0.42) if arid else Color(0.68, 0.64, 0.58)
	rock_dark = Color(0.46, 0.33, 0.25) if arid else Color(0.40, 0.37, 0.35)

# --- Tile source -------------------------------------------------------------------
# The bounded region's tile dictionaries. RegionChunkFeatureLayer reads a chunk instead.

func source_size() -> Vector2i:
	return view.map_size

# Tiles outside the source count as matching when counting neighbours, as at a board edge.
func is_in_source(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < view.map_size.x and y < view.map_size.y

func tile_type_at(x: int, y: int) -> String:
	return view.tiles[y][x]["type"]

func forest_at(x: int, y: int) -> bool:
	return view.tiles[y][x]["has_forest"] == true

func fertile_at(x: int, y: int) -> bool:
	return view.tiles[y][x]["is_fertile"] == true

func resource_at(x: int, y: int) -> String:
	return view.tiles[y][x]["resource"]

# Coordinates the per-tile variation is hashed from.
func hash_tile(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)

func is_cleared_at(position: Vector2) -> bool:
	return view.geometry.is_cleared(position)

func tile_temperature(x: int, y: int) -> float:
	if view.geography == null:
		return 0.6
	return view.geography.temperature[view.geography.tile_index(x, y)]

func on_lod_changed() -> void:
	# Only the ground details (shrubs, flowers) depend on the level of detail; re-recording
	# every strip on other changes stalls the frame once many chunks are on screen.
	var draws_details: bool = lod >= 2
	if draws_details == details_drawn:
		return
	details_drawn = draws_details
	redraw_strips()

static func hash01(x: int, y: int, salt: int) -> float:
	return LandscapePainter.hash01(x, y, salt)

func add_item(list_owner: Array, kind: int, position: Vector2, size: float, variant: float) -> void:
	var strip: int = clampi(int(position.y / (RegionMapStyle.TILE * RegionMapStyle.STRIP_ROWS)), 0, strips.size() - 1)
	(list_owner[strip] as Array).append(PackedFloat32Array([kind, position.x, position.y, size, variant]))

func collect_tile_features(x: int, y: int) -> void:
	var tile_type: String = tile_type_at(x, y)
	var resource: String = resource_at(x, y)
	var has_forest: bool = forest_at(x, y)
	var origin: Vector2 = Vector2(x, y) * RegionMapStyle.TILE
	var unit: float = RegionMapStyle.TILE
	var h: Vector2i = hash_tile(x, y)

	if has_forest:
		var neighbors: int = count_forest_neighbors(x, y)
		var count: int = 2 + (1 if neighbors >= 6 else 0) + (1 if hash01(h.x, h.y, 1) > 0.45 else 0)
		var radius: Vector2 = tree_style["radius"]
		for k in range(count):
			var position: Vector2 = origin + Vector2(1.5 + hash01(h.x, h.y, 10 + k) * (unit - 3.0), 1.5 + hash01(h.x, h.y, 20 + k) * (unit - 3.0))
			if is_cleared_at(position):
				continue
			var kind: int = ITEM_TREE
			if tree_style["kind"] == "scrub":
				kind = ITEM_SCRUB
			elif hash01(h.x, h.y, 30 + k) < float(tree_style["conifer_share"]):
				kind = ITEM_CONIFER
			add_item(strip_items, kind, position, lerpf(radius.x, radius.y, hash01(h.x, h.y, 40 + k)), hash01(h.x, h.y, 50 + k))

	if tile_type == "mountain" and hash01(h.x, h.y, 1) < PEAK_DENSITY:
		collect_peak(x, y)

	if resource == "stone" or resource == "iron":
		var kind: int = ITEM_STONE if resource == "stone" else ITEM_IRON
		for k in range(2):
			var position: Vector2 = origin + Vector2(2.5 + hash01(h.x, h.y, 60 + k) * (unit - 5.0), 2.5 + hash01(h.x, h.y, 70 + k) * (unit - 5.0))
			add_item(strip_items, kind, position, 1.5 + hash01(h.x, h.y, 80 + k) * 1.1, hash01(h.x, h.y, 90 + k))

	var open_ground: bool = tile_type == "grass" or tile_type == "hill"
	if open_ground and not has_forest and resource == "none":
		if hash01(h.x, h.y, 100) < (0.25 if tile_type == "hill" else 0.12):
			var position: Vector2 = origin + Vector2(hash01(h.x, h.y, 101), hash01(h.x, h.y, 102)) * unit
			if not is_cleared_at(position):
				add_item(strip_details, DETAIL_SHRUB, position, 0.9 + hash01(h.x, h.y, 103) * 0.5, hash01(h.x, h.y, 104))
		if fertile_at(x, y):
			for k in range(3):
				var position: Vector2 = origin + Vector2(hash01(h.x, h.y, 110 + k), hash01(h.x, h.y, 120 + k)) * unit
				if not is_cleared_at(position):
					add_item(strip_details, DETAIL_FLOWER, position, 0.32, hash01(h.x, h.y, 130 + k))

# Peaks stand on a random share of mountain tiles, sized by how deep in the range the tile
# lies: big summits inside, small peaks along the edge, and lit rock showing between them.
func collect_peak(x: int, y: int) -> void:
	var depth: int = 0
	for ny in range(y - 2, y + 3):
		for nx in range(x - 2, x + 3):
			if not is_in_source(nx, ny) or tile_type_at(nx, ny) == "mountain":
				depth += 1
	var h: Vector2i = hash_tile(x, y)
	var interior: float = depth / 25.0
	var size: float = 0.7 + interior * interior * 1.5 + hash01(h.x, h.y, 2) * 0.45
	var position: Vector2 = (Vector2(x, y) + Vector2(hash01(h.x, h.y, 3), 0.3 + hash01(h.x, h.y, 4) * 0.7)) * RegionMapStyle.TILE
	var cold: float = tile_temperature(x, y) - size * 0.06
	var snowy: float = 1.0 if cold < SNOW_TEMPERATURE else 0.0
	add_item(strip_items, ITEM_PEAK, position, size, snowy + hash01(h.x, h.y, 5) * 0.5)

func count_forest_neighbors(x: int, y: int) -> int:
	var count: int = 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			if not is_in_source(x + ox, y + oy) or forest_at(x + ox, y + oy):
				count += 1
	return count

# --- Drawing ----------------------------------------------------------------------

func paint_strip(canvas: CanvasItem, index: int) -> void:
	if index >= strip_items.size():
		return
	if stale_strips.has(index):
		if not (canvas as Strip).may_paint:
			return
		collect_strip(index)
	var batch: TriangleBatch = TriangleBatch.new()
	if lod >= 2:
		for detail: PackedFloat32Array in strip_details[index]:
			var position: Vector2 = Vector2(detail[1], detail[2])
			if int(detail[0]) == DETAIL_SHRUB:
				LandscapePainter.add_shrub(batch, tree_style, position, detail[3], detail[4])
			else:
				LandscapePainter.add_flower(batch, position, detail[3], detail[4])
	for item: PackedFloat32Array in strip_items[index]:
		var position: Vector2 = Vector2(item[1], item[2])
		match int(item[0]):
			ITEM_TREE:
				LandscapePainter.add_broadleaf(batch, tree_style, position, item[3], item[4])
			ITEM_CONIFER:
				LandscapePainter.add_conifer(batch, tree_style, position, item[3], item[4])
			ITEM_SCRUB:
				LandscapePainter.add_scrub(batch, tree_style, position, item[3], item[4])
			ITEM_PEAK:
				LandscapePainter.add_peak(batch, position, item[3], item[4], rock_light, rock_dark)
			ITEM_STONE, ITEM_IRON:
				LandscapePainter.add_boulder(batch, position, item[3], item[4], int(item[0]) == ITEM_IRON)
	batch.flush(canvas)