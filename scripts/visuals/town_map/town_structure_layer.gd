class_name TownStructureLayer
extends TownMapLayer

# What the town has built, drawn by TownBuildingPainter from each type's BuildingVisuals
# profile, north to south so nearer roofs overlap farther ones. Families without a house show
# where they live: tents for temporary shelter, a bedroll by the fire for the unsheltered,
# camped on open ground near the town's heart.
#
# Recorded again only when the development signature changes (TownMapView), never per frame:
# a building's type and place, its upkeep in steps of ten, whether a family works it, and how
# many families are camped.

func on_lod_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if view == null or view.city == null:
		return
	var city: City = view.city
	var order: Array[int] = []
	for index in range(city.buildings.size()):
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return building_bottom(city.buildings[a]) < building_bottom(city.buildings[b]))
	for index: int in order:
		var building: Building = city.buildings[index]
		var rect: Rect2 = TownMapStyle.tile_rect(building.tile, building.size)
		TownBuildingPainter.draw(self, rect, BuildingVisuals.get_profile(building.type), building_state(building))
	draw_camp(city)

func building_bottom(building: Building) -> float:
	return building.tile.y + building.size.y + building.tile.x * 0.001

func building_state(building: Building) -> Dictionary:
	var h: Vector2i = view.hash_tile(building.tile.x, building.tile.y)
	return {
		"variant": LandscapePainter.hash01(h.x, h.y, 300),
		"lod": lod,
		"weathered": 1.0 - float(TownMapView.upkeep_band(building)) / 10.0 if building.needs_maintenance() else 0.0,
		"idle": building.is_production_building() and building.assigned_workers <= 0,
	}

func draw_camp(city: City) -> void:
	var camped: Array[String] = TownMapView.camped_households(city)
	if camped.is_empty():
		return
	var spots: Array[Vector2i] = view.camp_spots(camped.size())
	for i in range(mini(spots.size(), camped.size())):
		var center: Vector2 = (Vector2(spots[i]) + Vector2(0.5, 0.55)) * TownMapStyle.TILE
		if camped[i] == Household.RESIDENCE_UNSHELTERED:
			TownBuildingPainter.bedroll(self, center, TownMapStyle.TILE * 0.8)
			TownBuildingPainter.fire_ring(self, center + Vector2(TownMapStyle.TILE * 0.55, TownMapStyle.TILE * 0.1), TownMapStyle.TILE * 0.16, true)
		else:
			TownBuildingPainter.tent(self, center, TownMapStyle.TILE * 0.85)
