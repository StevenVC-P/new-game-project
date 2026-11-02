extends SceneTree

# Building materials (sprint S4, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md): homes and proper buildings of
# timber, rough stone or dressed stone (masonry), at their own costs and labour; fields and hand work
# timber only; the player's plans use the player's chosen material, families choose their own
# (MaterialChoice): timber when the town has no stone, stone weighed by what it costs, how long it
# takes, what it gives back and the family's values; the materials truly carried; stone needing
# fewer tools and a stone home less firewood; the material kept through an upgrade and a save.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const Invariants = preload("res://tests/sim/economy_invariants.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_costs_and_labour()
	test_the_player_chooses_for_their_plans()
	test_materials_are_carried()
	test_stone_lasts_and_warms()
	test_families_choose()
	test_kept_through_upgrade_and_save()
	if failure_count > 0:
		push_error("Building materials validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Building materials validation passed.")
	quit()

func town(temperature: float = 0.55) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = HuntingTest.open_map([Rect2i(2, 2, 6, 6)])
	city.logistics.mark_layout_changed()
	city.site_profile = SettlementSiteProfile.new()
	city.site_profile.climate = {"temperature": temperature, "moisture": 0.6, "family": "temperate", "tree_temperature": temperature}
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 200
	city.resources["tools"] = 50
	return city

func test_costs_and_labour() -> void:
	_check(EconomyBalance.get_build_cost("house") == {"wood": 6, "tools": 0}, "a timber house costs what it always did")
	var stone: Dictionary = EconomyBalance.get_build_cost("house", EconomyBalance.MATERIAL_STONE)
	_check(int(stone["wood"]) == 2 and int(stone["stone_blocks"]) == 6, "a stone house keeps a third of the wood and takes stone for the rest: %s" % str(stone))
	var dressed: Dictionary = EconomyBalance.get_build_cost("house", EconomyBalance.MATERIAL_DRESSED)
	_check(int(dressed["wood"]) == 2 and int(dressed["masonry"]) == 2 and not dressed.has("stone_blocks"), "dressed stone takes masonry: %s" % str(dressed))
	_check(EconomyBalance.get_build_cost("farm", EconomyBalance.MATERIAL_STONE) == EconomyBalance.get_build_cost("farm"), "a field is a field whatever is chosen")
	_check(EconomyBalance.get_build_cost("hut", EconomyBalance.MATERIAL_STONE) == EconomyBalance.get_build_cost("hut"), "and hand work is hand work")
	var timber_days: float = EconomyBalance.get_build_work_days("house")
	_check(EconomyBalance.get_build_work_days("house", EconomyBalance.MATERIAL_STONE) > EconomyBalance.get_build_work_days("house", EconomyBalance.MATERIAL_DRESSED) and EconomyBalance.get_build_work_days("house", EconomyBalance.MATERIAL_DRESSED) > timber_days, "rough stone is slowest to raise, dressed stone between")

func test_the_player_chooses_for_their_plans() -> void:
	var city: City = town()
	var timber: ConstructionProject = city.construction.request_building("toolmaker", Vector2i(14, 30))
	_check(timber != null and timber.material == EconomyBalance.MATERIAL_TIMBER, "the player's plans are timber until the player chooses otherwise")
	city.influence.build_material = EconomyBalance.MATERIAL_STONE
	var stone: ConstructionProject = city.construction.request_building("toolmaker", Vector2i(20, 30))
	_check(stone != null and stone.material == EconomyBalance.MATERIAL_STONE and stone.materials_needed.has("stone_blocks"), "with stone chosen they are stone, and need stone")
	var field: ConstructionProject = city.construction.request_building("farm", Vector2i(30, 30))
	_check(field == null or field.material == EconomyBalance.MATERIAL_TIMBER, "a field stays a field")
	var family: ConstructionProject = city.construction.request_building("house", Vector2i(44, 20), ConstructionProject.REQUESTED_BY_HOUSEHOLD, city.households[0].id)
	_check(family != null and family.material == EconomyBalance.MATERIAL_TIMBER, "the player's choice doesn't reach a family's own project")
	var card: Dictionary = SidebarPlanningPage.get_material_card(city)
	_check((card["buttons"] as Array).any(func(b: Dictionary) -> bool: return bool(b["active"]) and str(b["action"]["material"]) == EconomyBalance.MATERIAL_STONE), "the Planning page shows stone chosen")

func test_materials_are_carried() -> void:
	var city: City = town()
	city.resources["stone_blocks"] = 20
	city.influence.build_material = EconomyBalance.MATERIAL_STONE
	var checker = Invariants.new()
	checker.watch(city)
	var project: ConstructionProject = city.construction.request_building("toolmaker", Vector2i(14, 30))
	var days: int = ConstructionTest.run_until_built(city, project, 120)
	_check(days > 0, "the stone toolmaker is built (%d days)" % days)
	var standing: Array = city.buildings.filter(func(b: Building) -> bool: return b.type == "toolmaker")
	_check(not standing.is_empty() and (standing[0] as Building).material == EconomyBalance.MATERIAL_STONE, "it stands as stone")
	var used: int = -int((city._flows.get("stone_blocks", {}) as Dictionary).get("built", 0))
	_check(used == int(project.materials_needed["stone_blocks"]), "its stone was carried from the store (%d of %d)" % [used, int(project.materials_needed["stone_blocks"])])
	_check(checker.violations.filter(func(v: String) -> bool: return v.contains("stone_blocks")).is_empty(), "the stone moved only as counted")

func test_stone_lasts_and_warms() -> void:
	var timber: Building = Building.new(-1, "toolmaker", Vector2i(2, 2), Vector2i(3, 3))
	var stone: Building = Building.new(-1, "toolmaker", Vector2i(2, 2), Vector2i(3, 3))
	stone.material = EconomyBalance.MATERIAL_STONE
	_check(stone.get_maintenance_interval() > timber.get_maintenance_interval(), "stone needs repair less often (%d, %d days)" % [stone.get_maintenance_interval(), timber.get_maintenance_interval()])
	var city: City = town(0.3)
	var household: Household = city.households[0]
	var home: Building = Building.new(-1, "house", Vector2i(30, 20), Vector2i.ONE)
	city.add_building(home)
	household.move_to_house(city.buildings.find(home))
	household.rough_housing_months = 0
	var timber_need: float = TownFuel.get_household_need(city, household, 3)
	home.material = EconomyBalance.MATERIAL_STONE
	_check(TownFuel.get_household_need(city, household, 3) < timber_need, "a stone home needs less firewood")

func test_families_choose() -> void:
	var bare: City = town(0.3)
	var household: Household = bare.households[0]
	_check(str(MaterialChoice.choose(bare, household, "house")["material"]) == EconomyBalance.MATERIAL_TIMBER, "with no stone in store a family builds of timber")
	var rich: City = town(0.3)
	rich.resources["stone_blocks"] = 200
	var family: Household = rich.households[0]
	var choice: Dictionary = MaterialChoice.choose(rich, family, "house")
	var stone_option: Array = (choice["options"] as Array).filter(func(o: Dictionary) -> bool: return str(o["material"]) == EconomyBalance.MATERIAL_STONE)
	_check(not stone_option.is_empty(), "with stone in store it is an option")
	var reasons: String = str(FamilyInitiative.get_reasons(stone_option[0]["terms"], true)) + str(FamilyInitiative.get_reasons(stone_option[0]["terms"], false))
	_check(reasons.contains("firewood") and reasons.contains("longer to raise"), "weighed by its warmth in the cold and its labour: %s" % reasons)
	var mild: City = town(0.8)
	mild.resources["stone_blocks"] = 200
	var mild_stone: Array = (MaterialChoice.choose(mild, mild.households[0], "house")["options"] as Array).filter(func(o: Dictionary) -> bool: return str(o["material"]) == EconomyBalance.MATERIAL_STONE)
	_check(not str(FamilyInitiative.get_reasons(mild_stone[0]["terms"], true)).contains("firewood"), "where nothing burns, warmth is no reason")
	var workshop: Array = (MaterialChoice.choose(rich, family, "toolmaker")["options"] as Array).filter(func(o: Dictionary) -> bool: return str(o["material"]) == EconomyBalance.MATERIAL_STONE)
	_check(str(FamilyInitiative.get_reasons(workshop[0]["terms"], true)).contains("fewer tools"), "a stone workshop is weighed by its upkeep")

func test_kept_through_upgrade_and_save() -> void:
	var city: City = town()
	city.resources["stone_blocks"] = 50
	var hut: Building = Building.new(-1, "hut", Vector2i(30, 20), Vector2i.ONE)
	city.add_building(hut)
	var project: ConstructionProject = city.construction.request_upgrade(city.buildings.find(hut), ConstructionProject.REQUESTED_BY_HOUSEHOLD, -1, EconomyBalance.MATERIAL_STONE)
	_check(project != null and project.material == EconomyBalance.MATERIAL_STONE, "a family may raise its hut into a stone house")
	ConstructionTest.run_until_built(city, project, 120)
	var house: Array = city.buildings.filter(func(b: Building) -> bool: return b.type == "house")
	_check(not house.is_empty() and (house[0] as Building).material == EconomyBalance.MATERIAL_STONE, "the house stands as stone")
	city.influence.build_material = EconomyBalance.MATERIAL_DRESSED
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	var restored_house: Array = restored.buildings.filter(func(b: Building) -> bool: return b.type == "house")
	_check(not restored_house.is_empty() and (restored_house[0] as Building).material == EconomyBalance.MATERIAL_STONE and restored.influence.build_material == EconomyBalance.MATERIAL_DRESSED, "the material and the player's choice survive a save")

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
