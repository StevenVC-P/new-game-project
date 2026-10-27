class_name ConstructionProject
extends RefCounted

# One thing being built in a town: a new building, an upgrade in place, a fence round a field,
# or a stretch of road.
# Projects are plain data owned by TownConstruction, which advances them each day. Whoever asked
# for it (the player, a family, later the town's own government) uses the same pipeline, and the
# project records who asked and who pays. Design: docs/TOWN_BUILDING_MODEL.md.

const KIND_BUILDING: String = "building"
const KIND_UPGRADE: String = "upgrade"
const KIND_ROAD: String = "road"
const KIND_FENCE: String = "fence"

const REQUESTED_BY_PLAYER: String = "player"
const REQUESTED_BY_HOUSEHOLD: String = "household"
const REQUESTED_BY_TOWN: String = "town"

# Who pays. Every project draws on the town's common stores today; household wealth, the
# player's own capital, and public funds are later sources (docs/ECONOMY_MODEL.md, M7).
const FUNDED_BY_TOWN_STORES: String = "town_stores"

const STAGE_SUPPLYING: String = "supplying"
const STAGE_BUILDING: String = "building"
const STAGE_DONE: String = "done"

var id: int = -1
var kind: String = KIND_BUILDING
# The building type this project produces (the tier 1 type for an upgrade; "road" for roads).
var building_type: String = ""
var tile: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
# Road projects: every tile the road covers.
var road_tiles: Array[Vector2i] = []
# Upgrade and fence projects: the building worked on, which keeps working until they are done.
var target_building_id: int = -1
var requested_by: String = REQUESTED_BY_PLAYER
var requester_household_id: int = -1
var funded_by: String = FUNDED_BY_TOWN_STORES
# The family the home is for; it moves in when the project completes.
var claimant_household_id: int = -1
var plot_id: int = -1

var materials_needed: Dictionary = {}
var materials_delivered: Dictionary = {}
# Family-days spent carrying toward the next unit of each material, carried between days.
var haul_progress: float = 0.0
var work_required: float = 1.0
var work_done: float = 0.0
# What happened on the last day, for display: household ids that worked here, and why the
# project could not move on (empty when it did).
var crew_household_ids: Array[int] = []
var blocked_reason: String = ""
var created_day: int = 0

func is_tier0() -> bool:
	return BuildingTiers.is_tier0(building_type)

# Upgrades and fences work on a building that already stands: they reserve no land of their own.
func is_on_standing_building() -> bool:
	return kind == KIND_UPGRADE or kind == KIND_FENCE

func is_home() -> bool:
	return kind != KIND_ROAD and kind != KIND_FENCE and BuildingTiers.get_base_type(building_type) == Building.BUILDING_HOUSE

func get_remaining_materials() -> Dictionary:
	var remaining: Dictionary = {}
	for material: String in materials_needed.keys():
		var left: int = int(materials_needed[material]) - int(materials_delivered.get(material, 0))
		if left > 0:
			remaining[material] = left
	return remaining

func has_all_materials() -> bool:
	return get_remaining_materials().is_empty()

func get_stage() -> String:
	if work_done >= work_required:
		return STAGE_DONE
	if not has_all_materials():
		return STAGE_SUPPLYING
	return STAGE_BUILDING

func get_progress() -> float:
	return clampf(work_done / maxf(work_required, 0.001), 0.0, 1.0)

# Share of the materials on site, 1.0 when nothing is needed.
func get_supply_fraction() -> float:
	var needed: int = 0
	var delivered: int = 0
	for material: String in materials_needed.keys():
		needed += int(materials_needed[material])
		delivered += mini(int(materials_needed[material]), int(materials_delivered.get(material, 0)))
	if needed <= 0:
		return 1.0
	return float(delivered) / float(needed)

func get_max_crew() -> int:
	if kind == KIND_ROAD or is_tier0():
		return EconomyBalance.MAX_CREW_TIER0
	return EconomyBalance.MAX_CREW

func get_footprint() -> Array[Vector2i]:
	if kind == KIND_ROAD:
		return road_tiles.duplicate()
	var tiles: Array[Vector2i] = []
	for y in range(tile.y, tile.y + size.y):
		for x in range(tile.x, tile.x + size.x):
			tiles.append(Vector2i(x, y))
	return tiles

func contains_tile(tile_pos: Vector2i) -> bool:
	if kind == KIND_ROAD:
		return road_tiles.has(tile_pos)
	return tile_pos.x >= tile.x and tile_pos.x < tile.x + size.x and tile_pos.y >= tile.y and tile_pos.y < tile.y + size.y

# The tile builders walk to: the middle of the footprint, or the middle of the road.
func get_site_tile() -> Vector2i:
	if kind == KIND_ROAD:
		return road_tiles[road_tiles.size() / 2] if not road_tiles.is_empty() else tile
	return tile + size / 2
