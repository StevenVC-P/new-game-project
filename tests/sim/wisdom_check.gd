extends SceneTree

# Guiding wisdom check (docs/GUIDING_WISDOM.md): the same towns, seeds and founders under no wisdom
# and each of the six pairs of the four starting wisdoms, chosen at founding and kept; and two pairs
# stacked with a community priority (one that reinforces, one that pulls against a wisdom) beside
# those priorities alone; and one pair given a third wisdom by the village's Elder (the day the
# town becomes a Village). Families lead, the social model is on, starting residential land; the
# stand-in player builds nothing else. Measured at three and six years:
#
# - cultural divergence: the share of families holding each wisdom's qualities and
#   counter-qualities, value changes, how far families keep to each expectation, and what families
#   did about the town's wisdoms;
# - gameplay consequences: towns that kept their families, people, departures, trust, disputes,
#   help and sharing, long days, improvements, food and tools.
#
# Conditions as in priority_check: ordinary sites; the same with the first winter's stores lost
# (test-only stressor); naturally difficult sites (chosen once by the classic reference player and
# cached in user://wisdom_difficult_seeds.txt, so parallel runs share them).
#
# Run one condition and some strategies per process (write to a file, filter for [WIS]):
#   <godot> --headless --path . --script res://tests/sim/wisdom_check.gd -- --conditions=ordinary --strategies=none,endure+respect > wis.log
# Options: --years=N (default 6, with a year-3 snapshot), --sites=N, --prepare-difficult (pick and cache),
# --no-reconsider (families never reconsider their work), --change-limit=N (families changing work a month; 0 none),
# --no-self-sufficiency (no secondary work, larders or proficiency: docs/HOUSEHOLD_SELF_SUFFICIENCY.md),
# --no-proficiency-effects / --no-secondary (to tell their effects apart), --meta=a,b (comparison switches on each town), --disrupt=specialist|stores (at DISRUPT_DAY, the same on both sides of a comparison: every family
# working tools leaves the town, or the common stores lose DISRUPT_STORE_LOSS of their food, wood and tools).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const W: Dictionary = {"endure": GuidingWisdom.ENDURE, "respect": GuidingWisdom.RESPECT, "prepare": GuidingWisdom.PREPARE, "pride": GuidingWisdom.PRIDE}
const STRATEGIES: Array = [
	{"name": "none", "wisdoms": [], "priority": ""},
	{"name": "endure+respect", "wisdoms": ["endure", "respect"], "priority": ""},
	{"name": "endure+prepare", "wisdoms": ["endure", "prepare"], "priority": ""},
	{"name": "endure+pride", "wisdoms": ["endure", "pride"], "priority": ""},
	{"name": "respect+prepare", "wisdoms": ["respect", "prepare"], "priority": ""},
	{"name": "respect+pride", "wisdoms": ["respect", "pride"], "priority": ""},
	{"name": "prepare+pride", "wisdoms": ["prepare", "pride"], "priority": ""},
	# Stacking: a priority alone, and with a pair it reinforces (cooperation, We Endure Together) or
	# pulls against (investment before winter, Prepare for Hard Times; with Pride, which it reinforces).
	{"name": "cooperation", "wisdoms": [], "priority": CommunityPriority.COOPERATION},
	{"name": "endure+respect|cooperation", "wisdoms": ["endure", "respect"], "priority": CommunityPriority.COOPERATION},
	{"name": "investment", "wisdoms": [], "priority": CommunityPriority.INVESTMENT},
	{"name": "food", "wisdoms": [], "priority": CommunityPriority.FOOD},
	{"name": "prepare+pride|investment", "wisdoms": ["prepare", "pride"], "priority": CommunityPriority.INVESTMENT},
	# The Elder's third slot: the same pair, with a third wisdom chosen the day the town is a Village.
	{"name": "endure+respect>pride", "wisdoms": ["endure", "respect"], "priority": "", "village": "pride"},
	{"name": "endure+respect>prepare", "wisdoms": ["endure", "respect"], "priority": "", "village": "prepare"},
]
const DIFFICULT_POOL_REGIONS: int = 30
const REFERENCE_DAYS: int = 720
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const SNAPSHOT_YEAR: int = 3
# The second autumn: a town past founding, before its second winter.
const DISRUPT_DAY: int = 540
const DISRUPT_STORE_LOSS: float = 0.8

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 6
	var site_count: int = 12
	var conditions: Array[String] = ["ordinary", "stressed", "difficult"]
	var only: Array[String] = []
	var prepare: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--strategies="):
			only.assign(argument.trim_prefix("--strategies=").split(","))
		elif argument == "--prepare-difficult":
			prepare = true
		elif argument == "--no-reconsider":
			reconsider = false
		elif argument.begins_with("--change-limit="):
			change_limit = int(argument.trim_prefix("--change-limit="))
		elif argument == "--no-self-sufficiency":
			self_sufficiency = false
		elif argument == "--no-proficiency-effects":
			economy_meta = "economy_no_proficiency_effects"
		elif argument == "--no-secondary":
			economy_meta = "economy_no_secondary"
		elif argument.begins_with("--disrupt="):
			disrupt = argument.trim_prefix("--disrupt=")
		elif argument.begins_with("--meta="):
			metas.assign(argument.trim_prefix("--meta=").split(","))
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	if prepare:
		pick_difficult_sites(ordinary, site_count)
		quit()
		return
	for condition: String in conditions:
		var sites: Array = get_difficult_sites(ordinary, site_count) if condition == "difficult" else ordinary
		var stress: bool = condition == "stressed"
		for strategy: Dictionary in STRATEGIES:
			if not only.is_empty() and not only.has(str(strategy["name"])):
				continue
			var started: int = Time.get_ticks_msec()
			if not reconsider:
				_report("   (families do not reconsider their work)")
			var snapshots: Dictionary = {SNAPSHOT_YEAR: [], years: []}
			for site: Dictionary in sites:
				var result: Dictionary = play(site, strategy, stress, years)
				for year: int in snapshots.keys():
					var measured: Dictionary = result["years"][year]
					(snapshots[year] as Array).append(measured)
					_report("TOWN %s | %s | year %d | seed %d | %s" % [condition, strategy["name"], year, int(site["seed"]), JSON.stringify(measured)])
			for year: int in snapshots.keys():
				summarize(condition, str(strategy["name"]), year, snapshots[year])
			_report("   (%s %s took %.0f s)" % [condition, strategy["name"], (Time.get_ticks_msec() - started) / 1000.0])
	quit()

var reconsider: bool = true
var change_limit: int = -1
var self_sufficiency: bool = true
var disrupt: String = ""
# Comparison only: proficiency tracked but without effect on output or choices, or no secondary work.
var economy_meta: String = ""
# Comparison only: switches set on each town before its first day (occupation_check's modes, e.g.
# "occupations_first_three,no_shortage_recognition" for the behaviour before autonomous occupations).
var metas: Array[String] = []

func play(site: Dictionary, strategy: Dictionary, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	# Before the first day, so a town compared without it never runs it.
	city.influence.self_sufficiency = self_sufficiency
	if economy_meta != "":
		city.set_meta(economy_meta, true)
	for meta: String in metas:
		city.set_meta(meta, true)
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var measured: Dictionary = {}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0:
			town.influence.reconsider_work = reconsider
			town.influence.self_sufficiency = self_sufficiency
			if change_limit >= 0:
				town.set_meta("work_change_limit", change_limit)
			for key: String in strategy["wisdoms"]:
				GuidingWisdom.choose(town, W[key])
			if str(strategy["priority"]) != "":
				town.influence.set_priority(str(strategy["priority"]))
		if strategy.has("village") and GuidingWisdom.choose(town, W[strategy["village"]]):
			town.set_meta("third_wisdom_day", day)
		# Each month: tools short (under 10) while proper workplaces need upkeep.
		if day % 30 == 29 and int(town.resources["tools"]) < 10 and town.buildings.any(func(b: Building) -> bool: return b.needs_maintenance()):
			town.set_meta("tools_short_months", int(town.get_meta("tools_short_months", 0)) + 1)
			town.set_meta("last_tools_short_day", day)
		if day == DISRUPT_DAY and disrupt != "":
			disrupt_town(town)
		if day == SNAPSHOT_YEAR * Calendar.DAYS_PER_YEAR - 1:
			measured[SNAPSHOT_YEAR] = measure(town)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	measured[years] = measure(city)
	measured[years]["off_the_ground"] = bool(result["off_the_ground"])
	if not measured.has(SNAPSHOT_YEAR):
		measured[SNAPSHOT_YEAR] = measured[years]
	return {"years": measured}

# The test's shock, identical with the system on and off: the town's toolmakers leave (their
# workplaces stay, open to others), or the common stores lose most of what they hold (larders kept).
func disrupt_town(city: City) -> void:
	if disrupt == "specialist":
		var leaving: Array[Household] = []
		for household: Household in city.households:
			var holding: Building = FamilyInitiative.get_holding(city, household)
			if holding != null and FamilyInitiative.get_activity(holding.type) == TownInfluence.ACTIVITY_TOOLS:
				leaving.append(household)
		for household: Household in leaving:
			HouseholdMigration.release_departing_household_work(city, household, 0)
			city.households.erase(household)
		city.update_shelter_counts()
		city.auto_assign_workers()
		city.set_meta("disrupted_families", leaving.size())
	elif disrupt == "stores":
		for good: String in ["food", "wood", "tools"]:
			city.resources[good] = int(round(float(int(city.resources[good])) * (1.0 - DISRUPT_STORE_LOSS)))
	city.set_meta("disrupted_people", city.get_total_population())

# One town at one moment: what its families are like, what they did, and how the town fares.
func measure(city: City) -> Dictionary:
	var social: TownSocial = city.social
	var households: Array = city.households
	var n: float = maxf(1.0, households.size())
	var m: Dictionary = {}
	m["people"] = city.get_total_population()
	m["households"] = households.size()
	m["kept_families"] = 1 if households.size() >= EconomyBalance.FOUNDING_FAMILIES else 0
	m["village"] = 1 if city.settlement.stage >= SettlementStage.VILLAGE else 0
	m["wisdoms"] = city.social.wisdoms.size()
	m["third_wisdom_day"] = int(city.get_meta("third_wisdom_day", -1))
	# Families reconsidering their work (OccupationReview).
	var influence: TownInfluence = city.influence
	m["work_reviews"] = influence.work_reviews
	m["work_changes"] = influence.work_changes
	m["work_deferred"] = influence.work_deferred
	m["left_proper"] = influence.workplaces_left_proper
	m["left_empty"] = influence.workplaces_left_empty
	m["work_triggers"] = influence.work_triggers.duplicate()
	m["swayed_work"] = int(influence.swayed.get("%s:work" % influence.priority, 0))
	var changed_families: int = 0
	var twice: int = 0
	var back: int = 0
	for household: Household in households:
		var history: Array = household.work_history
		changed_families += 1 if history.size() >= 2 else 0
		twice += 1 if history.size() >= 3 else 0
		for i in range(2, history.size()):
			back += 1 if history[i] == history[i - 2] else 0
	m["changed_families"] = changed_families
	m["changed_twice"] = twice
	m["changed_back"] = back
	var vacant: Dictionary = {}
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_household_id < 0 and FamilyInitiative.get_activity(building.type) != "":
			var key: String = ("proper_" if building.needs_maintenance() else "hand_") + FamilyInitiative.get_activity(building.type)
			vacant[key] = int(vacant.get(key, 0)) + 1
	m["vacant"] = vacant
	m["toolmakers_worked"] = city.buildings.filter(func(b: Building) -> bool: return FamilyInitiative.get_activity(b.type) == TownInfluence.ACTIVITY_TOOLS and b.assigned_household_id >= 0).size()
	m["tools_short_months"] = int(city.get_meta("tools_short_months", 0))
	m["last_tools_short_day"] = int(city.get_meta("last_tools_short_day", -1))
	m["review_log"] = influence._work_review_log.duplicate(true)
	m["departed"] = int(city.resources.get("departed_households", 0))
	var trust: float = 0.0
	var unhoused: int = 0
	for household: Household in households:
		trust += household.trust
		unhoused += 1 if household.housing_status != Household.RESIDENCE_HOUSED else 0
	m["trust"] = trust / n
	m["unhoused"] = unhoused
	m["food_days"] = FamilyInitiative.get_food_days(city)
	m["tools"] = int(city.resources["tools"])
	m["wood"] = int(city.resources["wood"])
	m["food"] = int(city.resources["food"])
	m["disrupted_families"] = int(city.get_meta("disrupted_families", 0))
	m["disrupted_people"] = int(city.get_meta("disrupted_people", -1))
	# Household self-sufficiency and proficiency (HouseholdEconomy).
	m["primary_share_days"] = influence.primary_share_days
	m["secondary_share_days"] = influence.secondary_share_days.duplicate()
	m["secondary_output"] = influence.secondary_output.duplicate()
	m["lost_primary_output"] = influence.lost_primary_output.duplicate()
	m["wood_to_own_projects"] = influence.wood_to_own_projects
	m["mended_upkeep"] = influence.mended_upkeep
	m["larder_eaten_own"] = influence.larder_eaten_own
	m["larder_eaten_short"] = influence.larder_eaten_short
	m["household_short_days"] = influence.household_short_days
	m["food_gifts"] = influence.food_gifts
	var larder: float = 0.0
	var larder_days: Array = []
	var secondary: Dictionary = {}
	var targets: Dictionary = {}
	var working_levels: Array = []
	var novices: int = 0
	var known: int = 0
	var by_value: Dictionary = {}
	for household: Household in households:
		larder += household.larder
		larder_days.append(HouseholdEconomy.get_larder_days(household))
		if household.secondary_share > 0.0:
			secondary[household.secondary_activity] = int(secondary.get(household.secondary_activity, 0)) + 1
		targets[str(household.larder_target_days)] = int(targets.get(str(household.larder_target_days), 0)) + 1
		known += household.proficiency.size()
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null:
			var level: float = HouseholdEconomy.get_level(household, holding.type)
			working_levels.append(level)
			novices += 1 if level < HouseholdEconomy.ESTABLISHED else 0
		# Families by conviction: their time and larders.
		for value_id: String in ["self_reliant", "thrifty", "common_stores", "sharing"]:
			if HouseholdCharacter.get_strength(household, value_id) > 0:
				var row: Dictionary = by_value.get(value_id, {"families": 0, "secondary": 0.0, "larder_target": 0.0})
				row["families"] = int(row["families"]) + 1
				row["secondary"] = float(row["secondary"]) + household.secondary_share
				row["larder_target"] = float(row["larder_target"]) + household.larder_target_days
				by_value[value_id] = row
	m["larder_food"] = larder
	larder_days.sort()
	m["larder_days_median"] = float(larder_days[larder_days.size() / 2]) if not larder_days.is_empty() else 0.0
	m["families_secondary"] = secondary
	m["larder_targets"] = targets
	working_levels.sort()
	m["working_level_median"] = float(working_levels[working_levels.size() / 2]) if not working_levels.is_empty() else 0.0
	m["working_novices"] = novices
	m["trades_known_per_family"] = known / n
	m["by_value"] = by_value
	m["proper_workplaces"] = city.buildings.filter(func(b: Building) -> bool: return b.needs_maintenance()).size()
	m["improvements"] = city.influence.improvements_started
	m["help_weeks"] = social.help_weeks
	m["shares"] = social.shares
	m["share_requests"] = social.share_requests
	m["disputes_raised"] = social.disputes_raised
	m["disputes_unsettled"] = social.dispute_pressure
	m["land_contests"] = social.land_contests
	m["long_day_weeks"] = social.long_day_weeks
	m["value_changes"] = social.value_changes
	m["shortage_days"] = int(city.resources.get("shortage_days_this_month", 0))
	for norm_id: String in TownSocial.NORM_IDS:
		m["acceptance_" + norm_id] = float(social.norms[norm_id]["acceptance"])
	# Share of families holding each quality and counter-quality, and their mean strength.
	var seen: Dictionary = {}
	for wisdom: String in GuidingWisdom.ALL:
		for value_id: String in (GuidingWisdom.QUALITIES[wisdom] as Array) + (GuidingWisdom.COUNTER_QUALITIES[wisdom] as Array):
			if seen.has(value_id):
				continue
			seen[value_id] = true
			var holders: int = 0
			var total: int = 0
			for household: Household in households:
				var strength: int = HouseholdCharacter.get_strength(household, value_id)
				holders += 1 if strength > 0 else 0
				total += strength
			m["hold_" + value_id] = holders / n
			m["strength_" + value_id] = total / n
	for wisdom: String in social.wisdom_record.keys():
		var record: Dictionary = social.wisdom_record[wisdom]
		for key: String in ["followed", "declined", "lived", "own_way"]:
			m["%s_%s" % [wisdom, key]] = int(record.get(key, 0))
	return m

func summarize(condition: String, name: String, year: int, rows: Array) -> void:
	var avg: Callable = func(key: String) -> float:
		var total: float = 0.0
		for row: Dictionary in rows:
			total += float(row.get(key, 0.0))
		return total / maxf(1.0, rows.size())
	var kept: int = rows.filter(func(row: Dictionary) -> bool: return int(row["kept_families"]) == 1).size()
	var line: String = "%-9s %-28s y%d | kept %2d/%d | people %5.1f | families %4.1f | departed %4.1f | trust %+.2f | help wks %5.1f | shares %4.1f/%4.1f | disputes %4.1f (unsettled %4.1f) | long-day wks %5.1f | improvements %4.1f | proper %4.1f | food d %5.0f | tools %5.0f | value changes %5.1f" % [
		condition, name, year, kept, rows.size(), avg.call("people"), avg.call("households"), avg.call("departed"), avg.call("trust"), avg.call("help_weeks"),
		avg.call("shares"), avg.call("share_requests"), avg.call("disputes_raised"), avg.call("disputes_unsettled"), avg.call("long_day_weeks"), avg.call("improvements"), avg.call("proper_workplaces"), avg.call("food_days"), avg.call("tools"), avg.call("value_changes")]
	_report(line)
	var culture: Array[String] = []
	for value_id: String in ["mutual_aid", "communal_labor", "self_governing", "solitary", "respect_for_holdings", "private_holdings", "common_stores", "sharing", "thrifty", "fatalistic", "hopeful", "perfectionist", "keepers_of_craft", "expedient"]:
		culture.append("%s %.0f%%" % [value_id, avg.call("hold_" + value_id) * 100.0])
	_report("%-9s %-28s y%d | holding: %s" % [condition, name, year, ", ".join(culture)])
	var norms: Array[String] = []
	for norm_id: String in TownSocial.NORM_IDS:
		norms.append("%s %.2f" % [norm_id, avg.call("acceptance_" + norm_id)])
	var conduct: Array[String] = []
	for wisdom: String in GuidingWisdom.ALL:
		if avg.call(wisdom + "_followed") + avg.call(wisdom + "_declined") > 0.0:
			conduct.append("%s kept %.0f / own way %.0f, lessons %.1f / %.1f" % [wisdom, avg.call(wisdom + "_followed"), avg.call(wisdom + "_declined"), avg.call(wisdom + "_lived"), avg.call(wisdom + "_own_way")])
	_report("%-9s %-28s y%d | customs: %s | conduct: %s" % [condition, name, year, ", ".join(norms), "; ".join(conduct) if not conduct.is_empty() else "-"])

# Difficult sites (as priority_check picks them), cached by seed.
func get_difficult_sites(ordinary: Array, count: int) -> Array:
	if not FileAccess.file_exists(DIFFICULT_CACHE):
		return pick_difficult_sites(ordinary, count)
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

func pick_difficult_sites(ordinary: Array, count: int) -> Array:
	var used: Dictionary = {}
	for site: Dictionary in ordinary:
		used[int(site["seed"])] = true
	var pool: Array = []
	for site: Dictionary in TownBuildingCheck.collect_sites(DIFFICULT_POOL_REGIONS, 2):
		if used.has(int(site["seed"])):
			continue
		var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
		city.site_profile = site["profile"]
		city.local_map = (site["map"] as Array).duplicate(true)
		site["reference"] = StandInPlayerScript.new().play(city, {}, REFERENCE_DAYS)
		pool.append(site)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ok: bool = a["reference"]["off_the_ground"]
		var b_ok: bool = b["reference"]["off_the_ground"]
		if a_ok != b_ok:
			return not a_ok
		return int(a["reference"]["population"]) < int(b["reference"]["population"]))
	var picked: Array = pool.slice(0, count)
	var file: FileAccess = FileAccess.open(DIFFICULT_CACHE, FileAccess.WRITE)
	for site: Dictionary in picked:
		file.store_line(str(int(site["seed"])))
	file.close()
	_report("difficult sites cached: %s" % ", ".join(picked.map(func(s: Dictionary) -> String: return str(int(s["seed"])))))
	return picked

func _report(line: String) -> void:
	print("[WIS] " + line)
