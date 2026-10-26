class_name TownBoardLayer
extends TownMapLayer

# The town as a model on a table, like a bounded regional map (RegionBoardLayer): a soft
# shadow under the board and the cut soil edge along its southern and eastern sides.

func _draw() -> void:
	if view == null or view.map_size == Vector2i.ZERO:
		return
	var extent: Vector2 = map_extent()
	var thickness: float = TownMapStyle.BOARD_THICKNESS
	for i in range(6):
		var spread: float = 3.0 + i * 4.0
		draw_rect(Rect2(Vector2(5.0, 8.0) - Vector2(spread, spread) * 0.5, extent + Vector2(spread, spread + thickness)), Color(0.0, 0.0, 0.0, 0.07))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, extent.y), Vector2(extent.x, extent.y),
		Vector2(extent.x, extent.y + thickness), Vector2(0.0, extent.y + thickness)]), RegionMapStyle.COLOR_BOARD_SIDE)
	for band in range(1, 4):
		var y: float = extent.y + thickness * band / 4.0
		draw_line(Vector2(0.0, y), Vector2(extent.x, y), RegionMapStyle.COLOR_BOARD_SIDE_DARK, 0.8)
	draw_rect(Rect2(Vector2(0.0, extent.y), Vector2(extent.x, 1.2)), Color(0.24, 0.30, 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(extent.x, 0.0), Vector2(extent.x + 2.0, 2.0),
		Vector2(extent.x + 2.0, extent.y + thickness), Vector2(extent.x, extent.y + thickness)]), RegionMapStyle.COLOR_BOARD_SIDE_DARK)
