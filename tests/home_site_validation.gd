extends SceneTree

# Household home-site selection (HomeSites): families choose where to build their homes by what they
# value, on land the player set aside; the player can prefer an area without forcing it; without
# land families cannot build and say why; sites never overlap; every choice is explained from the
# terms that made it.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

# Work away from the stockpile at the test map's centre; MIDDLE lies halfway between two blocks of land.
const WORK: Vector2i = Vector2i(20, 16)
const MIDDLE: Vector2i = Vector2i(29, 14)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_preferences_choose_different_sites()
	test_values_shape_the_terms()
	test_preferred_land_persuades_without_forcing()
	test_prohibited_land_is_respected()
	test_no_land_means_no_home()
	test_sites_never_overlap()
	test_explanations_follow_the_terms()
	test_rough_ranking_matches_the_terms()
	test_starting_land()
	test_land_is_reserved_for_homes()
	test_saved_with_the_town()

	if failure_count > 0:
		push_error("Home site validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Home site validation passed.")
	quit()

# A town of unhoused families with no marked temperament or conviction.
func make_city() -> City:
	var city: City = ConstructionTest.make_city()
	city.resources["wood"] = 200
	for household: Household in city.households:
		blank(household)
	return city

func blank(household: Household, axes: Dictionary = {}, strengths: Dictionary = {}) -> Household:
	for axis: String in HouseholdCharacter.AXES:
		household.personality[axis] = int(axes.get(axis, 0))
	household.value_strengths.clear()
	for value_id: String in HouseholdCharacter.get_held_values(household):
		household.value_strengths[value_id] = 0
	for value_id: String in strengths.keys():
		household.value_strengths[value_id] = int(strengths[value_id])
	household.values.erase(CultureValues.CATEGORY_HOME_PLACE)
	household.values[CultureValues.CATEGORY_CALLING] = []
	household.ties.clear()
	household.ambition = ""
	return household

func give_work(city: City, household: Household, tile: Vector2i = WORK) -> Building:
	var camp: Building = Building.new(-1, "gatherer_camp", tile, city.construction.get_size("gatherer_camp"))
	city.add_building(camp, household)
	return camp

func house(city: City, household: Household, tile: Vector2i) -> Building:
	var home: Building = Building.new(-1, "house", tile, Vector2i.ONE)
	city.add_building(home, household)
	return home

func has_reason(terms: Array, fragment: String) -> bool:
	return terms.any(func(term: Dictionary) -> bool: return str(term["reason"]).contains(fragment))

func distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b))

# --- Tests -----------------------------------------------------------------------------------------

# 1. Two families with the same work and the same land on offer settle apart because they value
# different things: a close-knit family beside its parents, a solitary one that likes its distance away.
func test_preferences_choose_different_sites() -> void:
	var city: City = make_city()
	var parent: Household = city.households[0]
	house(city, parent, Vector2i(16, 26))
	var close: Household = blank(city.households[1], {}, {"close_knit": 3})
	var apart: Household = blank(city.households[2], {HouseholdCharacter.SOCIABILITY: -2}, {"leave_the_nest": 3, "solitary": 3})
	for child: Household in [close, apart]:
		child.parent_household_id = parent.id
		give_work(city, child, MIDDLE + Vector2i(0, 3 * (child.id - 1)))
	HomeSites.mark(city, Vector2i(14, 20), Vector2i(18, 24), HomeSites.LAND_PERMITTED)
	HomeSites.mark(city, Vector2i(40, 20), Vector2i(44, 24), HomeSites.LAND_PERMITTED)
	var close_site: Vector2i = HomeSites.choose(city, close, Building.BUILDING_HOUSE)["tile"]
	var apart_site: Vector2i = HomeSites.choose(city, apart, Building.BUILDING_HOUSE)["tile"]
	var kin_home: Vector2i = Vector2i(16, 26)
	_check(close_site.x >= 0 and distance(close_site, kin_home) < 8.0, "a close-knit family settles beside its parents (%s)" % str(close_site))
	_check(apart_site.x >= 0 and distance(apart_site, kin_home) > 20.0, "a solitary family that likes to leave the nest settles across town (%s)" % str(apart_site))

# The considerations each family weighs come from its own values and calling.
func test_values_shape_the_terms() -> void:
	var city: City = make_city()
	var farmer: Household = blank(city.households[0])
	farmer.values[CultureValues.CATEGORY_CALLING] = ["soil"]
	var other: Household = blank(city.households[1])
	city.logistics.ensure_ready()
	var by_fields: Vector2i = Vector2i(20, 11)
	var farmer_terms: Array = HomeSites.get_terms(city, farmer, by_fields, HomeSites.get_context(city, farmer), false)
	var other_terms: Array = HomeSites.get_terms(city, other, by_fields, HomeSites.get_context(city, other), false)
	_check(farmer.get_match_quality("farm") == CultureEffects.MATCH_GOOD and has_reason(farmer_terms, "near fertile land") and not has_reason(other_terms, "near fertile land"), "a farming family weighs fertile land near its home; others do not")
	var on_field: Array = HomeSites.get_terms(city, farmer, Vector2i(20, 5), HomeSites.get_context(city, farmer), false)
	_check(on_field.any(func(t: Dictionary) -> bool: return str(t["reason"]).contains("good farmland") and float(t["weight"]) < 0.0), "and is loath to build on good farmland itself")
	var cautious: Household = blank(city.households[2], {HouseholdCharacter.RISK: -2})
	var daring: Household = blank(city.households[3], {HouseholdCharacter.RISK: 2})
	var shore: Vector2i = Vector2i(12, 32)
	var cautious_terms: Array = HomeSites.get_terms(city, cautious, shore, HomeSites.get_context(city, cautious), false)
	var daring_terms: Array = HomeSites.get_terms(city, daring, shore, HomeSites.get_context(city, daring), false)
	_check(cautious_terms.any(func(t: Dictionary) -> bool: return t["factor"] == "safety" and float(t["weight"]) < 0.0) and not daring_terms.any(func(t: Dictionary) -> bool: return t["factor"] == "safety"), "a cautious family avoids ground beside water that floods; a daring one does not mind")
	var town_loving: Household = blank(city.households[4])
	town_loving.values[CultureValues.CATEGORY_HOME_PLACE] = ["town_loving"]
	_check(has_reason(HomeSites.get_terms(city, town_loving, Vector2i(5, 5), HomeSites.get_context(city, town_loving), false), "the town's heart"), "a town-loving family weighs the town's heart")

# 2. Preferred land draws families by how receptive they are, without forcing any of them.
func test_preferred_land_persuades_without_forcing() -> void:
	var city: City = make_city()
	var plain_site: Vector2i = Vector2i(WORK.x + 3, WORK.y)
	var hoped: Vector2i = Vector2i(WORK.x + 5, WORK.y)
	HomeSites.mark(city, plain_site, plain_site, HomeSites.LAND_PERMITTED)
	var deferent: Household = blank(city.households[0], {}, {"deferential": 3})
	var free: Household = blank(city.households[1], {}, {"self_governing": 3})
	give_work(city, deferent)
	give_work(city, free, WORK)
	HomeSites.mark(city, hoped, hoped, HomeSites.LAND_PERMITTED)
	_check(HomeSites.choose(city, deferent, Building.BUILDING_HOUSE)["tile"] == plain_site, "with no preference, a family takes the site nearer its work")
	HomeSites.mark(city, hoped, hoped, HomeSites.LAND_PREFERRED)
	var deferent_choice: Dictionary = HomeSites.choose(city, deferent, Building.BUILDING_HOUSE)
	_check(deferent_choice["tile"] == hoped and str(deferent_choice["note"]).contains("where the gathering hopes homes will go"), "a deferential family heeds the hope and says so: %s" % deferent_choice["note"])
	_check(HomeSites.choose(city, free, Building.BUILDING_HOUSE)["tile"] == plain_site, "a self-governing family does not: the hope persuades, it does not force")

# 3. Families never build outside the land set aside, however near their work.
func test_prohibited_land_is_respected() -> void:
	var city: City = make_city()
	var family: Household = city.households[0]
	give_work(city, family)
	HomeSites.mark(city, Vector2i(50, 20), Vector2i(52, 22), HomeSites.LAND_PERMITTED)
	var started: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	var own: Array = started.filter(func(p: ConstructionProject) -> bool: return p.claimant_household_id == family.id)
	_check(not own.is_empty() and HomeSites.get_land(city, (own[0] as ConstructionProject).tile) != HomeSites.LAND_NONE, "a family builds only on the land set aside, far from its work though it is")
	HomeSites.mark(city, Vector2i(50, 20), Vector2i(52, 22), HomeSites.LAND_PERMITTED)
	_check(HomeSites.count_land(city) == 0, "marking the same land again clears it")

# 4. No land set aside, or none left that can hold a home: no home, and the family says why.
func test_no_land_means_no_home() -> void:
	var city: City = make_city()
	var family: Household = city.households[0]
	give_work(city, family)
	var started: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	_check(started.filter(func(p: ConstructionProject) -> bool: return p.claimant_household_id == family.id).is_empty(), "with no land set aside, a family builds no home")
	_check(family.home_site_note.contains("no land is set aside for homes") and city.construction.families_without_plot > 0, "and says why: %s" % family.home_site_note)
	var taken: Vector2i = Vector2i(40, 30)
	HomeSites.mark(city, taken, taken, HomeSites.LAND_PERMITTED)
	city.construction.set_occupied([taken] as Array[Vector2i], true)
	FamilyDevelopment.advance(city)
	_check(family.home_site_note.contains("taken or cannot hold one"), "land that is all taken is named as the obstacle: %s" % family.home_site_note)

# 5. Two families never choose the same spot, and nothing is planned where it cannot stand.
func test_sites_never_overlap() -> void:
	var city: City = make_city()
	HomeSites.mark(city, Vector2i(30, 30), Vector2i(31, 30), HomeSites.LAND_PERMITTED)
	var first: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	var homes: Array = first.filter(func(p: ConstructionProject) -> bool: return p.is_home())
	_check(homes.size() == 2 and (homes[0] as ConstructionProject).tile != (homes[1] as ConstructionProject).tile, "two families take the two spots, one each")
	var second: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	_check(second.filter(func(p: ConstructionProject) -> bool: return p.is_home() and p.claimant_household_id >= 0).is_empty(), "no third home is planned on land already taken")
	var waiting: Array = city.households.filter(func(h: Household) -> bool: return h.home_site_note.contains("taken or cannot hold one"))
	_check(not waiting.is_empty(), "the families left without a spot say so")

# 6. The explanation names what the site won and what it gave up, from the actual terms.
func test_explanations_follow_the_terms() -> void:
	var city: City = make_city()
	var parent: Household = city.households[0]
	house(city, parent, Vector2i(46, 22))
	var family: Household = blank(city.households[1], {}, {"close_knit": 3, "clannish": 3})
	family.parent_household_id = parent.id
	give_work(city, family)
	HomeSites.mark(city, Vector2i(WORK.x + 2, WORK.y), Vector2i(WORK.x + 2, WORK.y), HomeSites.LAND_PERMITTED)
	HomeSites.mark(city, Vector2i(45, 22), Vector2i(45, 22), HomeSites.LAND_PERMITTED)
	var choice: Dictionary = HomeSites.choose(city, family, Building.BUILDING_HOUSE)
	var note: String = choice["note"]
	_check(choice["tile"] == Vector2i(45, 22), "a family bound to its kin takes the site beside them")
	_check(note.contains("near its kin") and note.contains("despite being farther from its work"), "and says what it won and what it gave up: %s" % note)
	_check(note.begins_with(city.get_household_label(family.id)), "naming itself")
	var started: Array[ConstructionProject] = FamilyDevelopment.advance(city)
	_check(family.home_site_note == note and family.initiative_note == note and started.any(func(p: ConstructionProject) -> bool: return p.claimant_household_id == family.id and p.tile == Vector2i(45, 22)), "the decision is recorded with the family, and built where it says")

# Every site set aside is first ranked by its distance terms alone (HomeSites.get_rough_score): that
# number must stay equal to those terms in the full measure.
func test_rough_ranking_matches_the_terms() -> void:
	var city: City = make_city()
	var parent: Household = city.households[0]
	house(city, parent, Vector2i(16, 26))
	var friend: Household = city.households[2]
	house(city, friend, Vector2i(40, 12))
	var family: Household = blank(city.households[1], {}, {"close_knit": 2})
	family.parent_household_id = parent.id
	family.values[CultureValues.CATEGORY_HOME_PLACE] = ["town_loving"]
	HouseholdMemory.touch_tie(city, family, friend, 3, "friend")
	give_work(city, family)
	HomeSites.mark(city, Vector2i(24, 30), Vector2i(26, 31), HomeSites.LAND_PREFERRED)
	var context: Dictionary = HomeSites.get_context(city, family)
	var worst: float = 0.0
	for tile: Vector2i in [Vector2i(24, 30), Vector2i(10, 10), Vector2i(50, 40), Vector2i(33, 5)]:
		var distance_terms: float = 0.0
		for term: Dictionary in HomeSites.get_terms(city, family, tile, context, false):
			distance_terms += float(term["weight"]) if HomeSites.DISTANCE_FACTORS.has(term["factor"]) else 0.0
		worst = maxf(worst, absf(distance_terms - HomeSites.get_rough_score(city, tile, context)))
	_check(not (context["friends"] as Array).is_empty() and not (context["kin"] as Array).is_empty() and worst < 0.001, "the distance ranking equals the distance terms (largest gap %.4f)" % worst)

# A new town's modest starting land holds every founding family and a little more, beside the
# stockpile without covering it, and the founders can build on it.
func test_starting_land() -> void:
	var city: City = make_city()
	var room: int = HomeSites.set_aside_starting_land(city)
	var land: int = HomeSites.count_land(city)
	_check(room >= EconomyBalance.FOUNDING_FAMILIES + HomeSites.STARTING_SPARE and land <= 49, "starting land holds every founding family and two more (%d spots on %d tiles), and stays modest" % [room, land])
	var heart: Vector2i = TownLogistics.center_tile(city.logistics.stockpile_tile, TownLogistics.STOCKPILE_SIZE)
	_check(HomeSites.get_land(city, heart) == HomeSites.LAND_NONE, "it lies beside the stockpile, not on it")
	FamilyDevelopment.advance(city)
	FamilyDevelopment.advance(city)
	var homes: Array = city.construction.projects.filter(func(p: ConstructionProject) -> bool: return p.is_home())
	_check(homes.size() >= 4 and homes.all(func(p: ConstructionProject) -> bool: return HomeSites.get_land(city, p.tile) != HomeSites.LAND_NONE), "founders build their homes on it")

# 10. Residential land, plain or preferred, is reserved for homes: no workplace is planned on it,
# by a family or the player, so it never eats the room for homes. What already stands there stays.
func test_land_is_reserved_for_homes() -> void:
	var city: City = make_city()
	var camp_size: Vector2i = city.construction.get_size("gatherer_camp")
	var camp: Vector2i = Vector2i(-1, -1)
	# Camps need trees near; the first open spot with a margin of open ground below it for the land.
	for y in range(1, 30):
		for x in range(1, 60):
			if camp.x < 0 and city.construction.validate("gatherer_camp", Vector2i(x, y))["is_valid"] == true and city.construction.validate("hut", Vector2i(x, y + 2))["is_valid"] == true and city.construction.validate("hut", Vector2i(x - 1, y - 1))["is_valid"] == true:
				camp = Vector2i(x, y)
	_check(camp.x >= 0, "the test town has open ground for a workplace")
	HomeSites.mark(city, camp, camp + camp_size - Vector2i.ONE, HomeSites.LAND_PERMITTED)
	HomeSites.mark(city, camp + Vector2i(0, camp_size.y), camp + Vector2i(camp_size.x - 1, camp_size.y + 2), HomeSites.LAND_PREFERRED)
	var open_room: int = HomeSites.count_room(city)
	for origin: Vector2i in [camp, camp + Vector2i(0, camp_size.y), camp - Vector2i(1, 1)]:
		_check(city.construction.validate("gatherer_camp", origin)["is_valid"] != true, "a workplace touching residential land at %s cannot be planned" % origin)
	_check(city.construction.request_building("gatherer_camp", camp) == null, "nor is it, when the player asks")
	_check(city.construction.validate(Building.BUILDING_HOUSE, camp)["is_valid"] == true and city.construction.validate("hut", camp + Vector2i(0, camp_size.y))["is_valid"] == true, "homes and huts still can, on either kind of land")
	_check(city.construction.validate(TownConstruction.PLOT, camp)["is_valid"] == true, "and plots, which are for homes")
	_check(HomeSites.count_room(city) == open_room, "asking took none of the room for homes (%d spots)" % open_room)
	HomeSites.mark(city, camp, camp + camp_size + Vector2i(0, 2), HomeSites.LAND_NONE)
	_check(city.construction.validate("gatherer_camp", camp)["is_valid"] == true, "with the land cleared, the same workplace can be planned there")
	# Land set aside over a standing workplace leaves it standing.
	var standing: Building = give_work(city, city.households[0], Vector2i(44, 40))
	var buildings: int = city.buildings.size()
	HomeSites.mark(city, Vector2i(42, 38), Vector2i(48, 44), HomeSites.LAND_PERMITTED)
	_check(city.buildings.size() == buildings and city.buildings.has(standing) and city.households[0].assigned_building_ids.has(standing.id), "a workplace standing on land later set aside for homes stays, worked as before")
	# Families opening work with land set aside all around them go past it.
	var ringed: City = make_city()
	HomeSites.mark(ringed, Vector2i(10, 10), Vector2i(50, 45), HomeSites.LAND_PERMITTED)
	for household: Household in ringed.households:
		var site: Vector2i = FamilyInitiative.choose_site(ringed, household, "gatherer_camp")
		_check(site.x >= 0 and not ringed.construction.is_on_residential_land(TownLogistics.footprint(site, camp_size)), "family %d opens its work off the residential land (at %s)" % [household.id, site])

func test_saved_with_the_town() -> void:
	var city: City = make_city()
	HomeSites.mark(city, Vector2i(30, 30), Vector2i(33, 31), HomeSites.LAND_PERMITTED)
	HomeSites.mark(city, Vector2i(34, 30), Vector2i(35, 31), HomeSites.LAND_PREFERRED)
	FamilyDevelopment.advance(city)
	var loaded: City = GameState.restore_city(GameState.capture_city(city))
	_check(HomeSites.count_land(loaded) == 12 and HomeSites.get_land(loaded, Vector2i(34, 30)) == HomeSites.LAND_PREFERRED, "a loaded town keeps its residential land")
	_check(loaded.households[0].home_site_note == city.households[0].home_site_note and loaded.households[0].home_site_note != "", "and why each family chose its site")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
