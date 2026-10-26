class_name RegionOverlayLayer
extends RegionMapLayer

# Interaction marks over the landscape: founding exclusion zones around towns, the hovered
# tile (green where a town may be founded, red where not), the land a town's map would be
# drawn from, the chosen site, and highlighted settlements. Lines keep a constant screen
# width, so this cheap layer redraws on zoom as well as on hover.

func set_view_zoom(new_zoom: float) -> void:
	super.set_view_zoom(new_zoom)
	queue_redraw()

func px(pixels: float) -> float:
	return pixels / maxf(zoom, 0.01)

func _draw() -> void:
	if view == null or view.map_size == Vector2i.ZERO:
		return
	var tile_size: float = RegionMapStyle.TILE
	if view.founding_active:
		var radius: float = view.exclusion_radius_tiles * tile_size
		for city: City in view.cities:
			var center: Vector2 = RegionMapGeometry.tile_center(city.tile)
			draw_circle(center, radius, faded(RegionMapStyle.COLOR_EXCLUSION, 0.07))
			dashed_circle(self, center, radius, faded(RegionMapStyle.COLOR_EXCLUSION, 0.8), px(1.5), px(7.0))

	for city_index: int in [view.hovered_city, view.selected_city]:
		if city_index < 0 or city_index >= view.geometry.settlements.size():
			continue
		var settlement: RegionMapGeometry.SettlementShape = view.geometry.settlements[city_index]
		var ring_radius: float = maxf(settlement.enclosure_radius, 7.0) + 2.0
		var color: Color = RegionMapStyle.COLOR_SELECTION if city_index == view.selected_city else RegionMapStyle.COLOR_HOVER
		draw_arc(settlement.center, ring_radius, 0.0, TAU, 48, color, px(2.0), true)

	if view.has_pending_site():
		var site_center: Vector2 = RegionMapGeometry.tile_center(view.pending_tile)
		draw_circle(site_center, view.catchment_radius_tiles * tile_size, faded(RegionMapStyle.COLOR_PENDING, 0.10))
		draw_arc(site_center, view.catchment_radius_tiles * tile_size, 0.0, TAU, 64, faded(RegionMapStyle.COLOR_PENDING, 0.9), px(2.0), true)
		draw_rect(Rect2(Vector2(view.pending_tile) * tile_size, Vector2(tile_size, tile_size)).grow(-0.5), faded(RegionMapStyle.COLOR_PENDING, 0.35))
		draw_stake(site_center)

	if view.is_tile_inside(view.hovered_tile) and view.hovered_city < 0:
		var rect: Rect2 = Rect2(Vector2(view.hovered_tile) * tile_size, Vector2(tile_size, tile_size))
		var color: Color = RegionMapStyle.COLOR_HOVER
		if view.founding_active:
			color = RegionMapStyle.COLOR_SITE_VALID if view.hovered_tile_valid else RegionMapStyle.COLOR_SITE_INVALID
		draw_rect(rect.grow(-0.3), faded(color, 0.18))
		draw_rect(rect.grow(-0.3), color, false, px(2.0))
		if view.founding_active and view.hovered_tile_valid and view.hovered_tile != view.pending_tile:
			dashed_circle(self, rect.get_center(), view.catchment_radius_tiles * tile_size, faded(RegionMapStyle.COLOR_CATCHMENT, 0.85), px(1.5), px(6.0))

# The surveyor's stake marking the chosen founding site.
func draw_stake(base: Vector2) -> void:
	var top: Vector2 = base + Vector2(0.0, -9.0)
	draw_line(base + Vector2(1.5, 1.2), top + Vector2(5.0, 4.0), RegionMapStyle.COLOR_SHADOW, 0.7)
	draw_line(base, top, Color(0.25, 0.18, 0.12), 0.7, true)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(5.0, 1.6), top + Vector2(0.0, 3.2)]), RegionMapStyle.COLOR_PENDING)
	draw_polyline(PackedVector2Array([top, top + Vector2(5.0, 1.6), top + Vector2(0.0, 3.2)]), Color(0.35, 0.24, 0.08), 0.3, true)
