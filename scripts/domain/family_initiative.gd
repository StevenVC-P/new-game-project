class_name FamilyInitiative
extends RefCounted

# Families taking up and improving their own work: the family influence prototype
# (docs/FAMILY_INFLUENCE_PROTOTYPE.md). It runs only where the town's influence is enabled
# (TownInfluence.enabled). Every week, through the same construction pipeline as the player:
#
# - a family with no holding chooses work to take up (food, wood, or tools) and opens it near its
#   home as hand work (tier 0), which needs no materials;
# - a family on hand work considers improving it into a proper holding.
#
# Desire and ability are kept apart. Desire is a sum of terms, each with the reason it gives: the
# family's calling, temperament and values, what the town needs, what its neighbours' improved
# work shows, and what the community encourages. Ability is the land, the family's own hands
# (hand work needs no materials), and the stores under the community's rule (TownInfluence), which
# always keeps protected reserves. A family can want something it cannot do, and says so.
#
# A small, bounded unknown (NOISE) is added to each decision: a family the player is told is on the
# fence may go either way, while one clearly for or against does what the player was told.

const INTERVAL_DAYS: int = 7
const MAX_PROJECTS_PER_PASS: int = 3
const ACTIVITIES: Array[String] = [TownInfluence.ACTIVITY_FOOD, TownInfluence.ACTIVITY_WOOD, TownInfluence.ACTIVITY_TOOLS]
const HAND_WORK: Dictionary = {"food": "forager_garden", "wood": "gatherer_camp", "tools": "tool_mender"}
const PROPER_WORK: Dictionary = {"food": "farm", "wood": "woodcutter", "tools": "toolmaker"}

# A family improves its work when its desire reaches this.
const IMPROVE_THRESHOLD: float = 2.0
# The most the unknown can move a decision. It stays below the width of the "uncertain" band in
# predict(), so a family predicted likely or opposed always does what was predicted.
const NOISE: float = 0.75
const ENCOURAGE_WEIGHT: float = 2.0
# Days of food in store below which a cautious family will not change its work.
const CAUTIOUS_SECURE_FOOD_DAYS: float = 60.0
# How far a family looks for workplace sites, and how many valid ones it compares.
const SITE_SEARCH_RADIUS: int = 30
const SITE_CANDIDATES: int = 8
# Families whose homes stand this close, and kin, are the neighbours whose work a family watches.
const NEIGHBOUR_RADIUS: float = 10.0
const HEART_PULL: float = FamilyDevelopment.HEART_PULL

const OUTLOOK_LIKELY: String = "likely"
const OUTLOOK_UNCERTAIN: String = "uncertain"
const OUTLOOK_RESIST: String = "likely to resist"
const OUTLOOK_OPPOSED: String = "strongly opposed"

static func advance(city: City) -> Array[ConstructionProject]:
	var started: Array[ConstructionProject] = []
	if not city.influence.enabled:
		return started
	for household: Household in city.households:
		if started.size() >= MAX_PROJECTS_PER_PASS:
			break
		if household.labor_capacity <= 0 or has_own_project(city, household):
			continue
		var project: ConstructionProject = null
		var holding: Building = get_holding(city, household)
		if holding == null:
			if household.assigned_workers <= 0 and not city.construction.is_promised_to_workplace(household.id):
				project = take_up_work(city, household)
		elif holding.is_tier0() and get_activity(holding.type) != "":
			project = consider_improving(city, household, holding)
		if project != null:
			started.append(project)
	return started

# --- Taking up work -----------------------------------------------------------------------------

static func take_up_work(city: City, household: Household) -> ConstructionProject:
	var choices: Array[Dictionary] = []
	for activity: String in ACTIVITIES:
		var desire: Dictionary = get_work_desire(city, household, activity)
		desire["activity"] = activity
		desire["score"] = float(desire["score"]) + get_noise(city, household, activity)
		choices.append(desire)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	# Every workplace starts as hand work; improving it is a decision of its own, later.
	for choice: Dictionary in choices:
		var building_type: String = HAND_WORK[choice["activity"]]
		var site: Vector2i = choose_site(city, household, building_type)
		if site.x < 0:
			continue
		var project: ConstructionProject = city.construction.request_building(building_type, site, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)
		if project == null:
			continue
		city.influence.workplaces_opened += 1
		note(city, household, "Took up %s (%s)" % [describe_type(building_type), "; ".join(get_reasons(choice["terms"], true))])
		return project
	note(city, household, "Found no work it could take up")
	return null

# How much a family wants to take up an activity: {"score", "terms"}.
static func get_work_desire(city: City, household: Household, activity: String) -> Dictionary:
	var terms: Array = []
	var match_quality: String = household.get_match_quality(PROPER_WORK[activity])
	if match_quality == CultureEffects.MATCH_GOOD:
		add(terms, 3.0, "it is the family's calling")
	elif match_quality == CultureEffects.MATCH_POOR:
		add(terms, -2.0, "it is not the family's calling")
	var cautious: bool = has(household, "cautious")
	match activity:
		TownInfluence.ACTIVITY_FOOD:
			var ratio: float = get_food_ratio(city)
			var weight: float = 1.5 if cautious else 1.0
			if ratio < 1.0:
				add(terms, 3.0 * weight, "the town grows less food than it eats" + (", and it puts food first" if cautious else ""))
			elif ratio < 1.25:
				add(terms, 1.5 * weight, "the town's food is only just enough")
			elif ratio > 1.6:
				add(terms, -1.5, "the town grows plenty of food")
		TownInfluence.ACTIVITY_WOOD:
			var producers: int = count_producers(city, activity)
			if producers == 0:
				add(terms, 2.5, "no one cuts wood")
			elif producers >= 2:
				add(terms, -1.5 * (producers - 1), "others already cut wood")
			if int(city.resources["wood"]) < 20:
				add(terms, 1.5, "wood is short")
		TownInfluence.ACTIVITY_TOOLS:
			var producers: int = count_producers(city, activity)
			if producers == 0 and int(city.resources["tools"]) < 10:
				add(terms, 2.5, "tools are running out")
			elif producers == 0:
				add(terms, 1.0, "no one makes tools")
			else:
				add(terms, -2.5 * producers, "others already make tools")
	add_encouragement(city, household, activity, terms, "the community asks for " + TownInfluence.get_activity_name(activity))
	return {"score": sum(terms), "terms": terms}

# --- Improving work -----------------------------------------------------------------------------

static func consider_improving(city: City, household: Household, holding: Building) -> ConstructionProject:
	if city.construction.get_upgrade_project(holding.id) != null:
		return null
	var proper: String = BuildingTiers.get_upgrade_type(holding.type)
	var desire: Dictionary = get_improve_desire(city, household, proper)
	var name: String = describe_type(holding.type, false)
	if float(desire["score"]) + get_noise(city, household, "improve") < IMPROVE_THRESHOLD:
		note(city, household, "Keeps to hand work at its %s (%s)" % [name, "; ".join(get_reasons(desire["terms"], false))])
		return null
	var block: String = city.influence.get_funding_block(EconomyBalance.get_build_cost(proper), [get_activity(proper), TownInfluence.ACTIVITY_IMPROVE] as Array[String])
	if block != "":
		city.influence.held_back_by_stores += 1
		note(city, household, "Wants to improve its %s, but %s" % [name, block])
		return null
	var project: ConstructionProject = city.construction.request_upgrade(holding.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id)
	if project == null:
		return null
	city.influence.improvements_started += 1
	if household.improve_decision_day < 0:
		household.improve_decision_day = city.construction.day
	note(city, household, "Improving its %s into %s (%s)" % [name, describe_type(proper), "; ".join(get_reasons(desire["terms"], true))])
	return project

# How much a family wants to improve work into a proper holding of this type: {"score", "terms"}.
static func get_improve_desire(city: City, household: Household, proper_type: String) -> Dictionary:
	var terms: Array = []
	var cautious: bool = has(household, "cautious")
	var daring: bool = has(household, "daring")
	add(terms, 1.0, "proper work yields three times as much")
	# What the improvement would give the town, and what it would spend of the stores.
	match get_activity(proper_type):
		TownInfluence.ACTIVITY_FOOD:
			if get_food_ratio(city) < 1.25 or get_food_days(city) < 90.0:
				add(terms, 1.5, "more food for the winter")
		TownInfluence.ACTIVITY_WOOD:
			if int(city.resources["wood"]) < 20:
				add(terms, 1.5, "the town needs wood")
		TownInfluence.ACTIVITY_TOOLS:
			if int(city.resources["tools"]) < 10:
				add(terms, 1.5, "the town needs tools")
	var risk: float = get_spending_risk(city, EconomyBalance.get_build_cost(proper_type))
	if risk > 0.2:
		add(terms, -2.0 * risk * (1.5 if cautious else 0.5 if daring else 1.0), "it would spend scarce wood and tools")
	# A cautious family changes nothing while the town's food or stores are precarious: it waits
	# until they are secure, then weighs the change like anyone, a little warily.
	if daring:
		add(terms, 2.0, "the family is daring")
	elif cautious:
		add(terms, -1.5, "the family is cautious")
		if get_food_days(city) < CAUTIOUS_SECURE_FOOD_DAYS or risk > 0.3:
			add(terms, -1.5, "it waits until the town's food and stores are secure")
	if has(household, "traditionalist"):
		add(terms, -2.0, "it keeps to the old ways")
	elif has(household, "reformist"):
		add(terms, 1.0, "it welcomes new ways")
	if has(household, "industrious"):
		add(terms, 1.0, "the family is industrious")
	elif has(household, "leisurely"):
		add(terms, -1.0, "the family is leisurely")
	if has(household, "acquisitive") or has(household, "private_holdings"):
		add(terms, 1.0, "it invests in what is its own")
	if has(household, "fatalistic"):
		add(terms, -1.0, "it expects little to change")
	elif has(household, "hopeful"):
		add(terms, 0.5, "the family is hopeful")
	# What its neighbours' improved work shows. Cautious and traditional families are moved more by
	# what they have seen than by what they are told.
	var seen: Dictionary = get_neighbours_example(city, household)
	var example_weight: float = 1.5 if cautious or has(household, "traditionalist") else 1.0
	if int(seen["paying"]) > 0:
		add(terms, minf(3.0, 0.75 * int(seen["paying"])) * example_weight, "its neighbours' improved work is paying")
	if int(seen["idle"]) > 0:
		add(terms, -minf(2.0, float(seen["idle"])) * example_weight, "its neighbours' improved work stands short of tools")
	if city.resources["food_shortage"] == true:
		add(terms, -2.0, "the town is hungry: survival first")
	add_encouragement(city, household, TownInfluence.ACTIVITY_IMPROVE, terms, "the community asks for better work")
	return {"score": sum(terms), "terms": terms}

# How a family is expected to answer a call to improve its work, before the player decides:
# {"outlook", "reasons"}. Grounded in the same terms as the decision, without the unknown.
static func predict_improvement(city: City, household: Household, encouraged: bool) -> Dictionary:
	var holding: Building = get_holding(city, household)
	if holding == null or not holding.is_tier0() or get_activity(holding.type) == "":
		return {"outlook": "", "reasons": []}
	var was: bool = city.influence.is_encouraged(TownInfluence.ACTIVITY_IMPROVE)
	city.influence.set_encouraged(TownInfluence.ACTIVITY_IMPROVE, encouraged)
	var desire: Dictionary = get_improve_desire(city, household, BuildingTiers.get_upgrade_type(holding.type))
	city.influence.set_encouraged(TownInfluence.ACTIVITY_IMPROVE, was)
	var margin: float = float(desire["score"]) - IMPROVE_THRESHOLD
	var outlook: String = OUTLOOK_UNCERTAIN
	if margin >= 1.0:
		outlook = OUTLOOK_LIKELY
	elif margin < -3.0:
		outlook = OUTLOOK_OPPOSED
	elif margin < -1.0:
		outlook = OUTLOOK_RESIST
	return {"outlook": outlook, "reasons": get_reasons(desire["terms"], margin >= 0.0)}

# --- What a family weighs ----------------------------------------------------------------------

# How receptive a family is to the community's appeals. This is persuasion, not obedience: a
# self-governing family weighs its own judgment more, and nothing here costs trust.
static func add_encouragement(city: City, household: Household, activity: String, terms: Array, reason: String) -> void:
	if not city.influence.is_encouraged(activity):
		return
	var receptive: float = 1.0
	if has(household, "deferential"):
		receptive = 1.5
		reason += ", and it heeds the community"
	elif has(household, "self_governing"):
		receptive = 0.6
		reason += ", though it judges for itself"
	if has(household, "communal_labor"):
		receptive += 0.25
	elif has(household, "solitary"):
		receptive -= 0.25
	add(terms, ENCOURAGE_WEIGHT * receptive, reason)

# Proper workplaces worked by kin and near neighbours: how many pay (well kept) and how many stand
# short of tools (working by hand or idle for want of upkeep).
static func get_neighbours_example(city: City, household: Household) -> Dictionary:
	var paying: int = 0
	var idle: int = 0
	var home: Vector2i = city.logistics.get_home_tile(household) if not city.local_map.is_empty() else Vector2i(-1, -1)
	for other: Household in city.households:
		if other == household:
			continue
		var kin: bool = household.is_child_of(other.id) or other.is_child_of(household.id)
		if not kin and home.x >= 0:
			var other_home: Vector2i = city.logistics.get_home_tile(other)
			if other_home.x < 0 or Vector2(home).distance_to(Vector2(other_home)) > NEIGHBOUR_RADIUS:
				continue
		var holding: Building = get_holding(city, other)
		if holding == null or not holding.needs_maintenance():
			continue
		if holding.maintenance_level >= 50:
			paying += 1
		else:
			idle += 1
	return {"paying": paying, "idle": idle}

# How much of the free stores (above the protected reserve) a cost would take, 0 to 1.5.
static func get_spending_risk(city: City, cost: Dictionary) -> float:
	var reserve: Dictionary = city.influence.get_protected_reserve()
	var committed: Dictionary = city.construction.get_committed_materials()
	var risk: float = 0.0
	for material: String in cost.keys():
		if int(cost[material]) <= 0:
			continue
		var free: int = int(city.resources.get(material, 0)) - int(committed.get(material, 0)) - int(reserve.get(material, 0))
		risk += float(cost[material]) / float(maxi(1, free))
	return minf(1.5, risk)

# The food the town's workplaces will grow (standing and planned, upgrades counted as done)
# against what it eats.
static func get_food_ratio(city: City) -> float:
	var eats: float = maxf(1.0, float(city.get_food_consumption_for_population(city.get_total_population())))
	return get_expected_output(city, TownInfluence.ACTIVITY_FOOD) / eats

static func get_food_days(city: City) -> float:
	return float(city.resources["food"]) / maxf(1.0, float(city.get_food_consumption_for_population(city.get_total_population())))

static func get_expected_output(city: City, activity: String) -> float:
	var total: float = 0.0
	for building: Building in city.buildings:
		if get_activity(building.type) == activity:
			total += city.get_base_building_output_amount(building.type)
	for project: ConstructionProject in city.construction.projects:
		if project.kind == ConstructionProject.KIND_BUILDING and get_activity(project.building_type) == activity:
			total += city.get_base_building_output_amount(project.building_type)
		elif project.kind == ConstructionProject.KIND_UPGRADE and get_activity(project.building_type) == activity:
			total += city.get_base_building_output_amount(project.building_type) * (1.0 - EconomyBalance.TIER0_OUTPUT_FRACTION)
	return total

static func count_producers(city: City, activity: String) -> int:
	var count: int = 0
	for building: Building in city.buildings:
		count += 1 if get_activity(building.type) == activity else 0
	for project: ConstructionProject in city.construction.projects:
		count += 1 if project.kind == ConstructionProject.KIND_BUILDING and get_activity(project.building_type) == activity else 0
	return count

# --- Where a family opens its work --------------------------------------------------------------

# The valid site a family likes best: near its home and a store, pulled toward or away from the
# town's heart by its Home and Place values, on the work ground when the player has marked any.
# Without a town map, the origin (buildings are placed without terrain).
static func choose_site(city: City, household: Household, building_type: String) -> Vector2i:
	if city.local_map.is_empty():
		return Vector2i.ZERO
	var logistics: TownLogistics = city.logistics
	logistics.ensure_ready()
	var size: Vector2i = city.construction.get_size(building_type)
	var anchor: Vector2i = get_anchor(city, household)
	var stores: Array[Vector2i] = logistics.get_store_tiles()
	var heart: Vector2 = Vector2(logistics.map_size()) * 0.5
	var pull: float = 0.0
	if has(household, "town_loving"):
		pull = HEART_PULL
	elif has(household, "open_country"):
		pull = -HEART_PULL
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	var found: int = 0
	for radius in range(0, SITE_SEARCH_RADIUS + 1):
		for y in range(anchor.y - radius, anchor.y + radius + 1):
			for x in range(anchor.x - radius, anchor.x + radius + 1):
				if maxi(absi(x - anchor.x), absi(y - anchor.y)) != radius:
					continue
				var origin: Vector2i = Vector2i(x, y)
				if not city.influence.allows_site(origin, size) or city.construction.validate(building_type, origin)["is_valid"] != true:
					continue
				var center: Vector2 = Vector2(TownLogistics.center_tile(origin, size))
				var to_store: float = INF
				for store: Vector2i in stores:
					to_store = minf(to_store, center.distance_to(Vector2(store)))
				var score: float = center.distance_to(Vector2(anchor)) + (to_store if not is_inf(to_store) else 0.0) + pull * center.distance_to(heart)
				if score < best_score:
					best = origin
					best_score = score
				found += 1
		if found >= SITE_CANDIDATES:
			break
	return best

# Where a family lives, or will live: its home, the home being built for it, else the stockpile.
static func get_anchor(city: City, household: Household) -> Vector2i:
	if household.residence_building_id >= 0:
		return city.logistics.get_home_tile(household)
	var home: ConstructionProject = city.construction.get_home_project_for(household.id)
	if home != null:
		return home.tile
	if city.logistics.stockpile_tile.x >= 0:
		return city.logistics.stockpile_tile
	return Vector2i(city.logistics.map_size() / 2)

# --- Helpers ------------------------------------------------------------------------------------

static func get_activity(building_type: String) -> String:
	var base: String = BuildingTiers.get_base_type(building_type)
	for activity: String in PROPER_WORK.keys():
		if PROPER_WORK[activity] == base:
			return activity
	return ""

static func get_holding(city: City, household: Household) -> Building:
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_household_id == household.id:
			return building
	return null

# A workplace or upgrade the family asked for itself and is still building.
static func has_own_project(city: City, household: Household) -> bool:
	for project: ConstructionProject in city.construction.projects:
		if project.requester_household_id == household.id and project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and not project.is_home() and project.kind != ConstructionProject.KIND_FENCE:
			return true
	return false

static func has(household: Household, value_id: String) -> bool:
	return CultureValues.has_value(household.values, value_id)

static func add(terms: Array, weight: float, reason: String) -> void:
	terms.append({"weight": weight, "reason": reason})

static func sum(terms: Array) -> float:
	var total: float = 0.0
	for term: Dictionary in terms:
		total += float(term["weight"])
	return total

# The strongest reasons for (positive) or against (negative) a decision, strongest first.
static func get_reasons(terms: Array, for_it: bool, count: int = 3) -> Array[String]:
	var chosen: Array = terms.filter(func(term: Dictionary) -> bool: return (float(term["weight"]) > 0.0) == for_it)
	chosen.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(float(a["weight"])) > absf(float(b["weight"])))
	var reasons: Array[String] = []
	for term: Dictionary in chosen.slice(0, count):
		reasons.append(str(term["reason"]))
	return reasons

# The bounded unknown in a decision: drawn from the town, the family, the week, and what is
# decided, so a loaded game decides as the original would have.
static func get_noise(city: City, household: Household, what: String) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([city.founding_seed, household.id, city.construction.day / INTERVAL_DAYS, what])
	return rng.randf_range(-NOISE, NOISE)

static func note(city: City, household: Household, text: String) -> void:
	household.initiative_note = text
	household.initiative_day = city.construction.day

static func describe_type(building_type: String, with_article: bool = true) -> String:
	var name: String = BuildingTiers.get_display_name(building_type).to_lower()
	if not with_article:
		return name
	return ("an " if "aeiou".contains(name.left(1)) else "a ") + name
