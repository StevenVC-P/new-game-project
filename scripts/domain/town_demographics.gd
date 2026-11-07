class_name TownDemographics
extends RefCounted

# A town's people as demographics (master roadmap Phase 1, Stage C; GAME_VISION.md, Families At
# Scale): households grouped by labour (industry, then occupation, by the primary holding they work)
# and by life stage. It reads the town and changes nothing. Today every record is one household;
# the same groups are what weighted family records will be indexed and reported by (Phase 4), so
# new household systems should reach households through group() rather than a loop of their own.

const NONE: String = "none"

# Occupation (a holding's tier 1 type) -> industry. A production holding not listed is a craft.
const INDUSTRY_OF: Dictionary = {
	"farm": "agriculture",
	"herder": "agriculture",
	"woodcutter": "forestry",
	"fisher": "fishing_and_hunting",
	"hunter": "fishing_and_hunting",
	"quarry": "extraction",
	"brickworks": "extraction",
	"mine": "extraction",
}
const INDUSTRY_CRAFTS: String = "crafts"

# The household's occupation: the tier 1 type of the holding it works, or NONE.
static func occupation_of(city: City, household: Household) -> String:
	var holding: Building = FamilyInitiative.get_holding(city, household)
	return BuildingTiers.get_base_type(holding.type) if holding != null else NONE

static func industry_of(occupation: String) -> String:
	if occupation == NONE:
		return NONE
	return str(INDUSTRY_OF.get(occupation, INDUSTRY_CRAFTS))

# The households of a town grouped by "industry", "occupation" or "life_stage": key -> households,
# in household order.
static func group(city: City, by: String) -> Dictionary:
	var groups: Dictionary = {}
	for household: Household in city.households:
		var key: String = key_of(city, household, by)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(household)
	return groups

static func key_of(city: City, household: Household, by: String) -> String:
	match by:
		"industry":
			return industry_of(occupation_of(city, household))
		"occupation":
			return occupation_of(city, household)
		"life_stage":
			return household.lifecycle_stage
	return NONE

# The labour table: industry -> occupation -> {"households", "people", "workers"}.
static func labour_table(city: City) -> Dictionary:
	var table: Dictionary = {}
	for household: Household in city.households:
		var occupation: String = occupation_of(city, household)
		var industry: String = industry_of(occupation)
		if not table.has(industry):
			table[industry] = {}
		var row: Dictionary = (table[industry] as Dictionary).get(occupation, {"households": 0, "people": 0, "workers": 0})
		row["households"] = int(row["households"]) + 1
		row["people"] = int(row["people"]) + household.total_population
		row["workers"] = int(row["workers"]) + household.working_adults
		table[industry][occupation] = row
	return table

# Life stages: stage -> {"households", "people"}.
static func life_stages(city: City) -> Dictionary:
	var stages: Dictionary = {}
	for household: Household in city.households:
		var row: Dictionary = stages.get(household.lifecycle_stage, {"households": 0, "people": 0})
		row["households"] = int(row["households"]) + 1
		row["people"] = int(row["people"]) + household.total_population
		stages[household.lifecycle_stage] = row
	return stages
