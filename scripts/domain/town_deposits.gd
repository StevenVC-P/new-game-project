class_name TownDeposits
extends RefCounted

# Deposits on the town map that workplaces stand on and work out (owner decision 2026-10-25: some
# resources must be built on). Stone (sprint S1b): a quarry or stone pit may stand on stone-deposit
# tiles, rough ground nothing else is built on, and must take in at least one. Clay (sprint S5): a
# brickworks must take in clay, which lies on open ground by rivers and lakes. What a workplace gets
# depends on the deposit underfoot: each tile's grade, from the edge of a patch (poor) to the heart
# of a large one (good), and how many such tiles it covers. Every tile holds a finite amount that
# working takes away; a tile worked out is plain ground or rock, and a workplace with nothing left
# underfoot is worked out and lets its family go.
#
# The amount left is kept on the tile ("deposit_left"); town maps are saved whole, and a tile from
# an older save, with no amount recorded, is untouched. Some stone is limestone ("stone_kind"), which
# a lime kiln must stand near (is_near_limestone). Grade is read from the map's shape, so it needs no
# randomness of its own. Without a town map nothing here applies.

const STONE: String = "stone"
const CLAY: String = "clay"
const LIMESTONE: String = "limestone"
const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
# The deposit each workplace (by its tier 1 type) stands on and works.
const DEPOSIT_OF: Dictionary = {"quarry": STONE, "brickworks": CLAY}

static func get_units_per_tile(kind: String) -> int:
	return EconomyBalance.CLAY_DEPOSIT_UNITS_PER_TILE if kind == CLAY else EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE

static func is_deposit(tile: Dictionary, kind: String) -> bool:
	return str(tile.get("resource", "none")) == kind and get_left(tile, kind) > 0

static func is_stone(tile: Dictionary) -> bool:
	return is_deposit(tile, STONE)

static func get_left(tile: Dictionary, kind: String = STONE) -> int:
	if str(tile.get("resource", "none")) != kind:
		return 0
	return int(tile.get("deposit_left", get_units_per_tile(kind)))

# The deposit a workplace works, or "".
static func get_deposit_kind(building_type: String) -> String:
	return str(DEPOSIT_OF.get(BuildingTiers.get_base_type(building_type), ""))

static func draws_on_deposit(building: Building) -> bool:
	return get_deposit_kind(building.type) != ""

# From DEPOSIT_GRADE_FLOOR for a lone tile to 1.0 with the deposit all round it.
static func get_grade(local_map: Array, pos: Vector2i, kind: String = STONE) -> float:
	var around: int = 0
	for offset: Vector2i in NEIGHBOURS:
		var at: Vector2i = pos + offset
		if at.y >= 0 and at.y < local_map.size() and at.x >= 0 and at.x < (local_map[at.y] as Array).size():
			around += 1 if str((local_map[at.y][at.x] as Dictionary).get("resource", "none")) == kind else 0
	return EconomyBalance.DEPOSIT_GRADE_FLOOR + (1.0 - EconomyBalance.DEPOSIT_GRADE_FLOOR) * float(around) / float(NEIGHBOURS.size())

# The share of a full workplace's output a footprint gives: the grades of the deposit under it,
# against QUARRY_FULL_DEPOSIT_TILES tiles of the best, at most 1.
static func get_footprint_factor(local_map: Array, origin: Vector2i, size: Vector2i, kind: String = STONE) -> float:
	var total: float = 0.0
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			if y >= 0 and y < local_map.size() and x >= 0 and x < (local_map[y] as Array).size() and is_deposit(local_map[y][x], kind):
				total += get_grade(local_map, Vector2i(x, y), kind)
	return minf(1.0, total / float(EconomyBalance.QUARRY_FULL_DEPOSIT_TILES))

# What the deposit under a workplace allows of its full output (1 for one that works none).
static func get_factor(city: City, building: Building) -> float:
	var kind: String = get_deposit_kind(building.type)
	if city.local_map.is_empty() or kind == "":
		return 1.0
	return get_footprint_factor(city.local_map, building.tile, building.size, kind)

static func get_quarry_factor(city: City, building: Building) -> float:
	return get_factor(city, building)

# Takes what a workplace got out of the deposit under it, from the fullest tile first, so it works
# its deposit down evenly. A tile worked out becomes plain ground or rock.
static func extract(city: City, building: Building, amount: int) -> void:
	var kind: String = get_deposit_kind(building.type)
	if city.local_map.is_empty() or kind == "":
		return
	for _unit in range(amount):
		var fullest: Dictionary = {}
		for y in range(building.tile.y, building.tile.y + building.size.y):
			for x in range(building.tile.x, building.tile.x + building.size.x):
				var tile: Dictionary = city.local_map[y][x]
				if is_deposit(tile, kind) and (fullest.is_empty() or get_left(tile, kind) > get_left(fullest, kind)):
					fullest = tile
		if fullest.is_empty():
			return
		fullest["deposit_left"] = get_left(fullest, kind) - 1
		if int(fullest["deposit_left"]) <= 0:
			fullest["resource"] = "none"
			fullest.erase("stone_kind")
			city.logistics.mark_layout_changed()

static func get_left_under(city: City, building: Building) -> int:
	var kind: String = get_deposit_kind(building.type)
	var left: int = 0
	if city.local_map.is_empty() or kind == "":
		return left
	for y in range(building.tile.y, building.tile.y + building.size.y):
		for x in range(building.tile.x, building.tile.x + building.size.x):
			left += get_left(city.local_map[y][x], kind)
	return left

static func get_stone_left(city: City, building: Building) -> int:
	return get_left_under(city, building)

static func is_worked_out(city: City, building: Building) -> bool:
	return draws_on_deposit(building) and not city.local_map.is_empty() and get_factor(city, building) <= 0.0

# Limestone within `reach` tiles of a footprint (a lime kiln's access rule, sprint S5).
static func is_near_limestone(local_map: Array, origin: Vector2i, size: Vector2i, reach: int) -> bool:
	for y in range(origin.y - reach, origin.y + size.y + reach):
		for x in range(origin.x - reach, origin.x + size.x + reach):
			if y >= 0 and y < local_map.size() and x >= 0 and x < (local_map[y] as Array).size():
				var tile: Dictionary = local_map[y][x]
				if is_stone(tile) and str(tile.get("stone_kind", "")) == LIMESTONE:
					return true
	return false

# The best a workplace on a deposit anywhere on the map could get, as a share of a full one (the
# site survey).
static func get_best_factor(local_map: Array, kind: String = STONE) -> float:
	var best: float = 0.0
	var size: Vector2i = Vector2i(3, 3)
	for y in range(local_map.size() - size.y + 1):
		for x in range((local_map[y] as Array).size() - size.x + 1):
			var has: bool = false
			for dy in range(size.y):
				for dx in range(size.x):
					has = has or is_deposit(local_map[y + dy][x + dx], kind)
			if has:
				best = maxf(best, get_footprint_factor(local_map, Vector2i(x, y), size, kind))
	return best

static func get_best_quarry_factor(local_map: Array) -> float:
	return get_best_factor(local_map, STONE)

static func describe_quality(factor: float) -> String:
	if factor <= 0.0:
		return "none"
	if factor >= 0.9:
		return "good"
	if factor >= 0.5:
		return "fair"
	return "poor"
