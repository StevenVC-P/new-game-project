extends SceneTree

# Renders the regional map showcases and saves screenshots for visual review.
# Needs a real window and GPU, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/region_map_capture.gd -- <output_dir>
# Without an output directory, images go to user://region_map_capture.

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)

# zoom 0 means the whole region fits. "at" is a tile; "town" focuses on the player's town.
const SHOTS: Array = [
	{"name": "01_valley", "showcase": 0, "zoom": 0.0, "measure": true},
	{"name": "02_valley_close", "showcase": 0, "zoom": 3.0, "at": Vector2(66, 34), "measure": true},
	{"name": "03_foothills", "showcase": 1, "zoom": 0.0},
	{"name": "04_mountains", "showcase": 2, "zoom": 0.0, "measure": true},
	{"name": "05_mountains_close", "showcase": 2, "zoom": 2.6, "at": Vector2(40, 20)},
	{"name": "06_coast", "showcase": 3, "zoom": 0.0},
	{"name": "07_desert", "showcase": 4, "zoom": 0.0},
	{"name": "08_taiga", "showcase": 5, "zoom": 0.0},
	{"name": "09_valley_grown", "showcase": 0, "zoom": 0.0, "grown": true},
	{"name": "10_valley_town_close", "showcase": 0, "zoom": 4.0, "town": true, "grown": true, "measure": true},
	{"name": "11_coast_town_close", "showcase": 3, "zoom": 3.2, "town": true, "grown": true},
	{"name": "12_founding_hover", "showcase": 0, "zoom": 1.9, "at": Vector2(36, 22), "hover": Vector2i(36, 22)},
]

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
	var view: RegionMapView = RegionMapView.new()
	root.add_child(view)
	view.set_screen_rect(Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE)))

	for shot: Dictionary in SHOTS:
		print("[CAPTURE] rendering ", shot["name"])
		var showcase: Dictionary = RegionShowcase.SHOWCASES[int(shot["showcase"])]
		var started: int = Time.get_ticks_usec()
		var region: Dictionary = RegionShowcase.build(world, showcase["region"], bool(shot.get("grown", false)))
		view.set_region(region["tiles"], region["cities"], region["roads"], region["geography"])
		print("[CAPTURE] built and recorded in %.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
		var cities: Array[City] = region["cities"]
		var has_player: bool = cities.any(func(city: City) -> bool: return city.is_player_city())
		var sites: Array[Vector2i] = []
		if not has_player:
			for y in range(RegionShowcase.MAP_SIZE.y):
				for x in range(RegionShowcase.MAP_SIZE.x):
					if FoundingSiteHelper.is_valid_founding_tile(region["tiles"], cities, Vector2i(x, y), RegionShowcase.MIN_CITY_DISTANCE):
						sites.append(Vector2i(x, y))
		view.set_founding_state(not has_player, sites, Vector2i(-1, -1), RegionShowcase.MIN_CITY_DISTANCE, RegionShowcase.CITY_RESOURCE_RANGE)
		var zoom: float = float(shot["zoom"])
		if zoom > 0.0:
			var focus: Vector2 = Vector2(shot.get("at", Vector2(40, 25)))
			if shot.get("town", false):
				for city: City in cities:
					if city.is_player_city():
						focus = city.tile
			view.focus_on((focus + Vector2(0.5, 0.5)) * RegionMapStyle.TILE, zoom)
		else:
			view.reset_camera()
		if shot.has("hover"):
			var tile: Vector2i = shot["hover"]
			view.set_hover(tile, sites.has(tile), -1)
		else:
			view.set_hover(Vector2i(-1, -1), false, -1)
		for _frame in range(4):
			await process_frame
		if shot.get("measure", false):
			await measure(String(shot["name"]))
		await RenderingServer.frame_post_draw
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = output_dir.path_join(String(shot["name"]) + ".png")
		image.save_png(path)
		print("[CAPTURE] ", path)
	quit()

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
