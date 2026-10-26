class_name RegionMapStyle
extends RefCounted

# Shared look of the regional map: palette, sizes, and level-of-detail rules.
#
# Map units: one tile is TILE units, the same as main.gd's TILE_SIZE, so a tile coordinate
# means the same thing to the renderer, founding, and the town-map generator.
# Zoom is screen pixels per map unit.

const TILE: float = 12.0
const MAX_ZOOM: float = 6.0
const ZOOM_STEP: float = 1.2
const ZOOM_SMOOTHING: float = 14.0
const KEY_PAN_SPEED_PX: float = 700.0
const DRAG_THRESHOLD_PX: float = 4.0
# Margin around the board when the whole region fits on screen.
const FIT_MARGIN_PX: float = 18.0

# Levels of detail. Below DETAIL_ZOOM only what matters strategically is drawn; shrubs,
# furrows, and planks appear above it, and flowers and pebbles above NEAR_ZOOM.
const DETAIL_ZOOM: float = 2.2
const NEAR_ZOOM: float = 3.6

# Feature layers are split into horizontal strips of this many tile rows so the engine can
# skip strips that are off screen when zoomed in. Full-width strips keep draw order by row.
const STRIP_ROWS: int = 5

# The board: the region is shown as a model landscape on a table.
const COLOR_TABLE: Color = Color(0.11, 0.12, 0.11)
const COLOR_BOARD_SIDE: Color = Color(0.36, 0.27, 0.18)
const COLOR_BOARD_SIDE_DARK: Color = Color(0.25, 0.18, 0.12)
const BOARD_THICKNESS: float = 7.0

const COLOR_SHADOW: Color = Color(0.05, 0.06, 0.03, 0.30)
const COLOR_ROCK_LIGHT: Color = Color(0.70, 0.67, 0.61)
const COLOR_ROCK: Color = Color(0.56, 0.52, 0.46)
const COLOR_ROCK_DARK: Color = Color(0.36, 0.33, 0.30)
const COLOR_SNOW: Color = Color(0.95, 0.96, 0.98)
const COLOR_SNOW_SHADE: Color = Color(0.74, 0.79, 0.86)
const COLOR_STONE_LIGHT: Color = Color(0.82, 0.80, 0.74)
const COLOR_STONE: Color = Color(0.66, 0.64, 0.59)
const COLOR_IRON_DARK: Color = Color(0.33, 0.27, 0.24)
const COLOR_IRON_RUST: Color = Color(0.66, 0.37, 0.20)

const COLOR_ROAD_EDGE: Color = Color(0.38, 0.29, 0.18)
const COLOR_ROAD: Color = Color(0.70, 0.59, 0.41)
const COLOR_ROAD_MAJOR: Color = Color(0.74, 0.66, 0.50)
const COLOR_PATH: Color = Color(0.66, 0.56, 0.38, 0.85)
const COLOR_BRIDGE_DECK: Color = Color(0.56, 0.40, 0.24)
const COLOR_BRIDGE_RAIL: Color = Color(0.32, 0.22, 0.13)
const COLOR_BRIDGE_STONE: Color = Color(0.66, 0.63, 0.57)

const COLOR_WALL_TIMBER: Color = Color(0.86, 0.80, 0.66)
const COLOR_ROOF_THATCH: Color = Color(0.78, 0.65, 0.38)
const COLOR_ROOF_TIMBER: Color = Color(0.52, 0.36, 0.24)
const COLOR_ROOF_TILE: Color = Color(0.66, 0.33, 0.22)
const COLOR_ROOF_SLATE: Color = Color(0.40, 0.43, 0.48)
const COLOR_PLAZA: Color = Color(0.74, 0.67, 0.52)
const COLOR_PALISADE: Color = Color(0.45, 0.33, 0.20)
const COLOR_TOWN_WALL: Color = Color(0.70, 0.67, 0.60)

const COLOR_FIELD_WHEAT: Color = Color(0.83, 0.74, 0.44)
const COLOR_FIELD_GREEN: Color = Color(0.55, 0.65, 0.32)
const COLOR_FIELD_FALLOW: Color = Color(0.58, 0.45, 0.30)
const COLOR_FIELD_PASTURE: Color = Color(0.62, 0.70, 0.40)
const COLOR_QUARRY: Color = Color(0.80, 0.78, 0.72)

const COLOR_LABEL: Color = Color(0.16, 0.13, 0.09)
const COLOR_LABEL_HALO: Color = Color(0.97, 0.94, 0.84, 0.88)
const COLOR_LABEL_WATER: Color = Color(0.13, 0.30, 0.44)
const COLOR_LABEL_EDGE: Color = Color(0.25, 0.20, 0.14)

const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.85)
const COLOR_SITE_VALID: Color = Color(0.36, 0.86, 0.42)
const COLOR_SITE_INVALID: Color = Color(0.95, 0.42, 0.30)
const COLOR_SITE_DOT: Color = Color(0.99, 0.97, 0.80, 0.42)
const COLOR_EXCLUSION: Color = Color(0.80, 0.24, 0.18)
const COLOR_CATCHMENT: Color = Color(1.0, 0.97, 0.85)
const COLOR_PENDING: Color = Color(0.98, 0.80, 0.30)
const COLOR_PLAYER_BANNER: Color = Color(0.86, 0.66, 0.16)
const COLOR_NEUTRAL_BANNER: Color = Color(0.62, 0.64, 0.70)
const COLOR_SELECTION: Color = Color(0.98, 0.86, 0.42)

const COLOR_HUD: Color = Color(0.10, 0.11, 0.10, 0.88)
const COLOR_HUD_BORDER: Color = Color(0.40, 0.42, 0.36)
const COLOR_HUD_TEXT: Color = Color(0.94, 0.93, 0.84)
const COLOR_HUD_MUTED: Color = Color(0.70, 0.70, 0.62)
const COLOR_HUD_BUTTON: Color = Color(0.20, 0.22, 0.20)
const COLOR_HUD_BUTTON_ON: Color = Color(0.28, 0.36, 0.24)

static var _serif: Font = null
static var _serif_italic: Font = null
static var _sans: Font = null

static func serif_font() -> Font:
	if _serif == null:
		_serif = WorldMapStyle.make_system_font(600, false)
	return _serif

static func serif_italic_font() -> Font:
	if _serif_italic == null:
		_serif_italic = WorldMapStyle.make_system_font(400, true)
	return _serif_italic

static func ui_font() -> Font:
	return ThemeDB.fallback_font

static func lod_level(zoom: float) -> int:
	if zoom >= NEAR_ZOOM:
		return 2
	if zoom >= DETAIL_ZOOM:
		return 1
	return 0

static func region_temperature(geography: RegionGeography) -> float:
	return geography.mean_temperature if geography != null else 0.55

static func region_moisture(geography: RegionGeography) -> float:
	return geography.mean_moisture if geography != null else 0.6

static func climate_family(geography: RegionGeography) -> String:
	return geography.climate_family if geography != null else RegionGeography.CLIMATE_TEMPERATE

# Mirrors forest_color() in shaders/natural_palette.gdshaderinc.
static func forest_color(t: float) -> Color:
	var boreal: Color = Color(0.24, 0.35, 0.27)
	var temperate: Color = Color(0.25, 0.40, 0.22)
	var jungle: Color = Color(0.15, 0.36, 0.17)
	var color: Color = boreal.lerp(temperate, smoothstep(0.34, 0.55, t))
	return color.lerp(jungle, smoothstep(0.7, 0.86, t))

# Tree kinds by climate: broadleaf woods, conifer forest, dry scrub, or tall jungle.
static func tree_style(geography: RegionGeography) -> Dictionary:
	var t: float = region_temperature(geography)
	var base: Color = forest_color(t)
	var style: Dictionary = {
		"kind": "broadleaf",
		"conifer_share": 0.18,
		"radius": Vector2(2.5, 3.5),
		"dark": base.darkened(0.30),
		"base": base.lightened(0.04),
		"light": base.lightened(0.30),
	}
	match climate_family(geography):
		RegionGeography.CLIMATE_COLD:
			style["conifer_share"] = 0.85
			style["radius"] = Vector2(2.1, 2.9)
		RegionGeography.CLIMATE_ARID:
			style["kind"] = "scrub"
			style["conifer_share"] = 0.0
			style["radius"] = Vector2(1.7, 2.5)
			style["base"] = Color(0.44, 0.48, 0.26)
			style["dark"] = Color(0.30, 0.33, 0.18)
			style["light"] = Color(0.60, 0.62, 0.36)
		RegionGeography.CLIMATE_TROPICAL:
			style["conifer_share"] = 0.0
			style["radius"] = Vector2(3.0, 4.3)
			style["light"] = base.lightened(0.38)
	return style

# Settlement size bands for drawing. Capital-like importance is not modeled regionally.
const TIER_HAMLET: int = 0
const TIER_VILLAGE: int = 1
const TIER_TOWN: int = 2
const TIER_LARGE_TOWN: int = 3

static func settlement_tier_name(tier: int) -> String:
	match tier:
		TIER_VILLAGE:
			return "village"
		TIER_TOWN:
			return "town"
		TIER_LARGE_TOWN:
			return "large town"
	return "hamlet"

static func faded(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
