class_name TownMapStyle
extends RefCounted

# Shared look of the town map: sizes, zoom rules, and the colors of what a town builds. Natural
# colors and the building style come from the regional map (RegionMapStyle, LandscapePainter,
# BuildingPainter), so a town reads as its regional landscape magnified.
#
# Map units: one town tile is TILE units, the same as main.gd's CITY_TILE_SIZE. Zoom is screen
# pixels per map unit.

const TILE: float = 12.0
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 1.2
const ZOOM_SMOOTHING: float = 14.0
const KEY_PAN_SPEED_PX: float = 700.0
const DRAG_THRESHOLD_PX: float = 4.0
const FIT_MARGIN_PX: float = 18.0
const BOARD_THICKNESS: float = 9.0

# Levels of detail: shrubs, doors, and furrow lines from DETAIL_ZOOM; flowers, planks, and
# small props from NEAR_ZOOM. The fitted view of a 1600x900 window is about 1.5.
const DETAIL_ZOOM: float = 2.0
const NEAR_ZOOM: float = 3.2

# Trees here stand four times closer than on the regional map, so a crown spans about a tile.
const TREE_SCALE: float = 1.7

const COLOR_YARD: Color = Color(0.60, 0.52, 0.36, 0.55)
const COLOR_YARD_EDGE: Color = Color(0.48, 0.40, 0.27, 0.45)
const COLOR_EARTH: Color = Color(0.52, 0.42, 0.29)
const COLOR_EARTH_DARK: Color = Color(0.40, 0.31, 0.21)
const COLOR_TIMBER: Color = Color(0.50, 0.35, 0.21)
const COLOR_TIMBER_DARK: Color = Color(0.33, 0.22, 0.13)
const COLOR_LOG_END: Color = Color(0.80, 0.64, 0.42)
const COLOR_BRICK: Color = Color(0.68, 0.33, 0.22)
const COLOR_TILE_ORANGE: Color = Color(0.78, 0.45, 0.25)
const COLOR_LIME: Color = Color(0.90, 0.89, 0.84)
const COLOR_SMOKE: Color = Color(0.86, 0.86, 0.84, 0.42)
const COLOR_DOOR: Color = Color(0.28, 0.19, 0.12)
const COLOR_WINDOW: Color = Color(0.22, 0.20, 0.18)
const COLOR_TENT: Color = Color(0.84, 0.78, 0.62)
const COLOR_TENT_SHADE: Color = Color(0.66, 0.59, 0.44)

const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.75)
const COLOR_SELECTION: Color = Color(0.98, 0.86, 0.42)
const COLOR_VALID: Color = Color(0.36, 0.86, 0.42)
const COLOR_INVALID: Color = Color(0.95, 0.36, 0.28)
const COLOR_LINK: Color = Color(0.98, 0.84, 0.32, 0.95)
const COLOR_BADGE_RIM: Color = Color(0.12, 0.10, 0.08)
const COLOR_VACANT: Color = Color(0.86, 0.30, 0.22)
const COLOR_PLATE: Color = Color(0.10, 0.09, 0.07, 0.78)
const COLOR_SKIN: Color = Color(0.90, 0.74, 0.60)

static func lod_level(zoom: float) -> int:
	if zoom >= NEAR_ZOOM:
		return 2
	if zoom >= DETAIL_ZOOM:
		return 1
	return 0

# A family's preference shown in the town: the sidebar's colors, toned down to sit on the land.
static func preference_color(preference: String) -> Color:
	return VisualStyle.get_preference_color(preference).darkened(0.18)

static func tile_rect(tile: Vector2i, size: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(tile) * TILE, Vector2(size) * TILE)
