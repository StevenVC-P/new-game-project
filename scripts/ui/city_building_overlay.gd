class_name CityBuildingOverlay
extends RefCounted

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"

var city_tile_size: int = 12
var city_view_top: int = 48
var city_map_width: int = 64
var city_map_height: int = 44
var selected_house_building_index: int = -1
var inspected_building_index: int = -1
var action_options: Array[Dictionary] = []
var overlay_rect: Rect2 = Rect2()

func _init(tile_size: int = 12, view_top: int = 48, map_width: int = 64, map_height: int = 44):
	city_tile_size = tile_size
	city_view_top = view_top
	city_map_width = map_width
	city_map_height = map_height

func clear():
	selected_house_building_index = -1
	inspected_building_index = -1
	action_options.clear()
	overlay_rect = Rect2()

func has_selection() -> bool:
	return inspected_building_index >= 0

func is_inspected(building_index: int) -> bool:
	return building_index == inspected_building_index

func is_selected_house(building_index: int) -> bool:
	return building_index == selected_house_building_index

func select_building_at_tile(city: City, tile_pos: Vector2i, toggle_maintenance: bool) -> bool:
	var buildings: Array = city.buildings
	for building_index in range(buildings.size()):
		var building: Building = buildings[building_index]
		if not building.contains_tile(tile_pos):
			continue

		inspected_building_index = building_index
		if building.is_house():
			selected_house_building_index = building_index
			return true

		if toggle_maintenance:
			city.toggle_building_maintenance(building_index)
		selected_house_building_index = -1
		return true

	return false

func handle_action_click(mouse_pos: Vector2, city: City) -> bool:
	if inspected_building_index < 0:
		return false

	for option_data: Dictionary in action_options:
		var option_rect: Rect2 = option_data["rect"] as Rect2
		if not option_rect.has_point(mouse_pos):
			continue

		apply_action(option_data, city)
		return true

	if overlay_rect.has_point(mouse_pos):
		return true

	return false

func apply_action(option_data: Dictionary, city: City):
	var buildings: Array = city.buildings
	if inspected_building_index < 0 or inspected_building_index >= buildings.size():
		return

	var action: String = option_data["action"] as String

	if action == "assign_house":
		var house_index: int = int(option_data["house_index"])
		city.assign_household_to_building(inspected_building_index, house_index)
	elif action == "assign_household":
		var household_id: int = int(option_data["household_id"])
		city.assign_household_by_id_to_building(inspected_building_index, household_id)
	elif action == "assign_neutral":
		city.assign_neutral_worker_to_building(inspected_building_index)
	elif action == "unassign":
		city.unassign_building_worker(inspected_building_index)
	elif action == "toggle_maintenance":
		city.toggle_building_maintenance(inspected_building_index)

func draw(canvas: CanvasItem, font: Font, font_size: int, city: City):
	action_options.clear()
	overlay_rect = Rect2()

	if inspected_building_index < 0:
		return

	var buildings: Array = city.buildings
	if inspected_building_index >= buildings.size():
		return

	var building: Building = buildings[inspected_building_index]
	var building_rect: Rect2 = get_building_screen_rect(building)
	var overlay_size: Vector2 = get_building_overlay_size(city, building)
	var overlay_pos: Vector2 = building_rect.position + Vector2(building_rect.size.x + 8.0, -4.0)
	var max_x: float = city_map_width * city_tile_size - overlay_size.x - 4.0
	var max_y: float = city_view_top + city_map_height * city_tile_size - overlay_size.y - 4.0
	if max_x < 4.0:
		max_x = 4.0
	if max_y < city_view_top + 4.0:
		max_y = city_view_top + 4.0

	if overlay_pos.x > max_x:
		overlay_pos.x = building_rect.position.x - overlay_size.x - 8.0
	overlay_pos.x = clamp(overlay_pos.x, 4.0, max_x)
	overlay_pos.y = clamp(overlay_pos.y, city_view_top + 4.0, max_y)

	overlay_rect = Rect2(overlay_pos, overlay_size)
	var text_x: float = overlay_pos.x + 10.0
	var y: float = overlay_pos.y + 18.0

	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_OVERLAY_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	canvas.draw_string(font, Vector2(text_x, y), get_building_label(city, inspected_building_index), HORIZONTAL_ALIGNMENT_LEFT, overlay_size.x - 20.0, font_size, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 20.0

	if building.is_house():
		y = draw_overlay_line(canvas, font, font_size, "Resident: " + get_house_resident_text(city, inspected_building_index), text_x, y, overlay_size.x)
		y = draw_overlay_line(canvas, font, font_size, "Available labor: " + get_house_available_worker_text(city, inspected_building_index), text_x, y, overlay_size.x)
		y = draw_overlay_line(canvas, font, font_size, "Assigned: " + get_house_assignment_text(city, inspected_building_index), text_x, y, overlay_size.x)
		y = draw_overlay_section_title(canvas, font, font_size, "Household Lifecycle", text_x, y, overlay_size.x)
		for lifecycle_text: String in get_house_lifecycle_lines(city, inspected_building_index):
			y = draw_overlay_line(canvas, font, font_size, lifecycle_text, text_x, y, overlay_size.x)
		return

	y = draw_overlay_line(canvas, font, font_size, "Maintenance: " + str(building.maintenance_level) + "%", text_x, y, overlay_size.x)
	y = draw_overlay_line(canvas, font, font_size, "Upkeep: " + enabled_text(building.receives_maintenance), text_x, y, overlay_size.x)
	y = draw_overlay_line(canvas, font, font_size, "Worker: " + get_building_worker_text(city, inspected_building_index), text_x, y, overlay_size.x)
	y = draw_overlay_line(canvas, font, font_size, "Assignment: " + get_assignment_source_text(building), text_x, y, overlay_size.x)
	if building.assigned_workers <= 0:
		var succession_hint: String = get_work_succession_hint(city, building)
		if succession_hint != "":
			y = draw_overlay_line(canvas, font, font_size, succession_hint, text_x, y, overlay_size.x)
	y = draw_overlay_section_title(canvas, font, font_size, "Production Requirements", text_x, y, overlay_size.x)
	for requirement_text: String in ProductionRequirementHelper.get_requirement_lines(city, building):
		y = draw_overlay_line(canvas, font, font_size, requirement_text, text_x, y, overlay_size.x)

	if building.assigned_workers > 0:
		y = draw_overlay_action_option(canvas, font, font_size, "Unassign worker", text_x, y, overlay_size.x, {"action": "unassign"}, VisualStyle.COLOR_UI_BUTTON_DANGER)
	else:
		y = draw_overlay_available_worker_options(canvas, font, font_size, text_x, y, overlay_size.x, city, building)

	draw_overlay_action_option(canvas, font, font_size, "Toggle maintenance", text_x, y, overlay_size.x, {"action": "toggle_maintenance"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)

func get_building_screen_rect(building: Building) -> Rect2:
	var tile_pos: Vector2i = building.tile
	var size: Vector2i = building.size
	var pos: Vector2 = Vector2(tile_pos.x * city_tile_size, city_view_top + tile_pos.y * city_tile_size)
	return Rect2(pos, Vector2(size.x * city_tile_size - 1, size.y * city_tile_size - 1))

func get_building_overlay_size(city: City, building: Building) -> Vector2:
	var width: float = 260.0
	var line_count: int = 4
	var option_count: int = 0

	if building.is_house():
		line_count = 5 + get_house_lifecycle_lines(city, building.id).size()
	else:
		line_count = 6 + ProductionRequirementHelper.get_requirement_lines(city, building).size()
		if building.assigned_workers <= 0 and get_work_succession_hint(city, building) != "":
			line_count += 1
		if building.assigned_workers > 0:
			option_count = 1
		else:
			option_count = count_available_overlay_worker_options(city)
			if option_count <= 0:
				line_count += 1
		option_count += 1

	var height: float = 18.0 + float(line_count) * 18.0 + float(option_count) * 22.0
	return Vector2(width, height)

func count_available_overlay_worker_options(city: City) -> int:
	var count: int = 0

	if city.get_available_neutral_workers() > 0:
		count += 1

	for household: Household in city.get_available_households():
		if city.get_available_workers_from_household(household.id) > 0:
			count += 1

	return count

func draw_overlay_line(canvas: CanvasItem, font: Font, font_size: int, text: String, x: float, y: float, overlay_width: float) -> float:
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, overlay_width - 20.0, font_size, VisualStyle.COLOR_UI_TEXT_SOFT)
	return y + 18.0

func draw_overlay_section_title(canvas: CanvasItem, font: Font, font_size: int, text: String, x: float, y: float, overlay_width: float) -> float:
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, overlay_width - 20.0, max(10, font_size - 1), VisualStyle.COLOR_UI_SECTION_HEADER)
	return y + 18.0

func draw_overlay_available_worker_options(canvas: CanvasItem, font: Font, font_size: int, x: float, y: float, overlay_width: float, city: City, building: Building) -> float:
	var drew_option: bool = false

	if city.get_available_neutral_workers() > 0:
		y = draw_overlay_action_option(canvas, font, font_size, "Starter neutral - neutral", x, y, overlay_width, {"action": "assign_neutral"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)
		drew_option = true

	for household: Household in city.get_available_households():
		if city.get_available_workers_from_household(household.id) <= 0:
			continue

		var preference: String = household.preference
		var quality: String = household.get_match_quality(building.type)
		var label: String = get_household_option_label(city, household) + " - " + preference + " - " + quality
		var option_color: Color = get_match_quality_color(quality)
		y = draw_overlay_action_option(canvas, font, font_size, label, x, y, overlay_width, {"action": "assign_household", "household_id": household.id}, option_color)
		drew_option = true

	if not drew_option:
		y = draw_overlay_line(canvas, font, font_size, "No available workers.", x, y, overlay_width)

	return y

func draw_overlay_action_option(canvas: CanvasItem, font: Font, font_size: int, text: String, x: float, y: float, overlay_width: float, option_data: Dictionary, color: Color) -> float:
	var option_rect: Rect2 = Rect2(Vector2(x - 4.0, y - 13.0), Vector2(overlay_width - 12.0, 18.0))
	var stored_option: Dictionary = option_data.duplicate()
	stored_option["rect"] = option_rect
	action_options.append(stored_option)

	canvas.draw_rect(option_rect, color)
	canvas.draw_rect(option_rect, VisualStyle.COLOR_UI_OPTION_BORDER, false, VisualStyle.OPTION_BORDER_WIDTH)
	canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, overlay_width - 20.0, font_size, VisualStyle.COLOR_UI_TEXT)
	return y + 22.0

func get_building_label(city: City, building_index: int) -> String:
	var buildings: Array = city.buildings
	if building_index < 0 or building_index >= buildings.size():
		return "none"

	var building: Building = buildings[building_index]
	var building_number: int = count_buildings_of_type_through_index(buildings, building.type, building_index)
	return capitalize_building_name(building.type) + " " + str(building_number)

func count_buildings_of_type_through_index(buildings: Array, building_type: String, target_index: int) -> int:
	var count: int = 0

	for building_index in range(target_index + 1):
		var building: Building = buildings[building_index]
		if building.type == building_type:
			count += 1

	return count

func capitalize_building_name(building_type: String) -> String:
	if building_type == BUILDING_HOUSE:
		return "House"
	if building_type == BUILDING_FARM:
		return "Farm"
	if building_type == BUILDING_WOODCUTTER:
		return "Woodcutter"
	if building_type == BUILDING_TOOLMAKER:
		return "Toolmaker"
	if building_type == BUILDING_QUARRY:
		return "Quarry"
	if building_type == BUILDING_STONECUTTER:
		return "Stonecutter"
	if building_type == BUILDING_BRICKWORKS:
		return "Brickworks"
	if building_type == BUILDING_LIME_KILN:
		return "Lime Kiln"
	if building_type == BUILDING_MORTAR_YARD:
		return "Mortar Yard"
	if building_type == BUILDING_MASON_YARD:
		return "Mason Yard"
	if building_type == BUILDING_SCULPTOR:
		return "Sculptor"
	if building_type == BUILDING_CARVER:
		return "Carver"
	if building_type == BUILDING_TILEWORKS:
		return "Tileworks"
	if building_type == BUILDING_PAVER_YARD:
		return "Paver Yard"

	return building_type

func get_house_preference_text(city: City, house_index: int) -> String:
	var buildings: Array = city.buildings
	if house_index < 0 or house_index >= buildings.size():
		return "-"

	var house: Building = buildings[house_index]
	if not house.is_house():
		return "-"

	return city.get_household_preference_for_building(house_index)

func get_house_resident_text(city: City, house_index: int) -> String:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null:
		return "empty"

	return city.get_household_label(household.id) + " (" + household.preference + ", pop " + str(household.total_population) + ")"

func get_house_available_worker_text(city: City, house_index: int) -> String:
	var available_workers: int = city.get_available_workers_from_house(house_index)
	var capacity: int = city.get_house_worker_capacity(house_index)
	var used_workers: int = max(0, capacity - available_workers)
	return str(used_workers) + " / " + str(capacity) + " used"

func get_house_assignment_text(city: City, house_index: int) -> String:
	var assigned_jobs: Array[String] = []
	var assigned_building_ids: Array[int] = city.get_assigned_building_ids_for_house(house_index)

	for building_id: int in assigned_building_ids:
		assigned_jobs.append(get_building_label(city, building_id))

	if assigned_jobs.is_empty():
		return "none"

	var text: String = assigned_jobs[0]
	for job_index in range(1, assigned_jobs.size()):
		text += ", " + assigned_jobs[job_index]

	return text

func get_house_lifecycle_lines(city: City, house_index: int) -> Array[String]:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null:
		return ["No resident household."]

	return HouseholdLifecycleDisplayHelper.get_lifecycle_lines(household, city)

func get_building_worker_text(city: City, building_index: int) -> String:
	var buildings: Array = city.buildings
	if building_index < 0 or building_index >= buildings.size():
		return "-"

	var building: Building = buildings[building_index]
	if building.is_house():
		return get_house_preference_text(city, building_index)
	if building.assigned_workers <= 0:
		return "unassigned"

	var assigned_house_building_index: int = city.get_assigned_house_building_id(building)
	if assigned_house_building_index >= 0:
		return get_building_label(city, assigned_house_building_index) + " (" + get_house_preference_text(city, assigned_house_building_index) + ")"

	var household: Household = city.get_household_by_id(building.assigned_household_id)
	if household != null:
		return city.get_household_label(household.id) + " (" + household.preference + ", " + household.housing_status + ")"

	return "unknown household"

func get_work_succession_hint(city: City, building: Building) -> String:
	if building.preferred_successor_household_id < 0:
		return ""

	var successor: Household = city.get_household_by_id(building.preferred_successor_household_id)
	if successor == null:
		return ""

	return "Family work succession: " + city.get_household_label(successor.id) + " preferred"

func get_household_option_label(city: City, household: Household) -> String:
	if household.residence_building_id >= 0:
		return get_building_label(city, household.residence_building_id)

	return city.get_household_label(household.id) + " (" + household.housing_status + ")"

func get_assignment_source_text(building: Building) -> String:
	if building.assignment_source == Building.ASSIGNMENT_AUTO:
		return "automatic"
	if building.assignment_source == Building.ASSIGNMENT_PLAYER:
		return "player-directed"
	if building.auto_assignment_blocked:
		return "manual hold"

	return "none"

func get_match_quality_color(quality: String) -> Color:
	if quality == "good match":
		return VisualStyle.COLOR_UI_BUTTON_CONFIRM
	if quality == "poor match":
		return VisualStyle.COLOR_UI_BUTTON_DANGER

	return VisualStyle.COLOR_UI_BUTTON_DISABLED

func enabled_text(is_enabled: bool) -> String:
	if is_enabled:
		return "enabled"

	return "disabled"
