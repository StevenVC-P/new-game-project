extends SceneTree

# Town building check (docs/TOWN_BUILDING_MODEL.md): with construction taking time, labor, and
# carried materials, can towns on real town maps still get off the ground, and what is layout
# worth? Founds towns at valid sites across frontier regions of every climate on the continuous
# regional map and plays two years with the stand-in player under three policies:
#
# - instant (old): the rules before construction, as a control: finished buildings at once;
# - houses: the player places every house (as map_luck_check does);
# - homes on plots: the player only sets residential plots aside, and families build their own
#   homes on them (FamilyDevelopment);
# - scattered: houses placed by the player, but everything built far out from the stockpile.
#
# Reports towns off the ground, people, the share of the working day workplaces lose to travel,
# when the first home stood, how many site-days waited for a free builder, and homes families
# built themselves.
# Run: <godot> --headless --path . --script res://tests/sim/town_building_check.gd > log; then filter for [BUILD]
# (the household log is long: write it to a file rather than a pipe, which stalls Godot on Windows).

const MainScript = preload("res://scripts/main.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const REGIONS: int = 10
const SITES_PER_REGION: int = 2
const DAYS: int = 720
const POLICIES: Array = [
	{"name": "instant (old)", "instant": true},
	{"name": "houses"},
	{"name": "homes on plots", "homes_on_plots": true},
	{"name": "scattered", "scattered": true},
]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var sites: Array = collect_sites()
	_report("%d towns on real town maps, %d days, %d founding families" % [sites.size(), DAYS, EconomyBalance.FOUNDING_FAMILIES])
	for policy: Dictionary in POLICIES:
		var results: Array[Dictionary] = []
		for site: Dictionary in sites:
			results.append(play(site, policy))
		summarize(policy["name"], results)
	quit()

# [label, global site, town map, site profile] for valid sites across the frontier.
static func collect_sites() -> Array:
	var world: WorldMapData = FixedWorldDefinition.build()
	var terrain: RegionalTerrain = RegionalTerrain.new(world)
	var frontier: Array[WorldMapData.Region] = []
	for region: WorldMapData.Region in world.regions:
		if region.owner_kingdom_id == -1:
			frontier.append(region)
	frontier.sort_custom(func(a: WorldMapData.Region, b: WorldMapData.Region) -> bool: return a.climate + a.name < b.climate + b.name)
	var size: Vector2i = MainScript.NEIGHBOURHOOD_SIZE
	var generator: LocalCityMapGenerator = LocalCityMapGenerator.new(MainScript.CITY_MAP_WIDTH, MainScript.CITY_MAP_HEIGHT)
	var sites: Array = []
	for pick in range(REGIONS):
		var region: WorldMapData.Region = frontier[pick * frontier.size() / REGIONS]
		var focus: Vector2i = terrain.world_to_tile_index(terrain.region_focus(region))
		var origin: Vector2i = Vector2i(terrain.wrap_tile_x(focus.x - size.x / 2), clampi(focus.y - size.y / 2, 0, terrain.size_tiles.y - size.y))
		var tiles: Array = terrain.extract_window(origin, size)
		var no_cities: Array[City] = []
		var valid: Array[Vector2i] = []
		for y in range(size.y):
			for x in range(size.x):
				if FoundingSiteHelper.is_valid_founding_tile(tiles, no_cities, Vector2i(x, y), MainScript.MIN_CITY_DISTANCE):
					valid.append(Vector2i(x, y))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 9000 + region.id
		for _site in range(SITES_PER_REGION):
			if valid.is_empty():
				break
			var site: Vector2i = valid[rng.randi_range(0, valid.size() - 1)]
			var global_site: Vector2i = Vector2i(terrain.wrap_tile_x(origin.x + site.x), origin.y + site.y)
			var profile: SettlementSiteProfile = SettlementSiteProfile.analyze(Vector2(site), tiles, MainScript.CITY_RESOURCE_RANGE)
			profile.climate = terrain.climate_at(global_site)
			sites.append({"label": region.name, "site": site, "map": generator.generate_from_terrain(terrain, global_site, profile.climate), "profile": profile, "seed": rng.randi()})
	terrain.wait_for_tasks()
	return sites

func play(site: Dictionary, policy: Dictionary) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	var result: Dictionary = StandInPlayerScript.new().play(city, policy, DAYS)
	result["label"] = site["label"]
	return result

func summarize(policy_name: String, results: Array[Dictionary]) -> void:
	var made_it: int = 0
	var people: int = 0
	var travel: float = 0.0
	var stalled: int = 0
	var family_homes: int = 0
	var first_home_days: Array[int] = []
	var reasons: Dictionary = {}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		people += int(result["population"])
		travel += float(result["travel_share"])
		stalled += int(result["stalled_site_days"])
		family_homes += int(result["homes_by_families"])
		if int(result["first_home_day"]) >= 0:
			first_home_days.append(int(result["first_home_day"]))
		for reason: String in result["reasons"]:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
	first_home_days.sort()
	var n: float = maxf(1.0, results.size())
	_report("%-15s %2d/%d off the ground | avg people %.0f | travel %.0f%% of the working day | first home day %s | site-days waiting for builders %.0f | homes families built %.1f | problems: %s" % [
		policy_name, made_it, results.size(), people / n, travel / n * 100.0,
		str(first_home_days[first_home_days.size() / 2]) if not first_home_days.is_empty() else "-",
		stalled / n, family_homes / n, str(reasons) if not reasons.is_empty() else "none"])

func _report(line: String) -> void:
	print("[BUILD] " + line)
