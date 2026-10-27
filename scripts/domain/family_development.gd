class_name FamilyDevelopment
extends RefCounted

# Families developing their town on their own: the first piece of a town that grows without the
# player placing every building (docs/TOWN_BUILDING_MODEL.md). Once a month, families who need a
# better home act through the same construction pipeline as the player (TownConstruction):
#
# - a family in a hut upgrades it in place to a house, when the stores can spare the materials;
# - a family without a home claims one of the residential plots the player designated and
#   builds a house there, or a hut when the stores cannot spare a house's materials.
#
# Values decide who acts and where. Hearth-Proud families want a proper house at once; Simple
# Living families are content in a hut and build one; Town-Loving families settle near the
# town's heart and Open Country families toward its edge; every family prefers a plot close to
# its work.

const MAX_PROJECTS_PER_MONTH: int = 2
# Months a family lives in a hut before it upgrades it (Hearth-Proud families do not wait).
const HUT_PATIENCE_MONTHS: int = 3
# Families leave this much in the stores for the town's workshops.
const STORE_RESERVE: Dictionary = {"wood": 10}
# How much each tile of a plot's distance from the town's heart weighs against a tile of walk to
# work: Town-Loving families pay to live closer, Open Country families walk farther for space.
const HEART_PULL: float = 1.5

static func advance_month(city: City) -> Array[ConstructionProject]:
	var started: Array[ConstructionProject] = []
	var construction: TownConstruction = city.construction
	construction.families_without_plot = 0
	if city.local_map.is_empty():
		return started
	for household: Household in city.households:
		if started.size() >= MAX_PROJECTS_PER_MONTH:
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
	return started

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

# Claims the best open plot and starts a home on it; null when there is no plot to claim.
static func claim_plot(city: City, household: Household) -> ConstructionProject:
	var plot: Variant = choose_plot(city, household)
	if plot == null:
		return null
	var home_type: String = "hut"
	if not CultureValues.has_value(household.values, "simple_living") and city.construction.can_supply(EconomyBalance.get_build_cost(Building.BUILDING_HOUSE), STORE_RESERVE):
		home_type = Building.BUILDING_HOUSE
	return city.construction.request_building(home_type, plot["tile"], ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)

# The open plot a family likes best: the shortest walk to its work (or to the stockpile when it
# has none), pulled toward or away from the town's heart by its Home and Place values.
static func choose_plot(city: City, household: Household) -> Variant:
	var logistics: TownLogistics = city.logistics
	logistics.ensure_ready()
	var work_tile: Vector2i = logistics.stockpile_tile
	if not household.assigned_building_ids.is_empty():
		var workplace: Building = city.buildings[household.assigned_building_ids[0]]
		work_tile = TownLogistics.center_tile(workplace.tile, workplace.size)
	var heart: Vector2 = Vector2(logistics.map_size()) * 0.5
	var pull: float = 0.0
	if CultureValues.has_value(household.values, "town_loving"):
		pull = HEART_PULL
	elif CultureValues.has_value(household.values, "open_country"):
		pull = -HEART_PULL
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
