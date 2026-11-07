class_name TownWoodland
extends RefCounted

# The woods of a town. The player marks woods for clearing; woodcutters (gatherer's camps too)
# fell them, a tile at a time, as the place they cut their wood, and with nothing marked they
# slowly cut the trees nearest them. Woods also spread on their own, slowly: each spring every
# open tile beside them may be chosen to become woods, more likely the more woods stand within a
# few steps (choose_spread; numbers in EconomyBalance, Woodland), and the chosen ones grow in one
# by one through spring, summer, and autumn. Felled land is open land like any other, so a
# clearing nobody uses closes again over the years.
#
# Woods take only land nothing else holds: not water or rock, nothing built or reserved (fields
# are buildings), no road, and no trail or path (TownLogistics). A path in use holds its line
# open; once nobody walks it, it fades and the woods may take it.
#
# Living forests (sprint S2, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md): a woodcutter's wood comes out of
# the trees. Every wooded tile holds timber (the tile's "timber", EconomyBalance.TIMBER_PER_TILE when
# mature; a tile from an older map, with none recorded, is mature). A woodcutter cuts its day's wood
# from the trees it fells (take_timber) and a tile with none left falls, so it fells at the pace its
# wood is made; it brings in less the farther it must go for trees it may fell, and nothing when there
# are none (get_felling_factor). Families' wood gathering cuts the trees near their homes the same
# way. Woods that spread grow in young and gain timber each spring until mature.
# Design: docs/TOWN_BUILDING_MODEL.md (Woodland). A town without a town map has no woodland.

const CLEAR: String = "clear_woods"
# Woods the player keeps (owner, 2026-11-01): a binding designation, like clearing. No tree in them
# is felled, by any woodcutter or gatherer's camp; woodcutters fell elsewhere, and bring in less
# wood the farther they must go for it (get_felling_factor). A tile is kept or marked for clearing,
# never both: the player's later designation replaces the earlier.
const PROTECT: String = "protect_woods"
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
# Woods kept: tile -> true. Saved with the town, like the clearing marks.
var protected: Dictionary = {}
# Unmarked trees a woodcutter was cutting: tile -> working days spent so far. No longer advanced
# since sprint S2 (unmarked trees fall as their timber is cut); kept so older saves load as they were.
var cutting: Dictionary = {}
# This year's chosen spread: tile -> the day of the year it grows in.
var scheduled: Dictionary = {}
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
# Each woodcutter's nearest unmarked trees, for the land_version they were found at.
var _cut_targets: Dictionary = {}
var _cut_targets_version: int = -1

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

# For the woods' pull: beyond the map's edge the woods at the edge are taken to go on.
func is_wooded_or_beyond(tile: Vector2i) -> bool:
	var size: Vector2i = city.logistics.map_size()
	return tile_data(tile.clamp(Vector2i.ZERO, size - Vector2i.ONE))["has_trees"] == true

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
			if protected.erase(tile):
				_cut_targets.clear()
			changed += 1
	return changed

func is_marked(tile: Vector2i) -> bool:
	return marked.has(tile)

# Keeps every wooded tile in the block (taking any clearing marks off it); when all of them are kept
# already, lifts the keeping instead. Returns how many tiles changed.
func protect_block(from: Vector2i, to: Vector2i) -> int:
	var tiles: Array[Vector2i] = get_wooded_in_block(from, to)
	var all_kept: bool = tiles.all(func(tile: Vector2i) -> bool: return protected.has(tile))
	var changed: int = 0
	for tile: Vector2i in tiles:
		if all_kept:
			protected.erase(tile)
			changed += 1
		elif not protected.has(tile):
			protected[tile] = true
			marked.erase(tile)
			cutting.erase(tile)
			changed += 1
	# Which trees woodcutters may fell has changed (the woods themselves have not).
	if changed > 0:
		_cut_targets.clear()
	return changed

func is_protected(tile: Vector2i) -> bool:
	return protected.has(tile)

# Woods a woodcutter may fell: wooded and not kept.
func is_fellable(tile: Vector2i) -> bool:
	return is_wooded(tile) and not protected.has(tile)

# --- Timber ------------------------------------------------------------------------------------

static func get_timber(tile: Dictionary) -> int:
	if tile.get("has_trees", false) != true:
		return 0
	return int(tile.get("timber", EconomyBalance.TIMBER_PER_TILE))

# How much of its wood a woodcutter brings in: all of it from trees it may fell within
# WOODCUTTER_FULL_DISTANCE of its middle, less the farther it must walk to them (woods kept, woods
# felled), with no floor (S13); nothing with no tree it may
# fell left in reach of a route.
func get_felling_factor(building: Building) -> float:
	if not has_map():
		return 1.0
	var target: Vector2i = get_cutting_target(building)
	if target.x < 0:
		return 0.0
	return get_distance_factor(TownLogistics.center_tile(building.tile, building.size), target)

static func get_distance_factor(origin: Vector2i, target: Vector2i) -> float:
	var distance: float = Vector2(target - origin).length()
	return clampf(EconomyBalance.WOODCUTTER_FULL_DISTANCE / maxf(EconomyBalance.WOODCUTTER_FULL_DISTANCE, distance), 0.0, 1.0)

# What a woodcutter at `origin` would bring in, judged by straight distance to the nearest trees it
# could fell (families judging a site; FamilyInitiative). Reads only.
func estimate_felling_factor_at(origin: Vector2i, size: Vector2i) -> float:
	if not has_map():
		return 1.0
	var center: Vector2i = TownLogistics.center_tile(origin, size)
	var best: int = 1 << 30
	var found: Vector2i = Vector2i(-1, -1)
	var map_size: Vector2i = city.logistics.map_size()
	for radius in range(0, maxi(map_size.x, map_size.y)):
		if found.x >= 0 and radius * radius > best:
			break
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if maxi(absi(x - center.x), absi(y - center.y)) == radius and is_fellable(Vector2i(x, y)):
					var distance: int = (Vector2i(x, y) - center).length_squared()
					if distance < best:
						best = distance
						found = Vector2i(x, y)
	if found.x < 0:
		return 0.0
	return get_distance_factor(center, found)

# Where a woodcutter cuts now: the nearest woods marked for clearing it can reach, else the nearest
# trees it may fell.
func get_cutting_target(building: Building) -> Vector2i:
	var target: Vector2i = nearest_marked(building) if not marked.is_empty() else Vector2i(-1, -1)
	if target.x < 0:
		target = nearest_trees(building)
	return target

# Cuts up to `amount` wood from the trees a woodcutter fells, tile by tile; a tile with no timber
# left falls. Returns what was cut (less when the trees run out).
func take_timber(building: Building, amount: int) -> int:
	if not has_map():
		return amount
	var taken: int = 0
	while taken < amount:
		var target: Vector2i = get_cutting_target(building)
		if target.x < 0:
			break
		taken += cut_from(target, amount - taken)
	return taken

# Up to `amount` timber from the trees a family may cut nearest its home, within `reach` tiles.
# Returns what was cut.
func take_timber_near(home: Vector2i, reach: int, amount: int) -> int:
	if not has_map():
		return amount
	var taken: int = 0
	while taken < amount:
		var best: Vector2i = Vector2i(-1, -1)
		var best_distance: int = 1 << 30
		for y in range(home.y - reach, home.y + reach + 1):
			for x in range(home.x - reach, home.x + reach + 1):
				var tile: Vector2i = Vector2i(x, y)
				if is_fellable(tile):
					var distance: int = (tile - home).length_squared()
					if distance < best_distance or (distance == best_distance and is_before(tile, best)):
						best_distance = distance
						best = tile
		if best.x < 0:
			break
		taken += cut_from(best, amount - taken)
	return taken

func cut_from(tile: Vector2i, amount: int) -> int:
	var data: Dictionary = tile_data(tile)
	var timber: int = get_timber(data)
	var cut: int = mini(amount, timber)
	data["timber"] = timber - cut
	if timber - cut <= 0:
		fell(tile)
		land_version += 1
		city.logistics.mark_layout_changed()
	return cut

# The first day of spring: young woods put on timber, up to a mature tile's.
func grow_timber() -> void:
	for row: Array in city.local_map:
		for data: Dictionary in row:
			if data.get("has_trees", false) == true and data.has("timber") and int(data["timber"]) < EconomyBalance.TIMBER_PER_TILE:
				data["timber"] = mini(EconomyBalance.TIMBER_PER_TILE, int(data["timber"]) + EconomyBalance.TIMBER_GROWTH_PER_YEAR)

func get_standing_timber() -> int:
	var total: int = 0
	if not has_map():
		return total
	for row: Array in city.local_map:
		for data: Dictionary in row:
			total += get_timber(data)
	return total

# --- Hunting grounds under the axe ----------------------------------------------------------------

# How far ahead felling is judged a threat to a lodge's game: within this many days at today's pace,
# its woods fall below what gives a full bag (owner, 2026-11-02: warn before much is lost).
const THREAT_HORIZON_DAYS: float = 180.0

# The hunting workplaces families work whose woods the town's felling is taking, or will take within
# THREAT_HORIZON_DAYS: woodcutters cutting inside their reach, or woods marked for clearing there.
# Each: {"building", "woodcutters" (felling inside its reach), "wooded" (its share of the woods in
# reach), "full" (what gives a full bag), "factor" (its bag now), "after" (its bag at the horizon),
# "days" (until its bag starts to fall; 0 when it already falls with each tree), "marked" (tiles
# marked for clearing in its reach), "kept" (wooded tiles in its reach already kept), "rect"}.
# Reads only: the felling it predicts is what fell_woods would do.
func get_hunting_threats() -> Array[Dictionary]:
	var threats: Array[Dictionary] = []
	if not has_map():
		return threats
	var targets: Dictionary = {}
	for woodcutter: Building in get_woodcutters():
		var target: Dictionary = get_felling_target(woodcutter)
		if not target.is_empty():
			targets[woodcutter] = target
	for building: Building in city.buildings:
		if building.assigned_household_id < 0 or TownLand.get_reach_kind(building.type) != "woods":
			continue
		var rect: Rect2i = TownLand.get_reach_rect(building.type, building.tile, building.size)
		var rate: float = 0.0
		var cutters: Array[Building] = []
		for woodcutter: Building in targets.keys():
			if rect.has_point(targets[woodcutter]["tile"]):
				rate += float(targets[woodcutter]["rate"])
				cutters.append(woodcutter)
		var marked_here: int = 0
		var kept: int = 0
		var wooded_tiles: Array[Vector2i] = get_wooded_in_rect(rect)
		for tile: Vector2i in wooded_tiles:
			marked_here += 1 if marked.has(tile) else 0
			kept += 1 if protected.has(tile) else 0
		if rate <= 0.0 and marked_here == 0:
			continue
		var full: float = float(EconomyBalance.HUNTER_FULL_WOODS_TILES)
		# Its share of the woods in reach (shared woods count their share), and what one tree felled
		# there takes from it on average.
		var wooded: float = city.land.count_woods_share(building.tile, building.size, city.land.get_rival_reaches(building.type, building.tile, false))
		var per_tile: float = wooded / maxf(1.0, float(wooded_tiles.size()))
		var lost: float = minf(float(wooded_tiles.size() - kept), rate * THREAT_HORIZON_DAYS + float(marked_here)) * per_tile
		if wooded - lost >= full:
			continue
		var days: float = 0.0 if wooded <= full else maxf(0.0, wooded - full - float(marked_here) * per_tile) / maxf(0.0001, rate * per_tile)
		var after: float = clampf((wooded - lost) / full, 0.0, 1.0)
		threats.append({"building": building, "woodcutters": cutters, "wooded": wooded, "full": full, "factor": city.land.get_reach_factor(building), "after": after, "days": days, "marked": marked_here, "kept": kept, "rect": rect})
	return threats

# Wooded tiles in a rectangle, within the map (no limit on its size, unlike block_rect).
func get_wooded_in_rect(rect: Rect2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not has_map():
		return tiles
	var inside: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, city.logistics.map_size()))
	for y in range(inside.position.y, inside.end.y):
		for x in range(inside.position.x, inside.end.x):
			if tile_data(Vector2i(x, y))["has_trees"] == true:
				tiles.append(Vector2i(x, y))
	return tiles

# Where a woodcutter fells now and how fast, as fell_woods does it: {"tile", "rate" (tiles a day,
# a winter's faster felling spread over the year)}; empty when it fells nothing.
func get_felling_target(building: Building) -> Dictionary:
	var work: float = city.get_work_time_factor(building)
	if building.is_tier0():
		work *= EconomyBalance.TIER0_OUTPUT_FRACTION
	work *= 1.0 + (EconomyBalance.WINTER_FELLING_FACTOR - 1.0) / 4.0
	var target: Vector2i = nearest_marked(building) if not marked.is_empty() else Vector2i(-1, -1)
	if target.x >= 0:
		return {"tile": target, "rate": work / EconomyBalance.CLEAR_DAYS_PER_TILE}
	# Unmarked trees fall as their timber is cut (take_timber): the wood it makes a day, over a tile's.
	target = nearest_trees(building)
	if target.x < 0:
		return {}
	var wood: float = city.get_base_building_output_amount(building.type) * city.get_work_time_factor(building) * get_felling_factor(building)
	return {"tile": target, "rate": wood / maxf(1.0, float(get_timber(tile_data(target))))}

# Keeps the woods within a hunting workplace's reach (the hunting-ground card's answer): every
# wooded tile there, by the same binding designation as the Keep woods tool. Returns how many tiles
# were newly kept; never lifts keeping that is already there.
func keep_hunting_ground(building: Building) -> int:
	var changed: int = 0
	for tile: Vector2i in get_wooded_in_rect(TownLand.get_reach_rect(building.type, building.tile, building.size)):
		if not protected.has(tile):
			protected[tile] = true
			marked.erase(tile)
			cutting.erase(tile)
			changed += 1
	if changed > 0:
		_cut_targets.clear()
	return changed

# What keeping a block would cost a woodcutter: the share of its wood it would still bring in, from
# the nearest trees it could then fell (as get_felling_factor judges it, by straight distance).
# Reads only.
func estimate_felling_factor_if_kept(building: Building, rect: Rect2i) -> float:
	var origin: Vector2i = TownLogistics.center_tile(building.tile, building.size)
	var size: Vector2i = city.logistics.map_size()
	var best: int = 1 << 30
	var found: Vector2i = Vector2i(-1, -1)
	for y in range(size.y):
		for x in range(size.x):
			var tile: Vector2i = Vector2i(x, y)
			if is_fellable(tile) and not rect.has_point(tile) and (tile - origin).length_squared() < best:
				best = (tile - origin).length_squared()
				found = tile
	if found.x < 0:
		return 0.0
	return get_distance_factor(origin, found)

# Why woods marked for clearing are not being felled, or "" when they are (Planning page).
func get_clearing_obstacle() -> String:
	if marked.is_empty():
		return ""
	var woodcutters: Array[Building] = get_woodcutters()
	if woodcutters.is_empty():
		return "needs a working woodcutter"
	if city.should_skip_for_food_shortage():
		return "felling stops while the town is out of food"
	if woodcutters.all(func(b: Building) -> bool: return nearest_marked(b).x < 0):
		return "no woodcutter can reach them"
	return ""

# Working woodcutters of any tier: a gatherer's camp fells too, at its tier's pace.
func get_woodcutters() -> Array[Building]:
	var woodcutters: Array[Building] = []
	for building: Building in city.buildings:
		if BuildingTiers.get_base_type(building.type) == Building.BUILDING_WOODCUTTER and building.can_produce():
			woodcutters.append(building)
	return woodcutters

# --- Daily change ------------------------------------------------------------------------------

# A day: woodcutters fell trees; on the first day of spring the year's spread is chosen, and
# through spring, summer, and autumn the chosen tiles grow in on their days. Trees felled or
# grown change routes, so they count as a layout change.
func advance_day() -> void:
	if not has_map():
		return
	var changed: bool = fell_woods()
	var today: int = city.get_day_of_year()
	if today == 1:
		grow_timber()
		choose_spring_spread()
	if grow_scheduled(today):
		changed = true
	if changed:
		land_version += 1
		city.logistics.mark_layout_changed()

# Each working woodcutter puts its day into the marked tile nearest it that it can reach, as
# much of the day as travel and spare time leave (City.get_work_time_factor), and fells it in
# CLEAR_DAYS_PER_TILE working days whatever timber is left. With nothing marked, the trees nearest
# it fall as their timber is cut (take_timber). A gatherer's camp works at its tier's pace.
func fell_woods() -> bool:
	if city.should_skip_for_food_shortage() or marked.is_empty():
		return false
	var felled: bool = false
	for building: Building in get_woodcutters():
		var work: float = city.get_work_time_factor(building)
		if building.is_tier0():
			work *= EconomyBalance.TIER0_OUTPUT_FRACTION
		if city.get_season_index() == 3:
			work *= EconomyBalance.WINTER_FELLING_FACTOR
		var target: Vector2i = nearest_marked(building)
		if target.x < 0:
			continue
		marked[target] = float(marked.get(target, 0.0)) + work
		if float(marked[target]) >= EconomyBalance.CLEAR_DAYS_PER_TILE:
			fell(target)
			felled = true
	return felled

# The wooded tile nearest a woodcutter that a route reaches: ring by ring outward, nearest first
# within a ring. Kept until the woods change.
func nearest_trees(building: Building) -> Vector2i:
	if _cut_targets_version != land_version:
		_cut_targets_version = land_version
		_cut_targets.clear()
	if _cut_targets.has(building.id) and is_fellable(_cut_targets[building.id]):
		return _cut_targets[building.id]
	var origin: Vector2i = TownLogistics.center_tile(building.tile, building.size)
	var size: Vector2i = city.logistics.map_size()
	var found: Vector2i = Vector2i(-1, -1)
	for radius in range(0, maxi(size.x, size.y)):
		var ring: Array[Vector2i] = []
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) == radius and is_fellable(Vector2i(x, y)):
					ring.append(Vector2i(x, y))
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (a - origin).length_squared()
			var db: int = (b - origin).length_squared()
			return da < db or (da == db and is_before(a, b)))
		for tile: Vector2i in ring:
			if not is_inf(city.logistics.effort_between(origin, tile)):
				found = tile
				break
		if found.x >= 0:
			break
	_cut_targets[building.id] = found
	return found

func nearest_marked(building: Building) -> Vector2i:
	return nearest_reachable(building, marked.keys())

# The tile of `tiles` nearest a building that a route reaches: nearest by distance, ties broken by
# row then column. Also used for land marked to till (TownFarmland).
func nearest_reachable(building: Building, tiles: Array) -> Vector2i:
	var origin: Vector2i = TownLogistics.center_tile(building.tile, building.size)
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
	if protected.has(tile):
		return
	tile_data(tile)["has_trees"] = false
	marked.erase(tile)
	cutting.erase(tile)
	felled_count += 1
	update_frontier_around(tile)

# --- Spreading ---------------------------------------------------------------------------------

# One year's draws, the same for a town and year whenever they are made (a loaded game draws
# what the original would have), as the town's other chances are (City.make_values_rng).
func make_spread_rng(year: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), year, "forest"])
	return rng

# The first day of spring: this year's spread is chosen from the woods as they stand, and each
# chosen tile gets a day between spring and the end of autumn to grow in. So the year's new
# woods appear one by one through the growing season, and none of them spreads further until
# next spring.
func choose_spring_spread() -> void:
	spread_years += 1
	var rng: RandomNumberGenerator = make_spread_rng(spread_years)
	for tile: Vector2i in choose_spread(func() -> float: return rng.randf()):
		scheduled[tile] = rng.randi_range(1, EconomyBalance.FOREST_GROWING_DAYS)

# Chosen tiles whose day has come become woods, if nothing has taken the land meanwhile.
# Returns whether any did.
func grow_scheduled(today: int) -> bool:
	var grown: bool = false
	for tile: Vector2i in scheduled.keys():
		if int(scheduled[tile]) > today:
			continue
		scheduled.erase(tile)
		if can_forest(tile):
			plant(tile)
			grown = true
	return grown

# One year of spreading at once (tests and tools): chosen as in spring, all grown in now.
func spread_forest(draw: Callable) -> Array[Vector2i]:
	var grown: Array[Vector2i] = []
	if not has_map():
		return grown
	spread_years += 1
	grown = choose_spread(draw)
	for tile: Vector2i in grown:
		plant(tile)
	return grown

# Every candidate is judged against the woods as they stand and draws one number from `draw`
# (uniform in [0, 1)), in row order; nothing changes until all have drawn. Returns the winners.
func choose_spread(draw: Callable) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	if not has_map():
		return chosen
	for tile: Vector2i in get_spread_candidates():
		if float(draw.call()) < get_spread_chance(tile):
			chosen.append(tile)
	return chosen

func plant(tile: Vector2i) -> void:
	tile_data(tile)["has_trees"] = true
	tile_data(tile)["timber"] = EconomyBalance.YOUNG_WOODS_TIMBER
	spread_count += 1
	update_frontier_around(tile)

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
		if is_wooded_or_beyond(tile + offset):
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
