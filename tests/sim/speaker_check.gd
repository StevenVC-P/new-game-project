extends SceneTree

# Emergent recognition and the Speaker of the Gathering (docs/EMERGENT_RECOGNITION_AND_LEADERSHIP.md):
# the same towns, seeds and founders as the wisdom check, played under a community priority and its
# wisdoms, families leading and the social model on; the stand-in player builds nothing else and
# never honours anyone. Branches of the same town (identical until Village, since the simulation is
# deterministic):
#
# - existing: recognition only by honours (which this player never gives), the old voices; no Speaker;
# - emergent: families notice each other; influence and voices; no Speaker;
# - speaker0/1/2: at Village the Elder appoints the first, second or third most influential household;
# - replace01/12/20: the first (second, third) appointed, then replaced REPLACE_AFTER_DAYS later by
#   the second (third, first).
#
# Measured at Village (before any appointment) and at the end. One condition, strategy and branch
# per process (write to a file, filter for [SPK]):
#   <godot> --headless --path . --script res://tests/sim/speaker_check.gd -- --conditions=ordinary --strategies=food --branch=speaker0 > spk.log
# Options: --years=N (default 6), --sites=N (default 12). Difficult sites come from the wisdom
# check's cache (run it with --prepare-difficult first).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const W: Dictionary = {"endure": GuidingWisdom.ENDURE, "respect": GuidingWisdom.RESPECT, "prepare": GuidingWisdom.PREPARE, "pride": GuidingWisdom.PRIDE}
const STRATEGIES: Array = [
	{"name": "food", "wisdoms": [], "priority": CommunityPriority.FOOD},
	{"name": "endure+respect|cooperation", "wisdoms": ["endure", "respect"], "priority": CommunityPriority.COOPERATION},
	{"name": "prepare+pride|investment", "wisdoms": ["prepare", "pride"], "priority": CommunityPriority.INVESTMENT},
]
const BRANCHES: Array[String] = ["existing", "emergent", "speaker0", "speaker1", "speaker2", "replace01", "replace12", "replace20"]
const REPLACE_AFTER_DAYS: int = 540
const DIFFICULT_POOL_REGIONS: int = 30
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const POLITICAL_VALUES: Array[String] = ["egalitarian", "hierarchical", "deferential", "self_governing", "communal_labor", "solitary", "mutual_aid", "private_holdings", "common_stores", "sharing", "lawful", "charitable", "acquisitive", "keepers_of_craft", "perfectionist", "negotiation"]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 6
	var site_count: int = 12
	var conditions: Array[String] = ["ordinary"]
	var only: Array[String] = []
	var branch: String = "emergent"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--strategies="):
			only.assign(argument.trim_prefix("--strategies=").split(","))
		elif argument.begins_with("--branch="):
			branch = argument.trim_prefix("--branch=")
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	for condition: String in conditions:
		var sites: Array = get_difficult_sites() if condition == "difficult" else ordinary
		for strategy: Dictionary in STRATEGIES:
			if not only.is_empty() and not only.has(str(strategy["name"])):
				continue
			var started: int = Time.get_ticks_msec()
			for site: Dictionary in sites:
				var result: Dictionary = play(site, strategy, branch, years)
				_report("TOWN %s | %s | %s | seed %d | %s" % [condition, strategy["name"], branch, int(site["seed"]), JSON.stringify(result)])
			_report("   (%s %s %s took %.0f s)" % [condition, strategy["name"], branch, (Time.get_ticks_msec() - started) / 1000.0])
	quit()

func play(site: Dictionary, strategy: Dictionary, branch: String, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	city.social.emergent_regard = branch != "existing"
	var scenario: Dictionary = BASE.duplicate(true)
	var result: Dictionary = {"village_day": -1}
	var state: Dictionary = {"candidates": [], "village_day": -1, "replaced": false}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0:
			for key: String in strategy["wisdoms"]:
				GuidingWisdom.choose(town, W[key])
			town.influence.set_priority(str(strategy["priority"]))
		if int(state["village_day"]) < 0 and town.settlement.stage >= SettlementStage.VILLAGE:
			state["village_day"] = day
			var candidates: Array[Household] = []
			if TownRegard.is_on(town):
				candidates = TownRegard.get_candidates(town)
			state["candidates"] = candidates.map(func(h: Household) -> int: return h.id)
			result["village_day"] = day
			result["at_village"] = measure(town)
			result["candidates"] = describe_candidates(town, candidates)
			var first: int = get_appointee(branch, true)
			if first >= 0 and first < candidates.size():
				TownRegard.appoint(town, candidates[first])
		var village_day: int = int(state["village_day"])
		if village_day >= 0 and not bool(state["replaced"]) and day == village_day + REPLACE_AFTER_DAYS and branch.begins_with("replace"):
			state["replaced"] = true
			var ids: Array = state["candidates"]
			var second: int = get_appointee(branch, false)
			if second < ids.size():
				var successor: Household = town.get_household_by_id(int(ids[second]))
				result["before_replacement"] = measure(town)
				result["replaced_speaker"] = town.social.speaker_id
				if successor != null and TownRegard.appoint(town, successor):
					result["after_replacement"] = measure(town)
	StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	result["end"] = measure(city)
	return result

# The candidate a branch appoints first (or, replacing, second).
func get_appointee(branch: String, first: bool) -> int:
	if branch.begins_with("speaker"):
		return int(branch.trim_prefix("speaker")) if first else -1
	if branch.begins_with("replace"):
		var pair: String = branch.trim_prefix("replace")
		return int(pair[0]) if first else int(pair[1])
	return -1

func describe_candidates(city: City, candidates: Array[Household]) -> Array:
	var rows: Array = []
	for household: Household in candidates:
		var parts: Dictionary = TownRegard.get_influence(city, household)
		var holding: Building = FamilyInitiative.get_holding(city, household)
		rows.append({
			"id": household.id,
			"influence": float(parts["total"]),
			"regard": float(parts["regard"]),
			"following": float(parts["following"]),
			"weight": float(parts["weight"]),
			"contribution": float(parts["contribution"]),
			"supporters": (parts["supporters"] as Array).size(),
			"detractors": (parts["detractors"] as Array).size(),
			"work": holding.type if holding != null else "",
			"values": HouseholdCharacter.get_held_values(household).filter(func(v: String) -> bool: return POLITICAL_VALUES.has(v)),
			"likely_policy": str(TownRegard.choose_policy(city, household)["policy"]),
			"stance": str(CommunityPriority.get_view(city, household, city.influence.priority)["stance"]) if city.influence.priority != "" else "",
		})
	return rows

func measure(city: City) -> Dictionary:
	var social: TownSocial = city.social
	var households: Array = city.households
	var n: float = maxf(1.0, households.size())
	var m: Dictionary = {}
	m["day"] = city.construction.day
	m["people"] = city.get_total_population()
	m["households"] = households.size()
	m["departed"] = int(city.resources.get("departed_households", 0))
	var trusts: Array[float] = []
	var positive: int = 0
	var negative: int = 0
	for household: Household in households:
		trusts.append(float(household.trust) + household.trust_progress)
		for tie: Dictionary in household.ties:
			positive += 1 if int(tie["disposition"]) > 0 else 0
			negative += 1 if int(tie["disposition"]) < 0 else 0
	var mean: float = 0.0
	for t: float in trusts:
		mean += t
	mean /= n
	var spread: float = 0.0
	for t: float in trusts:
		spread += (t - mean) * (t - mean)
	m["trust"] = mean
	m["trust_sd"] = sqrt(spread / n)
	m["wary"] = trusts.filter(func(t: float) -> bool: return t <= -1.0).size()
	m["trusting"] = trusts.filter(func(t: float) -> bool: return t >= 1.0).size()
	m["ties_positive"] = positive
	m["ties_negative"] = negative
	m["trust_by_source"] = social.trust_by_source.duplicate()
	m["notices"] = social.notices
	m["admirations"] = social.admirations
	m["resentments"] = social.resentments
	m["divided"] = social.divided_notices
	m["influential"] = social.influential.duplicate()
	m["influential_changes"] = social.influential_changes
	m["ever_influential"] = social.ever_influential.size()
	var ranked: Array = TownRegard.get_ranked(city)
	m["top"] = ranked.map(func(entry: Dictionary) -> Dictionary: return {"id": (entry["household"] as Household).id, "influence": float(entry["influence"]["total"])})
	m["voices"] = social.get_respected_voices().map(func(h: Household) -> int: return h.id)
	m["speaker"] = social.speaker_id
	m["speaker_policy_counts"] = social.speaker_policy_counts.duplicate()
	m["speaker_grants"] = social.speaker_grants.duplicate()
	m["mediations"] = social.mediations
	m["mediated_settled"] = social.mediated_settled
	m["former_responses"] = social.former_speaker_responses.duplicate()
	m["removal_approved"] = social.removal_approved
	m["removal_opposed"] = social.removal_opposed
	m["vacancies"] = social.vacancies
	m["history"] = social.speaker_history.duplicate(true)
	var verdicts: Dictionary = {"supports": 0, "doubts": 0, "opposes": 0, "indifferent": 0}
	for key: String in social.speaker_verdicts.keys():
		var score: float = float(social.speaker_verdicts[key])
		verdicts["supports" if score >= TownRegard.SUPPORT_AT else "opposes" if score <= TownRegard.OPPOSE_AT else "doubts" if score <= TownRegard.DOUBT_AT else "indifferent"] += 1
	m["verdicts"] = verdicts
	var speaker: Household = TownRegard.get_speaker(city)
	if speaker != null:
		var parts: Dictionary = TownRegard.get_influence(city, speaker)
		m["speaker_supporters"] = (parts["supporters"] as Array).size()
		m["speaker_detractors"] = (parts["detractors"] as Array).size()
		m["speaker_influence"] = float(parts["total"])
	var stances: Dictionary = {"supports": 0, "indifferent": 0, "opposes": 0}
	if city.influence.priority != "" and city.influence.priority != CommunityPriority.NONE:
		for household: Household in households:
			var stance: String = CommunityPriority.get_view(city, household, city.influence.priority)["stance"]
			stances[{CommunityPriority.SUPPORTS: "supports", CommunityPriority.OPPOSES: "opposes"}.get(stance, "indifferent")] += 1
		m["backing"] = CommunityPriority.get_backing(city, city.influence.priority)
	m["priority_stances"] = stances
	m["swayed"] = city.influence.swayed.duplicate()
	m["grants_received"] = households.map(func(h: Household) -> int: return h.grants_received).reduce(func(a: int, b: int) -> int: return a + b, 0)
	m["help_weeks"] = social.help_weeks
	m["shares"] = social.shares
	m["disputes_raised"] = social.disputes_raised
	m["disputes_settled"] = social.disputes_settled
	m["disputes_unsettled"] = social.dispute_pressure
	m["value_changes"] = social.value_changes
	m["food_days"] = FamilyInitiative.get_food_days(city)
	m["tools"] = int(city.resources["tools"])
	m["improvements"] = city.influence.improvements_started
	for value_id: String in POLITICAL_VALUES:
		var holders: int = 0
		for household: Household in households:
			holders += 1 if HouseholdCharacter.get_strength(household, value_id) > 0 else 0
		m["hold_" + value_id] = holders / n
	return m

func get_difficult_sites() -> Array:
	var seeds: Array = []
	for line: String in FileAccess.get_file_as_string(DIFFICULT_CACHE).split("\n", false):
		seeds.append(int(line))
	var by_seed: Dictionary = {}
	for site: Dictionary in TownBuildingCheck.collect_sites(DIFFICULT_POOL_REGIONS, 2):
		by_seed[int(site["seed"])] = site
	var picked: Array = []
	for seed: int in seeds:
		picked.append(by_seed[seed])
	return picked

func _report(line: String) -> void:
	print("[SPK] " + line)
