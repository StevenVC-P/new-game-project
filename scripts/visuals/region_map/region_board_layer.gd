class_name RegionBoardLayer
extends RegionMapLayer

# The region as a model landscape on a table: a soft shadow under the board and the cut
# soil edge along its southern side. Drawn under the terrain.

func _draw() -> void:
	if view == null or view.map_size == Vector2i.ZERO:
		return
	var extent: Vector2 = map_extent()
	var thickness: float = RegionMapStyle.BOARD_THICKNESS
	# Soft shadow cast on the table, offset away from the light.
	for i in range(6):
		var spread: float = 2.0 + i * 3.0
		var shadow: Rect2 = Rect2(Vector2(4.0, 6.0) - Vector2(spread, spread) * 0.5, extent + Vector2(spread, spread + thickness))
		draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.07))
	# Cut edge of the board: soil layers under a grass lip.
	var side: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, extent.y), Vector2(extent.x, extent.y),
		Vector2(extent.x, extent.y + thickness), Vector2(0.0, extent.y + thickness)])
	draw_colored_polygon(side, RegionMapStyle.COLOR_BOARD_SIDE)
	for band in range(1, 4):
		var y: float = extent.y + thickness * band / 4.0
		draw_line(Vector2(0.0, y), Vector2(extent.x, y), RegionMapStyle.COLOR_BOARD_SIDE_DARK, 0.6)
	draw_rect(Rect2(Vector2(0.0, extent.y), Vector2(extent.x, 1.0)), Color(0.24, 0.30, 0.16))
	var east: PackedVector2Array = PackedVector2Array([
		Vector2(extent.x, 0.0), Vector2(extent.x + 1.6, 1.6),
		Vector2(extent.x + 1.6, extent.y + thickness), Vector2(extent.x, extent.y + thickness)])
	draw_colored_polygon(east, RegionMapStyle.COLOR_BOARD_SIDE_DARK)
