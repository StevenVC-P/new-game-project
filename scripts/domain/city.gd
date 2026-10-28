class_name City
extends RefCounted

const GoodsNeedBucketHelperScript = preload("res://scripts/domain/goods_need_bucket_helper.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const CultureEffectsScript = preload("res://scripts/domain/culture_effects.gd")
const HouseholdMigrationScript = preload("res://scripts/domain/household_migration.gd")
const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")
const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const ROLE_PLAYER: String = "player"
const ROLE_NEUTRAL: String = "neutral"
const ROLE_DEBUG: String = "debug"
const WORK_PREF_NEUTRAL: String = "neutral"
const WORK_PREF_AGRARIAN: String = "agrarian"
const WORK_PREF_INDUSTRIAL: String = "industrial"
# Economy numbers live in scripts/domain/economy_balance.gd.
const TOOLMAKER_WOOD_INPUT: int = EconomyBalanceScript.TOOLMAKER_WOOD_PER_TOOL
const STARTER_NEUTRAL_WORKERS: int = 0
const STARTING_HOUSEHOLD_COUNT: int = 3
const STARTING_HOUSEHOLD_POPULATION: int = 4
# Founders draw their life stage from the first this-many seed shapes (excludes old couples).
const FOUNDING_LIFE_STAGE_SHAPES: int = 4
const STARTING_POPULATION: int = STARTING_HOUSEHOLD_COUNT * STARTING_HOUSEHOLD_POPULATION
const HOUSE_CAPACITY: int = 4
const FOOD_PER_POPULATION_DIVISOR: int = EconomyBalanceScript.PEOPLE_FED_PER_FOOD
const OLDER_CHILD_SUPPORT_TICK_INTERVAL: int = 4
const RESOURCE_HISTORY_LIMIT: int = 16
const BIRTH_FOOD_SURPLUS_DAYS: float = 10.0
const BIRTH_MIN_FOOD_DAYS: float = 5.0
const BIRTH_FOOD_SURPLUS_BONUS: int = 5
const BIRTH_HOUSING_HEADROOM_BONUS: int = 5
const BIRTH_REQUIRED_HOUSING_HEADROOM: int = 2
const OLD_COUPLE_MIN_MORTALITY_MONTHS: int = 12
# Production is skipped one tick in this many during a food shortage (25% loss).
const FOOD_SHORTAGE_SKIP_TICK_INTERVAL: int = 4
const SUCCESSION_AUTO_FILL_MONTHS: int = 2
# Marriage (M3). How long a grown child waits before marrying an outsider is cultural:
# CultureEffects.get_outsider_marriage_wait_months().
const MARRIAGE_LINEAGE_PREFERENCE: int = 10
const LINEAGE_RULES: Array[String] = ["fathers_line", "mothers_line", "strongest_line"]
# Used when no family in the town holds a lineage rule.
const DEFAULT_LINEAGE_RULE: String = "fathers_line"
const ENABLE_HOUSEHOLD_LIFECYCLE_LOGS: bool = true

var name: String = "City"
var role: String = ROLE_PLAYER
var tile: Vector2 = Vector2.ZERO
var local_map: Array = []
var buildings: Array[Building] = []
var households: Array[Household] = []
var resources: Dictionary = {}
var resource_history: Array = []
var soft_need_results: Dictionary = {}
# Mixed into every random roll the town makes (founders, values, newcomers, marriages).
var founding_seed: int = 0
# Value counts of the region newcomers come from; generated on first arrival.
var regional_value_counts: Dictionary = {}
# Producing buildings by type, refreshed each tick; read by Communal Labor.
var operating_building_counts: Dictionary = {}
var site_profile: SettlementSiteProfile = SettlementSiteProfile.new()
# How goods and people move around the town map, and everything being built (docs/TOWN_BUILDING_MODEL.md).
var logistics: TownLogistics = null
var construction: TownConstruction = null
# Woods marked for clearing, and woods spreading.
var woodland: TownWoodland = null
# Land marked to till into farmland.
var farmland: TownFarmland = null
# Families' own trips from home: the store, water, firewood, kin.
var errands: TownErrands = null
# What the land and season give each workplace, and the season's hazards.
var land: TownLand = null
# Traders from the neutral town, and the town's link to them.
var trade: TownTrade = null
# Bandits on the roads, the watch, and the militia.
var defense: TownDefense = null
# The settlement's stage (camp, hamlet, village) and chronicle.
var settlement: SettlementStage = null
# What the community asks of families who develop their own work (influence prototype; off unless
# enabled).
var influence: TownInfluence = null
# How households deal with one another and what the community expects of them (household social
# prototype; off unless enabled).
var social: TownSocial = null
# Proper workplaces short of tools work by hand instead of standing idle (influence prototype).
var hand_method_fallback: bool = false
# Today's day of the year (1-360), set by the game before each day's tick; -1 where nothing sets
# it (tests, balance tools), which count years from founding instead.
var day_of_year: int = -1

# `random_seed` makes each founding differ between games; 0 (the default, used by tests and
# tools) keeps a town reproducible from its tile alone.
func _init(city_name: String = "City", city_tile: Vector2 = Vector2.ZERO, city_role: String = ROLE_PLAYER, starter_household_count: int = STARTING_HOUSEHOLD_COUNT, random_seed: int = 0):
	name = city_name
	tile = city_tile
	role = get_normalized_role(city_role)
	logistics = TownLogistics.new(self)
	construction = TownConstruction.new(self)
	woodland = TownWoodland.new(self)
	farmland = TownFarmland.new(self)
	errands = TownErrands.new(self)
	land = TownLand.new(self)
	trade = TownTrade.new(self)
	defense = TownDefense.new(self)
	settlement = SettlementStage.new(self)
	influence = TownInfluence.new(self)
	founding_seed = random_seed
	social = TownSocial.new(self)
	var normalized_household_count: int = max(0, starter_household_count)
	resources = make_starting_resources(normalized_household_count)
	create_starter_households(normalized_household_count)
	recalculate_household_succession_pressures()
	update_shelter_counts()
	record_resource_history()

func get_normalized_role(city_role: String) -> String:
	if city_role == ROLE_PLAYER or city_role == ROLE_NEUTRAL or city_role == ROLE_DEBUG:
		return city_role

	return ROLE_PLAYER

func set_role(city_role: String) -> void:
	role = get_normalized_role(city_role)

func is_player_city() -> bool:
	return role == ROLE_PLAYER

func is_neutral_city() -> bool:
	return role == ROLE_NEUTRAL

func is_debug_city() -> bool:
	return role == ROLE_DEBUG

func is_controllable_city() -> bool:
	return is_player_city() or is_debug_city()

func should_tick_simulation() -> bool:
	return is_player_city() or is_debug_city()

func make_starting_resources(starter_household_count: int = STARTING_HOUSEHOLD_COUNT) -> Dictionary:
	var starting_population: int = starter_household_count * STARTING_HOUSEHOLD_POPULATION
	var starting: Dictionary = {
		"food": EconomyBalanceScript.STARTING_FOOD,
		"wood": EconomyBalanceScript.STARTING_WOOD,
		"tools": EconomyBalanceScript.STARTING_TOOLS,
		"stone_blocks": 0,
		"cut_stone": 0,
		"bricks": 0,
		"masonry": 0,
		"lime": 0,
		"mortar": 0,
		"statues": 0,
		"carved_goods": 0,
		"tiles": 0,
		"paving_stones": 0,
		"clothing": 0,
		"wool": 0,
		"house_shelter_capacity": 0,
		"temporary_shelter_capacity": starting_population,
		"housing_capacity": starting_population,
		"housed_population": 0,
		"temporary_sheltered_population": starting_population,
		"sheltered_population": starting_population,
		"unsheltered_population": 0,
		"total_population": 0,
		"household_count": 0,
		"total_labor_capacity": 0,
		"assigned_workers": 0,
		"idle_workers": 0,
		"food_consumption_rate": 2,
		"food_shortage": false,
		"production_tick_count": 0
	}
	starting.merge(HouseholdMigrationScript.make_starting_resources())
	return starting

# Founding families are random: each gets a random life stage (never an old couple, so founders
# do not pass on in the first year) and a fully random value profile, calling included; its
# family trade follows its calling.
func create_starter_households(starter_household_count: int = STARTING_HOUSEHOLD_COUNT):
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([founding_seed, int(tile.x), int(tile.y), "founders"])

	for household_index in range(starter_household_count):
		var household: Household = Household.new(household_index, -1, WORK_PREF_NEUTRAL, STARTING_HOUSEHOLD_POPULATION, Household.RESIDENCE_TEMPORARY)
		seed_starter_household_lifecycle(household, rng.randi_range(0, FOUNDING_LIFE_STAGE_SHAPES - 1))
		households.append(household)
	ensure_founding_farmer(rng)

# Farms are the only food source, so every founding includes at least one family called to the
# soil (owner decision 2026-10-20). Everything else about the founders stays random.
func ensure_founding_farmer(rng: RandomNumberGenerator):
	if households.is_empty():
		return
	for household: Household in households:
		if CultureValuesScript.has_value(household.values, "soil"):
			return

	var farmer: Household = households[rng.randi_range(0, households.size() - 1)]
	var callings: Array = (farmer.values[CultureValuesScript.CATEGORY_CALLING] as Array).duplicate()
	callings[rng.randi_range(0, callings.size() - 1)] = "soil"
	var profile: Dictionary = farmer.values.duplicate(true)
	profile[CultureValuesScript.CATEGORY_CALLING] = callings
	farmer.set_values(profile)
	farmer.family_trade = HouseholdMigrationScript.get_family_trade_for_calling(farmer.values)

# `shape_index` picks the family's life stage and children (0-3; 4 is an old couple).
func seed_starter_household_lifecycle(household: Household, shape_index: int):
	var seed_index: int = shape_index % 5
	household.parent_household_id = -1
	household.origin_household_id = household.id
	household.generation = 0
	household.succession_pressure = 0

	if seed_index == 0:
		household.lifecycle_stage = "young_family"
		household.young_children = 2
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 1
	elif seed_index == 1:
		household.lifecycle_stage = "established_family"
		household.young_children = 1
		household.older_children = 1
		household.adult_children = 0
		household.age_in_stage = 2
	elif seed_index == 2:
		household.lifecycle_stage = "mature_family"
		household.young_children = 0
		household.older_children = 1
		household.adult_children = 1
		household.age_in_stage = 3
	elif seed_index == 3:
		household.lifecycle_stage = "newlywed"
		household.young_children = 0
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 0
	else:
		household.lifecycle_stage = "old_couple"
		household.young_children = 0
		household.older_children = 0
		household.adult_children = 0
		household.age_in_stage = 4

	household.set_values(CultureValuesScript.make_random_profile(make_values_rng(household, "seed")))
	household.family_trade = HouseholdMigrationScript.get_family_trade_for_calling(household.values)

	# Seeds are constructed at a flat starting population; derive it from the seeded family so
	# couples without children (newlywed, old couple) are not counted as four people.
	household.total_population = household.working_adults + household.get_total_child_count()
	household.update_labor_capacity()
	household.recalculate_succession_pressure()

# Deterministic per household and purpose, so the same world seed reproduces the same culture.
func make_values_rng(household: Household, purpose: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([founding_seed, household.id, household.generation, int(tile.x), int(tile.y), purpose])
	return rng

func get_settlement_value_counts() -> Dictionary:
	var profiles: Array = []
	for household: Household in households:
		if household.has_values():
			profiles.append(household.values)
	return CultureValuesScript.count_values(profiles)

func get_household_defining_values(household: Household, limit: int = 3) -> Array[String]:
	if household == null or not household.has_values():
		return []
	return CultureValuesScript.get_defining_values(household.values, get_settlement_value_counts(), households.size(), limit)

func advance_household_lifecycle_month(city_index: int = 0):
	log_household_lifecycle_event(city_index, -1, "MonthAgingPass", "households=" + str(households.size()))
	for household: Household in households:
		var before_state: Dictionary = get_household_lifecycle_log_state(household)
		household.advance_lifecycle_month()
		log_household_lifecycle_event(city_index, household.id, "MonthAged", "age_in_stage=" + str(household.age_in_stage) + " child_age_months=" + str(household.child_age_months))
		log_household_lifecycle_state_changes(city_index, household, before_state)
	recalculate_household_succession_pressures(city_index)
	advance_new_family_formation_month(city_index)
	recalculate_household_succession_pressures(city_index)
	advance_old_couple_lifecycle_completion_month(city_index)
	recalculate_household_succession_pressures(city_index)
	advance_work_succession_vacancies(city_index)
	HouseholdMigrationScript.advance_month(self, city_index)
	update_shelter_counts()
	update_worker_counts()

func recalculate_household_succession_pressures(city_index: int = 0):
	for household: Household in households:
		var previous_pressure: int = household.succession_pressure
		household.recalculate_succession_pressure()
		if household.succession_pressure != previous_pressure:
			log_household_lifecycle_event(city_index, household.id, "SuccessionPressureRecalculated", "from=" + str(previous_pressure) + " to=" + str(household.succession_pressure) + " potential_new_families=" + str(household.get_potential_new_family_count()))
		elif household.has_succession_pressure():
			log_household_lifecycle_event(city_index, household.id, "SuccessionReady", "potential_new_families=" + str(household.get_potential_new_family_count()))

# M3: a grown child marries a grown child of another household (never a sibling). With no
# partner in town for a culturally set wait, they marry someone from outside.
# Each household marries off at most one child per month.
func advance_new_family_formation_month(city_index: int = 0):
	var ready: Array[Household] = []
	for household: Household in get_family_formation_order():
		if not household.can_form_new_family():
			household.family_formation_wait_months = 0
			continue
		household.family_formation_wait_months += 1
		if household.family_formation_wait_months > CultureEffectsScript.get_family_formation_delay_months(household.values):
			ready.append(household)

	var married_this_month: Array[int] = []
	for household: Household in ready:
		if married_this_month.has(household.id) or household.adult_children <= 0:
			continue

		var partner: Household = find_marriage_partner(household, ready, married_this_month)
		var outsider_wait: int = CultureEffectsScript.get_family_formation_delay_months(household.values) + CultureEffectsScript.get_outsider_marriage_wait_months(household.values)
		if partner == null and household.family_formation_wait_months <= outsider_wait:
			continue

		var partner_text: String = "outsider"
		if partner != null:
			partner_text = str(partner.id)
		log_household_lifecycle_event(city_index, household.id, "NewFamilyFormationAttempted", "adult_children=" + str(household.adult_children) + " partner=" + partner_text)
		var house_id: int = find_empty_house_building_id()
		if house_id < 0:
			log_household_lifecycle_event(city_index, household.id, "NewFamilyFormationBlocked", "reason=no_empty_house adult_children=" + str(household.adult_children))
			return

		form_family_by_marriage(household, partner, house_id, city_index)
		married_this_month.append(household.id)
		if partner != null:
			married_this_month.append(partner.id)

# Clannish families prefer partners from their own lineage; others prefer a different lineage.
func find_marriage_partner(household: Household, ready: Array[Household], married_this_month: Array[int]) -> Household:
	var best: Household = null
	var best_score: int = -9999
	for candidate: Household in ready:
		if candidate.id == household.id or married_this_month.has(candidate.id) or candidate.adult_children <= 0:
			continue
		var same_lineage: bool = get_lineage_origin_id(candidate) == get_lineage_origin_id(household)
		var score: int = 0
		for side: Household in [household, candidate]:
			var clannish: bool = CultureValuesScript.has_value(side.values, "clannish")
			if same_lineage and clannish:
				score += MARRIAGE_LINEAGE_PREFERENCE
			elif same_lineage or clannish:
				score -= MARRIAGE_LINEAGE_PREFERENCE
		if best == null or score > best_score:
			best = candidate
			best_score = score
	return best

func get_lineage_origin_id(household: Household) -> int:
	if household.origin_household_id >= 0:
		return household.origin_household_id
	return household.id

func get_lineage_household_count(origin_id: int) -> int:
	var count: int = 0
	for household: Household in households:
		if get_lineage_origin_id(household) == origin_id:
			count += 1
	return count

func get_household_lineage_rule(household: Household) -> String:
	for rule: String in LINEAGE_RULES:
		if CultureValuesScript.has_value(household.values, rule):
			return rule
	return ""

# When the two families agree, their rule applies; otherwise the town's most common rule does.
func resolve_marriage_lineage_rule(first: Household, second: Household) -> String:
	var first_rule: String = get_household_lineage_rule(first)
	if second == null:
		if first_rule != "":
			return first_rule
		return get_settlement_lineage_rule()
	if first_rule != "" and first_rule == get_household_lineage_rule(second):
		return first_rule
	return get_settlement_lineage_rule()

func get_settlement_lineage_rule() -> String:
	var best_rule: String = DEFAULT_LINEAGE_RULE
	var best_count: int = 0
	for rule: String in LINEAGE_RULES:
		var count: int = 0
		for household: Household in households:
			if CultureValuesScript.has_value(household.values, rule):
				count += 1
		if count > best_count:
			best_rule = rule
			best_count = count
	return best_rule

func choose_lineage_parent(groom_side: Household, bride_side: Household, rule: String) -> Household:
	if rule == "mothers_line":
		return bride_side
	if rule == "strongest_line":
		if get_lineage_household_count(get_lineage_origin_id(bride_side)) > get_lineage_household_count(get_lineage_origin_id(groom_side)):
			return bride_side
	return groom_side

# Leave the Nest families get first claim on empty houses; otherwise the existing order is kept.
func get_family_formation_order() -> Array[Household]:
	var first: Array[Household] = []
	var rest: Array[Household] = []
	for household: Household in households:
		if CultureEffectsScript.has_family_formation_priority(household.values):
			first.append(household)
		else:
			rest.append(household)
	first.append_array(rest)
	return first

func find_empty_house_building_id() -> int:
	var open_house_ids: Array[int] = get_empty_house_building_ids()
	if open_house_ids.is_empty():
		return -1

	return int(open_house_ids[0])

# `partner` is null when the spouse comes from outside the town; the family then joins the
# town household's lineage.
func form_family_by_marriage(household: Household, partner: Household, house_id: int, city_index: int = 0):
	var partner_id: int = -1
	if partner != null:
		partner_id = partner.id
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([founding_seed, household.id, partner_id, household.generation, int(tile.x), int(tile.y), "marriage"])

	var lineage_parent: Household = household
	var other_parent: Household = partner
	if partner != null:
		var groom_side: Household = household
		var bride_side: Household = partner
		if rng.randi_range(0, 1) == 1:
			groom_side = partner
			bride_side = household
		lineage_parent = choose_lineage_parent(groom_side, bride_side, resolve_marriage_lineage_rule(household, partner))
		if lineage_parent == household:
			other_parent = partner
		else:
			other_parent = household

	for side in [household, partner]:
		if side == null:
			continue
		var adult_children_before: int = side.adult_children
		side.spend_adult_child_for_marriage()
		side.family_formation_wait_months = 0
		log_household_lifecycle_event(city_index, side.id, "NewFamilyParentUpdated", "adult_children=" + str(adult_children_before) + "->" + str(side.adult_children) + " total_population=" + str(side.total_population))

	var new_household: Household = Household.new(get_next_household_id(), house_id, lineage_parent.preference, 2, Household.RESIDENCE_HOUSED)
	new_household.lifecycle_stage = Household.LIFECYCLE_NEWLYWED
	new_household.young_children = 0
	new_household.older_children = 0
	new_household.adult_children = 0
	new_household.age_in_stage = 0
	new_household.child_age_months = 0
	new_household.working_adults = 2
	new_household.parent_household_id = lineage_parent.id
	new_household.second_parent_household_id = -1
	if other_parent != null:
		new_household.second_parent_household_id = other_parent.id
	new_household.spouse_from_outside = partner == null
	new_household.origin_household_id = get_lineage_origin_id(lineage_parent)
	new_household.generation = lineage_parent.generation + 1
	new_household.family_trade = get_inherited_family_trade(lineage_parent, new_household, city_index)

	var parent_profiles: Array = [lineage_parent.values]
	if other_parent != null:
		parent_profiles.append(other_parent.values)
	else:
		# The outside spouse brings the region's culture.
		parent_profiles.append(CultureValuesScript.inherit_profile([], rng, HouseholdMigrationScript.get_regional_value_counts(self)))
	new_household.set_values(CultureValuesScript.inherit_profile(parent_profiles, make_values_rng(new_household, "inherit"), get_settlement_value_counts()))

	new_household.succession_pressure = 0
	new_household.move_to_house(house_id)
	new_household.update_labor_capacity()
	households.append(new_household)
	log_household_lifecycle_event(city_index, new_household.id, "NewFamilyFormed", "lineage_parent=" + str(lineage_parent.id) + " other_parent=" + str(new_household.second_parent_household_id) + " outside_spouse=" + str(new_household.spouse_from_outside) + " house=" + str(house_id))
	log_household_lifecycle_event(city_index, new_household.id, "LineageAssigned", "origin=" + str(new_household.origin_household_id) + " generation=" + str(new_household.generation) + " family_trade=" + new_household.family_trade)

func get_inherited_family_trade(parent: Household, child: Household, city_index: int = 0) -> String:
	var parent_trade: String = parent.family_trade
	if parent_trade.strip_edges() == "":
		parent_trade = "general"

	var related_trades: Array[String] = get_related_family_trades(parent_trade)
	var roll: int = get_family_trade_inheritance_roll(parent, child, city_index)
	if roll < 75:
		return parent_trade
	if roll < 95 and related_trades.size() > 0:
		return related_trades[roll % related_trades.size()]

	return "general"

func get_family_trade_inheritance_roll(parent: Household, child: Household, city_index: int = 0) -> int:
	var seed_value: int = parent.id * 43
	seed_value += child.id * 97
	seed_value += city_index * 131
	seed_value += child.generation * 29
	seed_value += int(tile.x) * 17
	seed_value += int(tile.y) * 19
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func get_related_family_trades(family_trade: String) -> Array[String]:
	if family_trade == "farming":
		return ["food_processing"]
	if family_trade == "woodcraft":
		return ["construction", "toolmaking"]
	if family_trade == "stonework":
		return ["construction", "masonry"]
	if family_trade == "claywork":
		return ["construction"]
	if family_trade == "textile":
		return []
	if family_trade == "food_processing":
		return ["farming"]
	if family_trade == "toolmaking":
		return ["woodcraft", "stonework"]
	if family_trade == "construction":
		return ["woodcraft", "stonework"]

	return []

func advance_old_couple_lifecycle_completion_month(city_index: int = 0):
	var active_households: Array[Household] = households.duplicate()
	for household: Household in active_households:
		if household.lifecycle_stage != Household.LIFECYCLE_OLD_COUPLE:
			continue
		if household.adult_children > 0:
			log_household_lifecycle_event(city_index, household.id, "OldCoupleRemovalBlocked", "reason=adult_children_remaining adult_children=" + str(household.adult_children))
			continue
		var chance: int = get_old_couple_lifecycle_completion_chance(household)
		if chance <= 0:
			continue
		var roll: int = get_old_couple_lifecycle_completion_roll(household, city_index)
		log_household_lifecycle_event(city_index, household.id, "OldCoupleMortalityRoll", "roll=" + str(roll) + " chance=" + str(chance) + " age_in_stage=" + str(household.age_in_stage))
		if roll >= chance:
			continue

		complete_old_couple_lifecycle(household, city_index)

func get_old_couple_lifecycle_completion_chance(household: Household) -> int:
	if household.age_in_stage < OLD_COUPLE_MIN_MORTALITY_MONTHS:
		return 0
	if household.age_in_stage < 24:
		return 5
	if household.age_in_stage < 36:
		return 10
	if household.age_in_stage < 48:
		return 20

	return 35

func get_old_couple_lifecycle_completion_roll(household: Household, city_index: int = 0) -> int:
	var seed_value: int = household.id * 41
	seed_value += city_index * 109
	seed_value += household.age_in_stage * 31
	seed_value += int(tile.x) * 11
	seed_value += int(tile.y) * 17
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func complete_old_couple_lifecycle(household: Household, city_index: int = 0):
	var house_id: int = household.residence_building_id
	log_household_lifecycle_event(city_index, household.id, "OldCoupleLifecycleComplete", "age_in_stage=" + str(household.age_in_stage))
	cleanup_removed_household_assignments(household, city_index)
	if house_id >= 0:
		log_household_lifecycle_event(city_index, household.id, "HouseFreed", "house=" + str(house_id))
	households.erase(household)
	log_household_lifecycle_event(city_index, household.id, "HouseholdRemoved", "reason=old_couple_lifecycle_complete")

func cleanup_removed_household_assignments(household: Household, city_index: int = 0):
	for building: Building in buildings:
		if building.assigned_household_id != household.id:
			continue

		log_household_lifecycle_event(city_index, household.id, "AssignmentCleared", "building=" + str(building.id))
		building.unassign_worker(true)
		record_work_succession_vacancy(household, building, city_index)
	household.assigned_workers = 0
	household.assigned_building_ids.clear()

func record_work_succession_vacancy(removed_household: Household, building: Building, city_index: int = 0):
	if building == null or not building.is_production_building():
		return

	building.succession_source_household_id = removed_household.id
	building.preferred_successor_household_id = -1
	log_household_lifecycle_event(city_index, removed_household.id, "WorkSuccessionVacancy", "building=" + str(building.id) + " trade=" + removed_household.family_trade)

	var heir: Household = get_immediate_work_heir(removed_household)
	if heir != null:
		building.assign_household(heir, Building.ASSIGNMENT_AUTO)
		# Keep labor counts current so one heir is not handed more work than it can do.
		update_household_assignments()
		log_household_lifecycle_event(city_index, heir.id, "WorkInherited", "building=" + str(building.id) + " from_household=" + str(removed_household.id))
		return
	building.succession_vacancy_months = 0

	var preferred_candidate: Dictionary = get_preferred_work_successor(removed_household, building)
	if preferred_candidate.is_empty():
		return

	var successor: Household = preferred_candidate["household"] as Household
	var priority: String = preferred_candidate["priority"] as String
	building.preferred_successor_household_id = successor.id
	log_household_lifecycle_event(city_index, successor.id, "WorkSuccessionCandidate", "building=" + str(building.id) + " source_household=" + str(removed_household.id) + " priority=" + priority)
	log_household_lifecycle_event(city_index, successor.id, "WorkSuccessionPreferred", "building=" + str(building.id) + " reason=" + priority)

# A direct child's family with spare labor inherits the work with no gap. Same-trade heirs first.
func get_immediate_work_heir(removed_household: Household) -> Household:
	var heir: Household = null
	for household: Household in households:
		if household == removed_household or not household.is_child_of(removed_household.id):
			continue
		if household.housing_status == Household.RESIDENCE_UNSHELTERED or household.get_available_workers() <= 0:
			continue
		if heir == null or (household.family_trade == removed_household.family_trade and heir.family_trade != removed_household.family_trade):
			heir = household
	return heir

# Workplaces with no heir wait for the player; after SUCCESSION_AUTO_FILL_MONTHS the game fills
# them, preferring the suggested successor. Future: when Houses or rivals compete for control
# of a workplace, this wait could lengthen (docs/IMPLEMENTATION_ROADMAP.md, Future Feature Notes).
func advance_work_succession_vacancies(city_index: int = 0):
	var filled_any: bool = false
	for building: Building in buildings:
		if building.succession_vacancy_months < 0 or building.assigned_workers > 0:
			continue
		building.succession_vacancy_months += 1
		if building.succession_vacancy_months < SUCCESSION_AUTO_FILL_MONTHS:
			continue

		var successor: Household = get_household_by_id(building.preferred_successor_household_id)
		if successor == null or successor.get_available_workers() <= 0:
			successor = find_auto_assignment_household(building)
		if successor == null:
			# No one free yet: open it to ordinary auto-assignment instead of holding it.
			building.auto_assignment_blocked = false
			continue
		building.assign_household(successor, Building.ASSIGNMENT_AUTO)
		update_household_assignments()
		filled_any = true
		log_household_lifecycle_event(city_index, successor.id, "WorkSuccessionAutoFilled", "building=" + str(building.id))
	if filled_any:
		update_worker_counts()

func get_household_descendants(household_id: int) -> Array[Household]:
	var result: Array[Household] = []
	for household: Household in households:
		if household.is_child_of(household_id):
			result.append(household)

	return result

func get_work_succession_candidates(removed_household: Household, building: Building) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for household: Household in households:
		if household.id == removed_household.id:
			continue
		if not is_household_available_for_work_succession(household):
			continue

		var priority: String = get_work_succession_priority(removed_household, household)
		if priority == "":
			continue

		result.append({
			"household": household,
			"priority": priority,
			"score": get_work_succession_priority_score(priority)
		})

	sort_work_succession_candidates(result)
	return result

func get_preferred_work_successor(removed_household: Household, building: Building) -> Dictionary:
	var candidates: Array[Dictionary] = get_work_succession_candidates(removed_household, building)
	if candidates.is_empty():
		return {}

	return candidates[0]

func is_household_available_for_work_succession(household: Household) -> bool:
	if household.housing_status != Household.RESIDENCE_HOUSED:
		return false
	if household.get_available_workers() <= 0:
		return false
	for building: Building in buildings:
		if building.assigned_household_id == household.id:
			return false

	return true

func get_work_succession_priority(removed_household: Household, candidate: Household) -> String:
	var same_trade: bool = candidate.family_trade == removed_household.family_trade
	if candidate.is_child_of(removed_household.id):
		if same_trade:
			return "direct_child_same_trade"
		return "direct_child"
	if removed_household.origin_household_id >= 0 and candidate.origin_household_id == removed_household.origin_household_id and candidate.generation > removed_household.generation:
		if same_trade:
			return "origin_descendant_same_trade"
		return "origin_descendant"
	if same_trade:
		return "same_family_trade"

	return ""

func get_work_succession_priority_score(priority: String) -> int:
	if priority == "direct_child_same_trade":
		return 0
	if priority == "direct_child":
		return 1
	if priority == "origin_descendant_same_trade":
		return 2
	if priority == "origin_descendant":
		return 3
	if priority == "same_family_trade":
		return 4

	return 99

func sort_work_succession_candidates(candidates: Array[Dictionary]):
	for outer_index in range(candidates.size()):
		for inner_index in range(outer_index + 1, candidates.size()):
			var outer_candidate: Dictionary = candidates[outer_index]
			var inner_candidate: Dictionary = candidates[inner_index]
			if should_swap_work_succession_candidates(outer_candidate, inner_candidate):
				candidates[outer_index] = inner_candidate
				candidates[inner_index] = outer_candidate

func should_swap_work_succession_candidates(left: Dictionary, right: Dictionary) -> bool:
	var left_score: int = int(left["score"])
	var right_score: int = int(right["score"])
	if right_score < left_score:
		return true
	if right_score > left_score:
		return false

	var left_household: Household = left["household"] as Household
	var right_household: Household = right["household"] as Household
	return right_household.id < left_household.id

func get_household_succession_status(household: Household) -> String:
	if household == null:
		return "none"
	if not household.has_succession_pressure():
		return "none"
	if get_empty_house_building_ids().size() > 0:
		return "ready_for_new_family"

	return "blocked_no_house"

func get_household_succession_status_text(household: Household) -> String:
	var status: String = get_household_succession_status(household)
	if status == "ready_for_new_family":
		var family_count: int = household.get_potential_new_family_count()
		if family_count == 1:
			return "Succession: 1 future family ready"
		return "Succession: " + str(family_count) + " future families ready"
	if status == "blocked_no_house":
		return "Succession: Blocked - no empty house"

	return "Succession: No pressure"

func advance_household_birth_rolls_season(calendar: Calendar, city_index: int = 0):
	update_shelter_counts()
	for household: Household in households:
		if has_birth_blocker(household):
			log_household_lifecycle_event(city_index, household.id, "BirthBlocked", "reason=" + get_birth_blocker_reason(household))
			continue

		var chance: int = get_birth_roll_chance(household)
		if chance <= 0:
			continue

		var roll: int = get_birth_roll_for_household(household, calendar, city_index)
		log_household_lifecycle_event(city_index, household.id, "BirthRollEvaluated", "roll=" + str(roll) + " chance=" + str(chance) + " season=" + calendar.get_current_season() + " year=" + str(calendar.current_year))
		if roll < chance:
			household.add_young_child_from_birth()
			log_household_lifecycle_event(city_index, household.id, "BirthSucceeded", "young_children=" + str(household.young_children) + " total_population=" + str(household.total_population) + " working_adults=" + str(household.working_adults) + " labor_capacity=" + str(household.labor_capacity))

	update_shelter_counts()
	update_worker_counts()

func get_birth_roll_for_household(household: Household, calendar: Calendar, city_index: int = 0) -> int:
	var seed_value: int = household.id * 37
	seed_value += city_index * 101
	seed_value += calendar.current_year * 503
	seed_value += calendar.current_month * 29
	seed_value += int(tile.x) * 7
	seed_value += int(tile.y) * 13
	var mixed_value: int = abs(seed_value * 1103515245 + 12345)
	return mixed_value % 100

func get_birth_roll_chance(household: Household) -> int:
	if has_birth_blocker(household):
		return 0

	var chance: int = household.get_birth_base_chance()
	chance += CultureEffectsScript.get_birth_chance_bonus(household.values)
	if HouseholdMigrationScript.is_household_crowded(household, self):
		chance += CultureEffectsScript.get_crowding_birth_penalty(household.values)
	if get_food_days_stored() >= BIRTH_FOOD_SURPLUS_DAYS:
		chance += BIRTH_FOOD_SURPLUS_BONUS
	if get_housing_headroom() >= BIRTH_REQUIRED_HOUSING_HEADROOM:
		chance += BIRTH_HOUSING_HEADROOM_BONUS

	return clampi(chance, 0, 30)

func has_birth_blocker(household: Household) -> bool:
	return get_birth_blocker_reason(household) != ""

func get_birth_blocker_reason(household: Household) -> String:
	if household == null:
		return "unknown_birth_blocker"
	if resources["food_shortage"] == true:
		return "food_shortage"
	if household.lifecycle_stage == Household.LIFECYCLE_OLD_COUPLE:
		return "old_couple"
	if household.housing_status == Household.RESIDENCE_UNSHELTERED:
		return "not_housed"
	if household.young_children >= 2:
		return "too_many_young_children"
	if household.get_total_child_count() >= 4:
		return "too_many_total_children"
	if get_food_days_stored() < BIRTH_MIN_FOOD_DAYS:
		return "food_stored_below_5_days"
	if not household.can_receive_birth():
		if household.get_birth_base_chance() <= 0:
			return "stage_not_eligible"
		return "unknown_birth_blocker"

	return ""

func get_family_growth_status_text(household: Household) -> String:
	var blocker: String = get_birth_blocker_reason(household)
	if blocker != "":
		return "Family growth: " + get_birth_blocker_player_text(blocker)

	return "Family growth: possible"

func get_birth_blocker_player_text(blocker: String) -> String:
	if blocker == "old_couple" or blocker == "stage_not_eligible":
		return "blocked by age"
	if blocker == "food_shortage" or blocker == "food_stored_below_5_days":
		return "blocked by food"
	if blocker == "not_housed" or blocker == "temporary_housing" or blocker == "housing_full" or blocker == "no_housing_headroom":
		return "blocked by housing"
	if blocker == "too_many_young_children" or blocker == "too_many_total_children":
		return "child limit reached"

	return "not eligible"

func get_food_days_stored() -> float:
	var consumption_rate: int = max(1, int(resources["food_consumption_rate"]))
	return float(int(resources["food"])) / float(consumption_rate)

func get_housing_headroom() -> int:
	return int(resources["housing_capacity"]) - get_total_population()

func get_household_lifecycle_log_state(household: Household) -> Dictionary:
	return {
		"lifecycle_stage": household.lifecycle_stage,
		"age_in_stage": household.age_in_stage,
		"child_age_months": household.child_age_months,
		"young_children": household.young_children,
		"older_children": household.older_children,
		"adult_children": household.adult_children,
		"succession_pressure": household.succession_pressure,
		"total_population": household.total_population
	}

func log_household_lifecycle_state_changes(city_index: int, household: Household, before_state: Dictionary):
	var before_stage: String = before_state["lifecycle_stage"] as String
	if before_stage != household.lifecycle_stage:
		log_household_lifecycle_event(city_index, household.id, "StageTransition", "from=" + before_stage + " to=" + household.lifecycle_stage)

	var before_young: int = int(before_state["young_children"])
	var before_older: int = int(before_state["older_children"])
	var before_adult: int = int(before_state["adult_children"])
	if before_young != household.young_children or before_older != household.older_children or before_adult != household.adult_children:
		log_household_lifecycle_event(city_index, household.id, "ChildCohortsMoved", "young=" + str(before_young) + "->" + str(household.young_children) + " older=" + str(before_older) + "->" + str(household.older_children) + " adult=" + str(before_adult) + "->" + str(household.adult_children))

func log_household_lifecycle_event(city_index: int, household_id: int, event_name: String, detail: String = ""):
	if not ENABLE_HOUSEHOLD_LIFECYCLE_LOGS:
		return

	var line: String = "[HouseholdLifecycle] City=" + str(city_index) + " Household=" + str(household_id) + " Event=" + event_name
	if detail.strip_edges() != "":
		line += " " + detail
	print(line)

# Adds a finished building. One built for a family (household) is theirs: they move into a house
# before other families without a home are housed, and take on a workplace before it is offered
# to anyone else.
func add_building(building: Building, household: Household = null):
	building.id = buildings.size()
	building.works_by_hand_without_tools = hand_method_fallback
	buildings.append(building)
	logistics.mark_layout_changed()
	if building.is_production_building() and household != null:
		building.assign_household(household, Building.ASSIGNMENT_AUTO)
	if building.is_house():
		if household != null:
			household.move_to_house(building.id)
		assign_households_to_housing()

	update_shelter_counts()
	update_worker_counts()
	auto_assign_workers()

# Proper workplaces short of tools keep their buildings and work by hand (influence prototype).
func set_hand_method_fallback(on: bool) -> void:
	hand_method_fallback = on
	for building: Building in buildings:
		building.works_by_hand_without_tools = on

func get_day_of_year() -> int:
	if day_of_year > 0:
		return day_of_year
	return posmod(construction.day - 1, Calendar.DAYS_PER_YEAR) + 1

# 0 spring, 1 summer, 2 autumn, 3 winter.
func get_season_index() -> int:
	return clampi((get_day_of_year() - 1) / Calendar.DAYS_PER_MONTH / 3, 0, 3)

func tick():
	update_shelter_counts()
	resources["production_tick_count"] = int(resources["production_tick_count"]) + 1
	update_worker_counts()
	consume_food()
	refresh_operating_building_counts()
	construction.advance_day()
	if construction.day % FamilyDevelopment.INTERVAL_DAYS == 0:
		FamilyDevelopment.advance(self)
	# A day after families look at their homes, and from the first day, so founders take up work
	# at once.
	if influence.enabled and construction.day % FamilyInitiative.INTERVAL_DAYS == 1:
		FamilyInitiative.advance(self)
	social.advance_day()
	land.advance_day()

	for building: Building in buildings:
		if building.is_house():
			continue
		if building.needs_maintenance():
			if building.upkeep_grace_days > 0:
				building.upkeep_grace_days -= 1
			else:
				update_building_maintenance(building)
		if building.can_produce():
			apply_building_production(building)
	logistics.advance_day()
	woodland.advance_day()
	farmland.advance_day()
	trade.advance_day()
	defense.advance_day()
	settlement.advance_day()

	resolve_soft_needs()
	if resources["food_shortage"] == true:
		resources["shortage_days_this_month"] = int(resources["shortage_days_this_month"]) + 1

func update_worker_counts():
	update_shelter_counts()
	var total_labor_capacity: int = get_total_labor_capacity()
	var assigned_workers: int = 0

	for building: Building in buildings:
		if building.is_house():
			continue

		assigned_workers += building.assigned_workers

	if assigned_workers > total_labor_capacity:
		assigned_workers = total_labor_capacity
	resources["total_labor_capacity"] = total_labor_capacity
	resources["assigned_workers"] = assigned_workers
	resources["idle_workers"] = max(0, total_labor_capacity - assigned_workers)
	update_household_worker_capacities()
	update_household_assignments()

func get_available_neutral_workers() -> int:
	var neutral_workers: int = min(STARTER_NEUTRAL_WORKERS, int(resources["total_population"]))

	for building: Building in buildings:
		if building.assigned_workers <= 0:
			continue
		if building.assigned_household_id == -1:
			neutral_workers -= building.assigned_workers

	return max(0, neutral_workers)

func get_household_by_id(household_id: int) -> Household:
	for household: Household in households:
		if household.id == household_id:
			return household

	return null

func get_household_for_building_id(building_id: int) -> Household:
	for household: Household in households:
		if household.residence_building_id == building_id:
			return household

	return null

func update_household_worker_capacities():
	for household: Household in households:
		household.update_labor_capacity()
		household.worker_capacity = household.labor_capacity

func update_household_assignments():
	for household: Household in households:
		household.assigned_workers = 0
		household.assigned_building_ids.clear()

	for building: Building in buildings:
		if building.assigned_household_id < 0:
			continue

		var household: Household = get_household_by_id(building.assigned_household_id)
		if household != null:
			household.assign_to_building(building.id, building.assigned_workers)

func get_house_worker_capacity(house_index: int) -> int:
	update_household_worker_capacities()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.worker_capacity

func get_assigned_workers_from_house(house_index: int) -> int:
	update_household_assignments()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.assigned_workers

func get_available_workers_from_house(house_index: int) -> int:
	update_household_worker_capacities()
	update_household_assignments()
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return 0

	return household.get_available_workers()

func get_available_workers_from_household(household_id: int) -> int:
	update_household_worker_capacities()
	update_household_assignments()
	var household: Household = get_household_by_id(household_id)
	if household == null:
		return 0

	return household.get_available_workers()

func get_available_households() -> Array[Household]:
	update_household_worker_capacities()
	update_household_assignments()
	var result: Array[Household] = []

	for household: Household in households:
		if household.is_available():
			result.append(household)

	return result

func get_household_counts_by_preference() -> Dictionary:
	var result: Dictionary = {
		WORK_PREF_AGRARIAN: 0,
		WORK_PREF_INDUSTRIAL: 0,
		WORK_PREF_NEUTRAL: 0
	}

	for household: Household in households:
		result[household.preference] = int(result[household.preference]) + 1

	return result

func get_household_preference_for_building(house_index: int) -> String:
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return WORK_PREF_NEUTRAL

	return household.preference

func get_household_label(household_id: int) -> String:
	var household: Household = get_household_by_id(household_id)
	if household == null:
		return "Household ?"

	return "Household " + str(household.id + 1)

func get_assigned_building_ids_for_house(house_index: int) -> Array[int]:
	update_household_assignments()
	var result: Array[int] = []
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return result

	for building_id: int in household.assigned_building_ids:
		result.append(building_id)

	return result

func get_assigned_house_building_id(building: Building) -> int:
	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return -1

	return household.residence_building_id

func get_household_preference_for_worker_modifier(building: Building) -> String:
	if building.assigned_household_id < 0:
		return WORK_PREF_NEUTRAL

	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return WORK_PREF_NEUTRAL

	return household.preference

func assign_household_to_building(building_index: int, house_index: int):
	var household: Household = get_household_for_building_id(house_index)
	if household == null:
		return

	assign_household_by_id_to_building(building_index, household.id)

func assign_household_by_id_to_building(building_index: int, household_id: int):
	if building_index < 0 or building_index >= buildings.size():
		return

	var household: Household = get_household_by_id(household_id)
	if household == null:
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return
	if building.assigned_workers > 0:
		return
	if get_available_workers_from_household(household_id) <= 0:
		return

	building.assign_household(household, Building.ASSIGNMENT_PLAYER)
	update_worker_counts()

func assign_neutral_worker_to_building(building_index: int):
	if building_index < 0 or building_index >= buildings.size():
		return
	if get_available_neutral_workers() <= 0:
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return
	if building.assigned_workers > 0:
		return

	building.assign_neutral_worker()
	update_worker_counts()

func unassign_building_worker(building_index: int, player_override: bool = true):
	if building_index < 0 or building_index >= buildings.size():
		return

	var building: Building = buildings[building_index]
	if building.is_house():
		return

	building.unassign_worker(player_override)
	update_worker_counts()
	if not player_override:
		auto_assign_workers()

func toggle_building_maintenance(building_index: int):
	if building_index < 0 or building_index >= buildings.size():
		return

	var building: Building = buildings[building_index]
	building.toggle_maintenance()

func get_available_need_bucket_amount(bucket_id: String) -> int:
	var available_amount: int = 0
	for good_id in GoodsNeedBucketHelperScript.get_current_goods_for_need_bucket(bucket_id):
		if resources.has(good_id):
			available_amount += max(0, int(resources[good_id]))

	return available_amount

func consume_need_bucket(bucket_id: String, amount: int) -> int:
	if amount <= 0:
		return 0

	var remaining_amount: int = amount
	var consumed_amount: int = 0
	for good_id in GoodsNeedBucketHelperScript.get_current_goods_for_need_bucket(bucket_id):
		if remaining_amount <= 0:
			break
		if not resources.has(good_id):
			continue

		var available_good_amount: int = max(0, int(resources[good_id]))
		if available_good_amount <= 0:
			continue

		var consumed_good_amount: int = min(remaining_amount, available_good_amount)
		resources[good_id] = available_good_amount - consumed_good_amount
		remaining_amount -= consumed_good_amount
		consumed_amount += consumed_good_amount

	return consumed_amount

func resolve_soft_needs() -> Dictionary:
	var results: Dictionary = {}
	results[GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS] = resolve_soft_need_bucket(
		GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS,
		get_household_goods_need_demand()
	)
	results[GoodsNeedBucketHelperScript.BUCKET_CLOTHING] = resolve_soft_need_bucket(
		GoodsNeedBucketHelperScript.BUCKET_CLOTHING,
		get_clothing_need_demand()
	)
	soft_need_results = results
	return results

func resolve_soft_need_bucket(bucket_id: String, demand: int) -> Dictionary:
	var safe_demand: int = max(0, demand)
	var available_before: int = get_available_need_bucket_amount(bucket_id)
	var current_goods: Array[String] = GoodsNeedBucketHelperScript.get_current_goods_for_need_bucket(bucket_id)

	if safe_demand <= 0:
		return make_soft_need_result(bucket_id, "none", "neutral", safe_demand, available_before, available_before, 0)
	if current_goods.is_empty():
		return make_soft_need_result(bucket_id, "unavailable", "neutral", safe_demand, available_before, available_before, 0)

	var consumed_amount: int = consume_need_bucket(bucket_id, safe_demand)
	var remaining_amount: int = get_available_need_bucket_amount(bucket_id)
	var status: String = "unmet"
	var severity: String = "warning"
	if consumed_amount >= safe_demand:
		status = "met"
		severity = "positive"
	elif consumed_amount > 0:
		status = "low"

	return make_soft_need_result(bucket_id, status, severity, safe_demand, available_before, remaining_amount, consumed_amount)

func make_soft_need_result(bucket_id: String, status: String, severity: String, demand: int, available: int, remaining: int, consumed: int) -> Dictionary:
	var shortage_amount: int = max(0, demand - consumed)
	var result: Dictionary = make_need_pressure(bucket_id, status, severity, demand, available, shortage_amount, true)
	result["remaining"] = max(0, remaining)
	result["consumed_last_period"] = max(0, consumed)
	result["satisfaction_ratio"] = get_satisfaction_ratio(consumed, demand)
	return result

func get_satisfaction_ratio(consumed: int, demand: int) -> float:
	if demand <= 0:
		return 0.0

	return clamp(float(max(0, consumed)) / float(demand), 0.0, 1.0)

func consume_food():
	update_shelter_counts()
	var population: int = get_total_population()
	var consumption_rate: int = get_food_consumption_for_population(population)
	resources["food_consumption_rate"] = consumption_rate

	var consumed_food: int = consume_need_bucket(GoodsNeedBucketHelperScript.BUCKET_FOOD, consumption_rate)
	if consumed_food >= consumption_rate:
		resources["food_shortage"] = false
	else:
		resources["food_shortage"] = true

func should_skip_for_food_shortage() -> bool:
	if resources["food_shortage"] != true:
		return false

	# Hungry families lose about a quarter of their working days.
	return int(resources["production_tick_count"]) % FOOD_SHORTAGE_SKIP_TICK_INTERVAL == 0

func apply_building_production(building: Building):
	if should_skip_for_food_shortage():
		return

	var building_type: String = building.type
	var output_amount: int = get_current_building_output_amount(building)
	if output_amount <= 0:
		return

	# Tier 0 buildings produce the same goods as their tier 1 counterpart, at a lower rate.
	var chain: Dictionary = EconomyBalanceScript.PRODUCTION.get(BuildingTiersScript.get_base_type(building_type), {})
	if chain.is_empty():
		return
	apply_input_output_production(str(chain["output"]), output_amount, chain["inputs"])

func apply_input_output_production(output_key: String, output_amount: int, input_costs: Dictionary):
	var capped_output: int = output_amount
	for input_key: String in input_costs.keys():
		var input_cost: int = int(input_costs[input_key])
		if input_cost <= 0:
			continue
		capped_output = min(capped_output, int(floor(float(int(resources[input_key])) / float(input_cost))))

	if capped_output <= 0:
		return

	for input_key: String in input_costs.keys():
		var input_cost: int = int(input_costs[input_key])
		if input_cost > 0:
			resources[input_key] = int(resources[input_key]) - capped_output * input_cost

	resources[output_key] = int(resources[output_key]) + capped_output

func get_current_building_output_amount(building: Building) -> int:
	var maintenance_level: int = building.maintenance_level
	var tick_count: int = int(resources["production_tick_count"])
	var base_output: float = get_base_building_output_amount(building.type)

	# The building stays; only the method falls back, and returns when tools do.
	if building.is_working_by_hand():
		return apply_building_output_modifiers(base_output * EconomyBalanceScript.TIER0_OUTPUT_FRACTION, tick_count, building)
	if maintenance_level <= 0:
		return 0
	if maintenance_level >= 100:
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 75:
		if tick_count % 4 == 0:
			return 0
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 50:
		if tick_count % 2 == 1:
			return 0
		return apply_building_output_modifiers(base_output, tick_count, building)
	if maintenance_level >= 25:
		if tick_count % 4 == 0:
			return apply_building_output_modifiers(base_output, tick_count, building)
		return 0

	return 0

func get_base_building_output_amount(building_type: String) -> float:
	if BuildingTiersScript.is_tier0(building_type):
		return get_base_building_output_amount(BuildingTiersScript.get_base_type(building_type)) * EconomyBalanceScript.TIER0_OUTPUT_FRACTION
	if building_type == BUILDING_FARM:
		return EconomyBalanceScript.FARM_FOOD_PER_DAY
	if building_type == BUILDING_WOODCUTTER:
		return EconomyBalanceScript.WOODCUTTER_WOOD_PER_DAY
	if building_type == Building.BUILDING_FISHER:
		return EconomyBalanceScript.FISHER_FOOD_PER_DAY
	if building_type == Building.BUILDING_HUNTER:
		return EconomyBalanceScript.HUNTER_FOOD_PER_DAY
	if building_type == Building.BUILDING_HERDER:
		return EconomyBalanceScript.HERDER_WOOL_PER_DAY
	if building_type == BUILDING_TOOLMAKER:
		return EconomyBalanceScript.TOOLMAKER_TOOLS_PER_DAY
	if building_type in [BUILDING_QUARRY, BUILDING_STONECUTTER, BUILDING_BRICKWORKS, BUILDING_LIME_KILN, BUILDING_MORTAR_YARD, BUILDING_MASON_YARD, BUILDING_SCULPTOR, BUILDING_CARVER, BUILDING_TILEWORKS, BUILDING_PAVER_YARD]:
		return EconomyBalanceScript.EXPANDED_GOODS_PER_DAY

	return 0.0

func apply_building_output_modifiers(base_output: float, tick_count: int, building: Building) -> int:
	var family_output: float = base_output * get_family_labor_factor(get_household_by_id(building.assigned_household_id)) * get_work_time_factor(building)
	# A field people walk through loses some of its harvest underfoot; the land and season decide
	# the rest (TownLand).
	family_output *= 1.0 - logistics.get_field_trample_loss(building)
	family_output *= land.get_output_factor(building)
	# A family called up to the militia leaves its work until the band is dealt with.
	if defense.is_called_up(building.assigned_household_id):
		family_output = 0.0
	var output_amount: int = apply_output_percent(family_output, building, get_worker_output_percent(building))
	return apply_older_child_support_output_modifier(output_amount, tick_count, building)

# Share of a family's day left for its holding after travel (hauling goods to and from the
# nearest store, walking from home) and any spare time it gave a building site today.
func get_work_time_factor(building: Building) -> float:
	var spare: float = float(construction.spare_time_today.get(building.assigned_household_id, 0.0)) if building.assigned_household_id >= 0 else 0.0
	return maxf(0.0, 1.0 - logistics.get_travel_share(building) - spare)

# Balance outputs assume a two-adult family; a family with one working adult works at half.
# Workplaces without a household (starter neutral workers) work at full rate.
func get_family_labor_factor(household: Household) -> float:
	if household == null:
		return 1.0
	return clampf(float(household.working_adults) / EconomyBalanceScript.FULL_FAMILY_WORKING_ADULTS, 0.0, 1.0)

# Values decide the percent; families without values (legacy) use the old preference match.
func get_worker_output_percent(building: Building) -> int:
	var household: Household = null
	if building.assigned_household_id >= 0:
		household = get_household_by_id(building.assigned_household_id)
	if household != null and household.has_values():
		var context: Dictionary = {
			"food_shortage": bool(resources.get("food_shortage", false)),
			"same_type_operating_others": max(0, int(operating_building_counts.get(building.type, 0)) - 1)
		}
		return CultureEffectsScript.get_work_output_percent(household.values, building.type, context)

	var assigned_preference: String = get_household_preference_for_worker_modifier(building)
	if assigned_preference == WORK_PREF_NEUTRAL:
		return 0
	if assigned_preference == get_preferred_worker_for_building(building.type):
		return CultureEffectsScript.CALLING_MATCH_PERCENT
	return CultureEffectsScript.CALLING_POOR_MATCH_PERCENT

# Output is fractional (balance numbers and percent modifiers); the remainder carries over on
# the building so small daily outputs still average out to the intended rate.
func apply_output_percent(base_output: float, building: Building, percent: int) -> int:
	if base_output <= 0.0:
		return 0
	var exact_output: float = base_output * float(100 + percent) / 100.0 + building.output_carry
	var whole_output: int = int(floor(exact_output))
	building.output_carry = exact_output - float(whole_output)
	return max(0, whole_output)

func refresh_operating_building_counts():
	operating_building_counts.clear()
	for building: Building in buildings:
		if building.can_produce():
			operating_building_counts[building.type] = int(operating_building_counts.get(building.type, 0)) + 1

func apply_older_child_support_output_modifier(output_amount: int, tick_count: int, building: Building) -> int:
	if output_amount <= 0:
		return output_amount
	if building.assigned_household_id < 0:
		return output_amount
	if tick_count % OLDER_CHILD_SUPPORT_TICK_INTERVAL != 0:
		return output_amount

	var household: Household = get_household_by_id(building.assigned_household_id)
	if household == null:
		return output_amount

	return output_amount + household.get_older_child_support_bonus()

func get_preferred_worker_for_building(building_type: String) -> String:
	building_type = BuildingTiersScript.get_base_type(building_type)
	if building_type == BUILDING_FARM or building_type == Building.BUILDING_FISHER or building_type == Building.BUILDING_HUNTER:
		return WORK_PREF_AGRARIAN
	if building_type == BUILDING_WOODCUTTER or building_type == BUILDING_TOOLMAKER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_QUARRY:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_STONECUTTER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_BRICKWORKS:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_LIME_KILN:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_MORTAR_YARD:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_MASON_YARD:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_SCULPTOR:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_CARVER:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_TILEWORKS:
		return WORK_PREF_INDUSTRIAL
	if building_type == BUILDING_PAVER_YARD:
		return WORK_PREF_INDUSTRIAL

	return WORK_PREF_NEUTRAL

func count_housing_capacity() -> int:
	var capacity: int = 0

	for building: Building in buildings:
		if building.is_house():
			capacity += HOUSE_CAPACITY

	return capacity

func get_total_population() -> int:
	var total_population: int = 0

	for household: Household in households:
		total_population += household.total_population

	return total_population

func get_total_labor_capacity() -> int:
	var capacity: int = 0

	for household: Household in households:
		capacity += household.labor_capacity

	return capacity

func update_shelter_counts():
	assign_households_to_housing()
	var house_shelter_capacity: int = count_housing_capacity()
	var temporary_shelter_capacity: int = int(resources["temporary_shelter_capacity"])
	var total_shelter_capacity: int = house_shelter_capacity + temporary_shelter_capacity
	var total_population: int = get_total_population()
	var housed_population: int = get_population_by_residence(Household.RESIDENCE_HOUSED)
	var temporary_sheltered_population: int = get_population_by_residence(Household.RESIDENCE_TEMPORARY)
	var unsheltered_population: int = get_population_by_residence(Household.RESIDENCE_UNSHELTERED)

	for household: Household in households:
		household.update_labor_capacity()

	resources["house_shelter_capacity"] = house_shelter_capacity
	resources["housing_capacity"] = total_shelter_capacity
	resources["household_count"] = households.size()
	resources["total_population"] = total_population
	resources["total_labor_capacity"] = get_total_labor_capacity()
	resources["housed_population"] = housed_population
	resources["temporary_sheltered_population"] = temporary_sheltered_population
	resources["sheltered_population"] = housed_population + temporary_sheltered_population
	resources["unsheltered_population"] = unsheltered_population

func assign_households_to_housing():
	var open_house_ids: Array[int] = get_empty_house_building_ids()
	if open_house_ids.is_empty():
		return

	var candidates: Array[Household] = get_unhoused_households_by_size()
	for household: Household in candidates:
		if open_house_ids.is_empty():
			return

		var building_id: int = int(open_house_ids.pop_front())
		household.move_to_house(building_id)

# Proper houses are offered before huts, so families move into the better home first.
func get_empty_house_building_ids() -> Array[int]:
	var result: Array[int] = []
	var huts: Array[int] = []

	for building: Building in buildings:
		if not building.is_house():
			continue
		if get_household_for_building_id(building.id) != null:
			continue
		if building.is_tier0():
			huts.append(building.id)
		else:
			result.append(building.id)

	result.append_array(huts)
	return result

# Tier 0 housing: temporary shelter or a hut.
func is_household_in_rough_housing(household: Household) -> bool:
	if household.housing_status == Household.RESIDENCE_TEMPORARY:
		return true
	if household.housing_status != Household.RESIDENCE_HOUSED:
		return false
	var home_id: int = household.residence_building_id
	return home_id >= 0 and home_id < buildings.size() and buildings[home_id].is_tier0()

func get_upgrade_cost(building_index: int) -> Dictionary:
	if building_index < 0 or building_index >= buildings.size():
		return {}
	var upgrade_type: String = BuildingTiersScript.get_upgrade_type(buildings[building_index].type)
	if upgrade_type == "":
		return {}
	return EconomyBalanceScript.get_build_cost(upgrade_type)

func can_upgrade_building(building_index: int) -> bool:
	if building_index < 0 or building_index >= buildings.size():
		return false
	if BuildingTiersScript.get_upgrade_type(buildings[building_index].type) == "":
		return false
	return can_afford_cost(get_upgrade_cost(building_index))

# Upgrades a tier 0 building in place into its tier 1 counterpart at once. The family working or
# living in it stays; the footprint and terrain rules are shared, so no new placement is needed.
# Play goes through TownConstruction.request_upgrade, which takes time, labor, and delivery.
func upgrade_building(building_index: int) -> bool:
	if not can_upgrade_building(building_index):
		return false
	pay_cost(get_upgrade_cost(building_index))
	complete_upgrade(building_index)
	return true

# Turns a tier 0 building into its tier 1 counterpart, already paid for (by upgrade_building, or
# by a finished construction project).
func complete_upgrade(building_index: int) -> void:
	var building: Building = buildings[building_index]
	var upgrade_type: String = BuildingTiersScript.get_upgrade_type(building.type)
	if upgrade_type == "":
		return
	building.type = upgrade_type
	building.maintenance_level = 100
	building.maintenance_timer = 0
	building.upkeep_grace_days = EconomyBalanceScript.MAINTENANCE_GRACE_DAYS
	update_shelter_counts()
	update_worker_counts()

func get_unhoused_households_by_size() -> Array[Household]:
	var result: Array[Household] = []

	for household: Household in households:
		if household.housing_status == Household.RESIDENCE_TEMPORARY or household.housing_status == Household.RESIDENCE_UNSHELTERED:
			result.append(household)

	sort_households_by_population_desc(result)
	return result

func sort_households_by_population_desc(household_list: Array[Household]):
	for outer_index in range(household_list.size()):
		for inner_index in range(outer_index + 1, household_list.size()):
			var outer_household: Household = household_list[outer_index]
			var inner_household: Household = household_list[inner_index]
			if inner_household.total_population > outer_household.total_population:
				household_list[outer_index] = inner_household
				household_list[inner_index] = outer_household

func get_population_by_residence(residence_status: String) -> int:
	var population: int = 0

	for household: Household in households:
		if household.housing_status == residence_status:
			population += household.total_population

	return population

# Ids must stay unique after families leave or pass on, so they never reuse households.size().
func get_next_household_id() -> int:
	var next_id: int = 0
	for household: Household in households:
		next_id = max(next_id, household.id + 1)
	return next_id

func get_food_consumption_for_population(population: int) -> int:
	return int(ceil(float(population) / float(FOOD_PER_POPULATION_DIVISOR)))

func auto_assign_workers():
	update_worker_counts()

	for building_index in range(buildings.size()):
		var building: Building = buildings[building_index]
		if not building.is_production_building():
			continue
		if building.assigned_workers > 0:
			continue
		if building.auto_assignment_blocked:
			continue

		var household: Household = find_auto_assignment_household(building)
		if household == null:
			continue

		building.assign_household(household, Building.ASSIGNMENT_AUTO)
		update_worker_counts()

func find_auto_assignment_household(building: Building) -> Household:
	var best_household: Household = null
	var best_score: int = -9999

	for household: Household in get_available_households():
		var available_workers: int = household.get_available_workers()
		if available_workers <= 0:
			continue
		# A family building a workplace of its own is not free for other vacancies.
		if construction.is_promised_to_workplace(household.id):
			continue

		var score: int = get_auto_assignment_score(household, building)
		if best_household == null or score > best_score:
			best_household = household
			best_score = score

	return best_household

func get_auto_assignment_score(household: Household, building: Building) -> int:
	var score: int = 0
	var match_quality: String = household.get_match_quality(building.type)

	if match_quality == "good match":
		score += 30
	elif match_quality == "neutral":
		score += 10
	else:
		score -= 10

	if household.housing_status == Household.RESIDENCE_HOUSED:
		score += 6
	elif household.housing_status == Household.RESIDENCE_TEMPORARY:
		score += 3

	score += household.get_available_workers() * 2
	score -= household.id
	return score

func update_building_maintenance(building: Building):
	var interval: int = building.get_maintenance_interval()
	var cost: int = building.get_maintenance_tool_cost()

	building.maintenance_timer += 1
	if building.maintenance_timer < interval:
		return

	building.maintenance_timer = 0
	if building.receives_maintenance and int(resources["tools"]) >= cost:
		resources["tools"] = int(resources["tools"]) - cost
		building.maintenance_level = min(100, building.maintenance_level + 25)
	else:
		building.maintenance_level = max(0, building.maintenance_level - 25)

func record_resource_history():
	resource_history.append({
		"food": int(resources["food"]),
		"wood": int(resources["wood"]),
		"tools": int(resources["tools"])
	})

	while resource_history.size() > RESOURCE_HISTORY_LIMIT:
		resource_history.pop_front()

func get_resource_trends() -> Dictionary:
	var result: Dictionary = {"food": 0.0, "wood": 0.0, "tools": 0.0}
	if resource_history.size() < 2:
		return result

	var first_sample: Dictionary = resource_history[0] as Dictionary
	var last_sample: Dictionary = resource_history[resource_history.size() - 1] as Dictionary
	var tick_span: float = float(resource_history.size() - 1)

	result["food"] = float(int(last_sample["food"]) - int(first_sample["food"])) / tick_span
	result["wood"] = float(int(last_sample["wood"]) - int(first_sample["wood"])) / tick_span
	result["tools"] = float(int(last_sample["tools"]) - int(first_sample["tools"])) / tick_span
	return result

func get_pressure_summary() -> Dictionary:
	update_shelter_counts()
	update_worker_counts()
	var trends: Dictionary = get_resource_trends()

	return {
		"food": get_food_pressure(float(trends["food"])),
		"shelter": get_shelter_pressure(),
		"labor": get_labor_pressure(),
		"tools": get_tool_pressure(float(trends["tools"])),
		"maintenance": get_maintenance_pressure()
	}

func get_need_pressure_summary() -> Dictionary:
	return {
		GoodsNeedBucketHelperScript.BUCKET_FOOD: get_food_need_pressure(),
		GoodsNeedBucketHelperScript.BUCKET_TOOLS: get_inactive_need_pressure(GoodsNeedBucketHelperScript.BUCKET_TOOLS),
		GoodsNeedBucketHelperScript.BUCKET_CONSTRUCTION_MATERIALS: get_inactive_need_pressure(GoodsNeedBucketHelperScript.BUCKET_CONSTRUCTION_MATERIALS),
		GoodsNeedBucketHelperScript.BUCKET_MAINTENANCE_MATERIALS: get_inactive_need_pressure(GoodsNeedBucketHelperScript.BUCKET_MAINTENANCE_MATERIALS),
		GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS: get_household_goods_need_pressure(),
		GoodsNeedBucketHelperScript.BUCKET_CLOTHING: get_clothing_need_pressure(),
		GoodsNeedBucketHelperScript.BUCKET_CIVIC_GOODS: get_inactive_need_pressure(GoodsNeedBucketHelperScript.BUCKET_CIVIC_GOODS),
	}

func get_food_need_pressure() -> Dictionary:
	var demand: int = max(0, int(resources["food_consumption_rate"]))
	var available: int = get_available_need_bucket_amount(GoodsNeedBucketHelperScript.BUCKET_FOOD)
	var shortage_amount: int = 0
	var status: String = "met"
	var severity: String = "positive"

	if resources["food_shortage"] == true:
		shortage_amount = demand
		status = "shortage"
		severity = "danger"
	elif demand > 0 and available < demand:
		status = "low"
		severity = "warning"

	return make_need_pressure(GoodsNeedBucketHelperScript.BUCKET_FOOD, status, severity, demand, available, shortage_amount, true)

func get_household_goods_need_pressure() -> Dictionary:
	if soft_need_results.has(GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS):
		return (soft_need_results[GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS] as Dictionary).duplicate()

	var demand: int = get_household_goods_need_demand()
	var available: int = get_available_need_bucket_amount(GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS)
	var shortage_amount: int = max(0, demand - available)
	var status: String = "none"
	var severity: String = "neutral"

	if demand > 0 and available >= demand:
		status = "met"
		severity = "positive"
	elif demand > 0 and available > 0:
		status = "low"
		severity = "warning"
	elif demand > 0:
		status = "unmet"
		severity = "warning"

	return make_need_pressure(GoodsNeedBucketHelperScript.BUCKET_HOUSEHOLD_GOODS, status, severity, demand, available, shortage_amount, true)

func get_household_goods_need_demand() -> int:
	var demand: int = 0
	for household: Household in households:
		if household.housing_status == Household.RESIDENCE_HOUSED:
			demand += 1

	return demand

func get_clothing_need_pressure() -> Dictionary:
	if soft_need_results.has(GoodsNeedBucketHelperScript.BUCKET_CLOTHING):
		return (soft_need_results[GoodsNeedBucketHelperScript.BUCKET_CLOTHING] as Dictionary).duplicate()

	var demand: int = get_clothing_need_demand()
	var available: int = get_available_need_bucket_amount(GoodsNeedBucketHelperScript.BUCKET_CLOTHING)
	var shortage_amount: int = max(0, demand - available)
	var status: String = "none"
	var severity: String = "neutral"
	var current_clothing_goods: Array[String] = GoodsNeedBucketHelperScript.get_current_goods_for_need_bucket(GoodsNeedBucketHelperScript.BUCKET_CLOTHING)

	if demand > 0 and current_clothing_goods.is_empty():
		status = "unavailable"
	elif demand > 0 and available >= demand:
		status = "met"
		severity = "positive"
	elif demand > 0 and available > 0:
		status = "low"
		severity = "warning"
	elif demand > 0:
		status = "unmet"
		severity = "warning"

	return make_need_pressure(GoodsNeedBucketHelperScript.BUCKET_CLOTHING, status, severity, demand, available, shortage_amount, true)

# A garment lasts a person CLOTHING_DAYS_PER_PERSON, so the town needs one a day for every that
# many people (at least one while anyone lives here).
func get_clothing_need_demand() -> int:
	var people: int = 0
	for household: Household in households:
		people += max(0, household.total_population)
	if people <= 0:
		return 0
	return maxi(1, ceili(float(people) / EconomyBalanceScript.CLOTHING_DAYS_PER_PERSON))

func get_inactive_need_pressure(bucket_id: String) -> Dictionary:
	return make_need_pressure(bucket_id, "pressure_only", "neutral", 0, get_available_need_bucket_amount(bucket_id), 0, false)

func make_need_pressure(bucket_id: String, status: String, severity: String, demand: int, available: int, shortage: int, active: bool) -> Dictionary:
	return {
		"bucket": bucket_id,
		"display_name": GoodsNeedBucketHelperScript.get_bucket_display_name(bucket_id),
		"status": status,
		"severity": severity,
		"demand": demand,
		"available": available,
		"remaining": available,
		"shortage": shortage,
		"active": active,
		"consumed_last_period": 0,
		"satisfaction_ratio": 0.0,
	}

func make_pressure(status: String, severity: String, detail: String = "", values: Dictionary = {}) -> Dictionary:
	return {
		"status": status,
		"severity": severity,
		"detail": detail,
		"values": values
	}

func get_food_pressure(food_trend: float) -> Dictionary:
	var food: int = int(resources["food"])
	var consumption_rate: int = max(1, int(resources["food_consumption_rate"]))
	var days_of_food: float = float(food) / float(consumption_rate)
	var detail: String = get_food_pressure_detail(food, days_of_food, food_trend)
	var values: Dictionary = {
		"food": food,
		"consumption_rate": consumption_rate,
		"days_stored": days_of_food,
		"trend": food_trend
	}

	if resources["food_shortage"] == true or food <= 0:
		return make_pressure("Shortage", "danger", "Food empty; shortage penalty active", values)
	if food_trend < -0.25 and days_of_food < 8.0:
		return make_pressure("Declining", "warning", detail, values)
	if food_trend > 0.25 and days_of_food >= 4.0:
		return make_pressure("Surplus", "positive", detail, values)
	if days_of_food < 4.0:
		return make_pressure("Declining", "warning", detail, values)

	return make_pressure("Stable", "neutral", detail, values)

func get_shelter_pressure() -> Dictionary:
	var unsheltered_population: int = int(resources["unsheltered_population"])
	var temporary_population: int = int(resources["temporary_sheltered_population"])
	var housed_population: int = int(resources["housed_population"])
	var detail: String = str(housed_population) + " housed, " + str(temporary_population) + " temporary, " + str(unsheltered_population) + " unsheltered"
	var values: Dictionary = {
		"housed": housed_population,
		"temporary": temporary_population,
		"unsheltered": unsheltered_population
	}

	if unsheltered_population > 0:
		return make_pressure("Housing Shortage", "danger", str(unsheltered_population) + " people unsheltered", values)
	if temporary_population > 0:
		return make_pressure("Temporary Shelter", "warning", detail, values)

	return make_pressure("Stable", "positive", detail, values)

func get_labor_pressure() -> Dictionary:
	var total_labor_capacity: int = int(resources["total_labor_capacity"])
	var assigned_workers: int = int(resources["assigned_workers"])
	var idle_workers: int = int(resources["idle_workers"])
	var unassigned_jobs: int = count_unassigned_production_buildings()
	var production_buildings: int = get_production_building_count()
	# Families without a holding build (TownConstruction); only those not on a site are idle.
	var building_families: int = mini(idle_workers, construction.builders_today.size())
	var detail: String = str(assigned_workers) + "/" + str(total_labor_capacity) + " labor assigned, " + str(idle_workers - building_families) + " idle"
	if building_families > 0:
		detail += ", " + str(building_families) + " building"
	var values: Dictionary = {
		"assigned": assigned_workers,
		"capacity": total_labor_capacity,
		"idle": idle_workers,
		"unassigned_jobs": unassigned_jobs,
		"production_buildings": production_buildings
	}

	if total_labor_capacity <= 0 and production_buildings > 0:
		return make_pressure("Labor Shortage", "danger", str(production_buildings) + " workplaces, no labor available", values)
	if unassigned_jobs > 0 and idle_workers <= 0:
		return make_pressure("Overextended", "danger", str(unassigned_jobs) + " production buildings unstaffed", values)
	if unassigned_jobs > 0:
		return make_pressure("Labor Shortage", "warning", str(unassigned_jobs) + " production buildings unstaffed", values)
	if idle_workers - building_families >= 2:
		return make_pressure("Idle Labor", "neutral", detail, values)
	if assigned_workers >= total_labor_capacity and total_labor_capacity > 0:
		return make_pressure("Balanced", "positive", detail, values)

	return make_pressure("Balanced", "neutral", detail, values)

func get_tool_pressure(tool_trend: float) -> Dictionary:
	var tools: int = int(resources["tools"])
	var maintenance_demand: int = get_maintenance_tool_demand_estimate()
	var critical_buildings: int = count_buildings_below_maintenance(50)
	var detail: String = str(tools) + " tools stored, upkeep demand " + str(maintenance_demand)
	var values: Dictionary = {
		"tools": tools,
		"trend": tool_trend,
		"maintenance_demand": maintenance_demand,
		"critical_buildings": critical_buildings
	}

	if tools <= 0 or critical_buildings > 0:
		return make_pressure("Upkeep Risk", "danger", "Tools empty or buildings degrading", values)
	if tools < max(3, maintenance_demand) or tool_trend < -0.25:
		return make_pressure("Low Tools", "warning", detail + ", trend " + format_signed_decimal(tool_trend) + "/day", values)

	return make_pressure("Stable", "positive", detail + ", trend " + format_signed_decimal(tool_trend) + "/day", values)

func get_maintenance_pressure() -> Dictionary:
	var disabled_count: int = count_disabled_maintenance_buildings()
	var critical_count: int = count_buildings_below_maintenance(50)
	var worn_count: int = count_buildings_below_maintenance(100)
	var values: Dictionary = {
		"disabled": disabled_count,
		"critical": critical_count,
		"worn": worn_count
	}

	if critical_count > 0:
		return make_pressure("Critical", "danger", str(critical_count) + " buildings below 50%", values)
	if worn_count > 0 or disabled_count > 0:
		return make_pressure("Worn", "warning", str(worn_count) + " below full, " + str(disabled_count) + " disabled", values)

	return make_pressure("Good", "positive", "All production buildings maintained", values)

func get_food_pressure_detail(food: int, days_of_food: float, food_trend: float) -> String:
	return str(food) + " food, " + format_decimal(days_of_food) + " days stored, trend " + format_signed_decimal(food_trend) + "/day"

func format_decimal(value: float) -> String:
	return str(snapped(value, 0.1))

func format_signed_decimal(value: float) -> String:
	var rounded_value: float = snapped(value, 0.1)
	if rounded_value > 0.0:
		return "+" + str(rounded_value)

	return str(rounded_value)

func get_production_building_count() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building():
			count += 1

	return count

func count_unassigned_production_buildings() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.assigned_workers <= 0:
			count += 1

	return count

func count_disabled_maintenance_buildings() -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and not building.receives_maintenance:
			count += 1

	return count

func count_buildings_below_maintenance(threshold: int) -> int:
	var count: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.maintenance_level < threshold:
			count += 1

	return count

func get_maintenance_tool_demand_estimate() -> int:
	var demand: int = 0
	for building: Building in buildings:
		if building.is_production_building() and building.receives_maintenance:
			demand += building.get_maintenance_tool_cost()

	return demand

func can_transfer(resource_name: String, amount: int) -> bool:
	return int(resources[resource_name]) >= amount

func remove_resource(resource_name: String, amount: int):
	resources[resource_name] = int(resources[resource_name]) - amount

func add_resource(resource_name: String, amount: int):
	resources[resource_name] = int(resources[resource_name]) + amount

func can_afford_cost(cost: Dictionary) -> bool:
	for resource_name: String in cost.keys():
		if int(resources[resource_name]) < int(cost[resource_name]):
			return false

	return true

func pay_cost(cost: Dictionary):
	for resource_name: String in cost.keys():
		remove_resource(resource_name, int(cost[resource_name]))
