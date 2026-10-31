class_name TownSidebar
extends Control

# The town view's right-hand panel (docs/TOWN_UI.md): pages under tabs (Overview, Families,
# Planning, Community), scrolling when they run long, with a footer that answers what the cursor
# or the tool in hand is doing. main.gd owns the game state: it hands this panel a context each
# frame, forwards mouse events, and carries out the actions a click returns. The panel keeps only
# its own view state (page, scroll, open sections, the family in focus).
#
# A page builds blocks from the town (scripts/ui/town_sidebar/*_page.gd); SidebarPainter lays
# them out. Pages are rebuilt when the day changes, after a click, and at least twice a second,
# not every frame. A later stage's pages (districts, institutions) join TABS.

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

const TAB_OVERVIEW: String = "overview"
const TAB_FAMILIES: String = "families"
const TAB_PLANNING: String = "planning"
const TAB_COMMUNITY: String = "community"
const TABS: Array[Dictionary] = [
	{"id": TAB_OVERVIEW, "title": "Overview", "page": preload("res://scripts/ui/town_sidebar/overview_page.gd")},
	{"id": TAB_FAMILIES, "title": "Families", "page": preload("res://scripts/ui/town_sidebar/families_page.gd")},
	{"id": TAB_PLANNING, "title": "Planning", "page": preload("res://scripts/ui/town_sidebar/planning_page.gd")},
	{"id": TAB_COMMUNITY, "title": "Community", "page": preload("res://scripts/ui/town_sidebar/community_page.gd")},
]

const HEADER_HEIGHT: float = 40.0
const PADDING: float = 14.0
const SCROLLBAR_WIDTH: float = 6.0
const SCROLL_STEP: float = 54.0
const REBUILD_MSEC: int = 500

const COLOR_BACKGROUND: Color = Color(0.095, 0.10, 0.09)
const COLOR_HEADER: Color = Color(0.12, 0.125, 0.11)
const COLOR_BORDER: Color = Color(0.30, 0.31, 0.27)
const COLOR_TAB_ACTIVE: Color = Color(0.86, 0.78, 0.52)
const COLOR_SCROLL_TRACK: Color = Color(1.0, 1.0, 1.0, 0.04)
const COLOR_SCROLL_THUMB: Color = Color(0.55, 0.55, 0.48, 0.7)

var painter: SidebarPainter = SidebarPainter.new()
var tab: String = TAB_OVERVIEW
var scroll_by_tab: Dictionary = {}
var expanded: Dictionary = {}
var focused_household_id: int = -1
var context: Dictionary = {}
var footer_blocks: Array = []

var prims: Array = []
var content_height: float = 0.0
var footer_prims: Array = []
var footer_height: float = 0.0
var attention_count: int = 0
# Every expander id on the current page, for expand_all.
var expander_ids: Array[String] = []

var dirty: bool = true
var built_day: int = -1
var built_msec: int = 0
var built_width: float = -1.0
var last_map_household_id: int = -1
var hover: Vector2 = Vector2(-1.0, -1.0)
var dragging_thumb: bool = false
var drag_offset: float = 0.0

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Below main.gd's own drawing, so its tooltips and popups stay on top of the panel.
	z_index = -1

# --- What main.gd calls ---------------------------------------------------------------------------

# Each frame in the town view: the town and the player's selection and tool ({"city",
# "map_household_id", "tool", "placing"}), and the footer's blocks.
func update(new_context: Dictionary, new_footer: Array) -> void:
	var city: City = new_context.get("city")
	if city != context.get("city") or new_context.get("tool") != context.get("tool") or new_context.get("placing") != context.get("placing"):
		dirty = true
	context = new_context
	# The map's selection leads: selecting a house on the map focuses its family here.
	var map_household: int = int(new_context.get("map_household_id", -1))
	if map_household != last_map_household_id:
		if map_household >= 0:
			focused_household_id = map_household
		elif focused_household_id == last_map_household_id:
			focused_household_id = -1
		last_map_household_id = map_household
		dirty = true
	if city != null and focused_household_id >= 0 and city.get_household_by_id(focused_household_id) == null:
		focused_household_id = -1
	footer_blocks = new_footer
	if city != null and (dirty or city.construction.day != built_day or Time.get_ticks_msec() - built_msec > REBUILD_MSEC or size.x != built_width):
		rebuild()
	layout_footer()
	queue_redraw()

func show_tab(id: String) -> void:
	if get_tab_index(id) < 0 or id == tab:
		return
	tab = id
	dirty = true
	dragging_thumb = false

# Next or previous tab (Tab and Shift+Tab).
func cycle_tab(step: int) -> void:
	show_tab(TABS[posmod(get_tab_index(tab) + step, TABS.size())]["id"])

func focus_household(household_id: int) -> void:
	focused_household_id = household_id
	dirty = true

func expand_all(open: bool) -> void:
	rebuild()
	for id: String in expander_ids:
		expanded[id] = open
	dirty = true

func scroll_to(y: float) -> void:
	scroll_by_tab[tab] = y
	clamp_scroll()

func get_scroll() -> float:
	return float(scroll_by_tab.get(tab, 0.0))

# A mouse button over the panel (position in main.gd's coordinates): {} when the panel does not
# take it; {"action": ""} when the panel handled it itself; otherwise the action for main.gd.
func handle_mouse_button(event: InputEventMouseButton, at: Vector2) -> Dictionary:
	var point: Vector2 = at - position
	if not event.pressed:
		if dragging_thumb and event.button_index == MOUSE_BUTTON_LEFT:
			dragging_thumb = false
			return {"action": ""}
		return {}
	if not visible or not Rect2(Vector2.ZERO, size).has_point(point):
		return {}
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			scroll_to(get_scroll() + SCROLL_STEP * (event.factor if event.factor > 0.0 else 1.0) * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0))
			queue_redraw()
			return {"action": ""}
		MOUSE_BUTTON_LEFT:
			return click(point)
	return {}

func handle_mouse_motion(at: Vector2) -> void:
	var point: Vector2 = at - position
	if dragging_thumb:
		var track: Rect2 = get_scroll_track()
		var thumb: Rect2 = get_scroll_thumb()
		var movable: float = maxf(1.0, track.size.y - thumb.size.y)
		scroll_to((point.y - drag_offset - track.position.y) / movable * get_max_scroll())
	if point != hover:
		hover = point
		queue_redraw()

# --- Building the page ----------------------------------------------------------------------------

func rebuild() -> void:
	var city: City = context.get("city")
	if city == null:
		return
	var page_context: Dictionary = context.duplicate()
	page_context["focused_household_id"] = focused_household_id
	var blocks: Array = (TABS[get_tab_index(tab)]["page"] as Script).call("build", page_context)
	var focused: Household = city.get_household_by_id(focused_household_id) if focused_household_id >= 0 else null
	if focused != null and tab != TAB_FAMILIES:
		blocks.push_front(get_focus_strip(city, focused))
	expander_ids.clear()
	collect_expanders(blocks)
	var laid: Dictionary = painter.layout(blocks, PADDING, HEADER_HEIGHT + 6.0, get_content_width(), expanded)
	prims = laid["prims"]
	content_height = float(laid["height"]) + 24.0
	attention_count = SidebarOverviewPage.get_attention(city).size()
	dirty = false
	built_day = city.construction.day
	built_msec = Time.get_ticks_msec()
	built_width = size.x
	clamp_scroll()

# The family in focus, while another page is shown: one line, and the way back to its card.
func get_focus_strip(city: City, household: Household) -> Dictionary:
	return {"kind": "card", "title": city.get_household_label(household.id), "tag": "selected", "lines": [SidebarFamiliesPage.sentence(SidebarFamiliesPage.describe_now(city, household))], "columns": 2, "buttons": [
		{"text": "Family details", "action": {"action": "show_tab", "tab": TAB_FAMILIES}},
		{"text": "Deselect", "action": {"action": "focus_household", "household": household.id}},
	]}

func collect_expanders(blocks: Array) -> void:
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "expander":
			expander_ids.append(str(block["id"]))
			collect_expanders(block["blocks"])

func layout_footer() -> void:
	footer_prims = []
	footer_height = 0.0
	if footer_blocks.is_empty():
		return
	var measured: Dictionary = painter.layout(footer_blocks, PADDING, 0.0, size.x - PADDING * 2.0, {})
	footer_height = float(measured["height"]) + 14.0
	footer_prims = painter.layout(footer_blocks, PADDING, size.y - footer_height + 8.0, size.x - PADDING * 2.0, {})["prims"]

func get_content_width() -> float:
	return size.x - PADDING * 2.0 - SCROLLBAR_WIDTH

func get_view_top() -> float:
	return HEADER_HEIGHT

func get_view_bottom() -> float:
	return size.y - footer_height

func get_max_scroll() -> float:
	return maxf(0.0, content_height + HEADER_HEIGHT - get_view_bottom())

func clamp_scroll() -> void:
	scroll_by_tab[tab] = clampf(get_scroll(), 0.0, get_max_scroll())

func get_tab_index(id: String) -> int:
	for index in range(TABS.size()):
		if TABS[index]["id"] == id:
			return index
	return -1

func get_tab_rect(index: int) -> Rect2:
	var width: float = size.x / TABS.size()
	return Rect2(index * width, 0.0, width, HEADER_HEIGHT)

func get_scroll_track() -> Rect2:
	return Rect2(size.x - SCROLLBAR_WIDTH - 4.0, get_view_top() + 4.0, SCROLLBAR_WIDTH, get_view_bottom() - get_view_top() - 8.0)

func get_scroll_thumb() -> Rect2:
	var track: Rect2 = get_scroll_track()
	var visible_share: float = clampf((get_view_bottom() - get_view_top()) / maxf(1.0, content_height), 0.1, 1.0)
	var height: float = track.size.y * visible_share
	var share: float = get_scroll() / get_max_scroll() if get_max_scroll() > 0.0 else 0.0
	return Rect2(track.position.x, track.position.y + (track.size.y - height) * share, SCROLLBAR_WIDTH, height)

# --- Clicks ---------------------------------------------------------------------------------------

func click(point: Vector2) -> Dictionary:
	if point.y < HEADER_HEIGHT:
		for index in range(TABS.size()):
			if get_tab_rect(index).has_point(point):
				show_tab(TABS[index]["id"])
		return {"action": ""}
	if get_max_scroll() > 0.0 and point.x >= get_scroll_track().position.x - 4.0 and point.y < get_view_bottom():
		var thumb: Rect2 = get_scroll_thumb()
		dragging_thumb = true
		drag_offset = point.y - thumb.position.y if thumb.has_point(point) else thumb.size.y * 0.5
		handle_mouse_motion(point + position)
		return {"action": ""}
	var action: Dictionary = {}
	if point.y >= get_view_bottom():
		action = SP.hit_test(footer_prims, point)
	else:
		action = SP.hit_test(prims, point + Vector2(0.0, get_scroll()))
	return apply_own_action(action)

# The panel's own actions (pages, open sections, the family in focus) happen here; the rest go to
# main.gd, and the page is rebuilt to show what they changed.
func apply_own_action(action: Dictionary) -> Dictionary:
	var name: String = str(action.get("action", ""))
	dirty = true
	match name:
		"":
			return {"action": ""}
		"show_tab":
			show_tab(str(action["tab"]))
			return {"action": ""}
		"toggle_expand":
			var id: String = str(action["id"])
			expanded[id] = not expanded.get(id, false)
			return {"action": ""}
		"focus_household":
			var household_id: int = int(action["household"])
			if focused_household_id == household_id:
				focused_household_id = -1
				return {"action": "select_household", "household": -1}
			focused_household_id = household_id
			return {"action": "select_household", "household": household_id, "focus_camera": false}
	return action

# --- Drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	if context.get("city") == null:
		return
	painter.draw(self, prims, get_scroll(), get_view_top(), get_view_bottom(), hover)
	if get_max_scroll() > 0.0:
		draw_rect(get_scroll_track(), COLOR_SCROLL_TRACK)
		draw_rect(get_scroll_thumb(), COLOR_SCROLL_THUMB.lightened(0.2) if dragging_thumb else COLOR_SCROLL_THUMB)
	draw_header()
	if not footer_prims.is_empty():
		var top: float = size.y - footer_height
		draw_rect(Rect2(0.0, top, size.x, footer_height), COLOR_HEADER)
		draw_rect(Rect2(0.0, top, size.x, 1.0), COLOR_BORDER)
		painter.draw(self, footer_prims, 0.0, top, size.y, hover)
	draw_rect(Rect2(0.0, 0.0, 1.0, size.y), COLOR_BORDER)

func draw_header() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, HEADER_HEIGHT), COLOR_HEADER)
	draw_rect(Rect2(0.0, HEADER_HEIGHT - 1.0, size.x, 1.0), COLOR_BORDER)
	var font: Font = painter.font
	# The largest size at which every title (and the badge) fits its tab with a little room.
	var font_size: int = 14
	while font_size > 10:
		var widest: float = 0.0
		for entry: Dictionary in TABS:
			widest = maxf(widest, font.get_string_size(entry["title"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
		if widest + 12.0 <= size.x / TABS.size():
			break
		font_size -= 1
	for index in range(TABS.size()):
		var rect: Rect2 = get_tab_rect(index)
		var id: String = TABS[index]["id"]
		var active: bool = id == tab
		if rect.has_point(hover) and not active:
			draw_rect(rect, Color(1.0, 1.0, 1.0, 0.04))
		var title: String = TABS[index]["title"]
		var badge: String = str(attention_count) if id == TAB_OVERVIEW and attention_count > 0 else ""
		var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var badge_width: float = 18.0 if badge != "" else 0.0
		var x: float = rect.position.x + (rect.size.x - title_width - badge_width) * 0.5
		draw_string(font, Vector2(x, 25.0), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, COLOR_TAB_ACTIVE if active else SP.COLOR_MUTED)
		if badge != "":
			# The count of things needing attention: the number reads without the colour.
			var center: Vector2 = Vector2(x + title_width + 11.0, 20.0)
			draw_circle(center, 8.0, SP.tone_color(SP.TONE_CAUTION).darkened(0.25))
			draw_string(font, center + Vector2(-8.0, 4.5), badge, HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, Color(0.08, 0.08, 0.07))
		if active:
			draw_rect(Rect2(rect.position.x + 8.0, HEADER_HEIGHT - 3.0, rect.size.x - 16.0, 3.0), COLOR_TAB_ACTIVE)

# --- Footer content -------------------------------------------------------------------------------

# The tool in hand: what it is, what it costs, and whether the hovered ground takes it.
static func make_tool_footer(tool_name: String, cost_text: String, message: String, tone: String) -> Array:
	return [
		{"kind": "status", "label": "Placing", "value": tool_name + (" · " + cost_text if cost_text != "" else ""), "tone": SP.TONE_INFO},
		{"kind": "status", "label": "Here", "value": message, "tone": tone},
		{"kind": "buttons", "columns": 2, "items": [{"text": "Stop (Esc)", "action": {"action": "stop_placing"}}, {"text": "Catalog (B)", "action": {"action": "open_build_menu"}}]},
	]

# The ground under the cursor, in words, from the town map's tile.
static func describe_ground(city: City, tile: Vector2i) -> String:
	if city == null or city.local_map.is_empty() or tile.y < 0 or tile.y >= city.local_map.size() or tile.x < 0 or tile.x >= (city.local_map[tile.y] as Array).size():
		return ""
	var data: Dictionary = city.local_map[tile.y][tile.x]
	var parts: Array[String] = []
	match str(data.get("type", "")):
		"water":
			parts.append("water" + (" (" + str(data["water_kind"]) + ")" if str(data.get("water_kind", "")) != "" else ""))
		"rough":
			parts.append("rough ground" + (", " + str(data["resource"]) if str(data.get("resource", "none")) != "none" else ""))
		_:
			if data.get("has_trees", false):
				parts.append("woods")
			parts.append("fertile land" if data.get("is_fertile", false) else "open land")
	if data.get("is_hill", false):
		parts.append("hillside")
	if data.get("has_road", false):
		parts.append("road")
	elif city.logistics != null and city.logistics.has_map():
		match city.logistics.get_tile_path_level(tile):
			TownLogistics.PATH_TRAIL:
				parts.append("trail")
			TownLogistics.PATH_WORN:
				parts.append("worn path")
	if city.woodland.marked.has(tile):
		parts.append("marked for clearing")
	if city.farmland.marked.has(tile):
		parts.append("marked for tilling")
	if city.influence.enabled and city.influence.is_work_ground(tile):
		parts.append("work ground")
	return ", ".join(parts)
