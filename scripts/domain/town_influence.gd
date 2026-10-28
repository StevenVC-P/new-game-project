class_name TownInfluence
extends RefCounted

# What the community asks of its families, and the rule for drawing on its common stores: the
# player's levers in the family influence prototype (docs/FAMILY_INFLUENCE_PROTOTYPE.md). Families
# decide their own work (FamilyInitiative); the player encourages activities, sets the stores rule,
# and may mark the ground where families may open workplaces. The player can still plan any
# building directly: influence is added beside the direct tools, not in place of them.
#
# Off by default (`enabled` false): the town then plays exactly as before, with the player planning
# every workplace. The prototype is a development configuration, not a game mode.

const ACTIVITY_FOOD: String = "food"
const ACTIVITY_WOOD: String = "wood"
const ACTIVITY_TOOLS: String = "tools"
# Improving hand work into a proper holding, whatever its trade.
const ACTIVITY_IMPROVE: String = "improve"
const ACTIVITIES: Array[String] = [ACTIVITY_FOOD, ACTIVITY_WOOD, ACTIVITY_TOOLS, ACTIVITY_IMPROVE]

# Families' own projects may draw on the stores above the protected reserves.
const RULE_OPEN: String = "open"
# Only projects for what the community encourages may draw on the stores; the rest wait.
const RULE_PRIORITIES: String = "priorities"

# Marked on a town map tile (`local_map`) where families may open workplaces. Kept on the map so
# saves carry it with the town. Also the name of the player's marking tool (K).
const WORK_GROUND_KEY: String = "work_ground"
const WORK_GROUND: String = WORK_GROUND_KEY

var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
# Families take up and improve their own work (FamilyInitiative).
var enabled: bool = false
var encouraged: Array[String] = []
var store_rule: String = RULE_OPEN
# Tiles marked as work ground; with none marked, families open workplaces anywhere the land allows.
var work_ground_tiles: int = 0
# For balance tools and the sidebar: what families did on their own.
var workplaces_opened: int = 0
var improvements_started: int = 0
# Weekly decisions where a family wanted an improvement but the stores rule or reserves held it back.
var held_back_by_stores: int = 0
# Experiment (influence check, growth bottleneck): this many families without a holding stay free
# to build while any site is planned, instead of taking up work. 0: families take up work at once.
var reserved_builders: int = 0

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func is_encouraged(activity: String) -> bool:
	return encouraged.has(activity)

func set_encouraged(activity: String, on: bool) -> void:
	if on and not encouraged.has(activity):
		encouraged.append(activity)
	elif not on:
		encouraged.erase(activity)

func toggle_encouraged(activity: String) -> void:
	set_encouraged(activity, not is_encouraged(activity))

# What the stores always keep back from families' own projects: wood for the town's homes and
# workshops, and tools for the upkeep of every proper workplace for a while, so families investing
# on their own never cause the tool cliff the town has fought.
func get_protected_reserve() -> Dictionary:
	var proper_workplaces: int = 0
	for building: Building in city.buildings:
		if building.needs_maintenance():
			proper_workplaces += 1
	return {
		"wood": EconomyBalance.INFLUENCE_WOOD_RESERVE,
		"tools": maxi(EconomyBalance.INFLUENCE_TOOL_RESERVE_MIN, proper_workplaces * EconomyBalance.INFLUENCE_TOOL_RESERVE_PER_WORKPLACE),
	}

# Why the stores will not fund a family's project, or "" when they will. Under the priorities rule
# a project is funded when any of the activities it serves is encouraged: an improvement serves
# better work and its own trade.
func get_funding_block(cost: Dictionary, activities: Array[String]) -> String:
	if cost.is_empty():
		return ""
	if store_rule == RULE_PRIORITIES and not activities.any(is_encouraged):
		return "the stores go to the community's priorities first"
	if not city.construction.can_supply(cost, get_protected_reserve()):
		return "the stores hold too little beyond what is kept back"
	return ""

# --- Work ground --------------------------------------------------------------------------------

# Marks (or, when every tile in the block is marked already, unmarks) open land in a block.
func mark_work_ground(from: Vector2i, to: Vector2i) -> int:
	var tiles: Array[Vector2i] = []
	var all_marked: bool = true
	for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			var tile: Vector2i = Vector2i(x, y)
			if not city.construction.is_inside(tile):
				continue
			tiles.append(tile)
			all_marked = all_marked and is_work_ground(tile)
	for tile: Vector2i in tiles:
		var data: Dictionary = city.local_map[tile.y][tile.x]
		if all_marked:
			data.erase(WORK_GROUND_KEY)
		else:
			data[WORK_GROUND_KEY] = true
	work_ground_tiles = count_work_ground()
	_work_ground_cache = []
	return tiles.size()

# Every marked tile, for the town view (cached; rebuilt after marking or loading).
var _work_ground_cache: Array = []
func get_work_ground() -> Array:
	if work_ground_tiles > 0 and _work_ground_cache.is_empty():
		for y in range(city.local_map.size()):
			for x in range((city.local_map[y] as Array).size()):
				if is_work_ground(Vector2i(x, y)):
					_work_ground_cache.append(Vector2i(x, y))
	return _work_ground_cache if work_ground_tiles > 0 else []

func is_work_ground(tile: Vector2i) -> bool:
	return (city.local_map[tile.y][tile.x] as Dictionary).get(WORK_GROUND_KEY, false) == true

func count_work_ground() -> int:
	var count: int = 0
	for row: Array in city.local_map:
		for data: Dictionary in row:
			count += 1 if data.get(WORK_GROUND_KEY, false) == true else 0
	return count

# Whether families may open a workplace with this footprint: anywhere while no ground is marked.
func allows_site(origin: Vector2i, size: Vector2i) -> bool:
	if work_ground_tiles <= 0:
		return true
	for tile: Vector2i in TownLogistics.footprint(origin, size):
		if not city.construction.is_inside(tile) or not is_work_ground(tile):
			return false
	return true

# --- What the player sees -----------------------------------------------------------------------

static func get_activity_name(activity: String) -> String:
	match activity:
		ACTIVITY_FOOD:
			return "food"
		ACTIVITY_WOOD:
			return "wood"
		ACTIVITY_TOOLS:
			return "tools"
		ACTIVITY_IMPROVE:
			return "better work"
	return activity

func get_sidebar_lines() -> Array[String]:
	var lines: Array[String] = []
	var asked: Array[String] = []
	for activity: String in ACTIVITIES:
		if is_encouraged(activity):
			asked.append(get_activity_name(activity))
	lines.append("Asking for: " + (", ".join(asked) if not asked.is_empty() else "nothing"))
	lines.append("Stores: " + ("priorities first" if store_rule == RULE_PRIORITIES else "open above the reserve"))
	lines.append("Families opened %d, improved %d" % [workplaces_opened, improvements_started])
	return lines
