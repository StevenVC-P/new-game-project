class_name FamilyDevelopment
extends RefCounted

# Families developing their town on their own: the first piece of a town that grows without the
# player placing every building (docs/TOWN_BUILDING_MODEL.md). Every week, families who need a
# better home act through the same construction pipeline as the player (TownConstruction):
#
# - a family in a hut upgrades it in place to a house, when the stores can spare the materials;
# - a family without a home claims one of the residential plots the player designated and
#   builds a house there, or a hut when the stores cannot spare a house's materials; where
#   families lead and no plot is open, it chooses a site of its own near its work;
# - when the town has no empty home, a family with a grown child ready to marry builds one on a
#   plot for the new family (a marriage needs a home), Leave the Nest families first.
#
# Values decide who acts and where. Hearth-Proud families want a proper house at once; Simple
# Living families are content in a hut and build one; Town-Loving families settle near the
# town's heart and Open Country families toward its edge; every family prefers a plot close to
# its work.

# How often families look at their homes, and how many new projects they start at most each time.
const INTERVAL_DAYS: int = 7
const MAX_PROJECTS_PER_PASS: int = 2
# Months a family lives in a hut before it upgrades it (Hearth-Proud families do not wait).
const HUT_PATIENCE_MONTHS: int = 3
# Families leave this much in the stores for the town's workshops.
const STORE_RESERVE: Dictionary = {"wood": 10}
# How much each tile of a plot's distance from the town's heart weighs against a tile of walk to
# work: Town-Loving families pay to live closer, Open Country families walk farther for space.
const HEART_PULL: float = 1.5
# How far from its work a family looks for a site of its own for a home, in tiles.
const OWN_SITE_RADIUS: int = 12

static func advance(city: City) -> Array[ConstructionProject]:
	var started: Array[ConstructionProject] = []
	var construction: TownConstruction = city.construction
	construction.families_without_plot = 0
	if city.local_map.is_empty():
		return started
	for household: Household in city.households:
		if started.size() >= MAX_PROJECTS_PER_PASS:
			break
		if construction.get_home_project_for(household.id) != null:
			continue
		var project: ConstructionProject = null
		var hut: Building = get_hut(city, household)
		if hut != null:
			if wants_better_home(household) and construction.can_supply(EconomyBalance.get_build_cost(Building.BUILDING_HOUSE), STORE_RESERVE):
				project = construction.request_upgrade(hut.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id)
		elif household.housing_status != Household.RESIDENCE_HOUSED:
			project = claim_plot(city, household)
			if project == null:
				construction.families_without_plot += 1
		if project != null:
			started.append(project)
	if started.size() < MAX_PROJECTS_PER_PASS:
		var for_children: ConstructionProject = build_for_new_family(city)
		if for_children != null:
			started.append(for_children)
	return started

# One home at a time for a family about to form, when no home stands empty for it.
static func build_for_new_family(city: City) -> ConstructionProject:
	if not city.get_empty_house_building_ids().is_empty():
		return null
	for project: ConstructionProject in city.construction.projects:
		if project.is_home() and project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and project.claimant_household_id < 0:
			return null
	var parents: Array[Household] = []
	for household: Household in city.households:
		if household.can_form_new_family():
			parents.append(household)
	parents.sort_custom(func(a: Household, b: Household) -> bool:
		var a_first: bool = CultureEffects.has_family_formation_priority(a.values)
		var b_first: bool = CultureEffects.has_family_formation_priority(b.values)
		return a_first and not b_first or (a_first == b_first and a.id < b.id))
	for household: Household in parents:
		var project: ConstructionProject = claim_plot(city, household, false)
		if project != null:
			return project
	return null

static func get_hut(city: City, household: Household) -> Building:
	if household.housing_status != Household.RESIDENCE_HOUSED:
		return null
	var home_id: int = household.residence_building_id
	if home_id < 0 or home_id >= city.buildings.size() or not city.buildings[home_id].is_tier0():
		return null
	return city.buildings[home_id]

static func wants_better_home(household: Household) -> bool:
	if CultureValues.has_value(household.values, "simple_living"):
		return false
	if CultureValues.has_value(household.values, "hearth_proud"):
		return true
	return household.rough_housing_months >= HUT_PATIENCE_MONTHS

# Claims the best open plot and starts a home on it, for the family itself or (for_itself false)
# for whichever family needs it when it stands; null when there is no plot to claim.
# Where families lead (TownInfluence.enabled), a family finding no open plot chooses its own site
# (owner, 2026-10-31: laying out the town is not part of play for now).
static func claim_plot(city: City, household: Household, for_itself: bool = true) -> ConstructionProject:
	var home_type: String = "hut"
	if not CultureValues.has_value(household.values, "simple_living") and city.construction.can_supply(EconomyBalance.get_build_cost(Building.BUILDING_HOUSE), STORE_RESERVE):
		home_type = Building.BUILDING_HOUSE
	var tile: Vector2i = Vector2i(-1, -1)
	var plot: Variant = choose_plot(city, household)
	if plot != null:
		tile = plot["tile"]
	elif city.influence.enabled:
		tile = choose_own_site(city, household, home_type)
	if tile.x < 0:
		return null
	return city.construction.request_building(home_type, tile, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id if for_itself else -1)

# Where a family would build a home of its own choosing: by the same measure as choose_plot (the
# walk to its work, or to the stockpile, pulled toward or away from the heart by its values),
# among the valid spots nearest its work.
static func choose_own_site(city: City, household: Household, home_type: String) -> Vector2i:
	var logistics: TownLogistics = city.logistics
	logistics.ensure_ready()
	var work_tile: Vector2i = get_work_tile(city, household)
	var size: Vector2i = city.construction.get_size(home_type)
	var heart: Vector2 = Vector2(logistics.map_size()) * 0.5
	var pull: float = get_heart_pull(household)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	for radius in range(1, OWN_SITE_RADIUS + 1):
		for y in range(work_tile.y - radius, work_tile.y + radius + 1):
			for x in range(work_tile.x - radius, work_tile.x + radius + 1):
				if maxi(absi(x - work_tile.x), absi(y - work_tile.y)) != radius:
					continue
				var origin: Vector2i = Vector2i(x, y)
				if city.construction.validate(home_type, origin)["is_valid"] != true:
					continue
				var home_tile: Vector2i = TownLogistics.center_tile(origin, size)
				var score: float = logistics.effort_between(home_tile, work_tile)
				if is_inf(score):
					continue
				score += pull * Vector2(home_tile).distance_to(heart)
				if score < best_score:
					best = origin
					best_score = score
		# The nearest ring with a valid spot decides; farther rings only walk farther.
		if best.x >= 0:
			return best
	return best

static func get_work_tile(city: City, household: Household) -> Vector2i:
	if not household.assigned_building_ids.is_empty():
		var workplace: Building = city.buildings[household.assigned_building_ids[0]]
		return TownLogistics.center_tile(workplace.tile, workplace.size)
	return city.logistics.stockpile_tile

static func get_heart_pull(household: Household) -> float:
	if CultureValues.has_value(household.values, "town_loving"):
		return HEART_PULL
	if CultureValues.has_value(household.values, "open_country"):
		return -HEART_PULL
	return 0.0

# The open plot a family likes best: the shortest walk to its work (or to the stockpile when it
# has none), pulled toward or away from the town's heart by its Home and Place values.
static func choose_plot(city: City, household: Household) -> Variant:
	var logistics: TownLogistics = city.logistics
	logistics.ensure_ready()
	var work_tile: Vector2i = get_work_tile(city, household)
	var heart: Vector2 = Vector2(logistics.map_size()) * 0.5
	var pull: float = get_heart_pull(household)
	var best: Variant = null
	var best_score: float = INF
	for plot: Dictionary in city.construction.get_open_plots():
		var home_tile: Vector2i = TownLogistics.center_tile(plot["tile"], plot["size"])
		var score: float = logistics.effort_between(home_tile, work_tile)
		if is_inf(score):
			continue
		score += pull * Vector2(home_tile).distance_to(heart)
		if score < best_score:
			best = plot
			best_score = score
	return best
