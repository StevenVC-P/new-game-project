class_name BuildingVisuals
extends RefCounted

# Building visual profiles keep current drawn shapes separate from simulation data.
# A future sprite/texture renderer can use these same semantic profile keys.

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"

const GLYPH_HOUSE: String = "house"
const GLYPH_FARM: String = "farm"
const GLYPH_WOODCUTTER: String = "woodcutter"
const GLYPH_TOOLMAKER: String = "toolmaker"

static func get_profile(building_type: String) -> Dictionary:
	if building_type == BUILDING_FARM:
		return {
			"type": BUILDING_FARM,
			"base_color": VisualStyle.COLOR_BUILDING_FARM,
			"outline_color": VisualStyle.COLOR_BUILDING_OUTLINE,
			"accent_color": VisualStyle.COLOR_BUILDING_FARM_ACCENT,
			"glyph": GLYPH_FARM,
			"icon_hint": "furrows"
		}
	if building_type == BUILDING_WOODCUTTER:
		return {
			"type": BUILDING_WOODCUTTER,
			"base_color": VisualStyle.COLOR_BUILDING_WOODCUTTER,
			"outline_color": VisualStyle.COLOR_BUILDING_OUTLINE,
			"accent_color": VisualStyle.COLOR_BUILDING_WOODCUTTER_ACCENT,
			"glyph": GLYPH_WOODCUTTER,
			"icon_hint": "logs"
		}
	if building_type == BUILDING_TOOLMAKER:
		return {
			"type": BUILDING_TOOLMAKER,
			"base_color": VisualStyle.COLOR_BUILDING_TOOLMAKER,
			"outline_color": VisualStyle.COLOR_BUILDING_OUTLINE,
			"accent_color": VisualStyle.COLOR_BUILDING_TOOLMAKER_ACCENT,
			"glyph": GLYPH_TOOLMAKER,
			"icon_hint": "workshop"
		}

	return {
		"type": BUILDING_HOUSE,
		"base_color": VisualStyle.COLOR_BUILDING_HOUSE,
		"outline_color": VisualStyle.COLOR_BUILDING_OUTLINE,
		"accent_color": VisualStyle.COLOR_BUILDING_HOUSE_ACCENT,
		"glyph": GLYPH_HOUSE,
		"icon_hint": "roof"
	}

static func draw_building(canvas: CanvasItem, rect: Rect2, building_type: String):
	var profile: Dictionary = get_profile(building_type)
	canvas.draw_rect(rect, profile["base_color"] as Color)

	var glyph: String = profile["glyph"] as String
	if glyph == GLYPH_HOUSE:
		draw_house(canvas, rect, profile)
	elif glyph == GLYPH_FARM:
		draw_farm(canvas, rect, profile)
	elif glyph == GLYPH_WOODCUTTER:
		draw_woodcutter(canvas, rect, profile)
	elif glyph == GLYPH_TOOLMAKER:
		draw_toolmaker(canvas, rect, profile)

	canvas.draw_rect(rect, profile["outline_color"] as Color, false, 1.5)

static func draw_house(canvas: CanvasItem, rect: Rect2, profile: Dictionary):
	var body_margin: float = max(2.0, rect.size.x * 0.12)
	var roof_height: float = max(5.0, rect.size.y * 0.34)
	var body_rect: Rect2 = Rect2(
		rect.position + Vector2(body_margin, roof_height),
		Vector2(rect.size.x - body_margin * 2.0, rect.size.y - roof_height - 2.0)
	)
	var roof_points: PackedVector2Array = PackedVector2Array([
		Vector2(rect.position.x + rect.size.x * 0.50, rect.position.y + 2.0),
		Vector2(rect.position.x + rect.size.x - 2.0, rect.position.y + roof_height + 2.0),
		Vector2(rect.position.x + 2.0, rect.position.y + roof_height + 2.0)
	])

	var roof_color: Color = profile["accent_color"] as Color
	canvas.draw_polygon(roof_points, PackedColorArray([roof_color, roof_color, roof_color]))
	canvas.draw_rect(body_rect, profile["base_color"] as Color)
	canvas.draw_line(roof_points[0], roof_points[1], profile["outline_color"] as Color, 1.0)
	canvas.draw_line(roof_points[1], roof_points[2], profile["outline_color"] as Color, 1.0)
	canvas.draw_line(roof_points[2], roof_points[0], profile["outline_color"] as Color, 1.0)

static func draw_farm(canvas: CanvasItem, rect: Rect2, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var line_count: int = 3
	var gap: float = rect.size.x / float(line_count + 1)
	for line_index in range(line_count):
		var x: float = rect.position.x + gap * float(line_index + 1)
		canvas.draw_line(Vector2(x, rect.position.y + 3.0), Vector2(x - 3.0, rect.position.y + rect.size.y - 4.0), accent_color, 1.0)

	var cross_y: float = rect.position.y + rect.size.y * 0.58
	canvas.draw_line(Vector2(rect.position.x + 3.0, cross_y), Vector2(rect.position.x + rect.size.x - 4.0, cross_y - 2.0), accent_color, 1.0)

static func draw_woodcutter(canvas: CanvasItem, rect: Rect2, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var outline_color: Color = profile["outline_color"] as Color
	var log_radius: float = max(2.0, min(rect.size.x, rect.size.y) * 0.12)
	var log_y: float = rect.position.y + rect.size.y * 0.60
	for log_index in range(3):
		var center: Vector2 = Vector2(rect.position.x + rect.size.x * (0.32 + 0.16 * float(log_index)), log_y + float(log_index % 2) * 3.0)
		canvas.draw_circle(center, log_radius, accent_color)
		canvas.draw_circle(center, max(1.0, log_radius - 1.0), VisualStyle.COLOR_BUILDING_WOODCUTTER)
		canvas.draw_arc(center, log_radius, 0.0, TAU, 12, outline_color, 1.0)

	var handle_start: Vector2 = rect.position + Vector2(rect.size.x * 0.66, rect.size.y * 0.24)
	var handle_end: Vector2 = rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.46)
	canvas.draw_line(handle_start, handle_end, outline_color, 1.4)
	canvas.draw_line(handle_start + Vector2(-2.0, 0.0), handle_start + Vector2(4.0, -2.0), accent_color, 1.6)

static func draw_toolmaker(canvas: CanvasItem, rect: Rect2, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var outline_color: Color = profile["outline_color"] as Color
	var chimney_rect: Rect2 = Rect2(
		rect.position + Vector2(rect.size.x - 8.0, 2.0),
		Vector2(4.0, max(5.0, rect.size.y * 0.28))
	)
	canvas.draw_rect(chimney_rect, accent_color)
	canvas.draw_rect(chimney_rect, outline_color, false, 1.0)

	var anvil_base: Vector2 = rect.position + Vector2(rect.size.x * 0.33, rect.size.y * 0.62)
	canvas.draw_line(anvil_base, anvil_base + Vector2(rect.size.x * 0.34, 0.0), accent_color, 2.0)
	canvas.draw_line(anvil_base + Vector2(4.0, 0.0), anvil_base + Vector2(8.0, 5.0), accent_color, 2.0)
	canvas.draw_line(anvil_base + Vector2(rect.size.x * 0.28, 0.0), anvil_base + Vector2(rect.size.x * 0.23, 5.0), accent_color, 2.0)

	var hammer_start: Vector2 = rect.position + Vector2(rect.size.x * 0.58, rect.size.y * 0.30)
	var hammer_end: Vector2 = rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.48)
	canvas.draw_line(hammer_start, hammer_end, outline_color, 1.5)
	canvas.draw_line(hammer_start + Vector2(-3.0, -1.0), hammer_start + Vector2(4.0, 2.0), accent_color, 2.0)
