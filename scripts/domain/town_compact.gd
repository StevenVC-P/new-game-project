class_name TownCompact
extends RefCounted

# The founding compact (sprint S7; owner decision D1 and the owner's S7 guidance, 2026-11-05): the
# share of each holding's work the founding families agreed to give the community, by category of
# good. What a family keeps is its own (TownLedger): it eats, warms, builds and works from it first.
#
# An agreement among families, not a power to take: families may give more than it asks, by their
# values and trust (advance_month). How far they accept and keep to it is later work. Neither
# arrangement is helped: a high rate gives the community security and families little of their
# own; a low one the reverse, and leaves families depending on each other (exchange is S9).
#
# city.compact is {category: rate 0..1}. Empty is the pooled setting (old saves and comparison
# runs): everything goes to the community and play is the game before S6. A new game's founding
# asks for a compact (main.gd); the Community page changes it later.

const FOOD: String = "food"
const WOOD: String = "wood"
const STONE: String = "stone"
const TOOLS: String = "tools"
const GOODS: String = "goods"
const CATEGORIES: Array[String] = [FOOD, WOOD, STONE, TOOLS, GOODS]
const CATEGORY_OF: Dictionary = {
	"food": FOOD, "wood": WOOD, "tools": TOOLS,
	"stone_blocks": STONE, "cut_stone": STONE, "bricks": STONE, "lime": STONE, "mortar": STONE,
	"masonry": STONE, "paving_stones": STONE, "tiles": STONE,
}
const CATEGORY_NAMES: Dictionary = {FOOD: "Food", WOOD: "Wood", STONE: "Stone and clay", TOOLS: "Tools", GOODS: "Crafted goods"}
const PRESET_NAMES: Dictionary = {"communal": "Communal", "shared": "Shared", "private": "Private"}
# Values that lean a family toward giving the community more, and away from it.
const GIVING_VALUES: Array[String] = ["common_stores", "sharing", "communal_labor", "deferential"]
const KEEPING_VALUES: Array[String] = ["private_holdings", "acquisitive", "thrifty", "self_governing"]

static func is_set(city: City) -> bool:
	return not city.compact.is_empty()

static func get_category(good: String) -> String:
	return str(CATEGORY_OF.get(good, GOODS))

# The community's share of a good's work: everything while pooled.
static func get_rate(city: City, good: String) -> float:
	return get_category_rate(city, get_category(good))

static func get_category_rate(city: City, category: String) -> float:
	if not is_set(city):
		return 1.0
	return clampf(float(city.compact.get(category, 1.0)), 0.0, 1.0)

static func set_preset(city: City, preset: String) -> void:
	if not EconomyBalance.COMPACT_PRESETS.has(preset):
		return
	for category: String in CATEGORIES:
		city.compact[category] = float(EconomyBalance.COMPACT_PRESETS[preset])

# One category up or down a step (the Community page). Setting a rate on a pooled town starts it
# from everything to the community, which is what pooling was.
static func change_rate(city: City, category: String, steps: int) -> void:
	if not CATEGORIES.has(category):
		return
	if not is_set(city):
		set_preset(city, "communal")
	var rate: float = float(city.compact[category]) + float(steps) * EconomyBalance.COMPACT_RATE_STEP
	city.compact[category] = snappedf(clampf(rate, 0.0, 1.0), 0.01)

# The preset the rates match, or "" when they're mixed.
static func get_preset(city: City) -> String:
	for preset: String in EconomyBalance.COMPACT_PRESETS.keys():
		var matches: bool = true
		for category: String in CATEGORIES:
			matches = matches and is_equal_approx(float(city.compact.get(category, -1.0)), float(EconomyBalance.COMPACT_PRESETS[preset]))
		if matches:
			return preset
	return ""

static func get_value(good: String) -> float:
	return float(EconomyBalance.WORKED_VALUE_IN_GRAIN.get(good, EconomyBalance.VALUE_IN_GRAIN.get(good, 1.0)))

# --- Production ---------------------------------------------------------------------------------

# Puts what a workplace made into the store. Pooled, all of it is the community's. Under a compact
# it is divided by worth: the worth of its inputs goes back to whoever paid them (`paid` is
# {input good: {payer id: amount}}, from TownLedger.charge), and the worth the work added is shared
# between the community and the working family at the rate. A workplace nobody works gives
# everything to the community. Fractions of a unit are carried on the building.
static func deliver_output(city: City, building: Building, good: String, made: int, paid: Dictionary) -> void:
	var household: Household = city.get_household_by_id(building.assigned_household_id) if building != null and building.assigned_household_id >= 0 else null
	if made <= 0:
		return
	if not is_set(city) or household == null:
		city.add_resource(good, made, "made")
		return
	var inputs_worth: float = 0.0
	var own_inputs_worth: float = 0.0
	for input: String in paid.keys():
		var by_payer: Dictionary = paid[input]
		for payer: int in by_payer.keys():
			var worth: float = float(by_payer[payer]) * get_value(input)
			inputs_worth += worth
			if payer == household.id:
				own_inputs_worth += worth
	var output_worth: float = float(made) * get_value(good)
	var added: float = maxf(0.0, output_worth - inputs_worth)
	var family_worth: float = own_inputs_worth + added * (1.0 - get_rate(city, good))
	var family_units: float = float(made) * family_worth / maxf(0.0001, maxf(output_worth, inputs_worth)) + building.share_carry
	var whole: int = mini(made, int(floor(family_units)))
	building.share_carry = family_units - float(whole)
	TownLedger.credit(city, household, good, whole, "made")
	city.add_resource(good, made - whole, "made")

# --- Giving more (monthly) ----------------------------------------------------------------------

# How far a family leans toward giving the community more than the compact asks: its values (by
# strength) and its trust in the community's leadership. At or below zero it gives nothing extra.
static func get_giving_lean(household: Household) -> float:
	var lean: float = 0.0
	for value_id: String in GIVING_VALUES:
		lean += float(HouseholdCharacter.get_strength(household, value_id))
	for value_id: String in KEEPING_VALUES:
		lean -= float(HouseholdCharacter.get_strength(household, value_id))
	return lean + float(household.trust) * EconomyBalance.TRUST_GIVING_WEIGHT

# What a family keeps of a good before it would give any away: its food and winter fuel for a
# while, and whatever its own projects still wait for.
static func get_keep(city: City, household: Household, good: String) -> int:
	var keep: float = 0.0
	if good == "food":
		keep += HouseholdEconomy.get_daily_need(household) * float(EconomyBalance.GIVE_KEEPS_FOOD_DAYS)
	elif good == "wood":
		keep += TownFuel.get_household_need(city, household, 3) * float(EconomyBalance.GIVE_KEEPS_FUEL_DAYS)
	for project: ConstructionProject in city.construction.projects:
		if project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and project.requester_household_id == household.id:
			keep += float(project.get_remaining_materials().get(good, 0))
	return int(ceil(keep))

# Monthly (HouseholdMigration.advance_month): families that lean toward the community give a share
# of what they hold beyond their own needs. The goods stay in the store; only whose they are changes.
static func advance_month(city: City) -> void:
	if not is_set(city):
		return
	var ordered: Array[Household] = city.households.duplicate()
	ordered.sort_custom(func(a: Household, b: Household) -> bool: return a.id < b.id)
	for household: Household in ordered:
		var lean: float = get_giving_lean(household)
		if lean <= 0.0:
			continue
		var share: float = minf(EconomyBalance.GIVE_SHARE_MAX, lean * EconomyBalance.GIVE_SHARE_PER_POINT)
		for good: String in household.stores_share.keys().duplicate():
			var spare: int = TownLedger.get_share(household, good) - get_keep(city, household, good)
			var give: int = int(floor(float(spare) * share))
			if give <= 0:
				continue
			TownLedger.set_share(household, good, TownLedger.get_share(household, good) - give)
			city.compact_given[good] = int(city.compact_given.get(good, 0)) + give
			household.given_to_community += give
