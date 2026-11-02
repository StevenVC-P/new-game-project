class_name HouseholdEconomy
extends RefCounted

# Household self-sufficiency and occupational skills (docs/HOUSEHOLD_SELF_SUFFICIENCY.md). Where
# families lead (TownInfluence.enabled):
#
# - A family's working day is one: travel, spare time for building, and any secondary work all
#   come out of it, and its holding gets what is left (City.get_work_time_factor). Once a month a
#   family chooses whether to give 10-30% of its day to a garden, gathering wood, or mending its own
#   workplace's tools, at hand work's rate (a third of proper work), for its own reasons.
# - Its harvest goes into its own larder. Above the larder's target it eats its own first, sparing
#   the common store; below it, it eats from the common store and keeps its harvest; the larder is
#   drawn on only when the common store falls short. A larder fills only from the family's own
#   harvest or a gift, so no food is made or eaten twice. Whether a family went short is its own.
# - Proficiency grows with time actually spent on work, decays slowly when unused (to nothing in
#   the end), carries a little to related work, and passes partly to children. A novice produces
#   less than an established family; established families produce what they always did.

# --- Proficiency (prototype values, owner 2026-11-01) ---
const LEARN_DAYS: float = 360.0
const DECAY_DAYS: float = 1440.0
const TRANSFER_SHARE: float = 0.25
# Founders and newcomers start here in the trades they already know; output is full from here.
const ESTABLISHED: float = 0.7
const NOVICE_OUTPUT: float = 0.6
const INHERITED_SHARE: float = 0.6
const FORGOTTEN_BELOW: float = 0.02
# Work that teaches something of another (both ways where listed both ways).
const RELATED: Dictionary = {
	"farm": ["herder"],
	"herder": ["farm"],
	"fisher": ["hunter"],
	"hunter": ["fisher", "woodcutter"],
	"woodcutter": ["toolmaker", "hunter"],
	"toolmaker": ["woodcutter", "carver"],
	"carver": ["toolmaker"],
	"quarry": ["stonecutter"],
	"stonecutter": ["quarry", "mason_yard"],
	"mason_yard": ["stonecutter"],
	"brickworks": ["tileworks"],
	"tileworks": ["brickworks"],
}
# Work a family can know (watch posts are not a trade).
const TRADES: Array[String] = ["farm", "woodcutter", "toolmaker", "fisher", "hunter", "herder", "quarry", "stonecutter", "brickworks", "lime_kiln", "mortar_yard", "mason_yard", "sculptor", "carver", "tileworks", "paver_yard"]

# --- Secondary work ---
const SECONDARY_STEPS: Array[float] = [0.0, 0.1, 0.2, 0.3]
# The trade each activity practises, and whose hand-work rate it works at.
const SECONDARY_WORK: Dictionary = {"food": "farm", "wood": "woodcutter", "tools": "toolmaker"}
const SECONDARY_NAMES: Dictionary = {"food": "a garden", "wood": "gathering wood", "tools": "mending its tools"}
# A garden takes free ground within reach of home: fertile land in full, plain ground at half.
const GARDEN_REACH: int = 3
const GARDEN_TILES: int = 2
const PLAIN_GROUND_YIELD: float = 0.5
# Gathering wood takes woods within reach of home; fewer trees, less wood.
const WOODS_REACH: int = 4
const WOODS_FULL_TILES: int = 6
# Mending put by beyond this is wasted.
const MENDING_MAX: float = 2.0
# Score at which a family wants each step of secondary work (10%, 20%, 30%).
const STEP_SCORES: Array[float] = [0.0, 1.5, 3.0]
const SECONDARY_COST: float = 1.5
const TOWN_SHORT_WEIGHT: float = 2.5
const OWN_NEED_WEIGHT: float = 1.0
const OWN_PLENTY_WEIGHT: float = 1.0
const KNOWS_WEIGHT: float = 1.0
const OWN_SKILL_WEIGHT: float = 0.5
# In FamilyInitiative.get_work_desire: what a family knows draws it to that work.
const KNOWN_WORK_WEIGHT: float = 2.0

# --- Larder ---
const LARDER_STEPS: Array[int] = [0, 30, 60, 90]
const LARDER_STEP_SCORES: Array[float] = [0.5, 1.5, 2.5]
# A gift in a shortage: this many days of the recipient's food from the donor's larder.
const GIFT_DAYS: float = 10.0

static func is_on(city: City) -> bool:
	return city.influence.enabled and city.influence.self_sufficiency

# --- Proficiency ------------------------------------------------------------------------------

static func get_level(household: Household, building_type: String) -> float:
	return float(household.proficiency.get(BuildingTiers.get_base_type(building_type), 0.0))

# Output of a family's work for its proficiency: full from ESTABLISHED, NOVICE_OUTPUT with none.
static func get_output_factor(city: City, household: Household, building_type: String) -> float:
	if household == null or not is_on(city) or city.has_meta("economy_no_proficiency_effects"):
		return 1.0
	return NOVICE_OUTPUT + (1.0 - NOVICE_OUTPUT) * minf(1.0, get_level(household, building_type) / ESTABLISHED)

static func describe_level(level: float) -> String:
	if level >= 0.9:
		return "master"
	if level >= ESTABLISHED:
		return "established"
	if level >= 0.35:
		return "practised"
	return "learning"

# Work a family knows on arrival: what its calling and its trade are.
static func get_known_trades(household: Household) -> Array[String]:
	var known: Array[String] = []
	for trade: String in TRADES:
		if household.get_match_quality(trade) == CultureEffects.MATCH_GOOD:
			known.append(trade)
	return known

# A family's starting knowledge: what its parents still know, in part; else the trades it knows.
static func ensure_seeded(city: City, household: Household) -> void:
	if household.proficiency_seeded:
		return
	household.proficiency_seeded = true
	var parents: Array[Household] = []
	for parent_id: int in [household.parent_household_id, household.second_parent_household_id]:
		var parent: Household = city.get_household_by_id(parent_id) if parent_id >= 0 else null
		if parent != null and parent != household:
			parents.append(parent)
	if not parents.is_empty():
		for parent: Household in parents:
			ensure_seeded(city, parent)
			for trade: String in parent.proficiency.keys():
				var inherited: float = float(parent.proficiency[trade]) * INHERITED_SHARE
				if inherited >= FORGOTTEN_BELOW:
					household.proficiency[trade] = maxf(float(household.proficiency.get(trade, 0.0)), inherited)
		return
	for trade: String in get_known_trades(household):
		household.proficiency[trade] = ESTABLISHED

# A day's practice: {trade: share of the day}. Practice teaches the trade and a little of related
# ones; a trade not practised at all fades.
static func learn(household: Household, practice: Dictionary) -> void:
	var gained: Dictionary = {}
	for trade: String in practice.keys():
		var share: float = float(practice[trade])
		if share <= 0.0:
			continue
		gained[trade] = float(gained.get(trade, 0.0)) + share
		for related: String in RELATED.get(trade, []):
			gained[related] = float(gained.get(related, 0.0)) + share * TRANSFER_SHARE
	for trade: String in gained.keys():
		var level: float = float(household.proficiency.get(trade, 0.0))
		household.proficiency[trade] = minf(1.0, level + float(gained[trade]) * (1.0 - level) / LEARN_DAYS)
	for trade: String in household.proficiency.keys():
		if gained.has(trade):
			continue
		var level: float = float(household.proficiency[trade])
		level -= level / DECAY_DAYS
		if level < FORGOTTEN_BELOW:
			household.proficiency.erase(trade)
		else:
			household.proficiency[trade] = level

# --- The day ----------------------------------------------------------------------------------

# Before the day's work (City.tick): how much of each family's day goes to secondary work. It gets
# at most what is left after travel and building; the holding gets the rest.
static func plan_day(city: City) -> void:
	city.influence._secondary_today.clear()
	if not is_on(city):
		return
	if city.influence.economy_started_day < 0:
		start(city)
	for household: Household in city.households:
		ensure_seeded(city, household)
		if household.secondary_share <= 0.0 or household.secondary_activity == "":
			continue
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding == null or not holding.can_produce() or city.skips_work_today(household.id) or city.defense.is_called_up(household.id):
			continue
		var spare: float = float(city.construction.spare_time_today.get(household.id, 0.0))
		var free: float = 1.0 - city.logistics.get_travel_share(holding) - spare
		var share: float = clampf(minf(household.secondary_share, free), 0.0, 1.0)
		if share > 0.0:
			city.influence._secondary_today[household.id] = share

# The first day the system runs in a town. A town that was already going (an older save, or the
# system switched on mid-game) has families that know the work they have been doing.
static func start(city: City) -> void:
	city.influence.economy_started_day = city.construction.day
	if city.construction.day <= 1:
		return
	for household: Household in city.households:
		ensure_seeded(city, household)
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null:
			var trade: String = BuildingTiers.get_base_type(holding.type)
			household.proficiency[trade] = maxf(get_level(household, trade), ESTABLISHED)

# After the day's work: secondary output, and what each family learned or forgot.
static func work_day(city: City) -> void:
	if not is_on(city):
		return
	var influence: TownInfluence = city.influence
	for household: Household in city.households:
		var practice: Dictionary = {}
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null and holding.can_produce() and not city.skips_work_today(household.id) and not city.defense.is_called_up(household.id):
			var primary: float = city.get_work_time_factor(holding)
			practice[BuildingTiers.get_base_type(holding.type)] = primary
			influence.primary_share_days += primary
		var share: float = float(influence._secondary_today.get(household.id, 0.0))
		if share > 0.0:
			var activity: String = household.secondary_activity
			var trade: String = str(SECONDARY_WORK[activity])
			practice[trade] = float(practice.get(trade, 0.0)) + share
			influence.secondary_share_days[activity] = float(influence.secondary_share_days.get(activity, 0.0)) + share
			produce_secondary(city, household, activity, share)
			# What its holding would have made in that time, before land and season: the cost.
			var output: String = str((EconomyBalance.PRODUCTION.get(BuildingTiers.get_base_type(holding.type), {}) as Dictionary).get("output", ""))
			if output != "":
				var lost: float = city.get_base_building_output_amount(holding.type) * city.get_family_labor_factor(household) * get_output_factor(city, household, holding.type) * share
				influence.lost_primary_output[output] = float(influence.lost_primary_output.get(output, 0.0)) + lost
		learn(household, practice)

static func produce_secondary(city: City, household: Household, activity: String, share: float) -> void:
	var trade: String = str(SECONDARY_WORK[activity])
	var rate: float = city.get_base_building_output_amount(trade) * EconomyBalance.TIER0_OUTPUT_FRACTION
	var amount: float = share * rate * city.get_family_labor_factor(household) * get_output_factor(city, household, trade)
	var influence: TownInfluence = city.influence
	match activity:
		"food":
			amount *= EconomyBalance.FARM_SEASON_YIELD[city.get_season_index()] * household.garden_land
			household.larder += amount
		"wood":
			amount *= household.woods_land
			household.gathered_wood += amount
			while household.gathered_wood >= 1.0:
				household.gathered_wood -= 1.0
				deliver_wood(city, household)
		"tools":
			household.mending = minf(MENDING_MAX, household.mending + amount)
	influence.secondary_output[activity] = float(influence.secondary_output.get(activity, 0.0)) + amount

# Wood a family gathered goes to its own building first, carried straight to the site; else to the
# common store.
static func deliver_wood(city: City, household: Household) -> void:
	for project: ConstructionProject in city.construction.projects:
		if project.claimant_household_id != household.id and project.requester_household_id != household.id:
			continue
		if int(project.get_remaining_materials().get("wood", 0)) > 0:
			project.materials_delivered["wood"] = int(project.materials_delivered.get("wood", 0)) + 1
			city.influence.wood_to_own_projects += 1
			return
	city.add_resource("wood", 1, "gathered")

# When its workplace's upkeep falls due, a unit of mending the family did itself takes the place
# of a tool from the store (City.update_building_maintenance).
static func mend(city: City, building: Building) -> bool:
	if not is_on(city) or building.assigned_household_id < 0:
		return false
	var household: Household = city.get_household_by_id(building.assigned_household_id)
	if household == null or household.mending < 1.0:
		return false
	household.mending -= 1.0
	city.influence.mended_upkeep += 1
	return true

# --- Eating -----------------------------------------------------------------------------------

static func get_daily_need(household: Household) -> float:
	return float(household.total_population) / float(EconomyBalance.PEOPLE_FED_PER_FOOD)

static func get_larder_target(household: Household) -> float:
	return float(household.larder_target_days) * get_daily_need(household)

static func get_larder_days(household: Household) -> float:
	return household.larder / maxf(0.5, get_daily_need(household))

# The day's eating (City.consume_food). `rate` is the town's demand as it has always been counted;
# what families eat of their own comes off it, so total eating is unchanged. Each family eats its
# own above its larder's target, then from the common store, then, only if the store falls short,
# from its larder. A family whose food was not all met is short today.
static func feed(city: City, rate: int) -> void:
	var own_total: float = 0.0
	var from_store: Dictionary = {}
	for household: Household in city.households:
		household.short_today = false
		var need: float = get_daily_need(household)
		var own: float = minf(need, maxf(0.0, household.larder - get_larder_target(household)))
		household.larder -= own
		own_total += own
		from_store[household.id] = need - own
	city.influence.larder_eaten_own += own_total
	var demand: int = maxi(0, int(ceil(float(rate) - own_total - 0.000001)))
	var consumed: int = city.consume_need_bucket(GoodsNeedBucketHelper.BUCKET_FOOD, demand)
	city.resources["food_shortage"] = consumed < demand
	if consumed >= demand:
		return
	var fed: float = float(consumed) / float(demand)
	for household: Household in city.households:
		var unmet: float = float(from_store[household.id]) * (1.0 - fed)
		var reserve: float = minf(unmet, household.larder)
		household.larder -= reserve
		unmet -= reserve
		city.influence.larder_eaten_short += reserve
		if unmet > 0.001:
			household.short_today = true
			household.short_days_this_month += 1
			city.influence.household_short_days += 1

# --- The month --------------------------------------------------------------------------------

# Monthly (HouseholdMigration.advance_month, after the occupation review): each family weighs its
# time and its larder. Families claim garden ground in turn, so no two garden the same tile.
static func advance_month(city: City) -> void:
	if not is_on(city):
		return
	var claimed: Dictionary = {}
	var ordered: Array[Household] = city.households.duplicate()
	ordered.sort_custom(func(a: Household, b: Household) -> bool: return a.id < b.id)
	for household: Household in ordered:
		ensure_seeded(city, household)
		decide_time(city, household, claimed)
		decide_larder(city, household)

# Free ground near home for a garden, as a share of a full garden; claims it when `claim`.
static func get_garden_land(city: City, household: Household, claimed: Dictionary, claim: bool) -> float:
	if not city.logistics.has_map():
		return 1.0
	if household.residence_building_id < 0:
		return 0.0
	var home: Vector2i = city.logistics.get_home_tile(household)
	var fertile: Array[Vector2i] = []
	var plain: Array[Vector2i] = []
	for y in range(home.y - GARDEN_REACH, home.y + GARDEN_REACH + 1):
		for x in range(home.x - GARDEN_REACH, home.x + GARDEN_REACH + 1):
			var at: Vector2i = Vector2i(x, y)
			if not city.construction.is_inside(at) or claimed.has(at):
				continue
			var tile: Dictionary = city.local_map[y][x]
			if tile["type"] != "ground" or tile["has_trees"] == true or tile.get("occupied", false) == true or tile.get("has_road", false) == true:
				continue
			if tile.get("is_fertile", false) == true:
				fertile.append(at)
			else:
				plain.append(at)
	var chosen: Array[Vector2i] = []
	var land: float = 0.0
	for at: Vector2i in fertile + plain:
		if chosen.size() >= GARDEN_TILES:
			break
		chosen.append(at)
		land += 1.0 if fertile.has(at) else PLAIN_GROUND_YIELD
	if claim:
		for at: Vector2i in chosen:
			claimed[at] = household.id
	return land / float(GARDEN_TILES)

static func get_woods_land(city: City, household: Household) -> float:
	if not city.logistics.has_map():
		return 1.0
	if household.residence_building_id < 0:
		return 0.0
	var home: Vector2i = city.logistics.get_home_tile(household)
	return minf(1.0, float(city.land.count_near(home, Vector2i.ONE, WOODS_REACH, "woods")) / float(WOODS_FULL_TILES))

# What its holding makes, so it does not take up the same as secondary work.
static func get_holding_output(holding: Building) -> String:
	return str((EconomyBalance.PRODUCTION.get(BuildingTiers.get_base_type(holding.type), {}) as Dictionary).get("output", ""))

# How much of its day a family gives to which secondary work. It moves a step a month at most, and
# winds one activity down before taking up another.
static func decide_time(city: City, household: Household, claimed: Dictionary) -> void:
	var holding: Building = FamilyInitiative.get_holding(city, household)
	# Comparison only (tests/sim/wisdom_check.gd --no-secondary): no secondary work at all.
	if holding == null or household.labor_capacity <= 0 or city.has_meta("economy_no_secondary"):
		household.secondary_share = 0.0
		household.secondary_activity = ""
		household.garden_land = 0.0
		return
	var best: Dictionary = {}
	var best_activity: String = ""
	var best_score: float = -INF
	for activity: String in SECONDARY_WORK.keys():
		var desire: Dictionary = get_secondary_desire(city, household, holding, activity, claimed)
		if not bool(desire["possible"]):
			continue
		var score: float = float(desire["score"]) + FamilyInitiative.get_noise(city, household, "secondary_" + activity)
		if score > best_score:
			best_score = score
			best = desire
			best_activity = activity
	var step: int = SECONDARY_STEPS.find(household.secondary_share)
	step = maxi(0, step)
	var wanted: int = 0
	if best_activity != "":
		for i in range(STEP_SCORES.size()):
			if best_score >= STEP_SCORES[i]:
				wanted = i + 1
	var before: int = step
	if step > 0 and household.secondary_activity != best_activity:
		step -= 1
	elif wanted > step and step == 0:
		# Taking it up, a family chooses how much of its day to give, up to what its reasons call
		# for (random among those for now: owner, 2026-11-01).
		step = get_starting_step(city, household, wanted)
		household.secondary_activity = best_activity
	elif wanted > step:
		step += 1
	elif wanted < step:
		step -= 1
	household.secondary_share = SECONDARY_STEPS[step]
	if step == 0:
		household.secondary_activity = ""
	household.garden_land = get_garden_land(city, household, claimed, true) if household.secondary_activity == "food" else 0.0
	household.woods_land = get_woods_land(city, household) if household.secondary_activity == "wood" else 0.0
	if best.is_empty():
		set_note(city, household, "Keeps to its own work (no garden ground, woods or mending within reach)" if step == 0 else "")
		return
	# The wisdoms that bear on the choice, when they could have tipped it (GuidingWisdom).
	var threshold: float = STEP_SCORES[mini(before, STEP_SCORES.size() - 1)]
	var more: bool = step > before or (step == before and step > 0)
	GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PREPARE, more, best_score, threshold, float(best["prepare"]))
	GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PRIDE, not more, best_score, threshold, float(best["pride"]))
	if CommunityPriority.is_swayed(best_score, float(best["appeal"]), threshold) and step > before:
		CommunityPriority.record_swayed(city, household, "secondary", "It gave time to %s because the gathering asked" % SECONDARY_NAMES[best_activity])
	if step > 0:
		set_note(city, household, "Gives %d%% of its day to %s (%s)" % [roundi(household.secondary_share * 100.0), SECONDARY_NAMES[household.secondary_activity], "; ".join(FamilyInitiative.get_reasons(best["terms"], true))])
	else:
		set_note(city, household, "Keeps to its own work rather than %s (%s)" % [SECONDARY_NAMES[best_activity], "; ".join(FamilyInitiative.get_reasons(best["terms"], false))])

# Drawn from the town, the family and the day, so a loaded game chooses as the original would have.
static func get_starting_step(city: City, household: Household, wanted: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, household.id, city.construction.day, "secondary_start"])
	return rng.randi_range(1, wanted)

# {"possible", "score", "terms", "appeal", "prepare", "pride"}.
static func get_secondary_desire(city: City, household: Household, holding: Building, activity: String, claimed: Dictionary) -> Dictionary:
	var result: Dictionary = {"possible": false, "score": 0.0, "terms": [], "appeal": 0.0, "prepare": 0.0, "pride": 0.0}
	if get_holding_output(holding) == activity:
		return result
	var land: float = 1.0
	match activity:
		"food":
			land = get_garden_land(city, household, claimed, false)
		"wood":
			land = get_woods_land(city, household)
		"tools":
			land = 1.0 if holding.needs_maintenance() else 0.0
	if land <= 0.0:
		return result
	result["possible"] = true
	var terms: Array = []
	FamilyInitiative.add(terms, -SECONDARY_COST, "it would take time from its own work")
	var town_short: bool = GuidingWisdom.is_short_of(city, activity)
	if town_short:
		FamilyInitiative.add(terms, TOWN_SHORT_WEIGHT, "the town is short of " + activity)
	var own_need: bool = false
	match activity:
		"food":
			if household.larder_target_days > 0 and household.larder < get_larder_target(household):
				own_need = true
				FamilyInitiative.add(terms, OWN_NEED_WEIGHT, "its larder is low")
			var season: float = EconomyBalance.FARM_SEASON_YIELD[city.get_season_index()] - 1.0
			if absf(season) > 0.01:
				FamilyInitiative.add(terms, 2.0 * season, "the season is good for a garden" if season > 0.0 else "little grows this season")
			if land < 1.0:
				FamilyInitiative.add(terms, -(1.0 - land), "its garden ground is poor or small")
		"wood":
			if land < 1.0:
				FamilyInitiative.add(terms, -(1.0 - land), "few trees near its home")
		"tools":
			if holding.maintenance_level < 100:
				own_need = true
				FamilyInitiative.add(terms, OWN_NEED_WEIGHT, "its workplace needs mending")
			if household.mending >= 1.0:
				FamilyInitiative.add(terms, -OWN_NEED_WEIGHT * household.mending, "it has mended enough for now")
	if OccupationReview.is_oversupplied(city, holding):
		FamilyInitiative.add(terms, OWN_PLENTY_WEIGHT, "the town has plenty of what it makes")
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	if risk != 0:
		FamilyInitiative.add(terms, -0.5 * risk, "it is cautious" if risk < 0 else "it trusts things will hold")
	var self_reliant: int = HouseholdCharacter.get_strength(household, "self_reliant")
	if self_reliant > 0:
		FamilyInitiative.add(terms, 0.75 * self_reliant, "it would rather rely on itself")
	var thrifty: int = HouseholdCharacter.get_strength(household, "thrifty")
	if thrifty > 0:
		FamilyInitiative.add(terms, 0.5 * thrifty, "it is thrifty")
	var common: int = HouseholdCharacter.get_strength(household, "common_stores")
	if common > 0:
		FamilyInitiative.add(terms, -0.5 * common, "it relies on the common stores")
	if household.trust != 0:
		FamilyInitiative.add(terms, -0.25 * household.trust, "it doubts the town will see it through" if household.trust < 0 else "it trusts the town to see it through")
	var knows: float = get_level(household, str(SECONDARY_WORK[activity]))
	if knows >= FORGOTTEN_BELOW:
		FamilyInitiative.add(terms, KNOWS_WEIGHT * knows, "it knows how")
	var own_skill: float = minf(1.0, get_level(household, holding.type) / ESTABLISHED)
	if own_skill > 0.0:
		FamilyInitiative.add(terms, -OWN_SKILL_WEIGHT * own_skill, "it is good at its own work")
	if household.get_match_quality(holding.type) == CultureEffects.MATCH_GOOD:
		FamilyInitiative.add(terms, -0.5, "its own work is its calling")
	# Prepare for Hard Times asks it to keep something back when supplies are thin; Take Pride in
	# Your Work asks it to put its effort into its own work.
	if town_short or own_need:
		result["prepare"] = GuidingWisdom.add_appeal(city, household, GuidingWisdom.PREPARE, terms, 1.0)
	result["pride"] = GuidingWisdom.add_appeal(city, household, GuidingWisdom.PRIDE, terms, -1.0)
	result["appeal"] = FamilyInitiative.add_encouragement(city, household, activity, terms, "the gathering asks for more " + activity)
	result["score"] = FamilyInitiative.sum(terms)
	result["terms"] = terms
	return result

# How much food a family keeps back for itself: 0, 30, 60 or 90 days of its own eating, a step a
# month. Below its target it eats from the common store and keeps its harvest.
static func decide_larder(city: City, household: Household) -> void:
	if household.secondary_activity != "food" and household.larder <= 0.0 and household.larder_target_days == 0:
		return
	var terms: Array = []
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	if risk != 0:
		FamilyInitiative.add(terms, -0.5 * risk, "it is cautious" if risk < 0 else "it trusts things will hold")
	for value: String in ["thrifty", "self_reliant", "private_holdings"]:
		var strength: int = HouseholdCharacter.get_strength(household, value)
		if strength > 0:
			FamilyInitiative.add(terms, 0.5 * strength, "it holds to %s" % HouseholdCharacter.get_value_name(value))
	for value: String in ["common_stores", "sharing"]:
		var strength: int = HouseholdCharacter.get_strength(household, value)
		if strength > 0:
			FamilyInitiative.add(terms, -0.75 * strength, "it holds to %s" % HouseholdCharacter.get_value_name(value))
	if household.trust != 0:
		FamilyInitiative.add(terms, -0.25 * household.trust, "it doubts the common stores" if household.trust < 0 else "it trusts the common stores")
	if FamilyInitiative.get_food_days(city) < 90.0:
		FamilyInitiative.add(terms, 1.0, "the town's food is thin")
	if household.hardship_points > 0:
		FamilyInitiative.add(terms, 0.5, "it has known hardship")
	# Prepare asks it to keep something back; We Endure Together, to put its food with the town's.
	var prepare: float = GuidingWisdom.add_appeal(city, household, GuidingWisdom.PREPARE, terms, 1.0)
	var endure: float = GuidingWisdom.add_appeal(city, household, GuidingWisdom.ENDURE, terms, -1.0)
	var score: float = FamilyInitiative.sum(terms) + FamilyInitiative.get_noise(city, household, "larder")
	var step: int = maxi(0, LARDER_STEPS.find(household.larder_target_days))
	var wanted: int = 0
	for i in range(LARDER_STEP_SCORES.size()):
		if score >= LARDER_STEP_SCORES[i]:
			wanted = i + 1
	var before: int = step
	step += signi(wanted - step)
	household.larder_target_days = LARDER_STEPS[step]
	var threshold: float = LARDER_STEP_SCORES[mini(before, LARDER_STEP_SCORES.size() - 1)]
	GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PREPARE, step > 0, score, threshold, prepare)
	GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.ENDURE, step == 0, score, threshold, endure)
	if step > 0:
		household.larder_note = "Keeps back up to %d days of its own food (%s)" % [household.larder_target_days, "; ".join(FamilyInitiative.get_reasons(terms, true))]
	else:
		household.larder_note = "Eats what it grows and leaves the rest to the common store (%s)" % "; ".join(FamilyInitiative.get_reasons(terms, false))

static func set_note(city: City, household: Household, text: String) -> void:
	if text == "":
		return
	household.economy_note = text
	household.economy_note_day = city.construction.day

# --- Sharing ----------------------------------------------------------------------------------

# A donor with food in its larder can give real food: GIFT_DAYS of the recipient's eating.
static func can_give_food(household: Household, recipient: Household) -> bool:
	return household.larder >= GIFT_DAYS * get_daily_need(recipient)

static func give_food(city: City, donor: Household, recipient: Household) -> void:
	var amount: float = GIFT_DAYS * get_daily_need(recipient)
	donor.larder -= amount
	recipient.larder += amount
	city.influence.food_gifts += 1
	city.influence.food_gift_units += amount
