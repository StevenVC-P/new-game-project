class_name TownWoodland
extends RefCounted

# The woods of a town. The player marks woods for clearing; woodcutters fell them, a tile at a
# time, as the place they cut their wood. Woods also spread on their own, slowly: once a year
# every open tile beside them may become woods, more likely the more woods stand within a few
# steps (spread_forest; numbers in EconomyBalance, Woodland). Felled land is open land like any
# other, so a clearing nobody uses closes again over the years.
#
# Woods take only land nothing else holds: not water or rock, nothing built or reserved (fields
# are buildings), no road, and no trail or path (TownLogistics). A path in use holds its line
# open; once nobody walks it, it fades and the woods may take it.
# Design: docs/TOWN_BUILDING_MODEL.md (Woodland). A town without a town map has no woodland.

const CLEAR: String = "clear_woods"
# The largest block one marking covers, tiles per side.
const MAX_MARK_SIDE: int = 16
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# Woods marked for clearing: tile -> working days spent felling it so far.
var marked: Dictionary = {}
# Bumped whenever trees are felled or spread, so views redraw.
var land_version: int = 0
var felled_count: int = 0
var spread_count: int = 0
# Yearly spreading passes run so far.
var spread_years: int = 0
# Open tiles with woods on a side: the only places woods can spread to. Found from the town map
# when first needed and kept up as woods are felled or spread; not saved (the leading
# underscore keeps it out of SaveCodec), so a loaded town finds it again.
var _frontier: Dictionary = {}
var _frontier_ready: bool = false
# (offset, influence) of every tile within the influence radius, nearest first.
var _influence_offsets: Array = []

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

func tile_data(tile: Vector2i) -> Dictionary:
	return city.local_map[tile.y][tile.x]

func is_inside(tile: Vector2i) -> bool:
	var size: Vector2i = city.logistics.map_size()
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

func is_wooded(tile: Vector2i) -> bool:
	return is_inside(tile) and tile_data(tile)["has_trees"] == true

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

# A day: woodcutters fell marked woods, and on the last day of each year the woods spread.
# Trees felled or spread change routes, so they count as a layout change.
func advance_day() -> void:
	if not has_map():
		return
	var changed: bool = fell_marked_woods()
	var day: int = city.construction.day
	if day > 0 and day % Calendar.DAYS_PER_YEAR == 0:
		var rng: RandomNumberGenerator = make_spread_rng(day / Calendar.DAYS_PER_YEAR)
		if not spread_forest(func() -> float: return rng.randf()).is_empty():
			changed = true
	if changed:
		land_version += 1
		city.logistics.mark_layout_changed()

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
		return da < db or (da == db and is_before(a, b)))
	for tile: Vector2i in tiles:
		if not is_inf(city.logistics.effort_between(origin, tile)):
			return tile
	return Vector2i(-1, -1)

static func is_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)

func fell(tile: Vector2i) -> void:
	tile_data(tile)["has_trees"] = false
	marked.erase(tile)
	felled_count += 1
	update_frontier_around(tile)

# --- Spreading ---------------------------------------------------------------------------------

# One year's draws, the same for a town and year whenever they are made (a loaded game draws
# what the original would have), as the town's other chances are (City.make_values_rng).
func make_spread_rng(year: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), year, "forest"])
	return rng

# One year of spreading. Every candidate is judged against the woods as they stood at the start
# of the pass and draws one number from `draw` (uniform in [0, 1)); the winners become woods
# only after all have drawn, so woods never spread twice in a year. Candidates draw in row
# order. Returns the tiles that became woods.
func spread_forest(draw: Callable) -> Array[Vector2i]:
	var grown: Array[Vector2i] = []
	if not has_map():
		return grown
	spread_years += 1
	for tile: Vector2i in get_spread_candidates():
		if float(draw.call()) < get_spread_chance(tile):
			grown.append(tile)
	for tile: Vector2i in grown:
		tile_data(tile)["has_trees"] = true
		spread_count += 1
		update_frontier_around(tile)
	return grown

# Open tiles beside woods (sharing a side) that woods can take, in row order.
func get_spread_candidates() -> Array[Vector2i]:
	ensure_frontier()
	var candidates: Array[Vector2i] = []
	for tile: Vector2i in _frontier.keys():
		if can_forest(tile):
			candidates.append(tile)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return is_before(a, b))
	return candidates

# Land woods can take: open ground (meadow or unworked farmland) that nothing holds.
func can_forest(tile: Vector2i) -> bool:
	var data: Dictionary = tile_data(tile)
	return data["type"] == "ground" and data["has_trees"] != true and data["occupied"] != true and data.get("has_road", false) != true and city.logistics.get_tile_path_level(tile) == TownLogistics.PATH_NONE

# The pull of nearby woods on a tile: each wooded tile within the radius adds the decay raised to
# its distance in steps less one.
func get_forest_influence(tile: Vector2i) -> float:
	var influence: float = 0.0
	for entry: Array in get_influence_offsets():
		var offset: Vector2i = entry[0]
		if is_wooded(tile + offset):
			influence += float(entry[1])
	return influence

# This year's chance that woods take a tile, rising with influence toward the max chance.
static func get_spread_chance_for(influence: float) -> float:
	if influence <= 0.0:
		return 0.0
	var max_chance: float = EconomyBalance.FOREST_SPREAD_MAX_CHANCE
	return max_chance * (1.0 - pow(1.0 - EconomyBalance.FOREST_SPREAD_BASE_CHANCE / max_chance, influence))

func get_spread_chance(tile: Vector2i) -> float:
	return get_spread_chance_for(get_forest_influence(tile))

func get_influence_offsets() -> Array:
	if _influence_offsets.is_empty():
		var radius: int = EconomyBalance.FOREST_INFLUENCE_RADIUS
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var steps: int = absi(dx) + absi(dy)
				if steps >= 1 and steps <= radius:
					_influence_offsets.append([Vector2i(dx, dy), pow(EconomyBalance.FOREST_INFLUENCE_DECAY, steps - 1)])
	return _influence_offsets

# --- Frontier ----------------------------------------------------------------------------------

func ensure_frontier() -> void:
	if _frontier_ready:
		return
	_frontier_ready = true
	_frontier.clear()
	var size: Vector2i = city.logistics.map_size()
	for y in range(size.y):
		for x in range(size.x):
			update_frontier_at(Vector2i(x, y))

# Call when trees on the town map change outside this class (tests, tools).
func forget_frontier() -> void:
	_frontier_ready = false

func update_frontier_around(tile: Vector2i) -> void:
	if not _frontier_ready:
		return
	update_frontier_at(tile)
	for side: Vector2i in SIDES:
		update_frontier_at(tile + side)

func update_frontier_at(tile: Vector2i) -> void:
	if not is_inside(tile):
		return
	var beside_woods: bool = false
	if not is_wooded(tile):
		for side: Vector2i in SIDES:
			if is_wooded(tile + side):
				beside_woods = true
				break
	if beside_woods:
		_frontier[tile] = true
	else:
		_frontier.erase(tile)
