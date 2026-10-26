extends SceneTree

# Renders the continuous regional map and saves screenshots for visual review: the showcase
# regions near and far, a grown town, founding hover, a region border, the date line, and
# the widest view (where the world atlas takes over). Needs a real window and GPU, so run it
# without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_map_capture.gd -- <output_dir>
# Without an output directory, images go to user://region_map_capture.

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
# Longest wait for the chunks of one view to finish streaming in.
const STREAM_TIMEOUT_MS: int = 20000

# "offset" is in tiles from the showcase's focus; "world" looks at a world position instead.
const SHOTS: Array = [
	{"name": "01_valley", "showcase": 0, "zoom": 1.2, "measure": true},
	{"name": "02_valley_close", "showcase": 0, "zoom": 3.0, "offset": Vector2(14, 6), "measure": true},
	{"name": "03_foothills", "showcase": 1, "zoom": 1.2},
	{"name": "04_mountains", "showcase": 2, "zoom": 1.2, "measure": true},
	{"name": "05_mountains_close", "showcase": 2, "zoom": 2.6, "offset": Vector2(-10, -8)},
	{"name": "06_coast", "showcase": 3, "zoom": 1.2},
	{"name": "07_desert", "showcase": 4, "zoom": 1.2},
	{"name": "08_taiga", "showcase": 5, "zoom": 1.2},
	{"name": "09_valley_grown", "showcase": 0, "zoom": 1.6, "grown": true},
	{"name": "10_valley_town_close", "showcase": 0, "zoom": 4.0, "grown": true, "measure": true},
	{"name": "11_founding_hover", "showcase": 0, "zoom": 1.9, "offset": Vector2(-8, 4), "hover": true},
	{"name": "12_valley_far", "showcase": 0, "zoom": 0.6, "measure": true},
	{"name": "13_handoff_zoom", "showcase": 0, "zoom": 0.4, "measure": true},
	{"name": "14_region_border", "showcase": 1, "zoom": 0.8, "border": true},
	{"name": "15_date_line", "showcase": 0, "zoom": 0.7, "date_line": true},
]

var view: RegionMapView = null

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output_dir: String = args[0] if args.size() > 0 else "user://region_map_capture"
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	for _frame in range(3):
		await process_frame

	var world: WorldMapData = FixedWorldDefinition.build()
	var terrain: RegionalTerrain = RegionalTerrain.new(world)
	view = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE)))
	view.set_terrain(terrain)

	for shot: Dictionary in SHOTS:
		print("[CAPTURE] rendering ", shot["name"])
		var showcase: Dictionary = RegionShowcase.SHOWCASES[int(shot["showcase"])]
		var region: Dictionary = RegionShowcase.build_continuous(world, terrain, showcase["region"], bool(shot.get("grown", false)))
		view.set_neighbourhood(region["tiles"], region["cities"], region["roads"], region["origin"])
		var cities: Array[City] = region["cities"]
		var has_player: bool = cities.any(func(city: City) -> bool: return city.is_player_city())
		var sites: Array[Vector2i] = []
		if not has_player:
			var size: Vector2i = RegionShowcase.NEIGHBOURHOOD_SIZE
			for y in range(size.y):
				for x in range(size.x):
					if FoundingSiteHelper.is_valid_founding_tile(region["tiles"], cities, Vector2i(x, y), RegionShowcase.MIN_CITY_DISTANCE):
						sites.append(Vector2i(x, y))
		view.set_founding_state(not has_player, sites, Vector2i(-1, -1), RegionShowcase.MIN_CITY_DISTANCE, RegionShowcase.CITY_RESOURCE_RANGE)
		var focus: Vector2 = region["focus"] + Vector2(shot.get("offset", Vector2.ZERO))
		if shot.get("border", false):
			focus = find_region_border(terrain, Vector2i(focus))
		if shot.get("date_line", false):
			focus = find_land_on_date_line(terrain)
		view.focus_on_global_tile(focus, float(shot["zoom"]))
		if shot.get("hover", false):
			var tile: Vector2i = view.screen_to_tile(view.screen_rect.get_center())
			view.set_hover(tile, sites.has(tile), -1)
		else:
			view.set_hover(Vector2i(-1, -1), false, -1)
		var started: int = Time.get_ticks_msec()
		await wait_for_streaming()
		print("[CAPTURE] streamed in %d ms (%s)" % [Time.get_ticks_msec() - started, view.hud_region_text])
		if shot.get("measure", false):
			await measure(String(shot["name"]))
		await RenderingServer.frame_post_draw
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = output_dir.path_join(String(shot["name"]) + ".png")
		image.save_png(path)
		print("[CAPTURE] ", path)
	await measure_panning(1.4)
	await measure_panning(0.5)
	terrain.wait_for_tasks()
	quit()

# Frame times while panning steadily east, so chunks keep streaming in.
func measure_panning(zoom: float) -> void:
	view.focus_on_global_tile(view.camera_global_tile(), zoom)
	await wait_for_streaming()
	var frames: int = 150
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for _frame in range(frames):
		view.camera_center.x += 900.0 / zoom / 60.0
		view.apply_camera()
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	print("[PERF] panning at zoom %.1f: median frame %.1f ms, 95th %.1f ms, worst %.1f ms" % [zoom, times[frames / 2], times[int(frames * 0.95)], times[frames - 1]])

func wait_for_streaming() -> void:
	var deadline: int = Time.get_ticks_msec() + STREAM_TIMEOUT_MS
	for _frame in range(3):
		await process_frame
	while not view.streamer.is_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	for _frame in range(3):
		await process_frame

# A tile near the start where the region changes, searching outward along rows.
func find_region_border(terrain: RegionalTerrain, start: Vector2i) -> Vector2:
	var start_region: int = terrain.region_vote_at(terrain.tile_center_to_world(start))
	for step in range(1, 400):
		for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var tile: Vector2i = start + direction * step
			var world_pos: Vector2 = terrain.tile_center_to_world(tile)
			if terrain.world.is_land_at(world_pos) and terrain.region_vote_at(world_pos) != start_region:
				return Vector2(tile)
	return Vector2(start)

# A land tile on the date line, or the line's middle if it crosses only sea.
func find_land_on_date_line(terrain: RegionalTerrain) -> Vector2:
	for y in range(300, terrain.size_tiles.y - 300, 10):
		if terrain.world.is_land_at(terrain.tile_center_to_world(Vector2i(0, y))) and terrain.world.is_land_at(terrain.tile_center_to_world(Vector2i(-1, y))):
			return Vector2(0, y)
	return Vector2(0, terrain.size_tiles.y / 2)

# Average viewport render time over a few dozen frames of a still view.
func measure(label: String) -> void:
	var viewport_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for _frame in range(5):
		await process_frame
	var cpu: float = 0.0
	var gpu: float = 0.0
	var frames: int = 40
	for _frame in range(frames):
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	print("[PERF] %s: render cpu %.2f ms, gpu %.2f ms" % [label, cpu / frames, gpu / frames])
