extends SceneTree

# The regional map: world-driven generation, the original generator left unchanged, and a
# presentation that never shows what the tile data does not hold. Rendering itself is
# checked visually with tests/visual/region_map_capture.gd.

const MainScript = preload("res://scripts/main.gd")
const MAP_SIZE: Vector2i = Vector2i(80, 50)

# Fingerprints of RegionMapGenerator output without world geography, seeds 1-20, recorded
# before the regional map work. A change here means the original maps changed.
const LEGACY_FINGERPRINTS: Array[String] = [
	"056058c32c92a138e99431a8c1b485cf", "85506bf1f98064be2bdfb0022c6bea06", "ab58d25921dd340a81a50bfe3f6e75e8",
	"b2aafee78451904bb651df2701395d8d", "7e96d94399912e3107cb5a244e247d59", "e03a673bb1e8aac934d15596da94823f",
	"23428a7f4820f4800c36cec5ef05f03b", "d7259250341937c94538fb15ff0a594d", "3cd0f78acf75979f3c5890ff8f5f44f9",
	"4a7a4cd839a92371d103930249c65394", "1df86c739229ed6869e1918f8c88f970", "1a0a3964ab48ce682a75450481ca9748",
	"44dcf10c7c74ce8bfddb3f829688c835", "70898cb00584e3e03dbf67dd81613311", "64b0b7621b5280ee140f35db292220b6",
	"0b4b8b2c96de9eb6b659ebe5f23d2cfe", "da4be9a03b276693d0bbe75c6077b9bd", "88ec4a2eff85456b9e0b0e16d4ac2901",
	"3da19613e723e5aa367b0e4732f5e26f", "82063ee9fadbc59019719e291d6b36e6",
]
# Every frontier region must leave the player plenty of choice.
const MIN_FOUNDING_SITES: int = 300

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_legacy_generation_is_unchanged()
	var world: WorldMapData = FixedWorldDefinition.build()
	test_frontier_regions_are_playable(world)
	test_regions_follow_world_geography(world)
	test_world_generation_is_deterministic(world)
	test_presentation_follows_tile_data(world)
	test_camera_maps_screen_to_tiles(world)
	await test_clicking_the_landscape_picks_that_tile()

	if failure_count > 0:
		push_error("Region map validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("Region map validation passed.")
	quit()

func test_legacy_generation_is_unchanged() -> void:
	for seed_value in range(1, LEGACY_FINGERPRINTS.size() + 1):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var generator: RegionMapGenerator = RegionMapGenerator.new(rng, MAP_SIZE.x, MAP_SIZE.y, 24, 5, 7)
		var result: Dictionary = generator.generate_region()
		var cities: Array[City] = result["cities"] as Array[City]
		var roads: Array[Array] = generator.generate_roads_for_cities(cities)
		var parts: PackedStringArray = PackedStringArray()
		for row: Array in result["tiles"]:
			for tile: Dictionary in row:
				parts.append(str(tile["type"]) + str(tile["has_forest"]) + str(tile["is_fertile"]) + str(tile["resource"]) + str(tile["has_road"]) + str(tile["has_ford"]))
		for city: City in cities:
			parts.append(city.name + str(city.tile))
		for road: Array in roads:
			parts.append(str(road))
		_check("".join(parts).md5_text() == LEGACY_FINGERPRINTS[seed_value - 1], "maps made without the world should be unchanged (seed %d)" % seed_value)

func generate(world: WorldMapData, region: WorldMapData.Region) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = region.regional_map_seed
	var generator: RegionMapGenerator = RegionMapGenerator.new(rng, MAP_SIZE.x, MAP_SIZE.y, 24, 5, 7)
	generator.geography = RegionGeography.from_world(world, region.id, MAP_SIZE)
	var result: Dictionary = generator.generate_region()
	result["roads"] = generator.generate_roads_for_cities(result["cities"] as Array[City])
	result["geography"] = generator.geography
	return result

func count_tiles(tiles: Array, matches: Callable) -> int:
	var count: int = 0
	for row: Array in tiles:
		for tile: Dictionary in row:
			if matches.call(tile):
				count += 1
	return count

func test_frontier_regions_are_playable(world: WorldMapData) -> void:
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id != -1:
			continue
		var result: Dictionary = generate(world, region)
		var tiles: Array = result["tiles"]
		var cities: Array[City] = result["cities"] as Array[City]
		_check(cities.size() == 1 and cities[0].is_neutral_city(), "a frontier region should have one regional town: " + region.name)
		var sites: int = 0
		for y in range(MAP_SIZE.y):
			for x in range(MAP_SIZE.x):
				if FoundingSiteHelper.is_valid_founding_tile(tiles, cities, Vector2i(x, y), 24):
					sites += 1
		_check(sites >= MIN_FOUNDING_SITES, "%s should offer at least %d founding sites (has %d)" % [region.name, MIN_FOUNDING_SITES, sites])

func test_regions_follow_world_geography(world: WorldMapData) -> void:
	var valley: Dictionary = generate(world, world.find_region_by_name("Meander Plains"))
	_check(count_tiles(valley["tiles"], func(t: Dictionary) -> bool: return t["type"] == "river") >= 100, "the Great Meander should run through Meander Plains")
	_check((valley["cities"] as Array[City])[0].name == "Callow Ford", "the world's village should be the regional town")
	var leads_to_port: bool = false
	for exit: RegionGeography.RoadExit in (valley["geography"] as RegionGeography).road_exits:
		leads_to_port = leads_to_port or exit.toward == "Port Brannoch"
	_check(leads_to_port, "the road to Port Brannoch should leave the map")

	var lake: Dictionary = generate(world, world.find_region_by_name("Lake Callow"))
	_check(count_tiles(lake["tiles"], func(t: Dictionary) -> bool: return t["type"] == "lake") >= 200, "Lake Callow should hold its lake")

	var coast: Dictionary = generate(world, world.find_region_by_name("Tessaly"))
	_check(count_tiles(coast["tiles"], func(t: Dictionary) -> bool: return t["type"] == "sea") >= 200, "a coastal region should border the sea")

	var heights: Dictionary = generate(world, world.find_region_by_name("Crownspine Heights"))
	_check(count_tiles(heights["tiles"], func(t: Dictionary) -> bool: return t["type"] == "mountain") >= 600, "a mountain region should be mountainous")

	var desert: Dictionary = generate(world, world.find_region_by_name("Siwan Oases"))
	_check((desert["geography"] as RegionGeography).climate_family == RegionGeography.CLIMATE_ARID, "a desert region should read as arid")
	_check(count_tiles(desert["tiles"], func(t: Dictionary) -> bool: return t["has_forest"] == true) < 400, "a desert should have little woodland")

	var jungle: Dictionary = generate(world, world.find_region_by_name("Western Gulf"))
	_check(count_tiles(jungle["tiles"], func(t: Dictionary) -> bool: return t["has_forest"] == true) > 1200, "a jungle region should be heavily wooded")

func test_world_generation_is_deterministic(world: WorldMapData) -> void:
	var region: WorldMapData.Region = world.find_region_by_name("Thornspine North")
	var first: Dictionary = generate(world, region)
	var second: Dictionary = generate(world, region)
	_check(str(first["tiles"]).md5_text() == str(second["tiles"]).md5_text(), "a region should give the same map every time")
	_check(str(first["roads"]) == str(second["roads"]), "a region should give the same roads every time")

func make_view(world: WorldMapData) -> RegionMapView:
	var region: Dictionary = RegionShowcase.build(world, "Meander Plains", true)
	var view: RegionMapView = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2(0.0, 42.0), Vector2(1300.0, 858.0)))
	view.set_region(region["tiles"], region["cities"], region["roads"], region["geography"])
	return view

func tile_under(view: RegionMapView, map_position: Vector2) -> Dictionary:
	var tile: Vector2i = Vector2i((map_position / RegionMapStyle.TILE).floor())
	tile = tile.clamp(Vector2i.ZERO, view.map_size - Vector2i.ONE)
	return view.tiles[tile.y][tile.x]

# Decoration must not misrepresent the data: trees only on forest, peaks on mountains,
# boulders on deposits, houses on open land, fields on fertile land, bridges over rivers.
func test_presentation_follows_tile_data(world: WorldMapData) -> void:
	var view: RegionMapView = make_view(world)
	var trees: int = 0
	for items: Array in view.feature_layer.strip_items:
		for item: PackedFloat32Array in items:
			var tile: Dictionary = tile_under(view, Vector2(item[1], item[2]))
			match int(item[0]):
				RegionFeatureLayer.ITEM_TREE, RegionFeatureLayer.ITEM_CONIFER, RegionFeatureLayer.ITEM_SCRUB:
					trees += 1
					_check(tile["has_forest"] == true, "trees should stand only on forest tiles")
				RegionFeatureLayer.ITEM_PEAK:
					_check(tile["type"] == "mountain", "peaks should stand only on mountain tiles")
				RegionFeatureLayer.ITEM_STONE:
					_check(tile["resource"] == "stone", "pale boulders should mark stone deposits")
				RegionFeatureLayer.ITEM_IRON:
					_check(tile["resource"] == "iron", "rusty boulders should mark iron deposits")
	_check(trees > 1000, "a wooded valley should be drawn with many trees")

	var buildings: int = 0
	for settlement: RegionMapGeometry.SettlementShape in view.geometry.settlements:
		for building: RegionMapGeometry.BuildingShape in settlement.buildings:
			buildings += 1
			_check(view.geometry.is_open_land(building.position), "buildings should stand on open land")
	_check(buildings >= 10, "the grown town and the village should show buildings")
	for field: RegionMapGeometry.FieldShape in view.geometry.fields:
		var center: Vector2 = (field.corners[0] + field.corners[2]) * 0.5
		_check(tile_under(view, center)["is_fertile"] == true, "fields should lie on fertile land")
	_check(not view.geometry.fields.is_empty(), "settlements should have fields")
	for bridge: RegionMapGeometry.BridgeShape in view.geometry.bridges:
		var axis: Vector2 = Vector2(cos(bridge.angle), sin(bridge.angle))
		var over_river: bool = false
		for step in range(-4, 5):
			over_river = over_river or tile_under(view, bridge.center + axis * bridge.length * step / 10.0)["type"] == "river"
		_check(over_river, "bridges should span a river")
	_check(not view.geometry.bridges.is_empty(), "the road over the Great Meander should have a bridge")
	for quarry: RegionMapGeometry.QuarryShape in view.geometry.quarries:
		_check(tile_under(view, quarry.center)["resource"] == "stone", "a quarry should be cut into a stone deposit")
	view.free()

func test_camera_maps_screen_to_tiles(world: WorldMapData) -> void:
	var view: RegionMapView = make_view(world)
	for zoom: float in [view.min_zoom(), 2.0, RegionMapStyle.MAX_ZOOM]:
		view.focus_on(Vector2(40.5, 25.5) * RegionMapStyle.TILE, zoom)
		for tile: Vector2i in [Vector2i(40, 25), Vector2i(38, 24), Vector2i(42, 27)]:
			var screen: Vector2 = view.map_to_screen((Vector2(tile) + Vector2(0.5, 0.5)) * RegionMapStyle.TILE)
			_check(view.screen_to_tile(screen) == tile, "the camera should map a tile's center back to the tile at zoom %.2f" % zoom)
	view.focus_on(Vector2.ZERO, view.min_zoom())
	_check(view.screen_to_tile(Vector2(5.0, 5.0)) == Vector2i(-1, -1), "positions off the map area should hit no tile")
	view.free()

# The real flow: the landscape reports a click and main picks the tile under it as the site.
func test_clicking_the_landscape_picks_that_tile() -> void:
	# Headless runs report a 64x64 window, which the inspector panel would cover entirely.
	root.size = Vector2i(1600, 900)
	var main: Node2D = MainScript.new()
	root.add_child(main)
	main.world_map_view.request_region_entry(main.world_map_data.find_region_by_name("Meander Plains").id)
	# process_frame fires before nodes process, so main.gd's frame update needs a second one.
	await process_frame
	await process_frame
	_check(main.region_map_view != null and main.region_map_view.visible, "the regional landscape should show after entering a region")
	_check(not main.region_founding_sites.is_empty(), "founding sites should be listed for the landscape")
	var site: Vector2i = main.region_founding_sites[main.region_founding_sites.size() / 2]
	main.region_map_view.focus_on((Vector2(site) + Vector2(0.5, 0.5)) * main.TILE_SIZE, 2.5)
	var screen: Vector2 = main.region_map_view.map_to_screen((Vector2(site) + Vector2(0.5, 0.5)) * main.TILE_SIZE)
	main.on_region_map_clicked(screen)
	_check(main.pending_founding_tile == site, "clicking a site on the landscape should choose that tile")
	_check(main.pending_site_survey.size() >= 5, "choosing a site should still produce the site survey")
	_check(main.found_player_city_at_pending_site(), "founding should still open the town")
	_check(main.current_view == MainScript.VIEW_CITY, "founding should still lead to the town view")
	main.try_return_to_region(Vector2.ZERO)
	_check(main.region_founding_sites.is_empty(), "no founding sites remain once the town is founded")
	var shows_player_town: bool = false
	for settlement: RegionMapGeometry.SettlementShape in main.region_map_view.geometry.settlements:
		shows_player_town = shows_player_town or settlement.is_player
	_check(shows_player_town, "the founded town should appear on the regional map")
	main.queue_free()

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
