class_name RegionShowcase
extends RefCounted

# Fixed development examples of the regional map style: real world-atlas regions chosen for
# their character, generated exactly as the game generates them on entry (same seed, same
# world geography). Optionally adds a grown player town to show developed settlements,
# fields, roads, and a quarry. Used by the demo scene and the screenshot capture.

const SHOWCASES: Array[Dictionary] = [
	{"label": "Fertile river valley", "region": "Meander Plains"},
	{"label": "Forested foothills", "region": "Thornspine North"},
	{"label": "Mountain mining country", "region": "Crownspine Heights"},
	{"label": "Coastal plain", "region": "Tessaly"},
	{"label": "Desert oasis", "region": "Siwan Oases"},
	{"label": "Northern taiga", "region": "Taigard"},
]

const MAP_SIZE: Vector2i = Vector2i(80, 50)
const MIN_CITY_DISTANCE: int = 24
const RIVER_NEAR_RANGE: int = 5
const CITY_RESOURCE_RANGE: int = 7
const GROWN_TOWN_HOUSEHOLDS: int = 32
const GROWN_TOWN_BUILDINGS: Array[String] = [
	"house", "house", "house", "house", "house", "house", "house", "house", "house", "house",
	"house", "house", "house", "house", "house", "house", "farm", "farm", "farm", "farm",
	"farm", "farm", "woodcutter", "woodcutter", "quarry", "toolmaker"]

# Returns {"tiles", "cities", "roads", "geography", "label"}.
static func build(world: WorldMapData, region_name: String, with_grown_town: bool) -> Dictionary:
	var region: WorldMapData.Region = world.find_region_by_name(region_name)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = region.regional_map_seed
	var generator: RegionMapGenerator = RegionMapGenerator.new(rng, MAP_SIZE.x, MAP_SIZE.y, MIN_CITY_DISTANCE, RIVER_NEAR_RANGE, CITY_RESOURCE_RANGE)
	generator.geography = RegionGeography.from_world(world, region.id, MAP_SIZE)
	var result: Dictionary = generator.generate_region()
	var tiles: Array = result["tiles"]
	var cities: Array[City] = result["cities"] as Array[City]
	if with_grown_town:
		var site: Vector2i = best_founding_site(tiles, cities)
		if site.x >= 0:
			cities.append(make_grown_town(site))
	var roads: Array[Array] = generator.generate_roads_for_cities(cities)
	return {"tiles": tiles, "cities": cities, "roads": roads, "geography": generator.geography, "label": region_name}

# The valid founding tile with the most fertile land around it.
static func best_founding_site(tiles: Array, cities: Array[City]) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1
	for y in range(2, MAP_SIZE.y - 2):
		for x in range(2, MAP_SIZE.x - 2):
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
