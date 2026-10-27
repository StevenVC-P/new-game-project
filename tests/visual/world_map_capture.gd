extends SceneTree

# Renders the world map at several zoom levels and saves screenshots for visual review.
# Needs a real window and GPU, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/world_map_capture.gd -- <output_dir>
# Without an output directory, images go to user://world_map_capture.
# Add seed=N after the directory to review a generated world (WorldGenerator) instead:
#   ... -- <output_dir> seed=12

const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)

# zoom 0 means fully zoomed out. "select" picks a region to show the inspector.
const SHOTS: Array = [
	{"name": "01_planet", "at": Vector2(195, 0), "zoom": 0.0},
	{"name": "02_heartland", "at": Vector2(198, 48), "zoom": 0.42},
	{"name": "03_jade_reach", "at": Vector2(305, 34), "zoom": 0.42},
	{"name": "04_aldermark", "at": Vector2(176, 50), "zoom": 1.0},
	{"name": "05_varenne_close", "at": Vector2(155, 46), "zoom": 3.0},
	{"name": "06_kesh_river", "at": Vector2(213, 20), "zoom": 0.9},
	{"name": "07_frontier_selected", "at": Vector2(78, 46), "zoom": 0.6, "select": "Meander Plains"},
	{"name": "08_wrap_seam", "at": Vector2(0, 20), "zoom": 0.3},
	{"name": "09_crownspine_relief", "at": Vector2(200, 47), "zoom": 1.8},
]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output_dir: String = args[0] if args.size() > 0 else "user://world_map_capture"
	var world_seed: int = -1
	for arg: String in args:
		if arg.begins_with("seed="):
			world_seed = int(arg.trim_prefix("seed="))
	DirAccess.make_dir_recursive_absolute(output_dir)
	# The game opens maximized; leave that so screenshots have a fixed size.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	for _frame in range(3):
		await process_frame

	var world: WorldMapData = FixedWorldDefinition.build() if world_seed < 0 else WorldGenerator.build(world_seed)
	var view: WorldMapView = WorldMapView.new()
	root.add_child(view)
	view.setup(world)

	for shot: Dictionary in (SHOTS if world_seed < 0 else generated_world_shots(world, world_seed)):
		print("[CAPTURE] rendering ", shot["name"])
		var at: Vector2 = shot["at"]
		var world_position: Vector2 = Vector2(at.x / 360.0 * world.world_size.x, (90.0 - at.y) / 180.0 * world.world_size.y)
		var zoom: float = float(shot["zoom"])
		view.focus_on(world_position, zoom if zoom > 0.0 else view.min_zoom())
		if shot.has("select"):
			view.select_region(world.find_region_by_name(shot["select"]).id)
		else:
			view.clear_selection()
		for _frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_viewport().get_texture().get_image()
		var path: String = output_dir.path_join(String(shot["name"]) + ".png")
		image.save_png(path)
		print("[CAPTURE] ", path)

	quit()

# A generated world has no fixed places, so frame what it made: the planet, its continents,
# a capital up close, a frontier region selected, and the date line.
func generated_world_shots(world: WorldMapData, world_seed: int) -> Array:
	var prefix: String = "seed%d_" % world_seed
	var shots: Array = [{"name": prefix + "01_planet", "at": Vector2(180, 0), "zoom": 0.0}]
	var continent_number: int = 0
	for label: WorldMapData.GeoLabel in world.geo_labels:
		if label.kind == WorldMapData.LABEL_CONTINENT and continent_number < 3:
			continent_number += 1
			shots.append({"name": prefix + "02_continent_%d" % continent_number, "at": to_degrees(world, label.position), "zoom": 0.42})
	if not world.kingdoms.is_empty():
		var capital: WorldMapData.Settlement = world.get_settlement(world.kingdoms[0].capital_settlement_id)
		shots.append({"name": prefix + "03_capital", "at": to_degrees(world, capital.position), "zoom": 1.0})
		shots.append({"name": prefix + "04_capital_close", "at": to_degrees(world, capital.position), "zoom": 3.0})
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id < 0 and region.has_river:
			shots.append({"name": prefix + "05_frontier_selected", "at": to_degrees(world, region.centroid), "zoom": 0.6, "select": region.name})
			break
	shots.append({"name": prefix + "06_wrap_seam", "at": Vector2(0, 20), "zoom": 0.3})
	return shots

func to_degrees(world: WorldMapData, world_position: Vector2) -> Vector2:
	return Vector2(world_position.x / world.world_size.x * 360.0, 90.0 - world_position.y / world.world_size.y * 180.0)
