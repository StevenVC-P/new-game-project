class_name TownRegard
extends RefCounted

# Emergent recognition and the Speaker of the Gathering (docs/EMERGENT_RECOGNITION_AND_LEADERSHIP.md).
# Families create the community's politics; the player influences who receives authority, but
# cannot dictate what families believe or how everyone responds (owner, 2026-11-01).
#
# - Recognition: when a household reaches something new in one of the four kinds of contribution
#   (service, achievement, craft, civic), the households that know it judge it by their own lights:
#   what they prize, their ties, levelling or hierarchy, their own work overlooked, the town's
#   guiding wisdom. Some admire it, some resent it; most do not much mind. Each achievement is
#   noticed once.
# - Influence: regard (standing), following (families well or ill disposed to it), weight in the
#   town's work, and contribution, each shown; the three most influential are the candidates.
# - The Speaker (from Village): the Elder appoints one of the three. It keeps its own autonomy and
#   gains a voice: families who follow it take the priority as it does, families against it the
#   other way; it decides who gets first claim on the stores (within the Elder's rules and reserves);
#   it urges settlement in disputes. Families judge the appointment, its acts, and its removal.

const KINDS: Array[String] = [TownSocial.RECOGNITION_SERVICE, TownSocial.RECOGNITION_ACHIEVEMENT, TownSocial.RECOGNITION_CRAFT, TownSocial.RECOGNITION_CIVIC]
# Service and civic acts are counted: each doubling past the first two is a new achievement.
const COUNTED_FIRST: float = 2.0
# Holding and craft are levels (0-3): a new level from two up is a new achievement.
const LEVEL_FIRST: float = 2.0
# The wisdom each kind of contribution lives by.
const KIND_WISDOM: Dictionary = {
	TownSocial.RECOGNITION_SERVICE: GuidingWisdom.ENDURE,
	TownSocial.RECOGNITION_CIVIC: GuidingWisdom.RESPECT,
	TownSocial.RECOGNITION_CRAFT: GuidingWisdom.PRIDE,
	TownSocial.RECOGNITION_ACHIEVEMENT: GuidingWisdom.PRIDE,
}
const ADMIRE_AT: float = 1.0
const RESENT_AT: float = -1.5
const ADMIRED_STANDING: float = 0.25
const ADMIRED_STANDING_MAX: float = 1.0
const RESENTED_STANDING: float = -0.25
const RESENTED_STANDING_MIN: float = -0.5

# Influence parts.
const FOLLOWING_PER_FAMILY: float = 0.5
const FOLLOWING_MAX: float = 3.0
const KIN_WEIGHT: float = 0.5
const KIN_WEIGHT_MAX: float = 1.5
const CONTRIBUTION_MAX: float = 2.0
const CANDIDATES: int = 3
# A voice in the gathering needs at least this much influence.
const VOICE_INFLUENCE: float = 2.0

# The Speaker.
const SUPPORT_AT: float = 1.0
const DOUBT_AT: float = -1.0
const OPPOSE_AT: float = -2.0
const LEAD_VIEW_WEIGHT: float = 0.5
const LEAD_RECEPTIVE_WEIGHT: float = 0.2
const MEDIATION_WEIGHT: float = 0.4
const ACT_INTERVAL_MONTHS: int = 3
const GRANTS_PER_SEASON: int = 2
const POLICY_HELPERS: String = "helpers"
const POLICY_NEEDY: String = "needy"
const POLICY_OWN: String = "own"
const POLICY_NONE: String = "none"
const POLICY_TEXT: Dictionary = {
	POLICY_HELPERS: "gives first claim on the stores to families who help",
	POLICY_NEEDY: "gives first claim on the stores to families in hardship",
	POLICY_OWN: "gives first claim on the stores to its own kin and friends",
	POLICY_NONE: "leaves the stores to the Elder's rules alone",
}

static func is_on(city: City) -> bool:
	return city.social.enabled and city.social.emergent_regard

# --- Recognition ------------------------------------------------------------------------------

# Monthly (TownSocial.review_month): new achievements are noticed by the households that know them.
static func advance_month(city: City) -> void:
	if not is_on(city):
		return
	check_speaker(city)
	for target: Household in city.households.duplicate():
		for kind: String in KINDS:
			var merit: float = city.social.get_merit(target, kind)
			if is_new_achievement(target, kind, merit):
				target.noticed_merit[kind] = merit
				notice(city, target, kind)
	update_influential(city)
	if city.social.speaker_id >= 0:
		var months: int = (city.construction.day - city.social.speaker_since) / Calendar.DAYS_PER_MONTH
		if months > 0 and months % ACT_INTERVAL_MONTHS == 0:
			speaker_acts(city)

static func is_new_achievement(household: Household, kind: String, merit: float) -> bool:
	var noticed: float = float(household.noticed_merit.get(kind, 0.0))
	if kind == TownSocial.RECOGNITION_SERVICE or kind == TownSocial.RECOGNITION_CIVIC:
		return merit >= maxf(COUNTED_FIRST, noticed * 2.0)
	return merit >= LEVEL_FIRST and merit > noticed

# Every household that knows the target judges what it did.
static func notice(city: City, target: Household, kind: String) -> void:
	var social: TownSocial = city.social
	var middle: float = social.get_middle_merit(kind)
	var prosperous: bool = social.is_prosperous(target)
	var serves: bool = social.serves_town(target, kind)
	var what: String = TownSocial.RECOGNITION_NAMES[kind]
	var label: String = city.get_household_label(target.id)
	var admirers: int = 0
	var resenters: int = 0
	var standing: float = 0.0
	social.notices += 1
	for observer: Household in social.get_known_households(target):
		if observer == target or not city.households.has(observer):
			continue
		var judged: Dictionary = judge_deed(city, observer, target, kind, middle, prosperous, serves)
		var score: float = float(judged["score"])
		if score >= ADMIRE_AT:
			admirers += 1
			HouseholdMemory.touch_tie(city, observer, target, 1, "admires its " + what)
			HouseholdMemory.experience(city, observer, "honour_fair", "%s became known for its %s" % [label, what], target, {"fair": 1, "category": kind})
			if HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION) > 0 and TownSocial.get_esteem(observer, kind) > 0.0:
				observer.inspired_by = kind
				observer.inspired_by_household = target.id
				observer.inspired_until = city.construction.day + TownSocial.HONOUR_PRESTIGE_DAYS
			if standing < ADMIRED_STANDING_MAX:
				standing += ADMIRED_STANDING
			social.note(observer, "Admires %s's %s (%s)" % [label, what, "; ".join(FamilyInitiative.get_reasons(judged["terms"], true))])
		elif score <= RESENT_AT:
			resenters += 1
			HouseholdMemory.touch_tie(city, observer, target, -1, "thinks itself above us")
			if standing > RESENTED_STANDING_MIN:
				standing += RESENTED_STANDING
			social.note(observer, "Resents %s's %s (%s)" % [label, what, "; ".join(FamilyInitiative.get_reasons(judged["terms"], false))])
	social.adjust_standing(target, standing)
	social.admirations += admirers
	social.resentments += resenters
	if admirers > 0 and resenters > 0:
		social.divided_notices += 1
	if admirers >= 2:
		HouseholdMemory.experience(city, target, "honoured", "%d families admire its %s" % [admirers, what], null, {"benefit": 1, "category": kind})
	if admirers + resenters > 0:
		social.record_regard(target, kind, admirers, resenters)

# One household's judgment of another's new achievement: {"score", "terms"}. The same reasoning as
# judging an honour (TownSocial.judge_recognition), but nobody granted anything: the deed is real,
# so there is no question of desert or favouritism; what remains is what the observer prizes, its
# own work overlooked, levelling and hierarchy, kin and ties, and the town's wisdom.
static func judge_deed(city: City, observer: Household, target: Household, kind: String, middle: float, prosperous: bool, serves: bool) -> Dictionary:
	var terms: Array = []
	var s: Callable = func(value_id: String) -> int: return HouseholdCharacter.get_strength(observer, value_id)
	var what: String = TownSocial.RECOGNITION_NAMES[kind]
	FamilyInitiative.add(terms, 0.5, "it is real work, done")
	var esteem: float = TownSocial.get_esteem(observer, kind)
	if absf(esteem) >= 0.5:
		FamilyInitiative.add(terms, 0.5 * esteem, ("it prizes " if esteem > 0.0 else "it thinks little of ") + what)
	var prized: String = TownSocial.get_prized(observer)
	var overlooked: float = city.social.get_merit(observer, prized) - (city.social.get_merit(target, kind) if prized == kind else maxf(1.0, middle))
	if overlooked >= 2.0:
		FamilyInitiative.add(terms, -1.0 - 0.25 * maxi(0, HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION)), "its own %s goes unnoticed" % TownSocial.RECOGNITION_NAMES[prized])
	if kind == TownSocial.RECOGNITION_ACHIEVEMENT and prosperous:
		var levelling: float = s.call("egalitarian") + 0.5 * s.call("communal_labor") + 0.5 * s.call("sharing")
		if levelling >= 1.0:
			FamilyInitiative.add(terms, -minf(1.5, 0.5 * levelling), "they were already prosperous")
	if kind in [TownSocial.RECOGNITION_ACHIEVEMENT, TownSocial.RECOGNITION_CRAFT] and TownSocial.get_esteem(observer, TownSocial.RECOGNITION_SERVICE) >= 1.0:
		FamilyInitiative.add(terms, 0.5 if serves else -0.75, "their work serves the town" if serves else "their success serves only themselves")
	if s.call("hierarchical") > 0:
		FamilyInitiative.add(terms, 0.25 * s.call("hierarchical"), "regard belongs to the accomplished")
	if s.call("egalitarian") > 0 and target.standing >= TownSocial.VOICE_STANDING:
		FamilyInitiative.add(terms, -0.25 * s.call("egalitarian"), "regard piles on the already regarded")
	if HouseholdMemory.is_kin(observer, target):
		FamilyInitiative.add(terms, 0.5, "they are kin")
	var disposition: int = HouseholdMemory.get_disposition(observer, target.id) - (HouseholdMemory.KIN_START_DISPOSITION if HouseholdMemory.is_kin(observer, target) else 0)
	if disposition != 0:
		FamilyInitiative.add(terms, 0.3 * disposition, "they are on good terms" if disposition > 0 else "they are on bad terms")
	# What the town holds to: a deed that lives by a held wisdom pleases those who support it.
	var wisdom: String = KIND_WISDOM[kind]
	if GuidingWisdom.is_active(city, wisdom):
		var stance: String = GuidingWisdom.get_view(observer, wisdom)["stance"]
		if stance == GuidingWisdom.SUPPORTS:
			FamilyInitiative.add(terms, 0.5, "it lives by what the town holds to")
		elif stance == GuidingWisdom.RESERVED:
			FamilyInitiative.add(terms, -0.25, "it makes much of a wisdom the family doubts")
	var score: float = FamilyInitiative.sum(terms) + FamilyInitiative.get_noise(city, observer, "notice:%d:%s" % [target.id, kind])
	return {"score": score, "terms": terms}

# --- Influence --------------------------------------------------------------------------------

# A household's influence, in parts: {"total", "regard", "following", "weight", "contribution",
# "supporters", "detractors"} (supporters and detractors are households).
static func get_influence(city: City, household: Household) -> Dictionary:
	var supporters: Array[Household] = []
	var detractors: Array[Household] = []
	for other: Household in city.households:
		if other == household:
			continue
		var disposition: int = HouseholdMemory.get_disposition(other, household.id)
		if disposition > 0:
			supporters.append(other)
		elif disposition < 0:
			detractors.append(other)
	var following: float = clampf(FOLLOWING_PER_FAMILY * float(supporters.size() - detractors.size()), -FOLLOWING_MAX, FOLLOWING_MAX)
	var weight: float = 0.0
	var holding: Building = FamilyInitiative.get_holding(city, household)
	if holding != null and not holding.is_tier0():
		weight += 1.0
	if holding != null and city.social.serves_town(household, TownSocial.RECOGNITION_ACHIEVEMENT):
		weight += 1.0
	weight += minf(KIN_WEIGHT_MAX, KIN_WEIGHT * float(city.social.get_kin(household).size()))
	var contribution: float = minf(CONTRIBUTION_MAX, 0.1 * float(household.help_given) + 0.5 * float(household.civic_acts))
	var regard: float = float(household.standing)
	return {"total": regard + following + weight + contribution, "regard": regard, "following": following, "weight": weight, "contribution": contribution, "supporters": supporters, "detractors": detractors}

static func describe_influence(parts: Dictionary) -> String:
	return "regard %+d, following %+.1f (%d for, %d against), weight in the town's work %.1f, contribution %.1f" % [int(parts["regard"]), float(parts["following"]), (parts["supporters"] as Array).size(), (parts["detractors"] as Array).size(), float(parts["weight"]), float(parts["contribution"])]

# The most influential households, most first: [{"household", "influence"}].
static func get_ranked(city: City, count: int = CANDIDATES) -> Array:
	var ranked: Array = []
	for household: Household in city.households:
		ranked.append({"household": household, "influence": get_influence(city, household)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: float = float(a["influence"]["total"])
		var tb: float = float(b["influence"]["total"])
		return ta > tb or (ta == tb and (a["household"] as Household).id < (b["household"] as Household).id))
	return ranked.slice(0, count)

static func update_influential(city: City) -> void:
	var ids: Array = []
	for entry: Dictionary in get_ranked(city):
		ids.append((entry["household"] as Household).id)
	if ids != city.social.influential:
		if not city.social.influential.is_empty():
			city.social.influential_changes += 1
		city.social.influential = ids
	for id in ids:
		city.social.ever_influential[str(id)] = int(city.social.ever_influential.get(str(id), 0)) + 1

# The gathering's voices: the most influential households with enough influence to carry weight.
static func get_voices(city: City) -> Array[Household]:
	var voices: Array[Household] = []
	for entry: Dictionary in get_ranked(city):
		if float(entry["influence"]["total"]) >= VOICE_INFLUENCE:
			voices.append(entry["household"])
	return voices

# --- The Speaker ------------------------------------------------------------------------------

static func get_speaker(city: City) -> Household:
	return city.social.find(city.social.speaker_id) if city.social.speaker_id >= 0 else null

static func can_appoint(city: City) -> bool:
	return is_on(city) and city.settlement.stage >= SettlementStage.VILLAGE

static func get_candidates(city: City) -> Array[Household]:
	var candidates: Array[Household] = []
	for entry: Dictionary in get_ranked(city):
		candidates.append(entry["household"])
	return candidates

# The Elder appoints a Speaker (or replaces the one in office). Everyone judges it.
static func appoint(city: City, chosen: Household) -> bool:
	if not can_appoint(city) or chosen == null or not city.households.has(chosen):
		return false
	var social: TownSocial = city.social
	var former: Household = get_speaker(city)
	if former == chosen:
		return false
	var candidates: Array[Household] = get_candidates(city)
	if former != null:
		replace(city, former, chosen)
	social.speaker_id = chosen.id
	social.speaker_since = city.construction.day
	social.speaker_policy = ""
	social.speaker_record = {"favours_welcomed": 0, "favours_resented": 0, "mediations": 0, "mediated_settled": 0}
	social.speaker_start_trust.clear()
	social.speaker_verdicts.clear()
	social.speaker_history.append({"id": chosen.id, "from": city.construction.day, "to": -1, "ended": ""})
	social.appointments += 1
	var label: String = city.get_household_label(chosen.id)
	HouseholdMemory.experience(city, chosen, "honoured", "The Elder made it Speaker of the Gathering", null, {"benefit": 1, "category": TownSocial.RECOGNITION_CIVIC})
	for observer: Household in city.households:
		if observer == chosen:
			continue
		social.speaker_start_trust[str(observer.id)] = float(observer.trust) + observer.trust_progress
		var judged: Dictionary = judge_appointment(city, observer, chosen, candidates.has(observer))
		var score: float = float(judged["score"])
		social.speaker_verdicts[str(observer.id)] = score
		if score >= SUPPORT_AT:
			social.adjust_trust(observer, 0.5, "a Speaker it backs")
			social.note(observer, "Welcomes %s as Speaker (%s)" % [label, "; ".join(FamilyInitiative.get_reasons(judged["terms"], true))])
		elif score <= DOUBT_AT:
			social.adjust_trust(observer, -1.0 if score <= OPPOSE_AT else -0.5, "a Speaker it doubts")
			if score <= OPPOSE_AT:
				HouseholdMemory.touch_tie(city, observer, chosen, -1, "was raised over us")
			social.note(observer, "%s %s as Speaker (%s)" % ["Opposes" if score <= OPPOSE_AT else "Doubts", label, "; ".join(FamilyInitiative.get_reasons(judged["terms"], false))])
	update_stance(city)
	return true

# How one household takes a household's appointment: {"score", "terms"}.
static func judge_appointment(city: City, observer: Household, chosen: Household, was_candidate: bool) -> Dictionary:
	var terms: Array = []
	var s: Callable = func(value_id: String) -> int: return HouseholdCharacter.get_strength(observer, value_id)
	var disposition: int = HouseholdMemory.get_disposition(observer, chosen.id)
	if disposition != 0:
		FamilyInitiative.add(terms, 0.5 * disposition, "they are on good terms" if disposition > 0 else "they are on bad terms")
	if HouseholdMemory.is_kin(observer, chosen):
		FamilyInitiative.add(terms, 0.5, "they are kin")
	var shared: int = 0
	var opposed: int = 0
	var theirs: Array[String] = HouseholdCharacter.get_held_values(chosen)
	for value_id: String in HouseholdCharacter.get_held_values(observer):
		if theirs.has(value_id):
			shared += 1
		elif theirs.has(HouseholdCharacter.get_opposite(value_id)):
			opposed += 1
	if shared > 0:
		FamilyInitiative.add(terms, minf(1.0, 0.25 * shared), "they hold to the same things")
	if opposed > 0:
		FamilyInitiative.add(terms, -minf(1.0, 0.25 * opposed), "they hold to the opposite")
	var priority: String = city.influence.priority
	if priority != "" and priority != CommunityPriority.NONE:
		var mine: String = CommunityPriority.get_view(city, observer, priority)["stance"]
		var theirs_stance: String = CommunityPriority.get_view(city, chosen, priority)["stance"]
		if mine != CommunityPriority.INDIFFERENT and theirs_stance != CommunityPriority.INDIFFERENT:
			FamilyInitiative.add(terms, 0.5 if mine == theirs_stance else -0.5, "they see the community's priority alike" if mine == theirs_stance else "they see the community's priority differently")
	for wisdom: String in city.social.wisdoms:
		var mine_w: String = GuidingWisdom.get_view(observer, wisdom)["stance"]
		var theirs_w: String = GuidingWisdom.get_view(chosen, wisdom)["stance"]
		if mine_w != GuidingWisdom.INDIFFERENT and theirs_w != GuidingWisdom.INDIFFERENT:
			FamilyInitiative.add(terms, 0.25 if mine_w == theirs_w else -0.25, "they take %s alike" % GuidingWisdom.NAMES[wisdom] if mine_w == theirs_w else "they take %s differently" % GuidingWisdom.NAMES[wisdom])
	if s.call("deferential") > 0:
		FamilyInitiative.add(terms, 0.25 * s.call("deferential"), "it accepts the Elder's choice")
	if s.call("self_governing") > 0:
		FamilyInitiative.add(terms, -0.25 * s.call("self_governing"), "it wants no one speaking for it")
	if s.call("egalitarian") > 0 and chosen.standing >= TownSocial.VOICE_STANDING:
		FamilyInitiative.add(terms, -0.25 * s.call("egalitarian"), "power gathers in the already regarded")
	if s.call("hierarchical") > 0:
		FamilyInitiative.add(terms, 0.25 * s.call("hierarchical"), "the accomplished should lead")
	var ambition: int = HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION)
	if was_candidate and ambition > 0:
		FamilyInitiative.add(terms, -0.5 * ambition, "it wanted the office itself")
	var score: float = FamilyInitiative.sum(terms) + FamilyInitiative.get_noise(city, observer, "speaker:%d" % chosen.id)
	return {"score": score, "terms": terms}

# The Elder replaces a sitting Speaker. What follows depends on the circumstances: how the former
# Speaker takes it (its temperament, ambition, following and record), and how each family judges
# the removal (its ties to the former Speaker, and whether things went well for it under it).
static func replace(city: City, former: Household, chosen: Household) -> void:
	var social: TownSocial = city.social
	social.replacements += 1
	var label: String = city.get_household_label(former.id)
	close_term(city, "replaced")
	var parts: Dictionary = get_influence(city, former)
	var record: Dictionary = social.speaker_record
	var terms: Array = []
	var ambition: int = HouseholdCharacter.get_axis(former, HouseholdCharacter.AMBITION)
	if ambition != 0:
		FamilyInitiative.add(terms, -0.5 * ambition, "it wanted to keep the office" if ambition > 0 else "it never sought the office")
	var assertive: int = HouseholdCharacter.get_axis(former, HouseholdCharacter.ASSERTIVENESS)
	if assertive != 0:
		FamilyInitiative.add(terms, -0.25 * assertive, "it does not let a slight pass" if assertive > 0 else "it lets things go")
	var backers: int = (parts["supporters"] as Array).size()
	var critics: int = (parts["detractors"] as Array).size()
	if backers >= 3 and backers > critics:
		FamilyInitiative.add(terms, -0.5, "families stood behind it")
	if former.standing >= TownSocial.VOICE_STANDING:
		FamilyInitiative.add(terms, -0.5, "it was well regarded")
	if critics > backers or int(record.get("favours_resented", 0)) > int(record.get("favours_welcomed", 0)):
		FamilyInitiative.add(terms, 1.0, "it knew it had lost the town's confidence")
	var to_new: int = HouseholdMemory.get_disposition(former, chosen.id)
	if to_new != 0:
		FamilyInitiative.add(terms, 0.5 * to_new, "it thinks well of its successor" if to_new > 0 else "it thinks ill of its successor")
	var score: float = FamilyInitiative.sum(terms) + FamilyInitiative.get_noise(city, former, "replaced:%d" % chosen.id)
	var successor: String = city.get_household_label(chosen.id)
	if score <= -2.0:
		social.adjust_trust(former, -1.0, "removed as Speaker")
		HouseholdMemory.touch_tie(city, former, chosen, -2, "took the office from us", 0, "took its office")
		social.former_speaker_responses["aggrieved"] = int(social.former_speaker_responses.get("aggrieved", 0)) + 1
		social.note(former, "Will not forgive its removal as Speaker (%s)" % "; ".join(FamilyInitiative.get_reasons(terms, false)))
	elif score <= -1.0:
		social.adjust_trust(former, -0.5, "removed as Speaker")
		HouseholdMemory.touch_tie(city, former, chosen, -1, "took the office from us")
		social.former_speaker_responses["resentful"] = int(social.former_speaker_responses.get("resentful", 0)) + 1
		social.note(former, "Resents its removal as Speaker (%s)" % "; ".join(FamilyInitiative.get_reasons(terms, false)))
	else:
		social.former_speaker_responses["accepting"] = int(social.former_speaker_responses.get("accepting", 0)) + 1
		social.note(former, "Stepped down as Speaker for %s (%s)" % [successor, "; ".join(FamilyInitiative.get_reasons(terms, true))])
	HouseholdMemory.experience(city, former, "honour_unfair" if score <= -1.0 else "honoured", "The Elder replaced it as Speaker with %s" % successor, chosen, {"fair": -1 if score <= -1.0 else 0, "category": TownSocial.RECOGNITION_CIVIC})
	# Each family judges the removal.
	for observer: Household in city.households:
		if observer == former:
			continue
		var t: Array = []
		var disposition: int = HouseholdMemory.get_disposition(observer, former.id)
		if disposition != 0:
			FamilyInitiative.add(t, -0.5 * disposition, "it respected the former Speaker" if disposition > 0 else "it was glad to see it go")
		var start: float = float(social.speaker_start_trust.get(str(observer.id), float(observer.trust)))
		var change: float = float(observer.trust) + observer.trust_progress - start
		if absf(change) >= 0.5:
			FamilyInitiative.add(t, clampf(-0.5 * change, -1.0, 1.0), "things went well for it under that Speaker" if change > 0.0 else "things went badly for it under that Speaker")
		var verdict: float = float(social.speaker_verdicts.get(str(observer.id), 0.0))
		if verdict <= DOUBT_AT:
			FamilyInitiative.add(t, 0.5, "it never wanted that Speaker")
		var judged: float = FamilyInitiative.sum(t) + FamilyInitiative.get_noise(city, observer, "removal:%d" % former.id)
		if judged >= 1.0:
			social.adjust_trust(observer, 0.5, "an unsuccessful Speaker replaced")
			social.removal_approved += 1
		elif judged <= -1.0:
			social.adjust_trust(observer, -0.5, "a respected Speaker removed")
			social.removal_opposed += 1
			if judged <= -1.5:
				HouseholdMemory.touch_tie(city, observer, chosen, -1, "took a respected family's place")

static func close_term(city: City, why: String) -> void:
	var social: TownSocial = city.social
	if not social.speaker_history.is_empty():
		var term: Dictionary = social.speaker_history[-1]
		if int(term["to"]) < 0:
			term["to"] = city.construction.day
			term["ended"] = why
			term["record"] = social.speaker_record.duplicate()
			term["policies"] = social.speaker_policies.duplicate()
	social.speaker_policies.clear()

# A Speaker who leaves the town or passes on leaves the office empty.
static func check_speaker(city: City) -> void:
	var social: TownSocial = city.social
	if social.speaker_id >= 0 and social.find(social.speaker_id) == null:
		close_term(city, "left")
		social.speaker_id = -1
		social.speaker_policy = ""
		social.vacancies += 1

# Weekly (TownSocial.run_week): how the Speaker itself sees the community's priority.
static func update_stance(city: City) -> void:
	var speaker: Household = get_speaker(city)
	var priority: String = city.influence.priority
	if speaker == null or priority == "" or priority == CommunityPriority.NONE:
		city.social.speaker_stance = ""
		return
	city.social.speaker_stance = CommunityPriority.get_view(city, speaker, priority)["stance"]

# How far a household follows the Speaker's lead: 1 if it backs the Speaker, -0.5 if it opposes it
# (it takes the other side), 0 otherwise; by its tie to the Speaker, else its view when appointed.
static func get_lead(city: City, household: Household) -> float:
	var speaker: Household = get_speaker(city)
	if speaker == null or speaker == household or not is_on(city):
		return 0.0
	var disposition: int = HouseholdMemory.get_disposition(household, speaker.id)
	var verdict: float = float(city.social.speaker_verdicts.get(str(household.id), 0.0))
	if disposition > 0 or (disposition == 0 and verdict >= SUPPORT_AT):
		return 1.0
	if disposition < 0 or (disposition == 0 and verdict <= DOUBT_AT):
		return -0.5
	return 0.0

# The Speaker's stance on the community's priority as a sign: 1 for, -1 against, 0 neither.
static func get_stance_sign(city: City) -> float:
	match city.social.speaker_stance:
		CommunityPriority.SUPPORTS:
			return 1.0
		CommunityPriority.OPPOSES:
			return -1.0
	return 0.0

# The Speaker's lead in a family's view of the community's priority (CommunityPriority.get_view).
static func add_lead_to_view(city: City, household: Household, terms: Array) -> void:
	var lead: float = get_lead(city, household)
	var sign: float = get_stance_sign(city)
	if lead == 0.0 or sign == 0.0:
		return
	var weight: float = LEAD_VIEW_WEIGHT * lead * sign
	var speaker: String = city.get_household_label(city.social.speaker_id)
	if lead > 0.0:
		FamilyInitiative.add(terms, weight, ("the Speaker, %s, backs it" if sign > 0.0 else "the Speaker, %s, speaks against it") % speaker)
	else:
		FamilyInitiative.add(terms, weight, ("the Speaker it opposes, %s, backs it" if sign > 0.0 else "the Speaker it opposes, %s, is against it") % speaker)

# The same lead in how readily a family heeds the priority's appeals (FamilyInitiative.get_receptiveness).
static func get_lead_receptiveness(city: City, household: Household) -> Dictionary:
	var lead: float = get_lead(city, household)
	var sign: float = get_stance_sign(city)
	if lead == 0.0 or sign == 0.0:
		return {"factor": 0.0, "note": ""}
	var factor: float = LEAD_RECEPTIVE_WEIGHT * lead * sign
	var note: String = ""
	if lead > 0.0:
		note = ", and the Speaker backs it" if sign > 0.0 else ", though the Speaker is against it"
	else:
		note = ", though the Speaker it opposes backs it" if sign > 0.0 else ", and the Speaker it opposes is against it"
	return {"factor": factor, "note": note}

# --- The Speaker's acts -----------------------------------------------------------------------

# Every season the Speaker decides, by its own values and ties, who gets first claim on the stores.
static func speaker_acts(city: City) -> void:
	var speaker: Household = get_speaker(city)
	if speaker == null:
		return
	var social: TownSocial = city.social
	var choice: Dictionary = choose_policy(city, speaker)
	var policy: String = str(choice["policy"])
	social.speaker_policy = policy
	social.speaker_policy_note = "%s %s (%s)" % [city.get_household_label(speaker.id), POLICY_TEXT[policy], "; ".join(FamilyInitiative.get_reasons(choice["terms"], true))]
	social.speaker_policies[policy] = int(social.speaker_policies.get(policy, 0)) + 1
	social.speaker_policy_counts[policy] = int(social.speaker_policy_counts.get(policy, 0)) + 1
	social.incentive = policy == POLICY_HELPERS
	var recipients: Array[Household] = []
	if policy == POLICY_NEEDY:
		var needy: Array[Household] = []
		for household: Household in city.households:
			if household != speaker and TownSocial.is_in_need(city, household):
				needy.append(household)
		needy.sort_custom(func(a: Household, b: Household) -> bool: return TownSocial.get_security_margin(a) < TownSocial.get_security_margin(b) or (TownSocial.get_security_margin(a) == TownSocial.get_security_margin(b) and a.id < b.id))
		recipients = needy.slice(0, GRANTS_PER_SEASON)
	elif policy == POLICY_OWN:
		var own: Array[Household] = []
		for household: Household in city.households:
			if household != speaker and (HouseholdMemory.get_disposition(speaker, household.id) > 0 or HouseholdMemory.is_kin(speaker, household)):
				own.append(household)
		own.sort_custom(func(a: Household, b: Household) -> bool: return HouseholdMemory.get_disposition(speaker, a.id) > HouseholdMemory.get_disposition(speaker, b.id) or (HouseholdMemory.get_disposition(speaker, a.id) == HouseholdMemory.get_disposition(speaker, b.id) and a.id < b.id))
		recipients = own.slice(0, GRANTS_PER_SEASON)
	for recipient: Household in recipients:
		social.speaker_grants[policy] = int(social.speaker_grants.get(policy, 0)) + 1
		recipient.grants_received += 1
		social.grant_first_claim(recipient, TownSocial.GRANT_DAYS)
		HouseholdMemory.touch_tie(city, recipient, speaker, 1, "the Speaker gave us first claim")
		social.judge_distribution(recipient, "The Speaker, %s, gave %s first claim on the stores" % [city.get_household_label(speaker.id), city.get_household_label(recipient.id)], speaker)

# The Speaker's choice: {"policy", "terms"}, its own reasons for each weighed against the others.
static func choose_policy(city: City, speaker: Household) -> Dictionary:
	var s: Callable = func(value_id: String) -> float: return float(HouseholdCharacter.get_strength(speaker, value_id))
	var options: Dictionary = {}
	var helpers: Array = []
	FamilyInitiative.add(helpers, 0.5 * TownSocial.get_esteem(speaker, TownSocial.RECOGNITION_SERVICE), "it prizes service")
	FamilyInitiative.add(helpers, 0.5 * s.call("mutual_aid") + 0.25 * s.call("communal_labor"), "it holds that help should be returned")
	options[POLICY_HELPERS] = helpers
	var needy: Array = []
	var in_need: int = city.households.filter(func(h: Household) -> bool: return h != speaker and TownSocial.is_in_need(city, h)).size()
	FamilyInitiative.add(needy, 0.75 * s.call("charitable") + 0.5 * maxf(0.0, float(HouseholdCharacter.get_axis(speaker, HouseholdCharacter.EMPATHY))) + 0.25 * s.call("sharing"), "it is moved by others' need")
	FamilyInitiative.add(needy, 1.0 if in_need > 0 else -1.0, "families are in hardship" if in_need > 0 else "no family is in hardship")
	options[POLICY_NEEDY] = needy
	var own: Array = []
	var friends: int = speaker.ties.filter(func(tie: Dictionary) -> bool: return int(tie["disposition"]) > 0).size()
	FamilyInitiative.add(own, 0.75 * s.call("acquisitive") + 0.25 * maxf(0.0, float(HouseholdCharacter.get_axis(speaker, HouseholdCharacter.AMBITION))) + 0.25 * s.call("private_holdings"), "it looks after its own")
	FamilyInitiative.add(own, minf(1.0, 0.25 * friends) if friends > 0 else -1.0, "it has kin and friends to favour" if friends > 0 else "it has no one to favour")
	FamilyInitiative.add(own, -0.5 * s.call("honesty") - 0.5 * s.call("egalitarian") - 0.25 * s.call("lawful"), "it would not play favourites")
	options[POLICY_OWN] = own
	var none: Array = []
	FamilyInitiative.add(none, 0.5, "the Elder's rules are enough")
	FamilyInitiative.add(none, 0.25 * s.call("self_governing") + 0.25 * s.call("each_to_their_own") + 0.25 * s.call("lawful"), "it holds that families should fend for themselves")
	options[POLICY_NONE] = none
	var best: String = POLICY_NONE
	var best_score: float = -INF
	for policy: String in [POLICY_HELPERS, POLICY_NEEDY, POLICY_OWN, POLICY_NONE]:
		var score: float = FamilyInitiative.sum(options[policy]) + FamilyInitiative.get_noise(city, speaker, "policy:" + policy)
		if score > best_score:
			best_score = score
			best = policy
	return {"policy": best, "terms": (options[best] as Array).filter(func(term: Dictionary) -> bool: return absf(float(term["weight"])) > 0.001)}

# A dispute between two households: the Speaker, if it is neither and values settling things, urges
# amends; the crossing family heeds it by its tie to the Speaker (TownSocial.press_claim).
static func add_mediation(city: City, crosser: Household, victim: Household, terms: Array) -> bool:
	var speaker: Household = get_speaker(city)
	if speaker == null or speaker == crosser or speaker == victim or not is_on(city):
		return false
	if TownSocial.get_esteem(speaker, TownSocial.RECOGNITION_CIVIC) < 0.0:
		return false
	var lead: float = get_lead(city, crosser)
	city.social.speaker_record["mediations"] = int(city.social.speaker_record.get("mediations", 0)) + 1
	city.social.mediations += 1
	if lead == 0.0:
		FamilyInitiative.add(terms, MEDIATION_WEIGHT * 0.5, "the Speaker urges amends")
	else:
		FamilyInitiative.add(terms, MEDIATION_WEIGHT * lead * 2.0, "the Speaker it respects urges amends" if lead > 0.0 else "it will not be told by a Speaker it opposes")
	return true

# The Speaker settled a quarrel: both sides think better of it if they value settling things.
static func on_mediated_settlement(city: City, parties: Array[Household]) -> void:
	var speaker: Household = get_speaker(city)
	if speaker == null:
		return
	city.social.speaker_record["mediated_settled"] = int(city.social.speaker_record.get("mediated_settled", 0)) + 1
	city.social.mediated_settled += 1
	for household: Household in parties:
		if TownSocial.get_procedure_regard(household) >= 0:
			HouseholdMemory.touch_tie(city, household, speaker, 1, "the Speaker settled our quarrel")
