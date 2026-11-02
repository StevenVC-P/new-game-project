class_name MaterialChoice
extends RefCounted

# What a family builds its own home or workplace of (sprint S4b; owner D6: families choose the
# materials of their own buildings, the player those of communal ones). Timber, rough stone or
# dressed stone (EconomyBalance, Building materials), weighed like any other choice, with reasons
# and seeded noise:
#
# - only what the stores can supply now is open to it (stone where the town has quarried it);
# - what it takes from the stores, as scarce goods weigh (FamilyInitiative.get_spending_risk);
# - how much longer stone takes to raise, the more when the family needs shelter or food now
#   (survival: a roof this season before a lasting one);
# - what stone gives back: a workplace that needs fewer tools, a home that needs less firewood
#   where winters are cold;
# - its values: Perfectionist and Keepers of Craft want lasting work, Expedient the quick way,
#   Thrifty the cheaper one.
#
# Families that see no stone in store build of timber, so a town without stone builds as before.

const SPEND_WEIGHT: float = 2.0
const TIME_WEIGHT: float = 1.5
const LASTING_WEIGHT: float = 0.6
const WARMTH_WEIGHT: float = 1.2
const VALUE_WEIGHT: float = 0.6
const NOISE: float = 0.4

# {"material", "terms" (of the chosen), "options": [{material, score, terms}]}.
static func choose(city: City, household: Household, building_type: String) -> Dictionary:
	var options: Array[Dictionary] = []
	if not EconomyBalance.can_be_stone(building_type):
		return {"material": EconomyBalance.MATERIAL_TIMBER, "terms": [], "options": options}
	var urgency: float = get_urgency(city, household)
	var timber_days: float = EconomyBalance.get_build_work_days(building_type)
	for material: String in EconomyBalance.MATERIALS:
		var cost: Dictionary = EconomyBalance.get_build_cost(building_type, material)
		if material != EconomyBalance.MATERIAL_TIMBER and not city.construction.can_supply(cost):
			continue
		var terms: Array = []
		var spending: float = FamilyInitiative.get_spending_risk(city, cost)
		if spending > 0.0:
			FamilyInitiative.add(terms, -SPEND_WEIGHT * spending, "it would take scarce %s" % ", ".join(cost.keys().filter(func(k: String) -> bool: return int(cost[k]) > 0)))
		var extra: float = EconomyBalance.get_build_work_days(building_type, material) / timber_days - 1.0
		if extra > 0.0:
			FamilyInitiative.add(terms, -TIME_WEIGHT * extra * (1.0 + urgency), "stone takes longer to raise" + (", and it needs shelter or food now" if urgency > 0.0 else ""))
		if EconomyBalance.is_stone_material(material):
			if BuildingTiers.get_base_type(building_type) == Building.BUILDING_HOUSE:
				var cold: float = TownFuel.get_need_over(city, Calendar.DAYS_PER_YEAR) / maxf(1.0, float(maxi(1, city.households.size())) * float(Calendar.DAYS_PER_YEAR))
				if cold > 0.0:
					FamilyInitiative.add(terms, WARMTH_WEIGHT * minf(1.0, cold), "a stone home needs less firewood in the cold")
			else:
				FamilyInitiative.add(terms, LASTING_WEIGHT, "stone needs fewer tools to keep up")
			add_value(terms, household, "perfectionist", VALUE_WEIGHT, "it wants work that lasts")
			add_value(terms, household, "keepers_of_craft", VALUE_WEIGHT * (1.0 if material == EconomyBalance.MATERIAL_DRESSED else 0.5), "it values good craft")
			add_value(terms, household, "expedient", -VALUE_WEIGHT, "it would rather build quickly")
		if material == EconomyBalance.MATERIAL_DRESSED:
			add_value(terms, household, "thrifty", -VALUE_WEIGHT, "dressed stone is costly")
		var score: float = FamilyInitiative.sum(terms) + NOISE * FamilyInitiative.get_noise(city, household, "material_" + material + "_" + building_type)
		options.append({"material": material, "score": score, "terms": terms})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]) or (is_equal_approx(float(a["score"]), float(b["score"])) and EconomyBalance.MATERIALS.find(str(a["material"])) < EconomyBalance.MATERIALS.find(str(b["material"]))))
	return {"material": str(options[0]["material"]), "terms": options[0]["terms"], "options": options}

# How pressed the family is for shelter or food now, 0 to 1.
static func get_urgency(city: City, household: Household) -> float:
	var urgency: float = 0.0
	if household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household):
		urgency += 0.5
	urgency += 0.5 * clampf(float(FamilyInitiative.get_hardship(city, household)["level"]), 0.0, 1.0)
	return minf(1.0, urgency)

static func add_value(terms: Array, household: Household, value_id: String, weight: float, reason: String) -> void:
	var strength: int = HouseholdCharacter.get_strength(household, value_id)
	if strength > 0:
		FamilyInitiative.add(terms, weight * float(strength), reason)
