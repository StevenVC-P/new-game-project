extends SceneTree

# Hunting grounds (docs/AUTONOMOUS_OCCUPATIONS.md, fifth round, owner 2026-11-02):
#
# - shared woods: lodges whose reaches overlap share the woods there, in what they bring in and in
#   what families expect of them (TownLand); seven cases from the owner's brief, and families'
#   judgement of hunting;
# - the early warning: woodcutters felling inside a worked lodge's reach are shown before much game
#   is lost, with which lodges, what continued felling does, and the answer, keeping those woods,
#   with its cost to the woodcutters; never when hunting is not threatened; reading it changes
#   nothing (TownWoodland.get_hunting_threats, SidebarOverviewPage.get_hunting_ground_cards);
# - kept woods stay binding, and woods marked for clearing say what stops their felling;
# - in the real game: the card's button and the Keep woods tool by mouse, at 1920x1080 and 1366x768.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const MainScript = preload("res://scripts/main.gd")
# The game's random numbers from here, so every run founds the same town.
const FOUNDING_SEED: int = 20261103
# A patch of woods (8 x 6 = 48 tiles) and a lodge whose reach holds all of it.
const PATCH: Rect2i = Rect2i(18, 14, 8, 6)
const LODGE_A: Vector2i = Vector2i(20, 20)

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_one_lodge_uncontested()
	test_two_lodges_same_woods()
	test_two_lodges_overlapping()
	test_lodges_apart()
	test_shared_woods_felled()
	test_shared_woods_kept()
	test_shared_woods_over_time()
	test_families_judge_shared_woods()
	test_warning_before_loss()
	test_no_false_warnings()
	test_warning_for_marked_woods()
	test_keeping_is_binding_and_costs_wood()
	test_reading_changes_nothing()
	test_clearing_obstacles()
	await test_in_the_game()
	if failure_count > 0:
		push_error("Hunting grounds validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Hunting grounds validation passed.")
	quit()

# --- Towns ---------------------------------------------------------------------------------------

# Open ground everywhere (no farmland, water or trees), and woods only where asked.
static func open_map(woods: Array[Rect2i]) -> Array:
	var map: Array = ConstructionTest.make_map()
	for y in range(map.size()):
		for x in range((map[y] as Array).size()):
			var tile: Dictionary = map[y][x]
			tile["type"] = "ground"
			tile["water_kind"] = ""
			tile["is_fertile"] = false
			tile["has_trees"] = woods.any(func(r: Rect2i) -> bool: return r.has_point(Vector2i(x, y)))
	return map

func town(woods: Array[Rect2i]) -> City:
	var city: City = ConstructionTest.make_city()
	city.local_map = open_map(woods)
	city.influence.enabled = true
	city.resources["food"] = 5000
	city.resources["wood"] = 500
	city.resources["tools"] = 200
	return city

func give(city: City, household: Household, type: String, origin: Vector2i) -> Building:
	var building: Building = Building.new(-1, type, origin, city.construction.get_size(type))
	city.add_building(building, household)
	return building

func share(city: City, lodge: Building) -> float:
	return city.land.count_woods_share(lodge.tile, lodge.size, city.land.get_rival_reaches(lodge.type, lodge.tile, false))

func fell(city: City, tile: Vector2i) -> void:
	city.woodland.fell(tile)
	city.woodland.land_version += 1
	city.logistics.mark_layout_changed()

# A day of felling, as TownWoodland.advance_day does it (without the year's spreading).
# A day's felling: woods marked for clearing, and (since sprint S2) the unmarked trees the woodcutters
# fell as they cut their wood.
func fell_a_day(city: City) -> void:
	for building: Building in city.woodland.get_woodcutters():
		city.apply_building_production(building)
	if city.woodland.fell_woods():
		city.woodland.land_version += 1
		city.logistics.mark_layout_changed()

func card(city: City) -> Dictionary:
	for c: Dictionary in SidebarOverviewPage.get_attention(city):
		if str(c["title"]) == SidebarOverviewPage.HUNTING_GROUNDS_TITLE:
			return c
	return {}

# --- Shared woods --------------------------------------------------------------------------------

# 1. One lodge, its woods to itself: it counts every wooded tile in reach, a full bag at 40.
func test_one_lodge_uncontested() -> void:
	var city: City = town([PATCH])
	var lodge: Building = give(city, city.households[0], "hunter", LODGE_A)
	_check(share(city, lodge) == 48.0 and city.land.get_reach_factor(lodge) == 1.0, "a lodge alone counts the whole patch (%.1f) and has a full bag" % share(city, lodge))

# 2. Two lodges in exactly the same woods take half each: together what the woods give one lodge's
# reach, not twice it. In what they bring in, and in what families expect.
func test_two_lodges_same_woods() -> void:
	var city: City = town([PATCH])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var alone: float = city.land.get_output_factor(a)
	var b: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(2, 0))
	_check(share(city, a) == 24.0 and share(city, b) == 24.0, "both reaches hold the whole patch: 24 each (%.1f, %.1f)" % [share(city, a), share(city, b)])
	_check(is_equal_approx(city.land.get_reach_factor(a), 0.6) and is_equal_approx(city.land.get_reach_factor(b), 0.6), "each brings in 60%% of a full bag (%.2f, %.2f)" % [city.land.get_reach_factor(a), city.land.get_reach_factor(b)])
	_check(is_equal_approx(city.land.get_output_factor(a), alone * 0.6), "and its real output falls by as much (%.2f -> %.2f)" % [alone, city.land.get_output_factor(a)])
	city.set_meta("woods_not_shared", true)
	_check(city.land.get_reach_factor(a) == 1.0 and city.land.get_reach_factor(b) == 1.0, "before the fix (meta woods_not_shared) each counted the whole woods")
	city.remove_meta("woods_not_shared")

# 3. Partly overlapping reaches share only the overlap.
func test_two_lodges_overlapping() -> void:
	var city: City = town([PATCH])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var c: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(10, 0))
	# The second lodge's reach starts at x 24: the patch's last two columns (12 tiles) are shared.
	_check(share(city, a) == 42.0 and share(city, c) == 6.0, "the overlap is halved, the rest is whole (%.1f, %.1f)" % [share(city, a), share(city, c)])
	_check(city.land.get_reach_factor(a) == 1.0, "the first lodge still has a full bag (42 tiles of its own share)")

# 4. Lodges in separate woods do not affect each other.
func test_lodges_apart() -> void:
	var other: Rect2i = Rect2i(PATCH.position + Vector2i(26, 0), PATCH.size)
	var city: City = town([PATCH, other])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var d: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(26, 0))
	_check(share(city, a) == 48.0 and share(city, d) == 48.0, "separate woods stay whole (%.1f, %.1f)" % [share(city, a), share(city, d)])

# 5. A tree felled in shared woods costs each lodge its share of it.
func test_shared_woods_felled() -> void:
	var city: City = town([PATCH])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var b: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(2, 0))
	for x in range(18, 22):
		fell(city, Vector2i(x, 14))
	_check(share(city, a) == 22.0 and share(city, b) == 22.0 and is_equal_approx(city.land.get_reach_factor(a), 0.55), "four trees felled: 22 each, 55%% of a bag (%.1f, %.2f)" % [share(city, a), city.land.get_reach_factor(a)])

# 6. Woods kept round a lodge are never felled, however long a woodcutter works beside them.
func test_shared_woods_kept() -> void:
	var city: City = town([PATCH])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var b: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(2, 0))
	give(city, city.households[2], "woodcutter", Vector2i(26, 14))
	var kept: int = city.woodland.keep_hunting_ground(a)
	_check(kept == 48, "keeping the first lodge's grounds keeps the whole patch (%d)" % kept)
	for day in range(400):
		fell_a_day(city)
	_check(city.woodland.felled_count == 0 and share(city, a) == 24.0 and share(city, b) == 24.0, "a year of woodcutting fells none of it (%d felled)" % city.woodland.felled_count)

# 7. Shares follow who hunts: a lodge left empty no longer competes; one being set up counts for a
# place still being judged, but not against what a standing lodge brings in today.
func test_shared_woods_over_time() -> void:
	var city: City = town([PATCH])
	var a: Building = give(city, city.households[0], "hunter", LODGE_A)
	var b: Building = give(city, city.households[1], "hunter", LODGE_A + Vector2i(2, 0))
	_check(is_equal_approx(city.land.get_reach_factor(a), 0.6), "two lodges worked: 60% each")
	city.unassign_building_worker(city.buildings.find(b))
	_check(city.land.get_reach_factor(a) == 1.0, "its family leaves the second lodge: the first has its woods again (%.2f)" % city.land.get_reach_factor(a))
	var project: ConstructionProject = city.construction.request_building("snare_line", LODGE_A + Vector2i(-2, 2), ConstructionProject.REQUESTED_BY_HOUSEHOLD, city.households[2].id, city.households[2].id)
	_check(project != null, "a family sets up hand hunting beside it")
	_check(city.land.get_reach_factor(a) == 1.0, "the standing lodge brings in its full bag while the other is only being set up")
	var judged: float = city.land.get_reach_factor_at("hunter", LODGE_A + Vector2i(2, 0), Vector2i(2, 2))
	_check(judged < 0.5, "a family judging a third place there expects to share with both (%.2f)" % judged)
	for x in range(18, 26):
		for y in range(14, 20):
			fell(city, Vector2i(x, y))
	_check(city.land.get_reach_factor(a) == EconomyBalance.LAND_YIELD_FLOOR, "the woods all felled: the land's floor")

# Families judge hunting by the share they would have: a third lodge in woods two already hunt is
# "little game in reach", and the town's food outlook counts the shares, not the whole woods twice.
func test_families_judge_shared_woods() -> void:
	var city: City = town([PATCH])
	give(city, city.households[0], "hunter", LODGE_A)
	give(city, city.households[1], "hunter", LODGE_A + Vector2i(2, 0))
	city.set_meta("economy_no_proficiency_effects", true)
	var family: Household = city.households[2]
	var shared: Dictionary = FamilyInitiative.get_work_desire(city, family, "hunter")
	var shared_food: float = FamilyInitiative.get_working_output(city, "food")
	city.set_meta("woods_not_shared", true)
	var whole: Dictionary = FamilyInitiative.get_work_desire(city, family, "hunter")
	var whole_food: float = FamilyInitiative.get_working_output(city, "food")
	city.remove_meta("woods_not_shared")
	var little: Callable = func(d: Dictionary) -> bool: return (d["terms"] as Array).any(func(t: Dictionary) -> bool: return str(t["reason"]) == "little game in reach")
	_check(little.call(shared) and not little.call(whole), "a third family sees little game where two lodges already hunt; counting the whole woods, it did not")
	_check(float(shared["score"]) < float(whole["score"]), "so hunting there draws it less (%.2f against %.2f)" % [float(shared["score"]), float(whole["score"])])
	_check(is_equal_approx(shared_food, whole_food * 0.6), "the food the town's hunting brings in is the shares, 60%% of counting the woods twice (%.2f, %.2f)" % [shared_food, whole_food])

# --- The early warning ---------------------------------------------------------------------------

# A lodge with 44 wooded tiles in reach (a full bag needs 40), and a woodcutter just south of them.
const THIN: Rect2i = Rect2i(30, 10, 4, 11)
const THIN_LODGE: Vector2i = Vector2i(26, 14)
const CUTTER: Vector2i = Vector2i(31, 22)

func threatened_town() -> Dictionary:
	var city: City = town([THIN, Rect2i(50, 30, 6, 10)])
	var lodge: Building = give(city, city.households[0], "hunter", THIN_LODGE)
	return {"city": city, "lodge": lodge}

# The card comes as soon as the felling starts, with a full bag still, says which lodge, how long
# its bag holds, and offers to keep those woods; the old card (two thirds of its best) would have
# come much later.
func test_warning_before_loss() -> void:
	var setup: Dictionary = threatened_town()
	var city: City = setup["city"]
	var lodge: Building = setup["lodge"]
	_check(share(city, lodge) == 44.0 and city.land.get_reach_factor(lodge) == 1.0, "the lodge has 44 wooded tiles, a full bag")
	_check(card(city).is_empty(), "no warning while no one fells")
	give(city, city.households[1], "woodcutter", CUTTER)
	var shown: Dictionary = card(city)
	var lines: String = str(shown.get("lines", []))
	_check(not shown.is_empty(), "the woodcutter starts felling inside the lodge's reach: the warning shows")
	_check(lines.contains(city.get_household_label(city.households[0].id)) and lines.contains("44 wooded tiles") and lines.contains("100% of a full bag"), "it names the lodge and its woods, with its bag still full: %s" % lines)
	_check(lines.contains("starts to fall in about") and lines.contains("in half a year"), "it says when its bag starts to fall, and where it would be in half a year: %s" % lines)
	_check(lines.contains("If felling goes on") and lines.contains("If the woods are kept") and lines.contains("whatever the families want") and lines.contains("of the wood they do now"), "it gives both sides: what felling costs the hunting, and that keeping is binding and costs the woodcutters: %s" % lines)
	_check(lines.contains("Neither is always right") and lines.contains("of the food the town") and lines.contains("the town holds"), "and what the town has of each, without recommending either: %s" % lines)
	_check((shown.get("buttons", []) as Array).any(func(b: Dictionary) -> bool: return b["action"]["action"] == "keep_hunting_ground" and int(b["action"]["building"]) == lodge.id), "with a button to keep that lodge's woods")
	_check((shown.get("buttons", []) as Array).any(func(b: Dictionary) -> bool: return b["action"].get("tool", "") == TownWoodland.PROTECT), "and the Keep woods tool")
	# Left alone: how long until the old card (two thirds of the lodge's best) would have shown.
	lodge.peak_land_yield = 1.0
	var day: int = 0
	while city.land.get_reach_factor(lodge) > SidebarOverviewPage.FAILING_SHARE and day < 3000:
		fell_a_day(city)
		day += 1
	_check(day >= int(TownWoodland.THREAT_HORIZON_DAYS), "the new card showed on the first day of felling, with a full bag; the old card would have come only after %d days, at %.0f%% of a bag" % [day, 100.0 * city.land.get_reach_factor(lodge)])

# No warning where hunting is not threatened: abundant woods, felling elsewhere, an empty lodge, or
# no woodcutter.
func test_no_false_warnings() -> void:
	# Abundant: the lodge's whole reach is woods, but for its own ground and a strip to the south.
	var city: City = town([Rect2i(20, 8, 14, 13)])
	for x in range(26, 28):
		for y in range(14, 16):
			city.local_map[y][x]["has_trees"] = false
	var lodge: Building = give(city, city.households[0], "hunter", THIN_LODGE)
	var cutter: Building = give(city, city.households[1], "woodcutter", CUTTER)
	var target: Dictionary = city.woodland.get_felling_target(cutter)
	_check(not target.is_empty() and TownLand.get_reach_rect(lodge.type, lodge.tile, lodge.size).has_point(target["tile"]), "the woodcutter fells inside the lodge's reach")
	_check(city.woodland.get_hunting_threats().is_empty() and card(city).is_empty(), "but in abundant woods (%.0f wooded) that is no threat for years: no warning" % share(city, lodge))
	# Felling elsewhere: the woodcutter's nearest trees are outside the lodge's reach.
	var apart: City = town([THIN, Rect2i(50, 30, 6, 10)])
	give(apart, apart.households[0], "hunter", THIN_LODGE)
	give(apart, apart.households[1], "woodcutter", Vector2i(52, 41))
	_check(card(apart).is_empty(), "a woodcutter felling far from the lodge is no warning")
	# An empty lodge.
	var empty: City = town([THIN])
	var unworked: Building = give(empty, empty.households[0], "hunter", THIN_LODGE)
	empty.unassign_building_worker(empty.buildings.find(unworked))
	give(empty, empty.households[1], "woodcutter", CUTTER)
	_check(card(empty).is_empty(), "a lodge no family works is no warning")
	# No woodcutter at all.
	var quiet: Dictionary = threatened_town()
	_check(card(quiet["city"]).is_empty(), "no felling, no warning")

# Woods marked for clearing in a lodge's reach will be felled first: that is a threat too, said so.
func test_warning_for_marked_woods() -> void:
	var setup: Dictionary = threatened_town()
	var city: City = setup["city"]
	city.woodland.mark_block(Vector2i(30, 10), Vector2i(33, 12))
	var shown: Dictionary = card(city)
	_check(not shown.is_empty() and str(shown["lines"]).contains("marked for clearing"), "12 tiles marked for clearing in a 44-tile hunting ground: a warning that says so: %s" % str(shown.get("lines", [])))

# The card's answer keeps exactly the lodge's woods; nothing in them is felled after; the
# woodcutters fell farther off and bring in about what the card said.
func test_keeping_is_binding_and_costs_wood() -> void:
	var setup: Dictionary = threatened_town()
	var city: City = setup["city"]
	var lodge: Building = setup["lodge"]
	var cutter: Building = give(city, city.households[1], "woodcutter", CUTTER)
	var rect: Rect2i = TownLand.get_reach_rect(lodge.type, lodge.tile, lodge.size)
	var estimate: float = city.woodland.estimate_felling_factor_if_kept(cutter, rect)
	_check(city.woodland.protected.is_empty(), "the warning keeps nothing by itself")
	var kept: int = city.woodland.keep_hunting_ground(lodge)
	_check(kept == 44 and city.woodland.protected.size() == 44, "the answer keeps the 44 wooded tiles in the lodge's reach, and nothing else (%d)" % city.woodland.protected.size())
	_check(card(city).is_empty(), "and the warning is answered")
	var factor: float = city.woodland.get_felling_factor(cutter)
	_check(factor < 1.0 and absf(factor - estimate) < 0.1, "the woodcutter now walks farther and brings in %.0f%% of its wood; the card said about %.0f%%" % [100.0 * factor, 100.0 * estimate])
	for day in range(600):
		fell_a_day(city)
	_check(share(city, lodge) == 44.0 and city.woodland.felled_count > 0, "the woodcutter fells elsewhere (%d trees) and none of the kept woods" % city.woodland.felled_count)
	_check(city.woodland.keep_hunting_ground(lodge) == 0 and city.woodland.protected.size() == 44, "pressing it again changes nothing (it never lifts what is kept)")

# Reading the warning (and the planning page) every day changes nothing the town does: two equal
# towns run side by side, one read daily, end identical.
func test_reading_changes_nothing() -> void:
	var towns: Array[City] = []
	for i in range(2):
		var setup: Dictionary = threatened_town()
		var city: City = setup["city"]
		give(city, city.households[1], "woodcutter", CUTTER)
		towns.append(city)
	for day in range(120):
		SidebarOverviewPage.get_attention(towns[0])
		SidebarPlanningPage.get_designation_card(towns[0], TownWoodland.CLEAR, false)
		towns[0].woodland.get_hunting_threats()
		for city: City in towns:
			city.tick()
	_check(GameState.capture_city(towns[0]) == GameState.capture_city(towns[1]), "a town read every day for 120 days is the same as one never read")
	_check(towns[0].woodland.felled_count == towns[1].woodland.felled_count and towns[0].woodland.cutting == towns[1].woodland.cutting, "the same trees felled, the same felling under way")

# Woods marked for clearing are a binding task, done as labor and time allow; when they cannot be
# felled, the game says why.
func test_clearing_obstacles() -> void:
	var city: City = town([THIN])
	city.woodland.mark_block(Vector2i(30, 10), Vector2i(31, 11))
	_check(city.woodland.get_clearing_obstacle() == "needs a working woodcutter", "marked woods with no woodcutter say so: '%s'" % city.woodland.get_clearing_obstacle())
	_check(str(SidebarPlanningPage.get_designation_card(city, TownWoodland.CLEAR, false)["muted"]).contains("needs a working woodcutter"), "on the Planning page")
	give(city, city.households[1], "woodcutter", CUTTER)
	_check(city.woodland.get_clearing_obstacle() == "", "with a woodcutter at work they are being felled")
	city.resources["food"] = 0
	city.resources["food_shortage"] = true
	_check(city.woodland.get_clearing_obstacle() == "felling stops while the town is out of food" or not city.should_skip_for_food_shortage(), "while the town is out of food, felling stops, and the game says so: '%s'" % city.woodland.get_clearing_obstacle())

# --- In the game -----------------------------------------------------------------------------------

# Where the threatened town's layout sits in the cleared block: the lodge's whole reach inside it.
const LAYOUT: Vector2i = Vector2i(20, 4)

# Clears the trees in a block of open ground near the stores, then plants the threatened lodge's woods
# there: a lodge for one family, a woodcutter for another, and a second patch of woods to keep by the
# tool. Returns {"lodge", "cutter", "patch"} (the patch's top-left corner), or {} without room.
static func set_up_threat(city: City) -> Dictionary:
	var origin: Vector2i = find_open_block(city, Vector2i(24, 26))
	if origin.x < 0:
		return {}
	for y in range(origin.y, origin.y + 26):
		for x in range(origin.x, origin.x + 24):
			city.local_map[y][x]["has_trees"] = THIN.has_point(Vector2i(x, y) - origin + LAYOUT) or Rect2i(16, 22, 4, 4).has_point(Vector2i(x, y) - origin)
	city.woodland.forget_frontier()
	city.woodland.land_version += 1
	city.logistics.mark_layout_changed()
	var lodge: Building = Building.new(-1, "hunter", origin + THIN_LODGE - LAYOUT, Vector2i(2, 2))
	city.add_building(lodge, city.households[0])
	var cutter: Building = Building.new(-1, "woodcutter", origin + CUTTER - LAYOUT, Vector2i(2, 2))
	city.add_building(cutter, city.households[1])
	return {"lodge": lodge, "cutter": cutter, "patch": origin + Vector2i(16, 22)}

# A block of ground with nothing built, reserved or watered, nearest the stores.
static func find_open_block(city: City, size: Vector2i) -> Vector2i:
	var heart: Vector2i = city.logistics.stockpile_tile
	var map_size: Vector2i = city.logistics.map_size()
	for radius in range(6, 60):
		for y in range(heart.y - radius, heart.y + radius + 1):
			for x in range(heart.x - radius, heart.x + radius + 1):
				if maxi(absi(x - heart.x), absi(y - heart.y)) != radius or x < 0 or y < 0 or x + size.x > map_size.x or y + size.y > map_size.y:
					continue
				var open: bool = true
				for dy in range(size.y):
					for dx in range(size.x):
						var tile: Dictionary = city.local_map[y + dy][x + dx]
						open = open and tile["type"] == "ground" and tile["occupied"] != true and tile.get("has_road", false) != true and HomeSites.get_land(city, Vector2i(x + dx, y + dy)) == HomeSites.LAND_NONE
						if not open:
							break
					if not open:
						break
				if open:
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_in_the_game() -> void:
	for window: Vector2i in [Vector2i(1920, 1080), Vector2i(1366, 768)]:
		root.size = window
		var main: Node2D = MainScript.new()
		main.use_authored_world = true
		root.add_child(main)
		main.rng.seed = FOUNDING_SEED
		await _settle()
		var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
		main.world_map_view.request_region_entry(region.id)
		main.wait_for_neighbourhood_job()
		await _settle()
		var middle: Vector2 = Vector2(main.region_map_size) * 0.5
		var site: Vector2i = main.region_founding_sites[0]
		for tile: Vector2i in main.region_founding_sites:
			if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
				site = tile
		main.set_pending_founding_tile(site)
		_check(main.found_player_city_at_pending_site(), "founding should open the town")
		main.simulation_clock.is_paused = true
		await _settle()
		var city: City = main.cities[main.selected_city_index]
		var setup: Dictionary = set_up_threat(city)
		_check(not setup.is_empty(), "the town has open ground for the test's woods")
		if setup.is_empty():
			main.regional_terrain.wait_for_tasks()
			main.queue_free()
			await _settle()
			continue
		var lodge: Building = setup["lodge"]
		var label: String = "%dx%d" % [window.x, window.y]
		main.show_sidebar_tab(TownSidebar.TAB_OVERVIEW)
		await _settle()
		_check(not card(city).is_empty(), "%s: the warning is on the Overview" % label)
		# The card's Keep woods tool, then two clicks on the map over the second patch.
		_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "select_tool" and a.get("tool") == TownWoodland.PROTECT), "%s: the card offers the Keep woods tool" % label)
		_check(main.is_placing_building and main.selected_building_type == TownWoodland.PROTECT, "%s: clicking it picks up the tool" % label)
		var view: TownMapView = main.town_map_view
		var patch: Vector2i = setup["patch"]
		view.reset_camera()
		await _settle()
		_click(view.tile_rect_to_screen(patch).get_center())
		await _settle()
		main.update_city_hovered_tile(view.tile_rect_to_screen(patch + Vector2i(3, 3)).get_center())
		_click(view.tile_rect_to_screen(patch + Vector2i(3, 3)).get_center())
		await _settle()
		_check(city.woodland.protected.size() == 16, "%s: two clicks on the map keep the second patch's 16 tiles (%d kept)" % [label, city.woodland.protected.size()])
		_check(not card(city).is_empty(), "%s: woods kept elsewhere do not answer the warning" % label)
		main.is_placing_building = false
		# The card's own answer: one click keeps the lodge's woods.
		_check(await _click_action(main, func(a: Dictionary) -> bool: return a.get("action") == "keep_hunting_ground" and int(a.get("building", -1)) == lodge.id), "%s: its keep button can be clicked" % label)
		_check(city.woodland.protected.size() == 60 and card(city).is_empty(), "%s: a click keeps the lodge's 44 wooded tiles and answers the warning (%d kept)" % [label, city.woodland.protected.size()])
		main.regional_terrain.wait_for_tasks()
		main.queue_free()
		await _settle()

# Scrolls the sidebar's hit for the first action `matches` accepts into view and clicks it.
func _click_action(main: Node2D, matches: Callable) -> bool:
	var sidebar: TownSidebar = main.town_sidebar
	sidebar.rebuild()
	for prim: Dictionary in sidebar.prims:
		if str(prim["p"]) != "hit" or not matches.call(prim["action"]):
			continue
		var rect: Rect2 = prim["rect"]
		sidebar.scroll_to(rect.position.y - TownSidebar.HEADER_HEIGHT - 20.0)
		_click(sidebar.position + rect.get_center() - Vector2(0.0, sidebar.get_scroll()))
		await _settle()
		return true
	return false

func _click(position: Vector2) -> void:
	_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	_mouse_button(MOUSE_BUTTON_LEFT, false, position)

func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.push_input(event)

func _settle() -> void:
	for _frame in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
