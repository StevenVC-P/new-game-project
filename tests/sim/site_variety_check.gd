extends SceneTree

# Site variety check (docs/FIRST_STAGE_LOOP.md, Geography Shapes The Town): does the best opening
# differ between kinds of land, and does more than one opening work on each? Plays the same four
# openings on real town sites across the frontier for two years and groups the results by what
# the land within the town map holds. A site can count under several kinds (a wooded riverside
# is both water and woods); "plain" is land with none of them.
#
# Run: <godot> --headless --path . --script res://tests/sim/site_variety_check.gd > log; then filter for [VARIETY]
# (the household log is long: write it to a file rather than a pipe, which stalls Godot on Windows).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const DAYS: int = 720
const REGIONS: int = 14
const SITES_PER_REGION: int = 3
const OPENINGS: Array = [
	{"name": "wood first"},
	{"name": "farms first", "prebuild": ["farm", "farm"]},
	{"name": "hand work first", "prebuild": ["forager_garden", "gatherer_camp", "forager_garden"]},
	{"name": "houses first", "prebuild": ["house", "house", "house", "farm", "woodcutter", "toolmaker"]},
]
# Shares of the town map that make a kind of land.
const WATER_SHARE: float = 0.02
const WOODS_SHARE: float = 0.15
const ROCK_SHARE: float = 0.05
const FARMLAND_SHARE: float = 0.2

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var sites: Array = TownBuildingCheck.collect_sites(REGIONS, SITES_PER_REGION)
	var kinds_by_site: Array = []
	for site: Dictionary in sites:
		kinds_by_site.append(land_kinds(site["map"]))
	# people[kind][opening] -> list of populations; made[kind][opening] -> towns off the ground
	var people: Dictionary = {}
	var made: Dictionary = {}
	for opening: Dictionary in OPENINGS:
		for i in range(sites.size()):
			var site: Dictionary = sites[i]
			var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
			city.site_profile = site["profile"]
			city.local_map = (site["map"] as Array).duplicate(true)
			var result: Dictionary = StandInPlayerScript.new().play(city, opening, DAYS)
			for kind: String in kinds_by_site[i]:
				if not people.has(kind):
					people[kind] = {}
					made[kind] = {}
				if not people[kind].has(opening["name"]):
					people[kind][opening["name"]] = []
					made[kind][opening["name"]] = 0
				(people[kind][opening["name"]] as Array).append(int(result["population"]))
				made[kind][opening["name"]] = int(made[kind][opening["name"]]) + (1 if result["off_the_ground"] else 0)
	_report("%d towns, %d days; openings: %s" % [sites.size(), DAYS, ", ".join(OPENINGS.map(func(o: Dictionary) -> String: return o["name"]))])
	var bests: Dictionary = {}
	for kind: String in people.keys():
		var parts: Array[String] = []
		var best: String = ""
		var best_people: float = -1.0
		var viable: int = 0
		var towns: int = 0
		for opening: Dictionary in OPENINGS:
			var list: Array = people[kind][opening["name"]]
			towns = list.size()
			var mean: float = 0.0
			for value: int in list:
				mean += value
			mean /= maxf(1.0, list.size())
			var share: float = float(made[kind][opening["name"]]) / maxf(1.0, list.size())
			viable += 1 if share >= 0.75 else 0
			parts.append("%s %.0f people (%d/%d)" % [opening["name"], mean, int(made[kind][opening["name"]]), list.size()])
			if mean > best_people:
				best_people = mean
				best = opening["name"]
		bests[best] = true
		_report("%-9s %2d towns | best: %-15s | openings that get 3 towns in 4 off the ground: %d | %s" % [kind, towns, best, viable, " | ".join(parts)])
	_report("different best openings across kinds of land: %d" % bests.size())
	quit()

# What the land within a town map holds: water, woods, rock, farmland, or none of them (plain).
static func land_kinds(map: Array) -> Array[String]:
	var counts: Dictionary = {"water": 0, "woods": 0, "rock": 0, "farmland": 0}
	var total: int = 0
	for row: Array in map:
		for tile: Dictionary in row:
			total += 1
			if tile["type"] == "water":
				counts["water"] += 1
			elif tile["type"] == "rough":
				counts["rock"] += 1
			elif tile["has_trees"] == true:
				counts["woods"] += 1
			elif tile["is_fertile"] == true:
				counts["farmland"] += 1
	var kinds: Array[String] = []
	var thresholds: Dictionary = {"water": WATER_SHARE, "woods": WOODS_SHARE, "rock": ROCK_SHARE, "farmland": FARMLAND_SHARE}
	for kind: String in thresholds.keys():
		if float(counts[kind]) / float(total) >= float(thresholds[kind]):
			kinds.append(kind)
	if kinds.is_empty():
		kinds.append("plain")
	return kinds

func _report(line: String) -> void:
	print("[VARIETY] " + line)
