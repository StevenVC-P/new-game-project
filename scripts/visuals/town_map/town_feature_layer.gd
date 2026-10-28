class_name TownFeatureLayer
extends TownMapLayer

# Natural features on the town map, painted like the regional map's (LandscapePainter) at four
# times the scale: trees only on tree tiles, boulders only on rough ground and deposits, and up
# close shrubs on open ground and flowers on farmland, never under a building or on a trodden
# path. What the map shows as woods is woodland the town can use.
#
# Trees and boulders are recorded once per town map and again when woods are felled or spread
# (TownMapView.refresh_development). Shrubs and flowers sit on their own canvases, shown or
# hidden by level of detail in the rendering server (toggling `visible` would re-record them),
# and recorded again only when buildings cover new ground, paths wear, or woods change.

var tree_style: Dictionary = {}
var shrub_canvas: Canvas = null
var flower_canvas: Canvas = null
var details_shown: int = -1

class Canvas:
	extends Node2D
	var painter: Callable

	func _draw() -> void:
		painter.call(self)

func setup(map_view: TownMapView) -> void:
	super.setup(map_view)
	shrub_canvas = Canvas.new()
	shrub_canvas.name = "Shrubs"
	shrub_canvas.painter = paint_shrubs
	flower_canvas = Canvas.new()
	flower_canvas.name = "Flowers"
	flower_canvas.painter = paint_flowers
	# Ground details lie under the trees.
	shrub_canvas.show_behind_parent = true
	flower_canvas.show_behind_parent = true
	add_child(flower_canvas)
	add_child(shrub_canvas)

func rebuild() -> void:
	var climate: Dictionary = view.climate
	tree_style = RegionMapStyle.tree_style_for(float(climate.get("tree_temperature", 0.55)), str(climate.get("family", RegionalTerrain.CLIMATE_TEMPERATE)))
	queue_redraw()
	rebuild_details()

# Buildings changed: only the ground details depend on where they stand.
func rebuild_details() -> void:
	shrub_canvas.queue_redraw()
	flower_canvas.queue_redraw()

func on_lod_changed() -> void:
	if shrub_canvas == null or details_shown == lod:
		return
	details_shown = lod
	RenderingServer.canvas_item_set_visible(shrub_canvas.get_canvas_item(), lod >= 1)
	RenderingServer.canvas_item_set_visible(flower_canvas.get_canvas_item(), lod >= 2)

static func hash01(x: int, y: int, salt: int) -> float:
	return LandscapePainter.hash01(x, y, salt)

func tile_at(x: int, y: int) -> Dictionary:
	return view.city.local_map[y][x]

func is_tree_tile(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= view.map_size.x or y >= view.map_size.y:
		return true
	return tile_at(x, y)["has_trees"] == true

# --- Trees and boulders -----------------------------------------------------------------------

func _draw() -> void:
	if view == null or view.city == null:
		return
	var items: Array[PackedFloat32Array] = []
	var unit: float = TownMapStyle.TILE
	var radius: Vector2 = tree_style["radius"] * TownMapStyle.TREE_SCALE
	for y in range(view.map_size.y):
		for x in range(view.map_size.x):
			var tile: Dictionary = tile_at(x, y)
			var h: Vector2i = view.hash_tile(x, y)
			var origin: Vector2 = Vector2(x, y) * unit
			if tile["has_trees"] == true:
				var neighbours: int = 0
				for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					neighbours += 1 if is_tree_tile(x + offset.x, y + offset.y) else 0
				var count: int = 1 + (1 if hash01(h.x, h.y, 1) > 0.4 else 0) + (1 if neighbours == 4 and hash01(h.x, h.y, 2) > 0.5 else 0)
				# Conifer crowns are slimmer: cold woods need more of them to read as woods.
				if float(tree_style["conifer_share"]) > 0.5:
					count += 1
				for k in range(count):
					var position: Vector2 = origin + Vector2(0.2 + hash01(h.x, h.y, 10 + k) * 0.6, 0.2 + hash01(h.x, h.y, 20 + k) * 0.6) * unit
					var kind: float = 0.0
					if tree_style["kind"] == "scrub":
						kind = 2.0
					elif hash01(h.x, h.y, 30 + k) < float(tree_style["conifer_share"]):
						kind = 1.0
					items.append(PackedFloat32Array([kind, position.x, position.y, lerpf(radius.x, radius.y, hash01(h.x, h.y, 40 + k)), hash01(h.x, h.y, 50 + k)]))
			elif tile["type"] == "rough":
				var resource: String = tile.get("resource", "none")
				var kind: float = 4.0 if resource == "iron" else 3.0
				var boulders: int = 2 if resource != "none" else 1 + (1 if hash01(h.x, h.y, 60) > 0.55 else 0)
				for k in range(boulders):
					var position: Vector2 = origin + Vector2(0.2 + hash01(h.x, h.y, 61 + k) * 0.6, 0.25 + hash01(h.x, h.y, 71 + k) * 0.55) * unit
					var size: float = (1.6 if resource != "none" else 1.3) + hash01(h.x, h.y, 81 + k) * 1.6
					items.append(PackedFloat32Array([kind, position.x, position.y, size, hash01(h.x, h.y, 91 + k)]))
	# Nearer (more southern) things draw over farther ones.
	items.sort_custom(func(a: PackedFloat32Array, b: PackedFloat32Array) -> bool: return a[2] < b[2])
	var batch: RegionMapLayer.TriangleBatch = RegionMapLayer.TriangleBatch.new()
	for item: PackedFloat32Array in items:
		var position: Vector2 = Vector2(item[1], item[2])
		match int(item[0]):
			0:
				LandscapePainter.add_broadleaf(batch, tree_style, position, item[3], item[4])
			1:
				LandscapePainter.add_conifer(batch, tree_style, position, item[3], item[4])
			2:
				LandscapePainter.add_scrub(batch, tree_style, position, item[3], item[4])
			3, 4:
				LandscapePainter.add_boulder(batch, position, item[3], item[4], int(item[0]) == 4)
	batch.flush(self)

# --- Ground details -------------------------------------------------------------------------

func is_open_ground(tile: Dictionary, at: Vector2i) -> bool:
	return tile["type"] == "ground" and not tile["has_trees"] and not tile.get("has_road", false) and not tile["occupied"] and view.city.logistics.get_tile_path_level(at) == TownLogistics.PATH_NONE

func paint_shrubs(canvas: CanvasItem) -> void:
	if view == null or view.city == null:
		return
	var batch: RegionMapLayer.TriangleBatch = RegionMapLayer.TriangleBatch.new()
	for y in range(view.map_size.y):
		for x in range(view.map_size.x):
			var tile: Dictionary = tile_at(x, y)
			if not is_open_ground(tile, Vector2i(x, y)):
				continue
			var h: Vector2i = view.hash_tile(x, y)
			if hash01(h.x, h.y, 100) > (0.05 if tile["is_fertile"] else 0.11):
				continue
			var position: Vector2 = (Vector2(x, y) + Vector2(0.15 + hash01(h.x, h.y, 101) * 0.7, 0.15 + hash01(h.x, h.y, 102) * 0.7)) * TownMapStyle.TILE
			LandscapePainter.add_shrub(batch, tree_style, position, 2.6 + hash01(h.x, h.y, 103) * 1.4, 0.55 + hash01(h.x, h.y, 104) * 0.45)
	batch.flush(canvas)

func paint_flowers(canvas: CanvasItem) -> void:
	if view == null or view.city == null:
		return
	var batch: RegionMapLayer.TriangleBatch = RegionMapLayer.TriangleBatch.new()
	for y in range(view.map_size.y):
		for x in range(view.map_size.x):
			var tile: Dictionary = tile_at(x, y)
			if not is_open_ground(tile, Vector2i(x, y)) or not tile["is_fertile"]:
				continue
			var h: Vector2i = view.hash_tile(x, y)
			for k in range(3):
				if hash01(h.x, h.y, 110 + k) > 0.14:
					continue
				var position: Vector2 = (Vector2(x, y) + Vector2(hash01(h.x, h.y, 120 + k), hash01(h.x, h.y, 130 + k))) * TownMapStyle.TILE
				LandscapePainter.add_flower(batch, position, 0.55, hash01(h.x, h.y, 140 + k))
	batch.flush(canvas)
