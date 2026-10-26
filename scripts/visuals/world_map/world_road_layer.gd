class_name WorldRoadLayer
extends WorldMapLayer

# Roads are drawn by physical class, not by traffic: a cased highway for major routes,
# a solid line for regional roads, and a dashed track for local roads.

const LOCAL_DASH_PX: float = 4.0
const LOCAL_GAP_PX: float = 3.0

func draw_world() -> void:
	for road_class in [WorldMapData.ROAD_LOCAL, WorldMapData.ROAD_REGIONAL, WorldMapData.ROAD_MAJOR]:
		var visibility: float = WorldMapStyle.road_visibility(road_class, zoom)
		if visibility <= 0.01:
			continue
		var width: float = WorldMapStyle.road_width_px(road_class, zoom) / zoom
		for road: WorldMapData.Road in data.roads:
			if road.road_class != road_class or not is_in_view(road_bounds(road).grow(width * 2.0)):
				continue
			match road_class:
				WorldMapData.ROAD_MAJOR:
					draw_polyline(road.points, faded(WorldMapStyle.COLOR_ROAD_MAJOR_CASING, visibility), width + 1.6 / zoom, true)
					draw_polyline(road.points, faded(WorldMapStyle.COLOR_ROAD_MAJOR, visibility), width, true)
				WorldMapData.ROAD_REGIONAL:
					draw_polyline(road.points, faded(WorldMapStyle.COLOR_ROAD_REGIONAL, visibility * 0.9), width, true)
				_:
					var dashes: PackedVector2Array = dash_polyline(road.points, LOCAL_DASH_PX / zoom, LOCAL_GAP_PX / zoom)
					if not dashes.is_empty():
						draw_multiline(dashes, faded(WorldMapStyle.COLOR_ROAD_LOCAL, visibility * 0.9), width, true)

var bounds_by_road: Dictionary = {}

func road_bounds(road: WorldMapData.Road) -> Rect2:
	if not bounds_by_road.has(road.id):
		bounds_by_road[road.id] = points_rect(road.points)
	return bounds_by_road[road.id]

# Dashes measured along the whole road, so the pattern does not restart at every vertex.
static func dash_polyline(points: PackedVector2Array, dash: float, gap: float) -> PackedVector2Array:
	var segments: PackedVector2Array = PackedVector2Array()
	var period: float = dash + gap
	var travelled: float = 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		if length <= 0.0:
			continue
		var segment_end: float = travelled + length
		# Step whole dash indices rather than accumulating float offsets, which can
		# stall on rounding and never reach the end of the segment.
		var dash_index: int = int(floor(travelled / period))
		while true:
			var dash_start: float = dash_index * period
			if dash_start >= segment_end:
				break
			var dash_end: float = dash_start + dash
			var from_distance: float = maxf(dash_start, travelled)
			var to_distance: float = minf(dash_end, segment_end)
			if to_distance > from_distance:
				segments.append(a.lerp(b, (from_distance - travelled) / length))
				segments.append(a.lerp(b, (to_distance - travelled) / length))
			if dash_end >= segment_end:
				break
			dash_index += 1
		travelled = segment_end
	return segments
