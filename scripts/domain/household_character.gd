class_name HouseholdCharacter
extends RefCounted

# A household's personality and the strength of its values (docs/HOUSEHOLD_SOCIAL_MODEL.md,
# Sections 2-3). One household, one will: a single personality and a single set of convictions.
#
# Personality is seven axes from -2 to +2, used in decisions and reactions, never as production
# bonuses. Values keep their twelve categories (CultureValues); each held value has a strength
# from 1 (mild) to 3 (defining), and conduct values (honesty, respect for holdings, ...) are added
# outside the original random draw, so existing towns, seeds, and balance runs are unchanged.
#
# Every rule here reads a household's profile, so a demographic group can later be described by a
# representative profile.

const RISK: String = "risk"
const AMBITION: String = "ambition"
const SOCIABILITY: String = "sociability"
const DILIGENCE: String = "diligence"
const OPENNESS: String = "openness"
const EMPATHY: String = "empathy"
const ASSERTIVENESS: String = "assertiveness"
const AXES: Array[String] = [RISK, AMBITION, SOCIABILITY, DILIGENCE, OPENNESS, EMPATHY, ASSERTIVENESS]

# Words for each end of an axis: [strong low, mild low, mild high, strong high].
const AXIS_WORDS: Dictionary = {
	RISK: ["very cautious", "cautious", "daring", "very daring"],
	AMBITION: ["content", "unhurried", "aspiring", "driven"],
	SOCIABILITY: ["very private", "private", "outgoing", "gregarious"],
	DILIGENCE: ["leisure-loving", "easygoing", "industrious", "tireless"],
	OPENNESS: ["set in its ways", "familiarity-seeking", "experimental", "restless for new ways"],
	EMPATHY: ["detached", "reserved", "attuned", "deeply attuned"],
	ASSERTIVENESS: ["yielding", "accommodating", "forceful", "combative"],
}

# Values that moved to personality: holding one sets the axis (owner directive, Section 2).
const MIGRATED_VALUES: Dictionary = {
	"daring": [RISK, 1], "cautious": [RISK, -1],
	"industrious": [DILIGENCE, 1], "leisurely": [DILIGENCE, -1],
}

# Conduct values added to existing categories, never drawn by CultureValues' random profile.
const CONDUCT_VALUES: Dictionary = {
	"honesty": CultureValues.CATEGORY_CONFLICT,
	"negotiation": CultureValues.CATEGORY_CONFLICT,
	"forgiveness": CultureValues.CATEGORY_CONFLICT,
	"vindication": CultureValues.CATEGORY_CONFLICT,
	"respect_for_holdings": CultureValues.CATEGORY_HOME_PLACE,
	"stewardship": CultureValues.CATEGORY_HOME_PLACE,
	"mutual_aid": CultureValues.CATEGORY_COMMUNITY,
}
const CONDUCT_OPPOSITES: Dictionary = {"forgiveness": "vindication", "vindication": "forgiveness"}
# Chance a founding household holds each conduct value (then at strength 1 or 2).
const CONDUCT_CHANCE: int = 45
const CONDUCT_NAMES: Dictionary = {
	"honesty": "Honesty", "negotiation": "Negotiation", "forgiveness": "Forgiveness", "vindication": "Vindication",
	"respect_for_holdings": "Respect for Holdings", "stewardship": "Stewardship", "mutual_aid": "Mutual Aid",
}
# How a strength reads.
const STRENGTH_WORDS: Array[String] = ["", "leans toward", "holds to", "is defined by"]

# Gives a household a personality and value strengths if it has none: inherited from the
# household it came from when that one has a character, else drawn for it (founders, newcomers).
static func ensure(city: City, household: Household) -> void:
	if not household.personality.is_empty():
		return
	var parents: Array[Household] = []
	for parent_id: int in [household.parent_household_id, household.second_parent_household_id]:
		var parent: Household = city.get_household_by_id(parent_id)
		if parent != null and not parent.personality.is_empty():
			parents.append(parent)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, household.id, "character"])
	if parents.is_empty():
		draw(household, rng)
	else:
		inherit(household, parents, rng)

# A founder's or newcomer's character: each axis mostly balanced, set by any migrated value it
# holds; 3-5 strong convictions, 1-2 of them defining.
static func draw(household: Household, rng: RandomNumberGenerator) -> void:
	for axis: String in AXES:
		household.personality[axis] = draw_axis(rng)
	for value_id: String in MIGRATED_VALUES.keys():
		if CultureValues.has_value(household.values, value_id):
			var axis: String = MIGRATED_VALUES[value_id][0]
			household.personality[axis] = int(MIGRATED_VALUES[value_id][1]) * rng.randi_range(1, 2)
	for value_id: String in CONDUCT_VALUES.keys():
		if rng.randi_range(0, 99) < CONDUCT_CHANCE and get_strength(household, str(CONDUCT_OPPOSITES.get(value_id, ""))) == 0:
			household.value_strengths[value_id] = 1
	var held: Array[String] = get_held_values(household)
	for value_id: String in held:
		if not household.value_strengths.has(value_id):
			household.value_strengths[value_id] = 1
	# Shuffle in a fixed way (the generator's draws), then make the first few strong.
	for i in range(held.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: String = held[i]
		held[i] = held[j]
		held[j] = swap
	var strong: int = rng.randi_range(3, 5)
	var defining: int = rng.randi_range(1, 2)
	for i in range(mini(strong, held.size())):
		household.value_strengths[held[i]] = 3 if i < defining else 2

static func draw_axis(rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi_range(0, 99)
	if roll < 10:
		return -2
	if roll < 30:
		return -1
	if roll < 70:
		return 0
	if roll < 90:
		return 1
	return 2

# A new household from one or two established lines: temperament averaged with a step of
# variation; each parent value strength kept or moved a level; values the parents lack and the
# new household holds (CultureValues inheritance fills gaps from the settlement) start mild.
static func inherit(household: Household, parents: Array[Household], rng: RandomNumberGenerator) -> void:
	for axis: String in AXES:
		var total: float = 0.0
		for parent: Household in parents:
			total += float(parent.personality.get(axis, 0))
		var roll: int = rng.randi_range(0, 99)
		var step: int = -1 if roll < 15 else 1 if roll >= 85 else 0
		household.personality[axis] = clampi(roundi(total / parents.size()) + step, -2, 2)
	for parent: Household in parents:
		for value_id: String in parent.value_strengths.keys():
			var parent_strength: int = int(parent.value_strengths[value_id])
			if parent_strength <= 0 or (CONDUCT_OPPOSITES.has(value_id) and get_strength(household, CONDUCT_OPPOSITES[value_id]) > 0):
				continue
			if not CONDUCT_VALUES.has(value_id) and not CultureValues.has_value(household.values, value_id):
				continue
			var roll: int = rng.randi_range(0, 99)
			var strength: int = parent_strength + (-1 if roll < 15 else 1 if roll >= 90 else 0)
			household.value_strengths[value_id] = maxi(household.value_strengths.get(value_id, 0), clampi(strength, 1, 3))
	for value_id: String in get_held_values(household):
		if not household.value_strengths.has(value_id):
			household.value_strengths[value_id] = 1

# --- Reading a profile ---------------------------------------------------------------------------

# An axis, or for a household without a character yet, what its migrated values imply.
static func get_axis(household: Household, axis: String) -> int:
	if household.personality.has(axis):
		return int(household.personality[axis])
	for value_id: String in MIGRATED_VALUES.keys():
		if MIGRATED_VALUES[value_id][0] == axis and CultureValues.has_value(household.values, value_id):
			return int(MIGRATED_VALUES[value_id][1]) * 2
	return 0

# 0 not held, 1 mild, 2 strong, 3 defining. A catalog value held without a strength is mild.
static func get_strength(household: Household, value_id: String) -> int:
	if value_id == "":
		return 0
	if household.value_strengths.has(value_id):
		return int(household.value_strengths[value_id])
	return 1 if CultureValues.has_value(household.values, value_id) else 0

static func set_strength(household: Household, value_id: String, strength: int) -> void:
	household.value_strengths[value_id] = clampi(strength, 0, 3)

# Every value the household holds at any strength: catalog values (but not the ones that moved to
# personality) and conduct values.
static func get_held_values(household: Household) -> Array[String]:
	var held: Array[String] = []
	for category: String in household.values.keys():
		for value_id in household.values[category]:
			if not MIGRATED_VALUES.has(value_id) and not held.has(str(value_id)):
				held.append(str(value_id))
	for value_id: String in household.value_strengths.keys():
		if int(household.value_strengths[value_id]) > 0 and not held.has(value_id) and not MIGRATED_VALUES.has(value_id):
			held.append(value_id)
	return held

# --- Describing ----------------------------------------------------------------------------------

static func get_value_name(value_id: String) -> String:
	if CONDUCT_NAMES.has(value_id):
		return CONDUCT_NAMES[value_id]
	return CultureValues.get_display_name(value_id) if CultureValues.DISPLAY_NAMES.has(value_id) else value_id.capitalize()

static func describe_axis(axis: String, level: int) -> String:
	if level == 0:
		return ""
	var words: Array = AXIS_WORDS[axis]
	return str(words[0 if level <= -2 else 1 if level == -1 else 2 if level == 1 else 3])

# The household's marked temperaments, strongest first ("very cautious, outgoing").
static func describe_personality(household: Household, count: int = 7) -> String:
	var axes: Array[String] = AXES.duplicate()
	axes = axes.filter(func(axis: String) -> bool: return get_axis(household, axis) != 0)
	axes.sort_custom(func(a: String, b: String) -> bool: return absi(get_axis(household, a)) > absi(get_axis(household, b)))
	var words: Array[String] = []
	for axis: String in axes.slice(0, count):
		words.append(describe_axis(axis, get_axis(household, axis)))
	return ", ".join(words) if not words.is_empty() else "even-tempered"

# Its strong and defining convictions, defining first ("Communal Labor (defining), Honesty").
static func describe_convictions(household: Household, count: int = 4) -> String:
	var strong: Array[String] = get_held_values(household).filter(func(value_id: String) -> bool: return get_strength(household, value_id) >= 2)
	strong.sort_custom(func(a: String, b: String) -> bool: return get_strength(household, a) > get_strength(household, b) or (get_strength(household, a) == get_strength(household, b) and a < b))
	var words: Array[String] = []
	for value_id: String in strong.slice(0, count):
		words.append(get_value_name(value_id) + (" (defining)" if get_strength(household, value_id) >= 3 else ""))
	return ", ".join(words) if not words.is_empty() else "no strong convictions"

# One or two words for a roster line: its most marked trait and its first defining conviction.
static func describe_briefly(household: Household) -> String:
	var parts: Array[String] = []
	var temper: String = describe_personality(household, 1)
	if temper != "even-tempered":
		parts.append(temper)
	var defining: Array[String] = get_held_values(household).filter(func(value_id: String) -> bool: return get_strength(household, value_id) >= 3)
	defining.sort()
	if not defining.is_empty():
		parts.append(get_value_name(defining[0]).to_lower())
	return ", ".join(parts)
