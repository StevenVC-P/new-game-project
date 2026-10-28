class_name CultureEffects
extends RefCounted

# How household values change outcomes (M1 slice: Calling, Work Ethic, Kin).
# Design source: docs/CULTURE_AND_VALUES_MODEL.md. All numbers are tuning defaults.

const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")

const MATCH_GOOD: String = "good match"
const MATCH_NEUTRAL: String = "neutral"
const MATCH_POOR: String = "poor match"

# Same strength as the old preference adjustment (+1 every 2-4 ticks, about 25%).
const CALLING_MATCH_PERCENT: int = 25
const CALLING_POOR_MATCH_PERCENT: int = -25
const OUTPUT_PERCENT_CAP: int = 30

const WORK_ETHIC_PERCENT: Dictionary = {
	"industrious": 10,
	"leisurely": -10,
	"steady": 5,
	"perfectionist": -10,
	"expedient": 10
}
const SURGING_CRISIS_PERCENT: int = 15
const SURGING_CALM_PERCENT: int = -5
const COMMUNAL_GROUP_PERCENT: int = 10
const COMMUNAL_ALONE_PERCENT: int = -5
# Communal labor counts as a group when this many other workplaces of the same type operate.
const COMMUNAL_GROUP_MIN_OTHERS: int = 1

const BIRTH_CHANCE_BONUS: Dictionary = {
	"many_children": 5,
	"few_children": -5
}
const CLOSE_KNIT_FORMATION_DELAY_MONTHS: int = 12

# Callings drawn to each workplace. Building types are the string ids from Building.
const BUILDING_CALLINGS: Dictionary = {
	"farm": ["soil"],
	"woodcutter": ["forest"],
	"fisher": ["water"],
	"hunter": ["forest", "shield"],
	"watch_post": ["shield"],
	"herder": ["loom", "soil"],
	"toolmaker": ["forge_bench"],
	"quarry": ["stone", "deep_earth"],
	"stonecutter": ["stone"],
	"brickworks": ["stone"],
	"lime_kiln": ["stone"],
	"mortar_yard": ["stone"],
	"mason_yard": ["stone"],
	"sculptor": ["muse", "stone"],
	"carver": ["forge_bench", "muse"],
	"tileworks": ["stone"],
	"paver_yard": ["stone"],
	# Building sites (TownConstruction): masons and carpenters.
	"construction": ["stone", "forest"]
}

# Families whose only callings are material trades are poorly suited to unrelated material work.
# Callings without a workplace yet (hearth, word, shield, road, ...) are neutral anywhere.
const MATERIAL_CALLINGS: Array[String] = ["soil", "forest", "stone", "deep_earth", "forge_bench", "loom", "water"]

# Display bridge for UI that still groups families as agrarian / industrial / neutral.
const CALLING_DISPLAY_PREFERENCE: Dictionary = {
	"soil": "agrarian",
	"forest": "industrial",
	"stone": "industrial",
	"deep_earth": "industrial",
	"forge_bench": "industrial",
	"loom": "industrial"
}

static func get_callings(profile: Dictionary) -> Array:
	return profile.get(CultureValuesScript.CATEGORY_CALLING, [])

static func get_calling_match(profile: Dictionary, building_type: String) -> String:
	var callings: Array = get_callings(profile)
	if callings.is_empty():
		return MATCH_NEUTRAL

	var drawn: Array = BUILDING_CALLINGS.get(BuildingTiersScript.get_base_type(building_type), [])
	for calling in callings:
		if drawn.has(calling):
			return MATCH_GOOD

	if drawn.is_empty():
		return MATCH_NEUTRAL
	for calling in callings:
		if not MATERIAL_CALLINGS.has(calling):
			return MATCH_NEUTRAL
	return MATCH_POOR

# Agrarian wins if any calling is agrarian, then industrial, so a farming family never shows
# as neutral just because its other calling comes first.
static func get_display_preference(profile: Dictionary) -> String:
	var groups: Array = []
	for calling in get_callings(profile):
		groups.append(str(CALLING_DISPLAY_PREFERENCE.get(calling, "neutral")))
	if groups.has("agrarian"):
		return "agrarian"
	if groups.has("industrial"):
		return "industrial"
	return "neutral"

# context: {"food_shortage": bool, "same_type_operating_others": int}
static func get_work_output_percent(profile: Dictionary, building_type: String, context: Dictionary = {}) -> int:
	var percent: int = 0
	var match_quality: String = get_calling_match(profile, building_type)
	if match_quality == MATCH_GOOD:
		percent += CALLING_MATCH_PERCENT
	elif match_quality == MATCH_POOR:
		percent += CALLING_POOR_MATCH_PERCENT

	var work_ethic: Array = profile.get(CultureValuesScript.CATEGORY_WORK_ETHIC, [])
	for value_id in work_ethic:
		percent += int(WORK_ETHIC_PERCENT.get(value_id, 0))
	if work_ethic.has("surging"):
		percent += SURGING_CRISIS_PERCENT if bool(context.get("food_shortage", false)) else SURGING_CALM_PERCENT
	if work_ethic.has("communal_labor"):
		var others: int = int(context.get("same_type_operating_others", 0))
		percent += COMMUNAL_GROUP_PERCENT if others >= COMMUNAL_GROUP_MIN_OTHERS else COMMUNAL_ALONE_PERCENT

	return clampi(percent, -OUTPUT_PERCENT_CAP, OUTPUT_PERCENT_CAP)

static func get_birth_chance_bonus(profile: Dictionary) -> int:
	var bonus: int = 0
	for value_id in profile.get(CultureValuesScript.CATEGORY_KIN, []):
		bonus += int(BIRTH_CHANCE_BONUS.get(value_id, 0))
	return bonus

static func get_family_formation_delay_months(profile: Dictionary) -> int:
	if CultureValuesScript.has_value(profile, "close_knit"):
		return CLOSE_KNIT_FORMATION_DELAY_MONTHS
	return 0

# Leave the Nest families claim empty houses for their children first.
static func has_family_formation_priority(profile: Dictionary) -> bool:
	return CultureValuesScript.has_value(profile, "leave_the_nest")

# --- M2: departures, crowding, and community attraction ---

# Hardship points a family tolerates before leaving (docs/SETTLEMENT_GROWTH_SCALE_MODEL.md).
const DEPARTURE_BASE_THRESHOLD: int = 6
const DEPARTURE_MIN_THRESHOLD: int = 3
const DEPARTURE_THRESHOLD_MODIFIERS: Dictionary = {
	"rooted": 4,
	"wanderlust": -2,
	"hopeful": 2,
	"fatalistic": 2,
	"close_knit": 1,
	"leave_the_nest": -1
}

const CROWDING_SENSITIVE: String = "sensitive"
const CROWDING_NORMAL: String = "normal"
const CROWDING_TOLERANT: String = "tolerant"
const CROWDING_BIRTH_PENALTY: Dictionary = {
	CROWDING_SENSITIVE: -10,
	CROWDING_NORMAL: -5,
	CROWDING_TOLERANT: -2
}
const CROWDING_HARDSHIP_POINTS: Dictionary = {
	CROWDING_SENSITIVE: 2,
	CROWDING_NORMAL: 1,
	CROWDING_TOLERANT: 0
}

# Share of Welcoming minus Clannish families scales how attractive the town is to newcomers.
const COMMUNITY_ATTRACTION_PERCENT: int = 15

static func get_departure_threshold(profile: Dictionary) -> int:
	var threshold: int = DEPARTURE_BASE_THRESHOLD
	for category in profile.keys():
		for value_id in profile[category]:
			threshold += int(DEPARTURE_THRESHOLD_MODIFIERS.get(value_id, 0))
	return max(DEPARTURE_MIN_THRESHOLD, threshold)

static func get_crowding_tolerance(profile: Dictionary) -> String:
	if CultureValuesScript.has_value(profile, "hearth_proud"):
		return CROWDING_SENSITIVE
	if CultureValuesScript.has_value(profile, "simple_living") or CultureValuesScript.has_value(profile, "town_loving"):
		return CROWDING_TOLERANT
	return CROWDING_NORMAL

static func get_crowding_birth_penalty(profile: Dictionary) -> int:
	return int(CROWDING_BIRTH_PENALTY[get_crowding_tolerance(profile)])

static func get_crowding_hardship_points(profile: Dictionary) -> int:
	return int(CROWDING_HARDSHIP_POINTS[get_crowding_tolerance(profile)])

static func get_community_attraction(profiles: Array) -> int:
	if profiles.is_empty():
		return 0
	var welcoming: int = 0
	var clannish: int = 0
	for profile in profiles:
		if CultureValuesScript.has_value(profile, "welcoming"):
			welcoming += 1
		if CultureValuesScript.has_value(profile, "clannish"):
			clannish += 1
	return int(round(float(COMMUNITY_ATTRACTION_PERCENT * (welcoming - clannish)) / float(profiles.size())))

# --- Marriage outside the town ---

# Months a grown child with no partner in town waits before marrying an outsider.
const OUTSIDER_MARRIAGE_BASE_WAIT_MONTHS: int = 6
const OUTSIDER_MARRIAGE_MIN_WAIT_MONTHS: int = 2
const OUTSIDER_MARRIAGE_WAIT_MODIFIERS: Dictionary = {
	"clannish": 12,
	"insular": 6,
	"welcoming": -3,
	"cosmopolitan": -3
}

static func get_outsider_marriage_wait_months(profile: Dictionary) -> int:
	var wait: int = OUTSIDER_MARRIAGE_BASE_WAIT_MONTHS
	for category in profile.keys():
		for value_id in profile[category]:
			wait += int(OUTSIDER_MARRIAGE_WAIT_MODIFIERS.get(value_id, 0))
	return max(OUTSIDER_MARRIAGE_MIN_WAIT_MONTHS, wait)
