class_name RegionSiteLayer
extends RegionMapLayer

# Survey pegs on every tile where a town may be founded (the founding rules decide; the
# owner passes the result in). Shown while the player is choosing a site.

func on_lod_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if view == null or not view.founding_active or not view.show_sites:
		return
	# Pegs stay visible when zoomed out without crowding the land when zoomed in.
	var radius: float = clampf(1.6 / maxf(zoom, 0.01), 0.7, 1.2)
	for tile: Vector2i in view.founding_sites:
		draw_circle(RegionMapGeometry.tile_center(Vector2(tile)), radius, RegionMapStyle.COLOR_SITE_DOT)
