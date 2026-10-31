extends RefCounted

# Residential land set aside in a few standard ways, for the balance checks (home_site_check,
# priority_check), so they compare the same layouts. Every layout but "starting" offers CAPACITY
# spots a home can stand on from the first day, so layouts differ in where homes can go, not in
# how many or when.
#
# - starting:      the modest land a passive player has (HomeSites.set_aside_starting_land);
# - compact:       around the stockpile;
# - dispersed:     four blocks DISPERSED_OFFSET tiles out on the diagonals;
# - poor:          in the map's corner farthest from the stockpile;
# - far_only:      one block DISTANT tiles from the stockpile, on its roomiest side;
# - preferred_far: compact land, and as much again in the far block, marked preferred.

const CAPACITY: int = 24
const DISPERSED_OFFSET: int = 12
const DISTANT: int = 12
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static func get_heart(city: City) -> Vector2i:
	return TownLogistics.center_tile(city.logistics.stockpile_tile, TownLogistics.STOCKPILE_SIZE)

static func set_aside(city: City, layout: String) -> void:
	city.logistics.ensure_ready()
	var heart: Vector2i = get_heart(city)
	var size: Vector2i = city.logistics.map_size()
	match layout:
		"starting":
			HomeSites.set_aside_starting_land(city)
		"compact":
			mark_block(city, heart, 6, HomeSites.LAND_PERMITTED)
			trim(city, HomeSites.LAND_PERMITTED, [heart], CAPACITY)
		"dispersed":
			var centres: Array[Vector2i] = []
			for offset: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				centres.append(heart + offset * DISPERSED_OFFSET)
				mark_block(city, centres.back(), 3, HomeSites.LAND_PERMITTED)
			trim(city, HomeSites.LAND_PERMITTED, centres, CAPACITY)
		"poor":
			var corner: Vector2i = Vector2i(5 if heart.x > size.x / 2 else size.x - 6, 5 if heart.y > size.y / 2 else size.y - 6)
			mark_block(city, corner, 6, HomeSites.LAND_PERMITTED)
			trim(city, HomeSites.LAND_PERMITTED, [corner], CAPACITY)
		"far_only":
			var far: Vector2i = get_far_centre(city, heart)
			mark_block(city, far, 6, HomeSites.LAND_PERMITTED)
			trim(city, HomeSites.LAND_PERMITTED, [far], CAPACITY)
		"preferred_far":
			mark_block(city, heart, 6, HomeSites.LAND_PERMITTED)
			trim(city, HomeSites.LAND_PERMITTED, [heart], CAPACITY)
			var far: Vector2i = get_far_centre(city, heart)
			mark_block(city, far, 6, HomeSites.LAND_PREFERRED)
			trim(city, HomeSites.LAND_PREFERRED, [far], CAPACITY)
		_:
			push_error("unknown residential layout: " + layout)

static func mark_block(city: City, centre: Vector2i, radius: int, level: int) -> void:
	for y in range(centre.y - radius, centre.y + radius + 1):
		for x in range(centre.x - radius, centre.x + radius + 1):
			var tile: Vector2i = Vector2i(x, y)
			if city.construction.is_inside(tile) and HomeSites.get_land(city, tile) == HomeSites.LAND_NONE:
				(city.local_map[y][x] as Dictionary)[HomeSites.RESIDENTIAL_KEY] = level

# Keeps the `count` spots of a level a home could stand on nearest any of the centres (ties in row
# order) and clears the rest of that level.
static func trim(city: City, level: int, centres: Array, count: int) -> void:
	var spots: Array[Dictionary] = []
	var size: Vector2i = city.logistics.map_size()
	for y in range(size.y):
		for x in range(size.x):
			var tile: Vector2i = Vector2i(x, y)
			if HomeSites.get_land(city, tile) != level:
				continue
			if city.construction.validate(Building.BUILDING_HOUSE, tile)["is_valid"] != true:
				(city.local_map[y][x] as Dictionary).erase(HomeSites.RESIDENTIAL_KEY)
				continue
			spots.append({"tile": tile, "distance": HomeSites.nearest(Vector2(tile), centres), "index": spots.size()})
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]) or (float(a["distance"]) == float(b["distance"]) and int(a["index"]) < int(b["index"])))
	for spot: Dictionary in spots.slice(count):
		var tile: Vector2i = spot["tile"]
		(city.local_map[tile.y][tile.x] as Dictionary).erase(HomeSites.RESIDENTIAL_KEY)

# DISTANT tiles from the stockpile on the side with most open ground for homes.
static func get_far_centre(city: City, heart: Vector2i) -> Vector2i:
	var best: Vector2i = heart + DIRECTIONS[0] * DISTANT
	var best_room: int = -1
	for direction: Vector2i in DIRECTIONS:
		var centre: Vector2i = heart + direction * DISTANT
		var room: int = 0
		for y in range(centre.y - 6, centre.y + 7):
			for x in range(centre.x - 6, centre.x + 7):
				if city.construction.is_inside(Vector2i(x, y)) and city.construction.validate(Building.BUILDING_HOUSE, Vector2i(x, y))["is_valid"] == true:
					room += 1
		if room > best_room:
			best_room = room
			best = centre
	return best
