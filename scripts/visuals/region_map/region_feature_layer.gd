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
const FLOWER_COLORS: Array[Color] = [Color(0.98, 0.96, 0.88), Color(0.98, 0.84, 0.30), Color(0.76, 0.58, 0.88)]

var strips: Array[Strip] = []
# Per strip: items [kind, x, y, size, variant], sorted by y so nearer things draw on top.
var strip_items: Array = []
# Per strip: ground details [kind, x, y, size, variant], drawn first and only up close.
var strip_details: Array = []
var tree_style: Dictionary = {}
var rock_light: Color = RegionMapStyle.COLOR_ROCK_LIGHT
var rock_dark: Color = RegionMapStyle.COLOR_ROCK_DARK

func rebuild() -> void:
	var size: Vector2i = view.map_size
	var strip_count: int = ceili(float(size.y) / RegionMapStyle.STRIP_ROWS)
	while strips.size() < strip_count:
		var strip: Strip = Strip.new()
		strip.index = strips.size()
		strip.painter = paint_strip
		add_child(strip)
		strips.append(strip)
	strip_items.clear()
	strip_details.clear()
	for _i in range(strips.size()):
		strip_items.append([])
		strip_details.append([])

	tree_style = RegionMapStyle.tree_style(view.geography)
	var arid: bool = RegionMapStyle.climate_family(view.geography) == RegionGeography.CLIMATE_ARID
	rock_light = Color(0.74, 0.58, 0.42) if arid else Color(0.68, 0.64, 0.58)
	rock_dark = Color(0.46, 0.33, 0.25) if arid else Color(0.40, 0.37, 0.35)

	for y in range(size.y):
		for x in range(size.x):
			collect_tile_features(x, y)
	for items: Array in strip_items:
		items.sort_custom(func(a: PackedFloat32Array, b: PackedFloat32Array) -> bool: return a[2] < b[2])
	for strip: Strip in strips:
		strip.queue_redraw()

func on_lod_changed() -> void:
	for strip: Strip in strips:
		strip.queue_redraw()

static func hash01(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, salt)) & 0xFFFF) / 65535.0

func add_item(list_owner: Array, kind: int, position: Vector2, size: float, variant: float) -> void:
	var strip: int = clampi(int(position.y / (RegionMapStyle.TILE * RegionMapStyle.STRIP_ROWS)), 0, strips.size() - 1)
	(list_owner[strip] as Array).append(PackedFloat32Array([kind, position.x, position.y, size, variant]))

func collect_tile_features(x: int, y: int) -> void:
	var tile: Dictionary = view.tiles[y][x]
	var tile_type: String = tile["type"]
	var origin: Vector2 = Vector2(x, y) * RegionMapStyle.TILE
	var unit: float = RegionMapStyle.TILE

	if tile["has_forest"] == true:
		var neighbors: int = count_neighbors(x, y, func(t: Dictionary) -> bool: return t["has_forest"] == true)
		var count: int = 2 + (1 if neighbors >= 6 else 0) + (1 if hash01(x, y, 1) > 0.45 else 0)
		var radius: Vector2 = tree_style["radius"]
		for k in range(count):
			var position: Vector2 = origin + Vector2(1.5 + hash01(x, y, 10 + k) * (unit - 3.0), 1.5 + hash01(x, y, 20 + k) * (unit - 3.0))
			if view.geometry.is_cleared(position):
				continue
			var kind: int = ITEM_TREE
			if tree_style["kind"] == "scrub":
				kind = ITEM_SCRUB
			elif hash01(x, y, 30 + k) < float(tree_style["conifer_share"]):
				kind = ITEM_CONIFER
			add_item(strip_items, kind, position, lerpf(radius.x, radius.y, hash01(x, y, 40 + k)), hash01(x, y, 50 + k))

	if tile_type == "mountain" and hash01(x, y, 1) < PEAK_DENSITY:
		collect_peak(x, y)

	if tile["resource"] == "stone" or tile["resource"] == "iron":
		var kind: int = ITEM_STONE if tile["resource"] == "stone" else ITEM_IRON
		for k in range(2):
			var position: Vector2 = origin + Vector2(2.5 + hash01(x, y, 60 + k) * (unit - 5.0), 2.5 + hash01(x, y, 70 + k) * (unit - 5.0))
			add_item(strip_items, kind, position, 1.5 + hash01(x, y, 80 + k) * 1.1, hash01(x, y, 90 + k))

	var open_ground: bool = tile_type == "grass" or tile_type == "hill"
	if open_ground and tile["has_forest"] == false and tile["resource"] == "none":
		if hash01(x, y, 100) < (0.25 if tile_type == "hill" else 0.12):
			var position: Vector2 = origin + Vector2(hash01(x, y, 101), hash01(x, y, 102)) * unit
			if not view.geometry.is_cleared(position):
				add_item(strip_details, DETAIL_SHRUB, position, 0.9 + hash01(x, y, 103) * 0.5, hash01(x, y, 104))
		if tile["is_fertile"] == true:
			for k in range(3):
				var position: Vector2 = origin + Vector2(hash01(x, y, 110 + k), hash01(x, y, 120 + k)) * unit
				if not view.geometry.is_cleared(position):
					add_item(strip_details, DETAIL_FLOWER, position, 0.32, hash01(x, y, 130 + k))

# Peaks stand on a random share of mountain tiles, sized by how deep in the range the tile
# lies: big summits inside, small peaks along the edge, and lit rock showing between them.
func collect_peak(x: int, y: int) -> void:
	var depth: int = 0
	for ny in range(y - 2, y + 3):
		for nx in range(x - 2, x + 3):
			if nx < 0 or ny < 0 or nx >= view.map_size.x or ny >= view.map_size.y or view.tiles[ny][nx]["type"] == "mountain":
				depth += 1
	var interior: float = depth / 25.0
	var size: float = 0.7 + interior * interior * 1.5 + hash01(x, y, 2) * 0.45
	var position: Vector2 = (Vector2(x, y) + Vector2(hash01(x, y, 3), 0.3 + hash01(x, y, 4) * 0.7)) * RegionMapStyle.TILE
	var cold: float = tile_temperature(x, y) - size * 0.06
	var snowy: float = 1.0 if cold < SNOW_TEMPERATURE else 0.0
	add_item(strip_items, ITEM_PEAK, position, size, snowy + hash01(x, y, 5) * 0.5)

func count_neighbors(x: int, y: int, matches: Callable) -> int:
	var count: int = 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nx: int = x + ox
			var ny: int = y + oy
			if nx < 0 or ny < 0 or nx >= view.map_size.x or ny >= view.map_size.y:
				count += 1
				continue
			if matches.call(view.tiles[ny][nx]):
				count += 1
	return count

func tile_temperature(x: int, y: int) -> float:
	if view.geography == null:
		return 0.6
	return view.geography.temperature[view.geography.tile_index(x, y)]

# --- Drawing ----------------------------------------------------------------------

func paint_strip(canvas: CanvasItem, index: int) -> void:
	if index >= strip_items.size():
		return
	var batch: TriangleBatch = TriangleBatch.new()
	if lod >= 2:
		for detail: PackedFloat32Array in strip_details[index]:
			var position: Vector2 = Vector2(detail[1], detail[2])
			if int(detail[0]) == DETAIL_SHRUB:
				add_shrub(batch, position, detail[3], detail[4])
			else:
				var color: Color = FLOWER_COLORS[int(detail[4] * FLOWER_COLORS.size()) % FLOWER_COLORS.size()]
				batch.add_blob(position, Vector2(detail[3], detail[3]), color, 6)
	for item: PackedFloat32Array in strip_items[index]:
		var position: Vector2 = Vector2(item[1], item[2])
		match int(item[0]):
			ITEM_TREE:
				add_broadleaf(batch, position, item[3], item[4])
			ITEM_CONIFER:
				add_conifer(batch, position, item[3], item[4])
			ITEM_SCRUB:
				add_scrub(batch, position, item[3], item[4])
			ITEM_PEAK:
				add_peak(batch, position, item[3], item[4])
			ITEM_STONE, ITEM_IRON:
				add_boulder(batch, position, item[3], item[4], int(item[0]) == ITEM_IRON)
	batch.flush(canvas)

func tree_colors(variant: float) -> Array[Color]:
	var shift: float = (variant - 0.5) * 0.18
	var base: Color = tree_style["base"]
	var dark: Color = tree_style["dark"]
	var light: Color = tree_style["light"]
	if shift > 0.0:
		return [dark.lightened(shift), base.lightened(shift), light.lightened(shift * 0.5)]
	return [dark.darkened(-shift), base.darkened(-shift), light.darkened(-shift * 0.5)]

func add_broadleaf(batch: TriangleBatch, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(variant)
	batch.add_blob(center + Vector2(r * 0.45, r * 0.55), Vector2(r * 1.05, r * 0.82), RegionMapStyle.COLOR_SHADOW)
	batch.add_blob(center, Vector2(r, r), colors[0])
	batch.add_blob(center + Vector2(-r * 0.12, -r * 0.16), Vector2(r * 0.8, r * 0.8), colors[1])
	batch.add_blob(center + Vector2(-r * 0.34, -r * 0.38), Vector2(r * 0.4, r * 0.4), colors[2], 8)

func add_conifer(batch: TriangleBatch, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(variant)
	batch.add_blob(center + Vector2(r * 0.6, r * 0.7), Vector2(r * 0.95, r * 0.6), RegionMapStyle.COLOR_SHADOW)
	batch.add_fan(center, star(center, r, r * 0.58, 8, variant * TAU), colors[0])
	var inner: Vector2 = center + Vector2(-r * 0.1, -r * 0.14)
	batch.add_fan(inner, star(inner, r * 0.68, r * 0.4, 8, variant * TAU + 0.3), colors[1])
	batch.add_blob(center + Vector2(-r * 0.2, -r * 0.26), Vector2(r * 0.22, r * 0.22), colors[2], 6)

func add_scrub(batch: TriangleBatch, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(variant)
	batch.add_blob(center + Vector2(r * 0.4, r * 0.45), Vector2(r, r * 0.75), RegionMapStyle.COLOR_SHADOW)
	batch.add_blob(center, Vector2(r, r * 0.9), colors[0], 8)
	batch.add_blob(center + Vector2(-r * 0.2, -r * 0.22), Vector2(r * 0.6, r * 0.55), colors[1], 8)

static func star(center: Vector2, outer: float, inner: float, points: int, phase: float) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for i in range(points * 2):
		var angle: float = phase + PI * i / points
		var radius: float = outer if i % 2 == 0 else inner
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return polygon

# A peak seen from above and a little to the south: lit western face, shaded eastern face,
# a shadow cast toward the southeast, and snow on cold summits.
func add_peak(batch: TriangleBatch, base_center: Vector2, size: float, variant: float) -> void:
	var snowy: bool = variant >= 1.0
	var lean: float = (fmod(variant, 1.0) - 0.25) * 3.0
	var half_width: float = 7.4 * size
	var height: float = 8.4 * size + fmod(variant, 1.0) * 3.0
	var left: Vector2 = base_center + Vector2(-half_width, 0.0)
	var right: Vector2 = base_center + Vector2(half_width, 0.0)
	var apex: Vector2 = base_center + Vector2(lean, -height)
	var foot: Vector2 = base_center + Vector2(lean * 0.3 + half_width * 0.12, 1.2)
	batch.add_polygon(PackedVector2Array([apex + Vector2(height * 0.4, height * 0.5), right + Vector2(half_width * 0.5, 1.5), foot + Vector2(1.0, 1.6)]), RegionMapStyle.COLOR_SHADOW)
	var tint: float = (fmod(variant * 7.0, 1.0) - 0.5) * 0.16
	batch.add_polygon(PackedVector2Array([left, apex, foot]), rock_light.lightened(tint) if tint > 0.0 else rock_light.darkened(-tint))
	batch.add_polygon(PackedVector2Array([apex, right, foot]), rock_dark.lightened(tint) if tint > 0.0 else rock_dark.darkened(-tint))
	if snowy:
		var cap: float = 0.42
		var notch: Vector2 = apex.lerp(foot, cap * 1.15) + Vector2(0.0, -0.6)
		batch.add_polygon(PackedVector2Array([apex.lerp(left, cap), apex, notch, apex.lerp(left, cap * 0.7).lerp(notch, 0.5)]), RegionMapStyle.COLOR_SNOW)
		batch.add_polygon(PackedVector2Array([apex, apex.lerp(right, cap), apex.lerp(right, cap * 0.65).lerp(notch, 0.5), notch]), RegionMapStyle.COLOR_SNOW_SHADE)

func add_boulder(batch: TriangleBatch, center: Vector2, r: float, variant: float, is_iron: bool) -> void:
	var outline: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var angle: float = TAU * i / 7.0 + variant * 2.0
		outline.append(center + Vector2(cos(angle), sin(angle) * 0.8) * r * (0.8 + 0.35 * hash01(i, int(variant * 1000.0), 7)))
	var body: Color = RegionMapStyle.COLOR_IRON_DARK if is_iron else RegionMapStyle.COLOR_STONE
	var top: Color = RegionMapStyle.COLOR_IRON_RUST if is_iron else RegionMapStyle.COLOR_STONE_LIGHT
	batch.add_blob(center + Vector2(r * 0.4, r * 0.5), Vector2(r * 1.05, r * 0.7), RegionMapStyle.COLOR_SHADOW, 8)
	batch.add_fan(center, outline, body)
	batch.add_blob(center + Vector2(-r * 0.25, -r * 0.25), Vector2(r * 0.5, r * 0.4), top, 6)

func add_shrub(batch: TriangleBatch, center: Vector2, r: float, variant: float) -> void:
	var colors: Array[Color] = tree_colors(variant)
	batch.add_blob(center + Vector2(r * 0.4, r * 0.4), Vector2(r, r * 0.7), faded(RegionMapStyle.COLOR_SHADOW, 0.6), 6)
	batch.add_blob(center, Vector2(r, r * 0.85), colors[1], 7)
	batch.add_blob(center + Vector2(-r * 0.25, -r * 0.25), Vector2(r * 0.45, r * 0.4), colors[2], 6)