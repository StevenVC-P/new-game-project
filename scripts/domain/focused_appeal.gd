class_name FocusedAppeal
extends RefCounted

# Focused appeals (owner, 2026-11-01): the gathering asks the community for one thing the town lacks,
# for a while: someone to take up toolmaking, families to grow food, someone to cut wood. It is a
# request, not an order and not a priority:
#
# - it concerns one good, and pulls only on work that makes it (FamilyInitiative.get_work_desire),
#   weighed by each family's receptiveness like any ask (FamilyInitiative.get_receptiveness), in a
#   family's first choice of work and in a review it has its own reason for. It starts no review;
# - it lasts at most APPEAL_DAYS, and ends once a family has taken up the work asked for;
# - it leaves the Community Priority, its stores rule and the Guiding Wisdoms as they are, and the
#   player can make it again when it has ended.
#
# Before asking, the player sees which families are likely to answer and why (get_responses).

const APPEAL_DAYS: int = 90
const WEIGHT: float = 2.0
# What each good's appeal asks for, in the gathering's words and on the card.
const ASKS: Dictionary = {
	"tools": "asks someone to take up toolmaking",
	"food": "asks families to grow food",
	"wood": "asks someone to cut wood",
}
const LIKELY: String = "likely"
const MIGHT: String = "might"
const UNLIKELY: String = "unlikely"
const NOT_LOOKING: String = "not looking again yet"

static func is_active(city: City, good: String) -> bool:
	var appeal: Dictionary = city.influence.appeals.get(good, {})
	return not appeal.is_empty() and city.construction.day - int(appeal["day"]) < APPEAL_DAYS

static func make(city: City, good: String) -> bool:
	if not ASKS.has(good) or is_active(city, good):
		return false
	city.influence.appeals[good] = {"day": city.construction.day, "producers": FamilyInitiative.count_producers(city, good)}
	city.influence.appeals_made += 1
	return true

# Daily (City.tick, after families' weekly choices): an appeal ends once a family has taken up the
# work it asked for, or when its time is out.
static func advance_day(city: City) -> void:
	for good: String in city.influence.appeals.keys():
		var appeal: Dictionary = city.influence.appeals[good]
		if FamilyInitiative.count_producers(city, good) > int(appeal["producers"]):
			city.influence.appeals_answered += 1
			city.influence.appeals.erase(good)
		elif city.construction.day - int(appeal["day"]) >= APPEAL_DAYS:
			city.influence.appeals.erase(good)

# The appeal's weight in a family's wish to take up work making `good`; returns the weight added.
static func add_appeal(city: City, household: Household, good: String, terms: Array) -> float:
	if not is_active(city, good):
		return 0.0
	var receptive: Dictionary = FamilyInitiative.get_receptiveness(household, city, CommunityPriority.KIND_DIRECTING)
	var weight: float = WEIGHT * float(receptive["factor"])
	FamilyInitiative.add(terms, weight, "the gathering %s%s" % [ASKS[good], receptive["note"]])
	return weight

# How each family would likely answer an appeal for `good`, as if it were made now, with its
# reasons: [{"household", "outlook", "reasons"}], most likely first. A family without work weighs
# it in its next choice; a family at work only when it next looks at its work for its own reasons.
# Changes nothing: the appeal is set and taken back as predict_improvement does.
static func get_responses(city: City, good: String) -> Array[Dictionary]:
	var had: Dictionary = city.influence.appeals.get(good, {})
	city.influence.appeals[good] = {"day": city.construction.day, "producers": FamilyInitiative.count_producers(city, good)}
	var responses: Array[Dictionary] = []
	for household: Household in city.households:
		if household.labor_capacity <= 0:
			continue
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null and FamilyInitiative.get_activity(holding.type) == good:
			continue
		var best_asked: Dictionary = {}
		var best_asked_score: float = -INF
		for occupation: String in FamilyInitiative.get_occupations(city):
			if FamilyInitiative.get_activity(occupation) != good:
				continue
			var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, occupation)
			if bool(desire["available"]) and float(desire["score"]) > best_asked_score:
				best_asked_score = float(desire["score"])
				best_asked = desire
		if best_asked.is_empty():
			continue
		var outlook: String = UNLIKELY
		if holding == null:
			var best_other: float = -INF
			for occupation: String in FamilyInitiative.get_occupations(city):
				if FamilyInitiative.get_activity(occupation) == good:
					continue
				var other: Dictionary = FamilyInitiative.get_work_desire(city, household, occupation)
				if bool(other["available"]):
					best_other = maxf(best_other, float(other["score"]))
			var lead: float = best_asked_score - best_other
			outlook = LIKELY if lead >= FamilyInitiative.NOISE * 2.0 else MIGHT if lead > -FamilyInitiative.NOISE * 2.0 else UNLIKELY
		elif FamilyInitiative.get_activity(holding.type) != "":
			var margin: float = best_asked_score - float(OccupationReview.get_stay_desire(city, household, holding)["score"])
			var looking: bool = OccupationReview.is_due(city, household) or OccupationReview.is_due_in_danger(city, household)
			if margin >= OccupationReview.CHANGE_MARGIN + 1.0:
				outlook = LIKELY if looking else NOT_LOOKING
			elif margin >= OccupationReview.CHANGE_MARGIN - 1.5:
				outlook = MIGHT if looking else NOT_LOOKING
		responses.append({"household": household, "outlook": outlook, "reasons": FamilyInitiative.get_reasons(best_asked["terms"], outlook != UNLIKELY, 2)})
	if had.is_empty():
		city.influence.appeals.erase(good)
	else:
		city.influence.appeals[good] = had
	var order: Dictionary = {LIKELY: 0, MIGHT: 1, NOT_LOOKING: 2, UNLIKELY: 3}
	responses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(order[a["outlook"]]) < int(order[b["outlook"]]) or (a["outlook"] == b["outlook"] and (a["household"] as Household).id < (b["household"] as Household).id))
	return responses

# The card's lines about an appeal for `good`: the one standing, or who would likely answer one.
static func describe(city: City, good: String) -> Array:
	var lines: Array = []
	if is_active(city, good):
		var appeal: Dictionary = city.influence.appeals[good]
		lines.append("The gathering %s (%d days ago, for %d more); families weigh it for themselves." % [ASKS[good], city.construction.day - int(appeal["day"]), APPEAL_DAYS - (city.construction.day - int(appeal["day"]))])
		return lines
	var responses: Array[Dictionary] = get_responses(city, good)
	var likely: Array = responses.filter(func(r: Dictionary) -> bool: return r["outlook"] == LIKELY or r["outlook"] == MIGHT)
	if likely.is_empty():
		lines.append("If the gathering %s, no family is likely to answer now." % ASKS[good])
	else:
		var names: Array[String] = []
		for response: Dictionary in likely.slice(0, 2):
			names.append("%s %s answer (%s)" % [city.get_household_label((response["household"] as Household).id), "would likely" if response["outlook"] == LIKELY else "might", "; ".join(response["reasons"])])
		lines.append("If the gathering %s: %s." % [ASKS[good], "; ".join(names)])
	return lines
