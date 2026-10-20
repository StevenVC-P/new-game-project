class_name CultureValues
extends RefCounted

# Catalog and holding rules for household values. Design source: docs/CULTURE_AND_VALUES_MODEL.md.
# A family holds 1-2 values per category and never both sides of an exclusive group.

const CATEGORY_CALLING: String = "calling"
const CATEGORY_WORK_ETHIC: String = "work_ethic"
const CATEGORY_KIN: String = "kin"
const CATEGORY_WEALTH: String = "wealth"
const CATEGORY_TRADE_COIN: String = "trade_coin"
const CATEGORY_AUTHORITY: String = "authority"
const CATEGORY_CHANGE_RISK: String = "change_risk"
const CATEGORY_CRAFT_LEARNING: String = "craft_learning"
const CATEGORY_CONFLICT: String = "conflict"
const CATEGORY_FAITH: String = "faith"
const CATEGORY_COMMUNITY: String = "community"
const CATEGORY_HOME_PLACE: String = "home_place"

const MAX_VALUES_PER_CATEGORY: int = 2
const SECOND_VALUE_CHANCE: int = 40
const INHERIT_KEEP_CHANCE: int = 80

const CATEGORY_ORDER: Array[String] = [
	CATEGORY_CALLING,
	CATEGORY_WORK_ETHIC,
	CATEGORY_KIN,
	CATEGORY_WEALTH,
	CATEGORY_TRADE_COIN,
	CATEGORY_AUTHORITY,
	CATEGORY_CHANGE_RISK,
	CATEGORY_CRAFT_LEARNING,
	CATEGORY_CONFLICT,
	CATEGORY_FAITH,
	CATEGORY_COMMUNITY,
	CATEGORY_HOME_PLACE
]

const CATEGORY_VALUES: Dictionary = {
	CATEGORY_CALLING: ["soil", "forest", "stone", "deep_earth", "forge_bench", "loom", "road", "water", "shield", "hearth", "word", "muse"],
	CATEGORY_WORK_ETHIC: ["industrious", "leisurely", "steady", "surging", "perfectionist", "expedient", "communal_labor", "solitary"],
	CATEGORY_KIN: ["fathers_line", "mothers_line", "strongest_line", "many_children", "few_children", "close_knit", "leave_the_nest", "elder_reverence", "youth_ascendant"],
	CATEGORY_WEALTH: ["thrifty", "lavish", "sharing", "acquisitive", "common_stores", "private_holdings", "landholding"],
	CATEGORY_TRADE_COIN: ["old_ways", "coin_minded", "hard_money", "hagglers", "fair_dealers", "insular", "cosmopolitan"],
	CATEGORY_AUTHORITY: ["traditionalist", "reformist", "deferential", "self_governing", "lawful", "free_spirited", "hierarchical", "egalitarian"],
	CATEGORY_CHANGE_RISK: ["cautious", "daring", "rooted", "wanderlust", "hopeful", "fatalistic"],
	CATEGORY_CRAFT_LEARNING: ["keepers_of_craft", "teachers", "lettered", "hands_on", "curious", "self_reliant"],
	CATEGORY_CONFLICT: ["martial", "peaceable", "honor_bound", "pragmatic", "defenders", "conquerors", "mercenary"],
	CATEGORY_FAITH: ["devout", "worldly", "festive", "austere", "ancestral", "omen_watchers"],
	CATEGORY_COMMUNITY: ["welcoming", "clannish", "charitable", "each_to_their_own", "proud", "adaptable"],
	CATEGORY_HOME_PLACE: ["hearth_proud", "simple_living", "open_country", "town_loving", "monument_makers"]
}

# Values in the same group cannot be held together by one family. Pairs are the model's opposites;
# the lineage rules form one three-way group.
const EXCLUSIVE_GROUPS: Array = [
	["industrious", "leisurely"], ["steady", "surging"], ["perfectionist", "expedient"], ["communal_labor", "solitary"],
	["fathers_line", "mothers_line", "strongest_line"], ["many_children", "few_children"], ["close_knit", "leave_the_nest"], ["elder_reverence", "youth_ascendant"],
	["thrifty", "lavish"], ["sharing", "acquisitive"], ["common_stores", "private_holdings"],
	["old_ways", "coin_minded"], ["hagglers", "fair_dealers"], ["insular", "cosmopolitan"],
	["traditionalist", "reformist"], ["deferential", "self_governing"], ["lawful", "free_spirited"], ["hierarchical", "egalitarian"],
	["cautious", "daring"], ["rooted", "wanderlust"], ["hopeful", "fatalistic"],
	["keepers_of_craft", "teachers"], ["lettered", "hands_on"], ["curious", "self_reliant"],
	["martial", "peaceable"], ["honor_bound", "pragmatic"], ["defenders", "conquerors"],
	["devout", "worldly"], ["festive", "austere"],
	["welcoming", "clannish"], ["charitable", "each_to_their_own"], ["proud", "adaptable"],
	["hearth_proud", "simple_living"], ["open_country", "town_loving"]
]

const DISPLAY_NAMES: Dictionary = {
	"soil": "Of the Soil", "forest": "Of the Forest", "stone": "Of Stone", "deep_earth": "Of the Deep Earth",
	"forge_bench": "Of the Forge and Bench", "loom": "Of the Loom", "road": "Of the Road", "water": "Of the Water",
	"shield": "Of the Shield", "hearth": "Of the Hearth", "word": "Of the Word", "muse": "Of the Muse",
	"industrious": "Industrious", "leisurely": "Leisurely", "steady": "Steady", "surging": "Surging",
	"perfectionist": "Perfectionist", "expedient": "Expedient", "communal_labor": "Communal Labor", "solitary": "Solitary",
	"fathers_line": "Father's Line", "mothers_line": "Mother's Line", "strongest_line": "Strongest Line",
	"many_children": "Many Children", "few_children": "Few Children", "close_knit": "Close-Knit", "leave_the_nest": "Leave the Nest",
	"elder_reverence": "Elder Reverence", "youth_ascendant": "Youth Ascendant",
	"thrifty": "Thrifty", "lavish": "Lavish", "sharing": "Sharing", "acquisitive": "Acquisitive",
	"common_stores": "Common Stores", "private_holdings": "Private Holdings", "landholding": "Landholding",
	"old_ways": "Old Ways", "coin_minded": "Coin-Minded", "hard_money": "Hard Money", "hagglers": "Hagglers",
	"fair_dealers": "Fair Dealers", "insular": "Insular", "cosmopolitan": "Cosmopolitan",
	"traditionalist": "Traditionalist", "reformist": "Reformist", "deferential": "Deferential", "self_governing": "Self-Governing",
	"lawful": "Lawful", "free_spirited": "Free-Spirited", "hierarchical": "Hierarchical", "egalitarian": "Egalitarian",
	"cautious": "Cautious", "daring": "Daring", "rooted": "Rooted", "wanderlust": "Wanderlust", "hopeful": "Hopeful", "fatalistic": "Fatalistic",
	"keepers_of_craft": "Keepers of Craft", "teachers": "Teachers", "lettered": "Lettered", "hands_on": "Hands-On",
	"curious": "Curious", "self_reliant": "Self-Reliant",
	"martial": "Martial", "peaceable": "Peaceable", "honor_bound": "Honor-Bound", "pragmatic": "Pragmatic",
	"defenders": "Defenders", "conquerors": "Conquerors", "mercenary": "Mercenary",
	"devout": "Devout", "worldly": "Worldly", "festive": "Festive", "austere": "Austere", "ancestral": "Ancestral", "omen_watchers": "Omen-Watchers",
	"welcoming": "Welcoming", "clannish": "Clannish", "charitable": "Charitable", "each_to_their_own": "Each to Their Own",
	"proud": "Proud", "adaptable": "Adaptable",
	"hearth_proud": "Hearth-Proud", "simple_living": "Simple Living", "open_country": "Open Country", "town_loving": "Town-Loving",
	"monument_makers": "Monument-Makers"
}

const CATEGORY_DISPLAY_NAMES: Dictionary = {
	CATEGORY_CALLING: "Calling", CATEGORY_WORK_ETHIC: "Work Ethic", CATEGORY_KIN: "Kin and Lineage",
	CATEGORY_WEALTH: "Wealth and Property", CATEGORY_TRADE_COIN: "Trade and Coin", CATEGORY_AUTHORITY: "Authority and Law",
	CATEGORY_CHANGE_RISK: "Change and Risk", CATEGORY_CRAFT_LEARNING: "Craft and Learning", CATEGORY_CONFLICT: "Conflict and Honor",
	CATEGORY_FAITH: "Faith and Ritual", CATEGORY_COMMUNITY: "Community and Outsiders", CATEGORY_HOME_PLACE: "Home and Place"
}

static func get_display_name(value_id: String) -> String:
	return str(DISPLAY_NAMES.get(value_id, value_id))

static func get_category_display_name(category: String) -> String:
	return str(CATEGORY_DISPLAY_NAMES.get(category, category))

static func get_category_of(value_id: String) -> String:
	for category: String in CATEGORY_ORDER:
		if (CATEGORY_VALUES[category] as Array).has(value_id):
			return category
	return ""

static func values_conflict(first: String, second: String) -> bool:
	if first == second:
		return false
	for group: Array in EXCLUSIVE_GROUPS:
		if group.has(first) and group.has(second):
			return true
	return false

static func has_value(profile: Dictionary, value_id: String) -> bool:
	var category: String = get_category_of(value_id)
	if category == "" or not profile.has(category):
		return false
	return (profile[category] as Array).has(value_id)

static func is_valid_profile(profile: Dictionary) -> bool:
	for category: String in CATEGORY_ORDER:
		if not profile.has(category):
			return false
		var held: Array = profile[category]
		if held.size() < 1 or held.size() > MAX_VALUES_PER_CATEGORY:
			return false
		for value_id in held:
			if not (CATEGORY_VALUES[category] as Array).has(value_id):
				return false
		if held.size() == 2 and (held[0] == held[1] or values_conflict(held[0], held[1])):
			return false
	return true

# Builds a full profile. `preset` may fix some categories (for example a seeded calling).
static func make_random_profile(rng: RandomNumberGenerator, preset: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = {}
	for category: String in CATEGORY_ORDER:
		if preset.has(category):
			profile[category] = (preset[category] as Array).duplicate()
			continue
		profile[category] = _pick_category_values(category, rng, {})
	return profile

# Inherits from one or more parent profiles: each parent value is kept with INHERIT_KEEP_CHANCE;
# empty categories are filled from the settlement's value counts (falling back to uniform).
static func inherit_profile(parent_profiles: Array, rng: RandomNumberGenerator, settlement_counts: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = {}
	for category: String in CATEGORY_ORDER:
		var candidates: Array[String] = []
		for parent_profile in parent_profiles:
			if not (parent_profile is Dictionary) or not parent_profile.has(category):
				continue
			for value_id in parent_profile[category]:
				if candidates.has(value_id):
					continue
				if rng.randi_range(0, 99) < INHERIT_KEEP_CHANCE:
					candidates.append(value_id)
		_shuffle(candidates, rng)

		var held: Array[String] = []
		for value_id: String in candidates:
			if held.size() >= MAX_VALUES_PER_CATEGORY:
				break
			if _conflicts_with_any(value_id, held):
				continue
			held.append(value_id)

		if held.is_empty():
			held = _pick_category_values(category, rng, settlement_counts, 1)
		profile[category] = held
	return profile

static func count_values(profiles: Array) -> Dictionary:
	var counts: Dictionary = {}
	for profile in profiles:
		if not (profile is Dictionary):
			continue
		for category in profile.keys():
			for value_id in profile[category]:
				counts[value_id] = int(counts.get(value_id, 0)) + 1
	return counts

# Defining values are the ones least shared with the rest of the settlement.
static func get_defining_values(profile: Dictionary, settlement_counts: Dictionary, profile_count: int, limit: int = 3) -> Array[String]:
	var scored: Array = []
	for category: String in CATEGORY_ORDER:
		if not profile.has(category):
			continue
		for value_id in profile[category]:
			var share: float = float(settlement_counts.get(value_id, 0)) / float(max(1, profile_count))
			scored.append([share, CATEGORY_ORDER.find(category), value_id])
	scored.sort_custom(func(left, right): return left[0] < right[0] or (left[0] == right[0] and left[1] < right[1]))

	var result: Array[String] = []
	for entry in scored:
		if result.size() >= limit:
			break
		result.append(str(entry[2]))
	return result

static func format_profile_lines(profile: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for category: String in CATEGORY_ORDER:
		if not profile.has(category):
			continue
		var names: Array[String] = []
		for value_id in profile[category]:
			names.append(get_display_name(value_id))
		lines.append(get_category_display_name(category) + ": " + ", ".join(names))
	return lines

static func _pick_category_values(category: String, rng: RandomNumberGenerator, settlement_counts: Dictionary, max_count: int = MAX_VALUES_PER_CATEGORY) -> Array[String]:
	var target_count: int = 1
	if max_count >= 2 and rng.randi_range(0, 99) < SECOND_VALUE_CHANCE:
		target_count = 2

	var held: Array[String] = []
	var options: Array = CATEGORY_VALUES[category]
	var attempts: int = 0
	while held.size() < target_count and attempts < 20:
		attempts += 1
		var value_id: String = _weighted_pick(options, rng, settlement_counts)
		if held.has(value_id) or _conflicts_with_any(value_id, held):
			continue
		held.append(value_id)
	return held

static func _weighted_pick(options: Array, rng: RandomNumberGenerator, settlement_counts: Dictionary) -> String:
	# +1 keeps unseen values possible, so a settlement's culture can still drift.
	var total: int = 0
	for value_id in options:
		total += int(settlement_counts.get(value_id, 0)) + 1
	var roll: int = rng.randi_range(0, total - 1)
	for value_id in options:
		roll -= int(settlement_counts.get(value_id, 0)) + 1
		if roll < 0:
			return str(value_id)
	return str(options[options.size() - 1])

static func _conflicts_with_any(value_id: String, held: Array[String]) -> bool:
	for other: String in held:
		if values_conflict(value_id, other):
			return true
	return false

static func _shuffle(items: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temp: String = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temp
