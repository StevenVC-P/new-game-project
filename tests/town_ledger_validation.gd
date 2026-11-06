extends SceneTree

# The ownership ledger (sprint S6, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md;
# docs/PROPERTY_AND_COMMUNAL_RESOURCES.md §4.1-4.2): one physical store, families' shares in it,
# the community's goods the rest; shares never exceed the stock; losses fall in proportion; a
# family's own project is paid from its share first and the building records who paid; a cancelled
# project gives back to whoever paid; all of it survives a save; pooled, nothing changes.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_pooled_is_the_whole_store()
	test_shares_and_the_community()
	test_shares_never_exceed_the_stock()
	test_losses_fall_in_proportion()
	test_the_player_trades_only_the_community_goods()
	test_a_family_pays_for_its_own_project()
	test_the_player_pays_from_the_community()
	test_a_cancelled_project_gives_back()
	test_buildings_from_before_were_communal()
	test_it_survives_a_save()
	if failure_count > 0:
		push_error("Town ledger validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Town ledger validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func test_pooled_is_the_whole_store() -> void:
	var city: City = town()
	_check(TownLedger.is_pooled(city), "a new town is pooled")
	_check(TownLedger.get_community(city, "wood") == 500, "pooled, the community holds the whole store")
	_check(TownLedger.get_available(city, city.households[0], "wood") == 500, "pooled, a family may draw on the whole store")
	var card: Dictionary = SidebarCommunityPage.get_treasury_card(city)
	_check(card["tag"] == "pooled" and str(card["lines"][0]).contains("500 wood"), "the treasury card shows the pooled store: %s" % str(card))

func test_shares_and_the_community() -> void:
	var city: City = town()
	var first: Household = city.households[0]
	var second: Household = city.households[1]
	TownLedger.credit(city, first, "wood", 50, "made")
	_check(int(city.resources["wood"]) == 550, "credited goods go into the one store")
	_check(TownLedger.get_share(first, "wood") == 50 and TownLedger.get_community(city, "wood") == 500, "the family holds its 50, the community the rest")
	_check(TownLedger.get_available(city, second, "wood", false) == 0, "a family never draws on another's share")
	_check(TownLedger.get_available(city, first, "wood") == 550, "a family draws on its own and the community's")
	var paid: Dictionary = TownLedger.charge(first, "wood", 60)
	_check(int(paid.get(first.id, 0)) == 50 and int(paid.get(TownLedger.COMMUNITY, 0)) == 10, "a charge takes the family's own first, then the community's: %s" % str(paid))
	_check(first.stores_share.is_empty(), "a spent share is cleared")

func test_shares_never_exceed_the_stock() -> void:
	var city: City = town()
	var first: Household = city.households[0]
	var second: Household = city.households[1]
	city.resources["wood"] = 0
	TownLedger.credit(city, first, "wood", 60, "made")
	TownLedger.credit(city, second, "wood", 40, "made")
	# Taken without being charged to anyone (eating, a workshop's inputs).
	city.remove_resource("wood", 50, "used")
	TownLedger.settle(city)
	_check(TownLedger.get_shares_total(city, "wood") <= int(city.resources["wood"]), "after settling, shares fit in the stock")
	_check(TownLedger.get_share(first, "wood") == 30 and TownLedger.get_share(second, "wood") == 20, "owners lose in proportion: %d, %d" % [TownLedger.get_share(first, "wood"), TownLedger.get_share(second, "wood")])

func test_losses_fall_in_proportion() -> void:
	var city: City = town()
	var first: Household = city.households[0]
	city.resources["wood"] = 100
	TownLedger.credit(city, first, "wood", 100, "made")
	TownLedger.lose(city, "wood", 50, "raided")
	_check(int(city.resources["wood"]) == 150, "the loss leaves the store")
	_check(TownLedger.get_share(first, "wood") == 75 and TownLedger.get_community(city, "wood") == 75, "a raid falls on the family and the community alike: %d, %d" % [TownLedger.get_share(first, "wood"), TownLedger.get_community(city, "wood")])
	_check(int(city._flows["wood"].get("raided", 0)) == -50, "the loss is recorded as raided")

func test_the_player_trades_only_the_community_goods() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	city.resources["wood"] = 0
	city.trade.trader_until_day = city.construction.day + 10
	city.trade.wants = {"wood": 100}
	city.trade.offers = {"tools": 100}
	TownLedger.credit(city, family, "wood", 100, "made")
	_check(city.trade.get_lots().is_empty(), "the family's wood is not the player's to trade")
	city.add_resource("wood", 100, "made")
	var lots: Array[Dictionary] = city.trade.get_lots()
	_check(not lots.is_empty() and lots[0]["give"] == "wood", "the community's wood is")
	if not lots.is_empty():
		city.trade.accept_lot(0)
		_check(TownLedger.get_share(family, "wood") == 100, "a trade leaves the family's share whole")

func test_a_family_pays_for_its_own_project() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownLedger.credit(city, family, "wood", 4, "made")
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14), ConstructionProject.REQUESTED_BY_HOUSEHOLD, family.id, family.id)
	_check(project != null, "the family's house is requested")
	if project == null:
		return
	var wood_needed: int = int(project.materials_needed.get("wood", 0))
	city.construction.apply_labor(project, 1000.0)
	_check(project.has_all_materials(), "the materials are carried")
	_check(int(project.funded["wood"].get(family.id, 0)) == 4 and int(project.funded["wood"].get(TownLedger.COMMUNITY, 0)) == wood_needed - 4, "the family's 4 wood paid first, the community the rest: %s" % str(project.funded))
	_check(TownLedger.get_share(family, "wood") == 0, "the family's share is spent")
	ConstructionTest.run_until_built(city, project, 200)
	var built: Building = city.buildings[city.buildings.size() - 1]
	_check(built.type == "house" and built.funded == project.funded, "the building records who paid: %s" % str(built.funded))
	var share: float = TownLedger.get_funded_share(built.funded, family.id)
	_check(is_equal_approx(share, 4.0 / float(_units(built.funded))), "the family's part is its units over all units: %.2f" % share)

func _units(funded: Dictionary) -> int:
	var total: int = 0
	for good: String in funded.keys():
		for payer: int in (funded[good] as Dictionary).keys():
			total += int(funded[good][payer])
	return total

func test_the_player_pays_from_the_community() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownLedger.credit(city, family, "wood", 30, "made")
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14))
	city.construction.apply_labor(project, 1000.0)
	_check(TownLedger.get_share(family, "wood") == 30, "the player's project leaves the family's wood alone")
	_check(TownLedger.get_funded_share(project.funded, TownLedger.COMMUNITY) == 1.0, "the community paid all of it")

func test_a_cancelled_project_gives_back() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownLedger.credit(city, family, "wood", 4, "made")
	var before: int = int(city.resources["wood"])
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14), ConstructionProject.REQUESTED_BY_HOUSEHOLD, family.id, family.id)
	city.construction.apply_labor(project, 1000.0)
	city.construction.cancel(project.id)
	_check(int(city.resources["wood"]) == before, "the materials come back to the store")
	_check(TownLedger.get_share(family, "wood") == 4, "the family gets back what it paid")
	# A project from before the ledger has deliveries and no record: the community takes them back.
	var old: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14))
	city.construction.apply_labor(old, 1000.0)
	old.funded.clear()
	city.construction.cancel(old.id)
	_check(int(city.resources["wood"]) == before and TownLedger.get_share(family, "wood") == 4, "unrecorded deliveries go back to the community")

func test_buildings_from_before_were_communal() -> void:
	var building: Building = Building.new(-1, "house", Vector2i(2, 2), Vector2i(2, 2))
	_check(TownLedger.get_funded_share(building.funded, TownLedger.COMMUNITY) == 1.0, "a building with no record was the common store's")
	_check(TownLedger.get_funded_share(building.funded, 3) == 0.0, "and no family's")

func test_it_survives_a_save() -> void:
	var city: City = town()
	var family: Household = city.households[0]
	TownLedger.credit(city, family, "wood", 12, "made")
	var project: ConstructionProject = city.construction.request_building("house", Vector2i(30, 14), ConstructionProject.REQUESTED_BY_HOUSEHOLD, family.id, family.id)
	city.construction.apply_labor(project, 1000.0)
	TownLedger.credit(city, family, "food", 7, "made")
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(TownLedger.get_share(restored.get_household_by_id(family.id), "food") == 7, "a family's share survives a save")
	_check(restored.construction.projects[0].funded == project.funded, "who paid survives a save: %s" % str(restored.construction.projects[0].funded))

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
