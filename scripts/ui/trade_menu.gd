class_name TradeMenu
extends RefCounted

var open_state: bool = false
var source_city_index: int = -1
var destination_city_index: int = -1
var selected_resource: String = "food"
var amount_per_tick: int = 1
var menu_rect: Rect2 = Rect2()
var menu_position: Vector2 = Vector2(260.0, 86.0)
var menu_size: Vector2 = Vector2(300.0, 286.0)
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var action_options: Array[Dictionary] = []
var pending_route_data: Dictionary = {}

func open(_cities: Array[City]):
	open_state = true
	source_city_index = -1
	destination_city_index = -1
	selected_resource = "food"
	amount_per_tick = 1
	pending_route_data.clear()

func close():
	open_state = false
	is_dragging = false
	source_city_index = -1
	destination_city_index = -1
	menu_rect = Rect2()
	action_options.clear()

func is_open() -> bool:
	return open_state

func handle_key_event(key_event: InputEventKey, cities: Array[City]) -> bool:
	if not key_event.pressed or key_event.echo:
		return false

	if key_event.keycode == KEY_T or key_event.physical_keycode == KEY_T:
		open(cities)
		return true

	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		if open_state:
			close()
			return true

	return false

func handle_mouse_button(mouse_event: InputEventMouseButton, mouse_pos: Vector2) -> bool:
	if not open_state:
		return false
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if not mouse_event.pressed:
		if is_dragging:
			is_dragging = false
			return true
		return false

	if get_header_rect().has_point(mouse_pos):
		is_dragging = true
		drag_offset = mouse_pos - menu_position
		return true

	return false

func handle_mouse_motion(mouse_pos: Vector2, viewport_size: Vector2) -> bool:
	if not open_state or not is_dragging:
		return false

	menu_position = mouse_pos - drag_offset
	clamp_to_viewport(viewport_size)
	return true

func handle_menu_click(mouse_pos: Vector2, cities: Array[City]) -> bool:
	for option_data: Dictionary in action_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		apply_action(option_data, cities)
		return true

	if menu_rect.has_point(mouse_pos):
		return true

	return false

func handle_city_selection(city_index: int):
	if city_index == -1:
		return

	if source_city_index == -1:
		source_city_index = city_index
	elif destination_city_index == -1 and city_index != source_city_index:
		destination_city_index = city_index
	elif city_index != source_city_index:
		destination_city_index = city_index

func apply_action(option_data: Dictionary, cities: Array[City]):
	var action: String = option_data["action"] as String

	if action == "cancel_trade_route":
		close()
	elif action == "select_trade_resource":
		selected_resource = option_data["resource"] as String
	elif action == "decrease_trade_amount":
		amount_per_tick = max(1, amount_per_tick - 1)
	elif action == "increase_trade_amount":
		amount_per_tick += 1
	elif action == "create_trade_route":
		try_confirm_route(cities)

func try_confirm_route(cities: Array[City]):
	if source_city_index < 0 or destination_city_index < 0:
		return
	if source_city_index >= cities.size() or destination_city_index >= cities.size():
		return
	if source_city_index == destination_city_index:
		return

	pending_route_data = {
		"source": source_city_index,
		"destination": destination_city_index,
		"resource": selected_resource,
		"amount": amount_per_tick
	}
	close()

func has_pending_route() -> bool:
	return not pending_route_data.is_empty()

func consume_pending_route_data() -> Dictionary:
	var route_data: Dictionary = pending_route_data.duplicate()
	pending_route_data.clear()
	return route_data

func draw(canvas: CanvasItem, font: Font, cities: Array[City], viewport_size: Vector2):
	action_options.clear()
	if not open_state:
		menu_rect = Rect2()
		return

	clamp_to_viewport(viewport_size)

	var font_size: int = 14
	menu_rect = Rect2(menu_position, menu_size)
	var text_x: float = menu_position.x + 14.0
	var y: float = menu_position.y + 24.0
	var width: float = menu_size.x - 28.0

	canvas.draw_rect(menu_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	canvas.draw_rect(get_header_rect(), VisualStyle.COLOR_UI_POPUP_HEADER)
	canvas.draw_rect(menu_rect, VisualStyle.COLOR_SELECTION_OUTLINE, false, VisualStyle.PANEL_BORDER_WIDTH)
	canvas.draw_string(font, Vector2(text_x, y), "Create Trade Route", HORIZONTAL_ALIGNMENT_LEFT, width, 16, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 26.0

	y = draw_sidebar_like_line(canvas, font, font_size, "Source: " + get_trade_city_label(cities, source_city_index), text_x, y, width, VisualStyle.COLOR_UI_TEXT_SOFT)
	y = draw_sidebar_like_line(canvas, font, font_size, "Destination: " + get_trade_city_label(cities, destination_city_index), text_x, y, width, VisualStyle.COLOR_UI_TEXT_SOFT)
	y = draw_sidebar_like_line(canvas, font, font_size, "Click cities on the map to set them.", text_x, y, width, VisualStyle.COLOR_MUTED)
	y += 4.0
	y = draw_action_option(canvas, font, font_size, resource_button_label("food"), text_x, y, width, {"action": "select_trade_resource", "resource": "food"}, trade_resource_button_color("food"))
	y = draw_action_option(canvas, font, font_size, resource_button_label("wood"), text_x, y, width, {"action": "select_trade_resource", "resource": "wood"}, trade_resource_button_color("wood"))
	y = draw_action_option(canvas, font, font_size, resource_button_label("tools"), text_x, y, width, {"action": "select_trade_resource", "resource": "tools"}, trade_resource_button_color("tools"))
	y = draw_sidebar_like_line(canvas, font, font_size, "Amount/tick: " + str(amount_per_tick), text_x, y, width, VisualStyle.COLOR_UI_TEXT_SOFT)
	y = draw_action_option(canvas, font, font_size, "- amount", text_x, y, width, {"action": "decrease_trade_amount"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)
	y = draw_action_option(canvas, font, font_size, "+ amount", text_x, y, width, {"action": "increase_trade_amount"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)

	if source_city_index >= 0 and destination_city_index >= 0:
		y = draw_action_option(canvas, font, font_size, "Create route", text_x, y, width, {"action": "create_trade_route"}, VisualStyle.COLOR_UI_BUTTON_CONFIRM)
	else:
		y = draw_sidebar_like_line(canvas, font, font_size, "Select source and destination first.", text_x, y, width, VisualStyle.COLOR_MUTED)

	draw_action_option(canvas, font, font_size, "Cancel", text_x, y, width, {"action": "cancel_trade_route"}, VisualStyle.COLOR_UI_BUTTON_DANGER)

func draw_action_option(canvas: CanvasItem, font: Font, font_size: int, text: String, x: float, y: float, width: float, option_data: Dictionary, color: Color) -> float:
	var option_rect: Rect2 = Rect2(Vector2(x - 4.0, y - 13.0), Vector2(width + 8.0, 18.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = option_rect
	action_options.append(stored_option)

	canvas.draw_rect(option_rect, color)
	canvas.draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, VisualStyle.COLOR_UI_TEXT)
	return y + 21.0

func draw_sidebar_like_line(canvas: CanvasItem, font: Font, font_size: int, text: String, x: float, y: float, width: float, color: Color) -> float:
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
	return y + 18.0

func get_trade_city_label(cities: Array[City], city_index: int) -> String:
	if city_index < 0 or city_index >= cities.size():
		return "click city"

	var city: City = cities[city_index]
	return city.name

func resource_button_label(resource_name: String) -> String:
	var label: String = resource_name
	if selected_resource == resource_name:
		label += " selected"

	return label

func trade_resource_button_color(resource_name: String) -> Color:
	if selected_resource == resource_name:
		return VisualStyle.COLOR_UI_BUTTON_RESOURCE_SELECTED

	return VisualStyle.COLOR_UI_BUTTON_DISABLED

func get_header_rect() -> Rect2:
	return Rect2(menu_position, Vector2(menu_size.x, 38.0))

func clamp_to_viewport(viewport_size: Vector2):
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var max_x: float = max(0.0, viewport_size.x - menu_size.x)
	var max_y: float = max(0.0, viewport_size.y - menu_size.y)
	menu_position.x = clamp(menu_position.x, 0.0, max_x)
	menu_position.y = clamp(menu_position.y, 0.0, max_y)
