class_name RegionWorldLabelLayer
extends RegionLabelLayer

# Names on the continuous regional map, at a constant screen size: the world settlements the
# chunks draw, the world's rivers and lakes in view, and, from afar, the regions. The game's
# own towns in the neighbourhood are named by the view's RegionLabelLayer.

const REGION_FONT_SIZE: int = 17
# Below this zoom the map reads as a landscape of regions, so they are named.
const REGION_LABEL_ZOOM: float = 0.9

func _draw() -> void:
	if view == null or view.terrain == null or not view.show_labels:
		return
	var visible: Rect2 = view.visible_map_rect()
	var terrain: RegionalTerrain = view.terrain
	var planet: float = terrain.size_tiles.x * RegionMapStyle.TILE
	var tile_size: float = RegionMapStyle.TILE
	var serif: Font = RegionMapStyle.serif_font()
	var italic: Font = RegionMapStyle.serif_italic_font()

	for entry: Array in view.streamer.settlement_shapes():
		var settlement: RegionMapGeometry.SettlementShape = entry[0]
		var below: Vector2 = settlement.center + (entry[1] as Vector2) + Vector2(0.0, maxf(settlement.enclosure_radius, 6.0) + 2.0)
		draw_label(below, settlement.name, serif, SETTLEMENT_FONT_SIZE, RegionMapStyle.COLOR_LABEL, 0.0, Vector2(0.0, 12.0))

	var inner: Rect2 = visible.grow(-maxf(visible.size.x, visible.size.y) * 0.08)
	for line: RegionalTerrain.Polyline in terrain.water_lines:
		if line.kind != RegionalTerrain.LINE_RIVER or line.name == "":
			continue
		var placement: Vector3 = river_placement(line, inner, planet)
		if placement.z > -10.0:
			draw_label(Vector2(placement.x, placement.y), line.name, italic, WATER_FONT_SIZE, RegionMapStyle.COLOR_LABEL_WATER, wrapf(placement.z, -PI * 0.5, PI * 0.5), Vector2(0.0, -14.0))

	for lake: WorldMapData.Lake in terrain.world.lakes:
		var center: Vector2 = terrain.world_to_tile(lake.center) * tile_size
		center.x += roundf((visible.get_center().x - center.x) / planet) * planet
		if visible.has_point(center):
			draw_label(center, lake.name, italic, WATER_FONT_SIZE, RegionMapStyle.COLOR_LABEL_WATER, 0.0, Vector2.ZERO)

	if zoom < REGION_LABEL_ZOOM:
		var fade: float = 1.0 - smoothstep(REGION_LABEL_ZOOM * 0.8, REGION_LABEL_ZOOM, zoom)
		var color: Color = faded(RegionMapStyle.COLOR_LABEL_EDGE, fade)
		for region: WorldMapData.Region in terrain.world.regions:
			var center: Vector2 = terrain.world_to_tile(region.centroid) * tile_size
			center.x += roundf((visible.get_center().x - center.x) / planet) * planet
			if visible.has_point(center):
				draw_label(center, region.name.to_upper(), serif, REGION_FONT_SIZE, color, 0.0, Vector2(0.0, -24.0))
	draw_set_transform(Vector2.ZERO)

# Where to name a river: the point of its course in view nearest the middle of the view,
# with the course's direction there; z below -10 when the river is not in view.
func river_placement(line: RegionalTerrain.Polyline, inner: Rect2, planet: float) -> Vector3:
	var center: Vector2 = inner.get_center()
	var best: int = -1
	var best_distance: float = INF
	var best_point: Vector2 = Vector2.ZERO
	for i in range(1, line.points.size() - 1):
		var point: Vector2 = line.points[i] * RegionMapStyle.TILE
		point.x += roundf((center.x - point.x) / planet) * planet
		if not inner.has_point(point):
			continue
		var distance: float = point.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = i
			best_point = point
	if best < 0:
		return Vector3(0.0, 0.0, -100.0)
	var direction: Vector2 = line.points[mini(best + 2, line.points.size() - 1)] - line.points[maxi(best - 2, 0)]
	return Vector3(best_point.x, best_point.y, direction.angle())
