class_name SidebarPainter
extends RefCounted

# Lays out the town sidebar's content (docs/TOWN_UI.md) into drawing primitives once, so a frame
# only draws them. Pages say what to show as blocks; this decides how it looks.
#
# Blocks are Dictionaries with a "kind":
#   heading   {text, note?}                             a section title, a short note on the right
#   status    {label, value, tone, detail?}              a labelled state with its tone's glyph
#   card      {title, tone?, tag?, lines?, muted?, buttons?, columns?, action?, selected?}
#   row       {label, value?, tone?, key?, action?, selected?}  one line: a catalog entry
#   text      {text, muted?, tone?}
#   buttons   {items: [{text, action, active?, toggle?, enabled?}], columns?}
#   expander  {id, title, blocks}                        its blocks show while its id is expanded
#   gap       {size}
#
# A tone is never shown by colour alone: each has its own glyph shape, and the words say it too.

const TONE_GOOD: String = "good"
const TONE_CAUTION: String = "caution"
const TONE_ALERT: String = "alert"
const TONE_INFO: String = "info"
const TONE_NEUTRAL: String = "neutral"

const BODY_SIZE: int = 14
const SMALL_SIZE: int = 12
const HEADING_SIZE: int = 12
const TITLE_SIZE: int = 15
const BODY_LINE: float = 18.0
const SMALL_LINE: float = 15.0
const BUTTON_HEIGHT: float = 26.0
const BUTTON_GAP: float = 5.0
const CARD_PADDING: float = 10.0
const CARD_ACCENT: float = 3.0
const BLOCK_GAP: float = 8.0
const STATUS_LABEL_WIDTH: float = 92.0
const INDENT: float = 18.0

const COLOR_CARD: Color = Color(0.145, 0.155, 0.135)
const COLOR_CARD_SELECTED: Color = Color(0.19, 0.20, 0.15)
const COLOR_CARD_BORDER: Color = Color(0.25, 0.27, 0.23)
const COLOR_HEADING: Color = Color(0.86, 0.78, 0.52)
const COLOR_HEADING_RULE: Color = Color(0.30, 0.30, 0.25)
const COLOR_TITLE: Color = Color(1.0, 0.95, 0.78)
const COLOR_TEXT: Color = Color(0.90, 0.90, 0.83)
const COLOR_MUTED: Color = Color(0.66, 0.67, 0.60)
const COLOR_BUTTON: Color = Color(0.20, 0.22, 0.19)
const COLOR_BUTTON_HOVER: Color = Color(0.26, 0.28, 0.23)
const COLOR_BUTTON_ACTIVE: Color = Color(0.27, 0.33, 0.22)
const COLOR_BUTTON_BORDER: Color = Color(0.40, 0.42, 0.36)
const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.05)

const TONE_COLORS: Dictionary = {
	TONE_GOOD: Color(0.56, 0.84, 0.46),
	TONE_CAUTION: Color(0.95, 0.77, 0.32),
	TONE_ALERT: Color(1.0, 0.47, 0.38),
	TONE_INFO: Color(0.62, 0.78, 0.95),
	TONE_NEUTRAL: Color(0.68, 0.70, 0.62),
}

var font: Font = ThemeDB.fallback_font

static func tone_color(tone: String) -> Color:
	return TONE_COLORS.get(tone, TONE_COLORS[TONE_NEUTRAL])

# --- Layout ---------------------------------------------------------------------------------------

# Primitives for `blocks` laid out from y down in a column x..x+width: {"prims": Array, "height"}.
# Primitives: rect {rect, color}, frame {rect, color}, text {pos, text, size, color, width},
# glyph {center, tone}, chevron {center, open, color}, and hit {rect, action, style, ...} for
# what a click answers (buttons draw themselves; rows and cards only light up on hover).
func layout(blocks: Array, x: float, y: float, width: float, expanded: Dictionary) -> Dictionary:
	var prims: Array = []
	var top: float = y
	for block: Dictionary in blocks:
		y = layout_block(prims, block, x, y, width, expanded)
	return {"prims": prims, "height": y - top}

func layout_block(prims: Array, block: Dictionary, x: float, y: float, width: float, expanded: Dictionary) -> float:
	match str(block.get("kind", "")):
		"heading":
			return layout_heading(prims, block, x, y, width)
		"status":
			return layout_status(prims, block, x, y, width)
		"card":
			return layout_card(prims, block, x, y, width)
		"row":
			return layout_row(prims, block, x, y, width)
		"text":
			var size: int = SMALL_SIZE if block.get("muted", false) else BODY_SIZE
			var color: Color = COLOR_MUTED if block.get("muted", false) else (tone_color(block["tone"]) if block.has("tone") else COLOR_TEXT)
			return add_wrapped(prims, str(block["text"]), x, y, width, size, color) + BLOCK_GAP * 0.5
		"buttons":
			return layout_buttons(prims, block["items"], int(block.get("columns", 1)), x, y, width) + BLOCK_GAP
		"expander":
			return layout_expander(prims, block, x, y, width, expanded)
		"gap":
			return y + float(block.get("size", BLOCK_GAP))
	return y

func layout_heading(prims: Array, block: Dictionary, x: float, y: float, width: float) -> float:
	y += 8.0
	var note: String = str(block.get("note", ""))
	var note_width: float = text_width(note, SMALL_SIZE) if note != "" else 0.0
	prims.append({"p": "text", "pos": Vector2(x, y + 12.0), "text": str(block["text"]).to_upper(), "size": HEADING_SIZE, "color": COLOR_HEADING, "width": width - note_width - 8.0})
	if note != "":
		prims.append({"p": "text", "pos": Vector2(x + width - note_width, y + 12.0), "text": note, "size": SMALL_SIZE, "color": COLOR_MUTED, "width": note_width + 2.0})
	prims.append({"p": "rect", "rect": Rect2(x, y + 18.0, width, 1.0), "color": COLOR_HEADING_RULE})
	return y + 26.0

func layout_status(prims: Array, block: Dictionary, x: float, y: float, width: float) -> float:
	var tone: String = str(block.get("tone", TONE_NEUTRAL))
	prims.append({"p": "glyph", "center": Vector2(x + 6.0, y + 12.0), "tone": tone})
	prims.append({"p": "text", "pos": Vector2(x + INDENT, y + 14.0), "text": str(block["label"]), "size": BODY_SIZE, "color": COLOR_MUTED, "width": STATUS_LABEL_WIDTH - 4.0})
	var value_x: float = x + INDENT + STATUS_LABEL_WIDTH
	var value_color: Color = tone_color(tone) if tone == TONE_ALERT or tone == TONE_CAUTION else COLOR_TEXT
	y = add_wrapped(prims, str(block["value"]), value_x, y, width - INDENT - STATUS_LABEL_WIDTH, BODY_SIZE, value_color)
	var detail: String = str(block.get("detail", ""))
	if detail != "":
		y = add_wrapped(prims, detail, value_x, y - 2.0, width - INDENT - STATUS_LABEL_WIDTH, SMALL_SIZE, COLOR_MUTED)
	return y + 3.0

func layout_card(prims: Array, block: Dictionary, x: float, y: float, width: float) -> float:
	var tone: String = str(block.get("tone", ""))
	var content: Array = []
	var inner_x: float = x + CARD_PADDING + (CARD_ACCENT if tone != "" else 0.0)
	var inner_width: float = width - (inner_x - x) - CARD_PADDING
	var cy: float = y + CARD_PADDING - 2.0
	var tag: String = str(block.get("tag", ""))
	var tag_width: float = text_width(tag, SMALL_SIZE) if tag != "" else 0.0
	var title_x: float = inner_x
	if tone != "":
		content.append({"p": "glyph", "center": Vector2(inner_x + 6.0, cy + 11.0), "tone": tone})
		title_x += INDENT
	for line: String in wrap_text(str(block.get("title", "")), inner_width - (title_x - inner_x) - tag_width - 8.0, TITLE_SIZE):
		content.append({"p": "text", "pos": Vector2(title_x, cy + 15.0), "text": line, "size": TITLE_SIZE, "color": COLOR_TITLE, "width": inner_width - (title_x - inner_x)})
		cy += BODY_LINE + 1.0
	if tag != "":
		content.append({"p": "text", "pos": Vector2(inner_x + inner_width - tag_width, y + CARD_PADDING + 12.0), "text": tag, "size": SMALL_SIZE, "color": tone_color(tone) if tone != "" else COLOR_MUTED, "width": tag_width + 2.0})
	for line: String in block.get("lines", []):
		cy = add_wrapped(content, line, inner_x, cy, inner_width, BODY_SIZE - 1, COLOR_TEXT)
	for line: String in block.get("muted", []):
		cy = add_wrapped(content, line, inner_x, cy, inner_width, SMALL_SIZE, COLOR_MUTED)
	var buttons: Array = block.get("buttons", [])
	if not buttons.is_empty():
		cy = layout_buttons(content, buttons, int(block.get("columns", 1)), inner_x, cy + 4.0, inner_width)
	var rect: Rect2 = Rect2(x, y, width, cy - y + CARD_PADDING - 2.0)
	prims.append({"p": "rect", "rect": rect, "color": COLOR_CARD_SELECTED if block.get("selected", false) else COLOR_CARD})
	prims.append({"p": "frame", "rect": rect, "color": tone_color(tone).darkened(0.35) if block.get("selected", false) and tone != "" else COLOR_CARD_BORDER})
	if tone != "":
		prims.append({"p": "rect", "rect": Rect2(x, y, CARD_ACCENT, rect.size.y), "color": tone_color(tone).darkened(0.15)})
	# The card's own click goes in before its buttons, which are found first (hits are tested last to first).
	if block.has("action"):
		prims.append({"p": "hit", "rect": rect, "action": block["action"], "style": "row"})
	prims.append_array(content)
	return rect.end.y + BLOCK_GAP

func layout_row(prims: Array, block: Dictionary, x: float, y: float, width: float) -> float:
	var rect: Rect2 = Rect2(x - 4.0, y, width + 8.0, 24.0)
	if block.get("selected", false):
		prims.append({"p": "rect", "rect": rect, "color": COLOR_BUTTON_ACTIVE})
		prims.append({"p": "frame", "rect": rect, "color": COLOR_BUTTON_BORDER})
	if block.has("action"):
		prims.append({"p": "hit", "rect": rect, "action": block["action"], "style": "row"})
	var right: float = x + width
	var key: String = str(block.get("key", ""))
	if key != "":
		var key_rect: Rect2 = Rect2(right - 20.0, y + 4.0, 20.0, 16.0)
		prims.append({"p": "frame", "rect": key_rect, "color": COLOR_BUTTON_BORDER})
		prims.append({"p": "text", "pos": Vector2(key_rect.position.x, y + 17.0), "text": key, "size": SMALL_SIZE, "color": COLOR_MUTED, "width": 20.0, "align": HORIZONTAL_ALIGNMENT_CENTER})
		right -= 26.0
	var value: String = str(block.get("value", ""))
	if value != "":
		var value_width: float = minf(text_width(value, SMALL_SIZE), width * 0.5)
		prims.append({"p": "text", "pos": Vector2(right - value_width, y + 17.0), "text": value, "size": SMALL_SIZE, "color": COLOR_MUTED, "width": value_width + 1.0})
		right -= value_width + 8.0
	var label_x: float = x
	if block.has("tone"):
		prims.append({"p": "glyph", "center": Vector2(x + 6.0, y + 12.0), "tone": block["tone"]})
		label_x += INDENT
	prims.append({"p": "text", "pos": Vector2(label_x, y + 17.0), "text": str(block["label"]), "size": BODY_SIZE - 1, "color": COLOR_TITLE if block.get("selected", false) else COLOR_TEXT, "width": right - label_x})
	return y + 26.0

func layout_buttons(prims: Array, items: Array, columns: int, x: float, y: float, width: float) -> float:
	columns = maxi(1, columns)
	var button_width: float = (width - BUTTON_GAP * (columns - 1)) / columns
	for index in range(items.size()):
		var item: Dictionary = items[index]
		var column: int = index % columns
		if column == 0 and index > 0:
			y += BUTTON_HEIGHT + BUTTON_GAP
		var rect: Rect2 = Rect2(x + column * (button_width + BUTTON_GAP), y, button_width, BUTTON_HEIGHT)
		prims.append({"p": "hit", "rect": rect, "action": item.get("action", {}), "style": "button", "text": str(item["text"]), "active": item.get("active", false), "toggle": item.get("toggle", false), "enabled": item.get("enabled", true)})
	return y + BUTTON_HEIGHT + 2.0 if not items.is_empty() else y

func layout_expander(prims: Array, block: Dictionary, x: float, y: float, width: float, expanded: Dictionary) -> float:
	var id: String = str(block["id"])
	var open: bool = expanded.get(id, false)
	var rect: Rect2 = Rect2(x - 4.0, y, width + 8.0, 24.0)
	prims.append({"p": "hit", "rect": rect, "action": {"action": "toggle_expand", "id": id}, "style": "row"})
	prims.append({"p": "chevron", "center": Vector2(x + 5.0, y + 12.0), "open": open, "color": COLOR_HEADING})
	prims.append({"p": "text", "pos": Vector2(x + INDENT, y + 16.0), "text": str(block["title"]), "size": BODY_SIZE - 1, "color": COLOR_HEADING, "width": width - INDENT})
	y += 26.0
	if not open:
		return y + 2.0
	var top: float = y
	for child: Dictionary in block["blocks"]:
		y = layout_block(prims, child, x + 10.0, y, width - 10.0, expanded)
	prims.append({"p": "rect", "rect": Rect2(x + 2.0, top, 1.0, maxf(0.0, y - top - 4.0)), "color": COLOR_HEADING_RULE})
	return y + 4.0

# Wrapped text from y; returns the y below it.
func add_wrapped(prims: Array, text: String, x: float, y: float, width: float, size: int, color: Color) -> float:
	var line_height: float = BODY_LINE if size >= BODY_SIZE - 1 else SMALL_LINE
	for line: String in wrap_text(text, width, size):
		prims.append({"p": "text", "pos": Vector2(x, y + line_height - 4.0), "text": line, "size": size, "color": color, "width": width})
		y += line_height
	return y

func wrap_text(text: String, width: float, size: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			var candidate: String = word if line == "" else line + " " + word
			if line != "" and text_width(candidate, size) > width:
				lines.append(line)
				line = word
			else:
				line = candidate
		lines.append(line)
	return lines

func text_width(text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x

# --- Drawing --------------------------------------------------------------------------------------

# Draws what lies in [visible_top, visible_bottom] after moving everything up by `scroll`.
func draw(canvas: CanvasItem, prims: Array, scroll: float, visible_top: float, visible_bottom: float, hover: Vector2) -> void:
	var offset: Vector2 = Vector2(0.0, -scroll)
	for prim: Dictionary in prims:
		match str(prim["p"]):
			"rect":
				var rect: Rect2 = Rect2(prim["rect"].position + offset, prim["rect"].size)
				if rect.end.y >= visible_top and rect.position.y <= visible_bottom:
					canvas.draw_rect(rect, prim["color"])
			"frame":
				var rect: Rect2 = Rect2(prim["rect"].position + offset, prim["rect"].size)
				if rect.end.y >= visible_top and rect.position.y <= visible_bottom:
					canvas.draw_rect(rect, prim["color"], false, 1.0)
			"text":
				var pos: Vector2 = prim["pos"] + offset
				if pos.y >= visible_top and pos.y - 16.0 <= visible_bottom:
					canvas.draw_string(font, pos, prim["text"], prim.get("align", HORIZONTAL_ALIGNMENT_LEFT), prim["width"], prim["size"], prim["color"])
			"glyph":
				var center: Vector2 = prim["center"] + offset
				if center.y >= visible_top - 8.0 and center.y <= visible_bottom + 8.0:
					draw_glyph(canvas, str(prim["tone"]), center)
			"chevron":
				var center: Vector2 = prim["center"] + offset
				if center.y >= visible_top - 8.0 and center.y <= visible_bottom + 8.0:
					draw_chevron(canvas, center, prim["open"], prim["color"])
			"hit":
				var rect: Rect2 = Rect2(prim["rect"].position + offset, prim["rect"].size)
				if rect.end.y < visible_top or rect.position.y > visible_bottom:
					continue
				var hovered: bool = rect.has_point(hover) and hover.y >= visible_top and hover.y <= visible_bottom
				if str(prim["style"]) == "button":
					draw_button(canvas, rect, prim, hovered)
				elif hovered:
					canvas.draw_rect(rect, COLOR_HOVER)

func draw_button(canvas: CanvasItem, rect: Rect2, prim: Dictionary, hovered: bool) -> void:
	var enabled: bool = prim.get("enabled", true)
	var active: bool = prim.get("active", false)
	var background: Color = COLOR_BUTTON_ACTIVE if active else COLOR_BUTTON
	if hovered and enabled:
		background = background.lightened(0.12)
	canvas.draw_rect(rect, background)
	canvas.draw_rect(rect, COLOR_BUTTON_BORDER if enabled else COLOR_CARD_BORDER, false, 1.0)
	var text_x: float = rect.position.x + 8.0
	if prim.get("toggle", false):
		# A box that is ticked while the toggle is on: the state reads without colour.
		var box: Rect2 = Rect2(rect.position + Vector2(8.0, (rect.size.y - 12.0) * 0.5), Vector2(12.0, 12.0))
		canvas.draw_rect(box, COLOR_TEXT if enabled else COLOR_MUTED, false, 1.0)
		if active:
			canvas.draw_rect(box.grow(-3.0), TONE_COLORS[TONE_GOOD])
		text_x += 18.0
	var color: Color = COLOR_TEXT if enabled else COLOR_MUTED.darkened(0.2)
	canvas.draw_string(font, Vector2(text_x, rect.position.y + rect.size.y * 0.5 + 5.0), prim["text"], HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - text_x - 6.0, BODY_SIZE - 1, color)

# Each tone has its own shape: a dot for good, a triangle for caution, a diamond for alert, a ring
# for information, a dash for neutral.
static func draw_glyph(canvas: CanvasItem, tone: String, center: Vector2) -> void:
	var color: Color = tone_color(tone)
	match tone:
		TONE_GOOD:
			canvas.draw_circle(center, 4.5, color)
		TONE_CAUTION:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -5.5), center + Vector2(5.5, 4.5), center + Vector2(-5.5, 4.5)]), color)
		TONE_ALERT:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -6.0), center + Vector2(6.0, 0.0), center + Vector2(0.0, 6.0), center + Vector2(-6.0, 0.0)]), color)
		TONE_INFO:
			canvas.draw_arc(center, 4.5, 0.0, TAU, 16, color, 1.6)
		_:
			canvas.draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), color, 2.0)

static func draw_chevron(canvas: CanvasItem, center: Vector2, open: bool, color: Color) -> void:
	if open:
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-4.5, -2.5), center + Vector2(4.5, -2.5), center + Vector2(0.0, 3.5)]), color)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-2.5, -4.5), center + Vector2(3.5, 0.0), center + Vector2(-2.5, 4.5)]), color)

# The action of the last hit under `point` (in layout coordinates), or {}.
static func hit_test(prims: Array, point: Vector2) -> Dictionary:
	for index in range(prims.size() - 1, -1, -1):
		var prim: Dictionary = prims[index]
		if str(prim["p"]) != "hit" or not (prim["rect"] as Rect2).has_point(point):
			continue
		if not prim.get("enabled", true):
			return {"action": ""}
		return prim["action"]
	return {}
