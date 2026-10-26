class_name WorldLabelLayer
extends WorldMapLayer

# Atlas lettering at a constant screen size. Labels are placed greedily by priority
# (kingdoms, settlements by importance, geography, then regions) and any label that
# would collide with an icon or an earlier label is left out for this zoom.

const LABEL_PADDING: float = 3.0
const OUTLINE_PX: int = 4
const OUTLINE_LIGHT: Color = Color(0.97, 0.94, 0.85, 0.7)

class PlacedLabel:
	var text: String
	var font: Font
	var size: int
	var color: Color
	var outline_color: Color
	var world_position: Vector2
	# Offset from the anchor in screen pixels, to the label's center.
	var screen_offset: Vector2
	var angle: float
	var tracking: float
	var alpha: float

var placed: Array[PlacedLabel] = []
var occupied: Array[Rect2] = []
# Index into `occupied` of each settlement's icon, so its own label may touch it.
var icon_rect_index: Dictionary = {}

func before_draw() -> void:
	placed.clear()
	occupied.clear()
	icon_rect_index.clear()
	reserve_settlement_icons()
	place_kingdom_labels()
	place_settlement_labels()
	place_geo_labels()
	place_region_labels()

func draw_world() -> void:
	for label: PlacedLabel in placed:
		draw_label(label)
	draw_set_transform(draw_offset)

# --- Placement -------------------------------------------------------------

func reserve_settlement_icons() -> void:
	for settlement: WorldMapData.Settlement in data.settlements:
		if WorldMapStyle.settlement_visibility(settlement, zoom) <= 0.3 or not is_in_any_view(Rect2(settlement.position, Vector2.ZERO)):
			continue
		var radius: float = WorldMapStyle.settlement_icon_radius(settlement, zoom)
		var center: Vector2 = settlement.position * zoom
		icon_rect_index[settlement.id] = occupied.size()
		occupied.append(Rect2(center - Vector2(radius * 1.1, radius * 1.3), Vector2(radius * 2.2, radius * 2.2)))

func place_kingdom_labels() -> void:
	var visibility: float = WorldMapStyle.kingdom_label_visibility(zoom)
	if visibility <= 0.02:
		return
	# Larger kingdoms are lettered larger and placed first; a small kingdom whose name
	# would run into a neighbor's tries above and below its anchor instead.
	var region_counts: Dictionary = {}
	for kingdom: WorldMapData.Kingdom in data.kingdoms:
		region_counts[kingdom.id] = data.get_kingdom_regions(kingdom.id).size()
	var ordered: Array[WorldMapData.Kingdom] = data.kingdoms.duplicate()
	ordered.sort_custom(func(a: WorldMapData.Kingdom, b: WorldMapData.Kingdom) -> bool: return region_counts[a.id] > region_counts[b.id])
	var kingdom_rects: Array[Rect2] = []
	for kingdom: WorldMapData.Kingdom in ordered:
		var size: int = int(round(13.0 + minf(region_counts[kingdom.id], 10.0) * 0.9 + clampf(zoom * 6.0, 0.0, 4.0)))
		var tracking: float = size * 0.3
		var text: String = kingdom.name.to_upper()
		var text_size: Vector2 = measure(text, WorldMapStyle.serif_bold_font(), size, tracking)
		for offset: Vector2 in [Vector2.ZERO, Vector2(0.0, -text_size.y * 1.3), Vector2(0.0, text_size.y * 1.3)]:
			var rect: Rect2 = Rect2(kingdom.label_position * zoom + offset - text_size * 0.5, text_size).grow(LABEL_PADDING)
			var clear: bool = true
			for other: Rect2 in kingdom_rects:
				clear = clear and not other.intersects(rect)
			if clear:
				kingdom_rects.append(rect)
				# Kingdom names ignore icons; every later label makes room for them.
				add_label(text, WorldMapStyle.serif_bold_font(), size, kingdom.color.darkened(0.45), kingdom.label_position, offset, 0.0, tracking, visibility * 0.9, false)
				break

func place_settlement_labels() -> void:
	var ordered: Array[WorldMapData.Settlement] = data.settlements.duplicate()
	ordered.sort_custom(func(a: WorldMapData.Settlement, b: WorldMapData.Settlement) -> bool:
		if a.is_capital != b.is_capital:
			return a.is_capital
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.population > b.population)
	for settlement: WorldMapData.Settlement in ordered:
		var visibility: float = WorldMapStyle.settlement_visibility(settlement, zoom)
		if visibility <= 0.3:
			continue
		var size: int = WorldMapStyle.settlement_label_size(settlement)
		var font: Font = WorldMapStyle.serif_bold_font() if settlement.is_capital else WorldMapStyle.serif_font()
		var radius: float = WorldMapStyle.settlement_icon_radius(settlement, zoom)
		var text_size: Vector2 = measure(settlement.name, font, size, 0.0)
		# Try below the icon, then right, left, and above.
		var candidates: Array[Vector2] = [
			Vector2(0.0, radius * 0.95 + text_size.y * 0.5),
			Vector2(radius * 1.15 + text_size.x * 0.5, radius * 0.1),
			Vector2(-radius * 1.15 - text_size.x * 0.5, radius * 0.1),
			Vector2(0.0, -radius * 1.4 - text_size.y * 0.5)]
		for offset: Vector2 in candidates:
			if add_label(settlement.name, font, size, WorldMapStyle.COLOR_LABEL_SETTLEMENT, settlement.position, offset, 0.0, 0.0, visibility, true, OUTLINE_LIGHT, icon_rect_index.get(settlement.id, -1)):
				break

func place_geo_labels() -> void:
	for geo_label: WorldMapData.GeoLabel in data.geo_labels:
		var visibility: float = WorldMapStyle.geo_label_visibility(geo_label.kind, zoom)
		if visibility <= 0.02:
			continue
		match geo_label.kind:
			WorldMapData.LABEL_OCEAN:
				add_label(geo_label.text.to_upper(), WorldMapStyle.serif_italic_font(), 15, WorldMapStyle.COLOR_LABEL_OCEAN, geo_label.position, Vector2.ZERO, geo_label.angle, 4.0, visibility * 0.85, true, Color(0.06, 0.14, 0.24, 0.5))
			WorldMapData.LABEL_SEA:
				add_label(geo_label.text, WorldMapStyle.serif_italic_font(), 13, WorldMapStyle.COLOR_LABEL_SEA, geo_label.position, Vector2.ZERO, geo_label.angle, 1.5, visibility * 0.85, true, Color(0.08, 0.18, 0.28, 0.5))
			WorldMapData.LABEL_CONTINENT:
				add_label(geo_label.text.to_upper(), WorldMapStyle.serif_font(), 22, WorldMapStyle.COLOR_LABEL_CONTINENT, geo_label.position, Vector2.ZERO, geo_label.angle, 9.0, visibility * 0.42, true)
			_:
				add_label(geo_label.text.to_upper(), WorldMapStyle.serif_italic_font(), 12, WorldMapStyle.COLOR_LABEL_LANDFORM, geo_label.position, Vector2.ZERO, geo_label.angle, 2.5, visibility * 0.85, true)

func place_region_labels() -> void:
	var visibility: float = WorldMapStyle.region_label_visibility(zoom)
	if visibility <= 0.02:
		return
	for region: WorldMapData.Region in data.regions:
		add_label(region.name.to_upper(), WorldMapStyle.serif_font(), 10, WorldMapStyle.COLOR_LABEL_REGION, region.centroid, Vector2.ZERO, 0.0, 1.6, visibility * 0.75, true)

func add_label(text: String, font: Font, size: int, color: Color, world_position: Vector2, screen_offset: Vector2, angle: float, tracking: float, alpha: float, avoid_collisions: bool, outline_color: Color = OUTLINE_LIGHT, ignored_rect: int = -1) -> bool:
	# Labels far from the view are skipped; the view's margin keeps every label that could
	# meet one on screen, so what shows is placed exactly as without culling.
	if not is_in_any_view(Rect2(world_position, Vector2.ZERO)):
		return false
	var text_size: Vector2 = measure(text, font, size, tracking)
	var center: Vector2 = world_position * zoom + screen_offset
	var extent: Vector2 = text_size
	if not is_zero_approx(angle):
		# Bounding box of the rotated label.
		var c: float = absf(cos(angle))
		var s: float = absf(sin(angle))
		extent = Vector2(text_size.x * c + text_size.y * s, text_size.x * s + text_size.y * c)
	var rect: Rect2 = Rect2(center - extent * 0.5, extent).grow(LABEL_PADDING)
	if avoid_collisions:
		for i in range(occupied.size()):
			if i != ignored_rect and occupied[i].intersects(rect):
				return false
	occupied.append(rect)

	var label: PlacedLabel = PlacedLabel.new()
	label.text = text
	label.font = font
	label.size = size
	label.color = color
	label.outline_color = outline_color
	label.world_position = world_position
	label.screen_offset = screen_offset
	label.angle = angle
	label.tracking = tracking
	label.alpha = alpha
	placed.append(label)
	return true

static func measure(text: String, font: Font, size: int, tracking: float) -> Vector2:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	return Vector2(text_size.x + tracking * maxf(0.0, text.length() - 1.0), font.get_height(size))

# --- Drawing ---------------------------------------------------------------

func draw_label(label: PlacedLabel) -> void:
	# Scale 1/zoom cancels the camera zoom, so glyphs render at their native pixel size.
	draw_set_transform(draw_offset + label.world_position + label.screen_offset / zoom, label.angle, Vector2(1.0 / zoom, 1.0 / zoom))
	var text_size: Vector2 = measure(label.text, label.font, label.size, label.tracking)
	var baseline: Vector2 = Vector2(-text_size.x * 0.5, label.font.get_ascent(label.size) - text_size.y * 0.5)
	var outline_color: Color = faded(label.outline_color, label.alpha)
	var color: Color = faded(label.color, label.alpha)
	if is_zero_approx(label.tracking):
		draw_string_outline(label.font, baseline, label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.size, OUTLINE_PX, outline_color)
		draw_string(label.font, baseline, label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.size, color)
		return
	# Letter-spaced lettering, drawn glyph by glyph.
	var pen: Vector2 = baseline
	for character in label.text:
		draw_char_outline(label.font, pen, character, label.size, OUTLINE_PX, outline_color)
		pen.x += label.font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, label.size).x + label.tracking
	pen = baseline
	for character in label.text:
		draw_char(label.font, pen, character, label.size, color)
		pen.x += label.font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, label.size).x + label.tracking
