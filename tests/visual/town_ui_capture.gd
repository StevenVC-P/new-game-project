extends SceneTree

# Screenshots of the town view's interface in the real game (docs/TOWN_UI.md): a town founded
# through main.gd and grown by the stand-in player, then the sidebar's four tabs, a family's
# details, a tool being placed, and the alerts that come and go, at 1920x1080 and at a small
# laptop size. Needs a window (no --headless):
#
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/town_ui_capture.gd -- <output_dir>

const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1366, 768)]

var output_dir: String = "user://town_ui_capture"
var main: Node2D = null

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	set_size(SIZES[0])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
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
	main.simulation_clock.is_paused = true
	await shot("founded_overview")

	var town: City = main.cities[main.selected_city_index]
	StandInPlayerScript.new().play(town, {}, 360)
	for _day in range(30):
		town.tick()
	main.get_viewport().warp_mouse(Vector2(500.0, 500.0))
	await shot("grown_overview")
	if not main.has_method("show_sidebar_tab"):
		# The interface before the redesign has one long panel.
		finish()
		return

	for tab: String in ["families", "planning", "community"]:
		main.show_sidebar_tab(tab)
		await shot("grown_" + tab)

	# A family selected on the map: its details open in the Families tab.
	for index in range(town.buildings.size()):
		var resident: Household = town.get_household_for_building_id(index) if town.buildings[index].is_house() else null
		if resident != null and resident.initiative_note != "":
			main.select_household(resident)
			break
	main.show_sidebar_tab("families")
	await shot("family_selected")
	main.show_sidebar_tab("overview")
	await shot("family_selected_overview")
	main.clear_selected_household()

	# Placing a building: the tool strip at the bottom of the sidebar says what it costs and whether
	# the hovered ground takes it.
	main.select_building_type("farm")
	main.show_sidebar_tab("planning")
	main.get_viewport().warp_mouse(main.get_town_map_screen_rect().get_center())
	await shot("placing_farm")
	main.is_placing_building = false

	# Alerts: a trader in town and bandits on the road, in Needs attention.
	town.trade.arrive(town.construction.day, TownTrade.LINK_ROAD)
	town.defense.raid_day = town.construction.day + EconomyBalance.BANDIT_WARNING_DAYS
	town.defense.raid_strength = 3
	main.show_sidebar_tab("overview")
	await shot("alerts_overview")

	# The details a developer reads: every expander on the Overview open.
	main.town_sidebar.expand_all(true)
	await shot("overview_details")
	main.town_sidebar.expand_all(false)

	set_size(SIZES[1])
	for tab: String in ["overview", "families", "planning", "community"]:
		main.show_sidebar_tab(tab)
		await shot("small_" + tab)
	main.town_sidebar.scroll_to(100000.0)
	await shot("small_community_scrolled")
	finish()

func set_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size

func finish() -> void:
	main.regional_terrain.wait_for_tasks()
	quit()

func shot(shot_name: String) -> void:
	main.queue_redraw()
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)
