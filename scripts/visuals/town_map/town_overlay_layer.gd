class_name TownOverlayLayer
extends TownMapLayer

# What the player needs to read off the town, redrawn every frame: the building being placed
# (a ghost of it on a green or red footprint), hover and selection, the selected family's home
# and work, who works each workplace (a badge in the family's color, or a red vacancy badge),
# upkeep (a slim plate under each workplace), each house's family (a pennant in its color),
# families walking their routes between home and work, carriers taking goods to the store, and
# builders carrying materials to their sites, all along the routes that wear the paths; how far
# each site has come (a plate: materials, then work), the road being laid, woods marked for
# clearing, and for the selected workplace the routes its goods and family travel (to the
# nearest store, from home).
#
# Badges and plates keep their size on screen so they stay readable when zoomed out; walkers
# and pennants are part of the scene and scale with it.

const BADGE_RADIUS_PX: float = 5.5
const PLATE_HEIGHT_PX: float = 4.0
const COLOR_SUPPLY: Color = Color(0.72, 0.52, 0.30)
const COLOR_WORK: Color = Color(0.96, 0.80, 0.36)
const COLOR_HAUL_ROUTE: Color = Color(0.96, 0.72, 0.30, 0.9)
const COLOR_COMMUTE_ROUTE: Color = Color(0.70, 0.86, 0.98, 0.9)
const COLOR_CLEARING: Color = Color(0.95, 0.56, 0.22)
const COLOR_TILLING: Color = Color(0.62, 0.42, 0.22)
# Ground the player opened for families' workplaces (influence prototype).
const COLOR_WORK_GROUND: Color = Color(0.48, 0.66, 0.92)
# Residential land (HomeSites): set aside for homes, and the part the community prefers.
const COLOR_RESIDENTIAL: Color = Color(0.93, 0.82, 0.55)
const COLOR_PREFERRED: Color = Color(0.98, 0.62, 0.36)
const RESIDENTIAL_SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
# What an errand brings home: water, firewood, goods.
const ERRAND_LOADS: Dictionary = {
	"water": Color(0.42, 0.62, 0.78),
	"firewood": Color(0.50, 0.36, 0.22),
	"store": Color(0.80, 0.72, 0.52),
}

# Routes shown for the selected workplace, kept until the selection or the layout changes.
var route_key: Array = []
var routes: Array = []
# Walkers' paths in map units, by [kind, id], and the routes version they were made from.
var walker_paths: Dictionary = {}
var walker_paths_version: int = -1

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
	draw_errand_walkers(city)
	draw_builders(city)
	for index in range(city.buildings.size()):
		var building: Building = city.buildings[index]
		if building.is_production_building():
			draw_workplace_marks(building)
	draw_site_plates(city)
	draw_routes(city)
	draw_selection(city)
	draw_site_selection(city)
	draw_road_preview()
	draw_residential(city)
	draw_clearing(city)
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
	refresh_walker_paths(city)
	for index in range(city.buildings.size()):
		var workplace: Building = city.buildings[index]
		if not workplace.is_production_building() or workplace.assigned_workers <= 0 or workplace.assigned_household_id < 0:
			continue
		var color: Color = TownMapStyle.preference_color(city.get_household_preference_for_worker_modifier(workplace))
		var key: int = workplace.assigned_household_id * 10 + index
		# The family walks its route from home and back; one of it carries goods to the store and
		# back along the store route, half a day out of step.
		var commute: Dictionary = walker_path(city, "commute", workplace)
		for walker_index in range(workplace.assigned_workers):
			draw_walker(position_on(commute, out_and_back(0.0), walker_index, key), color)
		if TownLogistics.get_daily_units(city, workplace) > 0.0:
			var haul: Dictionary = walker_path(city, "haul", workplace)
			var phase: float = out_and_back(0.5)
			draw_walker(position_on(haul, phase, 0, key + 5), color)
			if phase_outbound(0.5):
				draw_load(position_on(haul, phase, 0, key + 5))

# Where along its route a walker is: out for the first half of the cycle, back for the second.
func out_and_back(offset: float) -> float:
	var cycle: float = fposmod(view.walker_time / maxf(view.walker_cycle_seconds, 0.01) + offset, 1.0)
	return cycle * 2.0 if cycle < 0.5 else 1.0 - (cycle - 0.5) * 2.0

func phase_outbound(offset: float) -> bool:
	return fposmod(view.walker_time / maxf(view.walker_cycle_seconds, 0.01) + offset, 1.0) < 0.5

# Routes in map units, kept until routes change. Walkers follow the routes the town's travel is
# reckoned on (TownLogistics), so what the player sees walked is what wears the paths.
func refresh_walker_paths(city: City) -> void:
	if walker_paths_version != city.logistics.routes_version:
		walker_paths_version = city.logistics.routes_version
		walker_paths.clear()

func walker_path(city: City, kind: String, building: Building) -> Dictionary:
	var key: Array = [kind, building.id, building.assigned_household_id]
	if walker_paths.has(key):
		return walker_paths[key]
	# Commutes run from home to work, store routes from work to the store.
	var route: Array = city.logistics.get_commute(building)["route"] if kind == "commute" else city.logistics.get_store_route(building)["route"]
	var path: Dictionary = make_path(route)
	if path["points"].size() < 2:
		# No town map or no route: a straight walk from home (or the camp) to work.
		var work: Vector2 = TownMapStyle.tile_rect(building.tile, building.size).get_center()
		var start: Vector2 = household_home(city, building.assigned_household_id, city.get_assigned_house_building_id(building)) if kind == "commute" else work
		path = make_path_from_points(PackedVector2Array([start, work]))
	walker_paths[key] = path
	return path

func make_path(route: Array) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in route:
		points.append(TownLogistics.cell_position(cell) * TownMapStyle.TILE)
	return make_path_from_points(points)

# A polyline with each point's distance from the start, for walking along it, and a sideways
# direction at each point: at a bend, between the two segments' sideways directions, so a walker
# keeping to its lane eases round the bend instead of hopping across it.
func make_path_from_points(points: PackedVector2Array) -> Dictionary:
	var lengths: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for i in range(points.size()):
		if i > 0:
			total += points[i].distance_to(points[i - 1])
		lengths.append(total)
	var sides: PackedVector2Array = PackedVector2Array()
	for i in range(points.size()):
		var side: Vector2 = Vector2.ZERO
		if i > 0:
			side += segment_side(points[i - 1], points[i])
		if i < points.size() - 1:
			side += segment_side(points[i], points[i + 1])
		sides.append(side.normalized() if side.length() > 0.01 else Vector2.ZERO)
	return {"points": points, "lengths": lengths, "total": total, "sides": sides}

static func segment_side(from: Vector2, to: Vector2) -> Vector2:
	var direction: Vector2 = to - from
	if direction.length() <= 0.01:
		return Vector2.ZERO
	return Vector2(-direction.normalized().y, direction.normalized().x)

# A point a share of the way along a path, walkers side by side across it.
func position_on(path: Dictionary, share: float, walker_index: int, key: int) -> Vector2:
	var points: PackedVector2Array = path["points"]
	if points.is_empty():
		return Vector2.ZERO
	var lengths: PackedFloat32Array = path["lengths"]
	var distance: float = clampf(share, 0.0, 1.0) * float(path["total"])
	var i: int = 1
	while i < points.size() - 1 and lengths[i] < distance:
		i += 1
	if points.size() == 1:
		return points[0]
	var span: float = maxf(lengths[i] - lengths[i - 1], 0.0001)
	var along: float = clampf((distance - lengths[i - 1]) / span, 0.0, 1.0)
	var position: Vector2 = points[i - 1].lerp(points[i], along)
	var sides: PackedVector2Array = path.get("sides", PackedVector2Array())
	var side: Vector2 = sides[i - 1].lerp(sides[i], along) if sides.size() == points.size() else segment_side(points[i - 1], points[i])
	var lane: float = (float(walker_index) - 0.5) * 1.6
	var bob: float = sin(view.walker_time * 5.0 + float(key + walker_index)) * 0.3
	return position + side * (lane + bob)

# Home is the family's house, or its tent at the camp.
func household_home(city: City, household_id: int, house_index: int) -> Vector2:
	if house_index >= 0 and house_index < city.buildings.size():
		var house: Building = city.buildings[house_index]
		return TownMapStyle.tile_rect(house.tile, house.size).get_center()
	var spots: Array[Vector2i] = view.camp_spots(TownMapView.camped_households(city).size())
	if spots.is_empty():
		return Vector2(view.map_size) * TownMapStyle.TILE * 0.5
	return (Vector2(spots[posmod(household_id, spots.size())]) + Vector2(0.5, 0.5)) * TownMapStyle.TILE

# A small figure seen from above: shadow, tunic in the family's color, head.
func draw_walker(position: Vector2, tunic: Color) -> void:
	RegionMapLayer.draw_blob(self, position + Vector2(0.9, 1.1), Vector2(1.5, 1.0), RegionMapStyle.COLOR_SHADOW, 8)
	RegionMapLayer.draw_blob(self, position, Vector2(1.3, 1.5), tunic, 8)
	draw_circle(position + Vector2(0.0, -1.3), 0.85, TownMapStyle.COLOR_SKIN)

# A load on a carrier's back: a sack of goods by default.
func draw_load(position: Vector2, color: Color = TownConstructionPainter.SACK) -> void:
	RegionMapLayer.draw_blob(self, position + Vector2(1.1, 0.2), Vector2(0.9, 1.0), color, 8)

# One of each family out on an errand (TownErrands), a different one each walk: water from the
# bank, firewood from the woods, goods from the store, or a visit to kin, bringing back what the
# errand is for.
func draw_errand_walkers(city: City) -> void:
	if not city.logistics.has_map():
		return
	var cycle: float = view.walker_time / maxf(view.walker_cycle_seconds, 0.01)
	for household: Household in city.households:
		var offset: float = fposmod(float(household.id) * 0.37 + 0.25, 1.0)
		var round_index: int = int(floor(cycle + offset))
		var kind: String = TownErrands.KINDS[posmod(round_index + household.id, TownErrands.KINDS.size())]
		var errand: Dictionary = city.errands.get_errand(household, kind)
		if (errand["route"] as Array).size() < 2:
			continue
		var key: Array = ["errand", household.id, kind]
		if not walker_paths.has(key):
			walker_paths[key] = make_path(errand["route"])
		var position: Vector2 = position_on(walker_paths[key], out_and_back(offset), 0, household.id * 13)
		draw_walker(position, TownMapStyle.preference_color(household.preference))
		if not phase_outbound(offset) and ERRAND_LOADS.has(kind):
			draw_load(position, ERRAND_LOADS[kind])

# Builders carry materials from the store along the site's delivery route while a site waits
# for them, then work on the site.
func draw_builders(city: City) -> void:
	for project: ConstructionProject in city.construction.projects:
		var site: Vector2 = TownMapStyle.tile_rect(project.get_site_tile()).get_center()
		var supplying: bool = project.get_stage() == ConstructionProject.STAGE_SUPPLYING and city.logistics.has_map()
		var delivery: Dictionary = {}
		if supplying:
			var key: Array = ["site", project.id]
			if not walker_paths.has(key):
				var route: Array = city.logistics.get_site_store_route(project.get_site_tile())["route"]
				walker_paths[key] = make_path(route)
			delivery = walker_paths[key]
		for i in range(project.crew_household_ids.size()):
			var household: Household = city.get_household_by_id(project.crew_household_ids[i])
			if household == null:
				continue
			var color: Color = TownMapStyle.preference_color(household.preference)
			if supplying and (delivery["points"] as PackedVector2Array).size() >= 2:
				# Routes run from the site to the store: loaded on the way back.
				var offset: float = float(i) * 0.3
				var position: Vector2 = position_on(delivery, out_and_back(offset), i, project.id * 7 + household.id)
				draw_walker(position, color)
				if not phase_outbound(offset):
					draw_load(position)
			else:
				var jitter: Vector2 = Vector2(sin(view.walker_time * 2.0 + float(i) * 2.1), cos(view.walker_time * 1.7 + float(i))) * TownMapStyle.TILE * 0.3
				draw_walker(site + jitter + Vector2((float(i) - 1.0) * TownMapStyle.TILE * 0.4, 0.0), color)

# --- Building sites ------------------------------------------------------------------------------

# A plate over each site: the brown part fills as materials arrive, the gold part as work is done.
func draw_site_plates(city: City) -> void:
	for project: ConstructionProject in city.construction.projects:
		var rect: Rect2 = TownMapStyle.tile_rect(project.get_site_tile()) if project.kind == ConstructionProject.KIND_ROAD else TownMapStyle.tile_rect(project.tile, project.size)
		var width: float = maxf(rect.size.x * 0.8, px(26.0))
		var plate: Rect2 = Rect2(Vector2(rect.get_center().x - width * 0.5, rect.position.y - px(PLATE_HEIGHT_PX) - px(2.0)), Vector2(width, px(PLATE_HEIGHT_PX)))
		draw_rect(plate.grow(px(1.0)), TownMapStyle.COLOR_PLATE)
		draw_rect(Rect2(plate.position, Vector2(plate.size.x * 0.3 * project.get_supply_fraction(), plate.size.y)), COLOR_SUPPLY)
		if project.get_progress() > 0.0:
			draw_rect(Rect2(plate.position + Vector2(plate.size.x * 0.3, 0.0), Vector2(plate.size.x * 0.7 * project.get_progress(), plate.size.y)), COLOR_WORK)
		if project.blocked_reason != "":
			draw_circle(Vector2(plate.end.x + px(5.0), plate.get_center().y), px(3.0), TownMapStyle.COLOR_VACANT)

func draw_road_preview() -> void:
	for tile: Vector2i in view.road_preview:
		var rect: Rect2 = TownMapStyle.tile_rect(tile).grow(-px(1.0))
		draw_rect(rect, RegionMapLayer.faded(TownMapStyle.COLOR_VALID, 0.35))
		draw_rect(rect, TownMapStyle.COLOR_VALID, false, px(1.0))

# Land set aside for homes: a light wash, and a line along its edge (and between plain and
# preferred land), so a block reads as one area rather than a grid of tiles.
func draw_residential(city: City) -> void:
	for y in range(city.local_map.size()):
		var row: Array = city.local_map[y]
		for x in range(row.size()):
			var level: int = int((row[x] as Dictionary).get(HomeSites.RESIDENTIAL_KEY, HomeSites.LAND_NONE))
			if level == HomeSites.LAND_NONE:
				continue
			var tile: Vector2i = Vector2i(x, y)
			var color: Color = COLOR_PREFERRED if level == HomeSites.LAND_PREFERRED else COLOR_RESIDENTIAL
			var rect: Rect2 = TownMapStyle.tile_rect(tile)
			draw_rect(rect, RegionMapLayer.faded(color, 0.28 if level == HomeSites.LAND_PREFERRED else 0.2))
			for side: Vector2i in RESIDENTIAL_SIDES:
				var next: Vector2i = tile + side
				if next.y >= 0 and next.y < city.local_map.size() and next.x >= 0 and next.x < row.size() and HomeSites.get_land(city, next) == level:
					continue
				var from: Vector2 = rect.get_center() + (Vector2(side) + Vector2(side.y, side.x)) * rect.size * 0.5
				var to: Vector2 = rect.get_center() + (Vector2(side) - Vector2(side.y, side.x)) * rect.size * 0.5
				draw_line(from, to, color, px(1.5))

# Woods marked for clearing and land marked for tilling (a tint that fills as the work goes on),
# and the block the clearing or tilling tool would mark.
func draw_clearing(city: City) -> void:
	for tile: Vector2i in city.woodland.marked.keys():
		draw_marked_tile(tile, float(city.woodland.marked[tile]) / EconomyBalance.CLEAR_DAYS_PER_TILE, COLOR_CLEARING)
	for tile: Vector2i in city.farmland.marked.keys():
		draw_marked_tile(tile, float(city.farmland.marked[tile]) / EconomyBalance.TILL_DAYS_PER_TILE, COLOR_TILLING)
	for tile: Vector2i in city.influence.get_work_ground():
		draw_marked_tile(tile, 0.0, COLOR_WORK_GROUND)
	if view.block_preview.size == Vector2i.ZERO:
		return
	var block: Rect2 = Rect2(TownMapStyle.tile_rect(view.block_preview.position).position, Vector2(view.block_preview.size) * TownMapStyle.TILE)
	draw_rect(block, RegionMapLayer.faded(TownMapStyle.COLOR_VALID, 0.12))
	draw_rect(block, TownMapStyle.COLOR_VALID, false, px(2.0))

func draw_marked_tile(tile: Vector2i, done: float, color: Color) -> void:
	var rect: Rect2 = TownMapStyle.tile_rect(tile).grow(-px(1.0))
	draw_rect(rect, RegionMapLayer.faded(color, 0.18 + 0.3 * clampf(done, 0.0, 1.0)))
	draw_rect(rect, color, false, px(1.0))

# The selected workplace's routes: its goods to the nearest store, its family from home.
func draw_routes(city: City) -> void:
	var index: int = view.inspected_index
	if index < 0 or index >= city.buildings.size() or not city.buildings[index].is_production_building():
		return
	var building: Building = city.buildings[index]
	var key: Array = [index, city.logistics.routes_version, building.assigned_household_id]
	if key != route_key:
		route_key = key
		var work: Vector2i = TownLogistics.center_tile(building.tile, building.size)
		var store: Vector2i = city.logistics.get_travel(building)["store_tile"]
		var household: Household = city.get_household_by_id(building.assigned_household_id)
		routes = [
			city.logistics.find_route(work, store) if store.x >= 0 else [],
			city.logistics.find_route(city.logistics.get_home_tile(household), work) if household != null else [],
		]
	draw_route(routes[0], COLOR_HAUL_ROUTE)
	draw_route(routes[1], COLOR_COMMUTE_ROUTE)

func draw_route(route: Array, color: Color) -> void:
	if route.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	# Routes run through tile middles and along the lines between tiles (TownLogistics cells).
	for cell: Vector2i in route:
		points.append(TownLogistics.cell_position(cell) * TownMapStyle.TILE)
	draw_polyline(points, Color(0.05, 0.05, 0.05, 0.55), px(4.0), true)
	draw_polyline(points, color, px(2.0), true)
	draw_circle(points[points.size() - 1], px(3.5), color)

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

# The selected building site or plot.
func draw_site_selection(city: City) -> void:
	var site: Rect2 = Rect2()
	var project: ConstructionProject = city.construction.get_project(view.inspected_project_id)
	if project != null:
		if project.kind == ConstructionProject.KIND_ROAD:
			for tile: Vector2i in project.road_tiles:
				draw_rect(TownMapStyle.tile_rect(tile), TownMapStyle.COLOR_SELECTION, false, px(1.5))
		else:
			site = TownMapStyle.tile_rect(project.tile, project.size)
	var plot: Dictionary = city.construction.get_plot(view.inspected_plot_id)
	if not plot.is_empty():
		site = TownMapStyle.tile_rect(plot["tile"], plot["size"])
	if site.has_area():
		draw_rect(site.grow(px(2.0)), RegionMapLayer.faded(TownMapStyle.COLOR_SELECTION, 0.16))
		draw_rect(site.grow(px(2.0)), TownMapStyle.COLOR_SELECTION, false, px(2.0))

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
	if view.preview_type == TownConstruction.PLOT:
		TownConstructionPainter.plot(canvas, rect, false)
	elif view.preview_type != TownWoodland.CLEAR and view.preview_type != TownFarmland.TILL and view.preview_type != TownConstruction.ROAD:
		TownBuildingPainter.draw(canvas, rect, BuildingVisuals.get_profile(view.preview_type), {"variant": 0.3, "lod": lod})
