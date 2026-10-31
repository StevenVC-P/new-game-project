class_name GuidingWisdom
extends RefCounted

# The founding town's guiding wisdom (docs/GUIDING_WISDOM.md): what the community holds to over
# generations, as its leader sets it. The town holds the wisdoms; each family answers them by its
# own lights. A wisdom grants nothing directly. It works only through what families already do:
#
# - It is what the gathering asks of families: each wisdom is one social expectation (TownSocial
#   norms; helping neighbours and respecting claims are two of them), and choosing it promotes that
#   expectation, the existing appeal in the decisions it concerns (SocialDecisions.add_norm). No
#   other weight is added. The two expectations the wisdoms add (keeping something back, doing
#   work well) are weighed only while their wisdom is held, so a town without one plays as before.
# - It frames what families learn: a lesson that bears the town's wisdom out is drawn a little more
#   readily (WISDOM_LESSON_SUPPORT, as if the family held the value mildly), but only from what the
#   family experienced and did (HouseholdMemory.experience).
# - Each family's conduct at those decisions is counted (record), and at most once a season it
#   becomes an experience of its own: having lived by the wisdom, or gone its own way. Either can
#   teach: families who follow it grow its qualities; families who refuse it grow other ones
#   (counter-qualities), each of which matters in later decisions. Values still move one level a
#   year at most (HouseholdMemory.add_evidence).
#
# Leadership: the Expedition Leader holds two wisdoms; when the town becomes a Village
# (SettlementStage) the leader is an Elder, with a third. Choices are fixed in this prototype.

const ENDURE: String = "endure_together"
const RESPECT: String = "respect_what_others_build"
const PREPARE: String = "prepare_for_hard_times"
const PRIDE: String = "pride_in_work"
const ALL: Array[String] = [ENDURE, RESPECT, PREPARE, PRIDE]
const NAMES: Dictionary = {ENDURE: "We Endure Together", RESPECT: "Respect What Others Build", PREPARE: "Prepare for Hard Times", PRIDE: "Take Pride in Your Work"}
const MEANINGS: Dictionary = {
	ENDURE: "Mutual help, sharing and shared responsibility: families give time to neighbours in need and share in a shortage.",
	RESPECT: "Property, boundaries and what each family achieves: families make amends for harm to others' fields and do not press for land others hold.",
	PREPARE: "Caution and readiness for shortage: families keep something back rather than give it away, hold off spending the stores as winter nears, and take up food work as stores run low.",
	PRIDE: "Craft and diligence: families improve their work into proper workplaces and put long days into their own building.",
}
# The expectation each wisdom is (TownSocial norms).
const NORMS: Dictionary = {ENDURE: TownSocial.NORM_HELP, RESPECT: TownSocial.NORM_CLAIMS, PREPARE: TownSocial.NORM_PREPARE, PRIDE: TownSocial.NORM_PRIDE}
# What following a wisdom tends to grow, and what refusing it tends to grow instead. Every value
# here is read by some decision (thrifty: sharing; fatalistic and hopeful: improving and how much
# hardship a family bears; perfectionist and expedient: their existing output effects).
const QUALITIES: Dictionary = {ENDURE: ["mutual_aid", "communal_labor"], RESPECT: ["respect_for_holdings", "private_holdings"], PREPARE: ["thrifty", "fatalistic"], PRIDE: ["perfectionist", "keepers_of_craft"]}
const COUNTER_QUALITIES: Dictionary = {ENDURE: ["self_governing", "solitary"], RESPECT: ["common_stores", "sharing"], PREPARE: ["hopeful"], PRIDE: ["expedient"]}

const EXPEDITION_LEADER: String = "Expedition Leader"
const ELDER: String = "Elder"
const LEADER_SLOTS: int = 2
const ELDER_SLOTS: int = 3
# A lesson that bears out the town's wisdom: as if the family held the value at strength 1 (owner,
# 2026-10-31). Lessons' value terms run 0.3-0.6 a level; this is their middle.
const WISDOM_LESSON_SUPPORT: float = 0.5
# Conduct becomes an experience when a family has met a wisdom's choice this often, at most once
# a season for each wisdom.
const LESSON_MIN_ACTS: int = 2
const LESSON_INTERVAL_DAYS: int = 90
const SUPPORT_AT: float = 1.0
const RESERVE_AT: float = -1.0
const SUPPORTS: String = "supports"
const INDIFFERENT: String = "does not much mind"
const RESERVED: String = "has reservations"

# --- Leadership and choice --------------------------------------------------------------------

static func get_title(city: City) -> String:
	return ELDER if city.settlement.stage >= SettlementStage.VILLAGE else EXPEDITION_LEADER

static func get_slots(city: City) -> int:
	return ELDER_SLOTS if get_title(city) == ELDER else LEADER_SLOTS

static func is_active(city: City, wisdom: String) -> bool:
	return city.social.wisdoms.has(wisdom)

static func can_choose(city: City, wisdom: String) -> bool:
	return ALL.has(wisdom) and not is_active(city, wisdom) and city.social.wisdoms.size() < get_slots(city)

# Adopts a wisdom while a slot is free; it stays (owner, 2026-10-31: fixed in this prototype).
static func choose(city: City, wisdom: String) -> bool:
	if not can_choose(city, wisdom):
		return false
	city.social.wisdoms.append(wisdom)
	city.social.wisdom_days[wisdom] = city.construction.day
	city.social.ensure_norms()
	city.social.norms[NORMS[wisdom]]["promoted"] = true
	return true

# A town saved when the gathering asked for helping or for respecting claims directly holds those
# asks as its wisdoms, up to the leader's slots, so its culture carries over.
static func adopt_earlier_asks(city: City) -> void:
	if not city.social.wisdoms.is_empty():
		return
	for wisdom: String in [ENDURE, RESPECT]:
		if bool(city.social.norms[NORMS[wisdom]].get("promoted", false)):
			city.social.wisdoms.append(wisdom)
			city.social.wisdom_days[wisdom] = city.construction.day

# --- In families' decisions ---------------------------------------------------------------------

# The appeal of a wisdom's expectation in a decision (`toward` -1 when keeping to it means not
# doing what is weighed), only while the town holds the wisdom. Returns the weight added.
static func add_appeal(city: City, household: Household, wisdom: String, terms: Array, toward: float = 1.0) -> float:
	if not city.social.enabled or not is_active(city, wisdom):
		return 0.0
	var before: float = FamilyInitiative.sum(terms)
	SocialDecisions.add_norm(city, household, NORMS[wisdom], terms, toward)
	return FamilyInitiative.sum(terms) - before

# Whether hard times are near enough for Prepare for Hard Times to ask families to hold off
# spending the stores: autumn and winter, or under three months of food.
static func are_hard_times_near(city: City) -> bool:
	return city.get_season_index() >= 2 or FamilyInitiative.get_food_days(city) < 90.0

# Whether the town's food is short enough for Prepare for Hard Times to ask a family choosing its
# work to take up food work.
static func is_food_short(city: City) -> bool:
	return FamilyInitiative.get_food_ratio(city) < 1.25 or FamilyInitiative.get_food_days(city) < 90.0

# A family met a choice a held wisdom concerns, and kept to it or not. Counted toward its own
# experience of the wisdom (review), and, for the two expectations the wisdoms add, toward how far
# the town's families keep to it (TownSocial.observe_norm; helping and claims are observed where
# they always were).
static func record(city: City, household: Household, wisdom: String, followed: bool) -> void:
	if not city.social.enabled or not is_active(city, wisdom):
		return
	var conduct: Array = household.wisdom_conduct.get(wisdom, [0, 0])
	conduct[0 if followed else 1] = int(conduct[0 if followed else 1]) + 1
	household.wisdom_conduct[wisdom] = conduct
	var counts: Dictionary = city.social.wisdom_record.get(wisdom, {"followed": 0, "declined": 0, "lived": 0, "own_way": 0})
	counts["followed" if followed else "declined"] = int(counts["followed" if followed else "declined"]) + 1
	city.social.wisdom_record[wisdom] = counts
	if wisdom == PREPARE or wisdom == PRIDE:
		city.social.observe_norm(NORMS[wisdom], followed)

# Monthly (TownSocial.review_month): each family's conduct toward each held wisdom, once there is
# enough of it and a season has passed since the last, becomes an experience it draws lessons from.
static func review(city: City) -> void:
	if city.social.wisdoms.is_empty():
		return
	var today: int = city.construction.day
	for household: Household in city.households:
		for wisdom: String in city.social.wisdoms:
			var conduct: Array = household.wisdom_conduct.get(wisdom, [0, 0])
			var acts: int = int(conduct[0]) + int(conduct[1])
			if acts < LESSON_MIN_ACTS or today - int(household.wisdom_lesson_day.get(wisdom, -LESSON_INTERVAL_DAYS)) < LESSON_INTERVAL_DAYS:
				continue
			var followed: bool = int(conduct[0]) >= int(conduct[1])
			var text: String = ("It lived by %s" if followed else "It went its own way rather than %s") % ("'" + NAMES[wisdom] + "'" if followed else SHORT_ASKS[wisdom])
			HouseholdMemory.experience(city, household, "wisdom", text, null, {"wisdom": wisdom, "followed": followed})
			household.wisdom_conduct[wisdom] = [0, 0]
			household.wisdom_lesson_day[wisdom] = today
			var counts: Dictionary = city.social.wisdom_record.get(wisdom, {"followed": 0, "declined": 0, "lived": 0, "own_way": 0})
			counts["lived" if followed else "own_way"] = int(counts["lived" if followed else "own_way"]) + 1
			city.social.wisdom_record[wisdom] = counts

const SHORT_ASKS: Dictionary = {ENDURE: "give to its neighbours", RESPECT: "defer to others' claims", PREPARE: "keep something back", PRIDE: "put its effort into its work"}

# --- What families learn --------------------------------------------------------------------------

# Whether a lesson bears out a wisdom the town holds (HouseholdMemory.experience adds
# WISDOM_LESSON_SUPPORT to it).
static func frames(city: City, value_id: String, direction: int) -> bool:
	if direction <= 0 or value_id == "" or city.social.wisdoms.is_empty():
		return false
	for wisdom: String in city.social.wisdoms:
		if (QUALITIES[wisdom] as Array).has(value_id):
			return true
	return false

# The lessons a family may draw from a season of living by a wisdom (followed) or going its own
# way, each supported by its temperament and convictions, as every experience's are.
static func get_lessons(household: Household, wisdom: String, followed: bool) -> Array[Dictionary]:
	var lessons: Array[Dictionary] = []
	var a: Callable = func(axis: String) -> float: return float(HouseholdCharacter.get_axis(household, axis))
	var s: Callable = func(value_id: String) -> float: return float(HouseholdCharacter.get_strength(household, value_id))
	var empathy: float = a.call(HouseholdCharacter.EMPATHY)
	var sociability: float = a.call(HouseholdCharacter.SOCIABILITY)
	var ambition: float = a.call(HouseholdCharacter.AMBITION)
	var assertiveness: float = a.call(HouseholdCharacter.ASSERTIVENESS)
	var diligence: float = a.call(HouseholdCharacter.DILIGENCE)
	var risk: float = a.call(HouseholdCharacter.RISK)
	match [wisdom, followed]:
		[ENDURE, true]:
			lessons.append(HouseholdMemory.lesson("we endure together", "mutual_aid", 1, 0.6 + 0.4 * empathy + 0.3 * sociability + 0.4 * s.call("mutual_aid")))
			lessons.append(HouseholdMemory.lesson("working together builds the town", "communal_labor", 1, 0.4 + 0.3 * sociability + 0.3 * diligence + 0.4 * s.call("communal_labor")))
			lessons.append(HouseholdMemory.lesson("our own work waits while we help", "solitary", 1, 0.1 - 0.4 * sociability + 0.3 * ambition + 0.5 * s.call("solitary") + 0.3 * s.call("private_holdings")))
		[ENDURE, false]:
			lessons.append(HouseholdMemory.lesson("each family must stand on its own", "self_governing", 1, 0.4 + 0.4 * assertiveness + 0.3 * ambition + 0.5 * s.call("self_governing") - 0.3 * empathy))
			lessons.append(HouseholdMemory.lesson("our own work comes first", "solitary", 1, 0.3 - 0.3 * sociability + 0.5 * s.call("solitary")))
			lessons.append(HouseholdMemory.lesson("we should have done more for them", "mutual_aid", 1, 0.1 + 0.5 * empathy + 0.4 * s.call("mutual_aid")))
		[RESPECT, true]:
			lessons.append(HouseholdMemory.lesson("what a family builds is its own", "respect_for_holdings", 1, 0.6 - 0.2 * assertiveness + 0.4 * s.call("respect_for_holdings") + 0.3 * s.call("private_holdings")))
			lessons.append(HouseholdMemory.lesson("a family should build up what is its own", "private_holdings", 1, 0.3 + 0.4 * ambition + 0.5 * s.call("private_holdings")))
			lessons.append(HouseholdMemory.lesson("land should serve those who need it", "common_stores", 1, 0.1 + 0.4 * empathy + 0.4 * s.call("common_stores")))
		[RESPECT, false]:
			lessons.append(HouseholdMemory.lesson("land should serve whoever works it", "common_stores", 1, 0.4 + 0.3 * assertiveness + 0.4 * s.call("common_stores") + 0.3 * s.call("sharing")))
			lessons.append(HouseholdMemory.lesson("what is shared is no one's loss", "sharing", 1, 0.3 + 0.4 * empathy + 0.4 * s.call("sharing")))
			lessons.append(HouseholdMemory.lesson("we wronged them", "respect_for_holdings", 1, 0.1 + 0.4 * empathy - 0.3 * assertiveness + 0.4 * s.call("respect_for_holdings")))
		[PREPARE, true]:
			lessons.append(HouseholdMemory.lesson("a family must keep something back", "thrifty", 1, 0.5 - 0.4 * risk + 0.4 * s.call("thrifty")))
			lessons.append(HouseholdMemory.lesson("hard times always come", "fatalistic", 1, 0.2 - 0.3 * risk - 0.2 * ambition + 0.5 * s.call("fatalistic") - 0.4 * s.call("hopeful")))
			lessons.append(HouseholdMemory.lesson("we held back when others needed it", "charitable", 1, 0.1 + 0.4 * empathy + 0.3 * s.call("charitable")))
		[PREPARE, false]:
			lessons.append(HouseholdMemory.lesson("what is stored does no good unused", "hopeful", 1, 0.4 + 0.4 * risk + 0.3 * ambition + 0.5 * s.call("hopeful") - 0.4 * s.call("fatalistic")))
			lessons.append(HouseholdMemory.lesson("we were careless with what we had", "thrifty", 1, 0.1 - 0.3 * risk + 0.4 * s.call("thrifty")))
		[PRIDE, true]:
			lessons.append(HouseholdMemory.lesson("work done well is worth the effort", "perfectionist", 1, 0.4 + 0.4 * diligence + 0.4 * s.call("perfectionist")))
			lessons.append(HouseholdMemory.lesson("good craft deserves its due", "keepers_of_craft", 1, 0.4 + 0.3 * ambition + 0.4 * s.call("keepers_of_craft")))
			lessons.append(HouseholdMemory.lesson("the work never ends", "", 0, 0.1 - 0.4 * diligence))
		[PRIDE, false]:
			lessons.append(HouseholdMemory.lesson("good enough feeds us", "expedient", 1, 0.4 - 0.3 * diligence + 0.3 * risk + 0.5 * s.call("expedient")))
			lessons.append(HouseholdMemory.lesson("we should take more care", "perfectionist", 1, 0.1 + 0.4 * diligence + 0.3 * s.call("perfectionist")))
	return lessons

# --- Families' views -------------------------------------------------------------------------------

# How a family takes a wisdom: {"score", "terms", "stance"}, in its own words, from its convictions
# and temperament. It only describes; families answer a wisdom in their decisions.
static func get_view(household: Household, wisdom: String) -> Dictionary:
	var terms: Array = []
	var s: Callable = func(value_id: String) -> int: return HouseholdCharacter.get_strength(household, value_id)
	var value: Callable = func(value_id: String, weight: float, reason: String) -> void:
		if s.call(value_id) > 0:
			FamilyInitiative.add(terms, weight * s.call(value_id), reason)
	var axis: Callable = func(axis_id: String, weight: float, high: String, low: String) -> void:
		var level: int = HouseholdCharacter.get_axis(household, axis_id)
		if level != 0:
			FamilyInitiative.add(terms, weight * level, high if level > 0 else low)
	match wisdom:
		ENDURE:
			value.call("mutual_aid", 1.0, "it believes neighbours should help one another")
			value.call("communal_labor", 0.75, "it values working together")
			value.call("charitable", 0.5, "it is charitable")
			value.call("self_governing", -1.0, "it holds that each family should look after itself")
			value.call("solitary", -0.75, "it prefers to work alone")
			value.call("acquisitive", -0.5, "it holds on to what it has")
			axis.call(HouseholdCharacter.EMPATHY, 0.5, "it is moved by others' hardship", "it is little moved by others' hardship")
		RESPECT:
			value.call("respect_for_holdings", 1.0, "it respects what others hold")
			value.call("private_holdings", 0.75, "it prizes its own holding")
			value.call("landholding", 0.5, "it values land of its own")
			value.call("common_stores", -1.0, "it holds that land and stores belong to all")
			value.call("sharing", -0.5, "it believes in sharing")
			axis.call(HouseholdCharacter.ASSERTIVENESS, -0.25, "it takes what it needs", "it gives way to others")
		PREPARE:
			value.call("thrifty", 1.0, "it is thrifty")
			value.call("fatalistic", 0.5, "it expects hard times")
			value.call("hopeful", -0.75, "it expects better times")
			value.call("lavish", -0.75, "it likes to enjoy what it has")
			axis.call(HouseholdCharacter.RISK, -0.5, "it is daring", "it is cautious")
		PRIDE:
			value.call("perfectionist", 1.0, "it takes care over its work")
			value.call("keepers_of_craft", 0.75, "it keeps a craft")
			value.call("expedient", -1.0, "it holds that good enough will do")
			axis.call(HouseholdCharacter.DILIGENCE, 0.5, "it is glad of work", "it guards its rest")
			axis.call(HouseholdCharacter.AMBITION, 0.25, "it wants to get on", "it is content as it is")
	var score: float = FamilyInitiative.sum(terms)
	var stance: String = SUPPORTS if score >= SUPPORT_AT else RESERVED if score <= RESERVE_AT else INDIFFERENT
	return {"score": score, "terms": terms, "stance": stance}

# --- Evidence ----------------------------------------------------------------------------------------

# Families now holding each of a wisdom's qualities and counter-qualities, and how many came to hold
# them more strongly since the town adopted it: {value: {"holders", "grown"}}.
static func get_qualities(city: City, wisdom: String) -> Dictionary:
	var since: int = int(city.social.wisdom_days.get(wisdom, 0))
	var result: Dictionary = {}
	for value_id: String in (QUALITIES[wisdom] as Array) + (COUNTER_QUALITIES[wisdom] as Array):
		var holders: int = 0
		var grown: int = 0
		for household: Household in city.households:
			holders += 1 if HouseholdCharacter.get_strength(household, value_id) > 0 else 0
			var key: String = "%d:%s" % [household.id, value_id]
			if int(household.value_changed_day.get(value_id, -1)) >= since and bool(city.social.value_change_directions.get(key, false)):
				grown += 1
		result[value_id] = {"holders": holders, "grown": grown}
	return result
