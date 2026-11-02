extends RefCounted

# The economy's correctness invariants (docs/ECONOMIC_FOUNDATIONS_TEST_PLAN.md, section 4), checked
# on a town as it plays. A check calls watch() once before the first day, check_day() every day and
# check_month() once a month; violations collects what failed, with the day and the town's seed.
#
# I1  no good in the store, and nothing a household holds, is negative;
# I2  each good in the store changed by exactly what City._flows says moved it;
# I6  shared land (woods, water, pasture): the shares of the workplaces in use add up to the land in
#     their reach counted once (an idle or empty workplace taking a share, or a tile counted twice,
#     breaks it);
# I7  no construction site holds more of a material than it needs;
# I14 no family's members are negative, and its number is its members (sprint S3b).

const SHARED_KINDS: Array[String] = ["woods", "water", "pasture"]
# How many violations are kept word for word; the rest are only counted.
const KEEP: int = 20

var violations: Array[String] = []
var violation_count: int = 0
var town_seed: int = 0
var _stock_at_start: Dictionary = {}
var _flow_at_start: Dictionary = {}

static func get_goods() -> Array[String]:
	var goods: Array[String] = ["clothing"]
	for chain: Dictionary in EconomyBalance.PRODUCTION.values():
		for good: String in [str(chain["output"])] + (chain["inputs"] as Dictionary).keys():
			if not goods.has(good):
				goods.append(good)
	return goods

static func get_flow_total(city: City, good: String) -> int:
	var total: int = 0
	for amount in (city._flows.get(good, {}) as Dictionary).values():
		total += int(amount)
	return total

func watch(city: City) -> void:
	town_seed = city.founding_seed
	reset_conservation(city)

# Starts I2 afresh from the store as it stands, for a check that changes the store itself (a
# disruption): from then on the store is held to what moves it again.
func reset_conservation(city: City) -> void:
	for good: String in get_goods():
		_stock_at_start[good] = int(city.resources.get(good, 0))
		_flow_at_start[good] = get_flow_total(city, good)

func check_day(city: City, day: int) -> void:
	for good: String in get_goods():
		var stock: int = int(city.resources.get(good, 0))
		if stock < 0:
			fail(day, "I1 store %s is %d" % [good, stock])
		var moved: int = get_flow_total(city, good) - int(_flow_at_start[good])
		if stock - int(_stock_at_start[good]) != moved:
			fail(day, "I2 store %s changed by %d, flows say %d (%s)" % [good, stock - int(_stock_at_start[good]), moved, str(city._flows.get(good, {}))])
			# Re-anchor so one break is reported once, not every day after it.
			_stock_at_start[good] = stock
			_flow_at_start[good] = get_flow_total(city, good)
	for household: Household in city.households:
		if household.larder < -0.0001 or household.gathered_wood < -0.0001 or household.mending < -0.0001:
			fail(day, "I1 household %d holds larder %.3f, gathered wood %.3f, mending %.3f" % [household.id, household.larder, household.gathered_wood, household.mending])
		# I14: members never negative, and the family's number is its members.
		if mini(mini(household.working_adults, household.young_children), mini(household.older_children, household.adult_children)) < 0 or household.total_population != household.working_adults + household.get_total_child_count():
			fail(day, "I14 household %d: adults %d, children %d/%d/%d, population %d" % [household.id, household.working_adults, household.young_children, household.older_children, household.adult_children, household.total_population])
	for project: ConstructionProject in city.construction.projects:
		for material: String in project.materials_delivered.keys():
			if int(project.materials_delivered[material]) > int(project.materials_needed.get(material, 0)):
				fail(day, "I7 site %d holds %d %s, needs %d" % [project.id, int(project.materials_delivered[material]), material, int(project.materials_needed.get(material, 0))])

func check_month(city: City, day: int) -> void:
	if city.local_map.is_empty():
		return
	for kind: String in SHARED_KINDS:
		if not city.land.is_shared(kind):
			continue
		var working: Array[Building] = []
		for building: Building in city.buildings:
			if building.can_produce() and TownLand.get_reach_kind(building.type) == kind:
				working.append(building)
		if working.is_empty():
			continue
		var shares: float = 0.0
		var reaches: Array[Rect2i] = []
		for building: Building in working:
			shares += city.land.count_share(kind, building.tile, building.size, city.land.get_rival_reaches(building.type, building.tile, false))
			reaches.append(TownLand.get_reach_rect(building.type, building.tile, building.size))
		var once: float = float(count_union(city, kind, reaches))
		if absf(shares - once) > 0.001:
			fail(day, "I6 %s: shares of %d workplaces add to %.3f, the land in their reach is %.0f" % [kind, working.size(), shares, once])

# The land of a kind inside any of the reaches, each tile counted once.
static func count_union(city: City, kind: String, reaches: Array[Rect2i]) -> int:
	var map_size: Vector2i = city.logistics.map_size()
	var bounds: Rect2i = reaches[0]
	for reach: Rect2i in reaches:
		bounds = bounds.merge(reach)
	var total: int = 0
	for y in range(maxi(0, bounds.position.y), mini(map_size.y, bounds.end.y)):
		for x in range(maxi(0, bounds.position.x), mini(map_size.x, bounds.end.x)):
			if reaches.any(func(reach: Rect2i) -> bool: return reach.has_point(Vector2i(x, y))):
				total += TownLand.get_tile_worth(city.local_map[y][x], kind)
	return total

func fail(day: int, what: String) -> void:
	violation_count += 1
	if violations.size() < KEEP:
		violations.append("seed %d day %d: %s" % [town_seed, day, what])

func is_clean() -> bool:
	return violation_count == 0
