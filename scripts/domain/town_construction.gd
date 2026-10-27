class_name TownConstruction
extends RefCounted

# Everything a town builds goes through here: the player's plans, families building their own
# homes (FamilyDevelopment), and later a town's own government. One pipeline, one set of rules:
#
# 1. A request is validated against the town map (BuildingPlacement) and reserves its land.
#    Nothing is paid up front.
# 2. Builders carry the materials from the nearest store to the site (TownLogistics), taking
#    them out of the stores only as they arrive, so a site waits while the stores are short.
# 3. With every material on site, builders work until the building is done; it then becomes a
#    real Building (a house's family moves in), an upgrade swaps its type in place, or a road
#    opens.
#
# Labor, in family-days: families without a holding are the town's builders and work a site full
# time, up to a crew per site. A family that works a holding can still give a little time
# (EconomyBalance.SPARE_TIME_SHARE) to its own new home or to tier 0 hand work, and its holding
# makes that much less that day. Tier 0 needs no materials, so a town can always raise huts,
# gardens, and camps, even with every family at work. Projects are worked in queue order.
# Design: docs/TOWN_BUILDING_MODEL.md.

const ROAD: String = "road"
const PLOT: String = "plot"
const PLOT_SIZE: Vector2i = Vector2i(2, 2)
# Construction work draws on these callings (masons and carpenters); see CultureEffects.
const CONSTRUCTION_WORK: String = "construction"

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
var placement: BuildingPlacement = BuildingPlacement.new()
var projects: Array[ConstructionProject] = []
# Residential plots the player designated: {"id", "tile", "size", "project_id"}. A plot is land
# kept for a home; a family claims it by starting a home on it, and it is gone once the home
# stands.
var plots: Array[Dictionary] = []
var next_project_id: int = 0
var next_plot_id: int = 0
var day: int = 0
# Today's share of each family's day spent building away from its holding (household id -> share).
var spare_time_today: Dictionary = {}
# Families who worked full time on a site today.
var builders_today: Array[int] = []
# The most recent things finished, newest last: {"label", "day"}.
var recent_completions: Array[Dictionary] = []
# Families who wanted to build a home last month but found no open residential plot.
var families_without_plot: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func logistics() -> TownLogistics:
	return city.logistics

func has_map() -> bool:
	return not city.local_map.is_empty()

# --- Requests ----------------------------------------------------------------------------------

func get_size(building_type: String) -> Vector2i:
	if building_type == ROAD:
		return Vector2i.ONE
	if building_type == PLOT:
		return PLOT_SIZE
	return placement.get_building_size(building_type)

# Whether a building, plot, or road tile can be planned at origin: {"is_valid", "message",
# "footprint"}. Materials are not checked: a site waits for them.
func validate(building_type: String, origin: Vector2i) -> Dictionary:
	var size: Vector2i = get_size(building_type)
	var footprint: Array[Vector2i] = TownLogistics.footprint(origin, size)
	if not has_map():
		return placement.make_result(true, "Valid placement", footprint)
	logistics().ensure_ready()
	if building_type == ROAD:
		if not is_roadable(origin):
			return placement.make_result(false, "Roads need open ground", footprint)
		return placement.make_result(true, "Valid placement", footprint)
	if BuildingTiers.get_base_type(building_type) == Building.BUILDING_HOUSE and get_open_plot_at(origin) != null:
		return placement.make_result(true, "On a residential plot", footprint)
	var rule_type: String = Building.BUILDING_HOUSE if building_type == PLOT else building_type
	return placement.validate(city, city.local_map, rule_type, origin, false)

# Plans a new building. Returns the project, or null when the land does not allow it.
func request_building(building_type: String, origin: Vector2i, requested_by: String = ConstructionProject.REQUESTED_BY_PLAYER, requester_household_id: int = -1, claimant_household_id: int = -1) -> ConstructionProject:
	if validate(building_type, origin)["is_valid"] != true:
		return null
	var project: ConstructionProject = make_project(ConstructionProject.KIND_BUILDING, building_type, requested_by, requester_household_id)
	project.tile = origin
	project.size = get_size(building_type)
	project.claimant_household_id = claimant_household_id
	project.materials_needed = EconomyBalance.get_build_cost(building_type)
	project.work_required = EconomyBalance.get_build_work_days(building_type)
	var plot: Variant = get_open_plot_at(origin) if project.is_home() else null
	if plot != null:
		plot["project_id"] = project.id
		project.plot_id = int(plot["id"])
	else:
		set_occupied(project.get_footprint(), true)
	return add_project(project)

# Plans upgrading a tier 0 building in place. It keeps working until the upgrade is done.
func request_upgrade(building_id: int, requested_by: String = ConstructionProject.REQUESTED_BY_PLAYER, requester_household_id: int = -1) -> ConstructionProject:
	if building_id < 0 or building_id >= city.buildings.size():
		return null
	var building: Building = city.buildings[building_id]
	var upgrade_type: String = BuildingTiers.get_upgrade_type(building.type)
	if upgrade_type == "" or get_upgrade_project(building_id) != null:
		return null
	var project: ConstructionProject = make_project(ConstructionProject.KIND_UPGRADE, upgrade_type, requested_by, requester_household_id)
	project.tile = building.tile
	project.size = building.size
	project.target_building_id = building_id
	project.materials_needed = EconomyBalance.get_build_cost(upgrade_type)
	project.work_required = EconomyBalance.get_build_work_days(upgrade_type) * EconomyBalance.UPGRADE_WORK_FRACTION
	if building.is_house():
		var resident: Household = city.get_household_for_building_id(building_id)
		project.claimant_household_id = resident.id if resident != null else -1
	return add_project(project)

# Plans a road over the given tiles; tiles that already carry a road are skipped.
func request_road(tiles: Array[Vector2i], requested_by: String = ConstructionProject.REQUESTED_BY_PLAYER) -> ConstructionProject:
	var new_tiles: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if not is_inside(tile):
			return null
		if (city.local_map[tile.y][tile.x] as Dictionary).get("has_road", false) == true:
			continue
		if not is_roadable(tile):
			return null
		if not new_tiles.has(tile):
			new_tiles.append(tile)
	if new_tiles.is_empty():
		return null
	var project: ConstructionProject = make_project(ConstructionProject.KIND_ROAD, ROAD, requested_by, -1)
	project.road_tiles = new_tiles
	project.tile = new_tiles[0]
	project.work_required = EconomyBalance.ROAD_WORK_DAYS_PER_TILE * new_tiles.size()
	set_occupied(new_tiles, true)
	return add_project(project)

# The easiest road between two tiles over ground a road can take (existing roads included),
# both ends included; empty when there is none.
func plan_road(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if not has_map() or not is_inside(from) or not is_inside(to):
		return route
	var size: Vector2i = logistics().map_size()
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y in range(size.y):
		for x in range(size.x):
			var tile: Dictionary = city.local_map[y][x]
			if tile.get("has_road", false) == true:
				grid.set_point_weight_scale(Vector2i(x, y), 0.5)
			elif not is_roadable(Vector2i(x, y)):
				grid.set_point_solid(Vector2i(x, y), true)
	if grid.is_point_solid(from) or grid.is_point_solid(to):
		return route
	for tile: Vector2i in grid.get_id_path(from, to):
		route.append(tile)
	return route

func is_roadable(tile: Vector2i) -> bool:
	if not is_inside(tile):
		return false
	var data: Dictionary = city.local_map[tile.y][tile.x]
	return LocalCityMapGenerator.is_buildable(data) and data["occupied"] != true and data.get("has_road", false) != true

func make_project(kind: String, building_type: String, requested_by: String, requester_household_id: int) -> ConstructionProject:
	var project: ConstructionProject = ConstructionProject.new()
	project.id = next_project_id
	next_project_id += 1
	project.kind = kind
	project.building_type = building_type
	project.requested_by = requested_by
	project.requester_household_id = requester_household_id
	project.created_day = day
	return project

func add_project(project: ConstructionProject) -> ConstructionProject:
	projects.append(project)
	logistics().mark_layout_changed()
	return project

# Drops a project. Materials already on site go back to the stores; the land is freed (a plot
# stays a plot, open to be claimed again).
func cancel(project_id: int) -> bool:
	var project: ConstructionProject = get_project(project_id)
	if project == null:
		return false
	for material: String in project.materials_delivered.keys():
		city.add_resource(material, int(project.materials_delivered[material]))
	if project.plot_id >= 0:
		var plot: Dictionary = get_plot(project.plot_id)
		if not plot.is_empty():
			plot["project_id"] = -1
	elif project.kind != ConstructionProject.KIND_UPGRADE:
		set_occupied(project.get_footprint(), false)
	projects.erase(project)
	logistics().mark_layout_changed()
	return true

# Moves a project to the front of the queue, so builders and materials go to it first.
func prioritize(project_id: int) -> bool:
	var project: ConstructionProject = get_project(project_id)
	if project == null:
		return false
	projects.erase(project)
	projects.insert(0, project)
	return true

# --- Plots -------------------------------------------------------------------------------------

func designate_plot(origin: Vector2i) -> int:
	if not has_map() or validate(PLOT, origin)["is_valid"] != true or get_plot_at(origin) != null:
		return -1
	var plot: Dictionary = {"id": next_plot_id, "tile": origin, "size": PLOT_SIZE, "project_id": -1}
	next_plot_id += 1
	plots.append(plot)
	set_occupied(TownLogistics.footprint(origin, PLOT_SIZE), true)
	logistics().mark_layout_changed()
	return int(plot["id"])

# Removes a plot nobody has started building on.
func remove_plot(plot_id: int) -> bool:
	var plot: Dictionary = get_plot(plot_id)
	if plot.is_empty() or int(plot["project_id"]) >= 0:
		return false
	set_occupied(TownLogistics.footprint(plot["tile"], plot["size"]), false)
	plots.erase(plot)
	logistics().mark_layout_changed()
	return true

func get_plot(plot_id: int) -> Dictionary:
	for plot: Dictionary in plots:
		if int(plot["id"]) == plot_id:
			return plot
	return {}

# The plot covering a tile, or null.
func get_plot_at(tile: Vector2i) -> Variant:
	for plot: Dictionary in plots:
		if Rect2i(plot["tile"], plot["size"]).has_point(tile):
			return plot
	return null

# An unclaimed plot whose corner is exactly this tile, or null.
func get_open_plot_at(origin: Vector2i) -> Variant:
	for plot: Dictionary in plots:
		if plot["tile"] == origin and int(plot["project_id"]) < 0:
			return plot
	return null

func get_open_plots() -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	for plot: Dictionary in plots:
		if int(plot["project_id"]) < 0:
			open.append(plot)
	return open

# --- Queries -----------------------------------------------------------------------------------

func get_project(project_id: int) -> ConstructionProject:
	for project: ConstructionProject in projects:
		if project.id == project_id:
			return project
	return null

func get_project_at_tile(tile: Vector2i) -> ConstructionProject:
	for project: ConstructionProject in projects:
		if project.kind != ConstructionProject.KIND_UPGRADE and project.contains_tile(tile):
			return project
	return null

func get_upgrade_project(building_id: int) -> ConstructionProject:
	for project: ConstructionProject in projects:
		if project.kind == ConstructionProject.KIND_UPGRADE and project.target_building_id == building_id:
			return project
	return null

func get_home_project_for(household_id: int) -> ConstructionProject:
	for project: ConstructionProject in projects:
		if project.claimant_household_id == household_id:
			return project
	return null

# Projects of a building type (or its tier 0 counterpart) not yet finished, upgrades included.
func count_planned(base_type: String) -> int:
	var count: int = 0
	for project: ConstructionProject in projects:
		if project.kind == ConstructionProject.KIND_BUILDING and BuildingTiers.get_base_type(project.building_type) == base_type:
			count += 1
	return count

# Materials still to be carried to every site in the queue.
func get_committed_materials() -> Dictionary:
	var committed: Dictionary = {}
	for project: ConstructionProject in projects:
		var remaining: Dictionary = project.get_remaining_materials()
		for material: String in remaining.keys():
			committed[material] = int(committed.get(material, 0)) + int(remaining[material])
	return committed

# Whether the stores hold a cost on top of what the queue still needs (and any reserve).
func can_supply(cost: Dictionary, reserve: Dictionary = {}) -> bool:
	var committed: Dictionary = get_committed_materials()
	for material: String in cost.keys():
		var free: int = int(city.resources.get(material, 0)) - int(committed.get(material, 0)) - int(reserve.get(material, 0))
		if free < int(cost[material]):
			return false
	return true

# A short, plain status for the sidebar and the site's card.
func get_status_text(project: ConstructionProject) -> String:
	if project.blocked_reason != "":
		return project.blocked_reason
	if project.get_stage() == ConstructionProject.STAGE_SUPPLYING:
		var parts: Array[String] = []
		for material: String in project.materials_needed.keys():
			parts.append("%d/%d %s" % [int(project.materials_delivered.get(material, 0)), int(project.materials_needed[material]), material])
		return "carrying " + ", ".join(parts)
	return "building %d%%" % int(round(project.get_progress() * 100.0))

static func get_display_name(project: ConstructionProject) -> String:
	if project.kind == ConstructionProject.KIND_ROAD:
		return "Road (%d tiles)" % project.road_tiles.size()
	var name: String = BuildingTiers.get_display_name(project.building_type)
	if project.kind == ConstructionProject.KIND_UPGRADE:
		return "Upgrade to " + name
	return name

# --- Daily work --------------------------------------------------------------------------------

func advance_day() -> void:
	day += 1
	spare_time_today.clear()
	builders_today.clear()
	if projects.is_empty():
		return
	logistics().ensure_ready()
	for project: ConstructionProject in projects:
		project.crew_household_ids.clear()
		project.blocked_reason = ""
	# Hungry families lose working days on sites as on their holdings.
	var hungry_day: bool = city.should_skip_for_food_shortage()
	var workable: Array[ConstructionProject] = []
	for project: ConstructionProject in projects:
		if can_progress(project):
			workable.append(project)
	if hungry_day:
		for project: ConstructionProject in workable:
			project.blocked_reason = "builders hungry today"
		return

	var free_families: Array[Household] = get_free_families()
	for project: ConstructionProject in workable:
		if free_families.is_empty():
			break
		while project.crew_household_ids.size() < project.get_max_crew() and not free_families.is_empty() and project.get_stage() != ConstructionProject.STAGE_DONE:
			var household: Household = take_builder(free_families, project)
			builders_today.append(household.id)
			project.crew_household_ids.append(household.id)
			apply_labor(project, get_builder_labor(household))
			if not can_progress(project):
				break

	for household: Household in city.households:
		if household.labor_capacity <= 0 or household.assigned_workers <= 0:
			continue
		var target: ConstructionProject = get_spare_time_project(household, workable)
		if target == null:
			continue
		project_add_spare(target, household)

	var finished: Array[ConstructionProject] = []
	for project: ConstructionProject in projects:
		if project.get_stage() == ConstructionProject.STAGE_DONE:
			finished.append(project)
		elif project.crew_household_ids.is_empty() and project.blocked_reason == "" and workable.has(project):
			project.blocked_reason = "no builders free"
	for project: ConstructionProject in finished:
		complete(project)

func project_add_spare(project: ConstructionProject, household: Household) -> void:
	project.crew_household_ids.append(household.id)
	spare_time_today[household.id] = EconomyBalance.SPARE_TIME_SHARE
	apply_labor(project, get_builder_labor(household) * EconomyBalance.SPARE_TIME_SHARE)

# A family at work on a holding gives spare time to its own home first, else to tier 0 work or a
# road, where the crew has room.
func get_spare_time_project(household: Household, workable: Array[ConstructionProject]) -> ConstructionProject:
	var fallback: ConstructionProject = null
	for project: ConstructionProject in workable:
		if project.crew_household_ids.size() >= project.get_max_crew() or not can_progress(project):
			continue
		if project.claimant_household_id == household.id:
			return project
		if fallback == null and (project.is_tier0() or project.kind == ConstructionProject.KIND_ROAD) and project.claimant_household_id < 0:
			fallback = project
	return fallback

# Whether builders could do anything on a site today; records why not when they cannot.
func can_progress(project: ConstructionProject) -> bool:
	if project.get_stage() == ConstructionProject.STAGE_DONE:
		return false
	if project.has_all_materials():
		return true
	if is_inf(logistics().get_site_haul_days_per_unit(project.get_site_tile())):
		project.blocked_reason = "no route from a store"
		return false
	var remaining: Dictionary = project.get_remaining_materials()
	for material: String in remaining.keys():
		if int(city.resources.get(material, 0)) > 0:
			return true
	var parts: Array[String] = []
	for material: String in remaining.keys():
		parts.append("%d %s" % [int(remaining[material]), material])
	project.blocked_reason = "waiting for " + ", ".join(parts)
	return false

# Families with no holding, best builders first.
func get_free_families() -> Array[Household]:
	var free: Array[Household] = []
	for household: Household in city.households:
		if household.labor_capacity > 0 and household.assigned_workers <= 0:
			free.append(household)
	free.sort_custom(func(a: Household, b: Household) -> bool:
		var labor_a: float = get_builder_labor(a)
		var labor_b: float = get_builder_labor(b)
		return labor_a > labor_b or (labor_a == labor_b and a.id < b.id))
	return free

# A home's own family builds it first; otherwise the best builder left.
func take_builder(free_families: Array[Household], project: ConstructionProject) -> Household:
	for i in range(free_families.size()):
		if free_families[i].id == project.claimant_household_id:
			var claimant: Household = free_families[i]
			free_families.remove_at(i)
			return claimant
	return free_families.pop_front()

# Family-days of work a family does in a full day on a site: half for a one-adult family, and its
# calling and work ethic apply as on a holding (masons and carpenters build best).
func get_builder_labor(household: Household) -> float:
	var labor: float = city.get_family_labor_factor(household)
	if household.has_values():
		labor *= float(100 + CultureEffects.get_work_output_percent(household.values, CONSTRUCTION_WORK)) / 100.0
	return labor

# Spends labor on a site: carrying the remaining materials first, then building.
func apply_labor(project: ConstructionProject, labor: float) -> void:
	var left: float = labor
	var per_unit: float = logistics().get_site_haul_days_per_unit(project.get_site_tile())
	while left > 0.0001 and not project.has_all_materials():
		var material: String = ""
		var remaining: Dictionary = project.get_remaining_materials()
		for candidate: String in remaining.keys():
			if int(city.resources.get(candidate, 0)) > 0:
				material = candidate
				break
		if material == "" or is_inf(per_unit):
			return
		var needed: float = per_unit - project.haul_progress
		if left < needed:
			project.haul_progress += left
			return
		left -= needed
		project.haul_progress = 0.0
		city.remove_resource(material, 1)
		project.materials_delivered[material] = int(project.materials_delivered.get(material, 0)) + 1
	if project.has_all_materials():
		project.work_done = minf(project.work_required, project.work_done + left)

func complete(project: ConstructionProject) -> void:
	projects.erase(project)
	match project.kind:
		ConstructionProject.KIND_ROAD:
			for tile: Vector2i in project.road_tiles:
				var data: Dictionary = city.local_map[tile.y][tile.x]
				data["occupied"] = false
				data["has_road"] = true
			logistics().mark_layout_changed()
		ConstructionProject.KIND_UPGRADE:
			city.complete_upgrade(project.target_building_id)
			move_claimant_in(project, project.target_building_id)
		_:
			if project.plot_id >= 0:
				var plot: Dictionary = get_plot(project.plot_id)
				plots.erase(plot)
			var building: Building = Building.new(-1, project.building_type, project.tile, project.size)
			var claimant: Household = city.get_household_by_id(project.claimant_household_id)
			if claimant != null and not wants_to_move_in(claimant, building):
				claimant = null
			city.add_building(building, claimant)
	recent_completions.append({"label": get_display_name(project), "day": day})
	while recent_completions.size() > 5:
		recent_completions.pop_front()

# A family moves into the home built for it unless it already has one at least as good.
func wants_to_move_in(household: Household, home: Building) -> bool:
	if household.housing_status != Household.RESIDENCE_HOUSED:
		return true
	return city.is_household_in_rough_housing(household) and not home.is_tier0()

func move_claimant_in(project: ConstructionProject, building_id: int) -> void:
	var claimant: Household = city.get_household_by_id(project.claimant_household_id)
	if claimant == null or claimant.residence_building_id == building_id:
		return
	if city.get_household_for_building_id(building_id) == null and wants_to_move_in(claimant, city.buildings[building_id]):
		claimant.move_to_house(building_id)
		city.update_shelter_counts()

# --- Helpers -----------------------------------------------------------------------------------

func is_inside(tile: Vector2i) -> bool:
	var size: Vector2i = logistics().map_size()
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

func set_occupied(tiles: Array[Vector2i], occupied: bool) -> void:
	if not has_map():
		return
	for tile: Vector2i in tiles:
		if is_inside(tile):
			(city.local_map[tile.y][tile.x] as Dictionary)["occupied"] = occupied
