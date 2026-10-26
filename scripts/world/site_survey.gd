class_name SiteSurvey
extends RefCounted

# Plain-language survey of a founding site, read from the town map the player will actually get
# (the map is generated when the site is picked and reused at founding). Regional measures alone
# misled: most sites read as poor farmland although every town map holds room for many farms.
#
# Thresholds come from the spread of real town maps on the continuous regional map
# (tests/sim/town_map_probe.gd, 80 sites in 20 frontier regions, 2026-10-26): fertile tiles
# 118-1196 (quartiles 182 / 364 / 619), tree tiles 90-2115 (quartiles 191 / 290 / 512). About a
# quarter of sites read as limited and a quarter as rich.

const FARMLAND_RICH_TILES: int = 600
const FARMLAND_FAIR_TILES: int = 200
const FOREST_DENSE_TILES: int = 500
const FOREST_SOME_TILES: int = 200

static func get_lines(local_map: Array, profile: SettlementSiteProfile) -> Array[String]:
	var fertile: int = 0
	var trees: int = 0
	var rough: int = 0
	var water_kinds: Dictionary = {}
	var deposits: Dictionary = {}
	for row in local_map:
		for tile in row:
			if tile["is_fertile"] == true:
				fertile += 1
			if tile["has_trees"] == true:
				trees += 1
			if tile["type"] == "water":
				var kind: String = tile.get("water_kind", "river")
				water_kinds[kind] = int(water_kinds.get(kind, 0)) + 1
			elif tile["type"] == "rough":
				rough += 1
			var resource: String = tile.get("resource", "none")
			if resource != "none":
				deposits[resource] = true

	var lines: Array[String] = []
	lines.append("Farmland: " + _level(fertile, FARMLAND_RICH_TILES, FARMLAND_FAIR_TILES, "rich", "fair", "limited"))
	lines.append("Forest: " + _level(trees, FOREST_DENSE_TILES, FOREST_SOME_TILES, "dense", "some", "light"))
	lines.append("Water: " + _water_text(water_kinds))
	lines.append("Rough ground: " + ("some" if rough > 0 else "none"))
	if not deposits.is_empty():
		lines.append("Stone/ore: " + _deposit_text(deposits) + " on the town map")
	elif profile != null and profile.nearest_resource_distance >= 0:
		lines.append("Stone/ore: in the region, " + str(profile.nearest_resource_distance) + " tiles away")
	else:
		lines.append("Stone/ore: none nearby")
	return lines

# The kind of water most of the town's water is.
static func _water_text(water_kinds: Dictionary) -> String:
	var kind: String = ""
	var most: int = 0
	for candidate: String in water_kinds.keys():
		if int(water_kinds[candidate]) > most:
			most = int(water_kinds[candidate])
			kind = candidate
	match kind:
		"":
			return "none"
		"sea":
			return "sea coast"
		"lake":
			return "lakeshore"
	return "river runs through"

static func _deposit_text(deposits: Dictionary) -> String:
	if deposits.has("stone") and deposits.has("iron"):
		return "stone and ore"
	if deposits.has("iron"):
		return "ore"
	return "stone"

static func _level(value: int, high: int, middle: int, high_word: String, middle_word: String, low_word: String) -> String:
	if value >= high:
		return high_word
	if value >= middle:
		return middle_word
	return low_word
