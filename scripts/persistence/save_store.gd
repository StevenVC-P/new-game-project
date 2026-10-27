class_name SaveStore
extends RefCounted

# Saved games on disk: one file per slot, holding a header (what the load list shows, see
# GameState.describe) and then the game state (GameState.capture).
#
# Files are Godot's binary Variant encoding, zstd-compressed. JSON would round floats and needs
# type tags for vectors and typed arrays; this keeps every value exact. Objects are never
# decoded (FileAccess.get_var's default), so a save file cannot run code.

const AUTOSAVE_SLOT: String = "Autosave"
const EXTENSION: String = ".save"

var directory: String

func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory

func slot_path(slot_name: String) -> String:
	var file_name: String = ""
	for character: String in slot_name.strip_edges().to_lower():
		file_name += character if character.is_valid_identifier() or character.is_valid_int() else "-"
	file_name = file_name.strip_edges().trim_prefix("-").trim_suffix("-")
	return directory.path_join((file_name if file_name != "" else "save") + EXTENSION)

func write(slot_name: String, header: Dictionary, state: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = slot_path(slot_name)
	# Write beside the old save and swap it in, so a crash mid-write never loses the last good save.
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open_compressed(temporary, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(header)
	file.store_var(state)
	file.close()
	# Rename replaces the old file in one step.
	return DirAccess.rename_absolute(temporary, path)

# Headers of every readable save, newest first, each with its "path".
func list() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory):
		return saves
	for file_name: String in DirAccess.get_files_at(directory):
		if not file_name.ends_with(EXTENSION):
			continue
		var header: Dictionary = read_header(directory.path_join(file_name))
		if not header.is_empty():
			saves.append(header)
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["saved_unix"]) > int(b["saved_unix"]) or (int(a["saved_unix"]) == int(b["saved_unix"]) and String(a["path"]) < String(b["path"])))
	return saves

func latest() -> Dictionary:
	var saves: Array[Dictionary] = list()
	return saves[0] if not saves.is_empty() else {}

# {} when the file is missing, unreadable, or from a newer build.
func read_header(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	var header: Variant = file.get_var()
	if not header is Dictionary or int((header as Dictionary).get("format", 0)) > GameState.FORMAT:
		return {}
	header["path"] = path
	return header

func read_state(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {}
	file.get_var()
	var state: Variant = file.get_var()
	return state if state is Dictionary else {}

func delete(path: String) -> Error:
	return DirAccess.remove_absolute(path)
