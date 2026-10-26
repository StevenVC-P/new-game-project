class_name WorldMapPanel
extends Node2D

# Screen-space HUD for the world map: top bar with layer toggles, an inspector for the
# selected region or settlement, a hover tooltip, and a small legend. It only reads
# state from the WorldMapView and asks the view to act; it never changes world data.

const TOP_BAR_HEIGHT: float = 42.0
const INSPECTOR_WIDTH: float = 300.0
const INSPECTOR_MARGIN: float = 12.0
const PADDING: float = 14.0
const ROW_HEIGHT: float = 17.0
const LEGEND_SIZE: Vector2 = Vector2(214.0, 150.0)

var view: WorldMapView = null
var buttons: Array[Dictionary] = []
var blocking_rects: Array[Rect2] = []
var show_legend: bool = true

func _draw() -> void:
	if view == null or view.data == null:
		return
	buttons.clear()
	blocking_rects.clear()
	var font: Font = ThemeDB.fallback_font
	draw_top_bar(font)
	draw_inspector(font)
	if show_legend:
		draw_legend(font)
	draw_tooltip(font)

# Returns true when the press landed on the HUD, so the map ignores it.
func handle_mouse_button(event: InputEventMouseButton) -> bool:
	if not is_over_hud(event.position):
		return false
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for button: Dictionary in buttons:
			if (button["rect"] as Rect2).has_point(event.position) and bool(button["enabled"]):
				view.apply_hud_action(button["action"])
				return true
	return event.pressed

func is_over_hud(screen_position: Vector2) -> bool:
	for rect: Rect2 in blocking_rects:
		if rect.has_point(screen_position):
			return true
	return false

# --- Top bar ---------------------------------------------------------------

func draw_top_bar(font: Font) -> void:
	var width: float = get_viewport_rect().size.x
	var bar: Rect2 = Rect2(Vector2.ZERO, Vector2(width, TOP_BAR_HEIGHT))
	blocking_rects.append(bar)
	draw_rect(bar, VisualStyle.COLOR_UI_PANEL_BACKGROUND)
	draw_rect(Rect2(Vector2(0.0, TOP_BAR_HEIGHT - 2.0), Vector2(width, 2.0)), VisualStyle.COLOR_UI_PANEL_BORDER)

	var x: float = 12.0
	var baseline: float = 26.0
	if view.home_region_id >= 0:
		var home: WorldMapData.Region = view.data.get_region(view.home_region_id)
		var back_text: String = "Back to " + home.name
		var back_width: float = font.get_string_size(back_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		x = draw_button(font, back_text, x, back_width, "return", true, VisualStyle.COLOR_UI_BUTTON_ACTIVE)
		x += 8.0
	draw_string(font, Vector2(x, baseline), "World Atlas", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, VisualStyle.COLOR_UI_TITLE)
	x += 108.0
	draw_string(font, Vector2(x, baseline), "Drag to pan, wheel to zoom, click a region to inspect", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, VisualStyle.COLOR_UI_TEXT_MUTED)

	var toggles: Array = [["Borders (B)", "toggle_borders", view.show_borders], ["Roads (R)", "toggle_roads", view.show_roads],
		["Towns (T)", "toggle_settlements", view.show_settlements], ["Labels (L)", "toggle_labels", view.show_labels],
		["Legend", "toggle_legend", show_legend]]
	var right: float = width - 12.0
	for i in range(toggles.size() - 1, -1, -1):
		var toggle: Array = toggles[i]
		var button_width: float = font.get_string_size(toggle[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		right -= button_width
		var color: Color = VisualStyle.COLOR_UI_BUTTON_ACTIVE if bool(toggle[2]) else VisualStyle.COLOR_UI_BUTTON_DISABLED
		draw_button(font, toggle[0], right, button_width, toggle[1], true, color)
		right -= 6.0

func draw_button(font: Font, text: String, x: float, width: float, action: String, enabled: bool, color: Color, y: float = 9.0) -> float:
	var rect: Rect2 = Rect2(Vector2(x, y), Vector2(width, 24.0))
	buttons.append({"rect": rect, "action": action, "enabled": enabled})
	draw_rect(rect, color if enabled else VisualStyle.COLOR_UI_BUTTON_DISABLED)
	draw_rect(rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	var text_color: Color = VisualStyle.COLOR_UI_TEXT if enabled else VisualStyle.COLOR_UI_TEXT_MUTED
	draw_string(font, Vector2(x + 9.0, y + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, width - 14.0, 13, text_color)
	return x + width + 6.0

# --- Inspector -------------------------------------------------------------

func draw_inspector(font: Font) -> void:
	var region: WorldMapData.Region = view.data.get_region(view.selected_region_id)
	if region == null:
		return
	var settlement: WorldMapData.Settlement = view.data.get_settlement(view.selected_settlement_id)
	var viewport_size: Vector2 = get_viewport_rect().size
	var x: float = viewport_size.x - INSPECTOR_WIDTH - INSPECTOR_MARGIN
	var top: float = TOP_BAR_HEIGHT + INSPECTOR_MARGIN
	var text_x: float = x + PADDING
	var text_width: float = INSPECTOR_WIDTH - PADDING * 2.0

	# Lay out first, then draw the frame behind the measured height.
	var lines: Array[Dictionary] = []
	if settlement != null:
		lines.append(line(settlement.name, 18, VisualStyle.COLOR_UI_TITLE))
		lines.append(line(describe_settlement(settlement), 13, VisualStyle.COLOR_UI_TEXT_NORMAL))
		lines.append(line("Population about " + format_population(settlement.population), 13, VisualStyle.COLOR_UI_TEXT_SOFT))
		lines.append(line(describe_allegiance(settlement.kingdom_id, settlement.is_capital), 13, allegiance_color(settlement.kingdom_id)))
		lines.append(spacer())
		lines.append(line("Region", 12, VisualStyle.COLOR_UI_SECTION_HEADER))
	lines.append(line(region.name, 16 if settlement != null else 18, VisualStyle.COLOR_UI_TITLE))
	lines.append(line(describe_control(region), 13, allegiance_color(region.owner_kingdom_id)))
	lines.append(line(region.climate, 13, VisualStyle.COLOR_UI_TEXT_NORMAL))
	lines.append(line(region.landscape + describe_water(region), 13, VisualStyle.COLOR_UI_TEXT_NORMAL))
	var residents: Array[WorldMapData.Settlement] = view.data.get_settlements_in_region(region.id)
	lines.append(spacer())
	lines.append(line("Settlements", 12, VisualStyle.COLOR_UI_SECTION_HEADER))
	if residents.is_empty():
		lines.append(line("None. Open frontier.", 13, VisualStyle.COLOR_UI_TEXT_MUTED))
	for resident: WorldMapData.Settlement in residents.slice(0, 6):
		var marker: String = " (capital)" if resident.is_capital else ""
		lines.append(line(resident.name + " - " + view.data.get_tier_name(resident.tier).to_lower() + marker, 13, VisualStyle.COLOR_UI_TEXT_SOFT))
	if residents.size() > 6:
		lines.append(line("and %d more" % (residents.size() - 6), 12, VisualStyle.COLOR_UI_TEXT_MUTED))

	var entry: Dictionary = view.get_region_entry_status(region)
	lines.append(spacer())
	var reason_lines: PackedStringArray = wrap_text(font, String(entry["reason"]), text_width, 12)
	var height: float = PADDING * 2.0 + 30.0 + reason_lines.size() * 15.0
	for entry_line: Dictionary in lines:
		height += float(entry_line["height"])

	var frame: Rect2 = Rect2(Vector2(x, top), Vector2(INSPECTOR_WIDTH, height))
	blocking_rects.append(frame)
	draw_rect(frame, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	draw_rect(frame, VisualStyle.COLOR_UI_OVERLAY_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)

	var y: float = top + PADDING
	for entry_line: Dictionary in lines:
		y += float(entry_line["height"])
		if String(entry_line["text"]) != "":
			draw_string(font, Vector2(text_x, y - 4.0), entry_line["text"], HORIZONTAL_ALIGNMENT_LEFT, text_width, int(entry_line["size"]), entry_line["color"])

	var allowed: bool = bool(entry["allowed"])
	draw_button(font, String(entry["button"]), text_x, text_width, "enter_region", allowed, VisualStyle.COLOR_UI_BUTTON_CONFIRM, y)
	y += 30.0
	for reason: String in reason_lines:
		y += 15.0
		draw_string(font, Vector2(text_x, y - 3.0), reason, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, VisualStyle.COLOR_UI_TEXT_MUTED)

func line(text: String, size: int, color: Color) -> Dictionary:
	return {"text": text, "size": size, "color": color, "height": float(size) + 6.0}

func spacer() -> Dictionary:
	return {"text": "", "size": 0, "color": Color.WHITE, "height": 6.0}

func describe_settlement(settlement: WorldMapData.Settlement) -> String:
	var text: String = view.data.get_tier_name(settlement.tier)
	if settlement.is_port:
		text += ", port"
	return text

func describe_allegiance(kingdom_id: int, is_capital: bool) -> String:
	var kingdom: WorldMapData.Kingdom = view.data.get_kingdom(kingdom_id)
	if kingdom == null:
		return "Independent"
	if is_capital:
		return "Capital of " + kingdom.name
	return "Kingdom of " + kingdom.name

func describe_control(region: WorldMapData.Region) -> String:
	var kingdom: WorldMapData.Kingdom = view.data.get_kingdom(region.owner_kingdom_id)
	if kingdom != null:
		return "Held by the Kingdom of " + kingdom.name
	if region.is_contested():
		var names: PackedStringArray = PackedStringArray()
		for claimant_id: int in region.claimant_kingdom_ids:
			names.append(view.data.get_kingdom(claimant_id).name)
		return "Contested frontier, claimed by " + " and ".join(names)
	return "Unclaimed frontier"

func describe_water(region: WorldMapData.Region) -> String:
	if region.has_river and region.has_coast:
		return ", river and coast"
	if region.has_river:
		return ", river"
	if region.has_coast:
		return ", coast"
	return ""

func allegiance_color(kingdom_id: int) -> Color:
	var kingdom: WorldMapData.Kingdom = view.data.get_kingdom(kingdom_id)
	if kingdom == null:
		return VisualStyle.COLOR_UI_TEXT_SOFT
	return kingdom.color.lightened(0.45)

static func format_population(population: int) -> String:
	if population >= 1000:
		return "%s,%03d" % [population / 1000, population % 1000]
	return str(population)

static func wrap_text(font: Font, text: String, width: float, size: int) -> PackedStringArray:
	var wrapped: PackedStringArray = PackedStringArray()
	var current: String = ""
	for word: String in text.split(" ", false):
		var candidate: String = word if current == "" else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and current != "":
			wrapped.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		wrapped.append(current)
	return wrapped

# --- Legend and tooltip ----------------------------------------------------

func draw_legend(font: Font) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var frame: Rect2 = Rect2(Vector2(INSPECTOR_MARGIN, viewport_size.y - LEGEND_SIZE.y - INSPECTOR_MARGIN), LEGEND_SIZE)
	blocking_rects.append(frame)
	draw_rect(frame, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	draw_rect(frame, VisualStyle.COLOR_UI_PANEL_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	var x: float = frame.position.x + 12.0
	var y: float = frame.position.y + 20.0
	draw_string(font, Vector2(x, y), "Legend", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 20.0
	var swatch_x: float = x + 34.0
	draw_line(Vector2(x, y - 4.0), Vector2(x + 26.0, y - 4.0), WorldMapStyle.COLOR_ROAD_MAJOR_CASING, 4.4)
	draw_line(Vector2(x, y - 4.0), Vector2(x + 26.0, y - 4.0), WorldMapStyle.COLOR_ROAD_MAJOR, 2.6)
	draw_string(font, Vector2(swatch_x, y), "Major route", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_SOFT)
	y += 18.0
	draw_line(Vector2(x, y - 4.0), Vector2(x + 26.0, y - 4.0), WorldMapStyle.COLOR_ROAD_REGIONAL.lightened(0.3), 1.8)
	draw_string(font, Vector2(swatch_x, y), "Regional road", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_SOFT)
	y += 18.0
	draw_dashed_line(Vector2(x, y - 4.0), Vector2(x + 26.0, y - 4.0), WorldMapStyle.COLOR_ROAD_LOCAL.lightened(0.35), 1.4, 4.0)
	draw_string(font, Vector2(swatch_x, y), "Local road", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_SOFT)
	y += 18.0
	draw_rect(Rect2(Vector2(x, y - 11.0), Vector2(26.0, 9.0)), Color(0.48, 0.17, 0.12, 0.5))
	draw_string(font, Vector2(swatch_x, y), "Contested (hatched)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_SOFT)
	y += 18.0
	draw_colored_polygon(PackedVector2Array([Vector2(x + 8.0, y - 13.0), Vector2(x + 22.0, y - 10.0), Vector2(x + 8.0, y - 6.0)]), WorldMapStyle.COLOR_SELECTED)
	draw_line(Vector2(x + 8.0, y - 14.0), Vector2(x + 8.0, y), VisualStyle.COLOR_UI_TEXT_SOFT, 1.2)
	draw_string(font, Vector2(swatch_x, y), "Pennant marks a capital", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_SOFT)
	y += 18.0
	draw_string(font, Vector2(x, y), "Ribbon color shows the kingdom", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, VisualStyle.COLOR_UI_TEXT_MUTED)

func draw_tooltip(font: Font) -> void:
	var mouse: Vector2 = get_local_mouse_position()
	if view.is_dragging or is_over_hud(mouse):
		return
	var text: String = ""
	var settlement: WorldMapData.Settlement = view.data.get_settlement(view.hovered_settlement_id)
	var region: WorldMapData.Region = view.data.get_region(view.hovered_region_id)
	if settlement != null:
		text = settlement.name + " - " + describe_allegiance(settlement.kingdom_id, settlement.is_capital)
	elif region != null:
		text = region.name + " - " + describe_control(region)
	if text == "":
		return
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13) + Vector2(16.0, 10.0)
	var tooltip_position: Vector2 = mouse + Vector2(16.0, 18.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	tooltip_position.x = minf(tooltip_position.x, viewport_size.x - size.x - 4.0)
	tooltip_position.y = minf(tooltip_position.y, viewport_size.y - size.y - 4.0)
	draw_rect(Rect2(tooltip_position, size), VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	draw_rect(Rect2(tooltip_position, size), VisualStyle.COLOR_UI_PANEL_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	draw_string(font, tooltip_position + Vector2(8.0, 18.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, VisualStyle.COLOR_UI_TEXT)
