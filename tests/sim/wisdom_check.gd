extends SceneTree

# Guiding wisdom check (docs/GUIDING_WISDOM.md): the same towns, seeds and founders under no wisdom
# and each of the six pairs of the four starting wisdoms, chosen at founding and kept; and two pairs
# stacked with a community priority (one that reinforces, one that pulls against a wisdom) beside
# those priorities alone. Families lead, the social model is on, starting residential land; the
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
# Options: --years=N (default 6, with a year-3 snapshot), --sites=N, --prepare-difficult (pick and cache).

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
	{"name": "prepare+pride|investment", "wisdoms": ["prepare", "pride"], "priority": CommunityPriority.INVESTMENT},
]
const DIFFICULT_POOL_REGIONS: int = 30
const REFERENCE_DAYS: int = 720
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const SNAPSHOT_YEAR: int = 3

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

func play(site: Dictionary, strategy: Dictionary, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var measured: Dictionary = {}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0:
			for key: String in strategy["wisdoms"]:
				GuidingWisdom.choose(town, W[key])
			if str(strategy["priority"]) != "":
				town.influence.set_priority(str(strategy["priority"]))
		if day == SNAPSHOT_YEAR * Calendar.DAYS_PER_YEAR - 1:
			measured[SNAPSHOT_YEAR] = measure(town)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	measured[years] = measure(city)
	measured[years]["off_the_ground"] = bool(result["off_the_ground"])
	if not measured.has(SNAPSHOT_YEAR):
		measured[SNAPSHOT_YEAR] = measured[years]
	return {"years": measured}

# One town at one moment: what its families are like, what they did, and how the town fares.
func measure(city: City) -> Dictionary:
	var social: TownSocial = city.social
	var households: Array = city.households
	var n: float = maxf(1.0, households.size())
	var m: Dictionary = {}
	m["people"] = city.get_total_population()
	m["households"] = households.size()
	m["kept_families"] = 1 if households.size() >= EconomyBalance.FOUNDING_FAMILIES else 0
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
