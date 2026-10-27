class_name GameMenu
extends Control

# The start menu and the in-game menu: continue, new world, save, load, quit. It only shows
# pages and reports choices; scripts/app.gd acts on them. Built from Godot controls (unlike the
# hand-drawn game panels) because it needs a text field, a scrolling list, and keyboard focus.

signal continue_requested(path: String)
signal new_world_requested
signal load_requested(path: String)
signal save_requested(slot_name: String)
signal resume_requested
signal quit_to_start_requested
signal quit_requested

const PANEL_WIDTH: float = 900.0
const LIST_HEIGHT: float = 260.0
const BACKDROP_IN_GAME: Color = Color(0.0, 0.0, 0.0, 0.55)

var store: SaveStore
# Offered as the name of a new save.
var suggested_save_name: String = ""
# Whether a game is running behind the menu: Back and Escape return to the pause page then.
var in_game: bool = false
var backdrop: ColorRect
var content: VBoxContainer
# Escape goes back to this page (null: resume the game).
var back_action: Callable = Callable()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = make_theme()
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

func setup(save_store: SaveStore) -> void:
	store = save_store

# --- Pages -------------------------------------------------------------------------------------

func show_start() -> void:
	in_game = false
	open_page(VisualStyle.COLOR_UI_BACKGROUND, Callable())
	add_title(ProjectSettings.get_setting("application/config/name", "New Game"))
	var latest: Dictionary = store.latest()
	var continue_button: Button = add_button("Continue", func() -> void: continue_requested.emit(latest["path"]))
	if latest.is_empty():
		continue_button.disabled = true
	else:
		add_note(describe(latest))
	var new_button: Button = add_button("New world", new_world_requested.emit)
	var load_button: Button = add_button("Load game", show_load)
	load_button.disabled = latest.is_empty()
	add_button("Quit", quit_requested.emit)
	(new_button if latest.is_empty() else continue_button).grab_focus()

func show_pause() -> void:
	in_game = true
	open_page(BACKDROP_IN_GAME, resume_requested.emit)
	add_title("Paused")
	add_button("Resume", resume_requested.emit).grab_focus()
	add_button("Save game", show_save)
	add_button("Load game", show_load).disabled = store.list().is_empty()
	add_button("Quit to start menu", quit_to_start_requested.emit)
	add_button("Quit game", quit_requested.emit)
	add_note("Leaving or quitting saves to the autosave first.")

func show_save() -> void:
	open_page(BACKDROP_IN_GAME, show_pause)
	add_title("Save game")
	var name_field: LineEdit = LineEdit.new()
	name_field.placeholder_text = "Name of the save"
	name_field.text = suggested_save_name
	name_field.max_length = 48
	content.add_child(name_field)
	var saves: ItemList = add_save_list(false)
	add_note("Pick a save to overwrite it, or type a new name.")
	var row: HBoxContainer = add_row()
	var save_button: Button = add_button("Save", func() -> void: save_requested.emit(name_field.text.strip_edges()), row)
	add_button("Back", show_pause, row)
	var refresh: Callable = func(text: String) -> void:
		save_button.disabled = text.strip_edges() == ""
		save_button.text = "Overwrite" if FileAccess.file_exists(store.slot_path(text)) else "Save"
	var submit: Callable = func(_text: String) -> void:
		if not save_button.disabled:
			save_button.pressed.emit()
	var pick: Callable = func(index: int) -> void:
		name_field.text = saves.get_item_metadata(index)["name"]
		refresh.call(name_field.text)
	name_field.text_changed.connect(refresh)
	name_field.text_submitted.connect(submit)
	saves.item_selected.connect(pick)
	refresh.call(name_field.text)
	name_field.grab_focus()
	name_field.select_all()

func show_load() -> void:
	var back: Callable = show_pause if in_game else show_start
	open_page(BACKDROP_IN_GAME if in_game else VisualStyle.COLOR_UI_BACKGROUND, back)
	add_title("Load game")
	var saves: ItemList = add_save_list(true)
	if in_game:
		add_note("Progress since the last save will be lost.")
	var row: HBoxContainer = add_row()
	var load_button: Button = add_button("Load", func() -> void: load_requested.emit(selected_path(saves)), row)
	var delete_button: Button = add_button("Delete", func() -> void: confirm_delete(saves.get_item_metadata(saves.get_selected_items()[0])), row)
	add_button("Back", back, row)
	var refresh: Callable = func() -> void:
		load_button.disabled = not saves.is_anything_selected()
		delete_button.disabled = not saves.is_anything_selected()
	saves.item_selected.connect(func(_index: int) -> void: refresh.call())
	saves.item_activated.connect(func(index: int) -> void: load_requested.emit(saves.get_item_metadata(index)["path"]))
	if saves.item_count > 0:
		saves.select(0)
		saves.grab_focus()
	refresh.call()

func confirm_delete(header: Dictionary) -> void:
	var back: Callable = show_load
	open_page(BACKDROP_IN_GAME if in_game else VisualStyle.COLOR_UI_BACKGROUND, back)
	add_title("Delete save?")
	add_note(describe(header))
	var row: HBoxContainer = add_row()
	var delete: Callable = func() -> void:
		store.delete(header["path"])
		show_load()
	add_button("Delete", delete, row).add_theme_stylebox_override("normal", button_box(VisualStyle.COLOR_UI_BUTTON_DANGER))
	add_button("Keep it", back, row).grab_focus()

func show_message(text: String, then: Callable) -> void:
	open_page(BACKDROP_IN_GAME if in_game else VisualStyle.COLOR_UI_BACKGROUND, then)
	add_note(text)
	add_button("OK", then).grab_focus()

func show_busy(text: String) -> void:
	open_page(VisualStyle.COLOR_UI_BACKGROUND, Callable())
	add_title(text)

func hide_menu() -> void:
	visible = false

# Escape: back one page, or out of the menu.
func go_back() -> void:
	if back_action.is_valid():
		back_action.call()

# --- Building blocks ---------------------------------------------------------------------------

func open_page(backdrop_color: Color, back: Callable) -> void:
	visible = true
	backdrop.color = backdrop_color
	back_action = back
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()

func add_title(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", VisualStyle.COLOR_UI_TITLE)
	content.add_child(label)

func add_note(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", VisualStyle.COLOR_UI_TEXT_MUTED)
	content.add_child(label)

func add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	return row

func add_button(text: String, action: Callable, parent: Container = null) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0 if parent != null else 0.0, 36.0)
	button.pressed.connect(action)
	(parent if parent != null else content).add_child(button)
	return button

# Saved games, newest first; each item's metadata is its header. The autosave is offered for
# loading but not as a name to save under.
func add_save_list(include_autosave: bool) -> ItemList:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	for header: Dictionary in store.list():
		if not include_autosave and header["name"] == SaveStore.AUTOSAVE_SLOT:
			continue
		var index: int = list.add_item(describe(header))
		list.set_item_metadata(index, header)
	content.add_child(list)
	return list

func selected_path(list: ItemList) -> String:
	return list.get_item_metadata(list.get_selected_items()[0])["path"]

static func describe(header: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray([String(header["name"]), String(header["place"]), String(header["date"])])
	if int(header.get("population", 0)) > 0:
		parts.append("%d people" % int(header["population"]))
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var saved: String = Time.get_datetime_string_from_unix_time(int(header["saved_unix"]) + bias_seconds, true)
	parts.append("saved " + saved.replace("T", " ").left(16))
	return "  |  ".join(parts)

# --- Look ----------------------------------------------------------------------------------------

static func make_theme() -> Theme:
	var menu_theme: Theme = Theme.new()
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = VisualStyle.COLOR_UI_POPUP_BACKGROUND
	panel.border_color = VisualStyle.COLOR_UI_OVERLAY_BORDER
	panel.set_border_width_all(2)
	menu_theme.set_stylebox("panel", "PanelContainer", panel)
	menu_theme.set_stylebox("normal", "Button", button_box(VisualStyle.COLOR_UI_BUTTON_BACKGROUND))
	menu_theme.set_stylebox("hover", "Button", button_box(VisualStyle.COLOR_UI_BUTTON_ACTIVE))
	menu_theme.set_stylebox("pressed", "Button", button_box(VisualStyle.COLOR_UI_BUTTON_CONFIRM))
	menu_theme.set_stylebox("focus", "Button", focus_box())
	menu_theme.set_stylebox("disabled", "Button", button_box(VisualStyle.COLOR_UI_BUTTON_DISABLED))
	menu_theme.set_color("font_color", "Button", VisualStyle.COLOR_UI_TEXT)
	menu_theme.set_color("font_disabled_color", "Button", VisualStyle.COLOR_UI_TEXT_MUTED * Color(1, 1, 1, 0.6))
	menu_theme.set_color("font_color", "Label", VisualStyle.COLOR_UI_TEXT)
	menu_theme.set_stylebox("panel", "ItemList", button_box(VisualStyle.COLOR_UI_PANEL_BACKGROUND))
	menu_theme.set_stylebox("selected", "ItemList", button_box(VisualStyle.COLOR_UI_BUTTON_ACTIVE))
	menu_theme.set_stylebox("selected_focus", "ItemList", button_box(VisualStyle.COLOR_UI_BUTTON_ACTIVE))
	menu_theme.set_color("font_color", "ItemList", VisualStyle.COLOR_UI_TEXT_NORMAL)
	menu_theme.set_stylebox("normal", "LineEdit", button_box(VisualStyle.COLOR_UI_PANEL_BACKGROUND))
	menu_theme.set_stylebox("focus", "LineEdit", focus_box())
	menu_theme.set_color("font_color", "LineEdit", VisualStyle.COLOR_UI_TEXT)
	return menu_theme

static func button_box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = VisualStyle.COLOR_UI_OPTION_BORDER
	box.set_border_width_all(1)
	box.set_content_margin_all(8)
	return box

static func focus_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = VisualStyle.COLOR_UI_OVERLAY_BORDER
	box.set_border_width_all(2)
	return box
