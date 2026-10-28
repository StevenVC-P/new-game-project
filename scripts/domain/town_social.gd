class_name TownSocial
extends RefCounted

# How a town's households deal with one another, and what the community expects of them
# (docs/HOUSEHOLD_SOCIAL_MODEL.md). The household social prototype: off unless enabled, and then
# the town plays as before apart from what is described here.
#
# Weekly, each household on a holding decides whether to give its spare time to a neighbour's or a
# communal project (SocialDecisions.get_help_desire), and families whose fields others trample
# decide whether to press their claim, and the crossers whether to make amends. In a month of
# shortage, households the shortage would drive toward leaving are helped, or not, by neighbours
# who give up part of their ration. Every interaction leaves consequences for both sides: ties,
# favours owed, grievances, standing, trust, memories, and norm observations.
#
# Candidates come only from a household's kin, ties, and nearest neighbours (a spatial grid, at
# most MAX_NEIGHBOURS): nothing here loops over every pair of households.

const NORM_HELP: String = "help_neighbours"
const NORM_CLAIMS: String = "respect_claims"
const NORM_NAMES: Dictionary = {NORM_HELP: "Helping neighbours", NORM_CLAIMS: "Respecting claims"}
const NORM_PHRASES: Dictionary = {NORM_HELP: "help neighbours in need", NORM_CLAIMS: "respect each other's fields"}
const NORM_ASKS: Dictionary = {NORM_HELP: "help neighbours in need", NORM_CLAIMS: "respect each other's land"}
const STATUS_NONE: String = "not yet a habit"
const STATUS_HABIT: String = "a habit"
const STATUS_CUSTOM: String = "a custom"
# Acceptance moves this far toward what a household did at each opportunity.
const ACCEPTANCE_RATE: float = 0.06
const ACCEPTANCE_START: float = 0.4
const HABIT_AT: float = 0.55
const CUSTOM_AT: float = 0.7
const CUSTOM_AFTER_DAYS: int = 90

const WEEK_OFFSET: int = 2
const MAX_NEIGHBOURS: int = 6
const NEIGHBOUR_RADIUS: float = 10.0
const GRID_CELL: float = 4.0
const MAX_HELP_CANDIDATES: int = 6
# Daily trips through a field that make its family notice who crosses it, and how long a dispute
# rests before the same pair quarrels over it again.
const CROSSING_TRIPS: float = 0.5
const DISPUTE_COOLDOWN_DAYS: int = 90
const UNRETURNED_COOLDOWN_DAYS: int = 90
const FIRST_CLAIM_DAYS: int = 120
const GRANT_DAYS: int = 180
const HONOUR_PRESTIGE_DAYS: int = 120

var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
var enabled: bool = false
# Norm id -> {"promoted", "acceptance", "status", "since", "sanctions", "opportunities", "followed"}.
var norms: Dictionary = {}
# Material incentive: households who help or share get first claim on the stores for a while.
var incentive: bool = false
# Unsettled disputes: {"victim", "crosser", "field", "day", "settled", "count"}.
var disputes: Array = []
var dispute_pressure: int = 0
var value_changes: int = 0
var honour_day_for_helping: int = -100000
# Measures for the social check.
var help_weeks: int = 0
var help_opportunities: int = 0
var help_followed: int = 0
var share_requests: int = 0
var shares: int = 0
var disputes_raised: int = 0
var disputes_settled: int = 0
var disputes_let_pass: int = 0
# Time spent in weekly passes, for profiling (microseconds).
var week_usec_total: int = 0
var weeks_run: int = 0
# This week's spare-time help: "helper:recipient" (recipient -1: communal) -> days.
var help_days: Dictionary = {}
# Household id (as text) -> last day a stores refusal counted against its trust.
var held_back_days: Dictionary = {}
# The neighbour grid, rebuilt weekly: cell -> household ids.
var _grid: Dictionary = {}
var _grid_key: Array = []
# Parent household id -> the households founded from it, and id -> household, rebuilt with the
# grid (City.get_household_by_id searches the whole list).
var _children: Dictionary = {}
var _by_id: Dictionary = {}
# This week's projects of families in need that a neighbour weighed helping: id -> helped by anyone.
var _needy_seen: Dictionary = {}
var _projects_by_owner: Dictionary = {}
var _project_index_key: Array = []
var _food_days: float = 0.0
var _food_days_day: int = -1

func _init(owner: City) -> void:
	_city_ref = weakref(owner)
	for norm_id: String in [NORM_HELP, NORM_CLAIMS]:
		norms[norm_id] = {"promoted": false, "acceptance": ACCEPTANCE_START, "status": STATUS_NONE, "since": 0, "sanctions": 0, "opportunities": 0, "followed": 0}

func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		for household: Household in city.households:
			HouseholdCharacter.ensure(city, household)
			HouseholdMemory.ensure_kin_ties(city, household)

# --- The week ------------------------------------------------------------------------------------

func advance_day() -> void:
	if not enabled:
		return
	if city.construction.day % FamilyInitiative.INTERVAL_DAYS == WEEK_OFFSET:
		advance_week()

func advance_week() -> void:
	var started: int = Time.get_ticks_usec()
	run_week()
	week_usec_total += Time.get_ticks_usec() - started
	weeks_run += 1

func run_week() -> void:
	rebuild_neighbours()
	for household: Household in city.households:
		HouseholdCharacter.ensure(city, household)
		HouseholdMemory.ensure_kin_ties(city, household)
	settle_help_week()
	for household: Household in city.households:
		choose_help(household)
	observe_needy_week()
	run_disputes()
	update_norms()

# --- Neighbours ----------------------------------------------------------------------------------

func rebuild_neighbours() -> void:
	_grid.clear()
	_children.clear()
	_by_id.clear()
	_grid_key = get_grid_key()
	for household: Household in city.households:
		_by_id[household.id] = household
		var cell: Vector2i = get_cell(household)
		if not _grid.has(cell):
			_grid[cell] = []
		(_grid[cell] as Array).append(household.id)
		for parent_id: int in [household.parent_household_id, household.second_parent_household_id]:
			if parent_id >= 0:
				if not _children.has(parent_id):
					_children[parent_id] = []
				(_children[parent_id] as Array).append(household.id)

# Kin living in the town: the households it came from and the ones it founded.
func get_kin(household: Household) -> Array[Household]:
	ensure_grid()
	var kin: Array[Household] = []
	for kin_id in [household.parent_household_id, household.second_parent_household_id] + (_children.get(household.id, []) as Array):
		var other: Household = find(int(kin_id))
		if other != null and other != household and not kin.has(other):
			kin.append(other)
	return kin

# The grid is rebuilt each week, and when households come or go or the stockpile (where families
# without a home camp) is placed; homes finished mid-week count from the next week.
func get_grid_key() -> Array:
	return [city.construction.day / FamilyInitiative.INTERVAL_DAYS, city.households.size(), city.logistics.stockpile_tile]

func ensure_grid() -> void:
	if _grid_key != get_grid_key():
		rebuild_neighbours()

# The town's days of food in store, counted once a day (it sums every household).
func get_food_days() -> float:
	if _food_days_day != city.construction.day:
		_food_days_day = city.construction.day
		_food_days = FamilyInitiative.get_food_days(city)
	return _food_days

func find(household_id: int) -> Household:
	ensure_grid()
	return _by_id.get(household_id, null)

func get_cell(household: Household) -> Vector2i:
	if city.local_map.is_empty():
		return Vector2i.ZERO
	var home: Vector2i = city.logistics.get_home_tile(household)
	return Vector2i(floori(home.x / GRID_CELL), floori(home.y / GRID_CELL))

# The households living nearest, within NEIGHBOUR_RADIUS, at most MAX_NEIGHBOURS. The search widens
# ring by ring from the household's own grid cell and stops once it has enough, so a crowded town
# costs no more per household than a sparse one. Without a town map, the households nearest it in
# the town's list.
func get_neighbours(household: Household) -> Array[Household]:
	ensure_grid()
	var found: Array[Household] = []
	var cell: Vector2i = get_cell(household)
	var home: Vector2 = Vector2(city.logistics.get_home_tile(household)) if not city.local_map.is_empty() else Vector2.ZERO
	var rings: int = ceili(NEIGHBOUR_RADIUS / GRID_CELL)
	for ring in range(0, rings + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				for other_id in _grid.get(cell + Vector2i(dx, dy), []):
					var other: Household = find(int(other_id))
					if other == null or other == household:
						continue
					if not city.local_map.is_empty() and home.distance_to(Vector2(city.logistics.get_home_tile(other))) > NEIGHBOUR_RADIUS:
						continue
					found.append(other)
		if found.size() >= MAX_NEIGHBOURS:
			break
	if city.local_map.is_empty():
		found.sort_custom(func(a: Household, b: Household) -> bool: return absi(a.id - household.id) < absi(b.id - household.id))
	else:
		found.sort_custom(func(a: Household, b: Household) -> bool: return home.distance_squared_to(Vector2(city.logistics.get_home_tile(a))) < home.distance_squared_to(Vector2(city.logistics.get_home_tile(b))))
	return found.slice(0, MAX_NEIGHBOURS)

# Everyone a household knows well enough to weigh: its ties (kin among them) and its neighbours.
func get_known_households(household: Household) -> Array[Household]:
	var known: Array[Household] = []
	for tie: Dictionary in household.ties:
		var other: Household = find(int(tie["with"]))
		if other != null and not known.has(other):
			known.append(other)
	for other: Household in get_kin(household):
		if not known.has(other):
			known.append(other)
	for other: Household in get_neighbours(household):
		if not known.has(other):
			known.append(other)
	return known

# --- Circumstances --------------------------------------------------------------------------------

# How far a household is from being driven to leave: its material security.
static func get_security_margin(household: Household) -> int:
	return HouseholdMigration.get_departure_threshold(household) - household.hardship_points

# A donor's margin once the shortage and the point it gives away are counted. It can give only if
# that leaves it clear of considering departure itself.
static func get_margin_after_giving(household: Household) -> int:
	return get_security_margin(household) - HouseholdMigration.HARDSHIP_SHORTAGE_POINTS - 1

static func can_afford_to_share(household: Household) -> bool:
	return get_margin_after_giving(household) > HouseholdMigration.DEPARTURE_WARNING_MARGIN

# A household is in need while it builds its first proper home, or while hardship weighs on it.
static func is_in_need(city_ref: City, household: Household, project: ConstructionProject = null) -> bool:
	if project != null and project.is_home() and project.claimant_household_id == household.id and (household.housing_status != Household.RESIDENCE_HOUSED or city_ref.is_household_in_rough_housing(household)):
		return true
	return HouseholdMigration.is_considering_departure(household)

static func describe_security(household: Household) -> String:
	var margin: int = get_security_margin(household)
	if margin <= 2:
		return "close to leaving"
	if margin <= 4:
		return "getting by"
	return "secure"

# --- Helping ---------------------------------------------------------------------------------------

func choose_help(household: Household) -> void:
	household.helping_project_id = -1
	if household.labor_capacity <= 0 or household.assigned_workers <= 0:
		return
	for project: ConstructionProject in get_projects_of(household):
		if city.construction.can_progress(project):
			return
	var best: ConstructionProject = null
	var best_score: float = -INF
	var best_desire: Dictionary = {}
	var declined: Dictionary = {}
	var declined_project: ConstructionProject = null
	for project: ConstructionProject in get_help_candidates(household):
		var target: Household = get_project_owner(project)
		var desire: Dictionary = SocialDecisions.get_help_desire(city, household, project, target)
		var score: float = float(desire["score"]) + FamilyInitiative.get_noise(city, household, "help:%d" % project.id)
		if target != null and is_in_need(city, target, project) and not _needy_seen.has(project.id):
			_needy_seen[project.id] = false
		if score >= SocialDecisions.HELP_THRESHOLD and score > best_score:
			best = project
			best_score = score
			best_desire = desire
		elif score < SocialDecisions.HELP_THRESHOLD:
			if declined.is_empty():
				declined = desire
				declined_project = project
			if target != null:
				notice_unreturned(household, target)
	if best != null:
		household.helping_project_id = best.id
		var target: Household = get_project_owner(best)
		if _needy_seen.has(best.id):
			_needy_seen[best.id] = true
		note(household, "Helping %s (%s)" % [describe_project(best, target), "; ".join(FamilyInitiative.get_reasons(best_desire["terms"], true))])
	elif declined_project != null:
		note(household, "Keeps to its own work rather than help %s (%s)" % [describe_project(declined_project, get_project_owner(declined_project)), "; ".join(FamilyInitiative.get_reasons(declined["terms"], false))])

# The help norm is about the community: each week, a family in need that some neighbour could help
# was either helped by someone or by no one.
func observe_needy_week() -> void:
	for project_id: int in _needy_seen.keys():
		var helped: bool = bool(_needy_seen[project_id])
		help_opportunities += 1
		help_followed += 1 if helped else 0
		observe_norm(NORM_HELP, helped)
	_needy_seen.clear()

# Neighbours' and kin's projects, and communal ones, that builders can work on now, nearest first.
func get_help_candidates(household: Household) -> Array[ConstructionProject]:
	var candidates: Array[ConstructionProject] = []
	var pool: Array[ConstructionProject] = []
	for other: Household in get_known_households(household):
		pool.append_array(get_projects_of(other))
	pool.append_array(get_communal_projects())
	for project: ConstructionProject in pool:
		if city.construction.can_progress(project):
			candidates.append(project)
	if not city.local_map.is_empty():
		var home: Vector2 = Vector2(city.logistics.get_home_tile(household))
		candidates.sort_custom(func(a: ConstructionProject, b: ConstructionProject) -> bool: return home.distance_squared_to(Vector2(a.tile)) < home.distance_squared_to(Vector2(b.tile)))
	return candidates.slice(0, MAX_HELP_CANDIDATES)

# Projects by the family they are built for, and the communal ones, indexed once per call of the
# day so no household scans the whole queue.
func get_projects_of(household: Household) -> Array[ConstructionProject]:
	ensure_project_index()
	var found: Array[ConstructionProject] = []
	found.assign(_projects_by_owner.get(household.id, []))
	return found

func get_communal_projects() -> Array[ConstructionProject]:
	ensure_project_index()
	var found: Array[ConstructionProject] = []
	found.assign(_projects_by_owner.get(-1, []))
	return found.slice(0, MAX_HELP_CANDIDATES)

func ensure_project_index() -> void:
	var key: Array = [city.construction.day, city.construction.next_project_id, city.construction.projects.size()]
	if key == _project_index_key:
		return
	_project_index_key = key
	_projects_by_owner.clear()
	for project: ConstructionProject in city.construction.projects:
		var owner_id: int = -1 if is_communal(project) else project.claimant_household_id
		if owner_id == -1 and not is_communal(project):
			continue
		if not _projects_by_owner.has(owner_id):
			_projects_by_owner[owner_id] = []
		(_projects_by_owner[owner_id] as Array).append(project)

# Roads, stores, and the watch are the community's, whoever builds them; anything else is the
# project of the family it is built for.
static func is_communal(project: ConstructionProject) -> bool:
	return project.kind == ConstructionProject.KIND_ROAD or project.building_type in [Building.BUILDING_STOREHOUSE, Building.BUILDING_WATCH_POST]

func get_project_owner(project: ConstructionProject) -> Household:
	return null if is_communal(project) else find(project.claimant_household_id)

# TownConstruction calls this for every day a household gives spare time to someone else's project.
func record_help_day(helper: Household, project: ConstructionProject) -> void:
	var owner: Household = get_project_owner(project)
	if not enabled or owner == helper:
		return
	var key: String = "%d:%d" % [helper.id, owner.id if owner != null else -1]
	help_days[key] = int(help_days.get(key, 0)) + 1

# The week's help settles into ties, favours owed, standing, and memories.
func settle_help_week() -> void:
	for key: String in help_days.keys():
		var parts: PackedStringArray = key.split(":")
		var helper: Household = find(int(parts[0]))
		var recipient: Household = find(int(parts[1]))
		if helper == null:
			continue
		help_weeks += 1
		helper.help_given += 1
		adjust_standing(helper, 0.25)
		if incentive:
			grant_first_claim(helper, FIRST_CLAIM_DAYS)
		if recipient == null:
			continue
		recipient.help_received += 1
		var first_time: bool = int(HouseholdMemory.get_tie(recipient, helper.id).get("owes", 0)) <= 0
		HouseholdMemory.touch_tie(city, recipient, helper, 1, "helped us build", 1)
		HouseholdMemory.touch_tie(city, helper, recipient, 0, "we helped them build", -1)
		if first_time:
			HouseholdMemory.experience(city, recipient, "helped", "%s helped build its %s" % [city.get_household_label(helper.id), "home" if is_in_need(city, recipient) else "work"], helper, {"benefit": 1, "voluntary": true})
	help_days.clear()

# A household that owes another for its help, and now passes over that household's project, is
# noticed: help that is never returned breeds resentment.
func notice_unreturned(household: Household, target: Household) -> void:
	var owed: Dictionary = HouseholdMemory.get_tie(household, target.id)
	if owed.is_empty() or int(owed["owes"]) < 2:
		return
	var their_tie: Dictionary = HouseholdMemory.get_tie(target, household.id)
	if not their_tie.is_empty() and city.construction.day - int(their_tie.get("unreturned_day", -UNRETURNED_COOLDOWN_DAYS)) < UNRETURNED_COOLDOWN_DAYS:
		return
	their_tie = HouseholdMemory.touch_tie(city, target, household, -1, "does not return help")
	their_tie["unreturned_day"] = city.construction.day
	norms[NORM_HELP]["sanctions"] = int(norms[NORM_HELP]["sanctions"]) + 1
	HouseholdMemory.experience(city, target, "help_unreturned", "%s did not return its help" % city.get_household_label(household.id), household, {"benefit": -1})

# --- Sharing in a shortage ------------------------------------------------------------------------

# Before a month's hardship is counted (HouseholdMigration): in a month of shortage, each household
# the shortage would bring close to leaving looks to the households it knows. The first willing
# donor gives up part of its ration: the donor takes on a point of the shortage's hardship, the
# recipient is spared one. Each donor gives once a month.
func share_in_shortage() -> void:
	if not enabled or int(city.resources["shortage_days_this_month"]) < HouseholdMigration.HARDSHIP_SHORTAGE_DAYS:
		return
	var at_risk: Array[Household] = []
	for household: Household in city.households:
		if household.hardship_points + HouseholdMigration.HARDSHIP_SHORTAGE_POINTS >= HouseholdMigration.get_departure_threshold(household) - HouseholdMigration.DEPARTURE_WARNING_MARGIN:
			at_risk.append(household)
	at_risk.sort_custom(func(a: Household, b: Household) -> bool: return get_security_margin(a) < get_security_margin(b) or (get_security_margin(a) == get_security_margin(b) and a.id < b.id))
	var given: Array[int] = []
	for recipient: Household in at_risk:
		share_requests += 1
		var donors: Array[Household] = get_known_households(recipient).filter(func(other: Household) -> bool: return not at_risk.has(other) and not given.has(other.id))
		donors.sort_custom(func(a: Household, b: Household) -> bool: return HouseholdMemory.get_disposition(recipient, a.id) > HouseholdMemory.get_disposition(recipient, b.id) or (HouseholdMemory.get_disposition(recipient, a.id) == HouseholdMemory.get_disposition(recipient, b.id) and a.id < b.id))
		var donor_found: Household = null
		var refused_able: bool = false
		for donor: Household in donors:
			var desire: Dictionary = SocialDecisions.get_share_desire(city, donor, recipient)
			var able: bool = can_afford_to_share(donor)
			if able and float(desire["score"]) + FamilyInitiative.get_noise(city, donor, "share:%d" % recipient.id) >= SocialDecisions.SHARE_THRESHOLD:
				donor_found = donor
				note(donor, "Shared its ration with %s (%s)" % [city.get_household_label(recipient.id), "; ".join(FamilyInitiative.get_reasons(desire["terms"], true))])
				break
			refused_able = refused_able or able
			note(donor, "Did not share with %s (%s)" % [city.get_household_label(recipient.id), "; ".join(FamilyInitiative.get_reasons(desire["terms"], false))])
		if donor_found != null:
			shares += 1
			given.append(donor_found.id)
			donor_found.shortage_hardship_adjust += 1
			recipient.shortage_hardship_adjust -= 1
			donor_found.help_given += 1
			adjust_standing(donor_found, 0.5)
			if incentive:
				grant_first_claim(donor_found, FIRST_CLAIM_DAYS)
			HouseholdMemory.touch_tie(city, recipient, donor_found, 1, "shared food with us", 1)
			HouseholdMemory.touch_tie(city, donor_found, recipient, 1, "we shared food with them", -1)
			HouseholdMemory.experience(city, recipient, "food_received", "%s shared its food in the shortage" % city.get_household_label(donor_found.id), donor_found, {"benefit": 1, "voluntary": true, "major": true})
			HouseholdMemory.experience(city, donor_found, "food_given", "It shared food with %s in the shortage" % city.get_household_label(recipient.id), recipient, {"cost": 1.0 if get_security_margin(donor_found) <= 4 else 0.0})
			observe_norm(NORM_HELP, true)
		elif not donors.is_empty():
			var asked: Household = donors[0]
			var could_not: bool = not can_afford_to_share(asked)
			if not could_not:
				HouseholdMemory.touch_tie(city, recipient, asked, -1, "would not share in the shortage")
				norms[NORM_HELP]["sanctions"] = int(norms[NORM_HELP]["sanctions"]) + 1
			HouseholdMemory.experience(city, recipient, "food_refused", "%s did not share its food in the shortage" % city.get_household_label(asked.id), asked, {"benefit": -1, "could_not": could_not, "major": true})
			if refused_able:
				observe_norm(NORM_HELP, false)

# --- Claims on fields -----------------------------------------------------------------------------

# Families whose fields others' walking tramples decide whether to press their claim; the crossing
# family decides whether to make amends by fencing the field with its own labor.
func run_disputes() -> void:
	for building: Building in city.buildings:
		if not TownLogistics.is_field(building) or building.fenced or building.assigned_household_id < 0:
			continue
		var victim: Household = find(building.assigned_household_id)
		if victim == null:
			continue
		var crossings: Dictionary = city.logistics.trampled_by.get(building.id, {})
		var loss: float = city.logistics.get_field_trample_loss(building)
		var crossers: Array = crossings.keys()
		crossers.sort()
		for crosser_id in crossers:
			var crosser: Household = find(int(crosser_id))
			if crosser == null or crosser == victim or float(crossings[crosser_id]) < CROSSING_TRIPS or is_resting(victim.id, crosser.id):
				continue
			press_claim(victim, crosser, building, loss)

func is_resting(victim_id: int, crosser_id: int) -> bool:
	for dispute: Dictionary in disputes:
		if int(dispute["victim"]) == victim_id and int(dispute["crosser"]) == crosser_id and city.construction.day - int(dispute["day"]) < DISPUTE_COOLDOWN_DAYS:
			return true
	return false

func get_dispute(victim_id: int, crosser_id: int) -> Dictionary:
	for dispute: Dictionary in disputes:
		if int(dispute["victim"]) == victim_id and int(dispute["crosser"]) == crosser_id:
			return dispute
	return {}

func press_claim(victim: Household, crosser: Household, field: Building, loss: float) -> void:
	var dispute: Dictionary = get_dispute(victim.id, crosser.id)
	if dispute.is_empty():
		dispute = {"victim": victim.id, "crosser": crosser.id, "field": field.id, "day": city.construction.day, "settled": false, "count": 0}
		disputes.append(dispute)
	dispute["day"] = city.construction.day
	var raise: Dictionary = SocialDecisions.get_raise_desire(city, victim, crosser, loss)
	if float(raise["score"]) + FamilyInitiative.get_noise(city, victim, "raise:%d" % crosser.id) < SocialDecisions.RAISE_THRESHOLD:
		disputes_let_pass += 1
		note(victim, "Lets %s's crossing of its field pass (%s)" % [city.get_household_label(crosser.id), "; ".join(FamilyInitiative.get_reasons(raise["terms"], false))])
		return
	disputes_raised += 1
	dispute["count"] = int(dispute["count"]) + 1
	note(victim, "Demands that %s stop trampling its field (%s)" % [city.get_household_label(crosser.id), "; ".join(FamilyInitiative.get_reasons(raise["terms"], true))])
	var amends: Dictionary = SocialDecisions.get_amends_desire(city, crosser, victim)
	if float(amends["score"]) + FamilyInitiative.get_noise(city, crosser, "amends:%d" % victim.id) >= SocialDecisions.AMENDS_THRESHOLD:
		settle(victim, crosser, field, dispute, amends)
	else:
		leave_unsettled(victim, crosser, dispute, amends)

func settle(victim: Household, crosser: Household, field: Building, dispute: Dictionary, amends: Dictionary) -> void:
	disputes_settled += 1
	dispute["settled"] = true
	var how: String = "fence the field with its own labor"
	var fence: ConstructionProject = null
	if city.construction.can_fence(field.id) and city.construction.can_supply(EconomyBalance.get_fence_cost(field.size), city.influence.get_protected_reserve()):
		fence = city.construction.request_fence(field.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD)
	if fence != null:
		crosser.helping_project_id = fence.id
	else:
		how = "help with the family's next work"
		HouseholdMemory.touch_tie(city, crosser, victim, 0, "", 1)
	HouseholdMemory.touch_tie(city, victim, crosser, 1, "made amends for crossing our field", 0, "-")
	HouseholdMemory.touch_tie(city, crosser, victim, 0, "we made amends for crossing their field")
	note(crosser, "Agreed to %s for %s (%s)" % [how, city.get_household_label(victim.id), "; ".join(FamilyInitiative.get_reasons(amends["terms"], true))])
	HouseholdMemory.experience(city, victim, "dispute_settled", "%s made amends for trampling its field" % city.get_household_label(crosser.id), crosser, {"victim": true, "fair": 1})
	HouseholdMemory.experience(city, crosser, "dispute_settled", "It made amends to %s for trampling their field" % city.get_household_label(victim.id), victim, {"cost": 1.0})
	observe_norm(NORM_CLAIMS, true)

func leave_unsettled(victim: Household, crosser: Household, dispute: Dictionary, amends: Dictionary) -> void:
	dispute["settled"] = false
	dispute_pressure += 1
	var repeated: bool = int(dispute["count"]) > 1
	HouseholdMemory.touch_tie(city, victim, crosser, -3 if repeated else -2, "tramples our field and refuses amends", 0, "tramples its field and refuses amends")
	HouseholdMemory.touch_tie(city, crosser, victim, -1, "makes a quarrel of a footpath")
	# Where the town expects claims to be respected, the refusal costs standing: the neighbours'
	# disapproval is the first sanction there is.
	if float(norms[NORM_CLAIMS]["acceptance"]) >= 0.5 or bool(norms[NORM_CLAIMS]["promoted"]):
		adjust_standing(crosser, -1.0)
		norms[NORM_CLAIMS]["sanctions"] = int(norms[NORM_CLAIMS]["sanctions"]) + 1
	note(crosser, "Refused to make amends to %s (%s)" % [city.get_household_label(victim.id), "; ".join(FamilyInitiative.get_reasons(amends["terms"], false))])
	HouseholdMemory.experience(city, victim, "dispute_unsettled", "%s tramples its field and refused amends" % city.get_household_label(crosser.id), crosser, {"victim": true, "fair": -1, "major": repeated})
	HouseholdMemory.experience(city, crosser, "dispute_unsettled", "%s made a quarrel over its crossing" % city.get_household_label(victim.id), victim, {"victim": false})
	observe_norm(NORM_CLAIMS, false)

# --- The player's levers ---------------------------------------------------------------------------

func set_promoted(norm_id: String, on: bool) -> void:
	norms[norm_id]["promoted"] = on

# Publicly honours a household. Its standing rises, and every household judges whether it was
# fair: whoever contributed more, or holds equality dear, may resent it and trust the leadership
# less; those who look up to honour may imitate it.
func recognize(target: Household) -> void:
	target.recognized += 1
	adjust_standing(target, 1.0)
	if target.help_given > 0:
		honour_day_for_helping = city.construction.day
	var proud: bool = HouseholdCharacter.get_axis(target, HouseholdCharacter.SOCIABILITY) > -2 and HouseholdCharacter.get_axis(target, HouseholdCharacter.AMBITION) >= 0
	if proud:
		adjust_trust(target, 1.0)
	HouseholdMemory.experience(city, target, "honoured", "The community honoured it", null, {"benefit": 1})
	judge_fairness(target, "honour", "The community honoured %s" % city.get_household_label(target.id))

# Gives a household first claim on the stores for its own projects for a while: a distribution of
# communal resources, judged for fairness like an honour.
func grant(target: Household) -> void:
	target.grants_received += 1
	grant_first_claim(target, GRANT_DAYS)
	judge_fairness(target, "share", "The community gave %s first claim on the stores" % city.get_household_label(target.id))

func grant_first_claim(household: Household, days: int) -> void:
	household.first_claim_until = maxi(household.first_claim_until, city.construction.day + days)

# Each household weighs whether a distinction was deserved: by what the honoured household gave
# the community (help given, food shared) against the town's middle and its own.
func judge_fairness(target: Household, kind: String, text: String) -> void:
	var contributions: Array[int] = []
	for household: Household in city.households:
		contributions.append(household.help_given)
	contributions.sort()
	var middle: int = contributions[contributions.size() / 2] if not contributions.is_empty() else 0
	for observer: Household in city.households:
		if observer == target:
			continue
		var overlooked: int = observer.help_given - target.help_given
		# Honouring the same household again and again is favouritism, whatever it has done.
		var favoured: bool = target.recognized + target.grants_received > 2
		var deserved: bool = target.help_given >= middle and overlooked < 2 and not favoured
		if kind == "share":
			deserved = deserved and observer.grants_received >= target.grants_received - 1
		if deserved:
			if HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION) > 0 or HouseholdCharacter.get_strength(observer, "communal_labor") >= 2:
				HouseholdMemory.experience(city, observer, "honour_fair", text, target, {"fair": 1})
			continue
		var resentment: float = 1.0 + HouseholdCharacter.get_strength(observer, "egalitarian") + 0.5 * maxi(0, HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION)) + (0.5 if overlooked >= 2 else 0.0) - HouseholdCharacter.get_strength(observer, "hierarchical") - 0.5 * HouseholdCharacter.get_strength(observer, "deferential")
		var said: String = text
		if kind == "share" and observer.grants_received > 0:
			said = "It accepted the community's help, but %s got more" % city.get_household_label(target.id)
		if resentment >= 1.5:
			adjust_trust(observer, -1.0)
			HouseholdMemory.touch_tie(city, observer, target, -1, "was favoured over us")
			note(observer, "Resents the favour shown to %s" % city.get_household_label(target.id))
		else:
			adjust_trust(observer, -0.25)
		HouseholdMemory.experience(city, observer, kind + "_unfair", said, target, {"fair": -1, "overlooked": maxf(0.0, float(overlooked))})

func helping_honoured_recently() -> bool:
	return city.construction.day - honour_day_for_helping <= HONOUR_PRESTIGE_DAYS

# The stores rule held back a household's own project (TownInfluence). Once a month at most, a
# household that is not secure takes it as the stores being closed to families like it.
func on_held_back(household: Household) -> void:
	if not enabled:
		return
	var key: String = str(household.id)
	if city.construction.day - int(held_back_days.get(key, -60)) < 30:
		return
	held_back_days[key] = city.construction.day
	if get_security_margin(household) <= 4:
		adjust_trust(household, -0.5)

# First claim on the stores let a household's project through: a promise kept.
func on_first_claim_used(household: Household) -> void:
	if enabled:
		adjust_trust(household, 0.5)

# --- Trust, standing, norms -----------------------------------------------------------------------

func adjust_trust(household: Household, amount: float) -> void:
	household.trust_progress += amount
	while household.trust_progress >= 1.0 and household.trust < 3:
		household.trust += 1
		household.trust_progress -= 1.0
	while household.trust_progress <= -1.0 and household.trust > -3:
		household.trust -= 1
		household.trust_progress += 1.0
	household.trust_progress = clampf(household.trust_progress, -0.99, 0.99)

func adjust_standing(household: Household, amount: float) -> void:
	household.standing_progress += amount
	while household.standing_progress >= 1.0 and household.standing < 3:
		household.standing += 1
		household.standing_progress -= 1.0
	while household.standing_progress <= -1.0 and household.standing > -3:
		household.standing -= 1
		household.standing_progress += 1.0
	household.standing_progress = clampf(household.standing_progress, -0.99, 0.99)

# Every opportunity to follow or break a norm moves its acceptance toward what was done.
func observe_norm(norm_id: String, followed: bool) -> void:
	var norm: Dictionary = norms[norm_id]
	norm["opportunities"] = int(norm["opportunities"]) + 1
	norm["followed"] = int(norm["followed"]) + (1 if followed else 0)
	norm["acceptance"] = float(norm["acceptance"]) + ACCEPTANCE_RATE * ((1.0 if followed else 0.0) - float(norm["acceptance"]))

# A norm becomes a habit when most opportunities are followed, and a custom when it has been widely
# followed for a season and breaking it has drawn a reaction. Each falls back a little below where
# it formed, so statuses do not flicker.
func update_norms() -> void:
	for norm_id: String in norms.keys():
		var norm: Dictionary = norms[norm_id]
		var acceptance: float = float(norm["acceptance"])
		var status: String = norm["status"]
		if status == STATUS_NONE and acceptance >= HABIT_AT:
			norm["status"] = STATUS_HABIT
			norm["since"] = city.construction.day
		elif status == STATUS_HABIT:
			if acceptance < HABIT_AT - 0.1:
				norm["status"] = STATUS_NONE
			elif acceptance >= CUSTOM_AT and int(norm["sanctions"]) > 0 and city.construction.day - int(norm["since"]) >= CUSTOM_AFTER_DAYS:
				norm["status"] = STATUS_CUSTOM
				norm["since"] = city.construction.day
		elif status == STATUS_CUSTOM and acceptance < CUSTOM_AT - 0.1:
			norm["status"] = STATUS_HABIT
			norm["since"] = city.construction.day

# --- Describing ------------------------------------------------------------------------------------

func note(household: Household, text: String) -> void:
	household.social_note = text
	household.social_note_day = city.construction.day

func describe_project(project: ConstructionProject, target: Household) -> String:
	var what: String = TownConstruction.get_display_name(project).to_lower()
	if target == null:
		return "build the town's " + what
	return "%s build its %s" % [city.get_household_label(target.id), what]

func get_sidebar_lines() -> Array[String]:
	var lines: Array[String] = []
	for norm_id: String in [NORM_HELP, NORM_CLAIMS]:
		var norm: Dictionary = norms[norm_id]
		lines.append("%s: %s, %d%%" % [NORM_NAMES[norm_id], norm["status"], roundi(float(norm["acceptance"]) * 100.0)])
	var open: int = disputes.filter(func(d: Dictionary) -> bool: return not bool(d["settled"])).size()
	if open > 0:
		lines.append("Unsettled disputes: %d%s" % [open, " (families look for agreed rules)" if dispute_pressure >= 2 else ""])
	return lines
