class_name SiteSurvey
extends RefCounted

# Plain-language survey of a founding site, read from the town map the player will actually get
# (the map is generated when the site is picked and reused at founding). Regional measures alone
# misled: most sites read as poor farmland although every town map holds room for many farms.
#
# Thresholds come from the spread of real town maps (2026-10-20 probe of 160 sites): fertile
# tiles 79-671 (median 160), tree tiles 93-569 (median 228).

const FARMLAND_RICH_TILES: int = 300
const FARMLAND_FAIR_TILES: int = 140
const FOREST_DENSE_TILES: int = 300
const FOREST_SOME_TILES: int = 170

static func get_lines(local_map: Array, profile: SettlementSiteProfile) -> Array[String]:
	var fertile: int = 0
	var trees: int = 0
	var water: int = 0
	var rough: int = 0
	for row in local_map:
		for tile in row:
			if tile["is_fertile"] == true:
				fertile += 1
			if tile["has_trees"] == true:
				trees += 1
			if tile["type"] == "water":
				water += 1
			elif tile["type"] == "rough":
				rough += 1

	var lines: Array[String] = []
	lines.append("Farmland: " + _level(fertile, FARMLAND_RICH_TILES, FARMLAND_FAIR_TILES, "rich", "fair", "limited"))
	lines.append("Forest: " + _level(trees, FOREST_DENSE_TILES, FOREST_SOME_TILES, "dense", "some", "light"))
	lines.append("Water: " + (_water_text(profile) if water > 0 else "none"))
	lines.append("Rough ground: " + ("some" if rough > 0 else "none"))
	# Stone and ore are not drawn on town maps yet, so this comes from the surrounding region.
	if profile != null and profile.nearest_resource_distance >= 0:
		lines.append("Stone/ore: in the region, " + str(profile.nearest_resource_distance) + " tiles away")
	else:
		lines.append("Stone/ore: none nearby")
	return lines

static func _water_text(profile: SettlementSiteProfile) -> String:
	if profile != null and profile.nearest_water_kind == "sea":
		return "sea coast"
	if profile != null and profile.nearest_water_kind == "lake":
		return "lakeshore"
	return "river runs through"

static func _level(value: int, high: int, middle: int, high_word: String, middle_word: String, low_word: String) -> String:
	if value >= high:
		return high_word
	if value >= middle:
		return middle_word
	return low_word
