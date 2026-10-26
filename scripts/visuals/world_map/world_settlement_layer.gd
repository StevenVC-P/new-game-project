class_name WorldSettlementLayer
extends WorldMapLayer

# Settlements in two passes. The footprint pass draws built-up land in world units, so a
# great city visibly covers more ground than a village; it sits under the roads. The icon
# pass draws illustrated symbols at a steady screen size above the roads.

enum Pass { FOOTPRINTS, ICONS }

const FOOTPRINT_POINTS: int = 32
const BLOCK_SPACING: float = 1.7

var pass_kind: Pass = Pass.ICONS
var hovered_settlement_id: int = -1
var selected_settlement_id: int = -1
# Directions of roads leaving each settlement; towns stretch out along them.
var road_angles: Dictionary = {}

func setup(world_data: WorldMapData) -> void:
	data = world_data
	rebuild_road_angles()
	queue_redraw()

func rebuild_road_angles() -> void:
	road_angles.clear()
	for road: WorldMapData.Road in data.roads:
		if road.points.size() < 2:
			continue
		add_road_angle(road.from_settlement_id, road.points[0], road.points[mini(2, road.points.size() - 1)])
		var last: int = road.points.size() - 1
		add_road_angle(road.to_settlement_id, road.points[last], road.points[maxi(last - 2, 0)])

func add_road_angle(settlement_id: int, from: Vector2, toward: Vector2) -> void:
	if not road_angles.has(settlement_id):
		road_angles[settlement_id] = PackedFloat32Array()
	var angles: PackedFloat32Array = road_angles[settlement_id]
	angles.append((toward - from).angle())
	road_angles[settlement_id] = angles

func set_highlight(hovered_id: int, selected_id: int) -> void:
	if hovered_id == hovered_settlement_id and selected_id == selected_settlement_id:
		return
	hovered_settlement_id = hovered_id
	selected_settlement_id = selected_id
	if pass_kind == Pass.ICONS:
		queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	# Footprints are world-sized; they only need redrawing while fading in or out.
	if pass_kind == Pass.FOOTPRINTS:
		var was_visible: float = WorldMapStyle.footprint_visibility(zoom)
		var now_visible: float = WorldMapStyle.footprint_visibility(new_zoom)
		zoom = new_zoom
		if not is_equal_approx(was_visible, now_visible):
			queue_redraw()
		return
	super.set_view_zoom(new_zoom)

func draw_world() -> void:
	if pass_kind == Pass.FOOTPRINTS:
		var visibility: float = WorldMapStyle.footprint_visibility(zoom)
		if visibility <= 0.01:
			return
		for settlement: WorldMapData.Settlement in data.settlements:
			draw_footprint(settlement, visibility)
		return

	# Smaller settlements first so cities sit on top where icons touch.
	for tier in range(WorldMapData.TIER_VILLAGE, WorldMapData.TIER_GREAT_CITY + 1):
		for settlement: WorldMapData.Settlement in data.settlements:
			if settlement.tier == tier:
				draw_settlement_icon(settlement)
	draw_set_transform(draw_offset)

func draw_settlement_icon(settlement: WorldMapData.Settlement) -> void:
	var visibility: float = WorldMapStyle.settlement_visibility(settlement, zoom)
	if visibility <= 0.02:
		return
	var icon_scale: float = WorldMapStyle.settlement_icon_radius(settlement, zoom) / zoom
	draw_set_transform(draw_offset + settlement.position, 0.0, Vector2(icon_scale, icon_scale))
	var highlight: Color = Color(0, 0, 0, 0)
	if settlement.id == selected_settlement_id:
		highlight = WorldMapStyle.COLOR_SELECTED
	elif settlement.id == hovered_settlement_id:
		highlight = WorldMapStyle.COLOR_HOVER
	SettlementIconPainter.draw_icon(self, settlement, WorldMapStyle.kingdom_color(data, settlement.kingdom_id), visibility, highlight)

func draw_footprint(settlement: WorldMapData.Settlement, visibility: float) -> void:
	var radius: float = WorldMapStyle.footprint_radius(settlement)
	var phase: float = float(settlement.id) * 1.37
	var angles: PackedFloat32Array = road_angles.get(settlement.id, PackedFloat32Array())
	var outline: PackedVector2Array = PackedVector2Array()
	var core: PackedVector2Array = PackedVector2Array()
	for k in range(FOOTPRINT_POINTS):
		var theta: float = TAU * k / FOOTPRINT_POINTS
		var r: float = radius * footprint_shape(theta, phase)
		var ribbon: float = 0.0
		for road_angle: float in angles:
			ribbon = maxf(ribbon, pow(maxf(0.0, cos(theta - road_angle)), 12.0))
		var direction: Vector2 = Vector2(cos(theta), sin(theta))
		outline.append(settlement.position + direction * r * (1.0 + 0.6 * ribbon))
		core.append(settlement.position + direction * r * 0.42)

	draw_colored_polygon(outline, faded(WorldMapStyle.COLOR_URBAN, visibility * 0.92))
	draw_blocks(settlement, radius, phase, visibility)
	draw_colored_polygon(core, faded(WorldMapStyle.COLOR_URBAN_CORE, visibility * 0.75))
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, faded(WorldMapStyle.COLOR_URBAN_EDGE, visibility * 0.7), 1.0 / zoom, true)
	if settlement.tier >= WorldMapData.TIER_CITY:
		# Old town walls around the core.
		var wall: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in core:
			wall.append(settlement.position + (point - settlement.position) * 1.18)
		wall.append(wall[0])
		draw_polyline(wall, faded(WorldMapStyle.COLOR_WALL_SHADE.darkened(0.25), visibility), 1.8 / zoom, true)

func footprint_shape(theta: float, phase: float) -> float:
	return 1.0 + 0.16 * sin(3.0 * theta + phase) + 0.09 * sin(5.0 * theta + phase * 2.1) + 0.05 * sin(9.0 * theta + phase * 0.7)

# Rooftop blocks give the built-up area texture once the player is close.
func draw_blocks(settlement: WorldMapData.Settlement, radius: float, phase: float, visibility: float) -> void:
	var block_visibility: float = visibility * WorldMapStyle.fade(zoom, 1.4, 2.2)
	if block_visibility <= 0.01:
		return
	var steps: int = int(ceil(radius / BLOCK_SPACING))
	for gy in range(-steps, steps + 1):
		for gx in range(-steps, steps + 1):
			var offset: Vector2 = Vector2(gx, gy) * BLOCK_SPACING + Vector2(0.4 * (gy % 2), 0.0)
			var distance: float = offset.length()
			if distance > radius * footprint_shape(offset.angle(), phase) * 0.92:
				continue
			var pick: float = fposmod(sin(gx * 12.9898 + gy * 78.233 + phase) * 43758.5453, 1.0)
			if pick < 0.18:
				continue
			var roof: Color = WorldMapStyle.COLOR_ROOF.lerp(WorldMapStyle.COLOR_URBAN, 0.35 + 0.45 * pick)
			draw_rect(Rect2(settlement.position + offset - Vector2(0.55, 0.4), Vector2(1.1, 0.8)), faded(roof, block_visibility * 0.85))
