extends SceneTree

# Screenshots of the early hunting-grounds warning and its answer in the real game
# (docs/AUTONOMOUS_OCCUPATIONS.md, fifth round): the founded town of tests/hunting_grounds_validation.gd
# with a lodge whose woods a woodcutter has begun to fell, at 1920x1080 and 1366x768: the Overview
# with the warning, then the town once the card's keep button is clicked. Needs a window:
#
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/hunting_warning_capture.gd -- <output_dir>

const HuntingTest = preload("res://tests/hunting_grounds_validation.gd")
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1366, 768)]

var output_dir: String = "user://hunting_warning_capture"
var main: Node2D = null

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for size: Vector2i in SIZES:
		DisplayServer.window_set_size(size)
		root.size = size
		main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		main.use_authored_world = true
		root.add_child(main)
		main.rng.seed = HuntingTest.FOUNDING_SEED
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
		main.simulation_clock.is_paused = true
		var city: City = main.cities[main.selected_city_index]
		var setup: Dictionary = HuntingTest.set_up_threat(city)
		var lodge: Building = setup["lodge"]
		var view: TownMapView = main.town_map_view
		view.reset_camera()
		await frames(4)
		view.focus_on(view.screen_to_map(view.tile_rect_to_screen(lodge.tile + Vector2i(4, 2)).get_center()), TownMapStyle.MAX_ZOOM * 0.45)
		main.show_sidebar_tab(TownSidebar.TAB_OVERVIEW)
		var label: String = "%dx%d" % [size.x, size.y]
		await frames(4)
		scroll_to_card()
		await shot("%s_1_warning" % label)
		main.apply_city_action({"action": "keep_hunting_ground", "building": lodge.id})
		await shot("%s_2_kept" % label)
		main.regional_terrain.wait_for_tasks()
		main.queue_free()
		await frames(4)
	quit()

# Scrolls the Overview so the hunting-grounds card's title is near the top.
func scroll_to_card() -> void:
	var sidebar: TownSidebar = main.town_sidebar
	sidebar.rebuild()
	for prim: Dictionary in sidebar.prims:
		if str(prim["p"]) == "hit" and prim["action"].get("tool", "") == TownWoodland.PROTECT:
			sidebar.scroll_to((prim["rect"] as Rect2).position.y - TownSidebar.HEADER_HEIGHT - 420.0)
			return

func frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func shot(shot_name: String) -> void:
	main.town_sidebar.dirty = true
	main.sync_town_map_view()
	main.queue_redraw()
	await frames(6)
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)
