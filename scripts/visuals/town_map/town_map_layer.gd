class_name TownMapLayer
extends Node2D

# Base for map-space layers of the town map. Like the regional layers, a layer records its draw
# commands once and records again only when what it draws changes, never when the camera pans.

var view: TownMapView = null
var zoom: float = 1.0
var lod: int = -1

func setup(map_view: TownMapView) -> void:
	view = map_view

# Called when the town map or the buildings this layer draws have changed.
func rebuild() -> void:
	queue_redraw()

func set_view_zoom(new_zoom: float) -> void:
	zoom = new_zoom
	var new_lod: int = TownMapStyle.lod_level(new_zoom)
	if new_lod != lod:
		lod = new_lod
		on_lod_changed()

func on_lod_changed() -> void:
	pass

func map_extent() -> Vector2:
	return Vector2(view.map_size) * TownMapStyle.TILE

func local_map() -> Array:
	return view.city.local_map if view.city != null else []

# One pixel on screen, in map units.
func px(pixels: float) -> float:
	return pixels / maxf(zoom, 0.01)
