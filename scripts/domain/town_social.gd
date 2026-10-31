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

# What the gathering may honour a household for (owner decision). The kinds are not equivalent:
# each household judges an honour by what it prizes (get_esteem) and by what the honoured family
# did of that kind (get_merit).
const RECOGNITION_SERVICE: String = "service"
const RECOGNITION_ACHIEVEMENT: String = "achievement"
const RECOGNITION_CRAFT: String = "craft"
const RECOGNITION_CIVIC: String = "civic"
const RECOGNITIONS: Array[String] = [RECOGNITION_SERVICE, RECOGNITION_ACHIEVEMENT, RECOGNITION_CRAFT, RECOGNITION_CIVIC]
const RECOGNITION_NAMES: Dictionary = {
	RECOGNITION_SERVICE: "community service", RECOGNITION_ACHIEVEMENT: "productive achievement",
	RECOGNITION_CRAFT: "craftsmanship", RECOGNITION_CIVIC: "civic contribution",
}
# A household's judgment of an honour: at or above FAIR_AT it was deserved, at or below UNFAIR_AT
# it was not, and at RESENT_AT the household resents it.
const HONOUR_FAIR_AT: float = 1.0
const HONOUR_UNFAIR_AT: float = -1.0
const HONOUR_RESENT_AT: float = -2.0

# Households whose standing reaches this are the gathering's respected voices, at most MAX_VOICES.
const VOICE_STANDING: int = 2
const MAX_VOICES: int = 3
# Changes to what the gathering asks and how it shares the stores, looked back over this many days:
# none is a steady hand, MANY_CHANGES is a gathering that keeps changing its mind.
const POLICY_WINDOW_DAYS: int = 90
const MANY_CHANGES: int = 3

# Contested land (owner verification request): kinds of contest, and the margin by which land
# another family has only just claimed must be nearer before a household asks for it.
const CONTEST_SAME_FIELD: String = "same field"
const CONTEST_NEWCOMER: String = "land in use"
const CONTEST_COMMUNAL: String = "the town's use"
const CONTEST_NEARER_TILES: float = 4.0
const LONG_DAYS_THRESHOLD: float = 1.0

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
# Measures for the social check.
var help_weeks: int = 0
var help_opportunities: int = 0
var help_followed: int = 0
var share_requests: int = 0
var shares: int = 0
var disputes_raised: int = 0
var disputes_settled: int = 0
var disputes_let_pass: int = 0
var land_contests: int = 0
var land_not_pressed: int = 0
var land_yielded: int = 0
var land_kept: int = 0
var land_taken: int = 0
var long_day_weeks: int = 0
var kin_help_weeks: int = 0
# Weeks a household on a holding, with no building of its own, helped no one (whether or not
# anyone's site was open to it).
var spare_weeks_unused: int = 0
var spare_weeks_no_site: int = 0
# Why households passed over a neighbour's or the town's project, by their strongest reason:
# reason -> weeks (for watching whether voluntary help leaves building short of hands).
var decline_reasons: Dictionary = {}
# Weekly help choices that differed from the household's choice the week before (behavior), to set
# against value changes (conviction).
var help_choice_changes: int = 0
# Value changes that undid the value's previous change, and the last direction of each
# ("household:value" -> stronger).
var value_reversals: int = 0
var value_change_directions: Dictionary = {}
# Honours given, and the different readings households made of them, summed over honours.
var honours: int = 0
var honour_readings: int = 0
# Trust gained and lost, by source, for the social check: source -> total.
var trust_by_source: Dictionary = {}
# Days the gathering changed what it asks for or how it shares the stores, and the last state seen.
var policy_change_days: Array = []
var policy_signature: Array = []
# Communal project id (as text) -> households that worked on it.
var communal_contributors: Dictionary = {}
# Time spent in weekly passes, for profiling (microseconds). Not saved: wall-clock time differs
# every run, and a loaded town must play on exactly as the original.
var _week_usec_total: int = 0
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
	_week_usec_total += Time.get_ticks_usec() - started
	weeks_run += 1

func run_week() -> void:
	rebuild_neighbours()
	for household: Household in city.households:
		HouseholdCharacter.ensure(city, household)
		HouseholdMemory.ensure_kin_ties(city, household)
	record_policy()
	settle_help_week()
	for household: Household in city.households:
		var was_helping: bool = household.helping_project_id >= 0
		choose_help(household)
		help_choice_changes += 1 if was_helping != (household.helping_project_id >= 0) else 0
		choose_hours(household)
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
	# Another project it also wanted to help: one household's labor, more than one obligation.
	var passed_over: ConstructionProject = null
	for project: ConstructionProject in get_help_candidates(household):
		var target: Household = get_project_owner(project)
		var desire: Dictionary = SocialDecisions.get_help_desire(city, household, project, target)
		var score: float = float(desire["score"]) + FamilyInitiative.get_noise(city, household, "help:%d" % project.id)
		if target != null and is_in_need(city, target, project) and not _needy_seen.has(project.id):
			_needy_seen[project.id] = false
		if score >= SocialDecisions.HELP_THRESHOLD and score > best_score:
			if best != null:
				passed_over = best
			best = project
			best_score = score
			best_desire = desire
		elif score >= SocialDecisions.HELP_THRESHOLD:
			if passed_over == null:
				passed_over = project
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
		var torn: String = ""
		if passed_over != null:
			torn = ", though it would also have helped %s" % describe_project(passed_over, get_project_owner(passed_over))
		note(household, "Helping %s (%s)%s" % [describe_project(best, target), "; ".join(FamilyInitiative.get_reasons(best_desire["terms"], true)), torn])
		if CommunityPriority.is_swayed(best_score, float(best_desire.get("appeal", 0.0)), SocialDecisions.HELP_THRESHOLD):
			CommunityPriority.record_swayed(city, household, "help", "It gave its spare time to %s because the gathering put %s first" % [describe_project(best, target), CommunityPriority.PHRASES[city.influence.priority]])
	else:
		spare_weeks_unused += 1
		spare_weeks_no_site += 1 if declined_project == null else 0
	if best == null and declined_project != null:
		var reasons: Array[String] = FamilyInitiative.get_reasons(declined["terms"], false)
		if not reasons.is_empty():
			var main: String = reasons[0].get_slice(":", 0)
			decline_reasons[main] = int(decline_reasons.get(main, 0)) + 1
		note(household, "Keeps to its own work rather than help %s (%s)" % [describe_project(declined_project, get_project_owner(declined_project)), "; ".join(reasons)])

# The help norm is about the community: each week, a family in need that some neighbour could help
# was either helped by someone or by no one.
func observe_needy_week() -> void:
	for project_id: int in _needy_seen.keys():
		var helped: bool = bool(_needy_seen[project_id])
		help_opportunities += 1
		help_followed += 1 if helped else 0
		observe_norm(NORM_HELP, helped)
	_needy_seen.clear()

# --- Long days -------------------------------------------------------------------------------------

# Whether a household on a holding works long days this week, giving its spare time to building out
# of its rest (TownConstruction.project_add_spare) instead of out of its holding: only when it has
# building to do, its own or the project it chose to help.
func choose_hours(household: Household) -> void:
	household.long_days = false
	if household.labor_capacity <= 0 or household.assigned_workers <= 0:
		return
	var work: ConstructionProject = null
	var own: bool = false
	for project: ConstructionProject in get_projects_of(household):
		if city.construction.can_progress(project):
			work = project
			own = true
			break
	if work == null and household.helping_project_id >= 0:
		work = city.construction.get_project(household.helping_project_id)
	if work == null:
		household.hours_note = ""
		return
	var desire: Dictionary = SocialDecisions.get_hours_desire(city, household, work, own)
	var score: float = float(desire["score"]) + FamilyInitiative.get_noise(city, household, "hours")
	household.long_days = score >= LONG_DAYS_THRESHOLD
	if household.long_days:
		household.long_weeks_this_month += 1
		long_day_weeks += 1
		household.hours_note = "Works long days (%s)" % "; ".join(FamilyInitiative.get_reasons(desire["terms"], true))
		if CommunityPriority.is_swayed(score, float(desire.get("appeal", 0.0)), LONG_DAYS_THRESHOLD):
			CommunityPriority.record_swayed(city, household, "long_days", "It worked long days on a home because the gathering put homes first")
	else:
		household.hours_note = "Keeps its usual hours (%s)" % "; ".join(FamilyInitiative.get_reasons(desire["terms"], false))

# --- Communal work ---------------------------------------------------------------------------------

# TownConstruction calls this for every day a family works on a site as a builder; spare-time help
# comes through record_help_day. Only communal work is tracked, for the town's shared success.
func record_contribution(household: Household, project: ConstructionProject) -> void:
	if not enabled or not is_communal(project):
		return
	var key: String = str(project.id)
	if not communal_contributors.has(key):
		communal_contributors[key] = []
	var ids: Array = communal_contributors[key]
	if not ids.has(household.id):
		ids.append(household.id)

# A communal project is finished: a shared success. The families who built it gain confidence in
# what the town does together; others gain some if they prize working together or heed the
# gathering; those who hold that families should look to themselves are unmoved.
func on_project_finished(project: ConstructionProject) -> void:
	if not enabled or not is_communal(project):
		return
	var builders: Array = communal_contributors.get(str(project.id), [])
	communal_contributors.erase(str(project.id))
	var what: String = TownConstruction.get_display_name(project).to_lower()
	for household: Household in city.households:
		var built_it: bool = builders.has(household.id)
		var regard: int = HouseholdCharacter.get_strength(household, "communal_labor") + HouseholdCharacter.get_strength(household, "deferential") - HouseholdCharacter.get_strength(household, "self_governing") - HouseholdCharacter.get_strength(household, "solitary")
		if built_it:
			adjust_trust(household, 0.5 if regard >= 0 else 0.25, "shared work finished")
			# A building is remembered; a stretch of road is too ordinary to change what a family values.
			if project.kind != ConstructionProject.KIND_ROAD:
				HouseholdMemory.experience(city, household, "built_together", "It helped build the town's %s" % what, null, {})
		elif regard >= 2:
			adjust_trust(household, 0.25, "shared work finished")

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

# Roads, stores, the watch, and homes built ahead for families still to come (no family claims
# them yet) are the community's, whoever builds them; anything else is the project of the family it
# is built for.
static func is_communal(project: ConstructionProject) -> bool:
	if project.is_home() and project.claimant_household_id < 0:
		return true
	return project.kind == ConstructionProject.KIND_ROAD or project.building_type in [Building.BUILDING_STOREHOUSE, Building.BUILDING_WATCH_POST]

func get_project_owner(project: ConstructionProject) -> Household:
	return null if is_communal(project) else find(project.claimant_household_id)

# TownConstruction calls this for every day a household gives spare time to someone else's project.
func record_help_day(helper: Household, project: ConstructionProject) -> void:
	var owner: Household = get_project_owner(project)
	if not enabled or owner == helper:
		return
	record_contribution(helper, project)
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
		kin_help_weeks += 1 if HouseholdMemory.is_kin(helper, recipient) else 0
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
			# Help that came because the gathering asked for it, or rewards it, is the gathering's
			# answer to the hardship, as the family helped sees it.
			if bool(norms[NORM_HELP]["promoted"]) or incentive:
				adjust_trust(recipient, 0.5, "hardship answered")
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
	crosser.civic_acts += 1
	judge_settlement([victim, crosser] as Array[Household])
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

# --- Contested land --------------------------------------------------------------------------------

# A household wants land another holds or has just claimed (FamilyInitiative.contest_for_land finds
# the stake, and moves the land if the holder yields). The claimant decides whether to ask at all;
# the holder whether to make room, for the claimant's labor in return; refused, the claimant accepts
# the prior claim or holds a grievance. Returns "not pressed", "yielded", or "kept". The same pair
# does not contest again while the matter rests.
func contest_land(claimant: Household, holder: Household, stake: Dictionary) -> String:
	if is_resting(holder.id, claimant.id) or is_resting(claimant.id, holder.id):
		return "not pressed"
	land_contests += 1
	var dispute: Dictionary = {"victim": holder.id, "crosser": claimant.id, "field": -1, "day": city.construction.day, "settled": true, "count": 1, "kind": str(stake.get("kind", CONTEST_SAME_FIELD))}
	disputes.append(dispute)
	var label: String = city.get_household_label(holder.id)
	var asker: String = city.get_household_label(claimant.id)
	var what: String = str(stake.get("what", "land"))
	var press: Dictionary = SocialDecisions.get_press_desire(city, claimant, holder, stake)
	if float(press["score"]) + FamilyInitiative.get_noise(city, claimant, "press:%d" % holder.id) < SocialDecisions.RAISE_THRESHOLD:
		land_not_pressed += 1
		note(claimant, "Leaves %s's claim to its %s be (%s)" % [label, what, "; ".join(FamilyInitiative.get_reasons(press["terms"], false))])
		observe_norm(NORM_CLAIMS, true)
		return "not pressed"
	note(claimant, "Asks %s for its %s (%s)" % [label, what, "; ".join(FamilyInitiative.get_reasons(press["terms"], true))])
	var give: Dictionary = SocialDecisions.get_yield_desire(city, holder, claimant, stake)
	if float(give["score"]) + FamilyInitiative.get_noise(city, holder, "yield:%d" % claimant.id) >= SocialDecisions.AMENDS_THRESHOLD:
		land_yielded += 1
		HouseholdMemory.touch_tie(city, claimant, holder, 1, "made room for us", 2)
		HouseholdMemory.touch_tie(city, holder, claimant, 0, "we made room for them", -2)
		holder.civic_acts += 1
		adjust_standing(holder, 0.5)
		note(holder, "Made room for %s on its %s (%s)" % [asker, what, "; ".join(FamilyInitiative.get_reasons(give["terms"], true))])
		HouseholdMemory.experience(city, holder, "land_yielded", "It gave up its %s to %s" % [what, asker], claimant, {"cost": 1.0})
		HouseholdMemory.experience(city, claimant, "land_given", "%s made room for it on its %s" % [label, what], holder, {"benefit": 1, "voluntary": true})
		judge_settlement([holder, claimant] as Array[Household])
		observe_norm(NORM_CLAIMS, true)
		return "yielded"
	land_kept += 1
	note(holder, "Keeps its %s from %s (%s)" % [what, asker, "; ".join(FamilyInitiative.get_reasons(give["terms"], false))])
	HouseholdMemory.experience(city, holder, "land_kept", "%s asked for its %s" % [asker, what], claimant, {})
	# Refused, the claimant accepts that the claim came first, unless it neither respects claims nor
	# lives where respecting them is expected, and is forceful enough to hold a grievance.
	var accepts: bool = HouseholdCharacter.get_strength(claimant, "respect_for_holdings") > 0 or str(norms[NORM_CLAIMS]["status"]) != STATUS_NONE or HouseholdCharacter.get_axis(claimant, HouseholdCharacter.ASSERTIVENESS) <= 0
	if accepts:
		HouseholdMemory.experience(city, claimant, "land_refused", "%s kept its %s" % [label, what], holder, {"accepted": true})
		observe_norm(NORM_CLAIMS, true)
		return "kept"
	dispute["settled"] = false
	dispute_pressure += 1
	HouseholdMemory.touch_tie(city, claimant, holder, -2, "would not make room for us", 0, "would not make room for us")
	HouseholdMemory.touch_tie(city, holder, claimant, -1, "wanted the land we hold")
	# Pressing against a claim where claims are expected to be respected costs standing.
	if float(norms[NORM_CLAIMS]["acceptance"]) >= 0.5 or bool(norms[NORM_CLAIMS]["promoted"]):
		adjust_standing(claimant, -0.5)
		norms[NORM_CLAIMS]["sanctions"] = int(norms[NORM_CLAIMS]["sanctions"]) + 1
	note(claimant, "Resents %s for keeping its %s" % [label, what])
	HouseholdMemory.experience(city, claimant, "land_refused", "%s would not make room for it" % label, holder, {"accepted": false, "major": bool(stake.get("nowhere_else", false))})
	observe_norm(NORM_CLAIMS, false)
	return "kept"

# The gathering asks a family to give up land it has claimed for its work, so the town can build
# something of its own there (a communal designation over a household's claim). The family decides
# (SocialDecisions.get_yield_to_community_desire), and is offered first claim on the stores for new
# work. If it refuses and the gathering requires it (`require`), the land is taken anyway: an
# arbitrary requirement to the family, and to every family that holds claims dear. Returns
# "yielded", "refused", or "taken", and the project built in its place in `result["project"]`.
#
# Only claims not yet built on can be given up: the town has no way to clear a standing workplace.
func ask_for_land(claim: ConstructionProject, communal_type: String, require: bool = false) -> Dictionary:
	var holder: Household = find(claim.claimant_household_id)
	if holder == null or claim.get_progress() > 0.0 or claim.is_home():
		return {"outcome": "", "project": null}
	land_contests += 1
	var purpose: String = BuildingTiers.get_display_name(communal_type).to_lower()
	var what: String = TownConstruction.get_display_name(claim).to_lower()
	var desire: Dictionary = SocialDecisions.get_yield_to_community_desire(city, holder, purpose)
	var willing: bool = float(desire["score"]) + FamilyInitiative.get_noise(city, holder, "community_land") >= SocialDecisions.AMENDS_THRESHOLD
	if not willing and not require:
		land_kept += 1
		note(holder, "Would not give up the land for its %s to the town's %s (%s)" % [what, purpose, "; ".join(FamilyInitiative.get_reasons(desire["terms"], false))])
		HouseholdMemory.experience(city, holder, "land_kept", "The gathering asked for the land of its %s" % what, null, {})
		# Asked, not forced: a family that holds families should decide for themselves sees its say kept.
		if HouseholdCharacter.get_strength(holder, "self_governing") > 0:
			adjust_trust(holder, 0.25, "its say respected")
		return {"outcome": "refused", "project": null}
	var tile: Vector2i = claim.tile
	city.construction.cancel(claim.id)
	var built: ConstructionProject = city.construction.request_building(communal_type, tile)
	grant_first_claim(holder, GRANT_DAYS)
	if willing:
		land_yielded += 1
		holder.civic_acts += 1
		adjust_standing(holder, 0.5)
		if HouseholdCharacter.get_strength(holder, "self_governing") == 0:
			adjust_trust(holder, 0.25, "asked fairly")
		note(holder, "Gave the land for its %s to the town's %s (%s)" % [what, purpose, "; ".join(FamilyInitiative.get_reasons(desire["terms"], true))])
		HouseholdMemory.experience(city, holder, "land_given_to_town", "It gave the land for its %s to the town" % what, null, {"cost": 1.0})
		observe_norm(NORM_CLAIMS, true)
		return {"outcome": "yielded", "project": built}
	land_taken += 1
	adjust_trust(holder, -1.5, "arbitrary requirement")
	note(holder, "The gathering took the land for its %s (%s)" % [what, "; ".join(FamilyInitiative.get_reasons(desire["terms"], false))])
	HouseholdMemory.experience(city, holder, "land_taken", "The gathering took the land of its %s" % what, null, {"major": true})
	# The other families judge the requirement by their own convictions.
	for observer: Household in city.households:
		if observer == holder:
			continue
		var regard: int = HouseholdCharacter.get_strength(observer, "private_holdings") + HouseholdCharacter.get_strength(observer, "landholding") + HouseholdCharacter.get_strength(observer, "respect_for_holdings") + HouseholdCharacter.get_strength(observer, "self_governing") - HouseholdCharacter.get_strength(observer, "deferential") - HouseholdCharacter.get_strength(observer, "common_stores")
		if regard >= 1:
			adjust_trust(observer, -0.25 * mini(2, regard), "arbitrary requirement")
	observe_norm(NORM_CLAIMS, false)
	return {"outcome": "taken", "project": built}

# --- The player's levers ---------------------------------------------------------------------------

func set_promoted(norm_id: String, on: bool) -> void:
	norms[norm_id]["promoted"] = on

# The gathering publicly honours a household for one kind of contribution (RECOGNITIONS). Its
# standing rises, and every other household judges the honour by its own lights
# (judge_recognition): deserved or not, worth honouring or not, its own work overlooked or not.
func recognize(target: Household, category: String = RECOGNITION_SERVICE) -> void:
	target.recognized += 1
	adjust_standing(target, 1.0)
	var what: String = RECOGNITION_NAMES[category]
	if HouseholdCharacter.get_axis(target, HouseholdCharacter.SOCIABILITY) > -2 and HouseholdCharacter.get_axis(target, HouseholdCharacter.AMBITION) >= 0:
		adjust_trust(target, 0.5, "honoured")
	HouseholdMemory.experience(city, target, "honoured", "The gathering honoured it for its %s" % what, null, {"benefit": 1, "category": category})
	var middle: float = get_middle_merit(category)
	var prosperous: bool = is_prosperous(target)
	var serves: bool = serves_town(target, category)
	var text: String = "The gathering honoured %s for its %s" % [city.get_household_label(target.id), what]
	var readings: Dictionary = {}
	for observer: Household in city.households:
		if observer != target:
			var judged: Dictionary = judge_recognition(observer, target, category, middle, prosperous, serves, text)
			readings[judged["reading"]] = true
	honours += 1
	honour_readings += readings.size()

# One household's judgment of an honour: {"score", "terms"} like any decision, then its
# consequences. Deserved, it trusts the gathering a little more, and an ambitious household that
# prizes this kind of work wants to match it; undeserved, it trusts the gathering less, and may
# resent the honoured family.
func judge_recognition(observer: Household, target: Household, category: String, middle: float, prosperous: bool, serves: bool, text: String) -> Dictionary:
	var terms: Array = []
	var s: Callable = func(value_id: String) -> int: return HouseholdCharacter.get_strength(observer, value_id)
	var merit: float = get_merit(target, category)
	var deserved: bool = merit >= maxf(1.0, middle)
	FamilyInitiative.add(terms, 1.0 if deserved else -1.0, "they did much of it" if deserved else "they did little to earn it")
	if not deserved and s.call("egalitarian") > 0:
		FamilyInitiative.add(terms, -0.25 * s.call("egalitarian"), "honour should follow what families do")
	# What a household prizes, honoured where it was earned, pleases it; honoured where it was not,
	# it is cheapened.
	var esteem: float = get_esteem(observer, category)
	if deserved and absf(esteem) >= 0.5:
		FamilyInitiative.add(terms, 0.5 * esteem, ("it prizes " if esteem > 0.0 else "it thinks little of ") + str(RECOGNITION_NAMES[category]))
	elif not deserved and esteem >= 0.5:
		FamilyInitiative.add(terms, -0.25 * esteem, "an unearned honour cheapens " + str(RECOGNITION_NAMES[category]))
	if target.recognized + target.grants_received > 2:
		FamilyInitiative.add(terms, -1.5, "the same family is favoured again and again")
	var prized: String = get_prized(observer)
	var overlooked: float = get_merit(observer, prized) - (merit if prized == category else 1.0)
	if overlooked >= 2.0:
		FamilyInitiative.add(terms, -1.0 - 0.25 * maxi(0, HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION)), "its own %s went unrecognised" % RECOGNITION_NAMES[prized])
	if category == RECOGNITION_ACHIEVEMENT and prosperous:
		var levelling: float = s.call("egalitarian") + 0.5 * s.call("communal_labor") + 0.5 * s.call("sharing")
		if levelling >= 1.0:
			FamilyInitiative.add(terms, -minf(1.5, 0.5 * levelling), "they were already prosperous")
	if category in [RECOGNITION_ACHIEVEMENT, RECOGNITION_CRAFT] and get_esteem(observer, RECOGNITION_SERVICE) >= 1.0:
		FamilyInitiative.add(terms, 0.5 if serves else -0.75, "their work serves the town" if serves else "their success serves only themselves")
	if deserved and s.call("hierarchical") > 0:
		FamilyInitiative.add(terms, 0.25 * s.call("hierarchical"), "honour belongs to the accomplished")
	if s.call("egalitarian") > 0 and target.standing >= VOICE_STANDING:
		FamilyInitiative.add(terms, -0.25 * s.call("egalitarian"), "honours pile on the already regarded")
	if HouseholdMemory.is_kin(observer, target):
		FamilyInitiative.add(terms, 0.5, "they are kin")
	var disposition: int = HouseholdMemory.get_disposition(observer, target.id) - (HouseholdMemory.KIN_START_DISPOSITION if HouseholdMemory.is_kin(observer, target) else 0)
	if disposition != 0:
		FamilyInitiative.add(terms, 0.3 * disposition, "they are on good terms" if disposition > 0 else "they are on bad terms")
	var score: float = FamilyInitiative.sum(terms)
	var label: String = city.get_household_label(target.id)
	if score >= HONOUR_FAIR_AT:
		adjust_trust(observer, 0.25, "deserved recognition")
		HouseholdMemory.experience(city, observer, "honour_fair", text, target, {"fair": 1, "category": category})
		if HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION) > 0 and esteem > 0.0:
			observer.inspired_by = category
			observer.inspired_by_household = target.id
			observer.inspired_until = city.construction.day + HONOUR_PRESTIGE_DAYS
		note(observer, "Thinks %s's honour deserved (%s)" % [label, "; ".join(FamilyInitiative.get_reasons(terms, true))])
	elif score <= HONOUR_UNFAIR_AT:
		if score <= HONOUR_RESENT_AT:
			adjust_trust(observer, -1.0, "undeserved recognition")
			HouseholdMemory.touch_tie(city, observer, target, -1, "was favoured over us")
			note(observer, "Resents the favour shown to %s (%s)" % [label, "; ".join(FamilyInitiative.get_reasons(terms, false))])
		else:
			adjust_trust(observer, -0.25, "undeserved recognition")
			note(observer, "Doubts %s's honour was deserved (%s)" % [label, "; ".join(FamilyInitiative.get_reasons(terms, false))])
		HouseholdMemory.experience(city, observer, "honour_unfair", text, target, {"fair": -1, "overlooked": maxf(0.0, overlooked), "category": category, "prosperous": prosperous})
	# How it read the honour, in short: its verdict and the strongest reason for it.
	var verdict: String = "deserved" if score >= HONOUR_FAIR_AT else "undeserved" if score <= HONOUR_UNFAIR_AT else "indifferent"
	var why: Array[String] = FamilyInitiative.get_reasons(terms, score >= 0.0, 1)
	return {"score": score, "terms": terms, "reading": verdict + (": " + why[0] if verdict != "indifferent" and not why.is_empty() else "")}

# What a household did of one kind of contribution, for judging an honour.
# Service: weeks it helped others build and times it shared food. Achievement: a proper holding,
# improved by its own decision, well kept. Craft: work of its calling, well kept, by a method no
# other family here uses yet. Civic: amends made, land given up, claims settled by agreement.
func get_merit(household: Household, category: String) -> float:
	match category:
		RECOGNITION_SERVICE:
			return float(household.help_given)
		RECOGNITION_CIVIC:
			return float(household.civic_acts)
	var holding: Building = FamilyInitiative.get_holding(city, household)
	if holding == null:
		return 0.0
	var proper: bool = not holding.is_tier0()
	var kept: bool = holding.needs_maintenance() and holding.maintenance_level >= 50
	var merit: float = 0.0
	if category == RECOGNITION_ACHIEVEMENT:
		merit += 1.0 if proper else 0.0
		merit += 1.0 if household.improve_decision_day >= 0 else 0.0
		merit += 1.0 if kept else 0.0
	else:
		merit += 1.0 if household.get_match_quality(holding.type) == CultureEffects.MATCH_GOOD else 0.0
		merit += 1.0 if proper and kept else 0.0
		merit += 1.0 if proper and FamilyInitiative.count_proper(city, holding.type) == 1 else 0.0
	return merit

func get_middle_merit(category: String) -> float:
	var merits: Array[float] = []
	for household: Household in city.households:
		merits.append(get_merit(household, category))
	merits.sort()
	return merits[merits.size() / 2] if not merits.is_empty() else 0.0

# How much a household prizes a kind of contribution, -2 to 3: what it values and its temperament.
static func get_esteem(household: Household, category: String) -> float:
	var s: Callable = func(value_id: String) -> float: return float(HouseholdCharacter.get_strength(household, value_id))
	var a: Callable = func(axis: String) -> float: return float(HouseholdCharacter.get_axis(household, axis))
	var esteem: float = 0.0
	match category:
		RECOGNITION_SERVICE:
			esteem = s.call("communal_labor") + s.call("mutual_aid") + s.call("charitable") + 0.5 * s.call("sharing") + 0.5 * maxf(0.0, a.call(HouseholdCharacter.EMPATHY)) - s.call("each_to_their_own") - 0.5 * s.call("solitary")
		RECOGNITION_ACHIEVEMENT:
			esteem = 0.5 * a.call(HouseholdCharacter.DILIGENCE) + 0.5 * a.call(HouseholdCharacter.AMBITION) + s.call("private_holdings") + 0.5 * s.call("landholding") + 0.5 * s.call("acquisitive") + 0.5 * s.call("hierarchical") - 0.5 * s.call("egalitarian") - 0.5 * s.call("common_stores")
		RECOGNITION_CRAFT:
			esteem = s.call("perfectionist") + s.call("keepers_of_craft") + 0.5 * s.call("hands_on") + 0.5 * s.call("curious") + 0.5 * a.call(HouseholdCharacter.OPENNESS) + 0.5 * a.call(HouseholdCharacter.DILIGENCE) - 0.5 * s.call("expedient")
		RECOGNITION_CIVIC:
			esteem = s.call("negotiation") + s.call("lawful") + 0.5 * s.call("forgiveness") + 0.5 * s.call("respect_for_holdings") + 0.5 * s.call("deferential") + 0.5 * s.call("honesty") - 0.5 * s.call("free_spirited") - 0.5 * s.call("vindication")
	return clampf(esteem, -2.0, 3.0)

# The kind of contribution a household prizes most (service when it prizes none above the rest).
static func get_prized(household: Household) -> String:
	var prized: String = RECOGNITION_SERVICE
	for category: String in RECOGNITIONS:
		if get_esteem(household, category) > get_esteem(household, prized):
			prized = category
	return prized

# Already well off: housed, on a proper holding of its own.
func is_prosperous(household: Household) -> bool:
	var holding: Building = FamilyInitiative.get_holding(city, household)
	return holding != null and not holding.is_tier0() and household.housing_status == Household.RESIDENCE_HOUSED and not city.is_household_in_rough_housing(household)

# Whether a household's own achievement benefits the town: its work supplies what the town is
# short of, or what no one else here supplies. Service and civic work always serve others.
func serves_town(household: Household, category: String) -> bool:
	if category == RECOGNITION_SERVICE or category == RECOGNITION_CIVIC:
		return true
	var holding: Building = FamilyInitiative.get_holding(city, household)
	if holding == null:
		return false
	var activity: String = FamilyInitiative.get_activity(holding.type)
	return activity != "" and (FamilyInitiative.get_waiting_risk(city, activity) > 0.0 or FamilyInitiative.count_producers(city, activity) == 1)

# Gives a household first claim on the stores for its own projects for a while: a distribution of
# the town's common stores, judged for fairness (judge_distribution).
func grant(target: Household) -> void:
	target.grants_received += 1
	grant_first_claim(target, GRANT_DAYS)
	judge_distribution(target, "The gathering gave %s first claim on the stores" % city.get_household_label(target.id))

func grant_first_claim(household: Household, days: int) -> void:
	household.first_claim_until = maxi(household.first_claim_until, city.construction.day + days)

# Each household weighs whether a share of the stores was fair: by what the family favoured gave
# others (help given, food shared) against the town's middle and its own, and how often the same
# family is favoured. Given to a family in hardship, it is a response to need, and those who are
# moved by others' need see it as right.
func judge_distribution(target: Household, text: String) -> void:
	var contributions: Array[int] = []
	for household: Household in city.households:
		contributions.append(household.help_given)
	contributions.sort()
	var middle: int = contributions[contributions.size() / 2] if not contributions.is_empty() else 0
	var in_need: bool = is_in_need(city, target)
	for observer: Household in city.households:
		if observer == target:
			continue
		var overlooked: int = observer.help_given - target.help_given
		# Favouring the same household again and again is favouritism, whatever it has done.
		var favoured: bool = target.recognized + target.grants_received > 2
		var moved_by_need: bool = in_need and (HouseholdCharacter.get_axis(observer, HouseholdCharacter.EMPATHY) > 0 or HouseholdCharacter.get_strength(observer, "charitable") > 0)
		var deserved: bool = (moved_by_need or (target.help_given >= middle and overlooked < 2)) and not favoured and observer.grants_received >= target.grants_received - 1
		if deserved:
			if moved_by_need:
				adjust_trust(observer, 0.25, "hardship answered")
			continue
		var resentment: float = 1.0 + HouseholdCharacter.get_strength(observer, "egalitarian") + 0.5 * maxi(0, HouseholdCharacter.get_axis(observer, HouseholdCharacter.AMBITION)) + (0.5 if overlooked >= 2 else 0.0) - HouseholdCharacter.get_strength(observer, "hierarchical") - 0.5 * HouseholdCharacter.get_strength(observer, "deferential")
		var said: String = text
		if observer.grants_received > 0:
			said = "It accepted the gathering's help, but %s got more" % city.get_household_label(target.id)
		if resentment >= 1.5:
			adjust_trust(observer, -1.0, "favouritism")
			HouseholdMemory.touch_tie(city, observer, target, -1, "was favoured over us")
			note(observer, "Resents the favour shown to %s" % city.get_household_label(target.id))
		else:
			adjust_trust(observer, -0.25, "favouritism")
		HouseholdMemory.experience(city, observer, "share_unfair", said, target, {"fair": -1, "overlooked": maxf(0.0, float(overlooked))})

# The stores rule held back a household's own project (TownInfluence). Once a month at most, a
# household that is not secure takes it as the stores being closed to families like it.
func on_held_back(household: Household) -> void:
	if not enabled:
		return
	var key: String = str(household.id)
	if city.construction.day - int(held_back_days.get(key, -60)) < 30:
		return
	held_back_days[key] = city.construction.day
	# First claim was promised to it, and the stores still would not fund it: a promise broken.
	if household.first_claim_until >= city.construction.day:
		adjust_trust(household, -0.75, "promise broken")
	elif get_security_margin(household) <= 4:
		adjust_trust(household, -0.5, "held back in hardship")

# First claim on the stores let a household's project through: a promise kept.
func on_first_claim_used(household: Household) -> void:
	if enabled:
		adjust_trust(household, 0.5, "promise kept")

# --- The gathering ---------------------------------------------------------------------------------

# Before there are institutions, the town decides through informal gatherings of its households, each
# one voice (owner decision). Some voices come to carry more weight because others regard them: the
# households of highest standing, earned by what they did (helping, sharing, honours), never
# granted. Their weight shows in how appeals are received (FamilyInitiative.get_receptiveness).
func get_respected_voices() -> Array[Household]:
	var voices: Array[Household] = []
	for household: Household in city.households:
		if household.standing >= VOICE_STANDING:
			voices.append(household)
	voices.sort_custom(func(a: Household, b: Household) -> bool: return a.standing > b.standing or (a.standing == b.standing and a.id < b.id))
	return voices.slice(0, MAX_VOICES)

# Notes, once a week, whether the gathering changed what it asks for or how it shares the stores.
func record_policy() -> void:
	var promoted: Array = []
	for norm_id: String in [NORM_HELP, NORM_CLAIMS]:
		promoted.append(bool(norms[norm_id]["promoted"]))
	var encouraged: Array = city.influence.encouraged.duplicate()
	encouraged.sort()
	var signature: Array = [city.influence.priority, encouraged, city.influence.store_rule, promoted, incentive]
	if not policy_signature.is_empty() and signature != policy_signature:
		policy_change_days.append(city.construction.day)
	policy_signature = signature
	while not policy_change_days.is_empty() and city.construction.day - int(policy_change_days[0]) > POLICY_WINDOW_DAYS:
		policy_change_days.pop_front()

func get_recent_policy_changes() -> int:
	return policy_change_days.filter(func(day: int) -> bool: return city.construction.day - day <= POLICY_WINDOW_DAYS).size()

# Once a month, each household weighs how the gathering has been deciding: steadily, or changing its
# mind. A family that values order, tradition, or caution cares most; one that welcomes new ways
# minds changes little. Steadiness counts only once the gathering has made some decision to keep.
func review_month() -> void:
	if not enabled:
		return
	var changes: int = get_recent_policy_changes()
	var decided: bool = city.influence.priority != "" or not city.influence.encouraged.is_empty() or city.influence.store_rule != TownInfluence.RULE_OPEN or incentive or bool(norms[NORM_HELP]["promoted"]) or bool(norms[NORM_CLAIMS]["promoted"])
	for household: Household in city.households:
		var order: int = get_order_regard(household)
		if changes >= MANY_CHANGES:
			adjust_trust(household, -0.25 * maxi(1, order), "decisions keep changing")
		# Predictability earns confidence, not devotion: it lifts trust no higher than mild, and not
		# for a family the steady policy itself has been holding back.
		elif changes == 0 and decided and order >= 1 and household.trust < 1 and city.construction.day - int(held_back_days.get(str(household.id), -1000)) > 60:
			adjust_trust(household, 0.05 * order, "steady decisions")

# How much a household cares that decisions are predictable and follow known rules.
static func get_order_regard(household: Household) -> int:
	var regard: int = HouseholdCharacter.get_strength(household, "lawful") + HouseholdCharacter.get_strength(household, "traditionalist") + HouseholdCharacter.get_strength(household, "steady")
	regard += maxi(0, -HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK))
	regard -= HouseholdCharacter.get_strength(household, "reformist") + HouseholdCharacter.get_strength(household, "free_spirited")
	return clampi(regard, 0, 3)

# Whether a household sees a settlement reached under the town's custom, or at the gathering's
# appeal, as legitimate: positive for families that value lawful order, deference, holdings, or
# talking things through; negative for those who hold that families should decide for themselves.
static func get_procedure_regard(household: Household) -> int:
	var regard: int = HouseholdCharacter.get_strength(household, "lawful") + HouseholdCharacter.get_strength(household, "deferential") + HouseholdCharacter.get_strength(household, "respect_for_holdings") + HouseholdCharacter.get_strength(household, "negotiation")
	regard -= HouseholdCharacter.get_strength(household, "self_governing") + HouseholdCharacter.get_strength(household, "free_spirited")
	return clampi(regard, -3, 3)

# A dispute settled where respecting claims is the custom or the gathering's appeal: each side
# judges whether that was a legitimate way to settle it.
func judge_settlement(parties: Array[Household]) -> void:
	var claims: Dictionary = norms[NORM_CLAIMS]
	if str(claims["status"]) != STATUS_CUSTOM and not bool(claims["promoted"]):
		return
	for household: Household in parties:
		var regard: int = get_procedure_regard(household)
		if regard >= 1:
			adjust_trust(household, 0.25 * mini(2, regard), "dispute settled fairly")
		elif regard <= -1:
			adjust_trust(household, -0.25, "settlement pressed on it")

# --- Trust, standing, norms -----------------------------------------------------------------------

func adjust_trust(household: Household, amount: float, source: String = "") -> void:
	if source != "":
		trust_by_source[source] = float(trust_by_source.get(source, 0.0)) + amount
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
		return ("build a %s for a family to come" if project.is_home() else "build the town's %s") % what
	return "%s build its %s" % [city.get_household_label(target.id), what]

func get_sidebar_lines() -> Array[String]:
	var lines: Array[String] = []
	for norm_id: String in [NORM_HELP, NORM_CLAIMS]:
		var norm: Dictionary = norms[norm_id]
		lines.append("%s: %s, %d%%" % [NORM_NAMES[norm_id], norm["status"], roundi(float(norm["acceptance"]) * 100.0)])
	var voices: Array[String] = []
	for voice: Household in get_respected_voices():
		voices.append(city.get_household_label(voice.id).replace("Household ", "H"))
	lines.append("Gathering: " + ("voices heeded " + ", ".join(voices) if not voices.is_empty() else "no family stands out yet"))
	var open: int = disputes.filter(func(d: Dictionary) -> bool: return not bool(d["settled"])).size()
	if open > 0:
		lines.append("Unsettled disputes: %d%s" % [open, " (families look for agreed rules)" if dispute_pressure >= 2 else ""])
	return lines
