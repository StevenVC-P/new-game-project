class_name CultureEffects
extends RefCounted

# How household values change outcomes (M1 slice: Calling, Work Ethic, Kin).
# Design source: docs/CULTURE_AND_VALUES_MODEL.md. All numbers are tuning defaults.

const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")

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
	"paver_yard": ["stone"]
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

	var drawn: Array = BUILDING_CALLINGS.get(building_type, [])
	for calling in callings:
		if drawn.has(calling):
			return MATCH_GOOD

	if drawn.is_empty():
		return MATCH_NEUTRAL
	for calling in callings:
		if not MATERIAL_CALLINGS.has(calling):
			return MATCH_NEUTRAL
	return MATCH_POOR

static func get_display_preference(profile: Dictionary) -> String:
	var callings: Array = get_callings(profile)
	if callings.is_empty():
		return "neutral"
	return str(CALLING_DISPLAY_PREFERENCE.get(callings[0], "neutral"))

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
