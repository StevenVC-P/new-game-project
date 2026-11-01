class_name OccupationReview
extends RefCounted

# Families reconsidering their work (docs/OCCUPATION_RECONSIDERATION.md). Where families lead
# (TownInfluence.enabled), a family chose its work once (FamilyInitiative.take_up_work); here it
# may look at it again, rarely, when its own circumstances have changed:
#
# - its work is against its calling, while work of its calling is something it could take up;
# - its workplace has stood short of tools (worked by hand, or idle) for a season;
# - the town has more than enough of what it makes, while it is short of something else, for a season;
# - its home has come to lie much farther from its work than when it took it up, for a season.
#
# A reason only starts a review; it does not decide it. The family weighs staying against the
# other work it could take up, with the same reasoning as its first choice (calling, what the
# town needs, the priority's ask, Prepare for Hard Times), and staying carries what it would lose:
# what it has built up, the years it has worked there, its workplace standing idle, its
# temperament, and the walk to work. It changes only when the other work is clearly better
# (CHANGE_MARGIN), at most once a year (REVIEW_INTERVAL_DAYS), and at most MAX_CHANGES_PER_MONTH
# families a month in the town. A Community Priority or a Guiding Wisdom weighs in, but never
# starts a review (owner, 2026-10-31).
#
# Changing: the family opens hand work for the new activity where land is free (no contests),
# keeps its old work until that is built, then leaves it. The old workplace stays standing, empty
# and open to the next family free to work, as when a family leaves the town. The change is
# remembered with its reasons; lessons come only from what follows.

const REVIEW_INTERVAL_DAYS: int = 360
# A family judges its work once it has had it for two seasons.
const MIN_TENURE_DAYS: int = 180
# Months a reason must hold before it counts (a season).
const STRAIN_MONTHS: int = 3
const MAX_CHANGES_PER_MONTH: int = 1
const CHANGE_MARGIN: float = 2.0

# Weights for staying, set before the comparison (docs/OCCUPATION_RECONSIDERATION.md).
const BUILT_UP_PROPER: float = 3.0
const BUILT_UP_HAND: float = 0.5
const TENURE_PER_YEAR: float = 0.5
const TENURE_MAX: float = 1.5
const LEFT_IDLE_PROPER: float = 1.5
const LEFT_IDLE_HAND: float = 0.5
const TRAVEL_WEIGHT: float = 5.0
const TRAVEL_NOTICED: float = 0.1
# A home much farther from work than when the family took it up: this share of its day travelling,
# and this much more than at the start.
const TRAVEL_TRIGGER: float = 0.25
const TRAVEL_TRIGGER_RISE: float = 0.15
const FOOD_PLENTY_RATIO: float = 1.6
const OTHER_PRODUCERS_PLENTY: int = 2

const CALLING: String = "calling"
const TOOLS: String = "short_of_tools"
const OVERSUPPLY: String = "oversupplied"
const DISTANCE: String = "distance"

static func is_on(city: City) -> bool:
	return city.influence.enabled and city.influence.reconsider_work

# Monthly (HouseholdMigration.advance_month, after ambitions).
static func advance_month(city: City) -> void:
	if not is_on(city):
		return
	var today: int = city.construction.day
	var changes: int = 0
	var candidates: Array[Household] = []
	for household: Household in city.households:
		# A plan to change that no longer has a site to build on is dropped.
		if household.work_change_from >= 0 and not FamilyInitiative.has_own_project(city, household):
			household.work_change_from = -1
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding == null or FamilyInitiative.get_activity(holding.type) == "":
			continue
		if household.work_building_id != holding.id:
			household.work_building_id = holding.id
			household.work_since = today
			household.work_start_travel = city.logistics.get_travel_share(holding)
			household.work_strain.clear()
		update_strain(city, household, holding)
		if is_due(city, household) and not get_triggers(city, household, holding).is_empty():
			candidates.append(household)
	# The longest-waiting first, so the town's limit does not always pass over the same families.
	candidates.sort_custom(func(a: Household, b: Household) -> bool: return a.work_review_day < b.work_review_day or (a.work_review_day == b.work_review_day and a.id < b.id))
	for household: Household in candidates:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		var triggers: Array[String] = get_triggers(city, household, holding)
		var decision: Dictionary = weigh(city, household, holding)
		if bool(decision["change"]) and changes >= get_change_limit(city):
			# Another family is already changing its work this month; this one looks again next month.
			city.influence.work_deferred += 1
			city.influence._work_review_log.append({"day": today, "household": household.id, "deferred": true, "families": city.households.size()})
			continue
		city.influence.work_reviews += 1
		for trigger: String in triggers:
			city.influence.work_triggers[trigger] = int(city.influence.work_triggers.get(trigger, 0)) + 1
		household.work_review_day = today
		var changed: bool = bool(decision["change"]) and change_work(city, household, holding, decision)
		if changed:
			changes += 1
		else:
			stay(city, household, holding, decision)
		city.influence._work_review_log.append({"day": today, "household": household.id, "families": city.households.size(), "from": FamilyInitiative.get_activity(holding.type), "proper": not holding.is_tier0(), "to": decision["activity"], "changed": changed, "triggers": triggers, "margin": float(decision["margin"]), "appeal": float(decision["appeal"]), "stay_appeal": float(decision["stay_appeal"]), "for": FamilyInitiative.get_reasons(decision["alternative_terms"], true, 2), "against": FamilyInitiative.get_reasons(decision["stay_terms"], true, 2)})

# The town's monthly limit; the comparison may lift it (meta "work_change_limit", 0 for none).
static func get_change_limit(city: City) -> int:
	var limit: int = int(city.get_meta("work_change_limit", MAX_CHANGES_PER_MONTH))
	return limit if limit > 0 else 1 << 30

static func is_due(city: City, household: Household) -> bool:
	var today: int = city.construction.day
	if household.labor_capacity <= 0 or household.work_change_from >= 0 or FamilyInitiative.has_own_project(city, household):
		return false
	if today - household.work_since < MIN_TENURE_DAYS:
		return false
	return household.work_review_day < 0 or today - household.work_review_day >= REVIEW_INTERVAL_DAYS

# Months each reason has held, reset when it lapses.
static func update_strain(city: City, household: Household, holding: Building) -> void:
	var holds: Dictionary = {
		TOOLS: holding.needs_maintenance() and holding.maintenance_level < 50,
		OVERSUPPLY: is_oversupplied(city, holding) and is_short_elsewhere(city, FamilyInitiative.get_activity(holding.type)),
		DISTANCE: is_far(city, household, holding),
	}
	for reason: String in holds.keys():
		household.work_strain[reason] = int(household.work_strain.get(reason, 0)) + 1 if bool(holds[reason]) else 0

# The reasons that would make the family look at its work again now.
static func get_triggers(city: City, household: Household, holding: Building) -> Array[String]:
	var triggers: Array[String] = []
	if is_against_calling(household, holding):
		triggers.append(CALLING)
	for reason: String in [TOOLS, OVERSUPPLY, DISTANCE]:
		if int(household.work_strain.get(reason, 0)) >= STRAIN_MONTHS:
			triggers.append(reason)
	return triggers

# Work against its calling (a poor match, or a calling ambition waiting past its patience) while
# work of its calling is among what families take up themselves.
static func is_against_calling(household: Household, holding: Building) -> bool:
	if not household.has_values():
		return false
	var current: String = FamilyInitiative.get_activity(holding.type)
	var calling_work: bool = FamilyInitiative.ACTIVITIES.any(func(a: String) -> bool: return a != current and household.get_match_quality(FamilyInitiative.PROPER_WORK[a]) == CultureEffects.MATCH_GOOD)
	if not calling_work:
		return false
	var poor: bool = household.get_match_quality(holding.type) == CultureEffects.MATCH_POOR
	var waiting: bool = household.ambition == FamilyAmbitions.CALLING and household.ambition_months > EconomyBalance.AMBITION_PATIENCE_MONTHS
	return poor or waiting

static func is_oversupplied(city: City, holding: Building) -> bool:
	var activity: String = FamilyInitiative.get_activity(holding.type)
	if activity == TownInfluence.ACTIVITY_FOOD:
		return FamilyInitiative.get_food_ratio(city) > FOOD_PLENTY_RATIO
	return FamilyInitiative.count_producers(city, activity) - 1 >= OTHER_PRODUCERS_PLENTY

static func is_short_elsewhere(city: City, activity: String) -> bool:
	return FamilyInitiative.ACTIVITIES.any(func(a: String) -> bool: return a != activity and FamilyInitiative.get_waiting_risk(city, a) > 0.0)

static func is_far(city: City, household: Household, holding: Building) -> bool:
	var share: float = city.logistics.get_travel_share(holding)
	return share >= TRAVEL_TRIGGER and share >= household.work_start_travel + TRAVEL_TRIGGER_RISE

# Staying against the best other work: {"change", "activity", "margin", "stay_terms",
# "alternative_terms", "appeal" (the priority's ask for the other work), "stay_appeal"}.
static func weigh(city: City, household: Household, holding: Building) -> Dictionary:
	var current: String = FamilyInitiative.get_activity(holding.type)
	var staying: Dictionary = get_stay_desire(city, household, holding)
	var stay_score: float = float(staying["score"]) + FamilyInitiative.get_noise(city, household, "stay_at_work")
	var best: Dictionary = {}
	var best_activity: String = ""
	var best_score: float = -INF
	for activity: String in FamilyInitiative.ACTIVITIES:
		if activity == current:
			continue
		var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, activity)
		var score: float = float(desire["score"]) + FamilyInitiative.get_noise(city, household, "change_to_" + activity)
		if score > best_score:
			best_score = score
			best = desire
			best_activity = activity
	var margin: float = best_score - stay_score
	return {"change": margin >= CHANGE_MARGIN, "activity": best_activity, "margin": margin, "stay_terms": staying["terms"], "alternative_terms": best["terms"], "appeal": float(best.get("appeal", 0.0)), "stay_appeal": float(staying.get("appeal", 0.0))}

# How much a family wants to keep its work: the same desire as choosing it (calling, the town's
# need, the priority's ask, Prepare), and what it would give up, in its own words.
static func get_stay_desire(city: City, household: Household, holding: Building) -> Dictionary:
	var current: String = FamilyInitiative.get_activity(holding.type)
	var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, current, holding)
	var terms: Array = desire["terms"]
	var name: String = FamilyInitiative.describe_type(holding.type, false)
	var proper: bool = not holding.is_tier0()
	FamilyInitiative.add(terms, BUILT_UP_PROPER if proper else BUILT_UP_HAND, ("it has built up its " if proper else "it knows its ") + name)
	var years: int = (city.construction.day - household.work_since) / Calendar.DAYS_PER_YEAR
	if years > 0:
		FamilyInitiative.add(terms, minf(TENURE_MAX, TENURE_PER_YEAR * years), "it has worked it for %d year%s" % [years, "" if years == 1 else "s"])
	if not someone_could_take_over(city, household):
		FamilyInitiative.add(terms, LEFT_IDLE_PROPER if proper else LEFT_IDLE_HAND, "its %s would stand idle" % name)
	var tradition: int = HouseholdCharacter.get_strength(household, "traditionalist")
	if tradition > 0:
		FamilyInitiative.add(terms, 0.75 * tradition, "it keeps to what it knows")
	var reform: int = HouseholdCharacter.get_strength(household, "reformist")
	if reform > 0:
		FamilyInitiative.add(terms, -0.5 * reform, "it welcomes new ways")
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	if risk != 0:
		FamilyInitiative.add(terms, -0.5 * risk, "it would not risk what it has" if risk < 0 else "it is ready to try something new")
	var travel: float = city.logistics.get_travel_share(holding)
	if travel >= TRAVEL_NOTICED:
		FamilyInitiative.add(terms, -TRAVEL_WEIGHT * travel, "its work is a long way from home (%d%% of its day)" % roundi(travel * 100.0))
	return {"score": FamilyInitiative.sum(terms), "terms": terms, "appeal": desire["appeal"]}

# Whether another family is free to take on a workplace it leaves (no work, none being built).
static func someone_could_take_over(city: City, household: Household) -> bool:
	for other: Household in city.households:
		if other != household and other.labor_capacity > 0 and FamilyInitiative.get_holding(city, other) == null and not city.construction.is_promised_to_workplace(other.id):
			return true
	return false

# Opens hand work for the new activity where land is free; the old work is left once it is built.
static func change_work(city: City, household: Household, holding: Building, decision: Dictionary) -> bool:
	var activity: String = decision["activity"]
	var building_type: String = FamilyInitiative.HAND_WORK[activity]
	var site: Vector2i = FamilyInitiative.choose_site(city, household, building_type)
	if site.x < 0:
		decision["blocked"] = "it found no free land for %s" % FamilyInitiative.describe_type(building_type)
		return false
	var project: ConstructionProject = city.construction.request_building(building_type, site, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)
	if project == null:
		return false
	city.influence.workplaces_opened += 1
	city.influence.work_changes += 1
	household.work_change_from = holding.id
	FamilyInitiative.use_first_claim(city, household, project)
	var reasons: Array[String] = FamilyInitiative.get_reasons(decision["alternative_terms"], true)
	for reason: String in reasons:
		city.influence.work_change_reasons[reason] = int(city.influence.work_change_reasons.get(reason, 0)) + 1
	if CommunityPriority.is_swayed(float(decision["margin"]), float(decision["appeal"]), CHANGE_MARGIN):
		CommunityPriority.record_swayed(city, household, "work")
	var short: Array[String] = []
	for a: String in FamilyInitiative.ACTIVITIES:
		if GuidingWisdom.is_short_of(city, a):
			short.append(a)
	if not short.is_empty():
		GuidingWisdom.record(city, household, GuidingWisdom.PREPARE, short.has(activity))
	var text: String = "It is leaving its %s to take up %s" % [FamilyInitiative.describe_type(holding.type, false), FamilyInitiative.describe_type(building_type)]
	var why: String = "%s (%s; it gives up: %s)" % [text, "; ".join(reasons), "; ".join(FamilyInitiative.get_reasons(decision["stay_terms"], true, 2))]
	HouseholdMemory.remember(city, household, "changed_work", why, null, 1.0, [] as Array[String])
	FamilyInitiative.note(city, household, why)
	set_review_note(city, household, why)
	return true

static func stay(city: City, household: Household, holding: Building, decision: Dictionary) -> void:
	var reasons: Array[String] = FamilyInitiative.get_reasons(decision["stay_terms"], true)
	if decision.has("blocked"):
		reasons.push_front(str(decision["blocked"]))
	for reason: String in reasons:
		var key: String = reason.split(" (")[0]
		city.influence.work_stay_reasons[key] = int(city.influence.work_stay_reasons.get(key, 0)) + 1
	var tempted: Array[String] = FamilyInitiative.get_reasons(decision["alternative_terms"], true, 2)
	var text: String = "Thought of %s, but keeps its %s (%s)" % [FamilyInitiative.describe_type(FamilyInitiative.HAND_WORK[decision["activity"]]) + (" (" + "; ".join(tempted) + ")" if not tempted.is_empty() else ""), FamilyInitiative.describe_type(holding.type, false), "; ".join(reasons)]
	FamilyInitiative.note(city, household, text)
	set_review_note(city, household, text)

static func set_review_note(city: City, household: Household, text: String) -> void:
	household.work_review_note = text
	household.work_review_note_day = city.construction.day

# City.add_building, for a workplace built for a family: when it is the new work of a family
# changing its work, the family now leaves its old workplace. The building stays, empty, open to
# the next family free to work.
static func on_workplace_added(city: City, household: Household, building: Building) -> void:
	if household.work_change_from < 0 or household.work_change_from == building.id:
		return
	var old_id: int = household.work_change_from
	household.work_change_from = -1
	for old: Building in city.buildings:
		if old.id == old_id and old.assigned_household_id == household.id:
			if household.work_history.is_empty():
				household.work_history.append(FamilyInitiative.get_activity(old.type))
			old.unassign_worker(false)
			if not old.is_tier0():
				city.influence.workplaces_left_proper += 1
			household.work_history.append(FamilyInitiative.get_activity(building.type))
			city.update_household_assignments()
			city.auto_assign_workers()
			if old.assigned_household_id < 0:
				city.influence.workplaces_left_empty += 1
			break
