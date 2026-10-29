class_name HouseholdMigration
extends RefCounted

# M2: whole families arrive and leave (docs/SETTLEMENT_GROWTH_SCALE_MODEL.md, Growth Sources).
# Runs once per month from City.advance_household_lifecycle_month(). All numbers are tuning defaults.

const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const CultureEffectsScript = preload("res://scripts/domain/culture_effects.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")

# Regional pool, counted in families. Departing families return to it.
const POOL_START_FAMILIES: int = 5
const POOL_MAX_FAMILIES: int = 8
const POOL_REFILL_MONTHS: int = 4

# Attractiveness becomes the monthly arrival chance (percent), capped.
const BASE_ATTRACTION: int = 20
const FOOD_STORED_GOOD_DAYS: float = 20.0
const FOOD_STORED_GOOD_BONUS: int = 20
const FOOD_STORED_OK_DAYS: float = 10.0
const FOOD_STORED_OK_BONUS: int = 10
const RECENT_SHORTAGE_PENALTY: int = 40
const SOFT_NEED_MET_BONUS: int = 5
const SOFT_NEED_UNMET_PENALTY: int = 5
const MAX_ARRIVAL_CHANCE: int = 60

const NEWLYWED_ARRIVAL_CHANCE: int = 60
const REGIONAL_CULTURE_SAMPLE: int = 24

# Hardship points per month; a family leaves once points reach its value-adjusted threshold.
const HARDSHIP_SHORTAGE_DAYS: int = 10
const HARDSHIP_SHORTAGE_POINTS: int = 2
const HARDSHIP_UNSHELTERED_POINTS: int = 2
const HARDSHIP_RECOVERY_POINTS: int = 1
const DEPARTURE_WARNING_MARGIN: int = 2
# A housed family larger than this is crowded in a single house.
const CROWDED_ABOVE_POPULATION: int = 5

const BLOCKER_POOL_EMPTY: String = "no_families_in_region"
const BLOCKER_NO_HOUSE: String = "no_empty_house"
const BLOCKER_FOOD_SHORTAGE: String = "food_shortage"
const BLOCKER_FOOD_NOT_SUSTAINABLE: String = "food_production_too_low"

static func make_starting_resources() -> Dictionary:
	return {
		"regional_migrant_families": POOL_START_FAMILIES,
		"arrived_households": 0,
		"departed_households": 0,
		"shortage_days_this_month": 0,
		"households_considering_departure": 0,
		"migration_month_index": 0
	}

static func advance_month(city, city_index: int = 0) -> void:
	var month_index: int = int(city.resources["migration_month_index"]) + 1
	city.resources["migration_month_index"] = month_index

	FamilyAmbitions.advance_month(city)
	# Neighbours may share their rations before the shortage's hardship falls (TownSocial).
	city.social.share_in_shortage()
	update_hardship(city)
	city.social.review_month()
	for household: Household in city.households:
		household.shortage_hardship_adjust = 0
		household.long_weeks_this_month = 0
	resolve_departure(city, city_index)
	if month_index % POOL_REFILL_MONTHS == 0:
		city.resources["regional_migrant_families"] = min(POOL_MAX_FAMILIES, int(city.resources["regional_migrant_families"]) + 1)
	resolve_arrival(city, city_index, month_index)

	city.resources["households_considering_departure"] = get_households_considering_departure(city).size()
	city.resources["shortage_days_this_month"] = 0

# Rough housing (temporary shelter or a hut) is crowding for births. It becomes hardship only
# after ROUGH_HOUSING_GRACE_MONTHS, so founders have time to build. Overcrowded homes, no shelter,
# and food shortage are hardship.
static func is_household_crowded(household: Household, city = null) -> bool:
	if household.housing_status == Household.RESIDENCE_TEMPORARY:
		return true
	if city != null and city.is_household_in_rough_housing(household):
		return true
	return household.housing_status == Household.RESIDENCE_HOUSED and household.total_population > CROWDED_ABOVE_POPULATION

static func get_monthly_hardship_points(city, household: Household) -> int:
	var points: int = 0
	if int(city.resources["shortage_days_this_month"]) >= HARDSHIP_SHORTAGE_DAYS:
		# A family that shared its ration carries more of the shortage; one helped carries less.
		points += maxi(0, HARDSHIP_SHORTAGE_POINTS + household.shortage_hardship_adjust)
	# Long days out of a family's rest (TownSocial.choose_hours) wear on it.
	if household.long_weeks_this_month >= EconomyBalance.OVERWORK_WEEKS:
		points += EconomyBalance.OVERWORK_HARDSHIP_POINTS
	if household.housing_status == Household.RESIDENCE_UNSHELTERED:
		points += HARDSHIP_UNSHELTERED_POINTS
	if household.housing_status == Household.RESIDENCE_HOUSED and household.total_population > CROWDED_ABOVE_POPULATION:
		points += CultureEffectsScript.get_crowding_hardship_points(household.values)
	if household.rough_housing_months > EconomyBalanceScript.ROUGH_HOUSING_GRACE_MONTHS:
		points += CultureEffectsScript.get_crowding_hardship_points(household.values)
	return points

# Hardship is capped just past the threshold, so once conditions improve a family recovers in a
# few months instead of carrying an old crisis indefinitely.
static func update_hardship(city) -> void:
	for household: Household in city.households:
		if city.is_household_in_rough_housing(household):
			household.rough_housing_months += 1
		else:
			household.rough_housing_months = 0
		var points: int = get_monthly_hardship_points(city, household)
		household.suffered_hardship_this_month = points > 0
		if points > 0:
			var cap: int = get_departure_threshold(household) + DEPARTURE_WARNING_MARGIN
			household.hardship_points = min(cap, household.hardship_points + points)
		else:
			household.hardship_points = max(0, household.hardship_points - HARDSHIP_RECOVERY_POINTS)

# Content families (FamilyAmbitions) endure more before leaving; a family whose wish has waited
# too long endures less.
static func get_departure_threshold(household: Household) -> int:
	return CultureEffectsScript.get_departure_threshold(household.values) + household.contentment - FamilyAmbitions.get_waiting_strain(household)

static func is_considering_departure(household: Household) -> bool:
	return household.hardship_points > 0 and household.hardship_points >= get_departure_threshold(household) - DEPARTURE_WARNING_MARGIN

static func get_households_considering_departure(city) -> Array[Household]:
	var result: Array[Household] = []
	for household: Household in city.households:
		if is_considering_departure(household):
			result.append(household)
	return result

# At most one family leaves per month: the one furthest past its threshold. Families leave while
# times are hard, not after a crisis has passed.
static func resolve_departure(city, city_index: int) -> void:
	var leaving: Household = null
	var worst_margin: int = -1
	for household: Household in city.households:
		if not household.suffered_hardship_this_month:
			continue
		var margin: int = household.hardship_points - get_departure_threshold(household)
		if margin >= 0 and margin > worst_margin:
			leaving = household
			worst_margin = margin
	if leaving == null:
		return

	city.log_household_lifecycle_event(city_index, leaving.id, "HouseholdDeparted", "hardship=" + str(leaving.hardship_points) + " threshold=" + str(get_departure_threshold(leaving)))
	release_departing_household_work(city, leaving, city_index)
	city.households.erase(leaving)
	city.resources["departed_households"] = int(city.resources["departed_households"]) + 1
	city.resources["regional_migrant_families"] = min(POOL_MAX_FAMILIES, int(city.resources["regional_migrant_families"]) + 1)
	city.update_shelter_counts()
	# Remaining families take up the work the leavers left, so departures relieve a shortage
	# instead of deepening it.
	city.auto_assign_workers()

# Unlike City.cleanup_removed_household_assignments (used when an old couple passes on), this
# leaves the workplace open to auto-assignment: a family that leaves in hard times should not
# leave its farm idle while neighbors have labor to spare.
static func release_departing_household_work(city, household: Household, city_index: int) -> void:
	for building: Building in city.buildings:
		if building.assigned_household_id != household.id:
			continue
		city.log_household_lifecycle_event(city_index, household.id, "AssignmentClearedByDeparture", "building=" + str(building.id))
		building.unassign_worker(false)
		city.record_work_succession_vacancy(household, building, city_index)
	household.assigned_workers = 0
	household.assigned_building_ids.clear()

static func get_arrival_blocker(city, family_size: int = 2) -> String:
	if int(city.resources["regional_migrant_families"]) <= 0:
		return BLOCKER_POOL_EMPTY
	if city.get_empty_house_building_ids().is_empty():
		return BLOCKER_NO_HOUSE
	if city.resources["food_shortage"] == true:
		return BLOCKER_FOOD_SHORTAGE
	var consumption_after: int = city.get_food_consumption_for_population(city.get_total_population() + family_size)
	if estimate_daily_food_production(city) < float(consumption_after):
		return BLOCKER_FOOD_NOT_SUSTAINABLE
	return ""

static func get_attractiveness(city) -> int:
	var score: int = BASE_ATTRACTION
	var food_days: float = city.get_food_days_stored()
	if food_days >= FOOD_STORED_GOOD_DAYS:
		score += FOOD_STORED_GOOD_BONUS
	elif food_days >= FOOD_STORED_OK_DAYS:
		score += FOOD_STORED_OK_BONUS
	if int(city.resources["shortage_days_this_month"]) > 0:
		score -= RECENT_SHORTAGE_PENALTY

	for result in city.soft_need_results.values():
		if not (result is Dictionary):
			continue
		var status: String = str(result.get("status", ""))
		if status == "met":
			score += SOFT_NEED_MET_BONUS
		elif status == "unmet":
			score -= SOFT_NEED_UNMET_PENALTY

	var profiles: Array = []
	var content_families: int = 0
	for household: Household in city.households:
		profiles.append(household.values)
		content_families += 1 if household.contentment > 0 else 0
	score += CultureEffectsScript.get_community_attraction(profiles)
	# Word of content families travels.
	score += mini(EconomyBalanceScript.CONTENT_ATTRACTION_MAX, content_families * EconomyBalanceScript.CONTENT_ATTRACTION)
	return clampi(score, 0, MAX_ARRIVAL_CHANCE)

# Expected daily food from every worked workplace that makes food (farms, fishers, hunters),
# including value modifiers, upkeep, travel, and what the land within reach allows; seasons
# average out over a year and are left out.
static func estimate_daily_food_production(city) -> float:
	var total: float = 0.0
	for building: Building in city.buildings:
		var chain: Dictionary = EconomyBalanceScript.PRODUCTION.get(BuildingTiersScript.get_base_type(building.type), {})
		if str(chain.get("output", "")) != "food" or not building.can_produce():
			continue
		var percent: int = 0
		var household: Household = city.get_household_by_id(building.assigned_household_id)
		if household != null and household.has_values():
			percent = CultureEffectsScript.get_work_output_percent(household.values, building.type)
		total += float(city.get_base_building_output_amount(building.type)) * city.get_family_labor_factor(household) * float(100 + percent) / 100.0 * get_maintenance_output_factor(building.maintenance_level) * (1.0 - city.logistics.get_travel_share(building)) * city.land.get_reach_factor(building)
	return total

static func get_maintenance_output_factor(maintenance_level: int) -> float:
	if maintenance_level >= 100:
		return 1.0
	if maintenance_level >= 75:
		return 0.75
	if maintenance_level >= 50:
		return 0.5
	if maintenance_level >= 25:
		return 0.25
	return 0.0

static func resolve_arrival(city, city_index: int, month_index: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), month_index, "arrival"])
	var newlywed: bool = rng.randi_range(0, 99) < NEWLYWED_ARRIVAL_CHANCE
	var young_children: int = 0 if newlywed else rng.randi_range(1, 2)
	var family_size: int = 2 + young_children

	if get_arrival_blocker(city, family_size) != "":
		return
	if rng.randi_range(0, 99) >= get_attractiveness(city):
		return

	var house_id: int = int(city.get_empty_house_building_ids()[0])
	var household: Household = Household.new(city.get_next_household_id(), house_id, Household.WORK_PREF_NEUTRAL, family_size, Household.RESIDENCE_HOUSED)
	household.working_adults = 2
	household.young_children = young_children
	household.lifecycle_stage = Household.LIFECYCLE_NEWLYWED if newlywed else Household.LIFECYCLE_YOUNG_FAMILY
	household.origin_household_id = household.id
	household.generation = 0
	household.set_values(CultureValuesScript.inherit_profile([], rng, get_regional_value_counts(city)))
	household.family_trade = get_family_trade_for_calling(household.values)
	household.move_to_house(house_id)
	household.update_labor_capacity()
	city.households.append(household)

	city.resources["regional_migrant_families"] = int(city.resources["regional_migrant_families"]) - 1
	city.resources["arrived_households"] = int(city.resources["arrived_households"]) + 1
	city.log_household_lifecycle_event(city_index, household.id, "HouseholdArrived", "size=" + str(family_size) + " stage=" + household.lifecycle_stage + " family_trade=" + household.family_trade)
	city.update_shelter_counts()
	city.update_worker_counts()
	city.auto_assign_workers()

# Newcomers bring the culture of the region they come from, not the town's.
static func get_regional_value_counts(city) -> Dictionary:
	if not city.regional_value_counts.is_empty():
		return city.regional_value_counts
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), "region"])
	var profiles: Array = []
	for index in range(REGIONAL_CULTURE_SAMPLE):
		profiles.append(CultureValuesScript.make_random_profile(rng))
	city.regional_value_counts = CultureValuesScript.count_values(profiles)
	return city.regional_value_counts

static func get_family_trade_for_calling(profile: Dictionary) -> String:
	var callings: Array = profile.get(CultureValuesScript.CATEGORY_CALLING, [])
	if callings.has("soil"):
		return "farming"
	if callings.has("forest") or callings.has("forge_bench"):
		return "woodcraft"
	if callings.has("stone"):
		return "stonework"
	return "general"

static func get_arrival_blocker_text(blocker: String) -> String:
	if blocker == BLOCKER_POOL_EMPTY:
		return "no families looking to move"
	if blocker == BLOCKER_NO_HOUSE:
		return "no empty house"
	if blocker == BLOCKER_FOOD_SHORTAGE:
		return "food shortage"
	if blocker == BLOCKER_FOOD_NOT_SUSTAINABLE:
		return "farms can't feed more"
	return "families may arrive"
