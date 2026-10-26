class_name RegionFieldLayer
extends RegionMapLayer

# Ground worked by people: field patchworks on the fertile land around settlements and
# quarries cut into stone deposits. Drawn on the terrain, under trees and buildings.
# Kept apart from the terrain so cultivation can spread, shrink, or move as towns change.

func on_lod_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if view == null:
		return
	var shapes: RegionMapGeometry = geometry()
	for field: RegionMapGeometry.FieldShape in shapes.fields:
		draw_field(field)
	for quarry: RegionMapGeometry.QuarryShape in shapes.quarries:
		draw_quarry(quarry)

func draw_field(field: RegionMapGeometry.FieldShape) -> void:
	# Slightly translucent so the ground's light and shade carry through the crops.
	draw_colored_polygon(field.corners, faded(field.color, 0.82))
	var closed: PackedVector2Array = field.corners.duplicate()
	closed.append(field.corners[0])
	# Hedgerow and ditch edges.
	draw_polyline(closed, Color(0.30, 0.36, 0.18, 0.55), 0.55, true)
	if lod < 1:
		return
	# Furrows, clipped to the parcel by walking its frame.
	var origin: Vector2 = field.corners[0]
	var side_a: Vector2 = field.corners[1] - origin
	var side_b: Vector2 = field.corners[3] - origin
	var along: Vector2 = side_a
	var across: Vector2 = side_b
	if absf(angle_difference(side_a.angle(), field.furrow_angle)) > PI * 0.25 and absf(angle_difference(side_a.angle(), field.furrow_angle + PI)) > PI * 0.25:
		along = side_b
		across = side_a
	var count: int = int(across.length() / 0.9)
	var furrow: Color = field.color.darkened(0.18)
	furrow.a = 0.55
	for i in range(1, count):
		var offset: Vector2 = across * (float(i) / count)
		draw_line(origin + offset + along * 0.05, origin + offset + along * 0.95, furrow, 0.3, true)

func draw_quarry(quarry: RegionMapGeometry.QuarryShape) -> void:
	var r: float = quarry.radius
	draw_blob(self, quarry.center, Vector2(r, r * 0.8), RegionMapStyle.COLOR_STONE, 12)
	# Terraced pit: the walls facing away from the light sit in shadow.
	draw_blob(self, quarry.center + Vector2(0.3, 0.3), Vector2(r * 0.72, r * 0.56), RegionMapStyle.COLOR_QUARRY, 12)
	draw_blob(self, quarry.center + Vector2(-0.4, -0.35), Vector2(r * 0.5, r * 0.36), Color(0.48, 0.46, 0.42), 10)
	draw_blob(self, quarry.center + Vector2(0.2, 0.15), Vector2(r * 0.42, r * 0.3), Color(0.70, 0.68, 0.62), 10)
