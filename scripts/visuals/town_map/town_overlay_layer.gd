class_name TownOverlayLayer
extends TownMapLayer

# What the player needs to read off the town, redrawn every frame: the building being placed
# (a ghost of it on a green or red footprint), hover and selection, the selected family's home
# and work, who works each workplace (a badge in the family's color, or a red vacancy badge),
# upkeep (a slim plate under each workplace), each house's family (a pennant in its color), and
# families walking between home and work.
#
# Badges and plates keep their size on screen so they stay readable when zoomed out; walkers
# and pennants are part of the scene and scale with it.

const BADGE_RADIUS_PX: float = 5.5
const PLATE_HEIGHT_PX: float = 4.0

var ghost: TownFeatureLayer.Canvas = null

func setup(map_view: TownMapView) -> void:
	super.setup(map_view)
	ghost = TownFeatureLayer.Canvas.new()
	ghost.name = "Ghost"
	ghost.painter = paint_ghost
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.6)
	add_child(ghost)

func refresh() -> void:
	queue_redraw()
	ghost.queue_redraw()

func _draw() -> void:
	if view == null or view.city == null:
		return
	var city: City = view.city
	for index in range(city.buildings.size()):
		var building: Building = city.buildings[index]
		if building.is_house():
			draw_pennant(city, building, index)
	draw_walkers(city)
	for index in range(city.buildings.size()):
		var building: Building = city.buildings[index]
		if building.is_production_building():
			draw_workplace_marks(building)
	draw_selection(city)
	draw_placement()

# --- Families --------------------------------------------------------------------------------

func draw_pennant(city: City, house: Building, index: int) -> void:
	if city.get_household_for_building_id(index) == null:
		return
	var rect: Rect2 = TownMapStyle.tile_rect(house.tile, house.size)
	var base: Vector2 = rect.position + rect.size * Vector2(0.14, 0.5)
	var top: Vector2 = base + Vector2(0.0, -TownMapStyle.TILE * 0.75)
	draw_line(base + Vector2(0.8, 0.6), top + Vector2(3.0, 3.0), RegionMapStyle.COLOR_SHADOW, 0.6)
	draw_line(base, top, TownMapStyle.COLOR_TIMBER_DARK, 0.6, true)
	var color: Color = TownMapStyle.preference_color(city.get_household_preference_for_building(index))
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(4.6, 1.3), top + Vector2(0.0, 2.8)]), color)

func draw_walkers(city: City) -> void:
	for index in range(city.buildings.size()):
		var workplace: Building = city.buildings[index]
		if not workplace.is_production_building() or workplace.assigned_workers <= 0 or workplace.assigned_household_id < 0:
			continue
		var home: Vector2 = household_home(city, workplace.assigned_household_id, city.get_assigned_house_building_id(workplace))
		var work: Vector2 = TownMapStyle.tile_rect(workplace.tile, workplace.size).get_center()
		var color: Color = TownMapStyle.preference_color(city.get_household_preference_for_worker_modifier(workplace))
		for walker_index in range(workplace.assigned_workers):
			draw_walker(walker_position(home, work, walker_index, workplace.assigned_household_id * 10 + index), color)

# Home is the family's house, or its tent at the camp.
func household_home(city: City, household_id: int, house_index: int) -> Vector2:
	if house_index >= 0 and house_index < city.buildings.size():
		var house: Building = city.buildings[house_index]
		return TownMapStyle.tile_rect(house.tile, house.size).get_center()
	var spots: Array[Vector2i] = view.camp_spots(TownMapView.camped_households(city).size())
	if spots.is_empty():
		return Vector2(view.map_size) * TownMapStyle.TILE * 0.5
	return (Vector2(spots[posmod(household_id, spots.size())]) + Vector2(0.5, 0.5)) * TownMapStyle.TILE

# Out to work for the first half of the cycle, home for the second, walking side by side.
func walker_position(home: Vector2, work: Vector2, walker_index: int, key: int) -> Vector2:
	var cycle: float = view.walker_time / maxf(view.walker_cycle_seconds, 0.01)
	var travel: float = cycle * 2.0 if cycle < 0.5 else 1.0 - (cycle - 0.5) * 2.0
	var position: Vector2 = home.lerp(work, travel)
	var direction: Vector2 = work - home
	if direction.length() > 0.1:
		var side: Vector2 = Vector2(-direction.normalized().y, direction.normalized().x)
		var lane: float = (float(walker_index) - 0.5) * 2.6
		var bob: float = sin(view.walker_time * 5.0 + float(key + walker_index)) * 0.4
		position += side * (lane + bob)
	return position

# A small figure seen from above: shadow, tunic in the family's color, head.
func draw_walker(position: Vector2, tunic: Color) -> void:
	RegionMapLayer.draw_blob(self, position + Vector2(0.9, 1.1), Vector2(1.5, 1.0), RegionMapStyle.COLOR_SHADOW, 8)
	RegionMapLayer.draw_blob(self, position, Vector2(1.3, 1.5), tunic, 8)
	draw_circle(position + Vector2(0.0, -1.3), 0.85, TownMapStyle.COLOR_SKIN)

# --- Workplaces --------------------------------------------------------------------------------

func draw_workplace_marks(building: Building) -> void:
	var rect: Rect2 = TownMapStyle.tile_rect(building.tile, building.size)
	var radius: float = px(BADGE_RADIUS_PX)
	var badge: Vector2 = rect.position + Vector2(rect.size.x - radius * 1.4, radius * 1.4)
	draw_circle(badge + Vector2(px(1.0), px(1.2)), radius, RegionMapStyle.COLOR_SHADOW)
	draw_circle(badge, radius, TownMapStyle.COLOR_BADGE_RIM)
	if building.assigned_workers > 0:
		draw_circle(badge, radius * 0.72, TownMapStyle.preference_color(building.assigned_preference))
	else:
		draw_circle(badge, radius * 0.72, TownMapStyle.COLOR_VACANT)
		draw_line(badge - Vector2(radius * 0.4, 0.0), badge + Vector2(radius * 0.4, 0.0), Color.WHITE, px(1.4))
	# Upkeep shows only when it needs attention: below full, or switched off.
	if not building.needs_maintenance() or (building.maintenance_level >= 100 and building.receives_maintenance):
		return
	var plate: Rect2 = Rect2(Vector2(rect.position.x + rect.size.x * 0.12, rect.end.y - px(PLATE_HEIGHT_PX) - px(3.0)), Vector2(rect.size.x * 0.76, px(PLATE_HEIGHT_PX)))
	draw_rect(plate.grow(px(1.0)), TownMapStyle.COLOR_PLATE)
	var level: float = clampf(building.maintenance_level / 100.0, 0.0, 1.0)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x * level, plate.size.y)), upkeep_color(building))

# The sidebar's upkeep colors, toned down to sit on the land.
static func upkeep_color(building: Building) -> Color:
	if not building.receives_maintenance:
		return VisualStyle.COLOR_MAINTENANCE_DISABLED
	if building.maintenance_level < 50:
		return VisualStyle.COLOR_MAINTENANCE_BAD.darkened(0.1)
	if building.maintenance_level < 75:
		return VisualStyle.COLOR_MAINTENANCE_WARNING.darkened(0.1)
	return VisualStyle.COLOR_MAINTENANCE_GOOD.darkened(0.3)

# --- Selection and placement ---------------------------------------------------------------------

func draw_selection(city: City) -> void:
	for index: int in [view.inspected_index, view.selected_house_index]:
		if index < 0 or index >= city.buildings.size():
			continue
		var building: Building = city.buildings[index]
		var rect: Rect2 = TownMapStyle.tile_rect(building.tile, building.size).grow(px(2.0))
		draw_rect(rect, RegionMapLayer.faded(TownMapStyle.COLOR_SELECTION, 0.16))
		draw_rect(rect, TownMapStyle.COLOR_SELECTION, false, px(2.0))
	if view.inspected_index < 0 or view.inspected_index >= city.buildings.size():
		return
	var start: Vector2 = building_center(city, view.inspected_index)
	for related: int in view.linked_indices:
		if related < 0 or related >= city.buildings.size():
			continue
		var end: Vector2 = building_center(city, related)
		draw_line(start + Vector2(px(1.0), px(1.0)), end + Vector2(px(1.0), px(1.0)), Color(0.05, 0.05, 0.05, 0.7), px(4.0))
		draw_line(start, end, TownMapStyle.COLOR_LINK, px(2.0))
		draw_circle(start, px(4.0), TownMapStyle.COLOR_LINK)
		draw_circle(end, px(5.0), TownMapStyle.COLOR_LINK)

func building_center(city: City, index: int) -> Vector2:
	var building: Building = city.buildings[index]
	return TownMapStyle.tile_rect(building.tile, building.size).get_center()

func draw_placement() -> void:
	if view.hovered_tile.x < 0:
		return
	if view.preview_type == "":
		draw_rect(TownMapStyle.tile_rect(view.hovered_tile), TownMapStyle.COLOR_HOVER, false, px(1.5))
		return
	var rect: Rect2 = TownMapStyle.tile_rect(view.hovered_tile, view.preview_size)
	var color: Color = TownMapStyle.COLOR_VALID if view.preview_valid else TownMapStyle.COLOR_INVALID
	draw_rect(rect, RegionMapLayer.faded(color, 0.28))
	draw_rect(rect, color, false, px(2.0))

func paint_ghost(canvas: CanvasItem) -> void:
	if view == null or view.city == null or view.hovered_tile.x < 0 or view.preview_type == "" or not view.preview_valid:
		return
	var rect: Rect2 = TownMapStyle.tile_rect(view.hovered_tile, view.preview_size)
	TownBuildingPainter.draw(canvas, rect, BuildingVisuals.get_profile(view.preview_type), {"variant": 0.3, "lod": lod})
