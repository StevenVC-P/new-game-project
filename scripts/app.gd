extends Node

# The application around a game: the start menu, starting or loading a game (scenes/main.tscn),
# the in-game menu, saving, and autosaving each season and when the window closes.
# Tests and tools create main.gd directly and never see any of this.

const MainScene: PackedScene = preload("res://scenes/main.tscn")

var store: SaveStore = SaveStore.new()
var game: Node = null
var menu: GameMenu

func _ready() -> void:
	# Closing the window autosaves first; _notification quits afterwards.
	get_tree().auto_accept_quit = false
	var layer: CanvasLayer = CanvasLayer.new()
	# Above every canvas layer the game uses.
	layer.layer = 100
	add_child(layer)
	menu = GameMenu.new()
	menu.setup(store)
	layer.add_child(menu)
	menu.continue_requested.connect(load_game)
	menu.load_requested.connect(load_game)
	menu.new_world_requested.connect(func() -> void: start_game({}))
	menu.save_requested.connect(save_game)
	menu.resume_requested.connect(resume)
	menu.quit_to_start_requested.connect(quit_to_start)
	menu.quit_requested.connect(quit)
	menu.show_start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	# Escape the game did not use for itself opens the menu; in the menu it goes back a page.
	if menu.visible:
		menu.go_back()
	elif game != null:
		open_menu()
	get_viewport().set_input_as_handled()

# --- Games ---------------------------------------------------------------------------------------

# An empty state starts a new world.
func start_game(state: Dictionary) -> void:
	close_game()
	menu.show_busy("Loading..." if not state.is_empty() else "Building a new world...")
	# Let the busy page draw: building the world holds the main thread for a few seconds.
	for _frame in range(2):
		await get_tree().process_frame
	game = MainScene.instantiate()
	if not state.is_empty():
		game.use_authored_world = bool(state["authored_world"])
		game.world_seed = int(state["world_seed"])
		game.pending_save_state = state
	game.menu_requested.connect(open_menu)
	game.autosave_due.connect(autosave)
	game.load_failed.connect(on_load_failed)
	add_child(game)
	menu.hide_menu()

func load_game(path: String) -> void:
	var state: Dictionary = store.read_state(path)
	if state.is_empty():
		menu.show_message("That save could not be read.", menu.show_pause if game != null else menu.show_start)
		return
	await start_game(state)

func on_load_failed(message: String) -> void:
	close_game()
	menu.show_message(message, menu.show_start)

func close_game() -> void:
	if game == null:
		return
	remove_child(game)
	game.queue_free()
	game = null

# --- Menu ----------------------------------------------------------------------------------------

func open_menu() -> void:
	if game == null:
		return
	# A disabled game neither simulates nor takes input, so time stands still under the menu.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	menu.suggested_save_name = suggested_save_name()
	menu.show_pause()

func resume() -> void:
	if game == null:
		return
	menu.hide_menu()
	game.process_mode = Node.PROCESS_MODE_INHERIT

func save_game(slot_name: String) -> void:
	var error: Error = write_save(slot_name)
	if error == OK:
		menu.show_message("Saved \"%s\"." % slot_name, resume)
	else:
		menu.show_message("The game could not be saved (%s)." % error_string(error), menu.show_pause)

func quit_to_start() -> void:
	autosave()
	close_game()
	menu.show_start()

func quit() -> void:
	autosave()
	get_tree().quit()

# --- Saving --------------------------------------------------------------------------------------

func write_save(slot_name: String) -> Error:
	return store.write(slot_name, GameState.describe(game, slot_name), GameState.capture(game))

# Only a game that has gone beyond the atlas has anything worth resuming.
func autosave() -> void:
	if game == null or not game.has_shown_region_map:
		return
	var error: Error = write_save(SaveStore.AUTOSAVE_SLOT)
	if error != OK:
		push_warning("Autosave failed: " + error_string(error))

func suggested_save_name() -> String:
	var place: String = String(GameState.describe(game, "")["place"]).trim_prefix("Exploring ")
	return "%s, %s" % [place, game.world_calendar.get_formatted_date()]
