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

func setup(world_data: WorldMapData) -> void:
	data = world_data
	queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	if is_equal_approx(new_zoom, zoom):
		return
	zoom = new_zoom
	queue_redraw()

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
