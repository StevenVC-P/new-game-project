class_name WorldMapStyle
extends RefCounted

# Visual language and level-of-detail rules for the world map, shared by every layer
# so icons, labels, and their collision boxes agree on what is visible at a zoom.
# Zoom is screen pixels per world unit (the full planet is about 0.17 on a 1280px window).

const COLOR_BACKGROUND: Color = Color(0.05, 0.08, 0.11)
const COLOR_INK: Color = Color(0.20, 0.15, 0.11)
const COLOR_PARCHMENT: Color = Color(0.97, 0.94, 0.85)
const COLOR_RIVER: Color = Color(0.30, 0.49, 0.62)
const COLOR_RIVER_EDGE: Color = Color(0.20, 0.33, 0.42)
const COLOR_ROAD_MAJOR_CASING: Color = Color(0.38, 0.18, 0.12)
const COLOR_ROAD_MAJOR: Color = Color(0.80, 0.55, 0.38)
const COLOR_ROAD_REGIONAL: Color = Color(0.44, 0.27, 0.17)
const COLOR_ROAD_LOCAL: Color = Color(0.40, 0.30, 0.22)
const COLOR_URBAN: Color = Color(0.70, 0.62, 0.53)
const COLOR_URBAN_EDGE: Color = Color(0.38, 0.30, 0.24)
const COLOR_URBAN_CORE: Color = Color(0.60, 0.40, 0.32)
const COLOR_WALL: Color = Color(0.84, 0.80, 0.70)
const COLOR_WALL_SHADE: Color = Color(0.64, 0.60, 0.52)
const COLOR_ROOF: Color = Color(0.68, 0.31, 0.21)
const COLOR_ROOF_DARK: Color = Color(0.52, 0.24, 0.18)
const COLOR_PLASTER: Color = Color(0.93, 0.88, 0.75)
const COLOR_INDEPENDENT: Color = Color(0.86, 0.80, 0.66)
const COLOR_HOVER: Color = Color(1.0, 0.93, 0.62)
const COLOR_SELECTED: Color = Color(0.98, 0.78, 0.28)
const COLOR_LABEL_SETTLEMENT: Color = Color(0.13, 0.10, 0.08)
const COLOR_LABEL_REGION: Color = Color(0.22, 0.19, 0.15)
const COLOR_LABEL_LANDFORM: Color = Color(0.33, 0.22, 0.13)
const COLOR_LABEL_OCEAN: Color = Color(0.80, 0.88, 0.94)
const COLOR_LABEL_SEA: Color = Color(0.86, 0.93, 0.97)
const COLOR_LABEL_CONTINENT: Color = Color(0.20, 0.17, 0.13)

const MIN_ZOOM_FALLBACK: float = 0.15
const MAX_ZOOM: float = 4.0

static var _serif: Font = null
static var _serif_bold: Font = null
static var _serif_italic: Font = null

static func serif_font() -> Font:
	if _serif == null:
		_serif = make_system_font(400, false)
	return _serif

static func serif_bold_font() -> Font:
	if _serif_bold == null:
		_serif_bold = make_system_font(700, false)
	return _serif_bold

static func serif_italic_font() -> Font:
	if _serif_italic == null:
		_serif_italic = make_system_font(400, true)
	return _serif_italic

# Atlas lettering uses an installed book face; SystemFont falls back to the default font
# when none of these exist, so no font files ship with the project.
static func make_system_font(weight: int, italic: bool) -> Font:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "Cambria", "Times New Roman", "serif"])
	font.font_weight = weight
	font.font_italic = italic
	font.fallbacks = [ThemeDB.fallback_font]
	return font

static func fade(zoom: float, start: float, full: float) -> float:
	if full < start:
		return 1.0 - smoothstep(full, start, zoom)
	return smoothstep(start, full, zoom)

# --- Settlements -----------------------------------------------------------

static func settlement_visibility(settlement: WorldMapData.Settlement, zoom: float) -> float:
	if settlement.is_capital or settlement.tier >= WorldMapData.TIER_GREAT_CITY:
		return 1.0
	match settlement.tier:
		WorldMapData.TIER_CITY:
			return fade(zoom, 0.2, 0.28)
		WorldMapData.TIER_TOWN:
			return fade(zoom, 0.36, 0.5)
	return fade(zoom, 0.75, 1.0)

# Icon half-size in screen pixels; icons grow gently as the player zooms in.
static func settlement_icon_radius(settlement: WorldMapData.Settlement, zoom: float) -> float:
	var base: float = 7.0
	match settlement.tier:
		WorldMapData.TIER_GREAT_CITY:
			base = 14.0
		WorldMapData.TIER_CITY:
			base = 11.5
		WorldMapData.TIER_TOWN:
			base = 9.0
	return base * clampf(0.85 + 0.2 * zoom, 0.9, 1.5)

# Exaggerated urban footprint radius in world units, from population.
static func footprint_radius(settlement: WorldMapData.Settlement) -> float:
	return 1.5 + sqrt(float(settlement.population)) * 0.045

# Farmland worked from a settlement, in world units; drawn by the terrain shader.
static func cultivation_radius(settlement: WorldMapData.Settlement) -> float:
	return 5.0 + sqrt(float(settlement.population)) * 0.09

static func footprint_visibility(zoom: float) -> float:
	return fade(zoom, 0.85, 1.35)

static func settlement_label_size(settlement: WorldMapData.Settlement) -> int:
	match settlement.tier:
		WorldMapData.TIER_GREAT_CITY:
			return 15
		WorldMapData.TIER_CITY:
			return 13
		WorldMapData.TIER_TOWN:
			return 12
	return 11

# --- Roads and rivers ------------------------------------------------------

static func road_visibility(road_class: int, zoom: float) -> float:
	match road_class:
		WorldMapData.ROAD_MAJOR:
			return lerpf(0.4, 1.0, fade(zoom, 0.22, 0.4))
		WorldMapData.ROAD_REGIONAL:
			return fade(zoom, 0.32, 0.5)
	return fade(zoom, 0.7, 1.0)

# Screen-pixel widths: major routes read as a cased highway, regional roads as a solid
# line, local roads as a thin dashed track.
static func road_width_px(road_class: int, zoom: float) -> float:
	var growth: float = clampf(0.75 + 0.3 * zoom, 0.8, 1.7)
	match road_class:
		WorldMapData.ROAD_MAJOR:
			return 2.0 * growth
		WorldMapData.ROAD_REGIONAL:
			return 1.4 * growth
	return 1.0 * growth

static func river_visibility(river: WorldMapData.River, zoom: float) -> float:
	if river.is_major:
		return 1.0
	return fade(zoom, 0.3, 0.5)

# --- Labels ----------------------------------------------------------------

static func kingdom_label_visibility(zoom: float) -> float:
	return 1.0 - smoothstep(0.75, 1.1, zoom)

static func region_label_visibility(zoom: float) -> float:
	return fade(zoom, 0.55, 0.75)

static func geo_label_visibility(kind: String, zoom: float) -> float:
	match kind:
		WorldMapData.LABEL_CONTINENT:
			return 1.0 - smoothstep(0.22, 0.32, zoom)
		WorldMapData.LABEL_OCEAN:
			return 1.0 - smoothstep(0.7, 1.0, zoom)
		WorldMapData.LABEL_SEA:
			return fade(zoom, 0.22, 0.32) * (1.0 - smoothstep(2.2, 3.0, zoom))
	return fade(zoom, 0.25, 0.4) * (1.0 - smoothstep(1.8, 2.6, zoom))

static func kingdom_color(data: WorldMapData, kingdom_id: int) -> Color:
	var kingdom: WorldMapData.Kingdom = data.get_kingdom(kingdom_id)
	if kingdom == null:
		return COLOR_INDEPENDENT
	return kingdom.color
