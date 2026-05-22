class_name VisualStyle
extends RefCounted

# Shared visual language for drawn prototype UI and maps.
# Keep these semantic so future sprites/icons can preserve meaning.

const COLOR_TERRAIN_GRASS: Color = Color(0.34, 0.54, 0.24)
const COLOR_TERRAIN_FERTILE: Color = Color(0.47, 0.68, 0.25)
const COLOR_TERRAIN_FOREST: Color = Color(0.04, 0.27, 0.09)
const COLOR_TERRAIN_WATER: Color = Color(0.12, 0.42, 0.92)
const COLOR_TERRAIN_CITY_WATER: Color = Color(0.13, 0.40, 0.84)
const COLOR_TERRAIN_HILL: Color = Color(0.48, 0.42, 0.25)
const COLOR_TERRAIN_MOUNTAIN: Color = Color(0.36, 0.36, 0.36)
const COLOR_TERRAIN_CLEARING: Color = Color(0.48, 0.60, 0.31)
const COLOR_TERRAIN_ROUGH: Color = Color(0.48, 0.45, 0.36)
const COLOR_TERRAIN_CITY_GRASS: Color = Color(0.34, 0.50, 0.24)
const COLOR_TERRAIN_GRASS_ACCENT: Color = Color(0.42, 0.62, 0.30)
const COLOR_TERRAIN_FERTILE_ACCENT: Color = Color(0.62, 0.74, 0.30)
const COLOR_TERRAIN_FOREST_ACCENT: Color = Color(0.08, 0.36, 0.12)
const COLOR_TERRAIN_WATER_ACCENT: Color = Color(0.40, 0.66, 1.0)
const COLOR_TERRAIN_HILL_ACCENT: Color = Color(0.62, 0.54, 0.32)
const COLOR_TERRAIN_MOUNTAIN_ACCENT: Color = Color(0.62, 0.62, 0.62)
const COLOR_TERRAIN_CLEARING_ACCENT: Color = Color(0.58, 0.68, 0.38)
const COLOR_TERRAIN_ROUGH_ACCENT: Color = Color(0.62, 0.58, 0.48)
const COLOR_RESOURCE_STONE_LIGHT: Color = Color(0.78, 0.78, 0.72)
const COLOR_RESOURCE_STONE_DARK: Color = Color(0.62, 0.62, 0.58)
const COLOR_RESOURCE_IRON_DARK: Color = Color(0.66, 0.22, 0.16)
const COLOR_RESOURCE_IRON_LIGHT: Color = Color(0.95, 0.45, 0.22)
const COLOR_BLOCKED_OVERLAY: Color = Color(0.05, 0.05, 0.05, 0.25)

const COLOR_BUILDING_HOUSE: Color = Color(0.66, 0.42, 0.25)
const COLOR_BUILDING_FARM: Color = Color(0.72, 0.62, 0.24)
const COLOR_BUILDING_WOODCUTTER: Color = Color(0.42, 0.28, 0.14)
const COLOR_BUILDING_TOOLMAKER: Color = Color(0.45, 0.45, 0.48)
const COLOR_BUILDING_HOUSE_ACCENT: Color = Color(0.84, 0.56, 0.30)
const COLOR_BUILDING_FARM_ACCENT: Color = Color(0.90, 0.82, 0.40)
const COLOR_BUILDING_WOODCUTTER_ACCENT: Color = Color(0.78, 0.55, 0.28)
const COLOR_BUILDING_TOOLMAKER_ACCENT: Color = Color(0.72, 0.72, 0.68)
const COLOR_BUILDING_SELECTED: Color = Color(1.0, 1.0, 1.0, 0.35)
const COLOR_BUILDING_OUTLINE: Color = Color(0.10, 0.09, 0.07)
const COLOR_VALID_PLACEMENT: Color = Color(0.15, 0.95, 0.30, 0.38)
const COLOR_INVALID_PLACEMENT: Color = Color(1.0, 0.12, 0.12, 0.38)
const COLOR_UNASSIGNED_BUILDING: Color = Color(0.05, 0.05, 0.05, 0.25)
const COLOR_MAINTENANCE_GOOD: Color = Color(0.25, 0.95, 0.35)
const COLOR_MAINTENANCE_WARNING: Color = Color(0.95, 0.78, 0.25)
const COLOR_MAINTENANCE_BAD: Color = Color(1.0, 0.38, 0.22)
const COLOR_MAINTENANCE_DISABLED: Color = Color(0.55, 0.55, 0.55)
const COLOR_MAINTENANCE_BAR_BACKGROUND: Color = Color(0.06, 0.06, 0.06, 0.8)

const COLOR_RESOURCE_FOOD: Color = Color(0.88, 0.92, 0.78)
const COLOR_RESOURCE_WOOD: Color = Color(0.88, 0.92, 0.78)
const COLOR_RESOURCE_TOOLS: Color = Color(0.88, 0.92, 0.78)
const COLOR_POPULATION_LABOR: Color = Color(0.82, 0.88, 0.96)
const COLOR_POSITIVE: Color = Color(0.45, 1.0, 0.48)
const COLOR_WARNING: Color = Color(1.0, 0.42, 0.36)
const COLOR_MUTED: Color = Color(0.78, 0.78, 0.70)

const COLOR_ROAD_BASE: Color = Color(0.53, 0.39, 0.22)
const COLOR_ROAD_CENTER: Color = Color(0.73, 0.61, 0.40)
const COLOR_FORD: Color = Color(0.72, 0.62, 0.42)
const COLOR_TRADE_ROUTE_SHADOW: Color = Color(0.08, 0.08, 0.08, 0.65)
const COLOR_TRADE_ROUTE: Color = Color(0.95, 0.86, 0.20)
const COLOR_CITY_MARKER_OUTER: Color = Color(1.0, 0.9, 0.2)
const COLOR_CITY_MARKER_INNER: Color = Color(1.0, 0.72, 0.0)
const COLOR_HOVER_OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.65)
const COLOR_SELECTION_OUTLINE: Color = Color(0.86, 0.76, 0.35)

const COLOR_UI_BACKGROUND: Color = Color(0.12, 0.13, 0.11)
const COLOR_UI_PANEL_BACKGROUND: Color = Color(0.10, 0.11, 0.10)
const COLOR_UI_POPUP_BACKGROUND: Color = Color(0.08, 0.09, 0.08, 0.96)
const COLOR_UI_POPUP_HEADER: Color = Color(0.13, 0.14, 0.12, 0.96)
const COLOR_UI_PANEL_BORDER: Color = Color(0.34, 0.36, 0.32)
const COLOR_UI_OVERLAY_BORDER: Color = Color(0.76, 0.72, 0.52)
const COLOR_UI_OPTION_BORDER: Color = Color(0.48, 0.50, 0.44)
const COLOR_UI_SECTION_HEADER: Color = Color(1.0, 0.95, 0.72)
const COLOR_UI_TITLE: Color = Color(1.0, 0.92, 0.55)
const COLOR_UI_TEXT: Color = Color(0.94, 0.94, 0.84)
const COLOR_UI_TEXT_NORMAL: Color = Color(0.92, 0.92, 0.84)
const COLOR_UI_TEXT_MUTED: Color = Color(0.78, 0.78, 0.70)
const COLOR_UI_TEXT_SOFT: Color = Color(0.86, 0.88, 0.78)
const COLOR_UI_BUTTON_BACKGROUND: Color = Color(0.20, 0.22, 0.20)
const COLOR_UI_BUTTON_ACTIVE: Color = Color(0.28, 0.34, 0.24)
const COLOR_UI_BUTTON_DANGER: Color = Color(0.34, 0.20, 0.18)
const COLOR_UI_BUTTON_CONFIRM: Color = Color(0.18, 0.32, 0.20)
const COLOR_UI_BUTTON_DISABLED: Color = Color(0.22, 0.24, 0.20)
const COLOR_UI_BUTTON_RESOURCE_SELECTED: Color = Color(0.32, 0.28, 0.12)

const COLOR_PREF_AGRARIAN: Color = Color(0.35, 0.95, 0.35)
const COLOR_PREF_INDUSTRIAL: Color = Color(0.65, 0.65, 1.0)
const COLOR_PREF_NEUTRAL: Color = Color(0.85, 0.85, 0.78)
const COLOR_WALKER_AGRARIAN: Color = Color(0.56, 1.0, 0.46)
const COLOR_WALKER_INDUSTRIAL: Color = Color(0.62, 0.72, 1.0)
const COLOR_WALKER_NEUTRAL: Color = Color(0.92, 0.88, 0.68)
const COLOR_WALKER_SHADOW: Color = Color(0.03, 0.03, 0.02, 0.45)

const SIDEBAR_PADDING: int = 14
const SIDEBAR_ROW_HEIGHT: float = 15.0
const SIDEBAR_SECTION_SPACING: float = 6.0
const PANEL_MARGIN: int = 16
const BUTTON_HEIGHT: float = 18.0
const BUTTON_ROW_HEIGHT: float = 21.0
const PANEL_BORDER_WIDTH: float = 2.0
const OPTION_BORDER_WIDTH: float = 1.0
const MAP_LINE_WIDTH_ROAD_BASE: float = 3.0
const MAP_LINE_WIDTH_ROAD_CENTER: float = 1.4
const MAP_LINE_WIDTH_TRADE_SHADOW: float = 5.0
const MAP_LINE_WIDTH_TRADE: float = 2.2

static func get_building_color(building_type: String) -> Color:
	if building_type == "farm":
		return COLOR_BUILDING_FARM
	if building_type == "woodcutter":
		return COLOR_BUILDING_WOODCUTTER
	if building_type == "toolmaker":
		return COLOR_BUILDING_TOOLMAKER

	return COLOR_BUILDING_HOUSE

static func get_preference_color(preference: String) -> Color:
	if preference == "agrarian":
		return COLOR_PREF_AGRARIAN
	if preference == "industrial":
		return COLOR_PREF_INDUSTRIAL

	return COLOR_PREF_NEUTRAL

static func get_walker_color(preference: String) -> Color:
	if preference == "agrarian":
		return COLOR_WALKER_AGRARIAN
	if preference == "industrial":
		return COLOR_WALKER_INDUSTRIAL

	return COLOR_WALKER_NEUTRAL
