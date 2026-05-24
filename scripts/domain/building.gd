class_name Building
extends RefCounted

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const WORK_PREF_NEUTRAL: String = "neutral"
const ASSIGNMENT_NONE: String = "none"
const ASSIGNMENT_AUTO: String = "auto"
const ASSIGNMENT_PLAYER: String = "player"

var id: int = -1
var type: String = BUILDING_HOUSE
var tile: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i(2, 2)
var required_workers: int = 1
var assigned_workers: int = 0
var assigned_preference: String = WORK_PREF_NEUTRAL
var assigned_household_id: int = -1
var assignment_source: String = ASSIGNMENT_NONE
var auto_assignment_blocked: bool = false
var maintenance_timer: int = 0
var maintenance_level: int = 100
var receives_maintenance: bool = true

func _init(building_id: int = -1, building_type: String = BUILDING_HOUSE, tile_pos: Vector2i = Vector2i.ZERO, footprint_size: Vector2i = Vector2i(2, 2)):
	id = building_id
	type = building_type
	tile = tile_pos
	size = footprint_size
	if is_house():
		required_workers = 0

func is_house() -> bool:
	return type == BUILDING_HOUSE

func is_production_building() -> bool:
	return type != BUILDING_HOUSE

func contains_tile(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= tile.x and tile_pos.x < tile.x + size.x and tile_pos.y >= tile.y and tile_pos.y < tile.y + size.y

func has_worker() -> bool:
	return assigned_workers > 0

func can_produce() -> bool:
	return is_production_building() and assigned_workers > 0 and maintenance_level > 0

func assign_household(household: Household, source: String = ASSIGNMENT_PLAYER):
	assigned_workers = required_workers
	assigned_preference = household.preference
	assigned_household_id = household.id
	assignment_source = source
	auto_assignment_blocked = false

func assign_neutral_worker():
	assigned_workers = required_workers
	assigned_preference = WORK_PREF_NEUTRAL
	assigned_household_id = -1
	assignment_source = ASSIGNMENT_PLAYER
	auto_assignment_blocked = false

func unassign_worker(block_auto_assignment: bool = true):
	assigned_workers = 0
	assigned_preference = WORK_PREF_NEUTRAL
	assigned_household_id = -1
	assignment_source = ASSIGNMENT_NONE
	auto_assignment_blocked = block_auto_assignment

func toggle_maintenance():
	if is_house():
		return

	receives_maintenance = not receives_maintenance

func get_maintenance_interval() -> int:
	if type == BUILDING_FARM:
		return 12
	if type == BUILDING_WOODCUTTER:
		return 10
	if type == BUILDING_TOOLMAKER:
		return 8

	return 10

func get_maintenance_tool_cost() -> int:
	return 1
