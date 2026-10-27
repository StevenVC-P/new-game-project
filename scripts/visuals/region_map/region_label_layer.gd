class_name RegionLabelLayer
extends RegionMapLayer

# Settlement names on the board at a constant screen size.

const SETTLEMENT_FONT_SIZE: int = 15

func set_view_zoom(new_zoom: float) -> void:
	super.set_view_zoom(new_zoom)
	queue_redraw()

func _draw() -> void:
	if view == null or not view.show_labels or view.map_size == Vector2i.ZERO:
		return
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
