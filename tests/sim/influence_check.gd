extends SceneTree

# Influence check (docs/FAMILY_INFLUENCE_PROTOTYPE.md): can a town that families develop, with the
# player influencing them, do as well as one the player builds directly, and do its families
# decide differently for their own reasons? Plays the planning check's 20 real town sites for five
# years. Three industries only (food from fields, wood, tools): no fisher's huts, lodges, or folds
# in any policy, so the policies differ only in who decides.
#
# - direct, today: the planning check's planned town (the player plans every building), today's
#   rules for workplaces short of tools (they stand idle);
# - direct: the same, with proper workplaces working by hand when short of tools;
# - families: families take up and improve their own work; the player only sets home plots aside
#   and plans the public works (fences, storehouses); stores open above the protected reserve;
# - guided: families, and the player keeps the stores for the community's priorities and asks for
#   what the town is short of (StandInPlayer.guide);
# - guided, scattered: guided, with home plots set aside far from the heart, so families open
#   their work far out too.
#
# Reports the planning check's figures, the player's decisions, what families did, and when the
# founding families first decided to improve their work, by temperament.
# Run: <godot> --headless --path . --script res://tests/sim/influence_check.gd > log; then filter
# for [INFL] (write to a file: a shell pipe stalls Godot on Windows). `-- --years=N` shortens it.

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const THREE_INDUSTRIES: Dictionary = {"land_food": false, "never": ["herder", "fisher", "hunter"]}
const POLICIES: Array = [
	{"name": "direct, today", "planned": true},
	{"name": "direct", "planned": true, "hand_method": true},
	{"name": "families", "planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true},
	{"name": "guided", "planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true, "guided": true},
	{"name": "guided, scattered", "planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true, "guided": true, "scattered": true},
]

# `-- --bottleneck`: why do towns families develop grow more slowly? Separates homes only on plots
# from every family taking up work at once (no one left free to build).
const BOTTLENECK_POLICIES: Array = [
	{"name": "direct", "planned": true, "hand_method": true},
	{"name": "direct, plots", "planned": true, "hand_method": true, "homes_on_plots": true},
	{"name": "families", "planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true},
	{"name": "families, houses", "planned": true, "hand_method": true, "families_develop": true},
	{"name": "families, builder", "planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true, "reserved_builders": 1},
	{"name": "families, both", "planned": true, "hand_method": true, "families_develop": true, "reserved_builders": 1},
]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 5
	var policies: Array = POLICIES
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument == "--bottleneck":
			policies = BOTTLENECK_POLICIES
	var days: int = years * Calendar.DAYS_PER_YEAR
	var sites: Array = TownBuildingCheck.collect_sites()
	_report("%d towns on real town maps, %d days (%d years)" % [sites.size(), days, years])
	for policy: Dictionary in policies:
		var scenario: Dictionary = policy.duplicate()
		scenario.merge(THREE_INDUSTRIES)
		var results: Array[Dictionary] = []
		for site: Dictionary in sites:
			var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
			city.site_profile = site["profile"]
			city.local_map = (site["map"] as Array).duplicate(true)
			results.append(StandInPlayerScript.new().play(city, scenario, days))
		summarize(policy["name"], results, years)
	quit()

func summarize(policy_name: String, results: Array[Dictionary], years: int) -> void:
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var keys: Array[String] = ["population", "households", "travel_share", "food", "player_actions", "opened_by_families", "improvements_by_families", "held_back_by_stores", "proper_workplaces", "hand_workplaces", "working_by_hand", "workplace_spread", "content"]
	var totals: Dictionary = {}
	for key: String in keys:
		totals[key] = 0.0
	var villages: Array[int] = []
	var hamlets: Array[int] = []
	var reasons: Dictionary = {}
	var groups: Dictionary = {}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in keys:
			totals[key] = float(totals[key]) + float(result[key])
		if int(result["village_day"]) >= 0:
			villages.append(int(result["village_day"]))
		if int(result["hamlet_day"]) >= 0:
			hamlets.append(int(result["hamlet_day"]))
		for reason: String in result["reasons"]:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		var founders: Dictionary = result["founder_improvements"]
		for group: String in founders.keys():
			if not groups.has(group):
				groups[group] = []
			(groups[group] as Array).append_array(founders[group])
	var avg: Callable = func(key: String) -> float: return float(totals[key]) / n
	_report("%-17s %2d/%d off the ground | people %.0f | households %.1f | travel %.0f%% | food in store %.0f | content families %.1f" % [
		policy_name, made_it, results.size(), avg.call("population"), avg.call("households"), avg.call("travel_share") * 100.0, avg.call("food"), avg.call("content")])
	villages.sort()
	hamlets.sort()
	_report("%-17s hamlet %d/%d (median day %d) | village %d/%d (median year %.1f) | problems: %s" % [
		policy_name, hamlets.size(), results.size(), median(hamlets), villages.size(), results.size(), float(median(villages)) / float(Calendar.DAYS_PER_YEAR), str(reasons)])
	_report("%-17s player decisions %.0f (%.0f a year) | families opened %.1f, improved %.1f, held back by the stores %.1f | proper workplaces %.1f, hand work %.1f, working by hand for want of tools %.1f | workplaces %.1f tiles from the stockpile" % [
		policy_name, avg.call("player_actions"), avg.call("player_actions") / float(years), avg.call("opened_by_families"), avg.call("improvements_by_families"), avg.call("held_back_by_stores"), avg.call("proper_workplaces"), avg.call("hand_workplaces"), avg.call("working_by_hand"), avg.call("workplace_spread")])
	var group_lines: Array[String] = []
	for group: String in ["daring", "cautious", "traditionalist", "other"]:
		var days: Array = groups.get(group, [])
		var decided: Array[int] = []
		for day in days:
			if int(day) >= 0:
				decided.append(int(day))
		decided.sort()
		var first_year: int = decided.filter(func(day: int) -> bool: return day < Calendar.DAYS_PER_YEAR).size()
		group_lines.append("%s %d: %d improved (median day %d), %d in the first year" % [group, days.size(), decided.size(), median(decided), first_year])
	_report("%-17s founders' first improvement by temperament: %s" % [policy_name, " | ".join(group_lines)])

func median(values: Array[int]) -> int:
	return values[values.size() / 2] if not values.is_empty() else -1

func _report(line: String) -> void:
	print("[INFL] " + line)
