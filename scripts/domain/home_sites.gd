class_name HomeSites
extends RefCounted

# Where families build their homes (FamilyDevelopment): each family chooses its own site, by what it
# values, on land the player has set aside. The player sets the conditions, not the choice.
#
# Feasibility (can it build here?): an open residential plot, or a tile of residential land the
# home can stand on (TownConstruction.validate: terrain, occupancy) with a route to the family's
# work. Land is set aside in two ways: plots, exact sites; and residential land, broad areas marked
# on the town map (`RESIDENTIAL_KEY`), plain or preferred. With neither, a family cannot build, and
# says so. Families are never given leave to build anywhere: land planning stays a choice.
#
# Preference (how much does this family want it?): a sum of terms, each a reason in the family's
# words and measured in tiles of walking, from what the simulation already holds:
#
# | Consideration | Weighed by |
# |---|---|
# | Walk to work (route effort) | everyone; to the stockpile, more lightly, for a family without work |
# | Kin nearby | close-knit, clannish, traditionalist, elder-revering families seek it; leave-the-nest families keep their distance |
# | Friends and rivals | its ties: good terms draw it, bad terms push it away |
# | Neighbours around | outgoing, communal families seek company; private, solitary, self-governing ones space |
# | The town's heart | town-loving families live closer, open-country ones farther (as before) |
# | Room around the home | families wanting a fenced yard, prizing their own holdings, or proud of their hearth |
# | The land for its calling | a farming family wants fertile land near, and not to build on it; woodcutters woods; fishers water |
# | Stores and roads | everyone a little: the walk for supplies, a road at the door |
# | Safety | ground beside a river or lake that floods, and woods' edge: cautious families avoid them, daring ones do not mind |
# | Preferred land | the gathering's hope, heeded by how receptive the family is (FamilyInitiative.get_receptiveness) |
#
# Only the most promising few sites (by straight-line measures) are walked by route, so the cost
# does not grow with the land set aside. Ties go to the earlier tile, row by row.

const RESIDENTIAL_KEY: String = "residential"
const LAND_NONE: int = 0
const LAND_PERMITTED: int = 1
const LAND_PREFERRED: int = 2
# The Planning tools that mark land (main.gd's block tools), and the level each marks.
const TOOL_LAND: String = "residential"
const TOOL_PREFERRED: String = "residential_preferred"
const TOOL_CLEAR: String = "clear_residential"
const TOOL_LEVELS: Dictionary = {TOOL_LAND: LAND_PERMITTED, TOOL_PREFERRED: LAND_PREFERRED, TOOL_CLEAR: LAND_NONE}
const TOOL_NAMES: Dictionary = {TOOL_LAND: "Residential land", TOOL_PREFERRED: "Preferred residential land", TOOL_CLEAR: "Clear residential land"}

# What may be planned on residential land (owner, 2026-10-31): homes and huts, plots, roads, and
# communal infrastructure (COMPATIBLE); never a private workplace. A shared work takes the room a
# home would have had, as it would anywhere: setting it among homes is a planning trade-off.
const COMPATIBLE: Array[String] = [Building.BUILDING_STOREHOUSE]

static func is_compatible(building_type: String) -> bool:
	if building_type == TownConstruction.PLOT or building_type == TownConstruction.ROAD:
		return true
	return BuildingTiers.get_base_type(building_type) == Building.BUILDING_HOUSE or COMPATIBLE.has(building_type)

# Sites weighed in full after the distance ranking, and walked by route after that.
const ROUGH_KEEP: int = 64
const SHORTLIST: int = 8
# The considerations that depend only on distances (get_rough_score ranks every site by them).
const DISTANCE_FACTORS: Array[String] = ["work", "kin", "friends", "rivals", "heart", "stores", "preferred"]
const NEIGHBOUR_RADIUS: int = 5
const MAX_NEIGHBOURS: int = 6
const RIVAL_RADIUS: float = 6.0
const NEAR_LAND: int = 3
const DOOR_ROAD: int = 1

# --- Residential land ----------------------------------------------------------------------------

# Marks a block of the town map as residential land at `level` (plain or preferred); when every tile
# in the block already has that level, clears it instead. Returns the tiles changed.
static func mark(city: City, from: Vector2i, to: Vector2i, level: int) -> int:
	var tiles: Array[Vector2i] = []
	var all_marked: bool = true
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			var tile: Vector2i = Vector2i(x, y)
			if not city.construction.is_inside(tile):
				continue
			tiles.append(tile)
			all_marked = all_marked and get_land(city, tile) == level
	for tile: Vector2i in tiles:
		var data: Dictionary = city.local_map[tile.y][tile.x]
		if all_marked or level == LAND_NONE:
			data.erase(RESIDENTIAL_KEY)
		else:
			data[RESIDENTIAL_KEY] = level
	return tiles.size()

static func get_land(city: City, tile: Vector2i) -> int:
	return int((city.local_map[tile.y][tile.x] as Dictionary).get(RESIDENTIAL_KEY, LAND_NONE))

# Tiles set aside for homes; with `level`, only those at that level.
static func count_land(city: City, level: int = -1) -> int:
	var count: int = 0
	for row: Array in city.local_map:
		for data: Dictionary in row:
			var land: int = int(data.get(RESIDENTIAL_KEY, LAND_NONE))
			count += 1 if land != LAND_NONE and (level < 0 or land == level) else 0
	return count

# Spots on residential land a home could stand on now.
static func count_room(city: City) -> int:
	var count: int = 0
	var map_size: Vector2i = city.logistics.map_size()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile: Vector2i = Vector2i(x, y)
			if get_land(city, tile) != LAND_NONE and city.construction.validate(Building.BUILDING_HOUSE, tile)["is_valid"] == true:
				count += 1
	return count

# A new town's modest starting residential land (owner, 2026-10-31: doing nothing must not be fatal
# for want of land, nor should it get an optimized layout): a square block a few tiles off the
# stockpile, on whichever side (north, east, south, west, in that order on ties) has most room,
# the smallest of STARTING_SIDES that holds a home for every founding family and STARTING_SPARE more.
const STARTING_SIDES: Array[int] = [5, 7, 9]
const STARTING_GAP: int = 2
const STARTING_SPARE: int = 2

static func set_aside_starting_land(city: City) -> int:
	city.logistics.ensure_ready()
	var heart: Vector2i = TownLogistics.center_tile(city.logistics.stockpile_tile, TownLogistics.STOCKPILE_SIZE)
	var wanted: int = EconomyBalance.FOUNDING_FAMILIES + STARTING_SPARE
	var best_corner: Vector2i = Vector2i(-1, -1)
	var best_side: int = 0
	for side: int in STARTING_SIDES:
		var best_room: int = -1
		for direction: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var middle: Vector2i = heart + direction * (STARTING_GAP + side / 2 + 2)
			var corner: Vector2i = middle - Vector2i(side / 2, side / 2)
			var room: int = 0
			for y in range(corner.y, corner.y + side):
				for x in range(corner.x, corner.x + side):
					if city.construction.is_inside(Vector2i(x, y)) and city.construction.validate(Building.BUILDING_HOUSE, Vector2i(x, y))["is_valid"] == true:
						room += 1
			if room > best_room:
				best_room = room
				best_corner = corner
				best_side = side
		if best_room >= wanted:
			break
	mark(city, best_corner, best_corner + Vector2i(best_side - 1, best_side - 1), LAND_PERMITTED)
	return count_room(city)

# Gives a town where families lead its starting land, once: when it is founded, when its families
# are first given the lead, or when a town saved before residential land existed is loaded. A town
# that already has land set aside keeps it as it is; nothing standing is moved or cleared. Returns
# whether land was set aside.
static func ensure_starting_land(city: City) -> bool:
	if not city.influence.enabled or city.construction.starting_land_given or not city.construction.has_map():
		return false
	city.construction.starting_land_given = true
	if count_land(city) > 0:
		return false
	set_aside_starting_land(city)
	return true

# --- Choosing a site -----------------------------------------------------------------------------

# A family's choice of site for a home of `home_type`: {"tile", "terms", "note", "obstacle"} with
# tile (-1, -1), and the obstacle in "obstacle" and "note", when it can build nowhere.
static func choose(city: City, household: Household, home_type: String) -> Dictionary:
	var logistics: TownLogistics = city.logistics
	logistics.ensure_ready()
	var label: String = city.get_household_label(household.id)
	var candidates: Array[Vector2i] = get_candidates(city, home_type)
	var context: Dictionary = get_context(city, household)
	var by_score: Callable = func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and int(a["index"]) < int(b["index"]))
	var rough: Array[Dictionary] = []
	for index in range(candidates.size()):
		rough.append({"tile": candidates[index], "score": get_rough_score(city, candidates[index], context), "index": index})
	rough.sort_custom(by_score)
	var ranked: Array[Dictionary] = []
	for entry: Dictionary in rough.slice(0, ROUGH_KEEP):
		ranked.append({"tile": entry["tile"], "score": FamilyInitiative.sum(get_terms(city, household, entry["tile"], context, false)), "index": entry["index"]})
	ranked.sort_custom(by_score)
	# Down the ranking, the first SHORTLIST sites the home can stand on and the family can walk to.
	var shortlist: Array[Dictionary] = []
	var buildable: int = 0
	for entry: Dictionary in ranked:
		if shortlist.size() >= SHORTLIST:
			break
		if city.construction.validate(home_type, entry["tile"])["is_valid"] != true:
			continue
		buildable += 1
		var terms: Array = get_terms(city, household, entry["tile"], context, true)
		if not terms.is_empty():
			shortlist.append({"tile": entry["tile"], "terms": terms})
	if shortlist.is_empty():
		var reason: String = "no spot set aside for homes can be reached from its work"
		if candidates.is_empty() and city.construction.get_open_plots().is_empty() and count_land(city) == 0:
			reason = "no land is set aside for homes"
		elif buildable == 0:
			reason = "every spot set aside for homes is taken or cannot hold one"
		return {"tile": Vector2i(-1, -1), "terms": [], "note": "%s cannot build a home: %s" % [label, reason], "obstacle": reason}
	var best: Dictionary = shortlist[0]
	for entry: Dictionary in shortlist:
		if FamilyInitiative.sum(entry["terms"]) > FamilyInitiative.sum(best["terms"]):
			best = entry
	return {"tile": best["tile"], "terms": best["terms"], "note": explain(label, best, shortlist), "obstacle": ""}

# The tiles a home might go on, in row order: open plots, and residential land not plainly taken
# (water, woods, or something standing there); the full placement check comes later, only for the
# sites a family ranks highest.
static func get_candidates(city: City, home_type: String) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var size: Vector2i = city.construction.get_size(home_type)
	var map_size: Vector2i = city.logistics.map_size()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile: Vector2i = Vector2i(x, y)
			var data: Dictionary = city.local_map[y][x]
			if city.construction.get_open_plot_at(tile) != null:
				tiles.append(tile)
			elif int(data.get(RESIDENTIAL_KEY, LAND_NONE)) != LAND_NONE and data["type"] != "water" and data.get("occupied", false) != true and is_land(city, tile, size):
				tiles.append(tile)
	return tiles

static func is_land(city: City, origin: Vector2i, size: Vector2i) -> bool:
	for tile: Vector2i in TownLogistics.footprint(origin, size):
		if not city.construction.is_inside(tile) or get_land(city, tile) == LAND_NONE:
			return false
	return true

# What a family brings to every site it weighs: where it works, where its kin, friends and rivals
# live, where other homes stand, and how much it cares about each.
static func get_context(city: City, household: Household) -> Dictionary:
	var logistics: TownLogistics = city.logistics
	var working: bool = not household.assigned_building_ids.is_empty()
	var work_tile: Vector2i = logistics.stockpile_tile
	if working:
		var workplace: Building = city.buildings[household.assigned_building_ids[0]]
		work_tile = TownLogistics.center_tile(workplace.tile, workplace.size)
	var kin: Array[Vector2i] = []
	var friends: Array[Vector2i] = []
	var rivals: Array[Vector2i] = []
	var homes: Array[Vector2i] = []
	for other: Household in city.households:
		if other == household or other.residence_building_id < 0:
			continue
		var home: Vector2i = logistics.get_home_tile(other)
		homes.append(home)
		if HouseholdMemory.is_kin(household, other):
			kin.append(home)
			continue
		var disposition: int = HouseholdMemory.get_disposition(household, other.id)
		if disposition >= 2:
			friends.append(home)
		elif disposition <= -2:
			rivals.append(home)
	var strength: Callable = func(value_id: String) -> int: return HouseholdCharacter.get_strength(household, value_id)
	var kin_weight: float = 0.25 + 0.25 * (strength.call("close_knit") + strength.call("clannish") + strength.call("traditionalist") + strength.call("elder_reverence")) - 0.5 * strength.call("leave_the_nest")
	var sociability: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.SOCIABILITY)
	var company: float = 0.25 * sociability + 0.25 * strength.call("communal_labor") - 0.35 * strength.call("solitary") - 0.25 * strength.call("self_governing")
	var room: float = 0.1
	if household.ambition == FamilyAmbitions.FENCE or strength.call("private_holdings") > 0 or strength.call("hearth_proud") > 0:
		room = 0.4
	var calling: String = ""
	for building_type: String in [Building.BUILDING_FARM, "woodcutter", Building.BUILDING_FISHER, "toolmaker"]:
		if household.get_match_quality(building_type) == CultureEffects.MATCH_GOOD:
			calling = building_type
			break
	return {
		"working": working,
		"work_tile": work_tile,
		"kin": kin,
		"friends": friends,
		"rivals": rivals,
		"homes": homes,
		"kin_weight": clampf(kin_weight, -0.5, 1.5),
		"company": company,
		"room": room,
		"calling": calling,
		"heart_pull": FamilyDevelopment.get_heart_pull(household),
		"caution": maxi(0, -HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)),
		"receptive": float(FamilyInitiative.get_receptiveness(household, city)["factor"]),
		"stores": logistics.get_store_tiles(),
	}

# The distance terms of get_terms (DISTANCE_FACTORS), straight-line, as one number: cheap enough to
# rank every site set aside. Kept equal to those terms (tests/home_site_validation.gd).
static func get_rough_score(city: City, tile: Vector2i, context: Dictionary) -> float:
	var here: Vector2 = Vector2(tile)
	var score: float = -(1.0 if context["working"] else 0.5) * here.distance_to(Vector2(context["work_tile"]))
	var kin_weight: float = context["kin_weight"]
	if not (context["kin"] as Array).is_empty() and absf(kin_weight) > 0.0:
		var to_kin: float = nearest(here, context["kin"])
		score += -kin_weight * (to_kin if kin_weight > 0.0 else minf(to_kin, 12.0))
	if not (context["friends"] as Array).is_empty():
		score += -0.3 * nearest(here, context["friends"])
	for rival: Vector2i in context["rivals"]:
		score += -0.5 * maxf(0.0, RIVAL_RADIUS - here.distance_to(Vector2(rival)))
	if float(context["heart_pull"]) != 0.0:
		score += -float(context["heart_pull"]) * here.distance_to(Vector2(city.logistics.map_size()) * 0.5)
	if not (context["stores"] as Array).is_empty():
		score += -0.2 * nearest(here, context["stores"])
	if get_land(city, tile) == LAND_PREFERRED:
		score += FamilyInitiative.ENCOURAGE_WEIGHT * float(context["receptive"])
	return score

# The terms for one site. With `walk`, the walk to work is the route's effort (empty terms when no
# route exists); without it, the straight line, for ranking.
static func get_terms(city: City, household: Household, tile: Vector2i, context: Dictionary, walk: bool) -> Array:
	var terms: Array = []
	var here: Vector2 = Vector2(tile)
	var work_tile: Vector2i = context["work_tile"]
	var to_work: float = here.distance_to(Vector2(work_tile))
	if walk:
		to_work = city.logistics.effort_between(tile, work_tile)
		if is_inf(to_work):
			return []
	var work_weight: float = 1.0 if context["working"] else 0.5
	add(terms, "work", -work_weight * to_work, "close to its work" if context["working"] else "close to the stockpile", "farther from its work" if context["working"] else "farther from the stockpile")
	var kin_weight: float = context["kin_weight"]
	if not (context["kin"] as Array).is_empty() and absf(kin_weight) > 0.0:
		var to_kin: float = nearest(here, context["kin"])
		if kin_weight > 0.0:
			add(terms, "kin", -kin_weight * to_kin, "near its kin", "farther from its kin")
		else:
			add(terms, "kin", -kin_weight * minf(to_kin, 12.0), "a way off from its kin, as it likes", "close to its kin")
	if not (context["friends"] as Array).is_empty():
		add(terms, "friends", -0.3 * nearest(here, context["friends"]), "near families it is friends with", "farther from its friends")
	var rival_weight: float = 0.0
	for rival: Vector2i in context["rivals"]:
		rival_weight += maxf(0.0, RIVAL_RADIUS - here.distance_to(Vector2(rival)))
	if not (context["rivals"] as Array).is_empty():
		add(terms, "rivals", -0.5 * rival_weight, "away from families it is at odds with", "close to families it is at odds with")
	var company: float = context["company"]
	if absf(company) > 0.0:
		var around: int = 0
		for home: Vector2i in context["homes"]:
			around += 1 if maxi(absi(home.x - tile.x), absi(home.y - tile.y)) <= NEIGHBOUR_RADIUS else 0
		around = mini(around, MAX_NEIGHBOURS)
		if company > 0.0:
			add(terms, "company", company * around, "among other homes", "among few neighbours")
		else:
			add(terms, "company", company * around, "with room between it and its neighbours", "crowded by neighbours")
	var heart_pull: float = context["heart_pull"]
	if heart_pull != 0.0:
		var heart: Vector2 = Vector2(city.logistics.map_size()) * 0.5
		add(terms, "heart", -heart_pull * here.distance_to(heart), "close to the town's heart" if heart_pull > 0.0 else "out in open country", "far from the town's heart" if heart_pull > 0.0 else "too close to the town's heart")
	add(terms, "room", float(context["room"]) * count_open_around(city, tile), "with room around it", "hemmed in")
	add_calling(city, tile, context, terms)
	var stores: Array = context["stores"]
	if not stores.is_empty():
		add(terms, "stores", -0.2 * nearest(here, stores), "near the stores", "farther from the stores")
	if near_kind(city, tile, DOOR_ROAD, "road"):
		add(terms, "road", 1.0, "on a road", "off the roads")
	var caution: int = context["caution"]
	if caution > 0:
		if near_kind(city, tile, 1, "flowing_water"):
			add(terms, "safety", -1.5 * caution, "on ground that does not flood", "on ground beside water that floods")
		if near_kind(city, tile, EconomyBalance.WOLF_WOODS_DISTANCE, "woods"):
			add(terms, "safety", -0.5 * caution, "away from the woods' edge", "at the woods' edge")
	if get_land(city, tile) == LAND_PREFERRED:
		add(terms, "preferred", FamilyInitiative.ENCOURAGE_WEIGHT * float(context["receptive"]), "where the gathering hopes homes will go", "not where the gathering hopes homes will go")
	return terms

static func add_calling(city: City, tile: Vector2i, context: Dictionary, terms: Array) -> void:
	match str(context["calling"]):
		Building.BUILDING_FARM:
			add(terms, "land", 0.5 * mini(count_near(city, tile, NEAR_LAND, "fertile"), 6), "near fertile land", "far from fertile land")
			if bool((city.local_map[tile.y][tile.x] as Dictionary).get("is_fertile", false)):
				add(terms, "land", -1.5, "without building on good farmland", "on good farmland it could farm")
		"woodcutter":
			add(terms, "land", 0.5 * mini(count_near(city, tile, NEAR_LAND, "woods"), 6), "near the woods it works", "far from the woods")
		Building.BUILDING_FISHER:
			add(terms, "land", 0.5 * mini(count_near(city, tile, NEAR_LAND, "water"), 6), "near the water", "far from the water")

# A term with what it means for the site when it is better (`for_it`) or worse (`against`) than the
# other sites the family weighed (explain).
static func add(terms: Array, factor: String, weight: float, for_it: String, against: String) -> void:
	terms.append({"factor": factor, "weight": weight, "reason": for_it, "against": against})

# Why the family chose its site, from the terms: what the site wins over the others it weighed,
# and what it gives up. "Household 3 chose a site close to its work and near its kin, despite being
# farther from the stores."
static func explain(label: String, chosen: Dictionary, weighed: Array[Dictionary]) -> String:
	var mean: Dictionary = {}
	for entry: Dictionary in weighed:
		for term: Dictionary in entry["terms"]:
			mean[term["factor"]] = float(mean.get(term["factor"], 0.0)) + float(term["weight"]) / weighed.size()
	var gains: Array[Dictionary] = []
	var costs: Array[Dictionary] = []
	var seen: Dictionary = {}
	for term: Dictionary in chosen["terms"]:
		var factor: String = term["factor"]
		var delta: float = float(get_factor(chosen["terms"], factor)) - float(mean.get(factor, 0.0))
		if seen.has(factor) or absf(delta) < 0.25:
			continue
		seen[factor] = true
		var strongest: Dictionary = term
		for other: Dictionary in chosen["terms"]:
			if other["factor"] == factor and absf(float(other["weight"])) > absf(float(strongest["weight"])):
				strongest = other
		(gains if delta > 0.0 else costs).append({"delta": delta, "text": strongest["reason"] if delta > 0.0 else strongest["against"]})
	gains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["delta"]) > float(b["delta"]))
	costs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["delta"]) < float(b["delta"]))
	if weighed.size() == 1 or gains.is_empty():
		return "%s chose the only fitting site set aside for homes%s" % [label, ", " + str(chosen["terms"][0]["reason"]) if not (chosen["terms"] as Array).is_empty() else ""]
	var reasons: PackedStringArray = PackedStringArray()
	for gain: Dictionary in gains.slice(0, 2):
		reasons.append(str(gain["text"]))
	var text: String = "%s chose a site %s" % [label, " and ".join(reasons)]
	if not costs.is_empty():
		text += ", despite being " + str(costs[0]["text"])
	return text

static func get_factor(terms: Array, factor: String) -> float:
	var total: float = 0.0
	for term: Dictionary in terms:
		if term["factor"] == factor:
			total += float(term["weight"])
	return total

# --- Land around a tile ---------------------------------------------------------------------------

static func nearest(from: Vector2, tiles: Array) -> float:
	var best: float = INF
	for tile: Vector2i in tiles:
		best = minf(best, from.distance_to(Vector2(tile)))
	return best

# Open ground beside a tile (its eight neighbours): room for a yard.
static func count_open_around(city: City, tile: Vector2i) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var at: Vector2i = tile + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or not city.construction.is_inside(at):
				continue
			var data: Dictionary = city.local_map[at.y][at.x]
			count += 1 if data["type"] != "water" and data.get("occupied", false) != true and not bool(data.get("has_trees", false)) else 0
	return count

static func count_near(city: City, tile: Vector2i, reach: int, kind: String) -> int:
	if kind == "fertile":
		var count: int = 0
		for y in range(tile.y - reach, tile.y + reach + 1):
			for x in range(tile.x - reach, tile.x + reach + 1):
				var at: Vector2i = Vector2i(x, y)
				if at != tile and city.construction.is_inside(at) and bool((city.local_map[y][x] as Dictionary).get("is_fertile", false)) and (city.local_map[y][x] as Dictionary).get("occupied", false) != true:
					count += 1
		return count
	return city.land.count_near(tile, Vector2i.ONE, reach, kind)

static func near_kind(city: City, tile: Vector2i, reach: int, kind: String) -> bool:
	if kind == "road":
		for y in range(tile.y - reach, tile.y + reach + 1):
			for x in range(tile.x - reach, tile.x + reach + 1):
				if city.construction.is_inside(Vector2i(x, y)) and bool((city.local_map[y][x] as Dictionary).get("has_road", false)):
					return true
		return false
	return city.land.count_near(tile, Vector2i.ONE, reach, kind) > 0
