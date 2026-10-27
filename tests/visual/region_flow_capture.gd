extends SceneTree

# Plays the real game flow through the continuous regional map and saves screenshots: zoom
# from the world atlas into a region, choose a founding site, found the town, return to the
# region, pan across a kingdom border, and zoom back out to the atlas.
# Needs a real window and GPU, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_flow_capture.gd -- <output_dir>

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
const REGION_NAME: String = "Meander Plains"
const STREAM_TIMEOUT_MS: int = 20000

var output_dir: String = "user://region_flow_capture"

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Looks up places by name, so it plays on the hand-authored planet.
	main.use_authored_world = true
	root.add_child(main)
	await settle(main)

	# The atlas at its closest view over the region's settlement, then one wheel step in.
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name(REGION_NAME)
	var settlement: WorldMapData.Settlement = main.world_map_data.get_settlements_in_region(region.id)[0]
	main.world_map_view.focus_on(settlement.position, WorldMapStyle.MAX_ZOOM)
	await settle(main)
	await shot("f1_atlas_closest")
	var cursor: Vector2 = main.world_map_view.map_screen_rect().get_center()
	wheel(MOUSE_BUTTON_WHEEL_UP, cursor)
	await settle(main)
	await shot("f2_region_at_handoff")

	main.region_map_view.focus_on_global_tile(main.region_map_view.camera_global_tile(), main.REGION_ENTRY_ZOOM)
	await settle(main)
	await shot("f3_region_entered")

	var site: Vector2i = best_site(main)
	main.set_pending_founding_tile(site)
	main.region_map_view.focus_on((Vector2(site) + Vector2(0.5, 0.5)) * main.TILE_SIZE, 2.2)
	main.queue_redraw()
	await settle(main)
	await shot("f4_site_chosen")

	main.found_player_city_at_pending_site()
	await settle(main)
	await shot("f5_town_view")

	main.try_return_to_region(Vector2.ZERO)
	main.region_map_view.focus_on((Vector2(site) + Vector2(0.5, 0.5)) * main.TILE_SIZE, 1.6)
	await settle(main)
	await shot("f6_back_on_region")

	# East across the kingdom border into Brannoch.
	main.region_map_view.focus_on_global_tile(main.region_map_view.camera_global_tile() + Vector2(130.0, 10.0), 1.0)
	await settle(main)
	await shot("f7_across_the_border")

	main.region_map_view.focus_on_global_tile(main.region_map_view.camera_global_tile(), RegionMapView.HANDOFF_ZOOM)
	await settle(main)
	wheel(MOUSE_BUTTON_WHEEL_DOWN, main.region_map_view.screen_rect.get_center())
	await settle(main)
	await shot("f8_back_on_atlas")
	print("[CAPTURE] final view: ", main.current_view)
	main.regional_terrain.wait_for_tasks()
	quit()

# The valid founding tile near the middle with the most fertile land in reach.
func best_site(main: Node2D) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -1.0
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) > 25.0:
			continue
		var profile: SettlementSiteProfile = SettlementSiteProfile.analyze(Vector2(tile), main.tiles, main.CITY_RESOURCE_RANGE)
		var score: float = profile.fertility + profile.river_influence * 2.0 + profile.forest_density * 0.5
		if score > best_score:
			best_score = score
			best = tile
	return best

func wheel(button: MouseButton, position: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event)

# Lets the views update and, on the regional map, the chunks in view stream in.
func settle(main: Node2D) -> void:
	for _frame in range(6):
		await process_frame
	var deadline: int = Time.get_ticks_msec() + STREAM_TIMEOUT_MS
	while main.current_view == main.VIEW_REGION and main.region_map_view.streamer != null and not main.region_map_view.streamer.is_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	for _frame in range(3):
		await process_frame

func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)
