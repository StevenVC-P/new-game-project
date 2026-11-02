class_name TownDeposits
extends RefCounted

# Stone deposits on the town map (owner decision 2026-10-25: a quarry sits on stone; sprint S1b,
# docs/ECONOMIC_FOUNDATIONS_ROADMAP.md). A quarry may stand on stone-deposit tiles, which are rough
# ground nothing else is built on, and must take in at least one. What it cuts depends on the stone
# underfoot: each deposit tile's grade, from the edge of an outcrop (poor) to the heart of a large
# deposit (good), and how many such tiles it covers. Every tile holds a finite amount
# (EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE) that cutting takes away; a tile cut out is plain
# rock, and a quarry with no stone left is worked out and lets its family go.
#
# The amount left is kept on the tile ("deposit_left"); town maps are saved whole, and a tile from
# an older save, with no amount recorded, is untouched. Grade is read from the map's shape, so it
# needs no randomness of its own. Without a town map nothing here applies.

const STONE: String = "stone"
const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

static func is_stone(tile: Dictionary) -> bool:
	return str(tile.get("resource", "none")) == STONE and get_left(tile) > 0

static func get_left(tile: Dictionary) -> int:
	if str(tile.get("resource", "none")) != STONE:
		return 0
	return int(tile.get("deposit_left", EconomyBalance.STONE_DEPOSIT_UNITS_PER_TILE))

# From DEPOSIT_GRADE_FLOOR for a lone tile to 1.0 with stone all round it.
static func get_grade(local_map: Array, pos: Vector2i) -> float:
	var around: int = 0
	for offset: Vector2i in NEIGHBOURS:
		var at: Vector2i = pos + offset
		if at.y >= 0 and at.y < local_map.size() and at.x >= 0 and at.x < (local_map[at.y] as Array).size():
			around += 1 if str((local_map[at.y][at.x] as Dictionary).get("resource", "none")) == STONE else 0
	return EconomyBalance.DEPOSIT_GRADE_FLOOR + (1.0 - EconomyBalance.DEPOSIT_GRADE_FLOOR) * float(around) / float(NEIGHBOURS.size())

# The share of a full quarry's cut a footprint gives: the grades of the stone under it, against
# QUARRY_FULL_DEPOSIT_TILES tiles of the best stone, at most 1.
static func get_footprint_factor(local_map: Array, origin: Vector2i, size: Vector2i) -> float:
	var total: float = 0.0
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			if y >= 0 and y < local_map.size() and x >= 0 and x < (local_map[y] as Array).size() and is_stone(local_map[y][x]):
				total += get_grade(local_map, Vector2i(x, y))
	return minf(1.0, total / float(EconomyBalance.QUARRY_FULL_DEPOSIT_TILES))

static func get_quarry_factor(city: City, building: Building) -> float:
	if city.local_map.is_empty():
		return 1.0
	return get_footprint_factor(city.local_map, building.tile, building.size)

static func is_quarry(building: Building) -> bool:
	return BuildingTiers.get_base_type(building.type) == Building.BUILDING_QUARRY

# Takes what a quarry cut out of the stone under it, from the fullest tile first, so the quarry
# works its deposit down evenly. A tile cut out becomes plain rock.
static func extract(city: City, building: Building, amount: int) -> void:
	if city.local_map.is_empty():
		return
	for _unit in range(amount):
		var fullest: Dictionary = {}
		for y in range(building.tile.y, building.tile.y + building.size.y):
			for x in range(building.tile.x, building.tile.x + building.size.x):
				var tile: Dictionary = city.local_map[y][x]
				if is_stone(tile) and (fullest.is_empty() or get_left(tile) > get_left(fullest)):
					fullest = tile
		if fullest.is_empty():
			return
		fullest["deposit_left"] = get_left(fullest) - 1
		if int(fullest["deposit_left"]) <= 0:
			fullest["resource"] = "none"
			city.logistics.mark_layout_changed()

static func get_stone_left(city: City, building: Building) -> int:
	var left: int = 0
	if city.local_map.is_empty():
		return left
	for y in range(building.tile.y, building.tile.y + building.size.y):
		for x in range(building.tile.x, building.tile.x + building.size.x):
			left += get_left(city.local_map[y][x])
	return left

static func is_worked_out(city: City, building: Building) -> bool:
	return is_quarry(building) and not city.local_map.is_empty() and get_quarry_factor(city, building) <= 0.0

# The best a quarry anywhere on the map could cut, as a share of a full quarry (the site survey).
static func get_best_quarry_factor(local_map: Array) -> float:
	var best: float = 0.0
	var size: Vector2i = Vector2i(3, 3)
	for y in range(local_map.size() - size.y + 1):
		for x in range((local_map[y] as Array).size() - size.x + 1):
			var has_stone: bool = false
			for dy in range(size.y):
				for dx in range(size.x):
					has_stone = has_stone or is_stone(local_map[y + dy][x + dx])
			if has_stone:
				best = maxf(best, get_footprint_factor(local_map, Vector2i(x, y), size))
	return best

static func describe_quality(factor: float) -> String:
	if factor <= 0.0:
		return "none"
	if factor >= 0.9:
		return "good"
	if factor >= 0.5:
		return "fair"
	return "poor"
