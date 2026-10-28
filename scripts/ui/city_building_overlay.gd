class_name CityBuildingOverlay
extends RefCounted

const HouseholdDemandDisplayHelperScript = preload("res://scripts/ui/household_demand_display_helper.gd")
const HouseholdProsperityDisplayHelperScript = preload("res://scripts/ui/household_prosperity_display_helper.gd")

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
# A building site (TownConstruction project id) or residential plot (plot id) shown instead of a
# building; -1 when none.
var inspected_project_id: int = -1
var inspected_plot_id: int = -1
var action_options: Array[Dictionary] = []
var overlay_rect: Rect2 = Rect2()
# Where the town map shows a building on screen (Building -> Rect2), and the screen area the
# card must stay inside. Set by the owner when the town map has a camera; without them the card
# follows the fixed tile grid.
var screen_rect_of_building: Callable = Callable()
# Where the town map shows a footprint (origin tile, size) on screen, for sites and plots.
var screen_rect_of_footprint: Callable = Callable()
var bounds: Rect2 = Rect2()

func _init(tile_size: int = 12, view_top: int = 48, map_width: int = 64, map_height: int = 44):
	city_tile_size = tile_size
	city_view_top = view_top
	city_map_width = map_width
	city_map_height = map_height

func clear():
	selected_house_building_index = -1
	inspected_building_index = -1
	inspected_project_id = -1
	inspected_plot_id = -1
	action_options.clear()
	overlay_rect = Rect2()

func has_selection() -> bool:
	return inspected_building_index >= 0 or inspected_project_id >= 0 or inspected_plot_id >= 0

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
		inspected_project_id = -1
		inspected_plot_id = -1
		if building.is_house():
			selected_house_building_index = building_index
			return true

		if toggle_maintenance:
			city.toggle_building_maintenance(building_index)
		selected_house_building_index = -1
		return true

	return false

# Selects the building site or residential plot under a tile, if any.
func select_site_at_tile(city: City, tile_pos: Vector2i) -> bool:
	var project: ConstructionProject = city.construction.get_project_at_tile(tile_pos)
	var plot: Variant = city.construction.get_plot_at(tile_pos) if project == null else null
	if project == null and plot == null:
		return false
	clear()
	if project != null:
		inspected_project_id = project.id
	else:
		inspected_plot_id = int(plot["id"])
	return true

func handle_action_click(mouse_pos: Vector2, city: City) -> bool:
	if not has_selection():
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
	var action: String = option_data["action"] as String
	if action == "prioritize_project":
		city.construction.prioritize(int(option_data["project_id"]))
		return
	if action == "cancel_project":
		city.construction.cancel(int(option_data["project_id"]))
		if inspected_project_id == int(option_data["project_id"]):
			clear()
		return
	if action == "remove_plot":
		if city.construction.remove_plot(inspected_plot_id):
			clear()
		return

	var buildings: Array = city.buildings
	if inspected_building_index < 0 or inspected_building_index >= buildings.size():
		return

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
	elif action == "upgrade":
		city.construction.request_upgrade(inspected_building_index)
	elif action == "fence":
		city.construction.request_fence(inspected_building_index)

func draw(canvas: CanvasItem, font: Font, font_size: int, city: City):
	action_options.clear()
	overlay_rect = Rect2()

	if inspected_project_id >= 0:
		draw_site_card(canvas, font, font_size, city)
		return
	if inspected_plot_id >= 0:
		draw_plot_card(canvas, font, font_size, city)
		return
	if inspected_building_index < 0:
		return

	var buildings: Array = city.buildings
	if inspected_building_index >= buildings.size():
		return

	var building: Building = buildings[inspected_building_index]
	var overlay_size: Vector2 = get_building_overlay_size(city, building)
	place_card(get_building_screen_rect(building), overlay_size)
	var text_x: float = overlay_rect.position.x + 10.0
	var y: float = overlay_rect.position.y + 18.0

	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_OVERLAY_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	canvas.draw_string(font, Vector2(text_x, y), get_building_label(city, inspected_building_index), HORIZONTAL_ALIGNMENT_LEFT, overlay_size.x - 20.0, font_size, VisualStyle.COLOR_UI_SECTION_HEADER)
	y += 20.0

	if building.is_house():
		y = draw_overlay_line(canvas, font, font_size, "Resident: " + get_house_resident_text(city, inspected_building_index), text_x, y, overlay_size.x)
		var resident_calling: String = get_house_calling_text(city, inspected_building_index)
		if resident_calling != "":
			y = draw_overlay_line(canvas, font, font_size, "Calling: " + resident_calling, text_x, y, overlay_size.x)
		y = draw_overlay_line(canvas, font, font_size, "Available labor: " + get_house_available_worker_text(city, inspected_building_index), text_x, y, overlay_size.x)
		y = draw_overlay_line(canvas, font, font_size, "Assigned: " + get_house_assignment_text(city, inspected_building_index), text_x, y, overlay_size.x)
		y = draw_overlay_section_title(canvas, font, font_size, "Household Lifecycle", text_x, y, overlay_size.x)
		for lifecycle_text: String in get_house_lifecycle_lines(city, inspected_building_index):
			y = draw_overlay_line(canvas, font, font_size, lifecycle_text, text_x, y, overlay_size.x)
		y = draw_overlay_section_title(canvas, font, font_size, "Family Demand", text_x, y, overlay_size.x)
		for demand_text: String in get_house_demand_lines(city, inspected_building_index):
			y = draw_overlay_line(canvas, font, font_size, demand_text, text_x, y, overlay_size.x)
		y = draw_overlay_section_title(canvas, font, font_size, "Household Status", text_x, y, overlay_size.x)
		for prosperity_text: String in get_house_prosperity_lines(city, inspected_building_index):
			y = draw_overlay_line(canvas, font, font_size, prosperity_text, text_x, y, overlay_size.x)
		y = draw_fence_option(canvas, font, font_size, text_x, y, overlay_size.x, city, building)
		draw_upgrade_option(canvas, font, font_size, text_x, y, overlay_size.x, city, building)
		return
	if building.is_store():
		y = draw_overlay_line(canvas, font, font_size, "Keeps the town's goods.", text_x, y, overlay_size.x)
		y = draw_overlay_line(canvas, font, font_size, "Workplaces nearby carry less far.", text_x, y, overlay_size.x)
		draw_fence_option(canvas, font, font_size, text_x, y, overlay_size.x, city, building)
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
	for travel_text: String in ConstructionDisplayHelper.get_travel_lines(city, building):
		y = draw_overlay_line(canvas, font, font_size, travel_text, text_x, y, overlay_size.x)

	if building.assigned_workers > 0:
		y = draw_overlay_action_option(canvas, font, font_size, "Unassign worker", text_x, y, overlay_size.x, {"action": "unassign"}, VisualStyle.COLOR_UI_BUTTON_DANGER)
	else:
		y = draw_overlay_available_worker_options(canvas, font, font_size, text_x, y, overlay_size.x, city, building)

	y = draw_fence_option(canvas, font, font_size, text_x, y, overlay_size.x, city, building)
	if building.is_tier0():
		y = draw_upgrade_option(canvas, font, font_size, text_x, y, overlay_size.x, city, building)
	else:
		draw_overlay_action_option(canvas, font, font_size, "Toggle maintenance", text_x, y, overlay_size.x, {"action": "toggle_maintenance"}, VisualStyle.COLOR_UI_BUTTON_DISABLED)

# Upgrading plans a construction project; the building keeps working until it is done.
func draw_upgrade_option(canvas: CanvasItem, font: Font, font_size: int, x: float, y: float, overlay_width: float, city: City, building: Building) -> float:
	var upgrade_type: String = BuildingTiers.get_upgrade_type(building.type)
	if upgrade_type == "":
		return y
	var project: ConstructionProject = city.construction.get_upgrade_project(building.id)
	if project != null:
		y = draw_overlay_line(canvas, font, font_size, "Upgrading: " + city.construction.get_status_text(project), x, y, overlay_width)
		return draw_overlay_action_option(canvas, font, font_size, "Cancel upgrade", x, y, overlay_width, {"action": "cancel_project", "project_id": project.id}, VisualStyle.COLOR_UI_BUTTON_DANGER)
	var cost: Dictionary = city.get_upgrade_cost(building.id)
	var label: String = "Upgrade to " + capitalize_building_name(upgrade_type) + " (" + get_cost_summary(cost) + ")"
	var color: Color = VisualStyle.COLOR_UI_BUTTON_CONFIRM if city.construction.can_supply(cost) else VisualStyle.COLOR_UI_BUTTON_DISABLED
	return draw_overlay_action_option(canvas, font, font_size, label, x, y, overlay_width, {"action": "upgrade"}, color)

# A fence round a field or a yard is a construction project too; once it stands, nobody else
# walks through it or along its edges.
func draw_fence_option(canvas: CanvasItem, font: Font, font_size: int, x: float, y: float, overlay_width: float, city: City, building: Building) -> float:
	if building.fenced:
		return draw_overlay_line(canvas, font, font_size, "Fenced: nobody else walks through or beside it", x, y, overlay_width)
	if BuildingTiers.get_base_type(building.type) == Building.BUILDING_QUARRY:
		return y
	var project: ConstructionProject = city.construction.get_fence_project(building.id)
	if project != null:
		y = draw_overlay_line(canvas, font, font_size, "Fencing: " + city.construction.get_status_text(project), x, y, overlay_width)
		return draw_overlay_action_option(canvas, font, font_size, "Cancel fence", x, y, overlay_width, {"action": "cancel_project", "project_id": project.id}, VisualStyle.COLOR_UI_BUTTON_DANGER)
	var cost: Dictionary = EconomyBalance.get_fence_cost(building.size)
	var color: Color = VisualStyle.COLOR_UI_BUTTON_CONFIRM if city.construction.can_supply(cost) else VisualStyle.COLOR_UI_BUTTON_DISABLED
	var what: String = "field" if TownLogistics.is_field(building) else "yard"
	return draw_overlay_action_option(canvas, font, font_size, "Fence the " + what + " (" + get_cost_summary(cost) + ")", x, y, overlay_width, {"action": "fence"}, color)

# Card rows the fence takes: (lines, options).
static func count_fence_rows(city: City, building: Building) -> Vector2i:
	if building.fenced:
		return Vector2i(1, 0)
	if BuildingTiers.get_base_type(building.type) == Building.BUILDING_QUARRY:
		return Vector2i.ZERO
	return Vector2i(1 if city.construction.get_fence_project(building.id) != null else 0, 1)

# --- Building sites and plots ------------------------------------------------------------------

# Places the card beside what it describes, inside the map area.
func place_card(anchor: Rect2, card_size: Vector2) -> void:
	var area: Rect2 = bounds if bounds.has_area() else Rect2(Vector2(0.0, city_view_top), Vector2(city_map_width, city_map_height) * city_tile_size)
	var min_x: float = area.position.x + 4.0
	var min_y: float = area.position.y + 4.0
	var max_x: float = maxf(area.end.x - card_size.x - 4.0, min_x)
	var max_y: float = maxf(area.end.y - card_size.y - 4.0, min_y)
	var card_pos: Vector2 = anchor.position + Vector2(anchor.size.x + 8.0, -4.0)
	if card_pos.x > max_x:
		card_pos.x = anchor.position.x - card_size.x - 8.0
	card_pos.x = clamp(card_pos.x, min_x, max_x)
	card_pos.y = clamp(card_pos.y, min_y, max_y)
	overlay_rect = Rect2(card_pos, card_size)

func get_footprint_screen_rect(tile_pos: Vector2i, size: Vector2i) -> Rect2:
	if screen_rect_of_footprint.is_valid():
		return screen_rect_of_footprint.call(tile_pos, size)
	return Rect2(Vector2(tile_pos.x * city_tile_size, city_view_top + tile_pos.y * city_tile_size), Vector2(size) * city_tile_size)

func draw_card_frame(canvas: CanvasItem, font: Font, font_size: int, title: String) -> float:
	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_POPUP_BACKGROUND)
	canvas.draw_rect(overlay_rect, VisualStyle.COLOR_UI_OVERLAY_BORDER, false, VisualStyle.PANEL_BORDER_WIDTH)
	var y: float = overlay_rect.position.y + 18.0
	canvas.draw_string(font, Vector2(overlay_rect.position.x + 10.0, y), title, HORIZONTAL_ALIGNMENT_LEFT, overlay_rect.size.x - 20.0, font_size, VisualStyle.COLOR_UI_SECTION_HEADER)
	return y + 20.0

func draw_site_card(canvas: CanvasItem, font: Font, font_size: int, city: City) -> void:
	var project: ConstructionProject = city.construction.get_project(inspected_project_id)
	if project == null:
		clear()
		return
	var lines: Array[String] = ConstructionDisplayHelper.get_project_lines(city, project)
	var card_size: Vector2 = Vector2(360.0, 18.0 + float(lines.size() + 1) * 18.0 + 2.0 * 22.0 + 6.0)
	var anchor_tile: Vector2i = project.get_site_tile() if project.kind == ConstructionProject.KIND_ROAD else project.tile
	var anchor_size: Vector2i = Vector2i.ONE if project.kind == ConstructionProject.KIND_ROAD else project.size
	place_card(get_footprint_screen_rect(anchor_tile, anchor_size), card_size)
	var x: float = overlay_rect.position.x + 10.0
	var y: float = draw_card_frame(canvas, font, font_size, ConstructionDisplayHelper.get_project_title(city, project))
	for line: String in lines:
		y = draw_overlay_line(canvas, font, font_size, line, x, y, card_size.x)
	y += 4.0
	var first: bool = city.construction.projects.size() > 0 and city.construction.projects[0] == project
	y = draw_overlay_action_option(canvas, font, font_size, "First in line" if first else "Build this first", x, y, card_size.x, {"action": "prioritize_project", "project_id": project.id}, VisualStyle.COLOR_UI_BUTTON_DISABLED if first else VisualStyle.COLOR_UI_BUTTON_CONFIRM)
	draw_overlay_action_option(canvas, font, font_size, "Cancel (materials go back to the stores)", x, y, card_size.x, {"action": "cancel_project", "project_id": project.id}, VisualStyle.COLOR_UI_BUTTON_DANGER)

func draw_plot_card(canvas: CanvasItem, font: Font, font_size: int, city: City) -> void:
	var plot: Dictionary = city.construction.get_plot(inspected_plot_id)
	if plot.is_empty():
		clear()
		return
	var lines: Array[String] = ConstructionDisplayHelper.get_plot_lines(city, plot)
	var open: bool = int(plot["project_id"]) < 0
	var card_size: Vector2 = Vector2(260.0, 18.0 + float(lines.size() + 1) * 18.0 + (22.0 if open else 0.0) + 6.0)
	place_card(get_footprint_screen_rect(plot["tile"], plot["size"]), card_size)
	var x: float = overlay_rect.position.x + 10.0
	var y: float = draw_card_frame(canvas, font, font_size, "Residential Plot")
	for line: String in lines:
		y = draw_overlay_line(canvas, font, font_size, line, x, y, card_size.x)
	if open:
		draw_overlay_action_option(canvas, font, font_size, "Remove plot", x, y + 4.0, card_size.x, {"action": "remove_plot"}, VisualStyle.COLOR_UI_BUTTON_DANGER)

func get_cost_summary(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_name in cost.keys():
		parts.append(str(cost[resource_name]) + " " + str(resource_name))
	if parts.is_empty():
		return "free"
	return ", ".join(parts)

func get_building_screen_rect(building: Building) -> Rect2:
	if screen_rect_of_building.is_valid():
		return screen_rect_of_building.call(building)
	var tile_pos: Vector2i = building.tile
	var size: Vector2i = building.size
	var pos: Vector2 = Vector2(tile_pos.x * city_tile_size, city_view_top + tile_pos.y * city_tile_size)
	return Rect2(pos, Vector2(size.x * city_tile_size - 1, size.y * city_tile_size - 1))

func get_building_overlay_size(city: City, building: Building) -> Vector2:
	var width: float = 260.0
	var line_count: int = 4
	var option_count: int = 0

	if building.is_store():
		line_count = 3
	elif building.is_house():
		line_count = 7 + get_house_lifecycle_lines(city, building.id).size() + get_house_demand_lines(city, building.id).size() + get_house_prosperity_lines(city, building.id).size()
	else:
		line_count = 6 + ProductionRequirementHelper.get_requirement_lines(city, building).size() + ConstructionDisplayHelper.get_travel_lines(city, building).size()
		if building.assigned_workers <= 0 and get_work_succession_hint(city, building) != "":
			line_count += 1
		if building.assigned_workers > 0:
			option_count = 1
		else:
			option_count = count_available_overlay_worker_options(city)
			if option_count <= 0:
				line_count += 1
		option_count += 1
	if building.is_tier0() and building.is_house():
		option_count += 1
	if building.is_tier0() and city.construction.get_upgrade_project(building.id) != null:
		line_count += 1
	var fence_rows: Vector2i = count_fence_rows(city, building)
	line_count += fence_rows.x
	option_count += fence_rows.y

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
	if BuildingTiers.is_tier0(building_type) or BuildingTiers.DISPLAY_NAMES.has(building_type):
		return BuildingTiers.get_display_name(building_type)
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
	if building_type == Building.BUILDING_STOREHOUSE:
		return "Storehouse"

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

	return city.get_household_label(household.id) + ", pop " + str(household.total_population)

func get_house_calling_text(city: City, house_index: int) -> String:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null or not household.has_values():
		return ""
	var names: Array[String] = []
	for calling in household.values.get(CultureValues.CATEGORY_CALLING, []):
		names.append(CultureValues.get_display_name(calling))
	return ", ".join(names)

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

func get_house_demand_lines(city: City, house_index: int) -> Array[String]:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null:
		return ["No resident household demand."]

	return HouseholdDemandDisplayHelperScript.get_demand_lines(city, household)

func get_house_prosperity_lines(city: City, house_index: int) -> Array[String]:
	var household: Household = city.get_household_for_building_id(house_index)
	if household == null:
		return ["Prosperity: no resident household"]

	return HouseholdProsperityDisplayHelperScript.get_prosperity_lines(city, household)

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

	var hint: String = "Family work succession: " + city.get_household_label(successor.id) + " preferred"
	if building.succession_vacancy_months >= 0:
		var months_left: int = max(0, City.SUCCESSION_AUTO_FILL_MONTHS - building.succession_vacancy_months)
		hint += " (filled automatically in " + str(months_left) + " mo)"
	return hint

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
