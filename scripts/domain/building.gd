class_name Building
extends RefCounted

const EconomyBalanceScript = preload("res://scripts/domain/economy_balance.gd")
const BuildingTiersScript = preload("res://scripts/domain/building_tiers.gd")

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const BUILDING_QUARRY: String = "quarry"
const BUILDING_FISHER: String = "fisher"
const BUILDING_HUNTER: String = "hunter"
const BUILDING_WATCH_POST: String = "watch_post"
const BUILDING_HERDER: String = "herder"
const BUILDING_STONECUTTER: String = "stonecutter"
const BUILDING_BRICKWORKS: String = "brickworks"
const BUILDING_LIME_KILN: String = "lime_kiln"
const BUILDING_MORTAR_YARD: String = "mortar_yard"
const BUILDING_MASON_YARD: String = "mason_yard"
const BUILDING_SCULPTOR: String = "sculptor"
const BUILDING_CARVER: String = "carver"
const BUILDING_TILEWORKS: String = "tileworks"
const BUILDING_PAVER_YARD: String = "paver_yard"
const BUILDING_STOREHOUSE: String = "storehouse"
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
var preferred_successor_household_id: int = -1
var succession_source_household_id: int = -1
# Months a workplace has waited for a successor after its family passed on or left; -1 when
# it is not a succession vacancy (for example a player hold, which is never auto-filled).
var succession_vacancy_months: int = -1
var maintenance_timer: int = 0
# Days a new or newly upgraded workplace runs before it needs tools (EconomyBalance).
var upkeep_grace_days: int = EconomyBalanceScript.MAINTENANCE_GRACE_DAYS
var maintenance_level: int = 100
var receives_maintenance: bool = true
# Fractional output carried between days when values modify output; starts at 0.5 so it rounds.
var output_carry: float = 0.5
# A fence round a field keeps everyone but its own family out (TownLogistics).
var fenced: bool = false
# A proper workplace short of tools keeps its building and works by hand, at tier 0's pace, instead
# of standing idle (influence prototype; City.set_hand_method_fallback). Off: today's rules.
var works_by_hand_without_tools: bool = false

func _init(building_id: int = -1, building_type: String = BUILDING_HOUSE, tile_pos: Vector2i = Vector2i.ZERO, footprint_size: Vector2i = Vector2i(2, 2)):
	id = building_id
	type = building_type
	tile = tile_pos
	size = footprint_size
	if is_house() or is_store():
		required_workers = 0

func is_house() -> bool:
	return BuildingTiersScript.get_base_type(type) == BUILDING_HOUSE

# A store holds the town's goods; nobody works it and it needs no upkeep yet.
func is_store() -> bool:
	return type == BUILDING_STOREHOUSE

func is_production_building() -> bool:
	return not is_house() and not is_store()

func is_tier0() -> bool:
	return BuildingTiersScript.is_tier0(type)

func needs_maintenance() -> bool:
	return is_production_building() and not is_tier0()

func contains_tile(tile_pos: Vector2i) -> bool:
	return tile_pos.x >= tile.x and tile_pos.x < tile.x + size.x and tile_pos.y >= tile.y and tile_pos.y < tile.y + size.y

func has_worker() -> bool:
	return assigned_workers > 0

func can_produce() -> bool:
	return is_production_building() and assigned_workers > 0 and (maintenance_level > 0 or is_working_by_hand())

# Short of tools, and working by hand rather than standing idle (works_by_hand_without_tools).
func is_working_by_hand() -> bool:
	return works_by_hand_without_tools and needs_maintenance() and maintenance_level < 50

func assign_household(household: Household, source: String = ASSIGNMENT_PLAYER):
	assigned_workers = required_workers
	assigned_preference = household.preference
	assigned_household_id = household.id
	assignment_source = source
	auto_assignment_blocked = false
	clear_work_succession_preference()

func assign_neutral_worker():
	assigned_workers = required_workers
	assigned_preference = WORK_PREF_NEUTRAL
	assigned_household_id = -1
	assignment_source = ASSIGNMENT_PLAYER
	auto_assignment_blocked = false
	clear_work_succession_preference()

func unassign_worker(block_auto_assignment: bool = true):
	assigned_workers = 0
	assigned_preference = WORK_PREF_NEUTRAL
	assigned_household_id = -1
	assignment_source = ASSIGNMENT_NONE
	auto_assignment_blocked = block_auto_assignment
	succession_vacancy_months = -1

func clear_work_succession_preference():
	preferred_successor_household_id = -1
	succession_source_household_id = -1
	succession_vacancy_months = -1

func toggle_maintenance():
	if not is_production_building():
		return

	receives_maintenance = not receives_maintenance

func get_maintenance_interval() -> int:
	return EconomyBalanceScript.get_maintenance_interval(type)

func get_maintenance_tool_cost() -> int:
	return EconomyBalanceScript.MAINTENANCE_TOOL_COST
