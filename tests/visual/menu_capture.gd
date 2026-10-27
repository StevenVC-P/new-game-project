extends SceneTree

# Screenshots of the start menu and the in-game menu, for visual review. Uses its own save
# folder, never the player's saves. Needs a window, so run it without --headless:
#   & (Get-Content .godot-exe).Trim() --path . --script res://tests/visual/menu_capture.gd -- <output_dir>

const AppScript = preload("res://scripts/app.gd")
const WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
const SAVE_DIRECTORY: String = "user://menu_capture_saves"

var output_dir: String

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output_dir = args[0] if args.size() > 0 else "user://menu_capture"
	DirAccess.make_dir_recursive_absolute(output_dir)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)
	if DirAccess.dir_exists_absolute(SAVE_DIRECTORY):
		for file_name: String in DirAccess.get_files_at(SAVE_DIRECTORY):
			DirAccess.remove_absolute(SAVE_DIRECTORY.path_join(file_name))

	var app: Node = AppScript.new()
	app.store = SaveStore.new(SAVE_DIRECTORY)
	root.add_child(app)
	await shoot("01_start_first_launch")

	await app.start_game({})
	app.game.world_map_view.request_region_entry(app.game.world_map_data.regions[0].id)
	app.game.wait_for_neighbourhood_job()
	await shoot("02_game")
	app.open_menu()
	await shoot("03_pause")
	app.save_game("Riverside start")
	await shoot("04_saved")
	app.open_menu()
	app.menu.show_save()
	await shoot("05_save_page")
	app.autosave()
	app.menu.show_load()
	await shoot("06_load_page")
	app.quit_to_start()
	await shoot("07_start_with_saves")
	quit()

func shoot(shot_name: String) -> void:
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output_dir.path_join(shot_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("[CAPTURE] ", path)
