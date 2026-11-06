class_name FamilyInitiative
extends RefCounted

# Families taking up and improving their own work: the family influence prototype
# (docs/FAMILY_INFLUENCE_PROTOTYPE.md). It runs only where the town's influence is enabled
# (TownInfluence.enabled). Every week, through the same construction pipeline as the player:
#
# - a family with no holding chooses work to take up (any trade with a hand-work stage: farming,
#   woodcutting, toolmaking, fishing, hunting, herding; get_occupations) and opens it near its home
#   as hand work (tier 0), which needs no materials;
# - a family on hand work considers improving it into a proper holding.
#
# Desire and ability are kept apart. Desire is a sum of terms, each with the reason it gives: the
# family's calling, temperament and values, what the town needs of the good the work makes, the
# land in reach, what its neighbours' improved work shows, and what the community encourages.
# Every trade is weighed by the same terms, by the good it makes rather than by its name, so a new
# trade needs a hand-work stage (BuildingTiers) and no decision path of its own. Ability is the land,
# the family's own hands (hand work needs no materials), and the stores under the community's rule
# (TownInfluence), which always keeps protected reserves. A family can want something it cannot
# do, and says so.
#
# A small, bounded unknown (NOISE) is added to each decision: a family the player is told is on the
# fence may go either way, while one clearly for or against does what the player was told.

const INTERVAL_DAYS: int = 7
const MAX_PROJECTS_PER_PASS: int = 3
# The goods the community's asks and the wisdoms speak of (TownInfluence, GuidingWisdom).
const ACTIVITIES: Array[String] = [TownInfluence.ACTIVITY_FOOD, TownInfluence.ACTIVITY_WOOD, TownInfluence.ACTIVITY_TOOLS]
# The first three trades, by the good each makes. Their decisions keep these names (get_choice_key),
# so the unknown in them is what it was before other trades could be chosen; the comparison can
# leave families only these (meta "occupations_first_three").
const PROPER_WORK: Dictionary = {"food": "farm", "wood": "woodcutter", "tools": "toolmaker"}

# Seeing an essential shortage coming (get_shortage): how far ahead a family looks, and how much the
# danger weighs, at its worst, in choosing work.
const SHORTAGE_HORIZON_DAYS: int = 90
const SHORTAGE_WEIGHT: float = 4.0
# Land in reach (TownLand) for work that lives off it: a family weighs what the work would yield
# where it would stand against the best any work yields of the same good (get_yield_term), at this
# weight for each share it falls short; and (choose_site) how many tiles of walk a full yield is
# worth against an empty one. Good land makes such work as good as the best, never better: it only
# deters where the land is poor or the work yields less by nature.
const LAND_WEIGHT: float = 3.0
const LAND_SITE_TILES: float = 8.0
const LAND_REASONS: Dictionary = {"water": "little water in reach to fish", "woods": "little game in reach", "pasture": "little pasture in reach", "timber": "the trees it could fell are far off or few", "stone": "little good stone underfoot", "clay": "little good clay underfoot"}
# A good the town only goes without (wool, for clothing; goods to come) pulls less than what it
# lives on (the food, wood and tools terms of get_work_desire, 1.5 to 3 each): no one making it,
# the need it meets going unmet, and each other family already making it.
const COMFORT_NONE_WEIGHT: float = 0.5
const COMFORT_UNMET_WEIGHT: float = 1.0
const COMFORT_OTHERS_WEIGHT: float = 1.5
# Building planned that waits for a good no one has enough of (stone, sprint S4c), at its most.
const BUILDING_WAITS_WEIGHT: float = 1.5
# A good with no use in the town (no need, no building waiting, no workshop using it) and this much
# already in store: more of it is work for nothing (sprint S4 review). Enough stone or bricks for
# a few homes stays wanted, so families can choose to build of it.
const NO_USE_STOCK: int = 30
const NO_USE_WEIGHT: float = 3.0
# Wood in store beyond what the town will burn and use through the coming winter (sprint S5b,
# get_wood_plenty): at its most, as much against wood work as a pile no one uses. Where little is
# needed, this much spare counts as full plenty.
const WOOD_PLENTY_WEIGHT: float = 3.0
const WOOD_PLENTY_FLOOR: float = 100.0
# A family wanting a better home of a material it would make itself (owner 2026-11-03).
const OWN_DEMAND_WEIGHT: float = 1.5
# New deposit trades (stone, brick) while the town holds less than SECURE_FOOD_DAYS of food in store
# and coming: at worst this much against, times how survival-minded the family is (owner 2026-11-03).
const FOOD_INSECURITY_WEIGHT: float = 2.0
# Survival before prosperity (owner, 2026-11-01; get_hardship): how far ahead a family looks at the
# town's food, how much the danger of hunger weighs for food work at its worst (scaled by what that
# work would really bring in here), and how much of its calling's pull a family sets aside at the
# worst of it. Cautious families weigh hunger more, daring and ambitious ones less; a family
# already going hungry weighs its own hunger fully whatever its temperament.
const SURVIVAL_HORIZON_DAYS: int = 120
const SURVIVAL_WEIGHT: float = 4.0
const CALLING_YIELD: float = 0.5
const HUNGRY_DAYS_DESPERATE: float = 10.0
# A town growing less food than it eats is in danger however full its store: at half what it eats,
# as much as a town with nothing coming (get_hardship).
const DEFICIT_WEIGHT: float = 2.0

# A family improves its work when its desire reaches this.
const IMPROVE_THRESHOLD: float = 2.0
# The most the unknown can move a decision. It stays below the width of the "uncertain" band in
# predict(), so a family predicted likely or opposed always does what was predicted.
const NOISE: float = 0.75
const ENCOURAGE_WEIGHT: float = 2.0
const SECURE_FOOD_DAYS: float = 180.0
# Wood is at risk when the store holds less than the hearths will burn over this many days (TownFuel).
const FUEL_RISK_DAYS: int = 90
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
	var short: Array[String] = []
	for activity: String in ACTIVITIES:
		if GuidingWisdom.is_short_of(city, activity):
			short.append(activity)
	var choices: Array[Dictionary] = []
	for occupation: String in get_occupations(city):
		if is_vetoed(city, household, occupation):
			continue
		var desire: Dictionary = get_work_desire(city, household, occupation)
		if not bool(desire["available"]):
			continue
		desire["occupation"] = occupation
		desire["score"] = float(desire["score"]) + get_noise(city, household, get_choice_key(occupation))
		choices.append(desire)
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	if is_comfort_calling_faded(city) and not choices.is_empty():
		count_fade_changed(city, household, "first_choice", choices[0]["occupation"], get_unfaded_best(choices))
	if city.has_meta("trace_choices"):
		record_choices(city, household, choices)
	if city.social.enabled and not choices.is_empty() and contest_for_land(city, household, choices):
		return null
	# Every workplace starts as hand work; improving it is a decision of its own, later.
	for choice: Dictionary in choices:
		var building_type: String = BuildingTiers.get_hand_work_type(choice["occupation"])
		var site: Vector2i = choice["site"] if choice.has("site") else choose_site(city, household, building_type)
		if site.x < 0:
			# Its first choice has no free land: something the player can see and answer.
			if choice == choices[0]:
				note_blocked(city, household, building_type)
			continue
		var project: ConstructionProject = city.construction.request_building(building_type, site, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, household.id)
		if project == null:
			continue
		city.influence.workplaces_opened += 1
		# Tipped by a focused appeal: without it, another choice would have come first.
		if float(choice.get("focused", 0.0)) > 0.0 and choices.size() > 1 and choice == choices[0] and float(choice["score"]) - float(choice["focused"]) < float(choices[1]["score"]):
			city.influence.appeals_tipped += 1
		if not short.is_empty():
			GuidingWisdom.record(city, household, GuidingWisdom.PREPARE, short.has(get_activity(choice["occupation"])))
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
	var occupation: String = choices[0]["occupation"]
	var building_type: String = BuildingTiers.get_hand_work_type(occupation)
	var free: Vector2i = choose_site(city, household, building_type)
	var nowhere_else: bool = free.x < 0 and choices.all(func(c: Dictionary) -> bool: return choose_site(city, household, BuildingTiers.get_hand_work_type(c["occupation"])).x < 0)
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
		if worked != null and worked.is_tier0() and BuildingTiers.get_base_type(worked.type) == occupation:
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

# How much a family wants to take up a trade (a proper workplace type, get_occupations):
# {"score", "terms", "appeal", "available", "site"} (appeal: the priority's ask). Work that lives off
# the land is "available" only where a site for it can be found, and "site" is where the family
# would open it. `own`: the workplace the family already works, left out of the producers it
# counts and judged by its own land (OccupationReview weighs staying at it).
static func get_work_desire(city: City, household: Household, occupation: String, own: Building = null) -> Dictionary:
	var terms: Array = []
	var result: Dictionary = {"available": true}
	var activity: String = get_activity(occupation)
	# Hardship: a calling is what a family pursues when it can; as hunger nears, it matters less.
	var hardship: Dictionary = get_hardship(city, household)
	var hunger: float = float(hardship["level"])
	# Cold is a danger to survival too (TownFuel; sprint S3 review): a calling and what the town only
	# goes without yield to whichever danger is greater.
	var cold: Dictionary = get_cold_hardship(city, household)
	var level: float = maxf(hunger, float(cold["level"]))
	var prosperity: float = 1.0 - CALLING_YIELD * level
	var hard_times: String = ", though survival comes first now" if level >= 0.3 else ""
	var essential: bool = activity in [TownInfluence.ACTIVITY_FOOD, TownInfluence.ACTIVITY_WOOD, TownInfluence.ACTIVITY_TOOLS]
	var match_quality: String = household.get_match_quality(occupation)
	if match_quality == CultureEffects.MATCH_GOOD:
		# For work making what the town only goes without (wool), the calling yields to hunger fully,
		# as that good's own need terms do (owner, 2026-11-02; is_comfort_calling_faded). Food, wood and
		# tools keep half the calling's pull. "calling_faded" is what fading took away, so its effect on
		# decisions can be counted.
		var pull: float = prosperity
		if is_comfort_calling_faded(city) and not essential:
			pull = 1.0 - level
			result["calling_faded"] = 3.0 * (prosperity - pull)
		add(terms, 3.0 * pull, "it is the family's calling" + hard_times)
	elif match_quality == CultureEffects.MATCH_POOR:
		add(terms, -2.0 * prosperity, "it is not the family's calling")
	var cautious: bool = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK) < 0
	match activity:
		TownInfluence.ACTIVITY_FOOD:
			var ratio: float = get_food_ratio(city)
			var weight: float = 1.0 + 0.25 * maxi(0, -HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK))
			if weighs_food_ahead(city):
				# One view of the town's food (get_hardship): hunger near, or a town growing less than
				# it eats, is weighed below as survival and not again here; here only how comfortably
				# the town is fed, by what it grows and what it holds for the coming months.
				var coverage: float = get_food_coverage(city)
				if ratio >= 1.0 and coverage >= 1.0 and (ratio < 1.25 or coverage < 1.25):
					add(terms, 1.5 * weight, "the town's food will only just last")
				elif ratio > 1.6 and coverage > 1.6:
					add(terms, -1.5, "the town has plenty of food in store and coming")
			elif ratio < 1.0:
				add(terms, 3.0 * weight, "the town grows less food than it eats" + (", and it puts food first" if cautious else ""))
			elif ratio < 1.25:
				add(terms, 1.5 * weight, "the town's food is only just enough")
			elif ratio > 1.6:
				add(terms, -1.5, "the town grows plenty of food")
		TownInfluence.ACTIVITY_WOOD:
			var producers: int = count_producers(city, activity) - (1 if own != null and get_activity(own.type) == activity else 0)
			if producers == 0:
				add(terms, 2.5, "no one cuts wood")
			elif producers >= 2:
				add(terms, -1.5 * (producers - 1), "others already cut wood")
			if int(city.resources["wood"]) < 20:
				add(terms, 1.5, "wood is short")
			var plenty: float = get_wood_plenty(city)
			if plenty > 0.0:
				add(terms, -WOOD_PLENTY_WEIGHT * plenty, WOOD_PLENTY_REASON)
		TownInfluence.ACTIVITY_TOOLS:
			var producers: int = count_producers(city, activity) - (1 if own != null and get_activity(own.type) == activity else 0)
			if producers == 0 and int(city.resources["tools"]) < 10:
				add(terms, 2.5, "tools are running out")
			elif producers == 0:
				add(terms, 1.0, "no one makes tools")
			else:
				add(terms, -2.5 * producers, "others already make tools")
		_:
			# Any other good (wool, and goods to come): whether anyone makes it, and whether the need
			# it meets goes unmet; less than what the town lives on.
			var producers: int = count_producers(city, activity) - (1 if own != null and get_activity(own.type) == activity else 0)
			var name: String = GoodsNeedBucketHelper.get_good_display_name(activity).to_lower()
			var unmet: String = get_unmet_need(city, activity)
			# What the town only goes without counts for less as hunger nears.
			var comfort: float = 1.0 - level
			if producers == 0 and comfort > 0.0:
				add(terms, COMFORT_NONE_WEIGHT * comfort, "no one makes " + name)
			elif unmet == "":
				add(terms, -COMFORT_OTHERS_WEIGHT * producers, "others already make " + name)
			if unmet != "" and comfort > 0.0:
				add(terms, COMFORT_UNMET_WEIGHT * comfort, "the town goes without " + unmet)
			# Building that waits for this good (stone for stone buildings, sprint S4c): wanted, not
			# merely missed, but still less than what the town lives on.
			var waiting_for: int = int(city.construction.get_committed_materials().get(activity, 0)) - int(city.resources.get(activity, 0))
			if waiting_for > 0 and comfort > 0.0:
				add(terms, BUILDING_WAITS_WEIGHT * comfort * minf(1.0, float(waiting_for) / 20.0), "the town's building waits for " + name)
			# A family that means to build its own home of this (sprint S4 review, owner 2026-11-03) has
			# its own reason to make it, before anyone else wants it: how new industries start.
			var for_own_home: bool = means_to_build_with(city, household, activity)
			if for_own_home:
				add(terms, OWN_DEMAND_WEIGHT, "it means to build its own home of %s" % name)
			# Work only for a pile no one uses (sprint S4 review): with a good no need, building or
			# workshop uses and NO_USE_STOCK of it already in store, more of it serves no one.
			elif has_no_use(city, activity):
				add(terms, -NO_USE_WEIGHT, "the town has more %s than it uses" % name)
			# New deposit trades while the town's food isn't secure (owner 2026-11-03): a weighed
			# reason, as strong as the family's temperament and values make it, never a bar. A family
			# holding to its craft may well go on, and bear what follows.
			if TownDeposits.DEPOSIT_OF.values().has(TownLand.get_reach_kind(occupation)):
				var insecurity: float = get_food_insecurity(city)
				if insecurity > 0.0:
					add(terms, -FOOD_INSECURITY_WEIGHT * insecurity * get_survival_mindedness(household), "the town's food isn't secure yet")
	# An essential good running out within the season: the danger competes with everything else.
	var shortage: float = get_shortage(city, activity)
	if shortage > 0.0:
		var no_one: bool = count_producers(city, activity) - (1 if own != null and get_activity(own.type) == activity else 0) <= 0
		add(terms, SHORTAGE_WEIGHT * shortage, "the town will run out of %s within the season%s" % [TownInfluence.get_activity_name(activity), ", and no one here makes any" if no_one else ""])
	# Work that lives off the land is only as good as the land in reach of where it would stand.
	var reach_kind: String = TownLand.get_reach_kind(occupation)
	var reach: float = 1.0
	if reach_kind != "" and not city.local_map.is_empty():
		if own != null and BuildingTiers.get_base_type(own.type) == occupation:
			reach = city.land.get_reach_factor(own)
		else:
			var hand_work: String = BuildingTiers.get_hand_work_type(occupation)
			var site: Vector2i = choose_site(city, household, hand_work)
			if site.x < 0:
				return {"score": -INF, "terms": terms, "appeal": 0.0, "available": false}
			result["site"] = site
			reach = city.land.get_reach_factor_at(hand_work, site, city.construction.get_size(hand_work))
		var land: float = LAND_WEIGHT * (city.get_base_building_output_amount(occupation) * reach / get_best_output(city, activity) - 1.0)
		if land <= -0.2:
			add(terms, land, LAND_REASONS[reach_kind] if reach < 0.75 else "it yields less than other ways of getting " + GoodsNeedBucketHelper.get_good_display_name(activity).to_lower())
	# The danger of hunger draws a family to food work, as far as that work would really feed people
	# here: on this land, with its skill, through the coming seasons.
	if activity == TownInfluence.ACTIVITY_FOOD and hunger > 0.0:
		var relief: float = get_food_relief(city, household, occupation, reach)
		if relief > 0.05:
			add(terms, SURVIVAL_WEIGHT * hunger * relief, str(hardship["reason"]))
	# The danger of cold draws a family to wood work in the same way, as far as the trees in reach of
	# where it would cut allow.
	if activity == TownInfluence.ACTIVITY_WOOD and float(cold["level"]) > 0.0 and reach > 0.05:
		add(terms, SURVIVAL_WEIGHT * float(cold["level"]) * minf(1.0, reach), str(cold["reason"]))
	# What it knows draws it to that work; work it would have to learn, it starts at a novice's pace
	# (HouseholdEconomy).
	if HouseholdEconomy.is_on(city) and not city.has_meta("economy_no_proficiency_effects"):
		var knows: float = HouseholdEconomy.get_level(household, occupation)
		if knows >= HouseholdEconomy.FORGOTTEN_BELOW:
			# Candidates under evaluation (Priority 5, comparison only): the familiar pulls as the calling
			# does, less as hunger nears, on any work but food (meta "known_work_yields_to_survival"), or
			# only on work for what the town merely goes without, like wool (meta "familiar_comfort_yields").
			var familiar: float = prosperity if (city.has_meta("known_work_yields_to_survival") and activity != TownInfluence.ACTIVITY_FOOD) or (city.has_meta("familiar_comfort_yields") and not essential) else 1.0
			add(terms, HouseholdEconomy.KNOWN_WORK_WEIGHT * familiar * minf(1.0, knows / HouseholdEconomy.ESTABLISHED), "it knows the work (%s)" % HouseholdEconomy.describe_level(knows))
	var appeal: float = add_encouragement(city, household, activity, terms, "the gathering asks for " + TownInfluence.get_activity_name(activity))
	# A focused appeal for this good, while it stands (FocusedAppeal): apart from the priority's ask.
	result["focused"] = FocusedAppeal.add_appeal(city, household, activity, terms)
	if GuidingWisdom.is_short_of(city, activity):
		GuidingWisdom.add_appeal(city, household, GuidingWisdom.PREPARE, terms)
	result["score"] = sum(terms)
	result["terms"] = terms
	result["appeal"] = appeal
	return result

# How near hunger is, for a family choosing its work: {"level" 0-1, "reason"}. The town's outlook
# (get_food_outlook) weighed by the family's temperament; a family already going hungry itself
# weighs its own hunger fully. 0 when the comparison turns survival awareness off (meta
# "no_survival_awareness").
static func get_hardship(city: City, household: Household) -> Dictionary:
	if city.has_meta("no_survival_awareness"):
		return {"level": 0.0, "reason": ""}
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	var ambition: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.AMBITION)
	var temperament: float = 1.0 + 0.25 * maxi(0, -risk) - 0.1 * maxi(0, risk) - 0.1 * maxi(0, ambition)
	# Two horizons of one danger, the larger counting: hunger near (what the town holds and will bring
	# in over the coming months against what it will eat), and a town growing less than it eats,
	# which a full store only puts off. Until 2026-11-01 only the first (meta "hunger_horizon_only").
	var near: float = get_food_outlook(city)
	var deficit: float = 0.0 if city.has_meta("hunger_horizon_only") else clampf((1.0 - get_food_ratio(city)) * DEFICIT_WEIGHT, 0.0, 1.0)
	var town: float = clampf(maxf(near, deficit) * temperament, 0.0, 1.0)
	var own: float = clampf(float(household.short_days_this_month) / HUNGRY_DAYS_DESPERATE, 0.0, 1.0)
	if own > town:
		return {"level": own, "reason": "the family itself is going hungry"}
	if deficit > near:
		return {"level": town, "reason": "the town grows less food than it eats"}
	var winter: bool = city.get_season_index() >= 2
	return {"level": town, "reason": "the town will go hungry before %s" % ("the winter is out" if winter else "the next harvest is in")}

# The danger of cold (TownFuel; sprint S3 review): {"level" 0..1, "reason"}, as get_hardship is for
# hunger. The family's own cold hearth this month, or the town's wood in store and coming from its
# wood work over the coming SURVIVAL_HORIZON_DAYS against what its hearths and workshops will burn and
# use then, weighed by temperament. Nothing where no hearth burns.
static func get_cold_hardship(city: City, household: Household) -> Dictionary:
	if city.has_meta("no_survival_awareness") or not TownFuel.is_on(city):
		return {"level": 0.0, "reason": ""}
	var own: float = clampf(float(household.cold_days_this_month) / HUNGRY_DAYS_DESPERATE, 0.0, 1.0)
	var town: float = 0.0
	if TownFuel.get_need_over(city, SURVIVAL_HORIZON_DAYS) > 0.0:
		var use: float = get_use(city, TownInfluence.ACTIVITY_WOOD, SURVIVAL_HORIZON_DAYS)
		var coming: float = float(int(city.resources["wood"])) + get_working_output(city, TownInfluence.ACTIVITY_WOOD) * SURVIVAL_HORIZON_DAYS
		var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
		var temperament: float = 1.0 + 0.25 * maxi(0, -risk) - 0.1 * maxi(0, risk)
		town = clampf((1.0 - coming / maxf(1.0, use)) * temperament, 0.0, 1.0)
		# A hearth that went cold this month weighs less once the store again holds the coming need
		# (sprint S5b): the cold is remembered, but the wood to answer it is there.
		if not city.has_meta("no_wood_plenty"):
			own *= clampf(1.0 - float(int(city.resources["wood"])) / maxf(1.0, use), 0.0, 1.0)
	if own >= town and own > 0.0:
		return {"level": own, "reason": "its own hearth has gone cold"}
	return {"level": town, "reason": "the town's hearths will go cold before the cold season is out"}

# How far the town's food falls short of what its people will eat over the coming
# SURVIVAL_HORIZON_DAYS, 0 (enough) to 1 (nothing in store or coming): its food in store and its
# families' larders, and what its food work will bring in on its land through the seasons ahead (a
# winter coming yields less). Only work a family does or has claimed counts, at that family's pace:
# its hands, its skill, and the share of its day left after walking and other work. A workplace
# standing empty feeds no one (docs/AUTONOMOUS_OCCUPATIONS.md: counting empty farms, families saw
# plenty in towns about to starve).
static func get_food_outlook(city: City) -> float:
	return clampf(1.0 - get_food_coverage(city), 0.0, 1.0)

# The town's food in store, in families' larders and coming from its work over the next
# SURVIVAL_HORIZON_DAYS, as a share of what its people will eat then (1: just enough).
static func get_food_coverage(city: City) -> float:
	var eats: float = float(city.get_food_consumption_for_population(city.get_total_population())) * SURVIVAL_HORIZON_DAYS
	if eats <= 0.0:
		return INF
	var coming: float = float(int(city.resources["food"]))
	for household: Household in city.households:
		coming += household.larder
	coming += get_working_output(city, TownInfluence.ACTIVITY_FOOD, true)
	return coming / eats

# Whether a family choosing its work judges the town's food by the coming months (survival
# awareness), rather than by today's output against today's eating. The comparison can keep the
# older term beside the survival term, as before 2026-11-01 (meta "hunger_counted_twice").
static func weighs_food_ahead(city: City) -> bool:
	return not city.has_meta("no_survival_awareness") and not city.has_meta("hunger_counted_twice")

# A workplace's output over the coming SURVIVAL_HORIZON_DAYS, in days of its average output: fields
# follow the farming year and hunting its own seasons (EconomyBalance).
static func get_season_days(city: City, building_type: String) -> float:
	var base: String = BuildingTiers.get_base_type(building_type)
	var yields: Array[float] = []
	if base == Building.BUILDING_FARM:
		yields = EconomyBalance.FARM_SEASON_YIELD
	elif base == Building.BUILDING_HUNTER:
		yields = EconomyBalance.HUNT_SEASON_YIELD
	if yields.is_empty():
		return float(SURVIVAL_HORIZON_DAYS)
	var total: float = 0.0
	var start: int = city.get_day_of_year() - 1
	for i in range(SURVIVAL_HORIZON_DAYS):
		total += yields[(posmod(start + i, Calendar.DAYS_PER_YEAR) / (Calendar.DAYS_PER_YEAR / 4)) % 4]
	return total

# What taking up food work would bring in, as a share of the best any food work brings in starting by
# hand: its hand work's output on this land, at the family's skill, through the coming seasons.
static func get_food_relief(city: City, household: Household, occupation: String, reach: float) -> float:
	var best: float = 0.001
	for hand_work: String in BuildingTiers.TIER0_TO_TIER1.keys():
		if get_activity(hand_work) == TownInfluence.ACTIVITY_FOOD:
			best = maxf(best, city.get_base_building_output_amount(hand_work) * get_season_days(city, hand_work))
	var own_hand: String = BuildingTiers.get_hand_work_type(occupation)
	var own: float = city.get_base_building_output_amount(own_hand) * reach * get_season_days(city, own_hand) * HouseholdEconomy.get_output_factor(city, household, occupation)
	return clampf(own / best, 0.0, 1.0)

# The most a proper workplace of any trade makes of a good on the best land.
static func get_best_output(city: City, good: String) -> float:
	var best: float = 0.0
	for occupation: String in BuildingTiers.TIER0_TO_TIER1.values():
		if get_activity(occupation) == good:
			best = maxf(best, city.get_base_building_output_amount(occupation))
	return maxf(best, 0.001)

# The need a good meets that goes unmet or short in the town ("" when none does).
static func get_unmet_need(city: City, good: String) -> String:
	var pressures: Dictionary = city.get_need_pressure_summary()
	for bucket: String in GoodsNeedBucketHelper.get_need_buckets_for_good(good):
		var pressure: Dictionary = pressures.get(bucket, {})
		if bool(pressure.get("active", false)) and str(pressure.get("status", "")) in ["unmet", "low"]:
			return GoodsNeedBucketHelper.get_bucket_display_name(bucket).to_lower()
	return ""

# How near the town is to running out of a good it cannot do without and no one here makes: 0 when
# what it holds will last the coming season (SHORTAGE_HORIZON_DAYS), up to 1 when it covers none of
# what that season will use (the tool gap: docs/WORKPLACE_CHOICE_INVESTIGATION.md). What a town uses
# up is what it eats, the upkeep its proper workplaces will draw once their grace is over, and what
# its workplaces use to make their goods. Mending families do for themselves (HouseholdEconomy) is
# not counted: a family judges by the store it can see. A good the town only goes without (wool for
# clothing) is never an essential shortage.
# Narrow by the owner's decision (2026-11-01): a deficit in a good the town does make (food grown,
# but too little) is not this danger; families weigh it in choosing their work (get_hardship). The
# comparison can count deficits too (meta "shortage_counts_deficits", what the first comparison
# measured as "broad") or turn recognition off (meta "no_shortage_recognition").
static func get_shortage(city: City, good: String) -> float:
	if city.has_meta("no_shortage_recognition"):
		return 0.0
	var making: float = 0.0
	if count_producers(city, good) > 0:
		if not city.has_meta("shortage_counts_deficits"):
			return 0.0
		making = get_expected_output(city, good) * SHORTAGE_HORIZON_DAYS
	var use: float = get_use(city, good, SHORTAGE_HORIZON_DAYS)
	if use <= 0.0:
		return 0.0
	return clampf(1.0 - (float(int(city.resources.get(good, 0))) + making) / use, 0.0, 1.0)

# How far the town is from food security, 0 (secure) to 1 (nothing in store or coming): its food
# in store, in larders and coming from its work over the coming SURVIVAL_HORIZON_DAYS, against
# SECURE_FOOD_DAYS of eating (owner 2026-11-03).
static func get_food_insecurity(city: City) -> float:
	var coverage: float = get_food_coverage(city)
	if is_inf(coverage):
		return 0.0
	return clampf(1.0 - coverage * float(SURVIVAL_HORIZON_DAYS) / SECURE_FOOD_DAYS, 0.0, 1.0)

# How much a family's temperament and values make it weigh survival over its craft (owner
# 2026-11-03): more for the cautious, less for the daring and the ambitious, and less again for a
# family that holds to its craft or its ways (Keepers of Craft, Traditionalist, Perfectionist).
# Values aren't good or bad economically: each cuts both ways by circumstance.
static func get_survival_mindedness(household: Household) -> float:
	var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
	var ambition: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.AMBITION)
	var weight: float = 1.0 + 0.25 * maxi(0, -risk) - 0.1 * maxi(0, risk) - 0.1 * maxi(0, ambition)
	for value_id: String in ["keepers_of_craft", "traditionalist", "perfectionist"]:
		if HouseholdCharacter.get_strength(household, value_id) > 0:
			weight *= CRAFT_HOLDS_SURVIVAL_FACTOR
	return maxf(0.0, weight)

const CRAFT_HOLDS_SURVIVAL_FACTOR: float = 0.6

# Whether a family wanting a better home would build it of what this good makes, if it could have
# any (MaterialChoice with supply set aside; sprint S4 review).
static func means_to_build_with(city: City, household: Household, good: String) -> bool:
	if not EconomyBalance.can_be_stone(Building.BUILDING_HOUSE):
		return false
	var wants_home: bool = household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household) or FamilyDevelopment.wants_better_home(household)
	if not wants_home:
		return false
	var material: String = str(MaterialChoice.choose(city, household, Building.BUILDING_HOUSE, true)["material"])
	return EconomyBalance.get_build_cost(Building.BUILDING_HOUSE, material).has(good)

# Whether the town has no use for more of a good (sprint S4 review): not food, wood or tools, no need
# it meets going short, no building waiting for it, no workshop using it, and NO_USE_STOCK in store.
static func has_no_use(city: City, good: String) -> bool:
	if good in ACTIVITIES or int(city.resources.get(good, 0)) < NO_USE_STOCK or get_unmet_need(city, good) != "":
		return false
	if int(city.construction.get_committed_materials().get(good, 0)) > int(city.resources.get(good, 0)):
		return false
	return get_use(city, good, SHORTAGE_HORIZON_DAYS) <= 0.0

const WOOD_PLENTY_REASON: String = "the town holds more wood than it needs through the coming winter"

# How far the wood in store exceeds what the town will burn and use through the end of the coming
# winter, and what its building still waits for (sprint S5b; owner 2026-11-05, option b of the Track A
# review): 0 (nothing spare) to 1 (spare as large again as that need, or WOOD_PLENTY_FLOOR where
# little is needed). What families see in the store, not what is coming. It weighs in their choices
# as a reason, never as a rule. Off with the meta "no_wood_plenty" (the Track A build).
static func get_wood_plenty(city: City) -> float:
	if city.has_meta("no_wood_plenty"):
		return 0.0
	var days: int = Calendar.DAYS_PER_YEAR - (city.get_day_of_year() - 1)
	var need: float = get_use(city, TownInfluence.ACTIVITY_WOOD, days) + float(int(city.construction.get_committed_materials().get("wood", 0)))
	return clampf((float(int(city.resources["wood"])) - need) / maxf(need, WOOD_PLENTY_FLOOR), 0.0, 1.0)

static func get_use(city: City, good: String, days: int) -> float:
	var use: float = 0.0
	if good == TownInfluence.ACTIVITY_FOOD:
		use += float(city.get_food_consumption_for_population(city.get_total_population())) * days
	# The hearths' wood over the coming days, season by season (TownFuel).
	if good == TownInfluence.ACTIVITY_WOOD:
		use += TownFuel.get_need_over(city, days)
	for building: Building in city.buildings:
		if good == TownInfluence.ACTIVITY_TOOLS and building.needs_maintenance() and building.receives_maintenance:
			var working_days: int = days - building.upkeep_grace_days
			if working_days > 0:
				use += float((building.maintenance_timer + working_days) / building.get_maintenance_interval() * building.get_maintenance_tool_cost())
		if building.can_produce():
			var inputs: Dictionary = (EconomyBalance.PRODUCTION.get(BuildingTiers.get_base_type(building.type), {}) as Dictionary).get("inputs", {})
			if inputs.has(good):
				use += city.get_base_building_output_amount(building.type) * float(inputs[good]) * days
	return use

# --- Improving work -----------------------------------------------------------------------------

static func consider_improving(city: City, household: Household, holding: Building) -> ConstructionProject:
	if city.construction.get_upgrade_project(holding.id) != null:
		return null
	var proper: String = BuildingTiers.get_upgrade_type(holding.type)
	var desire: Dictionary = get_improve_desire(city, household, proper)
	var name: String = describe_type(holding.type, false)
	var score: float = float(desire["score"]) + get_noise(city, household, "improve")
	var hard_times: bool = GuidingWisdom.asks_to_hold_off(city, proper)
	if score < IMPROVE_THRESHOLD:
		GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PRIDE, false, score, IMPROVE_THRESHOLD, float(desire["pride"]))
		if hard_times:
			GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PREPARE, true, score, IMPROVE_THRESHOLD, float(desire["prepare"]))
		note(city, household, "Keeps to hand work at its %s (%s)" % [name, "; ".join(get_reasons(desire["terms"], false))])
		return null
	# What it builds the proper workplace of (MaterialChoice, sprint S4).
	var material_choice: Dictionary = MaterialChoice.choose(city, household, proper)
	var material: String = str(material_choice["material"])
	var block: String = city.influence.get_funding_block(EconomyBalance.get_build_cost(proper, material), [get_activity(proper), TownInfluence.ACTIVITY_IMPROVE] as Array[String], household)
	if block != "":
		city.influence.held_back_by_stores += 1
		city.social.on_held_back(household)
		note(city, household, "Wants to improve its %s, but %s" % [name, block])
		return null
	var project: ConstructionProject = city.construction.request_upgrade(holding.id, ConstructionProject.REQUESTED_BY_HOUSEHOLD, household.id, material)
	if project == null:
		return null
	use_first_claim(city, household, project)
	city.influence.improvements_started += 1
	GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PRIDE, true, score, IMPROVE_THRESHOLD, float(desire["pride"]))
	if hard_times:
		GuidingWisdom.record_if_at_stake(city, household, GuidingWisdom.PREPARE, false, score, IMPROVE_THRESHOLD, float(desire["prepare"]))
	if CommunityPriority.is_swayed(score, float(desire["appeal"]), IMPROVE_THRESHOLD):
		CommunityPriority.record_swayed(city, household, "improve")
	if household.improve_decision_day < 0:
		household.improve_decision_day = city.construction.day
	var of_stone: String = "" if material == EconomyBalance.MATERIAL_TIMBER else ", of %s (%s)" % [material.replace("_", " "), "; ".join(get_reasons(material_choice["terms"], true))]
	note(city, household, "Improving its %s into %s (%s)%s" % [name, describe_type(proper), "; ".join(get_reasons(desire["terms"], true)), of_stone])
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
	# Guiding wisdom (the town's lasting expectations, apart from its priority): doing work well asks
	# for it; keeping something back asks to hold off as hard times near.
	var pride: float = GuidingWisdom.add_appeal(city, household, GuidingWisdom.PRIDE, terms)
	var prepare: float = GuidingWisdom.add_appeal(city, household, GuidingWisdom.PREPARE, terms, -1.0) if GuidingWisdom.asks_to_hold_off(city, proper_type) else 0.0
	var appeal: float = add_encouragement(city, household, TownInfluence.ACTIVITY_IMPROVE, terms, "the gathering asks for better work")
	# A priority for this trade's output (food) asks for its improvement too, once.
	if appeal == 0.0:
		appeal = add_encouragement(city, household, get_activity(proper_type), terms, "the gathering asks for " + TownInfluence.get_activity_name(get_activity(proper_type)))
	# A deserved honour for a holding or a craft it admires (TownSocial.judge_recognition).
	if household.inspired_until >= city.construction.day and household.inspired_by_household >= 0:
		var whose: String = city.get_household_label(household.inspired_by_household)
		if household.inspired_by == TownSocial.RECOGNITION_ACHIEVEMENT:
			add(terms, 0.75, "it would match %s's honoured holding" % whose)
		elif household.inspired_by == TownSocial.RECOGNITION_CRAFT:
			add(terms, 0.5, "it would equal %s's honoured craft" % whose)
	return {"score": sum(terms), "terms": terms, "appeal": appeal, "pride": pride, "prepare": prepare}

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
			# Little wood in store, or less than the hearths will burn this coming season (TownFuel).
			var wood: float = float(int(city.resources["wood"]))
			return 0.75 if wood < 20.0 or wood < TownFuel.get_need_over(city, FUEL_RISK_DAYS) else 0.0
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
# The asks come from the community's priority (CommunityPriority), a directing request. What the
# town backs does not pull here: it moves time given freely, not a family's own work (owner,
# 2026-10-31). Returns the weight added.
static func add_encouragement(city: City, household: Household, activity: String, terms: Array, reason: String) -> float:
	if not city.influence.is_encouraged(activity):
		return 0.0
	var receptive: Dictionary = get_receptiveness(household, city, CommunityPriority.KIND_DIRECTING)
	var weight: float = ENCOURAGE_WEIGHT * float(receptive["factor"])
	add(terms, weight, reason + str(receptive["note"]))
	return weight

# How readily a family heeds the gathering's appeals, {"factor", "note"}. Before there are
# institutions, the community's decisions come from informal gatherings of its households (owner
# decision; docs/HOUSEHOLD_SOCIAL_MODEL.md), so trust is confidence in how those gatherings decide.
# Deference and trust make a family readier, self-government less; communal labor and solitary work
# nudge it; and an appeal carries more weight when the families it respects most stand behind it,
# less when they are families it is at odds with (TownSocial.get_respected_voices).
#
# The kind of request matters (CommunityPriority): a self-governing family resists being directed
# in its own work, but time given freely is its own choice, so that request is spared the
# self-governing pull; communal labor and solitary work bear on giving time together, not on
# a family's own work. With no kind given (the norms' appeals), every term applies as before.
static func get_receptiveness(household: Household, city: City = null, kind: String = "") -> Dictionary:
	var factor: float = 1.0
	var note_text: String = ""
	var deference: int = HouseholdCharacter.get_strength(household, "deferential")
	var self_rule: int = HouseholdCharacter.get_strength(household, "self_governing")
	if deference > 0:
		factor += 0.25 * deference
		note_text = ", and it heeds the gathering"
	elif self_rule > 0 and kind != CommunityPriority.KIND_VOLUNTARY:
		factor -= 0.2 * self_rule
		note_text = ", though it judges for itself"
	factor += 0.15 * household.trust
	if household.trust <= -2:
		note_text += ", though it distrusts the gathering"
	if kind != CommunityPriority.KIND_DIRECTING:
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
		# The Speaker of the Gathering leads the families who follow it, one way or the other.
		if kind != "":
			var lead: Dictionary = TownRegard.get_lead_receptiveness(city, household)
			factor += float(lead["factor"])
			note_text += str(lead["note"])
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

# The food the town's work really brings in a day (get_working_output) against what it eats: what
# families weigh as "the town grows less food than it eats" or "plenty". Until 2026-11-01 it counted
# every workplace standing or planned at full yield, empty ones included, and families saw plenty in
# towns about to starve (docs/AUTONOMOUS_OCCUPATIONS.md); the comparison can restore that (meta
# "food_ratio_counts_empty").
static func get_food_ratio(city: City) -> float:
	var eats: float = maxf(1.0, float(city.get_food_consumption_for_population(city.get_total_population())))
	if city.has_meta("food_ratio_counts_empty"):
		return get_expected_output(city, TownInfluence.ACTIVITY_FOOD) / eats
	return get_working_output(city, TownInfluence.ACTIVITY_FOOD) / eats

# What one worked workplace really brings in a day, as get_working_output counts it.
static func get_building_output(city: City, building: Building) -> float:
	var family: Household = city.get_household_by_id(building.assigned_household_id)
	var pace: float = city.get_family_labor_factor(family) * HouseholdEconomy.get_output_factor(city, family, building.type) * city.get_work_time_factor(building)
	if building.is_working_by_hand():
		pace *= EconomyBalance.TIER0_OUTPUT_FRACTION
	return city.get_base_building_output_amount(building.type) * city.land.get_reach_factor(building) * pace

# What the town's work in a good really brings in a day: only work a family does or has claimed, on
# its land, at that family's pace (its hands, its skill, the share of its day left after walking,
# spare time and secondary work), and at hand work's pace where a proper workplace stands short of
# tools. With `seasonal`, the total over the coming SURVIVAL_HORIZON_DAYS, fields and hunting
# following their seasons.
static func get_working_output(city: City, good: String, seasonal: bool = false) -> float:
	var total: float = 0.0
	for building: Building in city.buildings:
		if building.assigned_household_id < 0 or get_activity(building.type) != good:
			continue
		total += get_building_output(city, building) * (get_season_days(city, building.type) if seasonal else 1.0)
	for project: ConstructionProject in city.construction.projects:
		if get_activity(project.building_type) != good:
			continue
		var share: float = 0.0
		var worker: int = project.claimant_household_id
		if project.kind == ConstructionProject.KIND_BUILDING:
			share = 1.0
		elif project.kind == ConstructionProject.KIND_UPGRADE:
			share = 1.0 - EconomyBalance.TIER0_OUTPUT_FRACTION
			for building: Building in city.buildings:
				if building.id == project.target_building_id:
					worker = building.assigned_household_id
		if worker < 0 or share <= 0.0:
			continue
		var family: Household = city.get_household_by_id(worker)
		var pace: float = city.get_family_labor_factor(family) * HouseholdEconomy.get_output_factor(city, family, project.building_type)
		total += city.get_base_building_output_amount(project.building_type) * share * city.land.get_reach_factor_at(project.building_type, project.tile, project.size) * pace * (get_season_days(city, project.building_type) if seasonal else 1.0)
	return total

static func get_food_days(city: City) -> float:
	return float(city.resources["food"]) / maxf(1.0, float(city.get_food_consumption_for_population(city.get_total_population())))

static func get_expected_output(city: City, activity: String) -> float:
	var total: float = 0.0
	# Work that lives off the land yields what the water, woods or pasture in its reach allow (TownLand).
	for building: Building in city.buildings:
		if get_activity(building.type) == activity:
			total += city.get_base_building_output_amount(building.type) * city.land.get_reach_factor(building)
	for project: ConstructionProject in city.construction.projects:
		if project.kind == ConstructionProject.KIND_BUILDING and get_activity(project.building_type) == activity:
			total += city.get_base_building_output_amount(project.building_type) * city.land.get_reach_factor_at(project.building_type, project.tile, project.size)
		elif project.kind == ConstructionProject.KIND_UPGRADE and get_activity(project.building_type) == activity:
			total += city.get_base_building_output_amount(project.building_type) * (1.0 - EconomyBalance.TIER0_OUTPUT_FRACTION) * city.land.get_reach_factor_at(project.building_type, project.tile, project.size)
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
# town's heart by its Home and Place values, toward richer water, woods or pasture for work that
# lives off them, on the work ground when the player has marked any.
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
	var lives_off_land: bool = TownLand.get_reach_kind(building_type) != ""
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
				if lives_off_land:
					score -= LAND_SITE_TILES * city.land.get_reach_factor_at(building_type, origin, size)
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

# Work families choose for themselves: every workplace with a hand-work stage that makes a good
# (BuildingTiers), in its order, so the first three keep their places.
static func get_occupations(city: City) -> Array[String]:
	var occupations: Array[String] = []
	if city.has_meta("occupations_first_three"):
		for activity: String in ACTIVITIES:
			occupations.append(PROPER_WORK[activity])
		return occupations
	# Comparison only: trades left out, to tell their effects apart (meta "occupations_left_out"),
	# for the whole game or until a day (meta "occupations_left_out_until").
	var left_out: Array = city.get_meta("occupations_left_out", [])
	if city.construction.day >= int(city.get_meta("occupations_left_out_until", 1 << 30)):
		left_out = []
	for proper: String in BuildingTiers.TIER0_TO_TIER1.values():
		if EconomyBalance.PRODUCTION.has(proper) and not left_out.has(proper):
			occupations.append(proper)
	return occupations

# Comparison only (meta "occupation_vetoes": [{"household", "occupation", "until"}]): one family
# may not choose one trade until a day, to tell what that one decision did to its town.
static func is_vetoed(city: City, household: Household, occupation: String) -> bool:
	for veto: Dictionary in city.get_meta("occupation_vetoes", []):
		if int(veto["household"]) == household.id and str(veto["occupation"]) == occupation and city.construction.day < int(veto["until"]):
			return true
	return false

# Comparison only (meta "trace_choices", an Array): a family's first choice of work, its options
# ranked with their scores and strongest reasons, and the town's hardship as it saw it.
static func record_choices(city: City, household: Household, choices: Array[Dictionary]) -> void:
	var ranked: Array = []
	for choice: Dictionary in choices.slice(0, 4):
		ranked.append({"occupation": choice["occupation"], "score": snappedf(float(choice["score"]), 0.01), "for": get_reasons(choice["terms"], true, 4), "against": get_reasons(choice["terms"], false, 2)})
	(city.get_meta("trace_choices") as Array).append({"day": city.construction.day, "household": household.id, "hardship": snappedf(float(get_hardship(city, household)["level"]), 0.01), "coverage": snappedf(get_food_coverage(city), 0.01), "ratio": snappedf(get_food_ratio(city), 0.01), "ranked": ranked})

# Whether a calling for work the town only goes without fades fully with hunger (the default since
# 2026-11-02). Meta "comfort_calling_kept" restores the old rule, half the pull surviving, for comparison.
static func is_comfort_calling_faded(city: City) -> bool:
	return not city.has_meta("comfort_calling_kept")

# What fading changed: the choice that would have come first without it, from choices carrying
# "calling_faded".
static func get_unfaded_best(choices: Array) -> String:
	var best: String = ""
	var best_score: float = -INF
	for choice: Dictionary in choices:
		var score: float = float(choice["score"]) + float(choice.get("calling_faded", 0.0))
		if score > best_score:
			best_score = score
			best = choice["occupation"]
	return best

# Counts (meta "comfort_calling_changed": {kind: count}) and lists (meta "comfort_calling_cases")
# the decisions fading changed: what the family did against what it would have done.
static func count_fade_changed(city: City, household: Household, kind: String, chosen: String, unfaded: String) -> void:
	if chosen == unfaded:
		return
	var counts: Dictionary = city.get_meta("comfort_calling_changed", {})
	counts[kind] = int(counts.get(kind, 0)) + 1
	city.set_meta("comfort_calling_changed", counts)
	var cases: Array = city.get_meta("comfort_calling_cases", [])
	cases.append({"day": city.construction.day, "household": household.id, "kind": kind, "chose": chosen, "instead_of": unfaded, "hardship": snappedf(float(get_hardship(city, household)["level"]), 0.01)})
	city.set_meta("comfort_calling_cases", cases)

# What a decision about a trade is called in its unknown (get_noise).
static func get_choice_key(occupation: String) -> String:
	for activity: String in PROPER_WORK.keys():
		if PROPER_WORK[activity] == occupation:
			return activity
	return occupation

# The good a workplace families choose makes ("food", "wood", "tools", "wool"...), or "" for one
# families do not choose (it has no hand-work stage).
static func get_activity(building_type: String) -> String:
	var base: String = BuildingTiers.get_base_type(building_type)
	if BuildingTiers.get_hand_work_type(base) == "" or not EconomyBalance.PRODUCTION.has(base):
		return ""
	return str((EconomyBalance.PRODUCTION[base] as Dictionary)["output"])

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

# The family wanted work it could find no free land for (SidebarOverviewPage, Needs attention).
static func note_blocked(city: City, household: Household, building_type: String) -> void:
	household.blocked_work_type = building_type
	household.blocked_work_day = city.construction.day

static func note(city: City, household: Household, text: String) -> void:
	household.initiative_note = text
	household.initiative_day = city.construction.day

static func describe_type(building_type: String, with_article: bool = true) -> String:
	var name: String = BuildingTiers.get_display_name(building_type).to_lower()
	if not with_article:
		return name
	return ("an " if "aeiou".contains(name.left(1)) else "a ") + name
