class_name RegionMapLayer
extends Node2D

# Base for map-space layers of the regional map. Draw commands are recorded once and reused
# by the engine; a layer records again only when the region's data or the level of detail
# it depends on changes, never when the camera pans.

var view: RegionMapView = null
var zoom: float = 1.0
var lod: int = -1
# Shapes this layer draws when not the view's own (a chunk's roads, a world settlement).
var geometry_override: RegionMapGeometry = null

func setup(map_view: RegionMapView) -> void:
	view = map_view

func geometry() -> RegionMapGeometry:
	return geometry_override if geometry_override != null else view.geometry

# Called when the data this layer draws has changed.
func rebuild() -> void:
	queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	zoom = new_zoom
	var new_lod: int = RegionMapStyle.lod_level(new_zoom)
	if new_lod != lod:
		lod = new_lod
		on_lod_changed()

func on_lod_changed() -> void:
	pass

func map_extent() -> Vector2:
	return Vector2(view.map_size) * RegionMapStyle.TILE

static func faded(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)

# A filled ellipse with few vertices; trees and stones are small, so ten sides read as round.
static func draw_blob(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, sides: int = 10) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(sides)
	for i in range(sides):
		var angle: float = TAU * i / sides
		points[i] = center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
	canvas.draw_colored_polygon(points, color)

static func rotated_rect(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var axis: Vector2 = Vector2(cos(angle), sin(angle))
	var across: Vector2 = Vector2(-axis.y, axis.x)
	return PackedVector2Array([
		center - axis * half.x - across * half.y,
		center + axis * half.x - across * half.y,
		center + axis * half.x + across * half.y,
		center - axis * half.x + across * half.y,
	])

static func dashed_circle(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float, dash: float) -> void:
	var segments: int = maxi(12, int(TAU * radius / dash))
	for i in range(0, segments, 2):
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		canvas.draw_arc(center, radius, a0, a1, 3, color, width, true)

# Filled shapes gathered into one triangle list, so a strip of thousands of trees is a single
# draw command; per-command engine cost otherwise dominated the frame. Shapes keep the order
# they were added in, so later shapes (and their shadows) layer over earlier ones.
class TriangleBatch:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	# Fan from the first point: right for convex shapes.
	func add_polygon(polygon: PackedVector2Array, color: Color) -> void:
		var base: int = points.size()
		points.append_array(polygon)
		for _i in range(polygon.size()):
			colors.append(color)
		for i in range(1, polygon.size() - 1):
			indices.append(base)
			indices.append(base + i)
			indices.append(base + i + 1)

	# Fan from a center point: right for star-shaped outlines such as conifers.
	func add_fan(center: Vector2, outline: PackedVector2Array, color: Color) -> void:
		var base: int = points.size()
		points.append(center)
		points.append_array(outline)
		for _i in range(outline.size() + 1):
			colors.append(color)
		for i in range(outline.size()):
			indices.append(base)
			indices.append(base + 1 + i)
			indices.append(base + 1 + (i + 1) % outline.size())

	func add_blob(center: Vector2, radius: Vector2, color: Color, sides: int = 10) -> void:
		var outline: PackedVector2Array = PackedVector2Array()
		outline.resize(sides)
		for i in range(sides):
			var angle: float = TAU * i / sides
			outline[i] = center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		add_polygon(outline, color)

	func flush(canvas: CanvasItem) -> void:
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, colors)
		points = PackedVector2Array()
		colors = PackedColorArray()
		indices = PackedInt32Array()

# Draws one horizontal strip of a layer's content; lets a layer split its drawing so the
# engine can cull strips that are off screen.
class Strip:
	extends Node2D
	var painter: Callable
	var index: int = 0

	func _draw() -> void:
		painter.call(self, index)
