extends SceneTree

# M3: marriage between lineages (docs/IMPLEMENTATION_ROADMAP.md, docs/HOUSES_AND_LINEAGE_MODEL.md).

const CityScript = preload("res://scripts/domain/city.gd")
const CultureValuesScript = preload("res://scripts/domain/culture_values.gd")
const LifecycleDisplayScript = preload("res://scripts/ui/household_lifecycle_display_helper.gd")

var failure_count: int = 0
# Typed empty array: find_marriage_partner takes Array[int], and an untyped [] aborts the call.
var NONE_MARRIED: Array[int] = []

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_children_of_two_households_marry()
	test_siblings_do_not_marry_each_other()
	test_lone_child_marries_outsider_after_waiting()
	test_lineage_rule_picks_the_lineage()
	test_rule_resolution_uses_town_when_families_disagree()
	test_new_family_draws_values_from_both_parents()
	test_clannish_families_marry_within_lineage()
	test_others_marry_outside_their_lineage()
	test_work_succession_counts_children_of_either_parent()
	test_lineage_display_names_both_parents()

	if failure_count > 0:
		push_error("Marriage lineage validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Marriage lineage validation passed.")
	quit()

func test_children_of_two_households_marry() -> void:
	var city = _city()
	var first: Household = _household(city, 1, ["fathers_line"])
	var second: Household = _household(city, 2, ["fathers_line"])
	_add_child(first)
	_add_child(second)
	var population_before: int = city.get_total_population()
	_add_house(city)
	city.advance_new_family_formation_month()
	_check(city.households.size() == 3, "two grown children from different households should marry")
	var couple: Household = city.households[2]
	_check(first.adult_children == 0 and second.adult_children == 0, "each parent household should give one grown child")
	_check(couple.working_adults == 2 and couple.total_population == 2, "the new family should be a couple")
	_check(couple.is_child_of(first.id) and couple.is_child_of(second.id), "the new family should record both parent households")
	_check(not couple.spouse_from_outside, "a marriage within town should not be marked as an outside spouse")
	_check(city.get_total_population() == population_before, "marriage should move people, not create them")

func test_siblings_do_not_marry_each_other() -> void:
	var city = _city()
	var parent: Household = _household(city, 1, ["fathers_line"])
	parent.adult_children = 2
	parent.total_population += 2
	_add_house(city)
	for month in range(CityScript.MARRIAGE_OUTSIDER_WAIT_MONTHS):
		city.advance_new_family_formation_month()
	_check(city.households.size() == 1, "two grown children of one household should not marry each other")

func test_lone_child_marries_outsider_after_waiting() -> void:
	var city = _city()
	var parent: Household = _household(city, 1, ["fathers_line"])
	_add_child(parent)
	_add_house(city)
	for month in range(CityScript.MARRIAGE_OUTSIDER_WAIT_MONTHS + 1):
		city.advance_new_family_formation_month()
	_check(city.households.size() == 2, "a grown child with no partner in town should marry an outsider after waiting")
	if city.households.size() < 2:
		return
	var couple: Household = city.households[1]
	_check(couple.spouse_from_outside, "the new family should be marked as having an outside spouse")
	_check(couple.parent_household_id == parent.id and couple.second_parent_household_id == -1, "an outside marriage joins the town household's lineage")
	_check(couple.total_population == 2, "the outside spouse should join the household")
	_check(CultureValuesScript.is_valid_profile(couple.values), "the new family should have a valid profile")

func test_lineage_rule_picks_the_lineage() -> void:
	var city = _city()
	var groom: Household = _household(city, 1, ["fathers_line"])
	var bride: Household = _household(city, 2, ["fathers_line"])
	var bride_cousin: Household = _household(city, 3, ["fathers_line"])
	bride_cousin.origin_household_id = bride.id
	_check(city.choose_lineage_parent(groom, bride, "fathers_line") == groom, "father's line should follow the groom's household")
	_check(city.choose_lineage_parent(groom, bride, "mothers_line") == bride, "mother's line should follow the bride's household")
	_check(city.choose_lineage_parent(groom, bride, "strongest_line") == bride, "strongest line should follow the lineage with more households")

func test_rule_resolution_uses_town_when_families_disagree() -> void:
	var city = _city()
	var fathers: Household = _household(city, 1, ["fathers_line"])
	var mothers: Household = _household(city, 2, ["mothers_line"])
	var mothers_too: Household = _household(city, 3, ["mothers_line"])
	_check(city.resolve_marriage_lineage_rule(mothers, mothers_too) == "mothers_line", "families that agree should use their shared rule")
	_check(city.resolve_marriage_lineage_rule(fathers, mothers) == "mothers_line", "families that disagree should follow the town's most common rule")

func test_new_family_draws_values_from_both_parents() -> void:
	var saw_first_calling: bool = false
	var saw_second_calling: bool = false
	for trial in range(30):
		var city = CityScript.new("Trial", Vector2(trial, trial), CityScript.ROLE_PLAYER, 0)
		city.resources["food"] = 1000
		var first: Household = _household(city, 1, ["fathers_line"], ["soil"])
		var second: Household = _household(city, 2, ["fathers_line"], ["muse"])
		_add_child(first)
		_add_child(second)
		_add_house(city)
		city.advance_new_family_formation_month()
		if city.households.size() < 3:
			continue
		var callings: Array = city.households[2].values[CultureValuesScript.CATEGORY_CALLING]
		saw_first_calling = saw_first_calling or callings.has("soil")
		saw_second_calling = saw_second_calling or callings.has("muse")
	_check(saw_first_calling and saw_second_calling, "children should inherit values from both parent households")

func test_clannish_families_marry_within_lineage() -> void:
	var city = _city()
	var clannish: Household = _household(city, 1, ["fathers_line"], ["soil"], ["clannish"])
	var cousin: Household = _household(city, 2, ["fathers_line"], ["soil"], ["clannish"])
	var stranger: Household = _household(city, 3, ["fathers_line"])
	cousin.origin_household_id = clannish.id
	for household: Household in [clannish, cousin, stranger]:
		_add_child(household)
	var ready: Array[Household] = [clannish, cousin, stranger]
	_check(city.find_marriage_partner(clannish, ready, NONE_MARRIED) == cousin, "clannish families should prefer a partner from their own lineage")

func test_others_marry_outside_their_lineage() -> void:
	var city = _city()
	var plain: Household = _household(city, 1, ["fathers_line"])
	var cousin: Household = _household(city, 2, ["fathers_line"])
	var stranger: Household = _household(city, 3, ["fathers_line"])
	cousin.origin_household_id = plain.id
	for household: Household in [plain, cousin, stranger]:
		_add_child(household)
	var ready: Array[Household] = [plain, cousin, stranger]
	_check(city.find_marriage_partner(plain, ready, NONE_MARRIED) == stranger, "most families should prefer a partner from another lineage")

func test_work_succession_counts_children_of_either_parent() -> void:
	var city = _city()
	var parent: Household = _household(city, 1, ["fathers_line"])
	var child: Household = _household(city, 2, ["fathers_line"])
	child.parent_household_id = 9
	child.second_parent_household_id = parent.id
	child.family_trade = parent.family_trade
	_check(city.get_work_succession_priority(parent, child) == "direct_child_same_trade", "a child through the second parent should count as a direct child for work succession")
	_check(city.get_household_descendants(parent.id).has(child), "descendants should include children through either parent")

func test_lineage_display_names_both_parents() -> void:
	var city = _city()
	var child: Household = _household(city, 5, ["fathers_line"])
	child.parent_household_id = 1
	child.second_parent_household_id = 2
	child.generation = 1
	child.lifecycle_stage = Household.LIFECYCLE_NEWLYWED
	var lines: Array[String] = LifecycleDisplayScript.get_lifecycle_lines(child, city)
	_check(lines.has("Lineage: Child of Household 2 and Household 3, generation 1"), "lineage display should name both parent households, got " + str(lines))
	child.second_parent_household_id = -1
	child.spouse_from_outside = true
	lines = LifecycleDisplayScript.get_lifecycle_lines(child, city)
	_check(lines.has("Lineage: Child of Household 2 and a spouse from outside, generation 1"), "lineage display should mention an outside spouse, got " + str(lines))

# --- helpers ---

func _city():
	var city = CityScript.new("Test", Vector2(7, 7), CityScript.ROLE_PLAYER, 0)
	city.resources["food"] = 1000
	return city

func _household(city, household_id: int, kin: Array, callings: Array = ["soil"], community: Array = ["welcoming"]) -> Household:
	var house: Building = _add_house(city)
	var household: Household = Household.new(household_id, house.id, Household.WORK_PREF_NEUTRAL, 2, Household.RESIDENCE_HOUSED)
	household.working_adults = 2
	household.update_labor_capacity()
	household.move_to_house(house.id)
	household.family_trade = "farming"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = household_id
	household.set_values(CultureValuesScript.make_random_profile(rng, {
		CultureValuesScript.CATEGORY_CALLING: callings,
		CultureValuesScript.CATEGORY_KIN: kin,
		CultureValuesScript.CATEGORY_COMMUNITY: community
	}))
	city.households.append(household)
	return household

func _add_child(household: Household) -> void:
	household.adult_children += 1
	household.total_population += 1

func _add_house(city) -> Building:
	var house: Building = Building.new(city.buildings.size(), Building.BUILDING_HOUSE)
	city.buildings.append(house)
	return house

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
