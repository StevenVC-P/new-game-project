class_name SettlementIconPainter
extends RefCounted

# Illustrated settlement symbols in one universal late-medieval style. Development reads
# as architectural complexity: cottages, then a church town, a walled city, and a great
# walled city with a cathedral. Capital status is a separate mark (a pennant in the
# kingdom's color), so a small town can carry it and a large city can lack it.
#
# Drawing happens in icon units: the caller sets a transform where the icon spans roughly
# -1..1 and the ground line sits near y = 0.6.

const GROUND_Y: float = 0.6
const INK_WIDTH: float = 0.07

static func draw_icon(canvas: CanvasItem, settlement: WorldMapData.Settlement, kingdom_color: Color, alpha: float, highlight: Color) -> void:
	var width: float = 0.95 if settlement.tier < WorldMapData.TIER_GREAT_CITY else 1.15
	if highlight.a > 0.0:
		draw_ellipse(canvas, Vector2(0.0, GROUND_Y), Vector2(width + 0.32, 0.42), with_alpha(highlight, alpha * 0.9))
	draw_ellipse(canvas, Vector2(0.06, GROUND_Y + 0.06), Vector2(width, 0.27), Color(0.0, 0.0, 0.0, 0.28 * alpha))
	# The ground plate carries the political color; independents get plain parchment.
	draw_ellipse(canvas, Vector2(0.0, GROUND_Y), Vector2(width, 0.25), with_alpha(kingdom_color, alpha))
	draw_ellipse_outline(canvas, Vector2(0.0, GROUND_Y), Vector2(width, 0.25), with_alpha(WorldMapStyle.COLOR_INK, alpha * 0.85))

	var flag_top: Vector2
	match settlement.tier:
		WorldMapData.TIER_GREAT_CITY:
			flag_top = draw_great_city(canvas, alpha)
		WorldMapData.TIER_CITY:
			flag_top = draw_city(canvas, alpha)
		WorldMapData.TIER_TOWN:
			flag_top = draw_town(canvas, alpha)
		_:
			flag_top = draw_village(canvas, alpha)

	if settlement.is_capital:
		draw_pennant(canvas, flag_top, kingdom_color, alpha)

static func draw_village(canvas: CanvasItem, alpha: float) -> Vector2:
	draw_house(canvas, -0.32, GROUND_Y - 0.02, 0.52, 0.34, 0.3, alpha)
	draw_house(canvas, 0.33, GROUND_Y + 0.02, 0.44, 0.28, 0.25, alpha)
	return Vector2(-0.32, GROUND_Y - 0.66)

static func draw_town(canvas: CanvasItem, alpha: float) -> Vector2:
	draw_house(canvas, -0.58, GROUND_Y, 0.42, 0.3, 0.25, alpha)
	draw_house(canvas, 0.62, GROUND_Y + 0.02, 0.4, 0.27, 0.23, alpha)
	var spire_top: Vector2 = draw_church(canvas, 0.0, GROUND_Y - 0.02, 0.85, alpha)
	return spire_top

static func draw_city(canvas: CanvasItem, alpha: float) -> Vector2:
	draw_house(canvas, -0.42, 0.12, 0.42, 0.3, 0.26, alpha)
	draw_house(canvas, 0.42, 0.1, 0.4, 0.3, 0.25, alpha)
	var keep_top: Vector2 = draw_keep(canvas, 0.0, 0.2, 0.34, 0.92, alpha)
	draw_wall(canvas, -0.82, 0.82, 0.18, GROUND_Y, alpha)
	draw_round_tower(canvas, -0.84, GROUND_Y, 0.28, 0.72, alpha)
	draw_round_tower(canvas, 0.84, GROUND_Y, 0.28, 0.72, alpha)
	return keep_top

static func draw_great_city(canvas: CanvasItem, alpha: float) -> Vector2:
	draw_house(canvas, -1.38, GROUND_Y + 0.02, 0.36, 0.24, 0.2, alpha)
	draw_house(canvas, 1.38, GROUND_Y + 0.04, 0.34, 0.22, 0.19, alpha)
	draw_house(canvas, -0.62, 0.08, 0.4, 0.3, 0.24, alpha)
	draw_house(canvas, 0.66, 0.06, 0.42, 0.32, 0.25, alpha)
	draw_church(canvas, 0.38, 0.12, 0.95, alpha)
	var keep_top: Vector2 = draw_keep(canvas, -0.18, 0.16, 0.38, 1.12, alpha)
	draw_wall(canvas, -1.04, 1.04, 0.14, GROUND_Y, alpha)
	draw_round_tower(canvas, -1.06, GROUND_Y, 0.3, 0.8, alpha)
	draw_round_tower(canvas, 0.0, GROUND_Y + 0.02, 0.26, 0.62, alpha)
	draw_round_tower(canvas, 1.06, GROUND_Y, 0.3, 0.8, alpha)
	return keep_top

# --- Architectural pieces --------------------------------------------------

static func draw_house(canvas: CanvasItem, x: float, ground: float, w: float, h: float, roof_h: float, alpha: float) -> void:
	var body: Rect2 = Rect2(x - w * 0.5, ground - h, w, h)
	canvas.draw_rect(body, with_alpha(WorldMapStyle.COLOR_PLASTER, alpha))
	canvas.draw_rect(Rect2(x + w * 0.1, ground - h, w * 0.4, h), with_alpha(WorldMapStyle.COLOR_WALL_SHADE, alpha * 0.55))
	var roof: PackedVector2Array = PackedVector2Array([
		Vector2(x - w * 0.62, ground - h), Vector2(x + w * 0.62, ground - h), Vector2(x, ground - h - roof_h)])
	canvas.draw_colored_polygon(roof, with_alpha(WorldMapStyle.COLOR_ROOF, alpha))
	canvas.draw_colored_polygon(PackedVector2Array([roof[1], roof[2], Vector2(x, ground - h)]), with_alpha(WorldMapStyle.COLOR_ROOF_DARK, alpha))
	outline(canvas, PackedVector2Array([body.position + Vector2(0, body.size.y), body.position, roof[0], roof[2], roof[1], body.end - Vector2(0, body.size.y), body.end]), alpha)
	canvas.draw_line(Vector2(body.position.x, ground), body.end, with_alpha(WorldMapStyle.COLOR_INK, alpha), INK_WIDTH)

static func draw_church(canvas: CanvasItem, x: float, ground: float, tower_h: float, alpha: float) -> Vector2:
	draw_house(canvas, x + 0.26, ground, 0.42, 0.38, 0.24, alpha)
	var tower: Rect2 = Rect2(x - 0.11, ground - tower_h, 0.22, tower_h)
	canvas.draw_rect(tower, with_alpha(WorldMapStyle.COLOR_WALL, alpha))
	canvas.draw_rect(Rect2(x + 0.02, ground - tower_h, 0.09, tower_h), with_alpha(WorldMapStyle.COLOR_WALL_SHADE, alpha * 0.7))
	var spire: PackedVector2Array = PackedVector2Array([
		Vector2(x - 0.15, ground - tower_h), Vector2(x + 0.15, ground - tower_h), Vector2(x, ground - tower_h - 0.5)])
	canvas.draw_colored_polygon(spire, with_alpha(WorldMapStyle.COLOR_ROOF_DARK, alpha))
	outline(canvas, PackedVector2Array([Vector2(tower.position.x, ground), tower.position, spire[0], spire[2], spire[1], Vector2(tower.end.x, tower.position.y), Vector2(tower.end.x, ground)]), alpha)
	return spire[2]

static func draw_keep(canvas: CanvasItem, x: float, ground: float, w: float, h: float, alpha: float) -> Vector2:
	var body: Rect2 = Rect2(x - w * 0.5, ground - h, w, h)
	canvas.draw_rect(body, with_alpha(WorldMapStyle.COLOR_WALL, alpha))
	canvas.draw_rect(Rect2(x + w * 0.1, ground - h, w * 0.4, h), with_alpha(WorldMapStyle.COLOR_WALL_SHADE, alpha * 0.7))
	draw_crenels(canvas, body.position.x, body.end.x, body.position.y, w * 0.24, alpha)
	outline(canvas, PackedVector2Array([Vector2(body.position.x, ground), body.position, Vector2(body.end.x, body.position.y), Vector2(body.end.x, ground)]), alpha)
	canvas.draw_rect(Rect2(x - w * 0.12, ground - h * 0.62, w * 0.24, h * 0.18), with_alpha(WorldMapStyle.COLOR_INK, alpha * 0.8))
	return Vector2(x, body.position.y - 0.1)

static func draw_wall(canvas: CanvasItem, left: float, right: float, top: float, ground: float, alpha: float) -> void:
	var wall: Rect2 = Rect2(left, top, right - left, ground - top)
	canvas.draw_rect(wall, with_alpha(WorldMapStyle.COLOR_WALL, alpha))
	canvas.draw_rect(Rect2(left, top + (ground - top) * 0.55, right - left, (ground - top) * 0.45), with_alpha(WorldMapStyle.COLOR_WALL_SHADE, alpha * 0.6))
	draw_crenels(canvas, left, right, top, 0.12, alpha)
	outline(canvas, PackedVector2Array([Vector2(left, ground), Vector2(left, top), Vector2(right, top), Vector2(right, ground), Vector2(left, ground)]), alpha)
	# Gate.
	var gate: PackedVector2Array = PackedVector2Array([
		Vector2(-0.1, ground), Vector2(-0.1, ground - 0.2), Vector2(0.0, ground - 0.28), Vector2(0.1, ground - 0.2), Vector2(0.1, ground)])
	canvas.draw_colored_polygon(gate, with_alpha(WorldMapStyle.COLOR_INK, alpha * 0.85))

static func draw_round_tower(canvas: CanvasItem, x: float, ground: float, w: float, h: float, alpha: float) -> void:
	var body: Rect2 = Rect2(x - w * 0.5, ground - h, w, h)
	canvas.draw_rect(body, with_alpha(WorldMapStyle.COLOR_WALL, alpha))
	canvas.draw_rect(Rect2(x + w * 0.05, ground - h, w * 0.45, h), with_alpha(WorldMapStyle.COLOR_WALL_SHADE, alpha * 0.7))
	var cone: PackedVector2Array = PackedVector2Array([
		Vector2(x - w * 0.68, ground - h), Vector2(x + w * 0.68, ground - h), Vector2(x, ground - h - w * 1.25)])
	canvas.draw_colored_polygon(cone, with_alpha(WorldMapStyle.COLOR_ROOF, alpha))
	outline(canvas, PackedVector2Array([Vector2(body.position.x, ground), body.position, cone[0], cone[2], cone[1], Vector2(body.end.x, body.position.y), Vector2(body.end.x, ground)]), alpha)

static func draw_crenels(canvas: CanvasItem, left: float, right: float, top: float, step: float, alpha: float) -> void:
	var x: float = left
	while x + step * 0.6 <= right + 0.001:
		canvas.draw_rect(Rect2(x, top - step * 0.55, step * 0.6, step * 0.55), with_alpha(WorldMapStyle.COLOR_WALL, alpha))
		canvas.draw_rect(Rect2(x, top - step * 0.55, step * 0.6, step * 0.55), with_alpha(WorldMapStyle.COLOR_INK, alpha), false, INK_WIDTH * 0.7)
		x += step

static func draw_pennant(canvas: CanvasItem, top: Vector2, kingdom_color: Color, alpha: float) -> void:
	var pole_top: Vector2 = top + Vector2(0.0, -0.62)
	canvas.draw_line(top, pole_top, with_alpha(WorldMapStyle.COLOR_INK, alpha), INK_WIDTH * 1.2)
	var flag: PackedVector2Array = PackedVector2Array([
		pole_top, pole_top + Vector2(0.62, 0.12), pole_top + Vector2(0.44, 0.2), pole_top + Vector2(0.62, 0.3), pole_top + Vector2(0.0, 0.34)])
	canvas.draw_colored_polygon(flag, with_alpha(kingdom_color, alpha))
	outline(canvas, flag + PackedVector2Array([pole_top]), alpha)

# --- Primitives ------------------------------------------------------------

static func outline(canvas: CanvasItem, points: PackedVector2Array, alpha: float) -> void:
	canvas.draw_polyline(points, with_alpha(WorldMapStyle.COLOR_INK, alpha * 0.9), INK_WIDTH, true)

static func draw_ellipse(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(ellipse_points(center, radius, 20), color)

static func draw_ellipse_outline(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = ellipse_points(center, radius, 20)
	points.append(points[0])
	canvas.draw_polyline(points, color, INK_WIDTH, true)

static func ellipse_points(center: Vector2, radius: Vector2, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
