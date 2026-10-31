class_name TownErrands
extends RefCounted

# A family's own trips from home, besides work (owner, 2026-10-27): fetching food and goods from
# the store, water from the nearest bank, firewood from the edge of the woods, and visits to its
# kin. They wear paths and trample fields like any walking (TownLogistics.add_traffic), but cost
# the family's workplace nothing: they are the household's own time.
#
# How often a family makes each errand is get_rates, the one place cultural values will shape it
# later (docs/CULTURE_AND_VALUES_MODEL.md): kin-minded families visiting more, town-loving ones
# going to the store more. Today every family keeps the same rates.
# Design: docs/TOWN_BUILDING_MODEL.md (Errands). A town without a town map runs no errands.

const STORE: String = "store"
const WATER: String = "water"
const FIREWOOD: String = "firewood"
const KIN: String = "kin"
const KINDS: Array[String] = [STORE, WATER, FIREWOOD, KIN]

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# [household id, kind] -> {"tile", "home", "route", "month"}. A family keeps an errand's route
# while its home and destination stay the same, found again at most once a month, so a town's
# many errands cost little (the routes still bend onto new paths, a month late at worst). The
# banks and wooded tiles errands go to are found again whenever the layout changes.
var _errands: Dictionary = {}
var _banks: Array[Vector2i] = []
var _woods: Array[Vector2i] = []
var _version: int = -1
const ROUTE_DAYS: int = 30

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

# The routes families keep, for saved games (GameState): a loaded town must walk the routes the
# original kept, not find fresh ones over today's paths, or the two wear different paths. The banks
# and woods are found again from the town map.
func get_saved() -> Dictionary:
	return _errands.duplicate(true)

func restore_saved(saved: Dictionary) -> void:
	_errands = saved.duplicate(true)

func has_map() -> bool:
	return not city.local_map.is_empty()

# Round trips a day a family makes on each errand.
func get_rates(_household: Household) -> Dictionary:
	return EconomyBalance.ERRAND_ROUND_TRIPS_PER_DAY.duplicate()

# Lays a day of every family's errands on the ground (called by TownLogistics.advance_day).
func add_daily_traffic() -> void:
	if not has_map():
		return
	for household: Household in city.households:
		var rates: Dictionary = get_rates(household)
		for kind: String in KINDS:
			var rate: float = float(rates.get(kind, 0.0))
			if rate <= 0.0:
				continue
			var route: Array = get_errand(household, kind)["route"]
			if not route.is_empty():
				city.logistics.add_traffic(route, rate * 2.0, household.id)

# Where a family goes on an errand and the way there from home: {"tile", "route"}; the route is
# empty when there is nowhere to go (no water, no woods, no kin) or no way there.
func get_errand(household: Household, kind: String) -> Dictionary:
	refresh()
	var key: Array = [household.id, kind]
	var home: Vector2i = city.logistics.get_home_tile(household)
	var month: int = city.construction.day / ROUTE_DAYS
	var kept: Dictionary = _errands.get(key, {})
	# Destinations only move when the layout does.
	if not kept.is_empty() and kept["home"] == home and int(kept["month"]) == month and int(kept["layout"]) == _version:
		return kept
	var target: Vector2i = find_destination(household, kind, home) if home.x >= 0 else Vector2i(-1, -1)
	if not kept.is_empty() and kept["tile"] == target and kept["home"] == home and int(kept["month"]) == month:
		kept["layout"] = _version
		return kept
	var errand: Dictionary = {"tile": target, "home": home, "route": [], "month": month, "layout": _version}
	if target.x >= 0 and target != home:
		errand["route"] = city.logistics.find_route(home, target)
	_errands[key] = errand
	return errand

func refresh() -> void:
	if _version == city.logistics.layout_version:
		return
	_version = city.logistics.layout_version
	_banks.clear()
	_woods.clear()
	var size: Vector2i = city.logistics.map_size()
	for y in range(size.y):
		for x in range(size.x):
			var tile: Dictionary = city.local_map[y][x]
			if tile["has_trees"] == true:
				_woods.append(Vector2i(x, y))
			elif tile["type"] == "ground" and tile["occupied"] != true and is_beside_water(Vector2i(x, y), size):
				_banks.append(Vector2i(x, y))

func is_beside_water(tile: Vector2i, size: Vector2i) -> bool:
	for side: Vector2i in TownWoodland.SIDES:
		var next: Vector2i = tile + side
		if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and (city.local_map[next.y][next.x] as Dictionary)["type"] == "water":
			return true
	return false

func find_destination(household: Household, kind: String, home: Vector2i) -> Vector2i:
	match kind:
		STORE:
			return nearest_of(city.logistics.get_store_tiles(), home)
		WATER:
			return nearest_of(_banks, home)
		FIREWOOD:
			return nearest_of(_woods, home)
		KIN:
			var homes: Array[Vector2i] = []
			for kin: Household in get_kin(household):
				var kin_home: Vector2i = city.logistics.get_home_tile(kin)
				if kin_home.x >= 0 and kin_home != home:
					homes.append(kin_home)
			return nearest_of(homes, home)
	return Vector2i(-1, -1)

# A family's kin in town: the households it came from and the ones its children founded.
func get_kin(household: Household) -> Array[Household]:
	var kin: Array[Household] = []
	for other: Household in city.households:
		if other.id == household.id:
			continue
		var parent: bool = other.id == household.parent_household_id or other.id == household.second_parent_household_id
		var child: bool = other.parent_household_id == household.id or other.second_parent_household_id == household.id
		if parent or child:
			kin.append(other)
	return kin

# Nearest by distance, ties broken by row then column; (-1, -1) for none.
static func nearest_of(tiles: Array, from: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1 << 30
	for tile: Vector2i in tiles:
		var distance: int = (tile - from).length_squared()
		if distance < best_distance or (distance == best_distance and TownWoodland.is_before(tile, best)):
			best = tile
			best_distance = distance
	return best
