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
# Each workplace's share of a full catch or bag (building id -> factor), for the layout it was
# worked out at: water and woods change only with the layout (felling, spreading).
var _reach: Dictionary = {}
var _reach_version: int = -1
var _has_flowing_water: int = -1

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func has_map() -> bool:
	return not city.local_map.is_empty()

# On the first day of spring, the year's water is known: high some years where a river or lake
# runs through the town.
func advance_day() -> void:
	if not has_map() or city.get_day_of_year() != 1:
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

# The share of a full catch (fisher: water in reach) or bag (hunter: woods in reach) a workplace
# can make, from LAND_YIELD_FLOOR up to 1.
func get_reach_factor(building: Building) -> float:
	if not has_map():
		return 1.0
	if _reach_version != city.logistics.layout_version:
		_reach_version = city.logistics.layout_version
		_reach.clear()
	if not _reach.has(building.id):
		_reach[building.id] = get_reach_factor_at(building.type, building.tile, building.size)
	return float(_reach[building.id])

func get_reach_factor_at(building_type: String, origin: Vector2i, size: Vector2i) -> float:
	var base: String = BuildingTiers.get_base_type(building_type)
	var found: int = 0
	var full: int = 1
	if base == Building.BUILDING_FISHER:
		found = count_near(origin, size, EconomyBalance.FISHER_REACH, "water")
		full = EconomyBalance.FISHER_FULL_WATER_TILES
	elif base == Building.BUILDING_HUNTER:
		found = count_near(origin, size, EconomyBalance.HUNTER_REACH, "woods")
		full = EconomyBalance.HUNTER_FULL_WOODS_TILES
	elif base == Building.BUILDING_HERDER:
		found = count_near(origin, size, EconomyBalance.HERDER_REACH, "pasture")
		full = EconomyBalance.HERDER_FULL_PASTURE_TILES
	else:
		return 1.0
	return clampf(float(found) / float(full), EconomyBalance.LAND_YIELD_FLOOR, 1.0)

# Tiles of a kind ("water", "flowing_water", "woods", "pasture") within `reach` tiles of a
# footprint (pasture counts hill tiles double).
func count_near(origin: Vector2i, size: Vector2i, reach: int, kind: String) -> int:
	var map_size: Vector2i = city.logistics.map_size()
	var count: int = 0
	for y in range(maxi(0, origin.y - reach), mini(map_size.y, origin.y + size.y + reach)):
		for x in range(maxi(0, origin.x - reach), mini(map_size.x, origin.x + size.x + reach)):
			var tile: Dictionary = city.local_map[y][x]
			match kind:
				"water":
					count += 1 if tile["type"] == "water" else 0
				"flowing_water":
					count += 1 if tile["type"] == "water" and tile.get("water_kind", "") != "sea" else 0
				"woods":
					count += 1 if tile["has_trees"] == true else 0
				"pasture":
					# Open ground nothing stands on; hill pasture counts double.
					if tile["type"] == "ground" and not tile["has_trees"] and tile["occupied"] != true:
						count += 2 if tile.get("is_hill", false) == true else 1
	return count

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
