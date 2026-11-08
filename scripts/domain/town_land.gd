class_name TownLand
extends RefCounted

# What the land around a workplace gives it, season by season (docs/FIRST_STAGE_LOOP.md,
# Geography Shapes The Town). Opportunities come from what lies within a workplace's reach on the
# town map, not from the site's label: a fisher's hut catches as much as the water beside it
# allows, a hunter's lodge as much as the woods around it hold, and a town that has both can use
# both. Fields follow the farming year.
#
# Two seasonal hazards, each with a visible cause and a counter, neither able to end a town:
# - High water: some springs, fields beside a river or lake are waterlogged and yield little
#   that season. Counter: farm higher ground, or fish instead.
# - Wolves: in winter, an unfenced hunter's lodge or gatherer's camp at the woods' edge works
#   warily and brings in less. Counter: fence the yard, or clear a margin of woods.
# Numbers in EconomyBalance (Land). A town without a town map has neither land nor hazards.

const SEASON_SPRING: int = 0
const SEASON_WINTER: int = 3

# The town this belongs to, held weakly: City owns this object, and a strong reference back
# would keep both alive forever.
var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# This spring brings high water to fields beside a river or lake.
var high_water_this_year: bool = false
var high_water_springs: int = 0
var springs_seen: int = 0
# Each workplace's share of a full catch, bag or flock (building id -> factor), for the layout it was
# worked out at: water and woods change only with the layout (felling, spreading).
var _reach: Dictionary = {}
var _reach_version: int = -1
# The same for land that is shared, for the layout and the workplaces families work on it.
var _shared_reach: Dictionary = {}
var _shared_reach_key: int = 0
var _has_flowing_water: int = -1
# Fish and game (sprint S13): each the share of what the town's water and woods can hold, 0 to 1.
var fish_stock: float = 1.0
var game_stock: float = 1.0
# Capacity (in food) for the layout and woods it was counted at.
var _capacity: Dictionary = {}
var _capacity_key: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

# On the first day of spring, the year's water is known: high some years where a river or lake
# runs through the town.
func advance_day() -> void:
	if not has_map():
		return
	fish_stock = regrow(fish_stock, EconomyBalance.FISH_GROWTH_PER_YEAR)
	game_stock = regrow(game_stock, EconomyBalance.GAME_GROWTH_PER_YEAR)
	if city.get_day_of_year() != 1:
		return
	springs_seen += 1
	high_water_this_year = false
	if not has_flowing_water():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, int(city.tile.x), int(city.tile.y), springs_seen, "high water"])
	high_water_this_year = rng.randf() < EconomyBalance.HIGH_WATER_CHANCE
	if high_water_this_year:
		high_water_springs += 1

# --- Fish and game stocks (sprint S13) ----------------------------------------------------------

# A day's logistic regrowth, peaking at half stock, and the trickle from beyond the town's reach.
static func regrow(stock: float, growth_per_year: float) -> float:
	var grown: float = stock + growth_per_year / 360.0 * stock * (1.0 - stock)
	grown += EconomyBalance.STOCK_INFLOW_PER_YEAR / 360.0 * (1.0 - grown)
	return clampf(grown, 0.0, 1.0)

static func get_stock_kind(building_type: String) -> String:
	match BuildingTiers.get_base_type(building_type):
		Building.BUILDING_FISHER:
			return "fish"
		Building.BUILDING_HUNTER:
			return "game"
	return ""

func get_stock(kind: String) -> float:
	return fish_stock if kind == "fish" else (game_stock if kind == "game" else 1.0)

# The food the town's water (fish) or woods (game) can hold at full stock.
func get_capacity(kind: String) -> float:
	var key: int = hash([city.logistics.layout_version, city.woodland.land_version])
	if key != _capacity_key:
		_capacity_key = key
		_capacity.clear()
	if not _capacity.has(kind):
		var tiles: int = 0
		for row: Array in city.local_map:
			for tile: Dictionary in row:
				if kind == "fish" and tile["type"] == "water":
					tiles += 1
				elif kind == "game" and tile["has_trees"] == true:
					tiles += 1
		_capacity[kind] = tiles * (EconomyBalance.FISH_STOCK_PER_WATER_TILE if kind == "fish" else EconomyBalance.GAME_STOCK_PER_WOODS_TILE)
	return float(_capacity[kind])

# A catch comes out of the stock (City.apply_building_production).
func note_catch(building: Building, food: int) -> void:
	var kind: String = get_stock_kind(building.type)
	if kind == "" or not has_map() or food <= 0:
		return
	var capacity: float = get_capacity(kind)
	var taken: float = float(food) / capacity if capacity > 0.0 else 1.0
	if kind == "fish":
		fish_stock = maxf(0.0, fish_stock - taken)
	else:
		game_stock = maxf(0.0, game_stock - taken)

func has_flowing_water() -> bool:
	if _has_flowing_water < 0:
		_has_flowing_water = 0
		for row: Array in city.local_map:
			for tile: Dictionary in row:
				if tile["type"] == "water" and tile.get("water_kind", "") != "sea":
					_has_flowing_water = 1
					break
			if _has_flowing_water == 1:
				break
	return _has_flowing_water == 1

# Everything the land and season do to a workplace's output today, as a factor.
func get_output_factor(building: Building) -> float:
	var season: int = city.get_season_index()
	var base: String = BuildingTiers.get_base_type(building.type)
	var factor: float = 1.0
	if TownLogistics.is_field(building):
		factor *= EconomyBalance.FARM_SEASON_YIELD[season]
		if season == SEASON_SPRING and is_waterlogged(building):
			factor *= EconomyBalance.HIGH_WATER_FIELD_YIELD
	elif base == Building.BUILDING_FISHER:
		factor *= get_reach_factor(building)
	elif base == Building.BUILDING_HUNTER:
		factor *= get_reach_factor(building) * EconomyBalance.HUNT_SEASON_YIELD[season]
	elif base == Building.BUILDING_HERDER:
		factor *= get_reach_factor(building)
	elif base == Building.BUILDING_WOODCUTTER:
		# The trees it may still fell, and how far it must walk to them (TownWoodland); felling is
		# winter work.
		factor *= city.woodland.get_felling_factor(building)
		if has_map():
			factor *= EconomyBalance.WOOD_SEASON_YIELD[season]
	elif TownDeposits.draws_on_deposit(building):
		# The stone or clay underfoot (TownDeposits).
		factor *= TownDeposits.get_factor(city, building)
	if season == SEASON_WINTER and is_wolf_exposed(building):
		factor *= EconomyBalance.WOLF_WINTER_YIELD
	return factor

# A field beside a river or lake in a high-water spring.
func is_waterlogged(building: Building) -> bool:
	return high_water_this_year and has_map() and TownLogistics.is_field(building) and count_near(building.tile, building.size, 1, "flowing_water") > 0

# An unfenced hunter's lodge, herder's fold, or gatherer's camp with woods within a few tiles.
func is_wolf_exposed(building: Building) -> bool:
	if not has_map() or building.fenced:
		return false
	var base: String = BuildingTiers.get_base_type(building.type)
	var exposed: bool = base == Building.BUILDING_HUNTER or base == Building.BUILDING_HERDER or building.type == "gatherer_camp"
	return exposed and count_near(building.tile, building.size, EconomyBalance.WOLF_WOODS_DISTANCE, "woods") > 0

# The share of a full catch (fisher: water in reach), bag (hunter: woods in reach) or flock (herder:
# pasture in reach) a workplace can make, from nothing up to 1, and for a fisher or hunter the stock
# left in the water or woods (S13). This is what it really brings in (get_output_factor), and what its
# family judges it by: land it shares with other workplaces of its kind that families work is shared
# with them.
func get_reach_factor(building: Building) -> float:
	return get_land_factor(building) * get_stock(get_stock_kind(building.type))

func get_land_factor(building: Building) -> float:
	if not has_map():
		return 1.0
	# Wood work: the trees it may still fell, which change with every tile felled or kept, so never
	# cached here (TownWoodland caches its own search).
	if get_reach_kind(building.type) == TIMBER:
		return city.woodland.get_felling_factor(building)
	# Stone or clay work: the deposit left underfoot, which every unit taken changes (TownDeposits).
	if get_reach_kind(building.type) == STONE or get_reach_kind(building.type) == CLAY:
		return TownDeposits.get_factor(city, building)
	if is_shared(get_reach_kind(building.type)):
		var key: int = hash([city.logistics.layout_version, get_rivals_key(Building.BUILDING_FISHER), get_rivals_key(Building.BUILDING_HUNTER), get_rivals_key(Building.BUILDING_HERDER)])
		if _shared_reach_key != key:
			_shared_reach_key = key
			_shared_reach.clear()
		if not _shared_reach.has(building.id):
			_shared_reach[building.id] = get_land_factor_at(building.type, building.tile, building.size, false)
		return float(_shared_reach[building.id])
	if _reach_version != city.logistics.layout_version:
		_reach_version = city.logistics.layout_version
		_reach.clear()
	if not _reach.has(building.id):
		_reach[building.id] = get_land_factor_at(building.type, building.tile, building.size, false)
	return float(_reach[building.id])

# What a workplace's yield depends on in its reach ("water", "woods", "pasture", or "timber": the
# trees a woodcutter may still fell, sprint S2), or "" when the land around it does not matter.
# Timber is not shared reach: woodcutters compete by felling the same trees (TownWoodland).
const TIMBER: String = "timber"
# And "stone": the deposit under a quarry or stone pit (TownDeposits, sprint S4c), not shared either.
const STONE: String = "stone"
# And "clay": the clay under a brickworks or clay pit (sprint S5).
const CLAY: String = "clay"

static func get_reach_kind(building_type: String) -> String:
	match BuildingTiers.get_base_type(building_type):
		Building.BUILDING_FISHER:
			return "water"
		Building.BUILDING_HUNTER:
			return "woods"
		Building.BUILDING_HERDER:
			return "pasture"
		Building.BUILDING_WOODCUTTER:
			return TIMBER
		Building.BUILDING_QUARRY:
			return STONE
		Building.BUILDING_BRICKWORKS:
			return CLAY
	return ""

# What a workplace of this type would make at `origin`. Its land is shared: every tile also in reach
# of other workplaces of its kind counts only its share, so two lodges in the same woods take half the
# game each, two huts on the same water half the fish, two folds on the same pasture half the grazing
# (owner, 2026-11-02; until then each counted the whole, which the comparison can restore with metas
# "woods_not_shared", "water_not_shared", "pasture_not_shared"). A workplace already standing shares
# with those families work (that is what it brings in); a place still being judged or built shares
# also with those families are setting up, since those will work there too (`planned`).
func get_reach_factor_at(building_type: String, origin: Vector2i, size: Vector2i, planned: bool = true) -> float:
	return get_land_factor_at(building_type, origin, size, planned) * get_stock(get_stock_kind(building_type))

# The land alone, without the stock.
func get_land_factor_at(building_type: String, origin: Vector2i, size: Vector2i, planned: bool = true) -> float:
	var kind: String = get_reach_kind(building_type)
	if kind == "":
		return 1.0
	if kind == TIMBER:
		return city.woodland.estimate_felling_factor_at(origin, size)
	if kind == STONE or kind == CLAY:
		return TownDeposits.get_footprint_factor(city.local_map, origin, size, kind)
	var full: int = EconomyBalance.HUNTER_FULL_WOODS_TILES
	match kind:
		"water":
			full = EconomyBalance.FISHER_FULL_WATER_TILES
		"pasture":
			full = EconomyBalance.HERDER_FULL_PASTURE_TILES
	var found: float = count_share(kind, origin, size, get_rival_reaches(building_type, origin, planned))
	return clampf(found / float(full), 0.0, 1.0)

# --- Shared land (hunting grounds, fishing water, pasture) -----------------------------------------

# Land whose yield is divided among the workplaces that share it, unless a comparison meta restores
# the old double counting for that kind.
func is_shared(kind: String) -> bool:
	match kind:
		"woods":
			return not city.has_meta("woods_not_shared")
		"water":
			return not city.has_meta("water_not_shared")
		"pasture":
			return not city.has_meta("pasture_not_shared")
	return false

static func get_reach_distance(kind: String) -> int:
	match kind:
		"water":
			return EconomyBalance.FISHER_REACH
		"pasture":
			return EconomyBalance.HERDER_REACH
	return EconomyBalance.HUNTER_REACH

# The reach of a workplace on the town map: its footprint and the land around it it lives off.
static func get_reach_rect(building_type: String, origin: Vector2i, size: Vector2i) -> Rect2i:
	var reach: int = get_reach_distance(get_reach_kind(building_type))
	return Rect2i(origin - Vector2i(reach, reach), size + Vector2i(reach, reach) * 2)

# The reaches of the other workplaces sharing the same kind of land: the ones in use (worked, by a
# family or a neutral worker, and able to work: Building.can_produce), and with `planned`, those a
# family is setting up. An empty workplace, one its family left, or one held but idle takes no share
# (owner, 2026-11-02). A workplace at `origin` itself (an improvement of it) is not its own rival.
func get_rival_reaches(building_type: String, origin: Vector2i, planned: bool) -> Array[Rect2i]:
	var rivals: Array[Rect2i] = []
	var kind: String = get_reach_kind(building_type)
	if not is_shared(kind):
		return rivals
	for building: Building in city.buildings:
		if building.can_produce() and building.tile != origin and get_reach_kind(building.type) == kind:
			rivals.append(get_reach_rect(building.type, building.tile, building.size))
	if planned:
		for project: ConstructionProject in city.construction.projects:
			if project.kind == ConstructionProject.KIND_BUILDING and project.claimant_household_id >= 0 and project.tile != origin and get_reach_kind(project.building_type) == kind:
				rivals.append(get_reach_rect(project.building_type, project.tile, project.size))
	return rivals

# Which workplaces of a kind are in use, as one number: a standing one's share changes when it does.
func get_rivals_key(building_type: String) -> int:
	var worked: Array = []
	var kind: String = get_reach_kind(building_type)
	for building: Building in city.buildings:
		if building.can_produce() and get_reach_kind(building.type) == kind:
			worked.append(building.id)
	return hash(worked)

# Wooded tiles within a hunter's reach of a footprint, each divided among the lodges whose reach it
# lies in.
func count_woods_share(origin: Vector2i, size: Vector2i, rivals: Array[Rect2i]) -> float:
	return count_share("woods", origin, size, rivals)

# Land of a kind ("woods", "water", "pasture") within its workplaces' reach of a footprint, each tile
# counted as count_near would, divided among the rival reaches it also lies in. The shares of every
# workplace on a tile add up to what that tile is worth once.
func count_share(kind: String, origin: Vector2i, size: Vector2i, rivals: Array[Rect2i]) -> float:
	var map_size: Vector2i = city.logistics.map_size()
	var reach: int = get_reach_distance(kind)
	var found: float = 0.0
	for y in range(maxi(0, origin.y - reach), mini(map_size.y, origin.y + size.y + reach)):
		for x in range(maxi(0, origin.x - reach), mini(map_size.x, origin.x + size.x + reach)):
			var worth: int = get_tile_worth(city.local_map[y][x], kind)
			if worth == 0:
				continue
			var sharing: int = 1
			for rival: Rect2i in rivals:
				sharing += 1 if rival.has_point(Vector2i(x, y)) else 0
			found += float(worth) / float(sharing)
	return found

# Tiles of a kind ("water", "flowing_water", "woods", "pasture") within `reach` tiles of a
# footprint (pasture counts hill tiles double).
func count_near(origin: Vector2i, size: Vector2i, reach: int, kind: String) -> int:
	var map_size: Vector2i = city.logistics.map_size()
	var count: int = 0
	for y in range(maxi(0, origin.y - reach), mini(map_size.y, origin.y + size.y + reach)):
		for x in range(maxi(0, origin.x - reach), mini(map_size.x, origin.x + size.x + reach)):
			count += get_tile_worth(city.local_map[y][x], kind)
	return count

# What one tile counts for as land of a kind.
static func get_tile_worth(tile: Dictionary, kind: String) -> int:
	match kind:
		"water":
			return 1 if tile["type"] == "water" else 0
		"flowing_water":
			return 1 if tile["type"] == "water" and tile.get("water_kind", "") != "sea" else 0
		"woods":
			return 1 if tile["has_trees"] == true else 0
		"pasture":
			# Open ground nothing stands on; hill pasture counts double.
			if tile["type"] == "ground" and not tile["has_trees"] and tile["occupied"] != true:
				return 2 if tile.get("is_hill", false) == true else 1
	return 0

# What the town's people should know this season: a line or two for the sidebar.
func get_notices() -> Array[String]:
	var lines: Array[String] = []
	if not has_map():
		return lines
	var season: int = city.get_season_index()
	var waterlogged: int = 0
	var wary: int = 0
	for building: Building in city.buildings:
		if season == SEASON_SPRING and is_waterlogged(building):
			waterlogged += 1
		if season == SEASON_WINTER and is_wolf_exposed(building) and building.can_produce():
			wary += 1
	if waterlogged > 0:
		lines.append("High water: %d field%s by the water waterlogged this spring" % [waterlogged, "" if waterlogged == 1 else "s"])
	if wary > 0:
		lines.append("Wolves: %d workplace%s at the woods' edge working warily (fence the yard)" % [wary, "" if wary == 1 else "s"])
	return lines
