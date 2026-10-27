class_name RegionShowcase
extends RefCounted

# Fixed development examples of the regional map style: real world-atlas regions chosen for
# their character, shown on the continuous map around each region's main settlement.
# Optionally adds a grown player town to show developed settlements, fields, roads, and a
# quarry. Used by the demo scene and the screenshot capture.

const SHOWCASES: Array[Dictionary] = [
	{"label": "Fertile river valley", "region": "Meander Plains"},
	{"label": "Forested foothills", "region": "Thornspine North"},
	{"label": "Mountain mining country", "region": "Crownspine Heights"},
	{"label": "Coastal plain", "region": "Tessaly"},
	{"label": "Desert oasis", "region": "Siwan Oases"},
	{"label": "Northern taiga", "region": "Taigard"},
]

const MIN_CITY_DISTANCE: int = 24
const CITY_RESOURCE_RANGE: int = 7
const GROWN_TOWN_HOUSEHOLDS: int = 32
const GROWN_TOWN_BUILDINGS: Array[String] = [
	"house", "house", "house", "house", "house", "house", "house", "house", "house", "house",
	"house", "house", "house", "house", "house", "house", "farm", "farm", "farm", "farm",
	"farm", "farm", "woodcutter", "woodcutter", "quarry", "toolmaker"]

# Size of the gameplay neighbourhood on the continuous map (main.gd uses the same).
const NEIGHBOURHOOD_SIZE: Vector2i = Vector2i(160, 100)

# The showcase as a neighbourhood of the continuous map, centered on the region's main
# settlement. Returns {"origin", "tiles", "cities", "roads", "focus", "label"}; focus is the
# global tile to look at, and the rest is in the neighbourhood's tile coordinates.
static func build_continuous(world: WorldMapData, terrain: RegionalTerrain, region_name: String, with_grown_town: bool) -> Dictionary:
	var region: WorldMapData.Region = world.find_region_by_name(region_name)
	var settlements: Array[WorldMapData.Settlement] = world.get_settlements_in_region(region.id)
	var anchor: Vector2i = terrain.settlement_tile(settlements[0]) if not settlements.is_empty() else terrain.world_to_tile_index(region.centroid)
	var origin: Vector2i = anchor - NEIGHBOURHOOD_SIZE / 2
	var tiles: Array = terrain.extract_window(origin, NEIGHBOURHOOD_SIZE)
	var cities: Array[City] = []
	for pair: Array in terrain.settlements_in_window(origin, NEIGHBOURHOOD_SIZE):
		var settlement: WorldMapData.Settlement = pair[0]
		cities.append(City.new(settlement.name, Vector2((pair[1] as Vector2i) - origin), City.ROLE_NEUTRAL))
	var focus: Vector2 = Vector2(anchor) + Vector2(0.5, 0.5)
	if with_grown_town:
		var site: Vector2i = best_founding_site(tiles, cities, NEIGHBOURHOOD_SIZE / 2, 34)
		if site.x >= 0:
			cities.append(make_grown_town(site))
			focus = Vector2(origin + site) + Vector2(0.5, 0.5)
	var roads: Array[Array] = []
	return {"origin": origin, "tiles": tiles, "cities": cities, "roads": roads, "focus": focus, "label": region_name}

# The valid founding tile with the most fertile land around it, within reach of a tile
# (the whole bounded map when reach is 0).
static func best_founding_site(tiles: Array, cities: Array[City], around: Vector2i = Vector2i.ZERO, reach: int = 0) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1
	var size: Vector2i = Vector2i((tiles[0] as Array).size(), tiles.size())
	var low: Vector2i = Vector2i(2, 2)
	var high: Vector2i = size - Vector2i(2, 2)
	if reach > 0:
		low = Vector2i(maxi(2, around.x - reach), maxi(2, around.y - reach))
		high = Vector2i(mini(size.x - 2, around.x + reach), mini(size.y - 2, around.y + reach))
	for y in range(low.y, high.y):
		for x in range(low.x, high.x):
			if not FoundingSiteHelper.is_valid_founding_tile(tiles, cities, Vector2i(x, y), MIN_CITY_DISTANCE):
				continue
			var profile: SettlementSiteProfile = SettlementSiteProfile.analyze(Vector2(x, y), tiles, CITY_RESOURCE_RANGE)
			# Good farmland with woods and stone in reach, but not on top of the deposits,
			# since houses are never drawn on them.
			var score: int = int(profile.fertility * 100.0) + int(profile.forest_density * 30.0) + (15 if profile.nearest_resource_distance >= 3 else 0)
			if score > best_score:
				best_score = score
				best = Vector2i(x, y)
	return best

static func make_grown_town(site: Vector2i) -> City:
	var town: City = City.new("Player Town", Vector2(site), City.ROLE_PLAYER, GROWN_TOWN_HOUSEHOLDS)
	for i in range(GROWN_TOWN_BUILDINGS.size()):
		town.buildings.append(Building.new(i, GROWN_TOWN_BUILDINGS[i], Vector2i.ZERO))
	return town
