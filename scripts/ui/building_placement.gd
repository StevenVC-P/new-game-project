class_name BuildingPlacement
extends RefCounted

const BUILDING_HOUSE: String = "house"
const BUILDING_FARM: String = "farm"
const BUILDING_WOODCUTTER: String = "woodcutter"
const BUILDING_TOOLMAKER: String = "toolmaker"
const RESOURCE_WOOD: String = "wood"
const RESOURCE_TOOLS: String = "tools"

var city_map_width: int = 64
var city_map_height: int = 44
var woodcutter_tree_radius: int = 5

func _init(local_width: int = 64, local_height: int = 44, tree_radius: int = 5):
	city_map_width = local_width
	city_map_height = local_height
	woodcutter_tree_radius = tree_radius

func validate(city: City, local_map: Array, building_type: String, origin: Vector2i) -> Dictionary:
	var size: Vector2i = get_building_size(building_type)
	var footprint: Array[Vector2i] = get_footprint_tiles(origin, size)
	var has_fertile_tile: bool = false
	var cost: Dictionary = get_building_cost(building_type)

	if not city.can_afford_cost(cost):
		return make_result(false, "Insufficient resources: " + get_cost_text(cost), footprint)

	for tile_pos: Vector2i in footprint:
		if not is_inside_city_map(tile_pos.x, tile_pos.y):
			return make_result(false, "Outside map", footprint)

		var tile: Dictionary = local_map[tile_pos.y][tile_pos.x] as Dictionary
		if tile["type"] == "water":
			return make_result(false, "Blocked terrain", footprint)
		if tile["type"] == "rough":
			return make_result(false, "Blocked terrain", footprint)
		if tile["has_trees"] == true:
			return make_result(false, "Blocked terrain", footprint)
		if tile["occupied"] == true:
			return make_result(false, "Occupied tiles", footprint)
		if tile["is_fertile"] == true:
			has_fertile_tile = true

	if building_type == BUILDING_FARM and not has_fertile_tile:
		return make_result(false, "Requires fertile land", footprint)
	if building_type == BUILDING_WOODCUTTER and not has_trees_near_building(local_map, origin, size, woodcutter_tree_radius):
		return make_result(false, "Requires nearby trees", footprint)

	return make_result(true, "Valid placement", footprint)

func make_result(is_valid: bool, message: String, footprint: Array[Vector2i]) -> Dictionary:
	return {
		"is_valid": is_valid,
		"message": message,
		"footprint": footprint
	}

func get_footprint_tiles(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var footprint: Array[Vector2i] = []

	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			footprint.append(Vector2i(x, y))

	return footprint

func has_trees_near_building(local_map: Array, origin: Vector2i, size: Vector2i, radius: int) -> bool:
	var start_x: int = max(0, origin.x - radius)
	var end_x: int = min(city_map_width, origin.x + size.x + radius)
	var start_y: int = max(0, origin.y - radius)
	var end_y: int = min(city_map_height, origin.y + size.y + radius)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var tile: Dictionary = local_map[y][x] as Dictionary
			if tile["has_trees"] == true:
				return true

	return false

func get_building_size(building_type: String) -> Vector2i:
	if building_type == BUILDING_FARM:
		return Vector2i(3, 3)
	if building_type == BUILDING_TOOLMAKER:
		return Vector2i(3, 3)

	return Vector2i(2, 2)

func get_building_cost(building_type: String) -> Dictionary:
	if building_type == BUILDING_HOUSE:
		return {RESOURCE_WOOD: 8, RESOURCE_TOOLS: 1}
	if building_type == BUILDING_FARM:
		return {RESOURCE_WOOD: 4, RESOURCE_TOOLS: 1}
	if building_type == BUILDING_WOODCUTTER:
		return {RESOURCE_WOOD: 6, RESOURCE_TOOLS: 1}
	if building_type == BUILDING_TOOLMAKER:
		return {RESOURCE_WOOD: 10, RESOURCE_TOOLS: 3}

	return {}

func get_cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []

	for resource_name: String in cost.keys():
		parts.append(str(cost[resource_name]) + " " + resource_name)

	if parts.is_empty():
		return "free"

	var text: String = parts[0]
	for part_index in range(1, parts.size()):
		text += ", " + parts[part_index]

	return text

func is_inside_city_map(x: int, y: int) -> bool:
	return x >= 0 and x < city_map_width and y >= 0 and y < city_map_height
