class_name MapElementVisuals
extends RefCounted

# Presentation helpers for regional map elements.
# Later this can swap lines/circles for textured strokes, animated route markers,
# culture-specific city symbols, or sprite-based map decorations.

static func draw_road_segment(canvas: CanvasItem, start_center: Vector2, end_center: Vector2):
	canvas.draw_line(start_center, end_center, VisualStyle.COLOR_ROAD_BASE, VisualStyle.MAP_LINE_WIDTH_ROAD_BASE)
	canvas.draw_line(start_center, end_center, VisualStyle.COLOR_ROAD_CENTER, VisualStyle.MAP_LINE_WIDTH_ROAD_CENTER)

static func draw_trade_route(canvas: CanvasItem, source_center: Vector2, destination_center: Vector2, is_highlighted: bool = false):
	var route_width: float = VisualStyle.MAP_LINE_WIDTH_TRADE
	if is_highlighted:
		route_width += 1.0

	canvas.draw_line(source_center, destination_center, VisualStyle.COLOR_TRADE_ROUTE_SHADOW, VisualStyle.MAP_LINE_WIDTH_TRADE_SHADOW)
	canvas.draw_line(source_center, destination_center, VisualStyle.COLOR_TRADE_ROUTE, route_width)

static func draw_ford(canvas: CanvasItem, tile_rect: Rect2):
	var ford_rect: Rect2 = Rect2(
		tile_rect.position + Vector2(2.0, tile_rect.size.y * 0.34),
		Vector2(max(2.0, tile_rect.size.x - 4.0), max(2.0, tile_rect.size.y * 0.34))
	)
	canvas.draw_rect(ford_rect, VisualStyle.COLOR_FORD)

static func draw_city_marker(canvas: CanvasItem, center: Vector2, tile_size: int, is_hovered: bool = false, is_selected: bool = false):
	var outer_radius: float = float(tile_size) * 0.85
	var inner_radius: float = float(tile_size) * 0.40

	if is_selected:
		canvas.draw_circle(center, outer_radius + 3.0, VisualStyle.COLOR_SELECTION_OUTLINE)
	elif is_hovered:
		canvas.draw_circle(center, outer_radius + 2.0, VisualStyle.COLOR_HOVER_OUTLINE)

	canvas.draw_circle(center, outer_radius, VisualStyle.COLOR_CITY_MARKER_OUTER)
	canvas.draw_circle(center, inner_radius, VisualStyle.COLOR_CITY_MARKER_INNER)

static func draw_tile_hover_outline(canvas: CanvasItem, tile_rect: Rect2):
	canvas.draw_rect(tile_rect, VisualStyle.COLOR_HOVER_OUTLINE, false, VisualStyle.PANEL_BORDER_WIDTH)

static func draw_selection_outline(canvas: CanvasItem, rect: Rect2):
	canvas.draw_rect(rect, VisualStyle.COLOR_SELECTION_OUTLINE, false, VisualStyle.PANEL_BORDER_WIDTH)
