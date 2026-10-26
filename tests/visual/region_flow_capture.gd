extends SceneTree

# Plays the real game flow through the regional map and saves screenshots: enter a region
# from the world atlas, choose a founding site, found the town, and return to the region.
# Needs a real window and GPU, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_flow_capture.gd -- <output_dir>

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
const REGION_NAME: String = "Meander Plains"

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
	root.add_child(main)
	await settle()

	main.world_map_view.request_region_entry(main.world_map_data.find_region_by_name(REGION_NAME).id)
	await settle()
	await shot("f1_region_entered")

	var site: Vector2i = best_site(main)
	main.set_pending_founding_tile(site)
	main.region_map_view.focus_on((Vector2(site) + Vector2(0.5, 0.5)) * main.TILE_SIZE, 2.2)
	main.queue_redraw()
	await settle()
	await shot("f2_site_chosen")

	main.found_player_city_at_pending_site()
	await settle()
	await shot("f3_town_view")

	main.try_return_to_region(Vector2.ZERO)
	main.region_map_view.reset_camera()
	await settle()
	await shot("f4_back_on_region")
	quit()

# The valid founding tile with the most fertile land in reach, so the flow shows a good site.
func best_site(main: Node2D) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -1.0
	for tile: Vector2i in main.region_founding_sites:
		var profile: SettlementSiteProfile = SettlementSiteProfile.analyze(Vector2(tile), main.tiles, main.CITY_RESOURCE_RANGE)
		var score: float = profile.fertility + profile.river_influence * 2.0 + profile.forest_density * 0.5
		if score > best_score:
			best_score = score
			best = tile
	return best

func settle() -> void:
	for _frame in range(6):
		await process_frame

func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)
