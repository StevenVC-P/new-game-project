class_name TerrainVisuals
extends RefCounted

# Terrain visual profiles keep tile appearance separate from generation data.
# Future terrain sprites/tilesets can replace these draw helpers behind the same profile keys.

const TERRAIN_GRASS: String = "grass"
const TERRAIN_FERTILE: String = "fertile"
const TERRAIN_FOREST: String = "forest"
const TERRAIN_WATER: String = "water"
const TERRAIN_HILL: String = "hill"
const TERRAIN_MOUNTAIN: String = "mountain"
const TERRAIN_ROUGH: String = "rough"
const TERRAIN_CLEARING: String = "clearing"

const MOTIF_GRASS: String = "grass"
const MOTIF_FERTILE: String = "fertile"
const MOTIF_FOREST: String = "forest"
const MOTIF_WATER: String = "water"
const MOTIF_HILL: String = "hill"
const MOTIF_MOUNTAIN: String = "mountain"
const MOTIF_ROUGH: String = "rough"
const MOTIF_CLEARING: String = "clearing"

static func draw_region_tile(canvas: CanvasItem, rect: Rect2, tile: Dictionary, tile_pos: Vector2i):
	var profile: Dictionary = get_region_profile(tile)
	draw_profile_tile(canvas, rect, tile_pos, profile)

	if tile["has_forest"] == true:
		draw_forest_overlay(canvas, rect, tile_pos, 0.70)

	var resource: String = tile["resource"] as String
	if resource == "stone":
		draw_stone_deposit(canvas, rect, tile_pos)
	elif resource == "iron":
		draw_iron_deposit(canvas, rect, tile_pos)

static func draw_city_tile(canvas: CanvasItem, rect: Rect2, tile: Dictionary, tile_pos: Vector2i):
	var profile: Dictionary = get_city_profile(tile)
	draw_profile_tile(canvas, rect, tile_pos, profile)

	if tile["has_trees"] == true:
		draw_forest_overlay(canvas, rect, tile_pos, 0.55)

	if tile["type"] == "rough":
		draw_stone_deposit(canvas, rect, tile_pos)

static func get_region_profile(tile: Dictionary) -> Dictionary:
	var tile_type: String = tile["type"] as String
	if tile_type == "river":
		return make_profile(TERRAIN_WATER, VisualStyle.COLOR_TERRAIN_WATER, VisualStyle.COLOR_TERRAIN_WATER_ACCENT, MOTIF_WATER, 0.75, "river_tile")
	if tile_type == "mountain":
		return make_profile(TERRAIN_MOUNTAIN, VisualStyle.COLOR_TERRAIN_MOUNTAIN, VisualStyle.COLOR_TERRAIN_MOUNTAIN_ACCENT, MOTIF_MOUNTAIN, 0.80, "mountain_tile")
	if tile_type == "hill":
		return make_profile(TERRAIN_HILL, VisualStyle.COLOR_TERRAIN_HILL, VisualStyle.COLOR_TERRAIN_HILL_ACCENT, MOTIF_HILL, 0.65, "hill_tile")
	if tile["is_fertile"] == true:
		return make_profile(TERRAIN_FERTILE, VisualStyle.COLOR_TERRAIN_FERTILE, VisualStyle.COLOR_TERRAIN_FERTILE_ACCENT, MOTIF_FERTILE, 0.55, "fertile_tile")

	return make_profile(TERRAIN_GRASS, VisualStyle.COLOR_TERRAIN_GRASS, VisualStyle.COLOR_TERRAIN_GRASS_ACCENT, MOTIF_GRASS, 0.35, "grass_tile")

static func get_city_profile(tile: Dictionary) -> Dictionary:
	var tile_type: String = tile["type"] as String
	if tile_type == "water":
		return make_profile(TERRAIN_WATER, VisualStyle.COLOR_TERRAIN_CITY_WATER, VisualStyle.COLOR_TERRAIN_WATER_ACCENT, MOTIF_WATER, 0.75, "water_tile")
	if tile_type == "clearing":
		return make_profile(TERRAIN_CLEARING, VisualStyle.COLOR_TERRAIN_CLEARING, VisualStyle.COLOR_TERRAIN_CLEARING_ACCENT, MOTIF_CLEARING, 0.30, "clearing_tile")
	if tile_type == "rough":
		return make_profile(TERRAIN_ROUGH, VisualStyle.COLOR_TERRAIN_ROUGH, VisualStyle.COLOR_TERRAIN_ROUGH_ACCENT, MOTIF_ROUGH, 0.60, "rough_tile")
	if tile["is_fertile"] == true:
		return make_profile(TERRAIN_FERTILE, VisualStyle.COLOR_TERRAIN_FERTILE, VisualStyle.COLOR_TERRAIN_FERTILE_ACCENT, MOTIF_FERTILE, 0.45, "fertile_ground_tile")

	return make_profile(TERRAIN_GRASS, VisualStyle.COLOR_TERRAIN_CITY_GRASS, VisualStyle.COLOR_TERRAIN_GRASS_ACCENT, MOTIF_GRASS, 0.25, "ground_tile")

static func make_profile(terrain_type: String, base_color: Color, accent_color: Color, motif: String, density: float, tile_hint: String) -> Dictionary:
	return {
		"type": terrain_type,
		"base_color": base_color,
		"accent_color": accent_color,
		"motif": motif,
		"density": density,
		"tile_hint": tile_hint
	}

static func draw_profile_tile(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	canvas.draw_rect(rect, profile["base_color"] as Color)

	var motif: String = profile["motif"] as String
	if motif == MOTIF_GRASS:
		draw_grass_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_FERTILE:
		draw_fertile_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_WATER:
		draw_water_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_HILL:
		draw_hill_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_MOUNTAIN:
		draw_mountain_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_ROUGH:
		draw_rough_motif(canvas, rect, tile_pos, profile)
	elif motif == MOTIF_CLEARING:
		draw_clearing_motif(canvas, rect, tile_pos, profile)

static func draw_grass_motif(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	if deterministic_value(tile_pos, 3) < 5:
		return

	var accent_color: Color = profile["accent_color"] as Color
	var start: Vector2 = rect.position + Vector2(3.0 + float(deterministic_value(tile_pos, 5) % 4), 8.0)
	canvas.draw_line(start, start + Vector2(1.5, -2.0), accent_color, 1.0)

static func draw_fertile_motif(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var offset: float = float(deterministic_value(tile_pos, 7) % 3)
	canvas.draw_line(rect.position + Vector2(2.0, 4.0 + offset), rect.position + Vector2(rect.size.x - 3.0, 3.0 + offset), accent_color, 1.0)
	canvas.draw_line(rect.position + Vector2(2.0, 8.0 + offset), rect.position + Vector2(rect.size.x - 3.0, 7.0 + offset), accent_color, 1.0)

static func draw_water_motif(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var wave_y: float = rect.position.y + 4.0 + float(deterministic_value(tile_pos, 11) % 3)
	canvas.draw_line(Vector2(rect.position.x + 2.0, wave_y), Vector2(rect.position.x + rect.size.x - 3.0, wave_y + 1.0), accent_color, 1.0)

static func draw_hill_motif(canvas: CanvasItem, rect: Rect2, _tile_pos: Vector2i, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var center_x: float = rect.position.x + rect.size.x * 0.50
	var base_y: float = rect.position.y + rect.size.y * 0.68
	canvas.draw_arc(Vector2(center_x, base_y), rect.size.x * 0.32, PI, TAU, 8, accent_color, 1.0)

static func draw_mountain_motif(canvas: CanvasItem, rect: Rect2, _tile_pos: Vector2i, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var peak: Vector2 = rect.position + Vector2(rect.size.x * 0.50, 2.0)
	var left: Vector2 = rect.position + Vector2(2.0, rect.size.y - 3.0)
	var right: Vector2 = rect.position + Vector2(rect.size.x - 3.0, rect.size.y - 3.0)
	canvas.draw_line(left, peak, accent_color, 1.0)
	canvas.draw_line(peak, right, accent_color, 1.0)

static func draw_rough_motif(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	var accent_color: Color = profile["accent_color"] as Color
	var center: Vector2 = rect.position + Vector2(4.0 + float(deterministic_value(tile_pos, 13) % 4), 5.0)
	canvas.draw_circle(center, 1.4, accent_color)
	canvas.draw_circle(center + Vector2(3.0, 2.0), 1.0, accent_color)

static func draw_clearing_motif(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, profile: Dictionary):
	if deterministic_value(tile_pos, 17) < 6:
		return

	var accent_color: Color = profile["accent_color"] as Color
	canvas.draw_circle(rect.position + Vector2(rect.size.x * 0.50, rect.size.y * 0.55), 1.2, accent_color)

static func draw_forest_overlay(canvas: CanvasItem, rect: Rect2, tile_pos: Vector2i, scale: float):
	var base_radius: float = max(1.6, rect.size.x * 0.16 * scale)
	var centers: Array[Vector2] = [
		rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.45),
		rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.36),
		rect.position + Vector2(rect.size.x * 0.52, rect.size.y * 0.64)
	]

	for center_index in range(centers.size()):
		if deterministic_value(tile_pos, center_index + 21) < 2:
			continue
		var center: Vector2 = centers[center_index]
		canvas.draw_circle(center, base_radius, VisualStyle.COLOR_TERRAIN_FOREST)
		canvas.draw_circle(center + Vector2(0.0, -0.8), max(1.0, base_radius - 0.8), VisualStyle.COLOR_TERRAIN_FOREST_ACCENT)

static func draw_stone_deposit(canvas: CanvasItem, rect: Rect2, _tile_pos: Vector2i):
	var center: Vector2 = rect.position + Vector2(rect.size.x * 0.40, rect.size.y * 0.42)
	canvas.draw_circle(center, 2.0, VisualStyle.COLOR_RESOURCE_STONE_LIGHT)
	canvas.draw_circle(center + Vector2(3.0, 2.5), 1.4, VisualStyle.COLOR_RESOURCE_STONE_DARK)

static func draw_iron_deposit(canvas: CanvasItem, rect: Rect2, _tile_pos: Vector2i):
	var center: Vector2 = rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.45)
	canvas.draw_circle(center, 2.1, VisualStyle.COLOR_RESOURCE_IRON_DARK)
	canvas.draw_circle(center + Vector2(2.5, 2.4), 1.3, VisualStyle.COLOR_RESOURCE_IRON_LIGHT)

static func deterministic_value(tile_pos: Vector2i, salt: int) -> int:
	var value: int = tile_pos.x * 928371 + tile_pos.y * 364479 + salt * 1097
	value = abs(value)
	return value % 10
