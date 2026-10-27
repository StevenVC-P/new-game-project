class_name TownFarmland
extends RefCounted

# Farmland the town makes. Clearing woods only clears the land; tilling is the second step
# (owner, 2026-10-27). The player marks open ground to till, cleared woods or meadow, and the
# families working the town's fields (farms and forager's gardens) till it, a tile at a time, as
# part of their work; a tilled tile is farmland (is_fertile), where a farm can stand.
# Design: docs/TOWN_BUILDING_MODEL.md (Woodland). A town without a town map has no farmland work.

const TILL: String = "till_land"

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# Land marked for tilling: tile -> working days spent tilling it so far.
var marked: Dictionary = {}
var tilled_count: int = 0
# Bumped whenever land is tilled, so views redraw the ground.
var land_version: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

# Open ground that is not farmland yet: no woods, rock, water, road, or anything built on it.
static func can_till(tile: Dictionary) -> bool:
	return tile["type"] == "ground" and tile["has_trees"] != true and tile["occupied"] != true and tile.get("has_road", false) != true and tile["is_fertile"] != true

# Same block as the clearing tool (TownWoodland.block_rect).
func get_tillable_in_block(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not has_map():
		return tiles
	var rect: Rect2i = city.woodland.block_rect(from, to)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if can_till(city.local_map[y][x]):
				tiles.append(Vector2i(x, y))
	return tiles

# Marks every tillable tile in the block; when all of them are marked already, takes the marks
# off instead. Returns how many tiles changed.
func mark_block(from: Vector2i, to: Vector2i) -> int:
	var tiles: Array[Vector2i] = get_tillable_in_block(from, to)
	var all_marked: bool = true
	for tile: Vector2i in tiles:
		if not marked.has(tile):
			all_marked = false
			break
	var changed: int = 0
	for tile: Vector2i in tiles:
		if all_marked:
			marked.erase(tile)
			changed += 1
		elif not marked.has(tile):
			marked[tile] = 0.0
			changed += 1
	return changed

func is_marked(tile: Vector2i) -> bool:
	return marked.has(tile)

# Working fields of any tier.
func get_farms() -> Array[Building]:
	var farms: Array[Building] = []
	for building: Building in city.buildings:
		if TownLogistics.is_field(building) and building.can_produce():
			farms.append(building)
	return farms

# A day: each working field puts its day into the marked tile nearest it that it can reach, as
# much of the day as travel and spare time leave, at its tier's pace; its harvest is unchanged.
# Marks on land something else has taken since (built on, grown over) are dropped.
func advance_day() -> void:
	if not has_map() or marked.is_empty():
		return
	for tile: Vector2i in marked.keys():
		if not can_till(city.local_map[tile.y][tile.x]):
			marked.erase(tile)
	if city.should_skip_for_food_shortage():
		return
	var changed: bool = false
	for farm: Building in get_farms():
		if marked.is_empty():
			break
		var target: Vector2i = city.woodland.nearest_reachable(farm, marked.keys())
		if target.x < 0:
			continue
		var work: float = city.get_work_time_factor(farm)
		if farm.is_tier0():
			work *= EconomyBalance.TIER0_OUTPUT_FRACTION
		marked[target] = float(marked[target]) + work
		if float(marked[target]) >= EconomyBalance.TILL_DAYS_PER_TILE:
			till(target)
			changed = true
	if changed:
		land_version += 1

func till(tile: Vector2i) -> void:
	(city.local_map[tile.y][tile.x] as Dictionary)["is_fertile"] = true
	marked.erase(tile)
	tilled_count += 1
