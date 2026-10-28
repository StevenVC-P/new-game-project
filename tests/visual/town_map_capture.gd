extends SceneTree

# Screenshots of the town map for review by eye, with [PERF] render times:
#  1. Town maps at showcase sites found on the continuous regional map (river, lakeshore, sea
#     coast, woods, rough ground with stone, arid, cold), fitted and up close.
#  2. A town grown by the stand-in player for a year and a half: houses, workplaces, walkers.
#  3. Every building type, tier 1 and tier 0, side by side.
#  4. The real game: a town founded through main.gd, grown, with a house selected.
#  5. Building in the real game: sites at every stage, plots, a road being built, a site's card,
#     woods marked for clearing; then a town grown with families building their own homes on
#     plots, the trails and paths its people wore (along the lines between yards and fields too),
#     the woods its woodcutter cleared and, years on, spreading back; and a workplace selected
#     with its routes to the store and from home.
# Needs a real window and GPU, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/town_map_capture.gd -- <output_dir>

const MainScript = preload("res://scripts/main.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
const MAP_RECT: Rect2 = Rect2(0.0, 0.0, 1600.0, 900.0)
const SEARCH_LIMIT: int = 600
# Town maps generated per region at most, so the search spreads over the world's climates.
const SEARCH_PER_REGION: int = 20

var output_dir: String = "user://town_map_capture"
var world: WorldMapData = null
var terrain: RegionalTerrain = null
var view: TownMapView = null

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	world = FixedWorldDefinition.build()
	terrain = RegionalTerrain.new(world)
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	view = TownMapView.new()
	layer.add_child(view)
	view.set_screen_rect(MAP_RECT)

	var showcases: Dictionary = find_showcase_sites()
	for label: String in showcases.keys():
		var town: City = make_town(showcases[label])
		await show_town(town)
		await shot("%s_fit" % label)
		view.focus_on(Vector2(view.map_size) * TownMapStyle.TILE * 0.5, 3.5)
		await shot("%s_close" % label)

	if showcases.has("river"):
		var grown: City = make_town(showcases["river"])
		StandInPlayerScript.new().play(grown, {}, 540)
		print("[CAPTURE] grown town: %d buildings, %d households" % [grown.buildings.size(), grown.households.size()])
		await show_town(grown)
		await shot("grown_fit")
		view.walker_time = 3.0
		view.focus_on(busiest_point(grown), 2.4)
		await shot("grown_mid")
		view.focus_on(busiest_point(grown), 5.0)
		await shot("grown_near")
		await measure("grown town")

	if showcases.has("plains"):
		var catalog: City = make_catalog_town(showcases["plains"])
		await show_town(catalog)
		view.focus_on(catalog_center(catalog), 2.6)
		await shot("catalog_mid")
		view.focus_on(catalog_center(catalog), 4.2)
		await shot("catalog_near")

	view.get_parent().queue_free()
	await capture_game_flow()
	terrain.wait_for_tasks()
	quit()

# --- Sites ----------------------------------------------------------------------------------------

# One site per kind, found by generating town maps at valid founding sites in frontier regions.
func find_showcase_sites() -> Dictionary:
	var wanted: Array[String] = ["river", "lake", "coast", "woods", "stone", "arid", "cold", "plains"]
	var found: Dictionary = {}
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	var size: Vector2i = MainScript.NEIGHBOURHOOD_SIZE
	var no_cities: Array[City] = []
	var tried: int = 0
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id != -1 or found.size() == wanted.size() or tried > SEARCH_LIMIT:
			continue
		var focus: Vector2i = terrain.world_to_tile_index(terrain.region_focus(region))
		var origin: Vector2i = Vector2i(terrain.wrap_tile_x(focus.x - size.x / 2), clampi(focus.y - size.y / 2, 0, terrain.size_tiles.y - size.y))
		var tiles: Array = terrain.extract_window(origin, size)
		var tried_here: int = 0
		for y in range(6, size.y - 6, 3):
			for x in range(8, size.x - 8, 3):
				if found.size() == wanted.size() or tried > SEARCH_LIMIT or tried_here >= SEARCH_PER_REGION:
					break
				if not might_fill(tiles, Vector2i(x, y), found):
					continue
				if not FoundingSiteHelper.is_valid_founding_tile(tiles, no_cities, Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
					continue
				var global_site: Vector2i = Vector2i(terrain.wrap_tile_x(origin.x + x), origin.y + y)
				var climate: Dictionary = terrain.climate_at(global_site)
				var local_map: Array = generator.generate_from_terrain(terrain, global_site, climate)
				tried += 1
				tried_here += 1
				var kind: String = classify(local_map, climate)
				if kind != "" and not found.has(kind):
					found[kind] = {"site": global_site, "climate": climate, "map": local_map, "region": region.name}
					print("[CAPTURE] %s site: %s in %s" % [kind, str(global_site), region.name])
	return found

# A cheap look at the regional tiles near a site: could its town fill a showcase still missing?
func might_fill(tiles: Array, site: Vector2i, found: Dictionary) -> bool:
	var near: Dictionary = {"lake": 0, "sea": 0, "river": 0}
	for y in range(site.y - 4, site.y + 5):
		for x in range(site.x - 6, site.x + 7):
			var tile_type: String = tiles[y][x]["type"]
			if near.has(tile_type):
				near[tile_type] += 1
	if near["sea"] > 12 and not found.has("coast"):
		return true
	if near["lake"] > 8 and not found.has("lake"):
		return true
	if near["river"] > 4 and not found.has("river"):
		return true
	for kind: String in ["woods", "stone", "arid", "cold", "plains"]:
		if not found.has(kind):
			return near["sea"] + near["lake"] == 0 and (site.x * 7 + site.y * 13) % 5 == 0
	return false

func classify(local_map: Array, climate: Dictionary) -> String:
	var counts: Dictionary = {"river": 0, "lake": 0, "sea": 0, "trees": 0, "deposit": 0, "fertile": 0}
	for row: Array in local_map:
		for tile: Dictionary in row:
			if tile["type"] == "water":
				counts[tile["water_kind"]] += 1
			counts["trees"] += 1 if tile["has_trees"] else 0
			counts["deposit"] += 1 if tile["resource"] != "none" else 0
			counts["fertile"] += 1 if tile["is_fertile"] else 0
	if climate["family"] == RegionalTerrain.CLIMATE_COLD:
		return "cold"
	if climate["family"] == RegionalTerrain.CLIMATE_ARID:
		return "arid"
	if counts["sea"] > 250:
		return "coast"
	if counts["lake"] > 150:
		return "lake"
	if counts["river"] > 120:
		return "river"
	if counts["deposit"] > 60:
		return "stone"
	if counts["trees"] > 900:
		return "woods"
	if counts["fertile"] > 500 and counts["trees"] < 300:
		return "plains"
	return ""

func make_town(entry: Dictionary) -> City:
	var town: City = City.new("Showcase", Vector2(entry["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, 7)
	town.site_profile = SettlementSiteProfile.new()
	town.site_profile.climate = entry["climate"]
	town.local_map = (entry["map"] as Array).duplicate(true)
	return town

# Every building type in both tiers, placed outward from the center wherever it is valid.
func make_catalog_town(entry: Dictionary) -> City:
	var town: City = make_town(entry)
	town.resources["wood"] = 100000
	town.resources["tools"] = 100000
	var placement: BuildingPlacement = BuildingPlacement.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT, MainScript.WOODCUTTER_TREE_RADIUS)
	var types: Array[String] = []
	for data: Dictionary in BuildMenuHelper.get_building_catalog():
		if data["id"] != TownConstruction.ROAD and data["id"] != TownConstruction.PLOT:
			types.append(str(data["id"]))
	for tier0: String in BuildingTiers.TIER0_TO_TIER1.keys():
		if not types.has(tier0):
			types.append(tier0)
	var center: Vector2i = Vector2i(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT) / 2
	for building_type: String in types:
		for resource_name: String in placement.get_building_cost(building_type).keys():
			town.resources[resource_name] = 100000
		var spot: Vector2i = find_spot(town, placement, building_type, center)
		if spot.x < 0:
			print("[CAPTURE] no spot for ", building_type)
			continue
		var size: Vector2i = placement.get_building_size(building_type)
		for y in range(spot.y, spot.y + size.y):
			for x in range(spot.x, spot.x + size.x):
				town.local_map[y][x]["occupied"] = true
		town.add_building(Building.new(-1, building_type, spot, size))
	# Half the workplaces staffed, so both looks show.
	for index in range(town.buildings.size()):
		if town.buildings[index].is_production_building() and index % 2 == 0:
			town.assign_neutral_worker_to_building(index)
	return town

func find_spot(town: City, placement: BuildingPlacement, building_type: String, center: Vector2i) -> Vector2i:
	for radius in range(0, 30):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				if placement.validate(town, town.local_map, building_type, Vector2i(x, y))["is_valid"] == true:
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func catalog_center(town: City) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for building: Building in town.buildings:
		sum += TownMapStyle.tile_rect(building.tile, building.size).get_center()
	return sum / maxf(1.0, town.buildings.size())

# The middle of the town's buildings, where most is going on.
func busiest_point(town: City) -> Vector2:
	return catalog_center(town)

# --- Capture --------------------------------------------------------------------------------------

func show_town(town: City) -> void:
	view.set_city(town)
	for _frame in range(4):
		await process_frame

func shot(shot_name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)

func measure(label: String) -> void:
	var cpu: float = 0.0
	var gpu: float = 0.0
	for _frame in range(30):
		await RenderingServer.frame_post_draw
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	print("[PERF] %s: render cpu %.2f ms, gpu %.2f ms" % [label, cpu / 30.0, gpu / 30.0])

# The real flow: found a town on the regional map, let the stand-in player grow it, and show the
# town view with its sidebar and a house selected.
func capture_game_flow() -> void:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Looks up places by name, so it plays on the hand-authored planet.
	main.use_authored_world = true
	root.add_child(main)
	for _frame in range(10):
		await process_frame
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.on_world_region_entry_requested(region.id)
	var deadline: int = Time.get_ticks_msec() + 20000
	while (main.region_founding_sites.is_empty() or main.is_neighbourhood_pending()) and Time.get_ticks_msec() < deadline:
		await process_frame
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	main.found_player_city_at_pending_site()
	await shot("game_founded")
	var town: City = main.cities[main.selected_city_index]
	StandInPlayerScript.new().play(town, {}, 360)
	for _frame in range(4):
		await process_frame
	await shot("game_grown")
	for index in range(town.buildings.size()):
		if town.buildings[index].is_house():
			main.city_building_overlay.inspected_building_index = index
			main.city_building_overlay.selected_house_building_index = index
			break
	main.town_map_view.focus_on(catalog_center(town), 2.6)
	main.queue_redraw()
	await shot("game_house_selected")
	await measure("game town view")
	main.clear_selected_household()
	# A trader from the neutral town in the sidebar (TownTrade), with its lots.
	town.trade.arrive(town.construction.day, TownTrade.LINK_ROAD)
	main.queue_redraw()
	await shot("game_trader")
	# Bandits seen on the road (TownDefense): the warning and the militia call-up.
	town.defense.raid_day = town.construction.day + EconomyBalance.BANDIT_WARNING_DAYS
	town.defense.raid_strength = 3
	main.queue_redraw()
	await shot("game_bandits")
	# Hovering a status chip in the top bar shows its detail (TownStatusBar): the free-homes chip.
	main.get_viewport().warp_mouse(Vector2(1060.0, 20.0))
	for _frame in range(3):
		await process_frame
	main.queue_redraw()
	await shot("game_status_hover")
	# The influence prototype (TownInfluence, --influence): its sidebar section, ground marked for
	# families' work, and a family's card saying what it decided and how it would answer a call.
	town.influence.enabled = true
	town.set_hand_method_fallback(true)
	town.influence.set_encouraged(TownInfluence.ACTIVITY_FOOD, true)
	town.influence.store_rule = TownInfluence.RULE_PRIORITIES
	var heart: Vector2i = town.logistics.stockpile_tile
	town.influence.mark_work_ground(heart + Vector2i(6, -4), heart + Vector2i(13, 3))
	for _day in range(15):
		town.tick()
	for index in range(town.buildings.size()):
		var resident: Household = town.get_household_for_building_id(index) if town.buildings[index].is_house() else null
		if resident != null and resident.initiative_note != "":
			main.city_building_overlay.inspected_building_index = index
			main.city_building_overlay.selected_house_building_index = index
			break
	main.get_viewport().warp_mouse(Vector2(600.0, 400.0))
	main.queue_redraw()
	await shot("game_influence")
	main.clear_selected_household()
	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await process_frame
	await capture_construction()

func nearest_roadable(town: City, near: Vector2i) -> Vector2i:
	for radius in range(0, 14):
		for y in range(near.y - radius, near.y + radius + 1):
			for x in range(near.x - radius, near.x + radius + 1):
				if town.construction.is_roadable(Vector2i(x, y)):
					return Vector2i(x, y)
	return near

static func nearest_wooded(town: City, near: Vector2i) -> Vector2i:
	var best: Vector2i = near
	var best_distance: int = 1 << 30
	for y in range(town.local_map.size()):
		for x in range((town.local_map[y] as Array).size()):
			var distance: int = (Vector2i(x, y) - near).length_squared()
			if town.local_map[y][x]["has_trees"] == true and distance < best_distance:
				best = Vector2i(x, y)
				best_distance = distance
	return best

static func count_path_levels(town: City) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for cell: Vector2i in town.logistics.cell_levels.keys():
		counts[town.logistics.get_cell_path_level(cell)] += 1
	return counts

# Building in the real game: plan a start, let a few days pass, look at the sites; then grow a
# town where families build their own homes on plots, and look at the paths they wore.
func capture_construction() -> void:
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Looks up places by name, so it plays on the hand-authored planet.
	main.use_authored_world = true
	root.add_child(main)
	for _frame in range(10):
		await process_frame
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.on_world_region_entry_requested(region.id)
	var deadline: int = Time.get_ticks_msec() + 20000
	while (main.region_founding_sites.is_empty() or main.is_neighbourhood_pending()) and Time.get_ticks_msec() < deadline:
		await process_frame
	main.set_pending_founding_tile(main.region_founding_sites[main.region_founding_sites.size() / 3])
	main.found_player_city_at_pending_site()
	var town: City = main.cities[main.selected_city_index]
	var player = StandInPlayerScript.new()
	for building_type: String in ["woodcutter", "farm", "farm", "house"]:
		player.try_build(town, building_type, {}, 0)
	for _plot in range(3):
		player.set_aside_plot(town, {})
	var store: Vector2i = town.logistics.get_store_tiles()[0]
	var road: Array[Vector2i] = town.construction.plan_road(nearest_roadable(town, store + Vector2i(3, 0)), nearest_roadable(town, store + Vector2i(16, 4)))
	print("[CAPTURE] road planned: %d tiles" % road.size())
	if not road.is_empty():
		town.construction.request_road(road)
	for _day in range(5):
		town.tick()
	print("[CAPTURE] after 5 days: %s" % [str(ConstructionDisplayHelper.get_sidebar_lines(town))])
	main.town_map_view.focus_on(TownMapStyle.tile_rect(store).get_center(), 2.4)
	main.queue_redraw()
	await shot("build_sites")
	main.town_map_view.focus_on(TownMapStyle.tile_rect(store).get_center(), 4.5)
	await shot("build_sites_near")
	if not town.construction.projects.is_empty():
		main.city_building_overlay.inspected_project_id = town.construction.projects[0].id
		main.town_map_view.focus_on(TownMapStyle.tile_rect(town.construction.projects[0].tile).get_center(), 2.6)
		main.queue_redraw()
		await shot("build_site_selected")
		main.clear_selected_household()
	# Woods marked for clearing beside the woodcutter: felled through the year, then left.
	var woodcutter_tile: Vector2i = store
	for building: Building in town.buildings:
		if building.type == Building.BUILDING_WOODCUTTER:
			woodcutter_tile = building.tile
	for project: ConstructionProject in town.construction.projects:
		if project.building_type == Building.BUILDING_WOODCUTTER:
			woodcutter_tile = project.tile
	var woods: Vector2i = nearest_wooded(town, woodcutter_tile)
	var marked: int = town.woodland.mark_block(woods - Vector2i(2, 2), woods + Vector2i(3, 3))
	print("[CAPTURE] woods marked for clearing: %d tiles" % marked)
	main.town_map_view.focus_on(TownMapStyle.tile_rect(woods).get_center(), 3.0)
	await shot("build_woods_marked")
	player.play(town, {"homes_on_plots": true}, 360)
	print("[CAPTURE] woods felled in a year: %d, still marked %d, spread %d" % [town.woodland.felled_count, town.woodland.marked.size(), town.woodland.spread_count])
	print("[CAPTURE] grown with plots: %d buildings, %d households, %d homes built by families, sites: %s" % [town.buildings.size(), town.households.size(), town.construction.completed_by_households, str(ConstructionDisplayHelper.get_sidebar_lines(town))])
	# Fence the first field, so the screenshots show one, and give the town a fortnight to build it.
	for building: Building in town.buildings:
		if TownLogistics.is_field(building):
			town.construction.request_fence(building.id)
			break
	for _day in range(15):
		town.tick()
	var fenced: int = 0
	for building: Building in town.buildings:
		fenced += 1 if building.fenced else 0
	print("[CAPTURE] fenced fields: %d; trampled fields yesterday: %s" % [fenced, str(town.logistics.trampled_trips)])
	var levels: Array[int] = count_path_levels(town)
	print("[CAPTURE] worn ground after a year: %d trail tiles, %d path tiles" % [levels[TownLogistics.PATH_TRAIL], levels[TownLogistics.PATH_WORN]])
	for _frame in range(4):
		await process_frame
	await shot("build_grown")
	main.town_map_view.focus_on(TownMapStyle.tile_rect(store).get_center(), 4.0)
	await shot("build_paths_near")
	main.town_map_view.focus_on(TownMapStyle.tile_rect(woods).get_center(), 3.0)
	await shot("build_woods_cleared")
	# Two more years of the town, then twenty more years of the woods alone (no families: only
	# the yearly spread), to see the edges creep.
	for _day in range(720):
		town.tick()
	print("[CAPTURE] two years later: woods spread to %d tiles" % town.woodland.spread_count)
	await shot("build_woods_two_years")
	for year in range(20):
		var rng: RandomNumberGenerator = town.woodland.make_spread_rng(100 + year)
		town.woodland.spread_forest(func() -> float: return rng.randf())
	town.woodland.land_version += 1
	print("[CAPTURE] twenty more years of spreading: woods spread to %d tiles" % town.woodland.spread_count)
	for _frame in range(4):
		await process_frame
	await shot("build_woods_twenty_years")
	var far: int = -1
	for index in range(town.buildings.size()):
		var building: Building = town.buildings[index]
		if building.is_production_building() and building.assigned_workers > 0 and (far < 0 or town.logistics.get_travel_share(building) > town.logistics.get_travel_share(town.buildings[far])):
			far = index
	if far >= 0:
		main.city_building_overlay.inspected_building_index = far
		main.town_map_view.focus_on(TownMapStyle.tile_rect(town.buildings[far].tile).get_center().lerp(TownMapStyle.tile_rect(store).get_center(), 0.5), 2.2)
		main.queue_redraw()
		await shot("build_workplace_routes")
	await measure("town with construction")
	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await process_frame
