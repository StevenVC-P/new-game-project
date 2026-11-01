extends SceneTree

# Priority check (docs/COMMUNITY_PRIORITIES.md): can the player's choices materially improve or
# damage a settlement through the simulation's own mechanics? The same towns, seeds and starting
# conditions under player strategies that use the community's one priority (CommunityPriority) and,
# separately, the stores rule, so persuasion and resource restriction can be told apart.
# (Step 1, before the priority existed, mapped each choice to the old asks: commit 8fd8b39.)
#
# Strategies, by kind:
# Only community choices are play here (owner, 2026-10-31): the player places nothing and plans no
# public works. Every town has the modest starting residential land a passive player has
# (HomeSites.set_aside_starting_land, docs/HOME_SITES.md), and families choose their own home sites
# on it; families open and improve their own work.
#
# - passive:     none;
# - fixed:       one priority held all game, with the stores open, and with the stores kept for the
#                priority first ("_pf"); some are reasonable, some risky, and the warnings say which;
# - informed:    "preview" reads the families' views and the warnings, as the Community tab will
#                show them: the priority the town backs most, the stores kept for it only when that
#                warns of nothing more than leaving them open; "seasonal" is step 1's informed rules
#                (food before winter, homes while founders lack them, investment when stores are
#                comfortable) with the stores open; "tool_aware" weighs the production chain (owner,
#                2026-10-31): tools before anything that needs them, food only once someone makes
#                tools, homes when their sites wait for hands, otherwise cooperation. All three change
#                at most twice in any 90 days;
# - uninformed:  changes on exactly the days the tool-aware strategy changed on the same town, to a
#                priority and a stores rule picked without regard to the town, so the number and
#                timing of policy changes are the same;
# - poor:        fickle (a new priority picked without regard every month: the trust penalty is in
#                play) and wrong-headed (investment in autumn and winter, cooperation in spring and
#                summer, never food);
# - destructive: starve (the stores kept for the priorities with none set, so no family's
#                improvement is funded) and unfair honours (every few months, honour and favour the
#                family that has given least). Selling food had no teeth in step 1 and is not repeated.
#
# Three conditions, reported separately: ordinary sites; the same sites with most of the stores lost
# as the first winter begins (a test-only stressor, StandInPlayer "hard_winter"); and naturally
# difficult sites, with no artificial stress: from a wider pool, those where the map luck check's
# classic player does worst (pick_difficult_sites).
#
# The informed, uninformed and wrong-headed rules were written before this step's results were seen
# and are not tuned to them.
# "--layout=" sets the residential land every town starts with (residential_layouts.gd; default
# "starting"), to cross land planning with leadership.
# Run: <godot> --headless --path . --script res://tests/sim/priority_check.gd > priority.log; filter
# for [PRI] (write to a file: a shell pipe stalls Godot on Windows).
# "-- --years=N --sites=N --conditions=ordinary,stressed,difficult --strategies=none,tool_aware --layout=compact"

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

# The stand-in player builds nothing: "house" is never planned (no plots), and nothing is "planned".
const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const OPEN: String = TownInfluence.RULE_OPEN
const FIRST: String = TownInfluence.RULE_PRIORITIES

const STRATEGIES: Array = [
	{"name": "none", "kind": "passive"},
	{"name": "food", "kind": "fixed", "priority": CommunityPriority.FOOD, "rule": OPEN},
	{"name": "housing", "kind": "fixed", "priority": CommunityPriority.HOUSING, "rule": OPEN},
	{"name": "investment", "kind": "fixed", "priority": CommunityPriority.INVESTMENT, "rule": OPEN},
	{"name": "cooperation", "kind": "fixed", "priority": CommunityPriority.COOPERATION, "rule": OPEN},
	{"name": "food_pf", "kind": "fixed", "priority": CommunityPriority.FOOD, "rule": FIRST},
	{"name": "housing_pf", "kind": "fixed", "priority": CommunityPriority.HOUSING, "rule": FIRST},
	{"name": "investment_pf", "kind": "fixed", "priority": CommunityPriority.INVESTMENT, "rule": FIRST},
	{"name": "cooperation_pf", "kind": "fixed", "priority": CommunityPriority.COOPERATION, "rule": FIRST},
	{"name": "preview", "kind": "informed"},
	{"name": "seasonal", "kind": "informed"},
	{"name": "tool_aware", "kind": "informed"},
	{"name": "uninformed", "kind": "uninformed"},
	{"name": "fickle", "kind": "poor"},
	{"name": "wrong_headed", "kind": "poor"},
	{"name": "starve", "kind": "destructive", "priority": CommunityPriority.NONE, "rule": FIRST},
	{"name": "unfair", "kind": "destructive", "unfair": true},
]

const DECIDE_DAYS: int = 30
# A careful player never changes the community's priority more often than this in any 90 days
# (TownSocial.MANY_CHANGES is when families start to lose trust).
const MAX_CHANGES_IN_WINDOW: int = TownSocial.MANY_CHANGES - 1
# The preview strategy changes priority only for one the town backs this much more.
const BACKING_MARGIN: float = 0.1
# Difficult sites: drawn from this many regions (two sites each), the hardest this many kept.
const DIFFICULT_POOL_REGIONS: int = 30
const REFERENCE_DAYS: int = 720

# One strategy playing one town: what it decides each day and what it saw.
class Plan extends RefCounted:
	var strategy: Dictionary
	var name: String
	var current: String = CommunityPriority.NONE
	var current_rule: String = OPEN
	var change_days: Array[int] = []
	var replay_days: Array = []
	var days_on: Dictionary = {}
	var shortage_days: int = 0
	var first_winter_low: float = INF
	var food_after_first_winter: int = -1

	func _init(strategy_ref: Dictionary, replay: Array = []) -> void:
		strategy = strategy_ref
		name = strategy["name"]
		replay_days = replay

	func each_day(city: City, day: int, player) -> void:
		var food_days: float = FamilyInitiative.get_food_days(city)
		if city.resources["food_shortage"] == true:
			shortage_days += 1
		if day >= 270 and day < 360:
			first_winter_low = minf(first_winter_low, food_days)
		if day == 359:
			food_after_first_winter = int(city.resources["food"])
		if strategy.has("rule") and day == 0:
			set_policy(city, strategy["priority"], strategy["rule"], day)
		match name:
			"preview":
				if day % DECIDE_DAYS == 0:
					var chosen: String = choose_by_preview(city)
					change_if_allowed(city, chosen, rule_by_warnings(city, chosen), day)
			"seasonal":
				if day % DECIDE_DAYS == 0:
					change_if_allowed(city, choose_by_season(city, day, player), OPEN, day)
			"tool_aware":
				if day % DECIDE_DAYS == 0:
					var chosen: String = choose_by_production(city, day, player)
					change_if_allowed(city, chosen, rule_by_warnings(city, chosen), day)
			"uninformed":
				if day == 0 or replay_days.has(day):
					set_policy(city, pick_blindly(city, day), FIRST if absi(hash([city.founding_seed, day, "rule"])) % 2 == 0 else OPEN, day)
			"fickle":
				if day % DECIDE_DAYS == 0:
					set_policy(city, pick_blindly(city, day), OPEN, day)
			"wrong_headed":
				if day % DECIDE_DAYS == 0:
					change_if_allowed(city, CommunityPriority.INVESTMENT if day % 360 >= 180 else CommunityPriority.COOPERATION, OPEN, day)
		var key: String = current if current != CommunityPriority.NONE else "none"
		days_on[key] = int(days_on.get(key, 0)) + 1

	# Written before this step's results: the priority the town backs most (CommunityPriority.get_backing),
	# changing only for one backed clearly more than the current one.
	func choose_by_preview(city: City) -> String:
		var best: String = current
		var best_backing: float = CommunityPriority.get_backing(city, current) + BACKING_MARGIN if current != CommunityPriority.NONE else 0.5
		for priority: String in CommunityPriority.ALL:
			var backing: float = CommunityPriority.get_backing(city, priority)
			if backing > best_backing:
				best = priority
				best_backing = backing
		return best

	# The stores kept for the priority only when that warns of nothing beyond leaving them open.
	func rule_by_warnings(city: City, priority: String) -> String:
		if priority == CommunityPriority.NONE:
			return OPEN
		return FIRST if CommunityPriority.get_warnings(city, priority, FIRST).size() <= CommunityPriority.get_warnings(city, priority, OPEN).size() else OPEN

	# Written before its results (owner, 2026-10-31: weigh food, toolmaking, upkeep and labour; do not
	# follow the town's backing). Every proper workplace wears tools, so tools come first while no one
	# makes them; food is asked for only once someone does, since asking for food draws families
	# choosing their work away from tools; homes when their sites stand waiting for hands; otherwise
	# cooperation, the priority whose warnings name no cost in production.
	func choose_by_production(city: City, day: int, player) -> String:
		var toolmakers: int = FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS)
		var proper: int = city.buildings.filter(func(b: Building) -> bool: return b.needs_maintenance()).size()
		var reserve: int = int(city.influence.get_protected_reserve()["tools"])
		var food_days: float = FamilyInitiative.get_food_days(city)
		var short_of_food: bool = food_days < 60.0 or FamilyInitiative.get_food_ratio(city) < 1.0
		if toolmakers == 0 and (int(city.resources["tools"]) < reserve + 6 or proper >= 2 or short_of_food):
			return CommunityPriority.INVESTMENT
		if short_of_food:
			return CommunityPriority.FOOD
		var of_year: int = day % 360
		if of_year >= 150 and of_year < 270 and food_days < 150.0:
			return CommunityPriority.FOOD
		var homes_waiting: bool = city.construction.projects.any(func(p: ConstructionProject) -> bool: return p.is_home() and p.blocked_reason == "no builders free")
		if homes_waiting and not player.founders_housed(city):
			return CommunityPriority.HOUSING
		return CommunityPriority.COOPERATION

	# Step 1's informed rules: food when the town is short or autumn is near with less than half a
	# year in store; homes while founders are still without one; better work when the stores are
	# comfortable and winter is not close; otherwise keep the current priority.
	func choose_by_season(city: City, day: int, player) -> String:
		var of_year: int = day % 360
		var food_days: float = FamilyInitiative.get_food_days(city)
		if food_days < 60.0 or FamilyInitiative.get_food_ratio(city) < 1.0:
			return CommunityPriority.FOOD
		if of_year >= 150 and of_year < 300 and food_days < 150.0:
			return CommunityPriority.FOOD
		if not player.founders_housed(city):
			return CommunityPriority.HOUSING
		var reserve: Dictionary = city.influence.get_protected_reserve()
		if of_year < 210 and int(city.resources["wood"]) >= 30 and int(city.resources["tools"]) >= int(reserve["tools"]) + 3:
			return CommunityPriority.INVESTMENT
		return current

	# A priority picked without regard to the town (but never the one already set), the same on
	# every run of the same town.
	func pick_blindly(city: City, day: int) -> String:
		var others: Array = CommunityPriority.ALL.filter(func(p: String) -> bool: return p != current)
		return others[absi(hash([city.founding_seed, day, "blind"])) % others.size()]

	func change_if_allowed(city: City, wanted: String, rule: String, day: int) -> void:
		if wanted == current and rule == current_rule:
			return
		var recent: int = change_days.filter(func(d: int) -> bool: return day - d <= TownSocial.POLICY_WINDOW_DAYS).size()
		if day > 0 and recent >= MAX_CHANGES_IN_WINDOW:
			return
		set_policy(city, wanted, rule, day)

	# A change made before the gathering first meets is the town's starting policy, not a change.
	func set_policy(city: City, priority: String, rule: String, day: int) -> void:
		if priority == current and rule == current_rule:
			return
		if day > 0:
			change_days.append(day)
		current = priority
		current_rule = rule
		city.influence.set_priority(priority)
		city.influence.store_rule = rule

func _init() -> void:
	call_deferred("run")

# The residential land every town starts with (residential_layouts.gd).
var layout: String = "starting"

func run() -> void:
	var years: int = 3
	var site_count: int = 12
	var conditions: Array[String] = ["ordinary", "stressed", "difficult"]
	var only: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--strategies="):
			only.assign(argument.trim_prefix("--strategies=").split(","))
		elif argument.begins_with("--layout="):
			layout = argument.trim_prefix("--layout=")
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	var difficult: Array = []
	if conditions.has("difficult"):
		difficult = pick_difficult_sites(ordinary, site_count)
	for condition: String in conditions:
		var sites: Array = difficult if condition == "difficult" else ordinary
		var stress: bool = condition == "stressed"
		_report("== %s: %d towns, %d years, six founding families, %s residential land%s" % [condition, sites.size(), years, layout, ", first winter's stores lost (test-only stressor)" if stress else ""])
		var by_strategy: Dictionary = {}
		var informed_changes: Array = []
		for strategy: Dictionary in STRATEGIES:
			var name: String = strategy["name"]
			# The uninformed strategy needs the tool-aware strategy's change days on each town.
			if not only.is_empty() and not only.has(name) and not (name == "tool_aware" and only.has("uninformed")):
				continue
			var started: int = Time.get_ticks_msec()
			var results: Array[Dictionary] = []
			for index in range(sites.size()):
				var replay: Array = informed_changes[index] if name == "uninformed" and index < informed_changes.size() else []
				var result: Dictionary = play(sites[index], strategy, stress, years, replay)
				results.append(result)
				if name == "tool_aware":
					informed_changes.append(result["change_days"])
			by_strategy[name] = results
			if only.is_empty() or only.has(name):
				summarize(strategy, results, by_strategy.get("none", []))
			_report("   (%s took %.0f s)" % [name, (Time.get_ticks_msec() - started) / 1000.0])
	quit()

func play(site: Dictionary, strategy: Dictionary, stress: bool, years: int, replay: Array) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, layout)
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	scenario["unfair"] = strategy.get("unfair", false)
	var plan: Plan = Plan.new(strategy, replay)
	scenario["each_day"] = Callable(plan, "each_day")
	var player = StandInPlayerScript.new()
	var result: Dictionary = player.play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	var social: Dictionary = result["social"]
	result["departed"] = int(city.resources["departed_households"])
	result["wood"] = int(city.resources["wood"])
	result["tools"] = int(city.resources["tools"])
	result["change_days"] = plan.change_days
	result["changes"] = plan.change_days.size()
	result["shortage_days"] = plan.shortage_days
	result["first_winter_low"] = plan.first_winter_low if not is_inf(plan.first_winter_low) else 0.0
	result["food_after_first_winter"] = plan.food_after_first_winter
	result["trust"] = float(social.get("trust", 0.0))
	result["help_rate"] = float(social.get("help_rate", 0.0))
	result["trust_fickle"] = float((social.get("trust_by_source", {}) as Dictionary).get("decisions keep changing", 0.0)) / maxf(1.0, float(social.get("households", 1)))
	result["long_day_weeks"] = int(social.get("long_day_weeks", 0))
	result["days_on"] = plan.days_on
	# Decisions the priority tipped (CommunityPriority.record_swayed), by decision.
	for decision: String in ["improve", "help", "long_days"]:
		result["swayed_" + decision] = 0
	for key: String in city.influence.swayed.keys():
		var decision: String = key.get_slice(":", 1)
		result["swayed_" + decision] = int(result.get("swayed_" + decision, 0)) + int(city.influence.swayed[key])
	result["site_seed"] = int(site["seed"])
	return result

func summarize(strategy: Dictionary, results: Array[Dictionary], baseline: Array) -> void:
	var name: String = strategy["name"]
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var totals: Dictionary = {}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in ["population", "households", "departed", "shortage_days", "first_winter_low", "food_after_first_winter", "improvements_by_families", "held_back_by_stores", "trust", "trust_fickle", "help_rate", "changes", "wood", "tools", "long_day_weeks", "swayed_improve", "swayed_help", "swayed_long_days"]:
			totals[key] = float(totals.get(key, 0.0)) + float(result[key])
	var days_on: Dictionary = {}
	for result: Dictionary in results:
		for priority: String in (result["days_on"] as Dictionary).keys():
			days_on[priority] = int(days_on.get(priority, 0)) + int(result["days_on"][priority])
	var avg: Callable = func(key: String) -> float: return float(totals.get(key, 0.0)) / n
	var reasons: Dictionary = {}
	for result: Dictionary in results:
		for reason: String in result["reasons"]:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
	var reason_words: Array[String] = []
	for reason: String in reasons.keys():
		reason_words.append("%s %d" % [reason, reasons[reason]])
	_report("%-12s %-11s %2d/%d off the ground | people %5.1f | families %4.1f (left %.1f) | hamlet %s | village %s | founders housed %s" % [
		name, strategy["kind"], made_it, results.size(), avg.call("population"), avg.call("households"), avg.call("departed"),
		median_day(results, "hamlet_day"), median_day(results, "village_day"), median_day(results, "founders_housed_day")])
	if not reason_words.is_empty():
		_report("%-12s %-11s towns short of the mark, why: %s" % [name, "", ", ".join(reason_words)])
	_report("%-12s %-11s food: shortage days %.0f, first winter's low %.0f days, store after it %.0f | improved %.1f, held back %.1f | trust %+.2f (from changing %+.2f) | helped %.0f%% | policy changes %.1f | end wood %.0f, tools %.0f" % [
		name, "", avg.call("shortage_days"), avg.call("first_winter_low"), avg.call("food_after_first_winter"), avg.call("improvements_by_families"), avg.call("held_back_by_stores"),
		avg.call("trust"), avg.call("trust_fickle"), avg.call("help_rate") * 100.0, avg.call("changes"), avg.call("wood"), avg.call("tools")])
	var all_days: float = 0.0
	for priority: String in days_on.keys():
		all_days += float(days_on[priority])
	var shares: Array[String] = []
	for priority: String in days_on.keys():
		shares.append("%s %.0f%%" % [priority, 100.0 * float(days_on[priority]) / maxf(1.0, all_days)])
	_report("%-12s %-11s decisions the priority tipped: improvements %.1f, help-weeks %.1f, long-day weeks %.1f (of %.1f) | time on each priority: %s" % [
		name, "", avg.call("swayed_improve"), avg.call("swayed_help"), avg.call("swayed_long_days"), avg.call("long_day_weeks"), ", ".join(shares)])
	if baseline.is_empty() or name == "none":
		return
	var better: int = 0
	var worse: int = 0
	var delta: float = 0.0
	var lost: int = 0
	var saved: int = 0
	for index in range(mini(results.size(), baseline.size())):
		var difference: int = int(results[index]["population"]) - int(baseline[index]["population"])
		delta += difference
		better += 1 if difference >= 5 else 0
		worse += 1 if difference <= -5 else 0
		lost += 1 if bool(baseline[index]["off_the_ground"]) and not bool(results[index]["off_the_ground"]) else 0
		saved += 1 if not bool(baseline[index]["off_the_ground"]) and bool(results[index]["off_the_ground"]) else 0
	_report("%-12s %-11s against none, town by town: people %+.1f on average, 5+ more in %d towns, 5+ fewer in %d | towns lost %d, saved %d" % [name, "", delta / n, better, worse, lost, saved])

# The median day a milestone was reached among the towns that reached it, and how many did.
func median_day(results: Array[Dictionary], key: String) -> String:
	var days: Array[int] = []
	for result: Dictionary in results:
		if int(result[key]) >= 0:
			days.append(int(result[key]))
	if days.is_empty():
		return "never"
	days.sort()
	return "d%d (%d/%d)" % [days[days.size() / 2], days.size(), results.size()]

# The hardest sites, from a wider pool than the ordinary ones and excluding them: those where the
# map luck check's own player (StandInPlayer with no scenario: the classic rules, the player
# placing every building) does worst in REFERENCE_DAYS. A measure of the land, not of any strategy
# compared here: that player's runs share no decisions or unknowns with families leading.
# (Room for fields and camps near the heart was tried first and did not predict difficulty.)
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
		var reference: Dictionary = StandInPlayerScript.new().play(city, {}, REFERENCE_DAYS)
		site["reference"] = reference
		pool.append(site)
	# Towns that did not get off the ground first, then the smallest.
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_ok: bool = a["reference"]["off_the_ground"]
		var b_ok: bool = b["reference"]["off_the_ground"]
		if a_ok != b_ok:
			return not a_ok
		return int(a["reference"]["population"]) < int(b["reference"]["population"]))
	var picked: Array = pool.slice(0, count)
	var failed: int = pool.filter(func(s: Dictionary) -> bool: return not s["reference"]["off_the_ground"]).size()
	_report("difficult sites: the %d where the classic player did worst in %d days, of %d (%d of them failed)" % [picked.size(), REFERENCE_DAYS, pool.size(), failed])
	for site: Dictionary in picked:
		var reference: Dictionary = site["reference"]
		_report("  %s: %s, %d people%s | tags %s" % [site["label"], "off the ground" if reference["off_the_ground"] else "failed", reference["population"],
			" (" + ", ".join(reference["reasons"]) + ")" if not (reference["reasons"] as Array).is_empty() else "", ", ".join((site["profile"] as SettlementSiteProfile).tags)])
	return picked

func _report(line: String) -> void:
	print("[PRI] " + line)
