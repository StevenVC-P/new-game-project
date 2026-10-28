class_name TownStatusBar
extends RefCounted

# The town's at-a-glance status in the top bar (owner request, 2026-10-28): people, free homes,
# and labor always; alerts only while they matter (hunger, families thinking of leaving, bandits
# on the road, a trader in town). Each chip is a small drawn symbol, a short number, and a colour
# for its state, with a line or two of detail on hover. Stores stay in the sidebar.

const ICON_SIZE: float = 16.0
const CHIP_HEIGHT: float = 24.0
const CHIP_PADDING: float = 7.0
const CHIP_GAP: float = 6.0

const COLOR_OK: Color = Color(0.82, 0.88, 0.96)
const COLOR_ALERT: Color = Color(1.0, 0.42, 0.36)
const COLOR_CAUTION: Color = Color(0.98, 0.78, 0.32)
const COLOR_GOOD: Color = Color(0.95, 0.86, 0.45)
const COLOR_CHIP: Color = Color(0.16, 0.17, 0.15)
const COLOR_TOOLTIP: Color = Color(0.08, 0.09, 0.08, 0.96)
const COLOR_BORDER: Color = Color(0.48, 0.50, 0.44)
const COLOR_TEXT: Color = Color(0.94, 0.94, 0.84)

# The chips for a town, in order: {"icon", "text", "color", "tooltip": Array[String]}.
static func get_chips(city: City) -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	var resources: Dictionary = city.resources
	var households: int = city.households.size()
	var people: int = city.get_total_population()
	chips.append({"icon": "people", "text": "%d · %d" % [households, people], "color": COLOR_OK, "tooltip": ["%d households, %d people" % [households, people]]})
	var free_homes: int = city.get_empty_house_building_ids().size()
	var blocker: String = HouseholdMigration.get_arrival_blocker(city)
	chips.append({"icon": "house", "text": "%d free" % free_homes, "color": COLOR_CAUTION if free_homes == 0 else COLOR_OK, "tooltip": ["Empty homes: %d (newcomers need one)" % free_homes, "Newcomers: " + HouseholdMigration.get_arrival_blocker_text(blocker)]})
	var labor: Dictionary = city.get_pressure_summary()["labor"]
	var labor_color: Color = COLOR_ALERT if str(labor.get("severity", "")) == "danger" else (COLOR_CAUTION if str(labor.get("severity", "")) == "warning" else COLOR_OK)
	chips.append({"icon": "labor", "text": "%d/%d" % [int(resources["assigned_workers"]), int(resources["total_labor_capacity"])], "color": labor_color, "tooltip": ["Labor: %s" % str(labor.get("status", "")), str(labor.get("detail", "")), "%d idle" % int(resources["idle_workers"])]})
	if resources["food_shortage"] == true:
		chips.append({"icon": "hunger", "text": "Hungry", "color": COLOR_ALERT, "tooltip": ["Food has run out: families are going hungry", "Hardship builds; newcomers stay away"]})
	var leaving: int = int(resources.get("households_considering_departure", 0))
	if leaving > 0:
		chips.append({"icon": "leaving", "text": "%d leaving?" % leaving, "color": COLOR_CAUTION, "tooltip": ["%d famil%s thinking of leaving" % [leaving, "y is" if leaving == 1 else "ies are"], "Ease food, housing, and crowding"]})
	if city.defense.is_band_coming():
		var days: int = maxi(0, city.defense.raid_day - city.construction.day)
		chips.append({"icon": "bandits", "text": "Bandits %dd" % days, "color": COLOR_ALERT, "tooltip": ["Bandits on the road: here in %d days" % days, "Band %d against guard %d (M: call the militia)" % [city.defense.raid_strength, city.defense.get_guard()]]})
	if city.trade.is_trader_here():
		var stay: int = city.trade.trader_until_day - city.construction.day + 1
		chips.append({"icon": "trader", "text": "Trader %dd" % stay, "color": COLOR_GOOD, "tooltip": ["A trader from %s is in town for %d more days" % [city.trade.partner_name, stay], "Trade in the sidebar's Trader section"]})
	return chips

static func get_chip_width(font: Font, font_size: int, chip: Dictionary) -> float:
	return CHIP_PADDING * 2.0 + ICON_SIZE + 5.0 + font.get_string_size(str(chip["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

# Draws chips from x while they fit before max_x (alerts come last, so the most important stay);
# returns each drawn chip's rect alongside it for hover.
static func draw_chips(canvas: CanvasItem, font: Font, font_size: int, chips: Array[Dictionary], x: float, baseline: float, max_x: float) -> Array[Dictionary]:
	var drawn: Array[Dictionary] = []
	for chip: Dictionary in chips:
		var width: float = get_chip_width(font, font_size, chip)
		if x + width > max_x:
			break
		var rect: Rect2 = Rect2(Vector2(x, baseline - 17.0), Vector2(width, CHIP_HEIGHT))
		canvas.draw_rect(rect, COLOR_CHIP)
		canvas.draw_rect(rect, Color(chip["color"]).darkened(0.35), false, 1.0)
		draw_icon(canvas, str(chip["icon"]), Rect2(rect.position + Vector2(CHIP_PADDING, (CHIP_HEIGHT - ICON_SIZE) * 0.5), Vector2(ICON_SIZE, ICON_SIZE)), chip["color"])
		canvas.draw_string(font, Vector2(x + CHIP_PADDING + ICON_SIZE + 5.0, baseline), str(chip["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, chip["color"])
		drawn.append({"rect": rect, "tooltip": chip["tooltip"]})
		x += width + CHIP_GAP
	return drawn

static func draw_tooltip(canvas: CanvasItem, font: Font, font_size: int, lines: Array, anchor: Vector2, viewport_width: float) -> void:
	var shown: Array[String] = []
	var width: float = 0.0
	for line in lines:
		if str(line) == "":
			continue
		shown.append(str(line))
		width = maxf(width, font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	if shown.is_empty():
		return
	var size: Vector2 = Vector2(width + 16.0, shown.size() * 18.0 + 10.0)
	var position: Vector2 = Vector2(minf(anchor.x, viewport_width - size.x - 8.0), anchor.y)
	canvas.draw_rect(Rect2(position, size), COLOR_TOOLTIP)
	canvas.draw_rect(Rect2(position, size), COLOR_BORDER, false, 1.0)
	for i in range(shown.size()):
		canvas.draw_string(font, position + Vector2(8.0, 19.0 + i * 18.0), shown[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, COLOR_TEXT)

# Small symbols drawn in a 16x16 box: no font glyphs, so they look the same everywhere.
static func draw_icon(c: CanvasItem, icon: String, r: Rect2, color: Color) -> void:
	var p: Vector2 = r.position
	var s: float = r.size.x
	match icon:
		"people":
			c.draw_circle(p + Vector2(s * 0.34, s * 0.3), s * 0.15, color)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.12, s * 0.95), p + Vector2(s * 0.2, s * 0.5), p + Vector2(s * 0.48, s * 0.5), p + Vector2(s * 0.56, s * 0.95)]), color)
			c.draw_circle(p + Vector2(s * 0.7, s * 0.4), s * 0.12, color.darkened(0.2))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.52, s * 0.95), p + Vector2(s * 0.58, s * 0.58), p + Vector2(s * 0.82, s * 0.58), p + Vector2(s * 0.9, s * 0.95)]), color.darkened(0.2))
		"house":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.08, s * 0.5), p + Vector2(s * 0.5, s * 0.12), p + Vector2(s * 0.92, s * 0.5)]), color)
			c.draw_rect(Rect2(p + Vector2(s * 0.2, s * 0.5), Vector2(s * 0.6, s * 0.42)), color)
			c.draw_rect(Rect2(p + Vector2(s * 0.43, s * 0.65), Vector2(s * 0.16, s * 0.27)), COLOR_CHIP)
		"labor":
			# A hammer.
			c.draw_line(p + Vector2(s * 0.25, s * 0.9), p + Vector2(s * 0.62, s * 0.38), color, s * 0.13)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.42, s * 0.18), p + Vector2(s * 0.62, s * 0.06), p + Vector2(s * 0.92, s * 0.48), p + Vector2(s * 0.72, s * 0.6)]), color)
		"hunger":
			# An empty bowl.
			c.draw_arc(p + Vector2(s * 0.5, s * 0.45), s * 0.38, 0.0, PI, 12, color, s * 0.12)
			c.draw_line(p + Vector2(s * 0.08, s * 0.45), p + Vector2(s * 0.92, s * 0.45), color, s * 0.1)
		"leaving":
			# A door and an arrow out of it.
			c.draw_rect(Rect2(p + Vector2(s * 0.08, s * 0.12), Vector2(s * 0.34, s * 0.78)), color, false, s * 0.09)
			c.draw_line(p + Vector2(s * 0.35, s * 0.5), p + Vector2(s * 0.92, s * 0.5), color, s * 0.11)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.98, s * 0.5), p + Vector2(s * 0.7, s * 0.28), p + Vector2(s * 0.7, s * 0.72)]), color)
		"bandits":
			# Crossed blades.
			c.draw_line(p + Vector2(s * 0.12, s * 0.12), p + Vector2(s * 0.88, s * 0.88), color, s * 0.11)
			c.draw_line(p + Vector2(s * 0.88, s * 0.12), p + Vector2(s * 0.12, s * 0.88), color, s * 0.11)
			c.draw_line(p + Vector2(s * 0.62, s * 0.78), p + Vector2(s * 0.78, s * 0.62), color, s * 0.16)
			c.draw_line(p + Vector2(s * 0.22, s * 0.62), p + Vector2(s * 0.38, s * 0.78), color, s * 0.16)
		"trader":
			# A tied sack.
			c.draw_circle(p + Vector2(s * 0.5, s * 0.62), s * 0.34, color)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.36, s * 0.32), p + Vector2(s * 0.5, s * 0.1), p + Vector2(s * 0.64, s * 0.32)]), color)
			c.draw_line(p + Vector2(s * 0.34, s * 0.32), p + Vector2(s * 0.66, s * 0.32), COLOR_CHIP, s * 0.08)
		_:
			c.draw_circle(r.get_center(), s * 0.3, color)
