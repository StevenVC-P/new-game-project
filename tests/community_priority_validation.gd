extends SceneTree

# Community priorities (docs/COMMUNITY_PRIORITIES.md): one primary priority replaces the four work
# asks; it is persuasion added to decisions families already make, scaled by how receptive each
# family is to that kind of request; the stores rule stays separate; families judge each priority
# for themselves; the player is warned of costs, never stopped.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_priority_sets_the_asks_not_the_stores_rule()
	test_stores_rule_follows_the_priority()
	test_receptiveness_depends_on_the_request()
	test_housing_draws_help_and_long_days_to_homes()
	test_cooperation_draws_help_to_any_site()
	test_families_judge_each_priority()
	test_backing_pulls_like_a_norm()
	test_homes_first_for_builders()
	test_warnings()
	test_responses_and_sway_are_recorded()
	test_families_choose_own_home_sites()
	test_saved_with_the_town()

	if failure_count > 0:
		push_error("Community priority validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Community priority validation passed.")
	quit()

func social_city() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.social.set_enabled(true)
	for household: Household in city.households:
		blank(household)
	return city

# A household with no marked temperament and no strong conviction, then the given ones.
func blank(household: Household, axes: Dictionary = {}, strengths: Dictionary = {}) -> Household:
	for axis: String in HouseholdCharacter.AXES:
		household.personality[axis] = int(axes.get(axis, 0))
	household.value_strengths.clear()
	for value_id: String in HouseholdCharacter.get_held_values(household):
		household.value_strengths[value_id] = 0
	for value_id: String in strengths.keys():
		household.value_strengths[value_id] = int(strengths[value_id])
	household.ties.clear()
	household.memories.clear()
	household.trust = 0
	return household

func give_holding(city: City, household: Household, building_type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, building_type, origin, city.construction.get_size(building_type))
	city.add_building(building, household)
	return building

func home_project(city: City, household: Household, origin: Vector2i) -> ConstructionProject:
	return city.construction.request_building("house", origin, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)

func has_reason(terms: Array, fragment: String) -> bool:
	return terms.any(func(term: Dictionary) -> bool: return str(term["reason"]).contains(fragment))

# --- Tests -----------------------------------------------------------------------------------------

func test_priority_sets_the_asks_not_the_stores_rule() -> void:
	var city: City = social_city()
	_check(city.influence.priority == CommunityPriority.NONE and city.influence.encouraged.is_empty(), "a town starts with no priority and no asks")
	city.influence.set_priority(CommunityPriority.INVESTMENT)
	_check(city.influence.is_encouraged(TownInfluence.ACTIVITY_IMPROVE) and city.influence.is_encouraged(TownInfluence.ACTIVITY_TOOLS), "investment asks for better work and tools")
	city.influence.set_priority(CommunityPriority.FOOD)
	_check(city.influence.encouraged.size() == 1 and city.influence.is_encouraged(TownInfluence.ACTIVITY_FOOD), "one priority at a time: food replaces investment's asks")
	_check(city.influence.store_rule == TownInfluence.RULE_OPEN, "setting a priority leaves the stores rule as the player set it")
	city.influence.set_priority(CommunityPriority.HOUSING)
	_check(city.influence.encouraged.is_empty(), "housing asks nothing of families' own work")

func test_stores_rule_follows_the_priority() -> void:
	var city: City = social_city()
	var farm_cost: Dictionary = EconomyBalance.get_build_cost("farm")
	var food_and_improve: Array[String] = [TownInfluence.ACTIVITY_FOOD, TownInfluence.ACTIVITY_IMPROVE]
	var tools_and_improve: Array[String] = [TownInfluence.ACTIVITY_TOOLS, TownInfluence.ACTIVITY_IMPROVE]
	city.influence.set_priority(CommunityPriority.HOUSING)
	_check(city.influence.get_funding_block(farm_cost, food_and_improve) == "", "with the stores open, the housing priority holds no improvement back")
	city.influence.store_rule = TownInfluence.RULE_PRIORITIES
	_check(city.influence.get_funding_block(farm_cost, food_and_improve) != "", "with the stores kept for priorities, housing funds no improvement")
	city.influence.set_priority(CommunityPriority.FOOD)
	_check(city.influence.get_funding_block(farm_cost, food_and_improve) == "", "the food priority funds a farm")
	_check(city.influence.get_funding_block(EconomyBalance.get_build_cost("toolmaker"), tools_and_improve) != "", "but not a toolmaker")

func test_receptiveness_depends_on_the_request() -> void:
	var city: City = social_city()
	var free: Household = blank(city.households[0], {}, {"self_governing": 2})
	var directed: float = float(FamilyInitiative.get_receptiveness(free, city, CommunityPriority.KIND_DIRECTING)["factor"])
	var voluntary: float = float(FamilyInitiative.get_receptiveness(free, city, CommunityPriority.KIND_VOLUNTARY)["factor"])
	_check(directed < 1.0 and is_equal_approx(voluntary, 1.0), "a self-governing family resists being directed (%.2f) but not a request for time freely given (%.2f)" % [directed, voluntary])
	var communal: Household = blank(city.households[1], {}, {"communal_labor": 2})
	var communal_directed: float = float(FamilyInitiative.get_receptiveness(communal, city, CommunityPriority.KIND_DIRECTING)["factor"])
	var communal_voluntary: float = float(FamilyInitiative.get_receptiveness(communal, city, CommunityPriority.KIND_VOLUNTARY)["factor"])
	_check(is_equal_approx(communal_directed, 1.0) and communal_voluntary > 1.0, "valuing working together bears on giving time together (%.2f), not on its own work (%.2f)" % [communal_voluntary, communal_directed])
	var plain: float = float(FamilyInitiative.get_receptiveness(free, city)["factor"])
	_check(is_equal_approx(plain, directed), "the norms' appeals (no kind) weigh self-government as before")

func test_housing_draws_help_and_long_days_to_homes() -> void:
	var city: City = social_city()
	var helper: Household = blank(city.households[0])
	give_holding(city, helper, "farm", Vector2i(28, 4))
	var builder: Household = city.households[1]
	var home: ConstructionProject = home_project(city, builder, Vector2i(34, 24))
	var store: ConstructionProject = city.construction.request_building(Building.BUILDING_STOREHOUSE, Vector2i(40, 24))
	var before: Dictionary = SocialDecisions.get_help_desire(city, helper, home, builder)
	city.influence.set_priority(CommunityPriority.HOUSING)
	var after: Dictionary = SocialDecisions.get_help_desire(city, helper, home, builder)
	_check(float(after["score"]) > float(before["score"]) and float(after["appeal"]) > 0.0 and has_reason(after["terms"], "the gathering puts homes first"), "the housing priority adds to a family's wish to help build a home, and says so")
	var store_desire: Dictionary = SocialDecisions.get_help_desire(city, helper, store, null)
	_check(float(store_desire["appeal"]) == 0.0, "but not to helping build a storehouse")
	var hours_before: float = float(SocialDecisions.get_hours_desire(city, helper, home, false)["score"])
	city.influence.set_priority(CommunityPriority.NONE)
	var hours_none: float = float(SocialDecisions.get_hours_desire(city, helper, home, false)["score"])
	_check(hours_before > hours_none, "and to its wish to work long days on a home (%.2f against %.2f)" % [hours_before, hours_none])
	city.influence.set_priority(CommunityPriority.HOUSING)
	var free: Household = blank(city.households[2], {}, {"self_governing": 3})
	var deferent: Household = blank(city.households[3], {}, {"deferential": 3})
	var free_appeal: float = float(SocialDecisions.get_help_desire(city, free, home, builder)["appeal"])
	var deferent_appeal: float = float(SocialDecisions.get_help_desire(city, deferent, home, builder)["appeal"])
	_check(free_appeal < deferent_appeal, "a self-governing family heeds the housing priority less than a deferential one (%.2f, %.2f)" % [free_appeal, deferent_appeal])

func test_cooperation_draws_help_to_any_site() -> void:
	var city: City = social_city()
	var helper: Household = blank(city.households[0], {}, {"self_governing": 2})
	give_holding(city, helper, "farm", Vector2i(28, 4))
	var store: ConstructionProject = city.construction.request_building(Building.BUILDING_STOREHOUSE, Vector2i(40, 24))
	var before: float = float(SocialDecisions.get_help_desire(city, helper, store, null)["score"])
	city.influence.set_priority(CommunityPriority.COOPERATION)
	var desire: Dictionary = SocialDecisions.get_help_desire(city, helper, store, null)
	_check(float(desire["score"]) > before and has_reason(desire["terms"], "the gathering puts working together first"), "cooperation adds to helping build the town's storehouse")
	_check(not has_reason(desire["terms"], "though it judges for itself"), "a self-governing family is not asked to change its own work, so it does not resist the request")

func test_families_judge_each_priority() -> void:
	var city: City = social_city()
	var tent: Household = blank(city.households[0])
	var view: Dictionary = CommunityPriority.get_view(city, tent, CommunityPriority.HOUSING)
	_check(view["stance"] == CommunityPriority.SUPPORTS and has_reason(view["terms"], "no proper home"), "a family without a proper home supports putting homes first, and says why")
	var free: Household = blank(city.households[1], {}, {"self_governing": 3, "solitary": 2})
	var cooperation: Dictionary = CommunityPriority.get_view(city, free, CommunityPriority.COOPERATION)
	_check(cooperation["stance"] == CommunityPriority.OPPOSES and has_reason(cooperation["terms"], "work alone"), "a solitary family opposes putting working together first")
	var directed: Dictionary = CommunityPriority.get_view(city, free, CommunityPriority.FOOD)
	_check(has_reason(directed["terms"], "families should decide their own work"), "a self-governing family weighs being directed against any directing priority")
	var together: Household = blank(city.households[2], {}, {"communal_labor": 2, "mutual_aid": 2})
	_check(CommunityPriority.get_view(city, together, CommunityPriority.COOPERATION)["stance"] == CommunityPriority.SUPPORTS, "a family that values working together supports cooperation")
	var views: Array[Dictionary] = CommunityPriority.get_views(city, CommunityPriority.HOUSING)
	_check(views.size() == city.households.size() and views.all(func(v: Dictionary) -> bool: return not (v["reasons"] as Array).is_empty() or v["stance"] == CommunityPriority.INDIFFERENT), "the preview gives every family's stance with its reasons")

func test_backing_pulls_like_a_norm() -> void:
	var city: City = social_city()
	# Every founding family is still without a proper home: the town backs housing.
	_check(CommunityPriority.get_backing(city, CommunityPriority.HOUSING) > 0.9, "a town of families without homes backs putting homes first")
	city.influence.set_priority(CommunityPriority.HOUSING)
	var helper: Household = city.households[0]
	give_holding(city, helper, "farm", Vector2i(28, 4))
	var home: ConstructionProject = home_project(city, city.households[1], Vector2i(34, 24))
	var desire: Dictionary = SocialDecisions.get_help_desire(city, helper, home, city.households[1])
	_check(has_reason(desire["terms"], "most families back putting homes first"), "what the town backs pulls on a family's decision")
	for household: Household in city.households:
		blank(household, {}, {"solitary": 3, "self_governing": 3})
	_check(CommunityPriority.get_backing(city, CommunityPriority.COOPERATION) < 0.1, "a town of solitary, self-governing families does not back cooperation")

func test_homes_first_for_builders() -> void:
	var city: City = social_city()
	var store: ConstructionProject = city.construction.request_building(Building.BUILDING_STOREHOUSE, Vector2i(40, 24))
	var home: ConstructionProject = home_project(city, city.households[0], Vector2i(34, 24))
	# One free family, so only one site gets builders today.
	for i in range(1, city.households.size()):
		give_holding(city, city.households[i], "gatherer_camp", Vector2i(4 + 3 * i, 30))
	city.households[0].assigned_workers = 0
	var other: Household = city.households[0]
	ConstructionTest.run_days(city, 1)
	_check(store.crew_household_ids.has(other.id) or home.crew_household_ids.has(other.id), "a free family builds somewhere")
	var store_first: bool = store.crew_household_ids.has(other.id)
	city.influence.set_priority(CommunityPriority.HOUSING)
	ConstructionTest.run_days(city, 1)
	_check(store_first and home.crew_household_ids.has(other.id), "the queue's first site gets the free builder, until homes are the priority")

func test_warnings() -> void:
	var city: City = social_city()
	var garden: Household = city.households[0]
	give_holding(city, garden, "forager_garden", Vector2i(28, 4))
	_check(CommunityPriority.get_warnings(city, CommunityPriority.FOOD, TownInfluence.RULE_OPEN).is_empty(), "food with the stores open costs nothing worth a warning")
	var closed: Array[String] = CommunityPriority.get_warnings(city, CommunityPriority.HOUSING, TownInfluence.RULE_PRIORITIES)
	_check(closed.any(func(w: String) -> bool: return w.contains("No family's improvement will be funded")), "housing with the stores kept for priorities warns that no improvement will be funded")
	_check(closed.any(func(w: String) -> bool: return w.contains("grow food by hand")), "and that food growers cannot improve into farms")
	_check(closed.any(func(w: String) -> bool: return w.contains("No home plots")), "and that no plots are set aside for families without homes")
	var food_rule: Array[String] = CommunityPriority.get_warnings(city, CommunityPriority.FOOD, TownInfluence.RULE_PRIORITIES)
	_check(food_rule.any(func(w: String) -> bool: return w.contains("No toolmaker will be funded")), "food with the stores kept for priorities warns about tools")
	city.influence.set_priority(CommunityPriority.HOUSING)
	city.influence.store_rule = TownInfluence.RULE_PRIORITIES
	_check(city.influence.priority == CommunityPriority.HOUSING and city.influence.store_rule == TownInfluence.RULE_PRIORITIES, "a warning never stops the player")

func test_responses_and_sway_are_recorded() -> void:
	var city: City = social_city()
	city.influence.set_priority(CommunityPriority.HOUSING)
	_check(city.influence.responses.size() == city.households.size() and city.influence.responses.all(func(r: Dictionary) -> bool: return r["priority"] == CommunityPriority.HOUSING), "each family's view is recorded when the priority is set")
	_check(CommunityPriority.is_swayed(2.0, 1.0, 1.5) and not CommunityPriority.is_swayed(3.0, 1.0, 1.5) and not CommunityPriority.is_swayed(1.0, 1.0, 1.5), "a decision is swayed only when the appeal carried it over the line")
	var household: Household = city.households[0]
	CommunityPriority.record_swayed(city, household, "long_days", "It worked long days on a home because the gathering put homes first")
	CommunityPriority.record_swayed(city, household, "long_days", "It worked long days on a home because the gathering put homes first")
	_check(int(city.influence.swayed.get("housing:long_days", 0)) == 2, "every swayed decision is counted")
	_check(household.memories.filter(func(m: Dictionary) -> bool: return m["kind"] == "priority").size() == 1, "and the family remembers the sacrifice once, not every week")

# Laying out the town is not part of play for now (owner, 2026-10-31): where families lead, a family
# with no plot to claim chooses its own home site near its work; a plot, when there is one, comes first.
func test_families_choose_own_home_sites() -> void:
	var classic: City = ConstructionTest.make_city()
	FamilyDevelopment.advance(classic)
	_check(classic.construction.projects.filter(func(p: ConstructionProject) -> bool: return p.is_home()).is_empty(), "under the classic rules, families without plots start no homes")
	var city: City = social_city()
	var worker: Household = city.households[0]
	var camp: Building = give_holding(city, worker, "gatherer_camp", Vector2i(10, 30))
	var started: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	var own: Array = started.filter(func(p: ConstructionProject) -> bool: return p.is_home() and p.claimant_household_id == worker.id)
	_check(not own.is_empty() and (own[0] as ConstructionProject).plot_id < 0, "where families lead, a family with no plot chooses a site of its own")
	if not own.is_empty():
		var near: float = Vector2((own[0] as ConstructionProject).tile).distance_to(Vector2(TownLogistics.center_tile(camp.tile, camp.size)))
		_check(near <= FamilyDevelopment.OWN_SITE_RADIUS + 1, "near its work (%.1f tiles)" % near)
	var planned: City = social_city()
	var plot_id: int = planned.construction.designate_plot(Vector2i(30, 30))
	FamilyDevelopment.advance(planned)
	_check(plot_id >= 0 and planned.construction.projects.any(func(p: ConstructionProject) -> bool: return p.plot_id == plot_id), "an open plot is still claimed first")

func test_saved_with_the_town() -> void:
	var city: City = social_city()
	city.influence.set_priority(CommunityPriority.COOPERATION)
	city.influence.store_rule = TownInfluence.RULE_PRIORITIES
	ConstructionTest.run_days(city, 8)
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	_check(loaded.influence.priority == CommunityPriority.COOPERATION and loaded.influence.store_rule == TownInfluence.RULE_PRIORITIES, "a loaded town keeps its priority and its stores rule")
	_check(loaded.influence.responses.size() == city.influence.responses.size(), "and the families' recorded views")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
