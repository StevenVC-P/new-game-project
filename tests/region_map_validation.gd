extends SceneTree

# The regional map: the original generator left unchanged, a presentation that never shows
# what the tile data does not hold, and founding on the continuous map. The continuous
# terrain itself is checked by tests/regional_terrain_validation.gd; rendering visually with
# tests/visual/region_map_capture.gd.

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
# Original-generator map for the presentation checks.
const VIEW_SEED: int = 3

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_legacy_generation_is_unchanged()
	test_presentation_follows_tile_data()
	test_camera_maps_screen_to_tiles()
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

# A bounded region as the original generator makes it, with a grown player town beside the
# neutral one, so settlements, fields, roads, and a quarry are all on the board.
func make_view() -> RegionMapView:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = VIEW_SEED
	var generator: RegionMapGenerator = RegionMapGenerator.new(rng, MAP_SIZE.x, MAP_SIZE.y, 24, 5, 7)
	var result: Dictionary = generator.generate_region()
	var tiles: Array = result["tiles"]
	var cities: Array[City] = result["cities"] as Array[City]
	var site: Vector2i = RegionShowcase.best_founding_site(tiles, cities)
	if site.x >= 0:
		cities.append(RegionShowcase.make_grown_town(site))
	var roads: Array[Array] = generator.generate_roads_for_cities(cities)
	var view: RegionMapView = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2(0.0, 42.0), Vector2(1300.0, 858.0)))
	view.set_region(tiles, cities, roads)
	return view

func tile_under(view: RegionMapView, map_position: Vector2) -> Dictionary:
	var tile: Vector2i = Vector2i((map_position / RegionMapStyle.TILE).floor())
	tile = tile.clamp(Vector2i.ZERO, view.map_size - Vector2i.ONE)
	return view.tiles[tile.y][tile.x]

# Decoration must not misrepresent the data: trees only on forest, peaks on mountains,
# boulders on deposits, houses on open land, fields on fertile land, bridges over rivers.
func test_presentation_follows_tile_data() -> void:
	var view: RegionMapView = make_view()
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
	_check(not view.geometry.bridges.is_empty(), "the road across the river should have a bridge")
	for quarry: RegionMapGeometry.QuarryShape in view.geometry.quarries:
		_check(tile_under(view, quarry.center)["resource"] == "stone", "a quarry should be cut into a stone deposit")
	view.free()

func test_camera_maps_screen_to_tiles() -> void:
	var view: RegionMapView = make_view()
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
	# Looks up places by name, so it plays on the hand-authored planet.
	main.use_authored_world = true
	root.add_child(main)
	main.world_map_view.request_region_entry(main.world_map_data.find_region_by_name("Meander Plains").id)
	main.wait_for_neighbourhood_job()
	# process_frame fires before nodes process, so main.gd's frame update needs a second one.
	await process_frame
	await process_frame
	_check(main.region_map_view != null and main.region_map_view.is_shown(), "the regional landscape should show after entering a region")
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
