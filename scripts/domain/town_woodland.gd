class_name TownWoodland
extends RefCounted

# The woods of a town. The player marks woods for clearing; woodcutters fell them, a tile at a
# time, as the place they cut their wood. Felled land then belongs to whichever of two things
# wins it: growth spreading from the wooded tiles around it, or the wear of people walking it
# (TownLogistics.wear). A path in use holds the land open; a clearing nobody uses fills with
# saplings and then woods again, from its edges inward, over years.
#
# Only felled land grows back. Meadows that were never wooded stay open, so the town keeps the
# woods the regional map shows it and they only take back what was theirs.
# Design: docs/TOWN_BUILDING_MODEL.md (Woodland). A town without a town map has no woodland.

const CLEAR: String = "clear_woods"
# The largest block one marking covers, tiles per side.
const MAX_MARK_SIDE: int = 16
const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# Woods marked for clearing: tile -> working days spent felling it so far.
var marked: Dictionary = {}
# Felled land that is not woods again: tile -> growth, 0 to 1.
var regrowth: Dictionary = {}
# Bumped whenever trees are felled or grow back or saplings appear, so views redraw.
var land_version: int = 0
var felled_count: int = 0
var regrown_count: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func tile_data(tile: Vector2i) -> Dictionary:
	return city.local_map[tile.y][tile.x]

# --- Marking -----------------------------------------------------------------------------------

# The block between two corners, at most MAX_MARK_SIDE a side (measured from the first corner)
# and within the map.
func block_rect(from: Vector2i, to: Vector2i) -> Rect2i:
	var limited: Vector2i = from + (to - from).clamp(Vector2i.ONE * -(MAX_MARK_SIDE - 1), Vector2i.ONE * (MAX_MARK_SIDE - 1))
	var rect: Rect2i = Rect2i(from.min(limited), (from - limited).abs() + Vector2i.ONE)
	return rect.intersection(Rect2i(Vector2i.ZERO, city.logistics.map_size()))

func get_wooded_in_block(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not has_map():
		return tiles
	var rect: Rect2i = block_rect(from, to)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if tile_data(Vector2i(x, y))["has_trees"] == true:
				tiles.append(Vector2i(x, y))
	return tiles

# Marks every wooded tile in the block for clearing; when all of them are marked already, takes
# the marks off instead. Returns how many tiles changed.
func mark_block(from: Vector2i, to: Vector2i) -> int:
	var tiles: Array[Vector2i] = get_wooded_in_block(from, to)
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

func get_woodcutters() -> Array[Building]:
	var woodcutters: Array[Building] = []
	for building: Building in city.buildings:
		if building.type == Building.BUILDING_WOODCUTTER and building.can_produce():
			woodcutters.append(building)
	return woodcutters

# --- Daily change ------------------------------------------------------------------------------

# A day: woodcutters fell marked woods, then felled land grows back or is held open by wear.
# Trees felled or grown back change routes, so they count as a layout change.
func advance_day() -> void:
	if not has_map():
		return
	var trees_changed: bool = fell_marked_woods()
	var growth: Dictionary = grow_back()
	if trees_changed or growth["trees"]:
		city.logistics.mark_layout_changed()
	if trees_changed or growth["trees"] or growth["saplings"]:
		land_version += 1

# Each working woodcutter puts its day into the marked tile nearest it that it can reach, as
# much of the day as travel and spare time leave (City.get_work_time_factor).
func fell_marked_woods() -> bool:
	if marked.is_empty() or city.should_skip_for_food_shortage():
		return false
	var felled: bool = false
	for building: Building in get_woodcutters():
		var target: Vector2i = nearest_marked(building)
		if target.x < 0:
			continue
		marked[target] = float(marked[target]) + city.get_work_time_factor(building)
		if float(marked[target]) >= EconomyBalance.CLEAR_DAYS_PER_TILE:
			fell(target)
			felled = true
	return felled

# Nearest by distance, ties broken by row then column; a tile no route reaches is passed over.
func nearest_marked(building: Building) -> Vector2i:
	var origin: Vector2i = TownLogistics.center_tile(building.tile, building.size)
	var tiles: Array = marked.keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a - origin).length_squared()
		var db: int = (b - origin).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for tile: Vector2i in tiles:
		if not is_inf(city.logistics.effort_between(origin, tile)):
			return tile
	return Vector2i(-1, -1)

func fell(tile: Vector2i) -> void:
	tile_data(tile)["has_trees"] = false
	marked.erase(tile)
	regrowth[tile] = 0.0
	felled_count += 1

# Felled ground that nothing stands on gains growth from its wooded neighbours and loses it to
# wear; returns {"trees", "saplings"}: whether any tile became woods, or showed or lost saplings.
func grow_back() -> Dictionary:
	var changed: Dictionary = {"trees": false, "saplings": false}
	for tile: Vector2i in regrowth.keys():
		var data: Dictionary = tile_data(tile)
		var growth: float = 0.0
		if can_regrow(data):
			var seeds: float = float(count_wooded_neighbours(tile)) / float(NEIGHBOURS.size())
			var trample: float = float(city.logistics.wear.get(tile, 0.0)) / EconomyBalance.TRAMPLE_WEAR
			growth = clampf(float(regrowth[tile]) + (seeds - trample) / EconomyBalance.REGROWTH_DAYS, 0.0, 1.0)
		var saplings: bool = growth >= EconomyBalance.SAPLING_GROWTH and growth < 1.0
		if saplings != (data.get("saplings", false) == true):
			data["saplings"] = saplings
			changed["saplings"] = true
		if growth >= 1.0:
			data["has_trees"] = true
			regrowth.erase(tile)
			regrown_count += 1
			changed["trees"] = true
		else:
			regrowth[tile] = growth
	return changed

# Open ground: nothing built, reserved, or paved on it.
static func can_regrow(tile: Dictionary) -> bool:
	return tile["type"] == "ground" and tile["has_trees"] != true and tile["occupied"] != true and tile.get("has_road", false) != true

func count_wooded_neighbours(tile: Vector2i) -> int:
	var size: Vector2i = city.logistics.map_size()
	var count: int = 0
	for offset: Vector2i in NEIGHBOURS:
		var neighbour: Vector2i = tile + offset
		if neighbour.x >= 0 and neighbour.y >= 0 and neighbour.x < size.x and neighbour.y < size.y and tile_data(neighbour)["has_trees"] == true:
			count += 1
	return count
