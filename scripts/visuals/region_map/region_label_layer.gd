class_name RegionLabelLayer
extends RegionMapLayer

# Names on the board at a constant screen size: settlements, the world's river and lake,
# and where roads leave the region toward the world's towns.

const SETTLEMENT_FONT_SIZE: int = 15
const WATER_FONT_SIZE: int = 14
const EDGE_FONT_SIZE: int = 12

func set_view_zoom(new_zoom: float) -> void:
	super.set_view_zoom(new_zoom)
	queue_redraw()

func _draw() -> void:
	if view == null or not view.show_labels or view.map_size == Vector2i.ZERO:
		return
	draw_water_labels()
	for road: RegionMapGeometry.RoadShape in view.geometry.roads:
		if road.toward != "":
			draw_edge_label(road)
	for settlement: RegionMapGeometry.SettlementShape in view.geometry.settlements:
		var below: Vector2 = settlement.center + Vector2(0.0, maxf(settlement.enclosure_radius, 6.0) + 2.0)
		var color: Color = Color(0.40, 0.26, 0.04) if settlement.is_player else RegionMapStyle.COLOR_LABEL
		draw_label(below, settlement.name, RegionMapStyle.serif_font(), SETTLEMENT_FONT_SIZE, color, 0.0, Vector2(0.0, 12.0))
	draw_set_transform(Vector2.ZERO)

# Text centered at a map position, drawn at screen size; offset is in screen pixels.
func draw_label(map_position: Vector2, text: String, font: Font, font_size: int, color: Color, angle: float, offset: Vector2) -> void:
	var scale: float = 1.0 / maxf(zoom, 0.01)
	draw_set_transform(map_position, angle, Vector2(scale, scale))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: Vector2 = offset + Vector2(-width * 0.5, font.get_ascent(font_size) * 0.35)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, RegionMapStyle.COLOR_LABEL_HALO)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_water_labels() -> void:
	var geography: RegionGeography = view.geography
	if geography == null:
		return
	var tile_size: float = RegionMapStyle.TILE
	for river: RegionGeography.RiverPath in geography.rivers:
		var placement: Vector3 = river_label_placement(river)
		if placement.z < 0.0:
			continue
		var angle: float = wrapf(placement.z, -PI * 0.5, PI * 0.5)
		draw_label(Vector2(placement.x, placement.y) * tile_size, river.name,RegionMapStyle.serif_italic_font(), WATER_FONT_SIZE, RegionMapStyle.COLOR_LABEL_WATER, angle, Vector2(0.0, -14.0))
	if geography.lake_name != "":
		var sum: Vector2 = Vector2.ZERO
		var count: int = 0
		for y in range(view.map_size.y):
			for x in range(view.map_size.x):
				if view.tiles[y][x]["type"] == "lake":
					sum += Vector2(x + 0.5, y + 0.5)
					count += 1
		if count > 6:
			draw_label(sum / count * tile_size, geography.lake_name, RegionMapStyle.serif_italic_font(), WATER_FONT_SIZE, RegionMapStyle.COLOR_LABEL_WATER, 0.0, Vector2.ZERO)

# Midpoint (tile coordinates) and direction of the longest stretch of the river on the map;
# z is -1 when the river barely touches the map.
func river_label_placement(river: RegionGeography.RiverPath) -> Vector3:
	var bounds: Rect2 = Rect2(Vector2(4.0, 4.0), Vector2(view.map_size) - Vector2(8.0, 8.0))
	var inside: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in river.points:
		if bounds.has_point(point):
			inside.append(point)
	if inside.size() < 4:
		return Vector3(0.0, 0.0, -1.0)
	var middle: int = inside.size() / 2
	var direction: Vector2 = inside[mini(middle + 2, inside.size() - 1)] - inside[maxi(middle - 2, 0)]
	return Vector3(inside[middle].x, inside[middle].y, direction.angle())

# "to Port Brannoch" just inside the edge where a road leaves the region.
func draw_edge_label(road: RegionMapGeometry.RoadShape) -> void:
	var extent: Vector2 = map_extent()
	var inward: Vector2 = Vector2.ZERO
	if road.edge_point.x <= 0.0:
		inward = Vector2.RIGHT
	elif road.edge_point.x >= extent.x:
		inward = Vector2.LEFT
	elif road.edge_point.y <= 0.0:
		inward = Vector2.DOWN
	else:
		inward = Vector2.UP
	var anchor: Vector2 = road.edge_point.clamp(Vector2.ZERO, extent)
	var font: Font = RegionMapStyle.serif_italic_font()
	var text: String = "to " + road.toward
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, EDGE_FONT_SIZE).x
	# Keep the whole label on the board, beside the road rather than on it.
	var offset: Vector2 = inward * (width * 0.5 + 10.0) if inward.x != 0.0 else inward * 14.0 + Vector2(width * 0.5 + 8.0, 0.0)
	var screen_scale: float = 1.0 / maxf(zoom, 0.01)
	var half_screen: Vector2 = Vector2(width * 0.5 + 4.0, 10.0) * screen_scale
	var position: Vector2 = (anchor + offset * screen_scale).clamp(half_screen, extent - half_screen)
	draw_label(position, text, font, EDGE_FONT_SIZE, RegionMapStyle.COLOR_LABEL_EDGE, 0.0, Vector2.ZERO)
