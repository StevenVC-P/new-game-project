class_name BuildingPainter
extends RefCounted

# Buildings seen from above and a little to the south, lit from the northwest: the same
# miniature style on the regional map and the town map. Sizes are in the caller's map units;
# the regional map draws a house a few units long, the town map one or two tiles.

const LIGHT_DIRECTION: Vector2 = Vector2(-0.63, -0.77)

# A gable-roofed building: its shadow, the front wall showing below the roof, and the two roof
# faces, the one facing the light brighter. wall_drop is how far the front wall shows.
static func draw_gabled(canvas: CanvasItem, center: Vector2, size: Vector2, angle: float, roof: Color, wall: Color, shadow_offset: Vector2, wall_drop: float, ridge_width: float) -> void:
	var half: Vector2 = size * 0.5
	canvas.draw_colored_polygon(RegionMapLayer.rotated_rect(center + shadow_offset, half, angle), RegionMapStyle.COLOR_SHADOW)
	canvas.draw_colored_polygon(RegionMapLayer.rotated_rect(center + Vector2(0.0, wall_drop), half, angle), wall.darkened(0.12))
	var axis: Vector2 = Vector2(cos(angle), sin(angle))
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var lit_side: float = 1.0 if across.dot(LIGHT_DIRECTION) > 0.0 else -1.0
	var ridge_a: Vector2 = center - axis * half.x
	var ridge_b: Vector2 = center + axis * half.x
	var lit_edge: Vector2 = across * half.y * lit_side
	canvas.draw_colored_polygon(PackedVector2Array([ridge_a, ridge_b, ridge_b + lit_edge, ridge_a + lit_edge]), roof.lightened(0.14))
	canvas.draw_colored_polygon(PackedVector2Array([ridge_a, ridge_b, ridge_b - lit_edge, ridge_a - lit_edge]), roof.darkened(0.22))
	canvas.draw_line(ridge_a, ridge_b, roof.darkened(0.4), ridge_width, true)
