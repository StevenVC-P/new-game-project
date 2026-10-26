class_name WorldMapLayer
extends Node2D

# Base for world-space layers of the world map. A layer draws the planet three times, one
# world-width apart, so panning across the date line is seamless. Draw commands are
# recorded once and reused by the engine; they are rebuilt only when world data or the
# level of detail changes, never when the camera pans.

var data: WorldMapData = null
var zoom: float = 1.0
# Offset of the wrap copy currently being drawn; layers that set their own draw
# transform (screen-sized icons and labels) add it to their positions.
var draw_offset: Vector2 = Vector2.ZERO
# Which wrap copies the camera can see. The engine resubmits every recorded command
# each frame, so drawing only visible copies cuts per-frame canvas cost about threefold.
var visible_copies: Array[int] = [-1, 0, 1]
# World rectangle around the camera (in its unwrapped frame) that drawing is limited to;
# empty means everything. The view grows it well past the screen and moves it only when
# the camera leaves it, so panning rarely re-records.
var cull_rect: Rect2 = Rect2()

func setup(world_data: WorldMapData) -> void:
	data = world_data
	queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	if is_equal_approx(new_zoom, zoom):
		return
	zoom = new_zoom
	queue_redraw()

func set_cull_rect(rect: Rect2) -> void:
	if rect == cull_rect:
		return
	cull_rect = rect
	queue_redraw()

# Whether something covering world_rect, drawn in the current wrap copy, can be on screen.
func is_in_view(world_rect: Rect2) -> bool:
	return cull_rect.size == Vector2.ZERO or cull_rect.intersects(Rect2(world_rect.position + draw_offset, world_rect.size))

# The same for placement done once for all copies (labels): any copy near the view counts.
func is_in_any_view(world_rect: Rect2) -> bool:
	if cull_rect.size == Vector2.ZERO:
		return true
	for copy: int in [-1, 0, 1]:
		if cull_rect.intersects(Rect2(world_rect.position + Vector2(copy * data.world_size.x, 0.0), world_rect.size)):
			return true
	return false

static func points_rect(points: PackedVector2Array) -> Rect2:
	var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect

func set_visible_copies(copies: Array[int]) -> void:
	if copies == visible_copies:
		return
	visible_copies = copies
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	before_draw()
	for copy: int in visible_copies:
		draw_offset = Vector2(copy * data.world_size.x, 0.0)
		draw_set_transform(draw_offset)
		draw_world()
	draw_set_transform(Vector2.ZERO)

# Per-redraw work shared by all three copies, such as label placement.
func before_draw() -> void:
	pass

func draw_world() -> void:
	pass

static func faded(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
