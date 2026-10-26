class_name RegionTileDisplayHelper
extends RefCounted

# Plain-language words for regional tiles and founding sites, for the region inspector.
# The words follow the game's resource rules: a quarry is built on a stone deposit, while
# woodcutters and farms work the land around them.

static func describe_terrain(tile: Dictionary) -> String:
	var tile_type: String = tile.get("type", "grass")
	match tile_type:
		"river":
			return "River"
		"lake":
			return "Lake"
		"sea":
			return "Sea"
		"mountain":
			return "Mountains (impassable)"
	var ground: String = "hills" if tile_type == "hill" else "meadow"
	if tile.get("is_fertile", false) == true:
		ground = "fertile " + ground
	if tile.get("has_forest", false) == true:
		ground = "woodland on " + ground
	return ground[0].to_upper() + ground.substr(1)

# What the land offers a town, or "" when it offers nothing in particular.
static func describe_offer(tile: Dictionary) -> String:
	var resource: String = tile.get("resource", "none")
	if resource == "stone":
		return "Quarry stone (a quarry sits on it)"
	if resource == "iron":
		return "Iron ore (mined on the deposit)"
	var offers: PackedStringArray = PackedStringArray()
	if tile.get("has_forest", false) == true:
		offers.append("timber, cut from nearby")
	if tile.get("is_fertile", false) == true and tile.get("type", "") != "mountain":
		offers.append("good farmland")
	if offers.is_empty():
		return ""
	var text: String = ", ".join(offers)
	return text[0].to_upper() + text.substr(1)

# A founding site's character from its profile tags, e.g. "Riverside, fertile, wooded".
static func describe_site_character(profile: SettlementSiteProfile) -> String:
	if profile == null:
		return ""
	var words: PackedStringArray = PackedStringArray()
	for tag: String in profile.tags:
		match tag:
			"river_settlement":
				match profile.nearest_water_kind:
					"sea":
						words.append("coastal")
					"lake":
						words.append("lakeside")
					_:
						words.append("riverside")
			"fertile_valley":
				words.append("fertile")
			"forest_settlement":
				words.append("wooded")
			"hill_settlement":
				words.append("hilly")
			"mountain_edge":
				words.append("under the mountains")
			"mining_region":
				words.append("stone nearby")
			"crossroads":
				words.append("on the road")
			"open_plains":
				words.append("open plains")
			"isolated":
				words.append("isolated")
	if words.is_empty():
		return "Ordinary land"
	var text: String = ", ".join(words)
	return text[0].to_upper() + text.substr(1)
