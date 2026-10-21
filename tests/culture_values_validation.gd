extends SceneTree

# M1 values foundation (docs/IMPLEMENTATION_ROADMAP.md, docs/CULTURE_AND_VALUES_MODEL.md).

const CityScript = preload("res://scripts/domain/city.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const CultureEffectsScript = preload("res://scripts/domain/culture_effects.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_random_profiles_follow_holding_rules()
	test_starter_households_have_values_matching_their_trade()
	test_founders_are_random_per_game()
	test_inheritance_keeps_most_parent_values()
	test_calling_match_quality()
	test_preference_is_derived_from_calling()
	test_calling_changes_output()
	test_work_ethic_changes_output_and_is_capped()
	test_kin_values_change_birth_chance()
	test_close_knit_delays_family_formation()
	test_leave_the_nest_claims_empty_house_first()
	test_new_family_inherits_values()
	test_defining_values_favor_rare_values()

	if failure_count > 0:
		push_error("Culture values validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Culture values validation passed.")
	quit()

func test_random_profiles_follow_holding_rules() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for index in range(300):
		var profile: Dictionary = CultureValuesScript.make_random_profile(rng)
		if not CultureValuesScript.is_valid_profile(profile):
			_check(false, "random profile should hold 1-2 non-conflicting values in every category: " + str(profile))
			return
	_check(CultureValuesScript.values_conflict("thrifty", "lavish"), "opposites should conflict")
	_check(CultureValuesScript.values_conflict("fathers_line", "strongest_line"), "lineage rules should be mutually exclusive")
	_check(not CultureValuesScript.values_conflict("thrifty", "sharing"), "unrelated values should not conflict")

func test_starter_households_have_values_matching_their_trade() -> void:
	var city = CityScript.new("Seed Town", Vector2(10, 10), CityScript.ROLE_PLAYER, 4)
	for household: Household in city.households:
		_check(household.has_values(), "starter household should have values")
		_check(CultureValuesScript.is_valid_profile(household.values), "starter household values should be valid")
		if household.family_trade == "farming":
			_check(household.values[CultureValuesScript.CATEGORY_CALLING].has("soil"), "farming family should be called to the soil")
		if household.family_trade == "stonework":
			_check(household.values[CultureValuesScript.CATEGORY_CALLING].has("stone"), "stonework family should be called to stone")

	var again = CityScript.new("Seed Town", Vector2(10, 10), CityScript.ROLE_PLAYER, 4)
	_check(str(again.households[0].values) == str(city.households[0].values), "seeded values should be deterministic for the same town")

func test_founders_are_random_per_game() -> void:
	var seen_callings: Dictionary = {}
	for game_seed in range(1, 21):
		var city = CityScript.new("Seed Town", Vector2(10, 10), CityScript.ROLE_PLAYER, 4, game_seed)
		for household: Household in city.households:
			_check(household.lifecycle_stage != Household.LIFECYCLE_OLD_COUPLE, "founders should never start as old couples")
			_check(household.total_population == household.working_adults + household.get_total_child_count(), "founder population should match its family")
			for calling in household.values[CultureValuesScript.CATEGORY_CALLING]:
				seen_callings[calling] = true
	_check(seen_callings.size() >= 8, "founding callings should vary across games, saw " + str(seen_callings.keys()))
	for game_seed in range(1, 41):
		var town = CityScript.new("Seed Town", Vector2(3, 4), CityScript.ROLE_PLAYER, 4, game_seed)
		var has_farmer: bool = false
		for household: Household in town.households:
			has_farmer = has_farmer or CultureValuesScript.has_value(household.values, "soil")
			_check(CultureValuesScript.is_valid_profile(household.values), "founder profiles should stay valid after the farmer guarantee")
			if CultureValuesScript.has_value(household.values, "soil"):
				_check(household.family_trade == "farming", "a founder called to the soil should farm")
		_check(has_farmer, "every founding should include a family called to the soil (seed " + str(game_seed) + ")")
	var first = CityScript.new("Seed Town", Vector2(10, 10), CityScript.ROLE_PLAYER, 4, 77)
	var again = CityScript.new("Seed Town", Vector2(10, 10), CityScript.ROLE_PLAYER, 4, 77)
	_check(str(first.households[0].values) == str(again.households[0].values), "the same game seed should found the same families")

func test_inheritance_keeps_most_parent_values() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var kept: int = 0
	var total: int = 0
	for index in range(200):
		var parent: Dictionary = CultureValuesScript.make_random_profile(rng)
		var child: Dictionary = CultureValuesScript.inherit_profile([parent], rng, {})
		if not CultureValuesScript.is_valid_profile(child):
			_check(false, "inherited profile should be valid: " + str(child))
			return
		for category in parent.keys():
			for value_id in parent[category]:
				total += 1
				if (child[category] as Array).has(value_id):
					kept += 1
	var keep_rate: float = float(kept) / float(total)
	_check(keep_rate > 0.7 and keep_rate < 0.95, "children should keep most but not all parent values, got " + str(keep_rate))

func test_calling_match_quality() -> void:
	var soil: Dictionary = _profile(["soil"], ["solitary"], ["fathers_line"])
	var hearth: Dictionary = _profile(["hearth"], ["solitary"], ["fathers_line"])
	_check(CultureEffectsScript.get_calling_match(soil, Building.BUILDING_FARM) == "good match", "soil family should match a farm")
	_check(CultureEffectsScript.get_calling_match(soil, Building.BUILDING_QUARRY) == "poor match", "soil-only family should be a poor match for a quarry")
	_check(CultureEffectsScript.get_calling_match(hearth, Building.BUILDING_QUARRY) == "neutral", "hearth family should be neutral at a quarry")

func test_preference_is_derived_from_calling() -> void:
	var household: Household = Household.new(1, -1, Household.WORK_PREF_INDUSTRIAL, 4, Household.RESIDENCE_HOUSED)
	household.set_values(_profile(["soil"], ["solitary"], ["fathers_line"]))
	_check(household.preference == Household.WORK_PREF_AGRARIAN, "display preference should follow the calling")
	_check(household.get_match_quality(Building.BUILDING_FARM) == "good match", "household match quality should use its calling")

func test_calling_changes_output() -> void:
	var good: int = _farm_output_over(100, _profile(["soil"], ["solitary"], ["fathers_line"]))
	var neutral: int = _farm_output_over(100, _profile(["hearth"], ["solitary"], ["fathers_line"]))
	var poor: int = _farm_output_over(100, _profile(["stone"], ["solitary"], ["fathers_line"]))
	# A two-adult family's farm output over 100 days: +25% matched, unchanged neutral, -25% poor.
	var hundred_days: float = EconomyBalance.FARM_FOOD_PER_DAY * 100.0
	_check(abs(good - hundred_days * 1.25) <= 1, "matched calling should raise farm output by 25%, got " + str(good))
	_check(abs(neutral - hundred_days) <= 1, "neutral calling should leave farm output unchanged, got " + str(neutral))
	_check(abs(poor - hundred_days * 0.75) <= 1, "poor match should lower farm output by 25%, got " + str(poor))

func test_work_ethic_changes_output_and_is_capped() -> void:
	var leisurely: int = _farm_output_over(100, _profile(["hearth"], ["leisurely"], ["fathers_line"]))
	_check(abs(leisurely - EconomyBalance.FARM_FOOD_PER_DAY * 100.0 * 0.9) <= 1, "leisurely family should produce 10% less, got " + str(leisurely))
	var capped_percent: int = CultureEffectsScript.get_work_output_percent(_profile(["soil"], ["industrious", "expedient"], ["fathers_line"]), Building.BUILDING_FARM)
	_check(capped_percent == CultureEffectsScript.OUTPUT_PERCENT_CAP, "stacked bonuses should cap at the output limit, got " + str(capped_percent))
	var communal_alone: int = CultureEffectsScript.get_work_output_percent(_profile(["hearth"], ["communal_labor"], ["fathers_line"]), Building.BUILDING_FARM, {"same_type_operating_others": 0})
	var communal_group: int = CultureEffectsScript.get_work_output_percent(_profile(["hearth"], ["communal_labor"], ["fathers_line"]), Building.BUILDING_FARM, {"same_type_operating_others": 2})
	_check(communal_group > communal_alone, "communal labor should do better alongside others")

func test_kin_values_change_birth_chance() -> void:
	var city = _empty_city_with_food()
	var many: Household = _housed_household(city, 1, _profile(["soil"], ["solitary"], ["many_children"]))
	var few: Household = _housed_household(city, 2, _profile(["soil"], ["solitary"], ["few_children"]))
	many.lifecycle_stage = Household.LIFECYCLE_YOUNG_FAMILY
	few.lifecycle_stage = Household.LIFECYCLE_YOUNG_FAMILY
	city.update_shelter_counts()
	_check(city.get_birth_roll_chance(few) > 0, "test families should be eligible for births")
	_check(city.get_birth_roll_chance(many) > city.get_birth_roll_chance(few), "many-children family should have a higher birth chance")

# Since M3 a new family needs grown children from two households, so these tests pair two.
func test_close_knit_delays_family_formation() -> void:
	var close_city = _empty_city_with_food()
	for household_id in [1, 2]:
		_add_marriageable_child(_housed_household(close_city, household_id, _profile(["soil"], ["solitary"], ["close_knit"])))
	_add_house(close_city)
	for month in range(CultureEffectsScript.CLOSE_KNIT_FORMATION_DELAY_MONTHS):
		close_city.advance_new_family_formation_month()
	_check(close_city.households.size() == 2, "close-knit families should keep their children home during the delay")
	close_city.advance_new_family_formation_month()
	_check(close_city.households.size() == 3, "close-knit families should marry their children off after the delay")

	var plain_city = _empty_city_with_food()
	for household_id in [1, 2]:
		_add_marriageable_child(_housed_household(plain_city, household_id, _profile(["soil"], ["solitary"], ["fathers_line"])))
	_add_house(plain_city)
	plain_city.advance_new_family_formation_month()
	_check(plain_city.households.size() == 3, "families without close-knit should form a family in the first month")

func test_leave_the_nest_claims_empty_house_first() -> void:
	var city = _empty_city_with_food()
	var first: Household = _housed_household(city, 1, _profile(["soil"], ["solitary"], ["fathers_line"]))
	var second: Household = _housed_household(city, 2, _profile(["soil"], ["solitary"], ["fathers_line"]))
	var nest: Household = _housed_household(city, 3, _profile(["soil"], ["solitary"], ["leave_the_nest"]))
	for parent: Household in [first, second, nest]:
		_add_marriageable_child(parent)
	_add_house(city)
	city.advance_new_family_formation_month()
	_check(city.households.size() == 4, "one family should form into the single empty house")
	_check(city.households[3].is_child_of(nest.id), "leave-the-nest family should marry into the empty house first")

func test_new_family_inherits_values() -> void:
	var city = _empty_city_with_food()
	for household_id in [1, 2]:
		_add_marriageable_child(_housed_household(city, household_id, _profile(["soil"], ["industrious"], ["many_children"])))
	_add_house(city)
	city.advance_new_family_formation_month()
	_check(city.households.size() == 3, "new family should form")
	var child: Household = city.households[2]
	_check(child.has_values() and CultureValuesScript.is_valid_profile(child.values), "new family should have a valid value profile")

func _add_marriageable_child(household: Household) -> void:
	household.adult_children = 1
	household.total_population += 1

func test_defining_values_favor_rare_values() -> void:
	var city = _empty_city_with_food()
	for index in range(4):
		_housed_household(city, index, _profile(["soil"], ["solitary"], ["fathers_line"]))
	var odd: Household = _housed_household(city, 9, _profile(["muse"], ["solitary"], ["fathers_line"]))
	var defining: Array[String] = city.get_household_defining_values(odd)
	_check(defining.has("muse"), "a calling no one else holds should be defining, got " + str(defining))

func _farm_output_over(days: int, profile: Dictionary) -> int:
	var city = _empty_city_with_food()
	var household: Household = _housed_household(city, 1, profile)
	var farm: Building = Building.new(city.buildings.size(), Building.BUILDING_FARM)
	city.buildings.append(farm)
	farm.assign_household(household, Building.ASSIGNMENT_PLAYER)
	var food_before: int = int(city.resources["food"])
	for day in range(days):
		city.resources["production_tick_count"] = day
		city.apply_building_production(farm)
	return int(city.resources["food"]) - food_before

func _empty_city_with_food():
	var city = CityScript.new("Test", Vector2.ZERO, CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = 1000
	city.resources["food_consumption_rate"] = 2
	city.resources["food_shortage"] = false
	return city

func _add_house(city) -> Building:
	var house: Building = Building.new(city.buildings.size(), Building.BUILDING_HOUSE)
	city.buildings.append(house)
	return house

func _housed_household(city, household_id: int, profile: Dictionary) -> Household:
	var house: Building = _add_house(city)
	var household: Household = Household.new(household_id, house.id, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	household.working_adults = 2
	household.update_labor_capacity()
	household.move_to_house(house.id)
	household.set_values(profile)
	city.households.append(household)
	return household

# Full valid profile with the three categories this milestone reads fixed; the rest are filled.
func _profile(callings: Array, work_ethic: Array, kin: Array) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	return CultureValuesScript.make_random_profile(rng, {
		CultureValuesScript.CATEGORY_CALLING: callings,
		CultureValuesScript.CATEGORY_WORK_ETHIC: work_ethic,
		CultureValuesScript.CATEGORY_KIN: kin
	})

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
