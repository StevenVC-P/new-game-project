class_name FamilyAmbitions
extends RefCounted

# What families want (docs/FIRST_STAGE_LOOP.md, milestone 3; docs/IMPLEMENTATION_ROADMAP.md, M4).
# Each month a family without an ambition takes one, the first that applies:
#
# - a proper home: it lives in a tent, in the open, or in a hut;
# - its field fenced: it works a field people walk through;
# - work that fits its calling: it works a holding its calling is not drawn to, and the town's land
#   allows work that is (a fisher's hut for a family of the water, a lodge or woodcutter for a
#   family of the forest, ...).
#
# A fulfilled ambition makes a family content (Household.contentment): content families endure
# hard times longer before leaving, and draw newcomers. An ambition left waiting past its patience
# makes the family endure a little less. Families act on their own where the player has
# set the frame: they build homes on the player's plots (FamilyDevelopment) and fence their own
# trampled fields when the stores can spare the wood, and move to a free workplace of their calling
# when one stands empty. Work for their calling is a wish the player answers, not something
# families build themselves. Values will shape all of this later.
# Numbers in EconomyBalance (Ambitions).

const HOME: String = "home"
const CALLING: String = "calling"
const FENCE: String = "fence"

# The month's pass, before hardship is counted (HouseholdMigration.advance_month).
static func advance_month(city: City) -> void:
	for household: Household in city.households:
		if household.ambition != "" and is_fulfilled(city, household, household.ambition):
			household.contentment = mini(EconomyBalance.MAX_CONTENTMENT, household.contentment + EconomyBalance.FULFILLED_CONTENTMENT)
			household.fulfilled_ambitions += 1
			household.ambition = ""
			household.ambition_months = 0
		if household.ambition == "":
			household.ambition = choose(city, household)
			household.ambition_months = 0
		elif not still_wanted(city, household, household.ambition):
			household.ambition = ""
			household.ambition_months = 0
		else:
			household.ambition_months += 1
		# Contentment lasts while a family has all it wants, and fades while it wants something.
		if household.ambition != "":
			household.contentment_months += 1
			if household.contentment > 0 and household.contentment_months % EconomyBalance.CONTENTMENT_FADE_MONTHS == 0:
				household.contentment -= 1
		if household.ambition == FENCE:
			fence_own_field(city, household)
		elif household.ambition == CALLING:
			take_calling_work(city, household)

# The first ambition that applies, or "".
static func choose(city: City, household: Household) -> String:
	if wants_home(city, household):
		return HOME
	# A fence comes before a calling: families build it themselves, so it should not wait behind
	# a wish only the player can answer.
	if get_trampled_field(city, household) != null:
		return FENCE
	if wants_calling(city, household):
		return CALLING
	return ""

static func still_wanted(city: City, household: Household, ambition: String) -> bool:
	match ambition:
		HOME:
			return wants_home(city, household)
		CALLING:
			return wants_calling(city, household)
		FENCE:
			return get_own_field(city, household) != null
	return false

static func is_fulfilled(city: City, household: Household, ambition: String) -> bool:
	match ambition:
		HOME:
			return household.housing_status == Household.RESIDENCE_HOUSED and not city.is_household_in_rough_housing(household)
		CALLING:
			return works_its_calling(city, household)
		FENCE:
			var field: Building = get_own_field(city, household)
			return field != null and field.fenced
	return false

static func wants_home(city: City, household: Household) -> bool:
	return household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household)

# Working a holding its calling is not drawn to, while some work it is drawn to exists.
static func wants_calling(city: City, household: Household) -> bool:
	if household.assigned_workers <= 0 or not household.has_values() or works_its_calling(city, household):
		return false
	return not get_calling_work(household, city).is_empty()

static func works_its_calling(city: City, household: Household) -> bool:
	for building: Building in city.buildings:
		if building.assigned_household_id == household.id and household.get_match_quality(building.type) == CultureEffects.MATCH_GOOD:
			return true
	return false

# Workplace types its callings are drawn to that the town's land allows (water for a fisher's
# hut, woods for a lodge or woodcutter).
static func get_calling_work(household: Household, city: City) -> Array[String]:
	var types: Array[String] = []
	for building_type: String in CultureEffects.BUILDING_CALLINGS.keys():
		if building_type != "construction" and land_allows(city, building_type) and household.get_match_quality(building_type) == CultureEffects.MATCH_GOOD:
			types.append(building_type)
	return types

static func land_allows(city: City, building_type: String) -> bool:
	var kind: String = ""
	match building_type:
		Building.BUILDING_FISHER:
			kind = "water"
		Building.BUILDING_HUNTER, "woodcutter":
			kind = "woods"
	if kind == "" or city.local_map.is_empty():
		return true
	for row: Array in city.local_map:
		for tile: Dictionary in row:
			if (kind == "water" and tile["type"] == "water") or (kind == "woods" and tile["has_trees"] == true):
				return true
	return false

static func get_own_field(city: City, household: Household) -> Building:
	for building: Building in city.buildings:
		if building.assigned_household_id == household.id and TownLogistics.is_field(building):
			return building
	return null

static func get_trampled_field(city: City, household: Household) -> Building:
	var field: Building = get_own_field(city, household)
	if field != null and not field.fenced and float(city.logistics.trampled_trips.get(field.id, 0.0)) >= EconomyBalance.FENCE_WISH_TRIPS:
		return field
	return null

# A family wishing for its calling takes up work its calling is drawn to, giving up a holding it
# was given automatically. Two ways, both leaving every workplace worked:
# - it swaps with a family that holds such work automatically and is not drawn to it;
# - it takes up a free workplace, when another family is free to take up the holding it leaves
#   (a family does not abandon work the town needs).
# Work the player assigned stays as it is.
static func take_calling_work(city: City, household: Household) -> void:
	var held: Building = null
	for building: Building in city.buildings:
		if building.assigned_household_id == household.id and building.assignment_source == Building.ASSIGNMENT_AUTO and household.get_match_quality(building.type) != CultureEffects.MATCH_GOOD:
			held = building
			break
	if held == null:
		return
	for building: Building in city.buildings:
		if building == held or not building.is_production_building() or building.assignment_source != Building.ASSIGNMENT_AUTO or household.get_match_quality(building.type) != CultureEffects.MATCH_GOOD:
			continue
		var other: Household = city.get_household_by_id(building.assigned_household_id)
		if other != null and other != household and other.get_match_quality(building.type) != CultureEffects.MATCH_GOOD:
			building.assign_household(household, Building.ASSIGNMENT_AUTO)
			held.assign_household(other, Building.ASSIGNMENT_AUTO)
			city.update_household_assignments()
			return
	if not city.get_available_households().any(func(free: Household) -> bool: return free != household):
		return
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_workers <= 0 and not building.auto_assignment_blocked and household.get_match_quality(building.type) == CultureEffects.MATCH_GOOD:
			held.unassign_worker(false)
			building.assign_household(household, Building.ASSIGNMENT_AUTO)
			city.auto_assign_workers()
			return

# A family that wants its field fenced plans the fence itself when the stores can spare the wood.
static func fence_own_field(city: City, household: Household) -> void:
	var field: Building = get_own_field(city, household)
	if field == null or not city.construction.can_fence(field.id):
		return
	if city.construction.can_supply(EconomyBalance.get_fence_cost(field.size), FamilyDevelopment.STORE_RESERVE):
		city.construction.request_fence(field.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD)

# How much less hardship a family endures while an ambition waits past its patience. A strain,
# not hardship itself: it makes hard times harder but drives no one out alone. A home is left out:
# rough housing already costs hardship once its grace runs out (HouseholdMigration).
static func get_waiting_strain(household: Household) -> int:
	if household.ambition == "" or household.ambition == HOME:
		return 0
	return EconomyBalance.AMBITION_WAITING_STRAIN if household.ambition_months > EconomyBalance.AMBITION_PATIENCE_MONTHS else 0

# Town notices: wishes the player can answer, and how many families are content.
static func get_notices(city: City) -> Array[String]:
	var lines: Array[String] = []
	var calling_families: int = 0
	var wanted: Dictionary = {}
	var fence_families: int = 0
	var content_families: int = 0
	for household: Household in city.households:
		content_families += 1 if household.contentment > 0 else 0
		if household.ambition == FENCE:
			fence_families += 1
		elif household.ambition == CALLING:
			calling_families += 1
			for building_type: String in get_calling_work(household, city):
				wanted[building_type] = int(wanted.get(building_type, 0)) + 1
	if calling_families > 0:
		var types: Array = wanted.keys()
		types.sort_custom(func(a: String, b: String) -> bool: return int(wanted[a]) > int(wanted[b]) or (int(wanted[a]) == int(wanted[b]) and a < b))
		var names: Array[String] = []
		for building_type: String in types.slice(0, 2):
			names.append(BuildingTiers.get_display_name(building_type).to_lower())
		lines.append("Wishes: %d famil%s want work for their calling (%s)" % [calling_families, "y" if calling_families == 1 else "ies", ", ".join(names)])
	if fence_families > 0:
		lines.append("Wishes: %d famil%s want their trampled field fenced" % [fence_families, "y" if fence_families == 1 else "ies"])
	if content_families > 0:
		lines.append("Content: %d famil%s (they endure more and draw newcomers)" % [content_families, "y" if content_families == 1 else "ies"])
	return lines

# What a family wants, for its card.
static func describe(city: City, household: Household) -> String:
	match household.ambition:
		HOME:
			return "a proper home"
		CALLING:
			var names: Array[String] = []
			for building_type: String in get_calling_work(household, city):
				names.append(BuildingTiers.get_display_name(building_type).to_lower())
			return "work for its calling (" + ", ".join(names.slice(0, 3)) + ")"
		FENCE:
			return "its field fenced"
	return ""
