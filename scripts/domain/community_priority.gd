class_name CommunityPriority
extends RefCounted

# The community's one primary priority (docs/COMMUNITY_PRIORITIES.md): what the gathering asks
# families to put first. It replaces the four separate work asks. It is persuasion: each priority
# adds an appeal to decisions families already make every week, scaled by how receptive each
# family is to that kind of request, and families still decide. It is separate from the stores
# rule (TownInfluence.store_rule): only under "priorities first" does the priority also decide which
# families' improvements the common stores fund.
#
# - food: improving and taking up food work (FamilyInitiative);
# - housing: giving spare time to home sites, and working long days on them (TownSocial); home
#   sites come first for builders and the materials they carry (TownConstruction);
# - investment: improving any hand work, and taking up tool work;
# - cooperation: giving spare time to neighbours' and the town's sites.
#
# Each family also judges each priority for itself (get_view): its own circumstances and
# convictions make it support, oppose, or not much mind one. What the town as a whole backs, with
# respected voices counting double, pulls on families as a norm's acceptance does (add_backing).
# There is no vote: the player sets the priority whatever the town backs.

const NONE: String = ""
const FOOD: String = "food"
const HOUSING: String = "housing"
const INVESTMENT: String = "investment"
const COOPERATION: String = "cooperation"
const ALL: Array[String] = [FOOD, HOUSING, INVESTMENT, COOPERATION]
const NAMES: Dictionary = {NONE: "No priority", FOOD: "Food security", HOUSING: "Permanent housing", INVESTMENT: "Productive investment", COOPERATION: "Cooperation"}
const PHRASES: Dictionary = {FOOD: "food", HOUSING: "homes", INVESTMENT: "better work", COOPERATION: "working together"}
# What each priority asks of families' own work (TownInfluence.is_encouraged); under the
# priorities-first stores rule, the activities whose projects the stores fund.
const ACTIVITIES: Dictionary = {
	NONE: [],
	FOOD: [TownInfluence.ACTIVITY_FOOD],
	HOUSING: [],
	INVESTMENT: [TownInfluence.ACTIVITY_IMPROVE, TownInfluence.ACTIVITY_TOOLS],
	COOPERATION: [],
}

# Requests by kind (FamilyInitiative.get_receptiveness): a directing request asks families to change
# their own work; a voluntary one asks for time given freely.
const KIND_DIRECTING: String = "directing"
const KIND_VOLUNTARY: String = "voluntary"

const SUPPORT_AT: float = 1.0
const OPPOSE_AT: float = -1.0
const SUPPORTS: String = "supports"
const INDIFFERENT: String = "does not much mind"
const OPPOSES: String = "opposes"
# Spare time given to a home site: the weight of a promise of help (SocialDecisions.get_hours_desire).
const LONG_DAYS_APPEAL_WEIGHT: float = 0.5
const RESPONSES_KEPT: int = 60
const MEMORY_INTERVAL_DAYS: int = 90

static func get_kind(priority: String) -> String:
	return KIND_VOLUNTARY if priority == COOPERATION else KIND_DIRECTING

static func get_display_name(priority: String) -> String:
	return str(NAMES.get(priority, priority))

# --- Families' views ---------------------------------------------------------------------------

# How one family judges putting a priority first: {"score", "terms", "stance"}, terms in its own
# words like any decision. From what the simulation already holds: its home, its security, its
# work, its temperament and convictions, the town's food, and its trust in the gathering.
static func get_view(city: City, household: Household, priority: String) -> Dictionary:
	var terms: Array = []
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	var unhoused: bool = household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household)
	match priority:
		HOUSING:
			if unhoused:
				FamilyInitiative.add(terms, 2.0, "it still has no proper home")
			elif household.ambition == FamilyAmbitions.HOME:
				FamilyInitiative.add(terms, 1.0, "it wants a better home")
			else:
				FamilyInitiative.add(terms, -0.5, "it has its own home")
			if not unhoused and city.social.enabled and city.social.get_kin(household).any(func(kin: Household) -> bool: return kin.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(kin)):
				FamilyInitiative.add(terms, 1.0, "its kin have no proper home")
		FOOD:
			var waiting: float = FamilyInitiative.get_waiting_risk(city, TownInfluence.ACTIVITY_FOOD)
			if waiting > 0.0:
				FamilyInitiative.add(terms, 1.5 * waiting, "the town's food is short")
			elif FamilyInitiative.get_food_days(city) >= FamilyInitiative.SECURE_FOOD_DAYS:
				FamilyInitiative.add(terms, -1.0, "the stores hold half a year of food")
			if risk < 0:
				FamilyInitiative.add(terms, 0.5 * -risk, "it puts food first")
			if TownSocial.get_security_margin(household) <= 4:
				FamilyInitiative.add(terms, 1.0, "it is getting by on little")
		INVESTMENT:
			var holding: Building = FamilyInitiative.get_holding(city, household)
			if holding != null and holding.is_tier0():
				FamilyInitiative.add(terms, 0.5, "it works by hand")
			elif holding != null:
				FamilyInitiative.add(terms, -0.5, "its own work is already improved")
			if risk != 0:
				FamilyInitiative.add(terms, 0.5 * risk, "the family is " + HouseholdCharacter.describe_axis(HouseholdCharacter.RISK, risk))
			var ambition: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.AMBITION)
			if ambition > 0:
				FamilyInitiative.add(terms, 0.5 * ambition, "it wants to get on")
			if city.social.enabled and int(FamilyInitiative.get_neighbours_example(city, household)["paying"]) > 0:
				FamilyInitiative.add(terms, 0.75, "its neighbours' improved work is paying")
			var spending: float = FamilyInitiative.get_spending_risk(city, EconomyBalance.get_build_cost("farm"))
			if spending > 0.0:
				FamilyInitiative.add(terms, -spending, "it would spend scarce wood and tools")
		COOPERATION:
			SocialDecisions.add_strength(terms, household, "communal_labor", 0.75, "it values working together")
			SocialDecisions.add_strength(terms, household, "mutual_aid", 0.5, "it believes neighbours should help one another")
			SocialDecisions.add_strength(terms, household, "solitary", -0.75, "it prefers to work alone")
			SocialDecisions.add_strength(terms, household, "private_holdings", -0.5, "it puts its own holding first")
			if city.social.enabled and city.social.get_kin(household).any(func(kin: Household) -> bool: return TownSocial.is_in_need(city, kin)):
				FamilyInitiative.add(terms, 1.0, "its kin need help")
	if get_kind(priority) == KIND_DIRECTING:
		SocialDecisions.add_strength(terms, household, "self_governing", -0.5, "it holds that families should decide their own work")
		SocialDecisions.add_strength(terms, household, "deferential", 0.25, "it follows the gathering's lead")
	if household.trust != 0:
		FamilyInitiative.add(terms, 0.25 * household.trust, "it trusts the gathering" if household.trust > 0 else "it distrusts the gathering")
	var score: float = FamilyInitiative.sum(terms)
	var stance: String = SUPPORTS if score >= SUPPORT_AT else OPPOSES if score <= OPPOSE_AT else INDIFFERENT
	return {"score": score, "terms": terms, "stance": stance}

# Every family's view of a priority, for the preview: [{"household", "stance", "score", "reasons"}].
static func get_views(city: City, priority: String) -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for household: Household in city.households:
		var view: Dictionary = get_view(city, household, priority)
		var supports: bool = view["stance"] != OPPOSES
		views.append({"household": household, "stance": view["stance"], "score": view["score"], "reasons": FamilyInitiative.get_reasons(view["terms"], supports and float(view["score"]) > 0.0)})
	return views

# How far the town backs a priority, 0 to 1: supporters count 1, families that do not much mind a
# half, opponents nothing; respected voices (TownSocial.get_respected_voices) count double.
static func get_backing(city: City, priority: String) -> float:
	if city.households.is_empty():
		return 0.5
	var voices: Array[Household] = city.social.get_respected_voices() if city.social.enabled else ([] as Array[Household])
	var total: float = 0.0
	var backed: float = 0.0
	for household: Household in city.households:
		var weight: float = 2.0 if voices.has(household) else 1.0
		var stance: String = get_view(city, household, priority)["stance"]
		total += weight
		backed += weight * (1.0 if stance == SUPPORTS else 0.5 if stance == INDIFFERENT else 0.0)
	return backed / total

# The town's backing of its current priority, worked out at most once a week.
static func get_town_backing(city: City) -> float:
	var influence: TownInfluence = city.influence
	var week: int = city.construction.day / FamilyInitiative.INTERVAL_DAYS
	if influence.backing_week != week or influence.backing_priority != influence.priority:
		influence.backing = get_backing(city, influence.priority) if influence.priority != NONE else 0.5
		influence.backing_week = week
		influence.backing_priority = influence.priority
	return influence.backing

# --- Appeals in families' decisions ---------------------------------------------------------------

# What the town backs pulls on a family as a norm's acceptance does (SocialDecisions.add_norm).
static func add_backing(city: City, household: Household, terms: Array) -> float:
	if city.influence.priority == NONE:
		return 0.0
	var pull: float = (get_town_backing(city) - 0.5) * 2.0 * (1.0 + 0.25 * HouseholdCharacter.get_axis(household, HouseholdCharacter.SOCIABILITY))
	if absf(pull) < 0.2:
		return 0.0
	FamilyInitiative.add(terms, pull, ("most families back putting %s first" if pull > 0.0 else "few families back putting %s first") % PHRASES[city.influence.priority])
	return pull

# The priority's appeal in a family's wish to give spare time to a site (SocialDecisions.get_help_desire):
# homes under housing, any neighbour's or the town's site under cooperation. Returns its weight.
static func add_help_appeal(city: City, household: Household, project: ConstructionProject, terms: Array) -> float:
	var priority: String = city.influence.priority
	if not ((priority == HOUSING and project.is_home()) or priority == COOPERATION):
		return 0.0
	var receptive: Dictionary = FamilyInitiative.get_receptiveness(household, city, get_kind(priority))
	var weight: float = SocialDecisions.NORM_APPEAL_WEIGHT * float(receptive["factor"])
	FamilyInitiative.add(terms, weight, "the gathering puts %s first%s" % [PHRASES[priority], receptive["note"]])
	return weight + add_backing(city, household, terms)

# The housing priority's appeal in a family's wish to work long days on a home site.
static func add_hours_appeal(city: City, household: Household, project: ConstructionProject, terms: Array) -> float:
	if city.influence.priority != HOUSING or not project.is_home():
		return 0.0
	var receptive: Dictionary = FamilyInitiative.get_receptiveness(household, city, KIND_DIRECTING)
	var weight: float = LONG_DAYS_APPEAL_WEIGHT * float(receptive["factor"])
	FamilyInitiative.add(terms, weight, "the gathering puts homes first" + str(receptive["note"]))
	return weight

# --- Responses and consequences -------------------------------------------------------------------

# A decision the priority's appeal tipped: it would not have been made without it.
static func is_swayed(score: float, appeal: float, threshold: float) -> bool:
	return appeal > 0.0 and score >= threshold and score - appeal < threshold

# Counts a decision the priority tipped, and the first such sacrifice in a while stays with the
# family as a memory (no lesson drawn: what it makes of the priority is for later).
static func record_swayed(city: City, household: Household, decision: String, text: String = "") -> void:
	var influence: TownInfluence = city.influence
	var key: String = "%s:%s" % [influence.priority, decision]
	influence.swayed[key] = int(influence.swayed.get(key, 0)) + 1
	if text == "":
		return
	for memory: Dictionary in household.memories:
		if str(memory["kind"]) == "priority" and city.construction.day - int(memory["day"]) < MEMORY_INTERVAL_DAYS:
			return
	HouseholdMemory.remember(city, household, "priority", text, null, 1.0, [])

# When the gathering sets a priority, each family's view of it is recorded.
static func record_responses(city: City) -> void:
	var influence: TownInfluence = city.influence
	if influence.priority == NONE:
		return
	for view: Dictionary in get_views(city, influence.priority):
		influence.responses.append({"day": city.construction.day, "priority": influence.priority, "household_id": (view["household"] as Household).id, "stance": view["stance"], "reasons": view["reasons"].slice(0, 2)})
	while influence.responses.size() > RESPONSES_KEPT:
		influence.responses.pop_front()

# --- Warnings ------------------------------------------------------------------------------------

# What a priority under a stores rule will cost or risk, in plain words, from the town's state now.
# These warn; they never stop the player.
static func get_warnings(city: City, priority: String, store_rule: String) -> Array[String]:
	var warnings: Array[String] = []
	var activities: Array = ACTIVITIES.get(priority, [])
	if store_rule == TownInfluence.RULE_PRIORITIES and not activities.has(TownInfluence.ACTIVITY_IMPROVE):
		if activities.is_empty():
			warnings.append("No family's improvement will be funded from the stores: every family stays on hand work, and hand work alone feeds few.")
		var held: Dictionary = {}
		for building: Building in city.buildings:
			var activity: String = FamilyInitiative.get_activity(building.type)
			if building.is_tier0() and activity != "" and not activities.has(activity) and building.assigned_workers > 0:
				held[activity] = int(held.get(activity, 0)) + 1
		var ratio: float = FamilyInitiative.get_food_ratio(city)
		if held.has(TownInfluence.ACTIVITY_FOOD):
			warnings.append("%d families grow food by hand and could not improve into farms; the town grows %d%% of the food it eats." % [held[TownInfluence.ACTIVITY_FOOD], roundi(ratio * 100.0)])
		if held.has(TownInfluence.ACTIVITY_TOOLS) or (not activities.has(TownInfluence.ACTIVITY_TOOLS) and FamilyInitiative.count_proper(city, "toolmaker") == 0):
			warnings.append("No toolmaker will be funded: tools (%d) run down with the upkeep of every proper workplace." % int(city.resources["tools"]))
		if held.has(TownInfluence.ACTIVITY_WOOD):
			warnings.append("%d families cut wood by hand and could not improve into woodcutters." % held[TownInfluence.ACTIVITY_WOOD])
	match priority:
		HOUSING:
			var unhoused: int = city.households.filter(func(h: Household) -> bool: return h.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(h)).size()
			if unhoused > 0 and city.construction.get_open_plots().is_empty():
				warnings.append("No home plots are set aside: %d families cannot build homes until plots are marked." % unhoused)
			warnings.append("Families who work long days on homes wear themselves out, and hardship drives families away.")
		INVESTMENT:
			var food_days: float = FamilyInitiative.get_food_days(city)
			if city.construction.day % Calendar.DAYS_PER_YEAR >= Calendar.DAYS_PER_YEAR / 2 and food_days < 90.0:
				warnings.append("Improvements now spend wood and tools before winter, with %d days of food in store." % roundi(food_days))
		COOPERATION:
			warnings.append("A family giving time to others' sites gives up a fifth of its own working day.")
	return warnings
