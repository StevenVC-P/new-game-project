extends SceneTree

# Autonomous occupations and essential shortages (docs/AUTONOMOUS_OCCUPATIONS.md): the same towns,
# seeds and founders under four modes, families leading and the social model on, the stand-in player
# building only homes and shared works (as wisdom_check):
#
# - existing: families choose among the first three trades and never see a shortage coming;
# - occupations: every trade with a hand-work stage (fishing, hunting, herding) is a family's choice;
# - shortage: families see an essential shortage coming and look at their work again early;
# - both.
#
# Measured at three and six years: the trades families work (and which callings chose them), how
# varied and how improved the town's work is, food and clothing going short, tools running out and
# whether the town recovers, families and people kept, and families' reviews of their work.
#
# One condition and some modes per process (write to a file, filter for [OCC]):
#   <godot> --headless --path . --script res://tests/sim/occupation_check.gd -- --conditions=ordinary --modes=existing,both > occ.log
# Options: --years=N (6, with a year-3 snapshot), --sites=N (12), --priority=investment|food|...,
# --leave-out=herder,hunter (trades families may not choose, to tell their effects apart).
# Conditions as in wisdom_check: ordinary sites; the same with the first winter's stores lost;
# naturally difficult sites (cached in user://wisdom_difficult_seeds.txt by wisdom_check).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const MODES: Dictionary = {
	"existing": ["occupations_first_three", "no_shortage_recognition"],
	"occupations": ["no_shortage_recognition"],
	"shortage": ["occupations_first_three"],
	"both": [],
	# Shortage recognition counting only goods no one makes (the brief's tool gap), not deficits.
	"both_narrow": ["shortage_missing_trade_only"],
	"shortage_narrow": ["occupations_first_three", "shortage_missing_trade_only"],
}
const SNAPSHOT_YEAR: int = 3
const DIFFICULT_POOL_REGIONS: int = 30
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const TRADES: Array[String] = ["farm", "woodcutter", "toolmaker", "fisher", "hunter", "herder"]

var priority: String = ""
# Comparison only: trades families may not choose, to tell each one's effect apart.
var left_out: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 6
	var site_count: int = 12
	var conditions: Array[String] = ["ordinary", "stressed", "difficult"]
	var modes: Array[String] = ["existing", "occupations", "shortage", "both"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--modes="):
			modes.assign(argument.trim_prefix("--modes=").split(","))
		elif argument.begins_with("--priority="):
			priority = argument.trim_prefix("--priority=")
		elif argument.begins_with("--leave-out="):
			left_out.assign(argument.trim_prefix("--leave-out=").split(","))
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	for condition: String in conditions:
		var sites: Array = get_difficult_sites() if condition == "difficult" else ordinary
		for mode: String in modes:
			var started: int = Time.get_ticks_msec()
			var snapshots: Dictionary = {SNAPSHOT_YEAR: [], years: []}
			for site: Dictionary in sites:
				var result: Dictionary = play(site, mode, condition == "stressed", years)
				for year: int in snapshots.keys():
					(snapshots[year] as Array).append(result[year])
					_report("TOWN %s | %s | year %d | seed %d | %s" % [condition, mode, year, int(site["seed"]), JSON.stringify(result[year])])
			for year: int in snapshots.keys():
				summarize(condition, mode, year, snapshots[year])
			_report("   (%s %s took %.0f s)" % [condition, mode, (Time.get_ticks_msec() - started) / 1000.0])
	quit()

func play(site: Dictionary, mode: String, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	# Before the first day: founders choose their work on it.
	for meta: String in MODES[mode]:
		city.set_meta(meta, true)
	if not left_out.is_empty():
		city.set_meta("occupations_left_out", left_out)
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var measured: Dictionary = {}
	var track: Dictionary = {
		"first_day": {}, "tools_short_months": 0, "tools_out_days": 0, "tool_work_days": 0,
		"first_tools_short_day": -1, "tool_work_after_short_day": -1, "recovered_day": -1,
		"food_short_days": 0, "clothing_unmet_months": 0, "clothing_met_months": 0, "danger_months": 0,
	}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0 and priority != "":
			town.influence.set_priority(priority)
		var upkeep: bool = town.buildings.any(func(b: Building) -> bool: return b.needs_maintenance())
		var tools: int = int(town.resources["tools"])
		var making_tools: bool = FamilyInitiative.count_producers(town, TownInfluence.ACTIVITY_TOOLS) > 0
		track["food_short_days"] = int(track["food_short_days"]) + (1 if town.resources["food_shortage"] == true else 0)
		if upkeep and tools == 0:
			track["tools_out_days"] = int(track["tools_out_days"]) + 1
		track["tool_work_days"] = int(track["tool_work_days"]) + (1 if making_tools else 0)
		# A tool shortage: under 10 tools while workplaces need upkeep. Recovery: tool work begun after
		# it, and the store back above 10.
		if upkeep and tools < 10 and int(track["first_tools_short_day"]) < 0:
			track["first_tools_short_day"] = day
		if int(track["first_tools_short_day"]) >= 0:
			if making_tools and int(track["tool_work_after_short_day"]) < 0:
				track["tool_work_after_short_day"] = day
			if tools >= 10 and int(track["recovered_day"]) < 0 and day > int(track["first_tools_short_day"]):
				track["recovered_day"] = day
		for building: Building in town.buildings:
			if building.assigned_household_id >= 0 and not (track["first_day"] as Dictionary).has(building.type):
				track["first_day"][building.type] = day
		if day % 30 == 29:
			if upkeep and tools < 10:
				track["tools_short_months"] = int(track["tools_short_months"]) + 1
			if OccupationReview.get_danger(town, "") >= OccupationReview.SHORTAGE_TRIGGER:
				track["danger_months"] = int(track["danger_months"]) + 1
			var status: String = str(town.get_clothing_need_pressure().get("status", ""))
			track["clothing_unmet_months"] = int(track["clothing_unmet_months"]) + (1 if status == "unmet" or status == "low" else 0)
			track["clothing_met_months"] = int(track["clothing_met_months"]) + (1 if status == "met" else 0)
		if day == SNAPSHOT_YEAR * Calendar.DAYS_PER_YEAR - 1:
			measured[SNAPSHOT_YEAR] = measure(town, track)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	measured[years] = measure(city, track)
	measured[years]["off_the_ground"] = bool(result["off_the_ground"])
	if not measured.has(SNAPSHOT_YEAR):
		measured[SNAPSHOT_YEAR] = measured[years]
	return measured

func measure(city: City, track: Dictionary) -> Dictionary:
	var m: Dictionary = track.duplicate(true)
	var influence: TownInfluence = city.influence
	m["people"] = city.get_total_population()
	m["households"] = city.households.size()
	m["kept_families"] = 1 if city.households.size() >= EconomyBalance.FOUNDING_FAMILIES else 0
	m["departed"] = int(city.resources.get("departed_households", 0))
	m["village"] = 1 if city.settlement.stage >= SettlementStage.VILLAGE else 0
	# The work families do: by trade and tier, and which callings chose which trade.
	var worked: Dictionary = {}
	var proper: Dictionary = {}
	var by_calling: Dictionary = {}
	var by_risk: Dictionary = {"cautious": [0, 0], "even": [0, 0], "daring": [0, 0]}
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding == null:
			continue
		var trade: String = BuildingTiers.get_base_type(holding.type)
		worked[trade] = int(worked.get(trade, 0)) + 1
		if not holding.is_tier0():
			proper[trade] = int(proper.get(trade, 0)) + 1
		var callings: Array = CultureEffects.get_callings(household.values)
		var key: String = "%s>%s" % [str(callings[0]) if not callings.is_empty() else "none", trade]
		by_calling[key] = int(by_calling.get(key, 0)) + 1
		var risk: int = HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK)
		var row: Array = by_risk["cautious" if risk < 0 else "daring" if risk > 0 else "even"]
		row[0] = int(row[0]) + 1
		row[1] = int(row[1]) + (0 if holding.is_tier0() else 1)
	m["worked"] = worked
	m["proper"] = proper
	m["trades"] = worked.size()
	m["by_calling"] = by_calling
	m["by_risk"] = by_risk
	m["proper_workplaces"] = city.buildings.filter(func(b: Building) -> bool: return b.needs_maintenance()).size()
	m["improvements"] = influence.improvements_started
	m["opened"] = influence.workplaces_opened
	m["held_back"] = influence.held_back_by_stores
	m["food_days"] = FamilyInitiative.get_food_days(city)
	m["household_short_days"] = influence.household_short_days
	m["tools"] = int(city.resources["tools"])
	m["wool"] = int(city.resources.get("wool", 0))
	m["clothing_status"] = str(city.get_clothing_need_pressure().get("status", ""))
	m["work_reviews"] = influence.work_reviews
	m["work_changes"] = influence.work_changes
	m["work_triggers"] = influence.work_triggers.duplicate()
	var shortage_changes: int = 0
	var shortage_reviews: int = 0
	var changed_to: Dictionary = {}
	for entry: Dictionary in influence._work_review_log:
		if entry.has("deferred"):
			continue
		var for_shortage: bool = (entry["triggers"] as Array).has(OccupationReview.SHORTAGE)
		shortage_reviews += 1 if for_shortage else 0
		if bool(entry["changed"]):
			changed_to[str(entry["to"])] = int(changed_to.get(str(entry["to"]), 0)) + 1
			shortage_changes += 1 if for_shortage else 0
	m["shortage_reviews"] = shortage_reviews
	m["shortage_changes"] = shortage_changes
	m["changed_to"] = changed_to
	m["swayed_work"] = int(influence.swayed.get("%s:work" % influence.priority, 0))
	return m

func summarize(condition: String, mode: String, year: int, rows: Array) -> void:
	var n: float = maxf(1.0, rows.size())
	var avg: Callable = func(key: String) -> float:
		var total: float = 0.0
		for row: Dictionary in rows:
			total += float(row.get(key, 0.0))
		return total / n
	var kept: int = rows.filter(func(r: Dictionary) -> bool: return int(r["kept_families"]) == 1).size()
	var short_towns: int = rows.filter(func(r: Dictionary) -> bool: return int(r["first_tools_short_day"]) >= 0).size()
	var answered: int = rows.filter(func(r: Dictionary) -> bool: return int(r["first_tools_short_day"]) >= 0 and int(r["tool_work_after_short_day"]) >= 0).size()
	var recovered: int = rows.filter(func(r: Dictionary) -> bool: return int(r["recovered_day"]) >= 0).size()
	var never_tools: int = rows.filter(func(r: Dictionary) -> bool: return int(r["tool_work_days"]) == 0).size()
	_report("%-9s %-11s y%d | kept %2d/%d | people %5.1f | families %4.1f | departed %4.1f | food short d %5.1f | hh short d %6.1f | clothing unmet mo %4.1f | wool %5.1f" % [
		condition, mode, year, kept, rows.size(), avg.call("people"), avg.call("households"), avg.call("departed"), avg.call("food_short_days"), avg.call("household_short_days"), avg.call("clothing_unmet_months"), avg.call("wool")])
	_report("%-9s %-11s y%d | tools short mo %4.1f | out d %5.1f | towns short %d, tool work after %d, recovered %d, never tool work %d | tools %5.0f | danger mo %4.1f | reviews %4.1f (shortage %4.1f) | changes %4.1f (shortage %4.1f)" % [
		condition, mode, year, avg.call("tools_short_months"), avg.call("tools_out_days"), short_towns, answered, recovered, never_tools, avg.call("tools"), avg.call("danger_months"), avg.call("work_reviews"), avg.call("shortage_reviews"), avg.call("work_changes"), avg.call("shortage_changes")])
	var worked: Array[String] = []
	var proper: Array[String] = []
	var towns_with: Array[String] = []
	for trade: String in TRADES:
		var total: int = 0
		var improved: int = 0
		var towns: int = 0
		for row: Dictionary in rows:
			total += int((row["worked"] as Dictionary).get(trade, 0))
			improved += int((row["proper"] as Dictionary).get(trade, 0))
			towns += 1 if int((row["worked"] as Dictionary).get(trade, 0)) > 0 else 0
		worked.append("%s %.1f" % [trade, total / n])
		proper.append("%s %d/%d" % [trade, improved, total])
		towns_with.append("%s %d" % [trade, towns])
	_report("%-9s %-11s y%d | trades %.1f | worked per town: %s | improved: %s | towns working: %s | improvements %4.1f | proper %4.1f" % [
		condition, mode, year, avg.call("trades"), ", ".join(worked), ", ".join(proper), ", ".join(towns_with), avg.call("improvements"), avg.call("proper_workplaces")])
	var callings: Dictionary = {}
	var risk: Dictionary = {"cautious": [0, 0], "even": [0, 0], "daring": [0, 0]}
	for row: Dictionary in rows:
		for key: String in (row["by_calling"] as Dictionary).keys():
			callings[key] = int(callings.get(key, 0)) + int(row["by_calling"][key])
		for key: String in risk.keys():
			risk[key][0] += int(row["by_risk"][key][0])
			risk[key][1] += int(row["by_risk"][key][1])
	var keys: Array = callings.keys()
	keys.sort()
	_report("%-9s %-11s y%d | calling>trade: %s | improved by temperament: cautious %d/%d, even %d/%d, daring %d/%d" % [
		condition, mode, year, ", ".join(keys.map(func(k: String) -> String: return "%s %d" % [k, callings[k]])), risk["cautious"][1], risk["cautious"][0], risk["even"][1], risk["even"][0], risk["daring"][1], risk["daring"][0]])

# Difficult sites as wisdom_check chose and cached them (run it with --prepare-difficult first).
func get_difficult_sites() -> Array:
	var by_seed: Dictionary = {}
	for site: Dictionary in TownBuildingCheck.collect_sites(DIFFICULT_POOL_REGIONS, 2):
		by_seed[int(site["seed"])] = site
	var picked: Array = []
	for line: String in FileAccess.get_file_as_string(DIFFICULT_CACHE).split("\n", false):
		picked.append(by_seed[int(line)])
	return picked

func _report(line: String) -> void:
	print("[OCC] " + line)
