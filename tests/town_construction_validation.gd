extends SceneTree

# Town building (docs/TOWN_BUILDING_MODEL.md): construction takes materials carried from a store,
# builder labor, and time; tier 0 hand work never stalls; upgrades happen in place while the
# building keeps working; travel to stores and from home costs output, and roads and storehouses
# reduce it; families claim residential plots and build their own homes through the same
# pipeline as the player.

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_request_reserves_land_and_takes_time()
	test_site_waits_for_materials()
	test_more_builders_build_faster()
	test_tier0_never_stalls()
	test_upgrade_in_place_keeps_working()
	test_travel_costs_output()
	test_roads()
	test_cancel_returns_materials()
	test_families_build_on_plots()
	test_family_values_shape_homes()
	test_without_a_town_map()

	if failure_count > 0:
		push_error("Town construction validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town construction validation passed.")
	quit()

# Open ground, farmland along the north edge, woods along the east edge, and a lake in the
# south-west corner with a small island in it.
static func make_map() -> Array:
	var rows: Array = []
	for y in range(44):
		var row: Array = []
		for x in range(64):
			var tile: Dictionary = {"type": "ground", "has_trees": x >= 56, "is_fertile": y < 10 and x < 56, "occupied": false, "water_kind": "", "resource": "none", "has_road": false}
			if x < 12 and y >= 32:
				var island: bool = x >= 4 and x < 7 and y >= 36 and y < 39
				if not island:
					tile["type"] = "water"
					tile["water_kind"] = "lake"
			row.append(tile)
		rows.append(row)
	return rows

static func make_city(with_map: bool = true) -> City:
	var city: City = City.new("Test Town", Vector2(20, 20), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES)
	if with_map:
		city.local_map = make_map()
	city.resources["food"] = 5000
	return city

static func run_days(city: City, days: int) -> void:
	for _day in range(days):
		city.tick()

static func run_until_built(city: City, project: ConstructionProject, max_days: int) -> int:
	for day in range(1, max_days + 1):
		city.tick()
		if not city.construction.projects.has(project):
			return day
	return -1

func test_request_reserves_land_and_takes_time() -> void:
	var city: City = make_city()
	var wood_before: int = int(city.resources["wood"])
	var tools_before: int = int(city.resources["tools"])
	var project: ConstructionProject = city.construction.request_building("farm", Vector2i(28, 4))
	_check(project != null, "a farm should be plannable on farmland")
	if project == null:
		return
	_check(project.requested_by == ConstructionProject.REQUESTED_BY_PLAYER and project.funded_by == ConstructionProject.FUNDED_BY_TOWN_STORES, "a player's plan should record who asked and who pays")
	_check(city.buildings.is_empty(), "nothing stands until it is built")
	_check(int(city.resources["wood"]) == wood_before, "nothing is paid when planning")
	_check(city.local_map[5][29]["occupied"] == true, "a planned site reserves its land")
	_check(city.construction.validate("farm", Vector2i(28, 4))["is_valid"] != true, "nothing else can be planned on a reserved site")
	var days: int = run_until_built(city, project, 60)
	_check(days > 1, "a farm should take more than a day, took %d" % days)
	_check(days > 0 and days < 20, "six founding families should raise a farm within weeks, took %d" % days)
	_check(city.buildings.size() == 1 and city.buildings[0].type == "farm" and city.buildings[0].tile == Vector2i(28, 4), "the finished farm should stand on its site")
	_check(int(city.resources["tools"]) == tools_before - 1, "the farm's tool should have been carried from the stores")
	_check(city.buildings[0].assigned_workers > 0, "a finished workplace gets a family")

func test_site_waits_for_materials() -> void:
	var city: City = make_city()
	city.resources["wood"] = 2
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14))
	run_days(city, 10)
	_check(city.construction.projects.has(project), "a house should wait while the stores lack wood")
	_check(int(project.materials_delivered.get("wood", 0)) == 2, "builders should carry what the stores hold")
	_check(project.blocked_reason.begins_with("waiting for"), "a waiting site should say what it waits for, got '%s'" % project.blocked_reason)
	_check(int(city.resources["wood"]) == 0, "carried materials leave the stores")
	city.resources["wood"] = 20
	_check(run_until_built(city, project, 40) > 0, "the house should go up once wood arrives")

func test_more_builders_build_faster() -> void:
	var quick: City = make_city()
	var quick_project: ConstructionProject = quick.construction.request_building("toolmaker", Vector2i(30, 14))
	var quick_days: int = run_until_built(quick, quick_project, 120)
	var slow: City = make_city()
	# Every family but one is busy at a workplace.
	for index in range(EconomyBalance.FOUNDING_FAMILIES - 1):
		slow.add_building(Building.new(-1, "forager_garden", Vector2i(2 + index * 3, 2), Vector2i(3, 3)))
	var slow_project: ConstructionProject = slow.construction.request_building("toolmaker", Vector2i(30, 14))
	var slow_days: int = run_until_built(slow, slow_project, 240)
	_check(quick_days > 0 and slow_days > quick_days, "a site with a full crew should finish before one with a single builder (%d vs %d days)" % [quick_days, slow_days])

func test_tier0_never_stalls() -> void:
	var city: City = make_city()
	city.resources["wood"] = 0
	city.resources["tools"] = 0
	for index in range(EconomyBalance.FOUNDING_FAMILIES):
		city.add_building(Building.new(-1, "forager_garden", Vector2i(2 + index * 3, 2), Vector2i(3, 3)))
	var house: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14))
	var hut: ConstructionProject = city.construction.request_building("hut", Vector2i(34, 14))
	city.resources["wood"] = 50
	run_days(city, 1)
	_check(not city.construction.spare_time_today.is_empty(), "families at work should give spare time to tier 0 work")
	var hut_days: int = run_until_built(city, hut, 120)
	_check(hut_days > 0, "a hut should go up from spare time alone, with every family at work")
	_check(city.construction.projects.has(house) and house.work_done == 0.0, "a house needs builders free of a holding")
	_check(house.blocked_reason == "no builders free", "a site without builders should say so, got '%s'" % house.blocked_reason)
	city.unassign_building_worker(0)
	_check(run_until_built(city, house, 120) > 0, "freeing a family should get the house built")

func test_upgrade_in_place_keeps_working() -> void:
	var city: City = make_city()
	city.add_building(Building.new(-1, "gatherer_camp", Vector2i(52, 20), Vector2i(2, 2)))
	var camp: Building = city.buildings[0]
	var family: int = camp.assigned_household_id
	var project: ConstructionProject = city.construction.request_upgrade(camp.id)
	_check(project != null and project.kind == ConstructionProject.KIND_UPGRADE, "a tier 0 building should be upgradable")
	_check(city.construction.request_upgrade(camp.id) == null, "a building upgrades once at a time")
	run_days(city, 1)
	_check(camp.type == "gatherer_camp" and camp.can_produce(), "the camp keeps working while it is upgraded")
	_check(run_until_built(city, project, 60) > 0, "the upgrade should finish")
	_check(camp.type == "woodcutter" and camp.tile == Vector2i(52, 20), "the upgrade happens in place")
	_check(camp.assigned_household_id == family, "the same family keeps the holding")

func test_travel_costs_output() -> void:
	var city: City = make_city()
	city.logistics.ensure_ready()
	city.add_building(Building.new(-1, "farm", Vector2i(29, 7), Vector2i(3, 3)))
	city.add_building(Building.new(-1, "farm", Vector2i(13, 1), Vector2i(3, 3)))
	var near: Building = city.buildings[0]
	var far: Building = city.buildings[1]
	var near_share: float = city.logistics.get_travel_share(near)
	var far_share: float = city.logistics.get_travel_share(far)
	print("[TOWN] travel share: farm next to the stockpile %.3f, farm far from it %.3f" % [near_share, far_share])
	_check(near_share > 0.0 and far_share > near_share * 1.5, "a farm far from the stores should lose more of its day to travel (%.3f vs %.3f)" % [far_share, near_share])
	var output_near: int = 0
	var output_far: int = 0
	for day in range(40):
		output_near += city.get_current_building_output_amount(near)
		output_far += city.get_current_building_output_amount(far)
	_check(output_far < output_near, "the far farm should produce less (%d vs %d over 40 days)" % [output_far, output_near])

	city.add_building(Building.new(-1, "storehouse", Vector2i(16, 5), Vector2i(2, 2)))
	_check(city.logistics.get_travel_share(far) < far_share * 0.8, "a storehouse near the far farm should cut its hauling")
	_check(not city.buildings[2].is_production_building() and city.buildings[2].assigned_workers == 0, "a storehouse takes no family")
	var travel: Dictionary = city.logistics.get_travel(far)
	_check(travel["store_tile"] == TownLogistics.center_tile(Vector2i(16, 5), Vector2i(2, 2)), "goods go to the nearest store")

	city.add_building(Building.new(-1, "farm", Vector2i(5, 37), Vector2i(1, 1)))
	_check(not city.logistics.get_travel(city.buildings[3])["reachable"], "a holding cut off by water cannot reach a store")
	_check(is_equal_approx(city.logistics.get_travel_share(city.buildings[3]), EconomyBalance.MAX_TRAVEL_SHARE), "an unreachable holding loses the most a day can lose")

func test_roads() -> void:
	var city: City = make_city()
	city.logistics.ensure_ready()
	city.add_building(Building.new(-1, "woodcutter", Vector2i(52, 20), Vector2i(2, 2)))
	var camp: Building = city.buildings[0]
	var before: float = city.logistics.get_travel_share(camp)
	var store: Vector2i = city.logistics.get_store_tiles()[0]
	var route: Array[Vector2i] = city.construction.plan_road(store + Vector2i(1, 0) * 2, Vector2i(51, 20))
	_check(route.size() > 10, "a road should be plannable across open ground")
	var project: ConstructionProject = city.construction.request_road(route)
	_check(project != null and city.local_map[route[3].y][route[3].x]["occupied"] == true, "a planned road reserves its tiles")
	_check(run_until_built(city, project, 60) > 0, "the road should get built")
	_check(city.local_map[route[3].y][route[3].x]["has_road"] == true and city.local_map[route[3].y][route[3].x]["occupied"] == false, "a finished road is a road tile")
	_check(city.construction.validate("house", route[3])["is_valid"] != true, "nothing can be built on a road")
	var after: float = city.logistics.get_travel_share(camp)
	print("[TOWN] travel share of a woodcutter's family: %.3f without a road, %.3f with one" % [before, after])
	_check(after < before * 0.8, "a road to the stores should cut travel")

func test_cancel_returns_materials() -> void:
	var city: City = make_city()
	var project: ConstructionProject = city.construction.request_building("toolmaker", Vector2i(30, 14))
	run_days(city, 1)
	var delivered: int = int(project.materials_delivered.get("wood", 0))
	var wood: int = int(city.resources["wood"])
	_check(delivered > 0, "builders should start carrying on the first day")
	_check(city.construction.cancel(project.id), "a site can be cancelled")
	_check(int(city.resources["wood"]) == wood + delivered, "cancelling returns the materials to the stores")
	_check(city.local_map[15][31]["occupied"] == false, "cancelling frees the land")

func test_families_build_on_plots() -> void:
	var city: City = make_city()
	FamilyDevelopment.advance_month(city)
	_check(city.construction.projects.is_empty(), "families build only where the town has set land aside")
	_check(city.construction.families_without_plot > 0, "families without a plot are counted for the player")
	var plot_id: int = city.construction.designate_plot(Vector2i(30, 14))
	_check(plot_id >= 0, "a residential plot can be designated on open ground")
	_check(city.construction.designate_plot(Vector2i(31, 15)) < 0, "plots cannot overlap")
	city.construction.designate_plot(Vector2i(40, 26))
	var started: Array[ConstructionProject] = FamilyDevelopment.advance_month(city)
	_check(started.size() == FamilyDevelopment.MAX_PROJECTS_PER_MONTH, "families should claim the open plots")
	var home: ConstructionProject = started[0]
	_check(home.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and home.claimant_household_id == home.requester_household_id, "a family's own home records the family")
	_check(home.building_type == "house" or home.building_type == "hut", "families build homes")
	_check(city.construction.get_open_plots().is_empty(), "a claimed plot is no longer open")
	var claimant: Household = city.get_household_by_id(home.claimant_household_id)
	_check(run_until_built(city, home, 90) > 0, "the family's home should get built")
	_check(claimant.housing_status == Household.RESIDENCE_HOUSED and city.buildings[claimant.residence_building_id].tile == home.tile, "the family moves into the home it built")
	_check(city.construction.get_plot(plot_id).is_empty() or home.plot_id != plot_id, "a plot is gone once its home stands")

	# With no wood to spare, a family raises a hut on its plot instead.
	var poor: City = make_city()
	poor.resources["wood"] = 0
	poor.construction.designate_plot(Vector2i(30, 14))
	var huts: Array[ConstructionProject] = FamilyDevelopment.advance_month(poor)
	_check(huts.size() == 1 and huts[0].building_type == "hut", "families short of wood build a hut")
	_check(run_until_built(poor, huts[0], 90) > 0, "a hut goes up without materials")
	# Once the stores have wood again and the family has waited, it upgrades the hut in place.
	var family: Household = poor.get_household_by_id(huts[0].claimant_household_id)
	family.values.erase(CultureValues.CATEGORY_HOME_PLACE)
	family.rough_housing_months = FamilyDevelopment.HUT_PATIENCE_MONTHS
	poor.resources["wood"] = 100
	var upgrades: Array[ConstructionProject] = FamilyDevelopment.advance_month(poor)
	_check(upgrades.size() >= 1 and upgrades[0].kind == ConstructionProject.KIND_UPGRADE and upgrades[0].claimant_household_id == family.id, "a family in a hut upgrades it when it can")

func test_family_values_shape_homes() -> void:
	var city: City = make_city()
	var near: int = city.construction.designate_plot(Vector2i(28, 14))
	var far: int = city.construction.designate_plot(Vector2i(46, 36))
	var family: Household = city.households[0]
	family.values[CultureValues.CATEGORY_HOME_PLACE] = ["open_country"]
	var plot: Dictionary = FamilyDevelopment.choose_plot(city, family)
	var plain: Household = city.households[1]
	plain.values.erase(CultureValues.CATEGORY_HOME_PLACE)
	var plain_plot: Dictionary = FamilyDevelopment.choose_plot(city, plain)
	_check(int(plain_plot["id"]) == near, "a family without a preference picks the plot nearest its work")
	_check(int(plot["id"]) == far, "an Open Country family settles toward the edge")
	family.values[CultureValues.CATEGORY_HOME_PLACE] = ["simple_living"]
	var hut: ConstructionProject = FamilyDevelopment.claim_plot(city, family)
	_check(hut != null and hut.building_type == "hut", "a Simple Living family is content with a hut")

func test_without_a_town_map() -> void:
	var city: City = make_city(false)
	var project: ConstructionProject = city.construction.request_building("farm", Vector2i.ZERO)
	_check(project != null, "towns without a town map (balance tools) still build")
	_check(run_until_built(city, project, 60) > 0, "and finish what they build")
	_check(city.logistics.get_travel_share(city.buildings[0]) == 0.0, "without a town map there is no travel")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
