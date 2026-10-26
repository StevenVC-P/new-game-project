class_name RegionStructureLayer
extends RegionMapLayer

# Built things: roads by class, bridges at river crossings, and settlements as clusters of
# miniature buildings. One early-to-late medieval building style throughout.

const YARD_COLOR: Color = Color(0.62, 0.56, 0.38, 0.22)

func on_lod_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if view == null:
		return
	var shapes: RegionMapGeometry = geometry()
	for road: RegionMapGeometry.RoadShape in shapes.roads:
		if not road.is_context:
			draw_road(road)
	for bridge: RegionMapGeometry.BridgeShape in shapes.bridges:
		draw_bridge(bridge)
	for settlement: RegionMapGeometry.SettlementShape in shapes.settlements:
		draw_settlement(settlement)

# --- Roads -------------------------------------------------------------------------

func draw_road(road: RegionMapGeometry.RoadShape) -> void:
	var half_width: float = RegionMapGeometry.ROAD_HALF_WIDTHS[road.road_class]
	match road.road_class:
		RegionMapGeometry.ROAD_MAJOR:
			draw_polyline(road.points, RegionMapStyle.COLOR_ROAD_EDGE, half_width * 2.0 + 0.9, true)
			draw_polyline(road.points, RegionMapStyle.COLOR_ROAD_MAJOR, half_width * 2.0, true)
			if lod >= 1:
				draw_polyline(road.points, RegionMapStyle.COLOR_ROAD_MAJOR.lightened(0.15), 0.5, true)
		RegionMapGeometry.ROAD_ROAD:
			draw_polyline(road.points, RegionMapStyle.COLOR_ROAD_EDGE, half_width * 2.0 + 0.7, true)
			draw_polyline(road.points, RegionMapStyle.COLOR_ROAD, half_width * 2.0, true)
		_:
			draw_polyline(road.points, RegionMapStyle.COLOR_PATH, half_width * 2.0, true)
	for end_point: Vector2 in [road.points[0], road.points[road.points.size() - 1]]:
		draw_circle(end_point, half_width, RegionMapStyle.COLOR_PATH if road.road_class == RegionMapGeometry.ROAD_PATH else RegionMapStyle.COLOR_ROAD)

func draw_bridge(bridge: RegionMapGeometry.BridgeShape) -> void:
	var half: Vector2 = Vector2(bridge.length * 0.5, bridge.width * 0.5)
	draw_colored_polygon(rotated_rect(bridge.center + Vector2(0.9, 1.1), half, bridge.angle), Color(0.03, 0.08, 0.10, 0.35))
	var deck: Color = RegionMapStyle.COLOR_BRIDGE_STONE if bridge.is_stone else RegionMapStyle.COLOR_BRIDGE_DECK
	draw_colored_polygon(rotated_rect(bridge.center, half, bridge.angle), deck)
	var axis: Vector2 = Vector2(cos(bridge.angle), sin(bridge.angle))
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var rail: Color = deck.darkened(0.45) if bridge.is_stone else RegionMapStyle.COLOR_BRIDGE_RAIL
	for side: float in [-1.0, 1.0]:
		var offset: Vector2 = across * half.y * side
		draw_line(bridge.center - axis * half.x + offset, bridge.center + axis * half.x + offset, rail, 0.55, true)
	if lod >= 1 and not bridge.is_stone:
		var planks: int = int(bridge.length / 0.8)
		for i in range(1, planks):
			var along: Vector2 = axis * (-half.x + bridge.length * i / planks)
			draw_line(bridge.center + along - across * half.y, bridge.center + along + across * half.y, Color(0.36, 0.25, 0.15, 0.6), 0.2)

# --- Settlements ------------------------------------------------------------------

func draw_settlement(settlement: RegionMapGeometry.SettlementShape) -> void:
	# Trodden yards and gardens around each house make even a hamlet read as a settled spot.
	# Buildings stand only on open land, so their yards never spread over water.
	for building: RegionMapGeometry.BuildingShape in settlement.buildings:
		draw_blob(self, building.position + Vector2(0.4, 0.6), Vector2(4.4, 3.8), YARD_COLOR, 12)
	if settlement.plaza_radius > 0.0:
		draw_blob(self, settlement.center, Vector2(settlement.plaza_radius, settlement.plaza_radius * 0.9), RegionMapStyle.COLOR_PLAZA, 14)
	else:
		draw_blob(self, settlement.center, Vector2(2.8, 2.4), RegionMapStyle.COLOR_PATH, 10)
	if settlement.enclosure == "palisade":
		draw_arc(settlement.center + Vector2(0.5, 0.7), settlement.enclosure_radius, 0.0, TAU, 64, RegionMapStyle.COLOR_SHADOW, 1.4, true)
		draw_arc(settlement.center, settlement.enclosure_radius, 0.0, TAU, 64, RegionMapStyle.COLOR_PALISADE, 1.1, true)
		if lod >= 1:
			var posts: int = int(TAU * settlement.enclosure_radius / 1.6)
			for i in range(posts):
				var angle: float = TAU * i / posts
				draw_circle(settlement.center + Vector2(cos(angle), sin(angle)) * settlement.enclosure_radius, 0.55, RegionMapStyle.COLOR_PALISADE.darkened(0.25))
	var ordered: Array[RegionMapGeometry.BuildingShape] = settlement.buildings.duplicate()
	ordered.sort_custom(func(a: RegionMapGeometry.BuildingShape, b: RegionMapGeometry.BuildingShape) -> bool: return a.position.y < b.position.y)
	for building: RegionMapGeometry.BuildingShape in ordered:
		draw_building(building)
	if settlement.enclosure == "wall":
		draw_town_wall(settlement)
	if settlement.is_player:
		draw_banner(settlement.center + Vector2(0.0, -1.0), RegionMapStyle.COLOR_PLAYER_BANNER)

# A building seen from above: its gable roof, lit on the side facing the light.
func draw_building(building: RegionMapGeometry.BuildingShape) -> void:
	var half: Vector2 = building.size * 0.5
	var height_offset: Vector2 = Vector2(1.0, 1.2) * (1.6 if building.kind == "church" else 1.0)
	var wall: Color = RegionMapStyle.COLOR_TOWN_WALL if building.kind == "church" else RegionMapStyle.COLOR_WALL_TIMBER
	BuildingPainter.draw_gabled(self, building.position, building.size, building.angle, building.roof, wall, height_offset, 0.9, 0.35)
	var axis: Vector2 = Vector2(cos(building.angle), sin(building.angle))
	if building.kind == "church":
		var tower: Vector2 = building.position + axis * (half.x + 0.9)
		draw_colored_polygon(rotated_rect(tower + Vector2(1.6, 2.0), Vector2(1.2, 1.2), building.angle), RegionMapStyle.COLOR_SHADOW)
		draw_colored_polygon(rotated_rect(tower, Vector2(1.2, 1.2), building.angle), RegionMapStyle.COLOR_TOWN_WALL.darkened(0.15))
		draw_blob(self, tower + Vector2(-0.25, -0.3), Vector2(0.75, 0.75), RegionMapStyle.COLOR_ROOF_SLATE.lightened(0.2), 6)

func draw_town_wall(settlement: RegionMapGeometry.SettlementShape) -> void:
	var radius: float = settlement.enclosure_radius
	draw_arc(settlement.center + Vector2(0.6, 0.8), radius, 0.0, TAU, 64, RegionMapStyle.COLOR_SHADOW, 1.8, true)
	draw_arc(settlement.center, radius, 0.0, TAU, 64, RegionMapStyle.COLOR_TOWN_WALL, 1.4, true)
	for i in range(8):
		var angle: float = TAU * i / 8.0 + 0.2
		var tower: Vector2 = settlement.center + Vector2(cos(angle), sin(angle)) * radius
		draw_blob(self, tower + Vector2(0.5, 0.6), Vector2(1.4, 1.2), RegionMapStyle.COLOR_SHADOW, 8)
		draw_blob(self, tower, Vector2(1.3, 1.3), RegionMapStyle.COLOR_TOWN_WALL.lightened(0.1), 8)

func draw_banner(base: Vector2, color: Color) -> void:
	var top: Vector2 = base + Vector2(0.0, -7.0)
	draw_line(base + Vector2(1.2, 1.0), top + Vector2(4.0, 3.5), RegionMapStyle.COLOR_SHADOW, 0.6)
	draw_line(base, top, Color(0.22, 0.17, 0.12), 0.5, true)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(4.2, 1.2), top + Vector2(0.0, 2.6)]), color)
