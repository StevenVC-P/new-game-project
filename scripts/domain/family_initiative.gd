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
const SECURE_FOOD_DAYS: float = 180.0
# How far a family looks for workplace sites, and how many valid ones it compares.
const SITE_SEARCH_RADIUS: int = 30
const SITE_CANDIDATES: int = 8
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
				if stays_free_to_build(city):
					note(city, household, "Stays free to build while the town's sites wait")
					continue
				project = take_up_work(city, household)
		elif holding.is_tier0() and get_activity(holding.type) != "":
			project = consider_improving(city, household, holding)
		if project != null:
			started.append(project)
	return started

# --- Taking up work -----------------------------------------------------------------------------

# The growth-bottleneck experiment (TownInfluence.reserved_builders): while sites are planned, the
# last few families without work stay free to build.
static func stays_free_to_build(city: City) -> bool:
	if city.influence.reserved_builders <= 0 or city.construction.projects.is_empty():
		return false
	var free: int = 0
	for other: Household in city.households:
		if other.labor_capacity > 0 and other.assigned_workers <= 0 and not city.construction.is_promised_to_workplace(other.id):
			free += 1
	return free <= city.influence.reserved_builders

static func take_up_work(city: City, household: Household) -> ConstructionProject:
	var choices: Array[Dictionary] = []
	for activity: String in ACTIVITIES:
		var desire: Dictionary = get_work_desire(city, household, activity)
		desire["activity"] = activity
		desire["score"] = float(desire["score"]) + get_noise(city, household, activity)
		choices.append(desire)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	if city.social.enabled and contest_for_land(city, household, choices):
		return null
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
		use_first_claim(city, household, project)
		note(city, household, "Took up %s (%s)" % [describe_type(building_type), "; ".join(get_reasons(choice["terms"], true))])
		return project
	note(city, household, "Found no work it could take up")
	return null

# With the household social model on, land is contested where it is scarce (docs/HOUSEHOLD_SOCIAL_MODEL.md,
# Contested land): when a family can open work nowhere, it may ask a neighbour for land it already
# works by hand; and when land another family has only just claimed for the same work lies much
# nearer its home than any land still open, it may ask for that. TownSocial.contest_land decides;
# returns true when the land changed hands (it then works it, or builds on the claim, as its own).
static func contest_for_land(city: City, household: Household, choices: Array[Dictionary]) -> bool:
	var activity: String = choices[0]["activity"]
	var building_type: String = HAND_WORK[activity]
	var free: Vector2i = choose_site(city, household, building_type)
	var nowhere_else: bool = free.x < 0 and choices.all(func(c: Dictionary) -> bool: return choose_site(city, household, HAND_WORK[c["activity"]]).x < 0)
	var anchor: Vector2 = Vector2(get_anchor(city, household))
	var size: Vector2i = city.construction.get_size(building_type)
	var free_distance: float = INF if free.x < 0 else Vector2(TownLogistics.center_tile(free, size)).distance_to(anchor)
	var holder: Household = null
	var claim: ConstructionProject = null
	var holding: Building = null
	var nearest: float = INF
	for other: Household in city.social.get_known_households(household):
		for project: ConstructionProject in city.social.get_projects_of(other):
			if project.kind == ConstructionProject.KIND_BUILDING and project.building_type == building_type and project.requested_by == ConstructionProject.REQUESTED_BY_HOUSEHOLD and project.get_progress() <= 0.0:
				var distance: float = Vector2(TownLogistics.center_tile(project.tile, project.size)).distance_to(anchor)
				if distance < nearest:
					nearest = distance
					holder = other
					claim = project
					holding = null
		var worked: Building = get_holding(city, other) if nowhere_else else null
		if worked != null and worked.is_tier0() and get_activity(worked.type) == activity:
			var distance: float = Vector2(TownLogistics.center_tile(worked.tile, worked.size)).distance_to(anchor)
			if distance < nearest:
				nearest = distance
				holder = other
				claim = null
				holding = worked
	if holder == null:
		return false
	var nearer: float = free_distance - nearest if not is_inf(free_distance) else 8.0
	if not nowhere_else and nearer < TownSocial.CONTEST_NEARER_TILES:
		return false
	var stake: Dictionary = {
		"kind": TownSocial.CONTEST_NEWCOMER if holding != null else TownSocial.CONTEST_SAME_FIELD,
		"nowhere_else": nowhere_else,
		"nearer": nearer,
		"built": holding != null,
		"holder_has_alternative": choose_site(city, holder, building_type).x >= 0,
		"what": describe_type(building_type, false),
	}
	if city.social.contest_land(household, holder, stake) != "yielded":
		return false
	if holding != null:
		var index: int = city.buildings.find(holding)
		city.unassign_building_worker(index)
		city.assign_household_by_id_to_building(index, household.id)
		note(city, household, "Took over %s's %s, which it made room for" % [city.get_household_label(holder.id), describe_type(holding.type, false)])
		note(city, holder, "Gave up its %s to %s" % [describe_type(holding.type, false), city.get_household_label(household.id)])
	else:
		claim.claimant_household_id = household.id
		claim.requester_household_id = household.id
		note(city, household, "Took up %s on land %s made room for" % [describe_type(building_type), city.get_household_label(holder.id)])
		note(city, holder, "Gave up the land it chose to %s" % city.get_household_label(household.id))
	return true

# How much a family wants to take up an activity: {"score", "terms"}.
static func get_work_desire(city: City, household: Household, activity: String) -> Dictionary:
	var terms: Array = []
	var match_quality: String = household.get_match_quality(PROPER_WORK[activity])
	if match_quality == CultureEffects.MATCH_GOOD:
		add(terms, 3.0, "it is the family's calling")
	elif match_quality == CultureEffects.MATCH_POOR:
		add(terms, -2.0, "it is not the family's calling")
	var cautious: bool = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK) < 0
	match activity:
		TownInfluence.ACTIVITY_FOOD:
			var ratio: float = get_food_ratio(city)
			var weight: float = 1.0 + 0.25 * maxi(0, -HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK))
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
	add_encouragement(city, household, activity, terms, "the gathering asks for " + TownInfluence.get_activity_name(activity))
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
	var block: String = city.influence.get_funding_block(EconomyBalance.get_build_cost(proper), [get_activity(proper), TownInfluence.ACTIVITY_IMPROVE] as Array[String], household)
	if block != "":
		city.influence.held_back_by_stores += 1
		city.social.on_held_back(household)
		note(city, household, "Wants to improve its %s, but %s" % [name, block])
		return null
	var project: ConstructionProject = city.construction.request_upgrade(holding.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id)
	if project == null:
		return null
	use_first_claim(city, household, project)
	city.influence.improvements_started += 1
	if household.improve_decision_day < 0:
		household.improve_decision_day = city.construction.day
	note(city, household, "Improving its %s into %s (%s)" % [name, describe_type(proper), "; ".join(get_reasons(desire["terms"], true))])
	return project

# How much a family wants to improve work into a proper holding of this type: {"score", "terms"}.
#
# Temperament never fixes an order (docs/HOUSEHOLD_SOCIAL_MODEL.md, Section 6). Risk tolerance sets
# how heavily a family weighs risk at all, and the risk of acting (spending scarce stores, a method
# untried here) is weighed against the risk of waiting (the work the town is short of): a cautious
# family improves first when waiting is the greater danger. Tradition resists what is new but
# backs what is already the established way; an aspiring family may hold off for work of its
# calling.
static func get_improve_desire(city: City, household: Household, proper_type: String) -> Dictionary:
	var terms: Array = []
	var risk_tolerance: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	add(terms, 1.0, "proper work yields three times as much")
	var waiting: float = get_waiting_risk(city, get_activity(proper_type))
	if waiting > 0.0:
		add(terms, 1.5 * waiting, {TownInfluence.ACTIVITY_FOOD: "more food for the winter", TownInfluence.ACTIVITY_WOOD: "the town needs wood", TownInfluence.ACTIVITY_TOOLS: "the town needs tools"}[get_activity(proper_type)])
	var spending: float = get_spending_risk(city, EconomyBalance.get_build_cost(proper_type))
	var established: int = count_proper(city, proper_type)
	var untried: float = 0.5 if established == 0 else 0.0
	var acting: float = spending + untried
	var weight: float = 1.0 - 0.4 * risk_tolerance
	var balance: float = weight * (waiting - acting)
	if absf(balance) >= 0.2:
		if balance > 0.0:
			add(terms, balance, "waiting is the greater risk")
		else:
			add(terms, balance, "it would spend scarce wood and tools" if spending >= untried else "the method is untried here")
	if risk_tolerance != 0:
		add(terms, 0.75 * risk_tolerance, "the family is " + HouseholdCharacter.describe_axis(HouseholdCharacter.RISK, risk_tolerance))
	var ambition: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.AMBITION)
	if ambition > 0 and household.ambition == FamilyAmbitions.CALLING and household.get_match_quality(proper_type) != CultureEffects.MATCH_GOOD:
		add(terms, -1.5, "it is holding out for work of its calling")
	elif ambition != 0:
		add(terms, 0.75 * ambition, "the family is " + HouseholdCharacter.describe_axis(HouseholdCharacter.AMBITION, ambition))
	var diligence: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.DILIGENCE)
	if diligence != 0:
		add(terms, 0.5 * diligence, "the family is " + HouseholdCharacter.describe_axis(HouseholdCharacter.DILIGENCE, diligence))
	var openness: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.OPENNESS)
	if openness != 0 and untried > 0.0:
		add(terms, 0.75 * openness, "the family is " + HouseholdCharacter.describe_axis(HouseholdCharacter.OPENNESS, openness))
	var tradition: int = HouseholdCharacter.get_strength(household, "traditionalist")
	if tradition > 0:
		if established >= 2:
			add(terms, 0.75 * tradition, "it is the established way here")
		else:
			add(terms, -1.0 * tradition, "it keeps to the old ways")
	var reform: int = HouseholdCharacter.get_strength(household, "reformist")
	if reform > 0:
		add(terms, 0.5 * reform, "it welcomes new ways")
	var owning: int = maxi(HouseholdCharacter.get_strength(household, "acquisitive"), HouseholdCharacter.get_strength(household, "private_holdings"))
	if owning > 0:
		add(terms, 0.5 * owning, "it invests in what is its own")
	var fatalism: int = HouseholdCharacter.get_strength(household, "fatalistic")
	if fatalism > 0:
		add(terms, -0.5 * fatalism, "it expects little to change")
	var hope: int = HouseholdCharacter.get_strength(household, "hopeful")
	if hope > 0:
		add(terms, 0.25 * hope, "the family is hopeful")
	# What its neighbours' improved work shows. Wary and traditional families are moved more by what
	# they have seen than by what they are told.
	var seen: Dictionary = get_neighbours_example(city, household)
	var example_weight: float = 1.0 + 0.25 * maxi(0, -risk_tolerance) + 0.25 * tradition
	if int(seen["paying"]) > 0:
		add(terms, minf(3.0, 0.75 * int(seen["paying"])) * example_weight, "its neighbours' improved work is paying")
	if int(seen["idle"]) > 0:
		add(terms, -minf(2.0, float(seen["idle"])) * example_weight, "its neighbours' improved work stands short of tools")
	add_encouragement(city, household, TownInfluence.ACTIVITY_IMPROVE, terms, "the gathering asks for better work")
	# A deserved honour for a holding or a craft it admires (TownSocial.judge_recognition).
	if household.inspired_until >= city.construction.day and household.inspired_by_household >= 0:
		var whose: String = city.get_household_label(household.inspired_by_household)
		if household.inspired_by == TownSocial.RECOGNITION_ACHIEVEMENT:
			add(terms, 0.75, "it would match %s's honoured holding" % whose)
		elif household.inspired_by == TownSocial.RECOGNITION_CRAFT:
			add(terms, 0.5, "it would equal %s's honoured craft" % whose)
	return {"score": sum(terms), "terms": terms}

# How dangerous it is for the town to go on without more of an activity's output, 0 to 1.5.
static func get_waiting_risk(city: City, activity: String) -> float:
	match activity:
		TownInfluence.ACTIVITY_FOOD:
			var risk: float = 0.0
			var ratio: float = get_food_ratio(city)
			var days: float = get_food_days(city)
			# Half a year of food in store is security, whatever the fields grow meanwhile.
			if days >= SECURE_FOOD_DAYS:
				return 0.0
			if ratio < 1.0 or days < 45.0:
				risk = 1.0
			elif ratio < 1.25 or days < 90.0:
				risk = 0.5
			if days < 30.0:
				risk += 0.5
			return risk
		TownInfluence.ACTIVITY_WOOD:
			return 0.75 if int(city.resources["wood"]) < 20 else 0.0
		TownInfluence.ACTIVITY_TOOLS:
			return 0.75 if int(city.resources["tools"]) < 10 else 0.0
	return 0.0

# Proper workplaces of a type standing in the town.
static func count_proper(city: City, proper_type: String) -> int:
	var count: int = 0
	for building: Building in city.buildings:
		count += 1 if building.type == proper_type else 0
	return count

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
	var receptive: Dictionary = get_receptiveness(household, city)
	add(terms, ENCOURAGE_WEIGHT * float(receptive["factor"]), reason + str(receptive["note"]))

# How readily a family heeds the gathering's appeals, {"factor", "note"}. Before there are
# institutions, the community's decisions come from informal gatherings of its households (owner
# decision; docs/HOUSEHOLD_SOCIAL_MODEL.md), so trust is confidence in how those gatherings decide.
# Deference and trust make a family readier, self-government less; communal labor and solitary work
# nudge it; and an appeal carries more weight when the families it respects most stand behind it,
# less when they are families it is at odds with (TownSocial.get_respected_voices).
static func get_receptiveness(household: Household, city: City = null) -> Dictionary:
	var factor: float = 1.0
	var note_text: String = ""
	var deference: int = HouseholdCharacter.get_strength(household, "deferential")
	var self_rule: int = HouseholdCharacter.get_strength(household, "self_governing")
	if deference > 0:
		factor += 0.25 * deference
		note_text = ", and it heeds the gathering"
	elif self_rule > 0:
		factor -= 0.2 * self_rule
		note_text = ", though it judges for itself"
	factor += 0.15 * household.trust
	if household.trust <= -2:
		note_text += ", though it distrusts the gathering"
	factor += 0.25 * signf(HouseholdCharacter.get_strength(household, "communal_labor") - HouseholdCharacter.get_strength(household, "solitary"))
	if city != null and city.social.enabled:
		var voices: float = 0.0
		for voice: Household in city.social.get_respected_voices():
			if voice == household:
				continue
			var disposition: int = HouseholdMemory.get_disposition(household, voice.id)
			voices += 0.1 if disposition > 0 else -0.15 if disposition < 0 else 0.0
		voices = clampf(voices, -0.3, 0.3)
		if voices > 0.0:
			note_text += ", and families it respects speak for it"
		elif voices < 0.0:
			note_text += ", though families it is at odds with speak for it"
		factor += voices
	return {"factor": maxf(0.2, factor), "note": note_text}

# Proper workplaces worked by kin and near neighbours: how many pay (well kept) and how many stand
# short of tools (working by hand or idle for want of upkeep).
static func get_neighbours_example(city: City, household: Household) -> Dictionary:
	var paying: int = 0
	var idle: int = 0
	for other: Household in city.social.get_known_households(household):
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

# A household with first claim on the stores (an incentive it earned, or a grant; TownSocial) has
# its project put at the front of the queue, so builders and materials reach it first: the promise
# kept, which the household notices.
static func use_first_claim(city: City, household: Household, project: ConstructionProject) -> void:
	if household.first_claim_until < city.construction.day:
		return
	city.construction.prioritize(project.id)
	city.social.on_first_claim_used(household)

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
