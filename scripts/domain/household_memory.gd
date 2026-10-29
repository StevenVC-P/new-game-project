class_name HouseholdMemory
extends RefCounted

# A household's ties, memories, and how experience slowly changes what it values
# (docs/HOUSEHOLD_SOCIAL_MODEL.md, Sections 4 and 11).
#
# Ties are sparse: kin and at most MAX_TIES households in all, each made by something that
# happened between them, never by scanning the town. Memories are bounded: the most significant
# few stay. An experience is interpreted by the household itself: each kind of experience offers
# several lessons, each supported by the household's personality, values, relationships, and the
# facts of the event (was it fair, voluntary, costly), and the best-supported lesson (two when
# nearly equal) adds evidence for or against a value. Values move one level at most a year, and
# only when the evidence has built up, so behavior can change long before beliefs do.

const MAX_TIES: int = 8
const MAX_MEMORIES: int = 8
const MAX_REASONS: int = 3
const MAX_CHANGE_NOTES: int = 4
# Evidence that moves a value one level, and the least time between two moves of one value.
const EVIDENCE_TO_CHANGE: float = 3.0
const DAYS_BETWEEN_CHANGES: int = 360
# A second lesson is also drawn when its support is within this of the best.
const SECOND_LESSON_MARGIN: float = 0.5

# --- Ties -----------------------------------------------------------------------------------------

static func get_tie(household: Household, other_id: int) -> Dictionary:
	for tie: Dictionary in household.ties:
		if int(tie["with"]) == other_id:
			return tie
	return {}

static func get_disposition(household: Household, other_id: int) -> int:
	return int(get_tie(household, other_id).get("disposition", 0))

static func is_kin(household: Household, other: Household) -> bool:
	return household.is_child_of(other.id) or other.is_child_of(household.id)

# Changes (and creates, if need be) the household's tie to another: disposition by `delta`, a
# reason, favours owed (positive: this household owes the other), and a grievance ("" leaves it;
# "-" clears it).
static func touch_tie(city: City, household: Household, other: Household, delta: int, reason: String, owes_delta: int = 0, grievance: String = "") -> Dictionary:
	var tie: Dictionary = get_tie(household, other.id)
	if tie.is_empty():
		tie = {"with": other.id, "disposition": 0, "kind": "", "reasons": [], "owes": 0, "grievance": "", "since": city.construction.day, "kin": is_kin(household, other)}
		household.ties.append(tie)
		if household.ties.size() > MAX_TIES:
			drop_weakest_tie(household)
	tie["disposition"] = clampi(int(tie["disposition"]) + delta, -3, 3)
	tie["owes"] = int(tie["owes"]) + owes_delta
	if reason != "":
		var reasons: Array = tie["reasons"]
		reasons.erase(reason)
		reasons.append(reason)
		while reasons.size() > MAX_REASONS:
			reasons.pop_front()
	if grievance == "-":
		tie["grievance"] = ""
	elif grievance != "":
		tie["grievance"] = grievance
	tie["kind"] = get_tie_kind(tie)
	return tie

static func get_tie_kind(tie: Dictionary) -> String:
	var disposition: int = int(tie["disposition"])
	if bool(tie.get("kin", false)):
		return "kin"
	if disposition <= -3 and str(tie["grievance"]) != "":
		return "feud"
	if disposition <= -2:
		return "rival"
	if disposition >= 2:
		return "friend"
	if int(tie["owes"]) != 0:
		return "obligation"
	return "cooperation" if disposition > 0 else "acquaintance"

# The weakest tie that is not kin gives way: the least strongly felt, then the oldest.
static func drop_weakest_tie(household: Household) -> void:
	var weakest: int = -1
	for i in range(household.ties.size()):
		var tie: Dictionary = household.ties[i]
		if bool(tie.get("kin", false)):
			continue
		if weakest < 0 or absi(int(tie["disposition"])) + absi(int(tie["owes"])) < absi(int(household.ties[weakest]["disposition"])) + absi(int(household.ties[weakest]["owes"])):
			weakest = i
	if weakest >= 0:
		household.ties.remove_at(weakest)

# Kin ties to the households a family came from and the ones it founded, warm to begin with.
const KIN_START_DISPOSITION: int = 1

static func ensure_kin_ties(city: City, household: Household) -> void:
	for other: Household in city.social.get_kin(household):
		if get_tie(household, other.id).is_empty():
			touch_tie(city, household, other, KIN_START_DISPOSITION, "kin")

# --- Memories and interpretation -----------------------------------------------------------------

# Records an experience and draws the household's own lesson from it. `facets`: what the
# interpretation weighs ({"benefit", "voluntary", "fair", "cost", "major", ...}). Returns the
# lessons drawn (their words).
static func experience(city: City, household: Household, kind: String, text: String, other: Household = null, facets: Dictionary = {}) -> Array[String]:
	var lessons: Array[Dictionary] = get_lessons(city, household, kind, other, facets)
	lessons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["support"]) > float(b["support"]))
	var chosen: Array[Dictionary] = []
	if not lessons.is_empty():
		chosen.append(lessons[0])
		if lessons.size() > 1 and float(lessons[0]["support"]) - float(lessons[1]["support"]) <= SECOND_LESSON_MARGIN:
			chosen.append(lessons[1])
	var words: Array[String] = []
	var magnitude: float = 2.0 if bool(facets.get("major", false)) else 1.0
	for lesson: Dictionary in chosen:
		words.append(str(lesson["text"]))
		if str(lesson["value"]) != "":
			add_evidence(city, household, str(lesson["value"]), float(lesson["direction"]) * magnitude, text)
	remember(city, household, kind, text, other, magnitude, words)
	return words

static func remember(city: City, household: Household, kind: String, text: String, other: Household, weight: float, lessons: Array[String]) -> void:
	household.memories.append({"day": city.construction.day, "kind": kind, "text": text, "with": other.id if other != null else -1, "weight": weight, "lessons": lessons})
	while household.memories.size() > MAX_MEMORIES:
		var least: int = 0
		for i in range(household.memories.size()):
			if float(household.memories[i]["weight"]) < float(household.memories[least]["weight"]):
				least = i
		household.memories.remove_at(least)

# The lessons an experience offers this household, each with its support. A lesson with no value
# changes only feelings (kept in the tie or in trust by whoever records the experience).
static func get_lessons(city: City, household: Household, kind: String, other: Household, facets: Dictionary) -> Array[Dictionary]:
	var lessons: Array[Dictionary] = []
	var empathy: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.EMPATHY)
	var sociability: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.SOCIABILITY)
	var ambition: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.AMBITION)
	var assertiveness: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.ASSERTIVENESS)
	var diligence: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.DILIGENCE)
	var risk: float = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	var disposition: float = get_disposition(household, other.id) if other != null else 0.0
	var s: Callable = func(value_id: String) -> float: return float(HouseholdCharacter.get_strength(household, value_id))
	match kind:
		"helped", "food_received":
			lessons.append(lesson("neighbours can be trusted", "mutual_aid", 1, 1.0 + 0.5 * empathy + 0.5 * sociability + 0.3 * disposition + 0.3 * s.call("mutual_aid")))
			lessons.append(lesson("we should help others in turn", "communal_labor" if kind == "helped" else "charitable", 1, 0.5 + 0.5 * diligence + 0.3 * empathy + 0.5 * s.call("communal_labor" if kind == "helped" else "charitable")))
			lessons.append(lesson("it is humbling to depend on others", "self_governing", 1, 0.5 * ambition + 0.5 * assertiveness + 0.5 * s.call("self_governing") + 0.5 * s.call("private_holdings") - 0.5 * sociability))
		"food_refused":
			var could_not: bool = bool(facets.get("could_not", false))
			lessons.append(lesson("they could not spare it", "", 0, (1.5 if could_not else -0.5) + 0.5 * empathy + 0.5 * s.call("forgiveness")))
			lessons.append(lesson("they are selfish", "", 0, (-0.5 if could_not else 1.0) + 0.5 * assertiveness + 0.5 * s.call("vindication") - 0.3 * disposition))
			lessons.append(lesson("we must provide for ourselves", "acquisitive", 1, 0.5 + 0.5 * ambition - 0.3 * risk + 0.5 * s.call("acquisitive") - 0.3 * empathy))
			lessons.append(lesson("neighbours should owe each other more", "mutual_aid", 1, 0.3 + 0.5 * s.call("mutual_aid") + 0.5 * s.call("charitable") + 0.3 * empathy))
		"food_given":
			lessons.append(lesson("sharing in hard times is right", "charitable", 1, 0.8 + 0.5 * empathy + 0.5 * s.call("charitable") + 0.3 * disposition))
			lessons.append(lesson("we gave more than we could spare", "sharing", -1, float(facets.get("cost", 0.0)) - 0.4 * risk + 0.5 * s.call("thrifty") - 0.3 * empathy))
		"help_unreturned":
			lessons.append(lesson("they take without giving", "", 0, 0.8 + 0.5 * assertiveness + 0.5 * s.call("vindication")))
			lessons.append(lesson("we must look after our own work first", "communal_labor", -1, 0.3 + 0.5 * ambition - 0.3 * empathy + 0.5 * s.call("solitary")))
			lessons.append(lesson("they have troubles of their own", "", 0, 0.3 + 0.5 * empathy + 0.5 * s.call("forgiveness")))
		"dispute_settled":
			lessons.append(lesson("talking it out works", "negotiation", 1, 0.8 + 0.5 * s.call("negotiation") + 0.3 * sociability - 0.3 * assertiveness))
			lessons.append(lesson("claims must be respected", "respect_for_holdings", 1, 0.5 + 0.5 * s.call("respect_for_holdings") + (0.5 if bool(facets.get("victim", false)) else 0.0)))
		"dispute_unsettled":
			if bool(facets.get("victim", false)):
				lessons.append(lesson("they wronged us and must answer for it", "vindication", 1, 0.5 + 0.6 * assertiveness + 0.5 * s.call("vindication") - 0.5 * s.call("forgiveness")))
				lessons.append(lesson("claims need protecting", "respect_for_holdings", 1, 0.8 + 0.5 * s.call("respect_for_holdings") + 0.3 * s.call("stewardship")))
				lessons.append(lesson("better to let it go", "forgiveness", 1, 0.3 - 0.5 * assertiveness + 0.4 * empathy + 0.5 * s.call("forgiveness") - 0.5 * s.call("vindication")))
			else:
				lessons.append(lesson("a footpath is no great harm", "respect_for_holdings", -1, 0.3 + 0.5 * assertiveness - 0.3 * empathy - 0.5 * s.call("respect_for_holdings")))
				lessons.append(lesson("they make a quarrel of everything", "", 0, 0.5 + 0.3 * assertiveness - 0.3 * disposition))
		"honour_unfair", "share_unfair":
			lessons.append(lesson("the gathering plays favourites", "", 0, 0.8 + 0.5 * s.call("egalitarian") + 0.3 * float(facets.get("overlooked", 0.0))))
			lessons.append(lesson("everyone's work deserves its due", "egalitarian", 1, 0.3 + 0.6 * s.call("egalitarian") + 0.3 * empathy - 0.4 * s.call("hierarchical")))
			lessons.append(lesson("honour goes to those who seek it", "hierarchical", 1, 0.3 * ambition + 0.6 * s.call("hierarchical") - 0.4 * s.call("egalitarian")))
		"honour_fair":
			var fair_value: String = RECOGNITION_VALUES.get(str(facets.get("category", "")), "communal_labor")
			lessons.append(lesson(str(RECOGNITION_LESSONS.get(str(facets.get("category", "")), "service is noticed here")), fair_value, 1, 0.5 + 0.3 * diligence + 0.3 * ambition + 0.3 * s.call(fair_value)))
			lessons.append(lesson("honours are for others", "", 0, 0.3 - 0.4 * ambition - 0.3 * sociability))
		"honoured":
			var own_value: String = RECOGNITION_VALUES.get(str(facets.get("category", "")), "communal_labor")
			lessons.append(lesson("the town values what we do", own_value, 1, 0.6 + 0.5 * ambition + 0.3 * s.call(own_value)))
			lessons.append(lesson("we would rather be left alone", "", 0, 0.2 - 0.6 * sociability - 0.3 * ambition))
		"land_yielded":
			lessons.append(lesson("neighbours should make room for each other", "mutual_aid", 1, 0.5 + 0.5 * empathy + 0.3 * s.call("sharing") + 0.3 * disposition))
			lessons.append(lesson("we gave up what was ours", "private_holdings", 1, 0.3 + 0.5 * s.call("private_holdings") + 0.5 * s.call("landholding") - 0.3 * empathy))
		"land_given":
			lessons.append(lesson("neighbours make room for those in need", "mutual_aid", 1, 0.6 + 0.4 * empathy + 0.3 * disposition))
			lessons.append(lesson("asking openly works", "negotiation", 1, 0.4 + 0.5 * s.call("negotiation") + 0.3 * sociability))
		"land_refused":
			if bool(facets.get("accepted", false)):
				lessons.append(lesson("their claim came first", "respect_for_holdings", 1, 0.5 + 0.5 * s.call("respect_for_holdings") - 0.3 * assertiveness))
			lessons.append(lesson("they keep everything for themselves", "", 0, 0.3 + 0.5 * assertiveness - 0.3 * disposition - (1.0 if bool(facets.get("accepted", false)) else 0.0)))
			lessons.append(lesson("we must secure land of our own", "landholding", 1, 0.3 + 0.4 * ambition + 0.5 * s.call("landholding") - 0.2 * empathy))
		"land_kept":
			lessons.append(lesson("claims must be respected", "respect_for_holdings", 1, 0.6 + 0.5 * s.call("respect_for_holdings") + 0.3 * s.call("private_holdings")))
			lessons.append(lesson("newcomers want what others built", "", 0, 0.3 + 0.3 * assertiveness - 0.4 * empathy))
		"land_taken":
			lessons.append(lesson("the gathering takes what it wants", "self_governing", 1, 0.5 + 0.5 * s.call("self_governing") + 0.5 * s.call("private_holdings") + 0.3 * assertiveness))
			lessons.append(lesson("the town's needs come first", "common_stores", 1, 0.2 + 0.5 * s.call("deferential") + 0.5 * s.call("common_stores")))
			lessons.append(lesson("no holding is safe", "landholding", 1, 0.3 + 0.5 * s.call("landholding") - 0.3 * risk))
		"land_given_to_town":
			lessons.append(lesson("the town's needs come first", "common_stores", 1, 0.5 + 0.5 * s.call("deferential") + 0.5 * s.call("common_stores") + 0.3 * s.call("communal_labor")))
			lessons.append(lesson("we gave up what was ours", "private_holdings", 1, 0.3 + 0.5 * s.call("private_holdings") + 0.5 * s.call("landholding")))
		"built_together":
			lessons.append(lesson("working together builds the town", "communal_labor", 1, 0.5 + 0.3 * sociability + 0.3 * s.call("communal_labor")))
			lessons.append(lesson("our own work waited for it", "solitary", 1, 0.2 - 0.4 * sociability + 0.5 * s.call("solitary") + 0.3 * s.call("private_holdings")))
	if kind == "honour_unfair":
		match str(facets.get("category", "")):
			TownSocial.RECOGNITION_ACHIEVEMENT:
				lessons.append(lesson("honours go to the already prosperous", "egalitarian", 1, 0.2 + 0.5 * s.call("egalitarian") + 0.4 * s.call("communal_labor") + (0.5 if bool(facets.get("prosperous", false)) else 0.0)))
			TownSocial.RECOGNITION_SERVICE:
				lessons.append(lesson("our own work goes unrewarded", "private_holdings", 1, 0.1 + 0.4 * diligence + 0.5 * s.call("private_holdings") + 0.3 * float(facets.get("overlooked", 0.0))))
	return lessons

# The value a deserved honour of each kind bears out, and how the household puts it.
const RECOGNITION_VALUES: Dictionary = {"service": "communal_labor", "achievement": "private_holdings", "craft": "keepers_of_craft", "civic": "negotiation"}
const RECOGNITION_LESSONS: Dictionary = {"service": "service is noticed here", "achievement": "building up a holding is honoured here", "craft": "good craft is honoured here", "civic": "keeping the peace is honoured here"}

static func lesson(text: String, value_id: String, direction: int, support: float) -> Dictionary:
	return {"text": text, "value": value_id, "direction": direction, "support": support}

# Adds evidence for (positive) or against a value. At EVIDENCE_TO_CHANGE the value moves one
# level, if it has not moved in the last year; the evidence then starts again (hysteresis), and
# the change is explained by the experience that tipped it.
static func add_evidence(city: City, household: Household, value_id: String, amount: float, because: String) -> void:
	# A household cannot hold both of a pair of opposites: evidence for one first wears down the other.
	var opposite: String = HouseholdCharacter.get_opposite(value_id)
	if amount > 0.0 and HouseholdCharacter.get_strength(household, opposite) > 0:
		value_id = opposite
		amount = -amount
	var evidence: float = float(household.value_evidence.get(value_id, 0.0)) + amount
	var last: int = int(household.value_changed_day.get(value_id, -DAYS_BETWEEN_CHANGES))
	var may_change: bool = city.construction.day - last >= DAYS_BETWEEN_CHANGES
	var strength: int = HouseholdCharacter.get_strength(household, value_id)
	if evidence >= EVIDENCE_TO_CHANGE and may_change and strength < 3:
		HouseholdCharacter.set_strength(household, value_id, strength + 1)
		note_change(city, household, value_id, true, because)
		evidence = 0.0
	elif evidence <= -EVIDENCE_TO_CHANGE and may_change and strength > 0:
		HouseholdCharacter.set_strength(household, value_id, strength - 1)
		note_change(city, household, value_id, false, because)
		evidence = 0.0
	household.value_evidence[value_id] = clampf(evidence, -EVIDENCE_TO_CHANGE * 2.0, EVIDENCE_TO_CHANGE * 2.0)

static func note_change(city: City, household: Household, value_id: String, stronger: bool, because: String) -> void:
	household.value_changed_day[value_id] = city.construction.day
	city.social.value_changes += 1
	# A value that moves back the way it last came is a reversal: the social check watches for
	# convictions that swing back and forth.
	var key: String = "%d:%s" % [household.id, value_id]
	if city.social.value_change_directions.has(key) and bool(city.social.value_change_directions[key]) != stronger:
		city.social.value_reversals += 1
	city.social.value_change_directions[key] = stronger
	var strength: int = HouseholdCharacter.get_strength(household, value_id)
	var now: String = HouseholdCharacter.STRENGTH_WORDS[strength] + " " + HouseholdCharacter.get_value_name(value_id) if strength > 0 else "no longer holds to " + HouseholdCharacter.get_value_name(value_id)
	household.value_change_notes.append("Day %d: after %s, it now %s" % [city.construction.day, because.to_lower(), now])
	while household.value_change_notes.size() > MAX_CHANGE_NOTES:
		household.value_change_notes.pop_front()
