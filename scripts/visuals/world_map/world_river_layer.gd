class_name WorldRiverLayer
extends WorldMapLayer

# Rivers widen toward their mouths but never thin below a hairline on screen.

const POINTS_PER_STRETCH: int = 6

func draw_world() -> void:
	# Every bank line goes down before any water, so stretch joints leave no marks.
	for draw_banks in [true, false]:
		for river: WorldMapData.River in data.rivers:
			var visibility: float = WorldMapStyle.river_visibility(river, zoom)
			if visibility > 0.01:
				draw_river(river, visibility, draw_banks)

func draw_river(river: WorldMapData.River, visibility: float, draw_banks: bool) -> void:
	var min_px: float = 1.1 if river.is_major else 0.8
	var last: int = river.points.size() - 1
	# Short stretches with stepped widths give the taper without per-vertex geometry.
	for start in range(0, last, POINTS_PER_STRETCH):
		var end: int = mini(start + POINTS_PER_STRETCH, last)
		var stretch: PackedVector2Array = river.points.slice(start, end + 1)
		var width_px: float = maxf(river.widths[(start + end) / 2] * zoom, min_px)
		if not is_in_view(points_rect(stretch).grow((width_px + 2.0) / zoom)):
			continue
		if draw_banks:
			if width_px > 2.6:
				draw_polyline(stretch, faded(WorldMapStyle.COLOR_RIVER_EDGE, visibility * 0.6), (width_px + 1.2) / zoom, true)
		else:
			draw_polyline(stretch, faded(WorldMapStyle.COLOR_RIVER, visibility), width_px / zoom, true)
