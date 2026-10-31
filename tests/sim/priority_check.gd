extends SceneTree

# Priority check (community priorities prototype, step 1): can the player's choices materially
# improve or damage a settlement through the simulation's own mechanics? The same towns, seeds and
# starting conditions under player strategies that use only the controls the player has today,
# each choice mapped to the nearest existing levers (no new behaviour):
#
# - food:        ask for food work; the stores go to the community's priorities first
# - housing:     keep four homes' worth of plots set aside instead of two; the stores go to the
#                priorities first with nothing asked, so families' improvements wait and wood stays
#                for homes (there is no housing ask today)
# - investment:  ask for better work and for tools
# - cooperation: ask families to help neighbours in need; first claim on the stores for helpers
#
# Strategies, by kind:
# - passive:     none (plots and public works only, as every strategy does);
# - fixed:       one priority held all game (reasonable, some of them risky);
# - informed:    a priority for the season and the town's state, at most two changes in any 90 days
#                so the gathering never looks fickle (TownSocial.review_month);
# - uninformed:  changes on exactly the days the informed strategy changed on the same town, to a
#                priority picked without regard to the town, so the number and timing of policy
#                changes are the same and the trust penalty for changing cannot explain a difference;
# - poor:        fickle (a new priority picked without regard every month: the trust penalty is in
#                play) and wrong-headed (investment in autumn and winter, cooperation in spring and
#                summer, never food, the informed strategy's change limit);
# - destructive: no plots (never set land aside for homes), squander (commission a storehouse
#                whenever the stores hold the wood), sell food (road out, sell every lot of food the
#                trader takes), unfair honours (the existing approach: honour and favour the family
#                that has given least); trade (road out, sensible lots) is the control for sell food.
#
# Three conditions, reported separately: ordinary sites; the same sites with most of the stores lost
# as the first winter begins (a test-only stressor, StandInPlayer "hard_winter"); and naturally
# difficult sites, with no artificial stress: from a wider pool, those where the map luck check's
# classic player does worst (pick_difficult_sites).
#
# The informed and wrong-headed rules were written before any result was seen and are not tuned to
# them. Every strategy also sets plots aside and plans the public works as the stand-in does.
# Run: <godot> --headless --path . --script res://tests/sim/priority_check.gd > priority.log; filter
# for [PRI] (write to a file: a shell pipe stalls Godot on Windows).
# "-- --years=N --sites=N --conditions=ordinary,stressed,difficult --strategies=none,informed"

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const BASE: Dictionary = {"planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter"]}

const PRIORITY_NONE: String = "none"
const PRIORITY_FOOD: String = "food"
const PRIORITY_HOUSING: String = "housing"
const PRIORITY_INVESTMENT: String = "investment"
const PRIORITY_COOPERATION: String = "cooperation"
const PRIORITIES: Array[String] = [PRIORITY_FOOD, PRIORITY_HOUSING, PRIORITY_INVESTMENT, PRIORITY_COOPERATION]

const STRATEGIES: Array = [
	{"name": "none", "kind": "passive"},
	{"name": "food", "kind": "fixed", "priority": PRIORITY_FOOD},
	{"name": "housing", "kind": "fixed", "priority": PRIORITY_HOUSING},
	{"name": "investment", "kind": "fixed", "priority": PRIORITY_INVESTMENT},
	{"name": "cooperation", "kind": "fixed", "priority": PRIORITY_COOPERATION},
	{"name": "informed", "kind": "informed"},
	{"name": "uninformed", "kind": "uninformed"},
	{"name": "fickle", "kind": "poor"},
	{"name": "wrong_headed", "kind": "poor"},
	{"name": "trade", "kind": "control", "trades": true},
	{"name": "no_plots", "kind": "destructive"},
	{"name": "squander", "kind": "destructive"},
	{"name": "sell_food", "kind": "destructive", "trades": true},
	{"name": "unfair", "kind": "destructive", "unfair": true},
	# The housing priority's two levers apart: four homes' worth of plots ahead with the stores open;
	# and the stores kept for the priorities with nothing asked (every improvement waits).
	{"name": "plots_ahead", "kind": "lever"},
	{"name": "stores_closed", "kind": "lever"},
]

const DECIDE_DAYS: int = 30
# A careful player never changes the community's priority more often than this in any 90 days
# (TownSocial.MANY_CHANGES is when families start to lose trust).
const MAX_CHANGES_IN_WINDOW: int = TownSocial.MANY_CHANGES - 1
const SQUANDER_DAYS: int = 10
# Difficult sites: drawn from this many regions (two sites each), the hardest this many kept.
const DIFFICULT_POOL_REGIONS: int = 30
const REFERENCE_DAYS: int = 720

# One strategy playing one town: what it decides each day and what it saw.
class Plan extends RefCounted:
	var name: String
	var scenario: Dictionary
	var current: String = PRIORITY_NONE
	var change_days: Array[int] = []
	var replay_days: Array = []
	var shortage_days: int = 0
	var first_winter_low: float = INF
	var food_after_first_winter: int = -1
	var lots_of_food_sold: int = 0
	var storehouses_commissioned: int = 0

	func _init(strategy_name: String, scenario_ref: Dictionary, replay: Array = []) -> void:
		name = strategy_name
		scenario = scenario_ref
		replay_days = replay

	func each_day(city: City, day: int, player) -> void:
		var food_days: float = FamilyInitiative.get_food_days(city)
		if city.resources["food_shortage"] == true:
			shortage_days += 1
		if day >= 270 and day < 360:
			first_winter_low = minf(first_winter_low, food_days)
		if day == 359:
			food_after_first_winter = int(city.resources["food"])
		match name:
			"food", "housing", "investment", "cooperation":
				if day == 0:
					set_priority(city, name, day)
			"informed":
				if day % DECIDE_DAYS == 0:
					change_if_allowed(city, informed_choice(city, day, player), day)
			"uninformed":
				if day == 0:
					set_priority(city, pick_blindly(city, day), day)
				elif replay_days.has(day):
					set_priority(city, pick_blindly(city, day), day)
			"fickle":
				if day % DECIDE_DAYS == 0:
					set_priority(city, pick_blindly(city, day), day)
			"wrong_headed":
				if day % DECIDE_DAYS == 0:
					change_if_allowed(city, PRIORITY_INVESTMENT if day % 360 >= 180 else PRIORITY_COOPERATION, day)
			"plots_ahead":
				scenario["plots_ahead"] = 4
			"stores_closed":
				city.influence.store_rule = TownInfluence.RULE_PRIORITIES
			"trade":
				player.trade(city, day)
				player.defend(city, day)
			"sell_food":
				sell_food(city, day, player)
				player.defend(city, day)
			"squander":
				if day % SQUANDER_DAYS == 0 and city.construction.can_supply(EconomyBalance.get_build_cost("storehouse")):
					var spot: Vector2i = player.find_spot(city, "storehouse")
					if spot.x >= 0 and city.construction.request_building("storehouse", spot) != null:
						storehouses_commissioned += 1

	# Written before any result was seen: food when the town is short or autumn is near with less
	# than half a year in store; homes while founders are still without one; better work when the
	# stores are comfortable and winter is not close; otherwise keep the current priority.
	func informed_choice(city: City, day: int, player) -> String:
		var of_year: int = day % 360
		var food_days: float = FamilyInitiative.get_food_days(city)
		if food_days < 60.0 or FamilyInitiative.get_food_ratio(city) < 1.0:
			return PRIORITY_FOOD
		if of_year >= 150 and of_year < 300 and food_days < 150.0:
			return PRIORITY_FOOD
		if not player.founders_housed(city):
			return PRIORITY_HOUSING
		var reserve: Dictionary = city.influence.get_protected_reserve()
		if of_year < 210 and int(city.resources["wood"]) >= 30 and int(city.resources["tools"]) >= int(reserve["tools"]) + 3:
			return PRIORITY_INVESTMENT
		return current

	# A priority picked without regard to the town (but never the one already set), the same on
	# every run of the same town.
	func pick_blindly(city: City, day: int) -> String:
		var others: Array = PRIORITIES.filter(func(p: String) -> bool: return p != current)
		return others[absi(hash([city.founding_seed, day, "blind"])) % others.size()]

	func change_if_allowed(city: City, wanted: String, day: int) -> void:
		if wanted == current:
			return
		var recent: int = change_days.filter(func(d: int) -> bool: return day - d <= TownSocial.POLICY_WINDOW_DAYS).size()
		if day > 0 and recent >= MAX_CHANGES_IN_WINDOW:
			return
		set_priority(city, wanted, day)

	# The priority's existing levers (see the top of the file). A change made before the gathering
	# first meets is the town's starting policy, not a change.
	func set_priority(city: City, priority: String, day: int) -> void:
		if priority == current:
			return
		if day > 0:
			change_days.append(day)
		current = priority
		var influence: TownInfluence = city.influence
		influence.encouraged.clear()
		influence.store_rule = TownInfluence.RULE_OPEN
		city.social.set_promoted(TownSocial.NORM_HELP, false)
		city.social.incentive = false
		scenario["plots_ahead"] = 2
		match priority:
			PRIORITY_FOOD:
				influence.set_encouraged(TownInfluence.ACTIVITY_FOOD, true)
				influence.store_rule = TownInfluence.RULE_PRIORITIES
			PRIORITY_HOUSING:
				influence.store_rule = TownInfluence.RULE_PRIORITIES
				scenario["plots_ahead"] = 4
			PRIORITY_INVESTMENT:
				influence.set_encouraged(TownInfluence.ACTIVITY_IMPROVE, true)
				influence.set_encouraged(TownInfluence.ACTIVITY_TOOLS, true)
			PRIORITY_COOPERATION:
				city.social.set_promoted(TownSocial.NORM_HELP, true)
				city.social.incentive = true

	# A road out once there is wood for it, then every lot of food the trader will take.
	func sell_food(city: City, day: int, player) -> void:
		if day % DECIDE_DAYS == 0 and city.trade.get_link() == TownTrade.LINK_NONE and int(city.resources["wood"]) >= player.ROAD_OUT_WOOD and not city.construction.projects.any(func(p: ConstructionProject) -> bool: return p.kind == ConstructionProject.KIND_ROAD):
			player.build_road_out(city)
		if not city.trade.is_trader_here():
			return
		while true:
			var lots: Array[Dictionary] = city.trade.get_lots()
			var chosen: int = -1
			for index in range(lots.size()):
				if lots[index]["give"] == "food":
					chosen = index
					break
			if chosen < 0 or not city.trade.accept_lot(chosen):
				return
			lots_of_food_sold += 1

func _init() -> void:
	call_deferred("run")

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
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	var difficult: Array = []
	if conditions.has("difficult"):
		difficult = pick_difficult_sites(ordinary, site_count)
	for condition: String in conditions:
		var sites: Array = difficult if condition == "difficult" else ordinary
		var stress: bool = condition == "stressed"
		_report("== %s: %d towns, %d years, six founding families%s" % [condition, sites.size(), years, ", first winter's stores lost (test-only stressor)" if stress else ""])
		var by_strategy: Dictionary = {}
		var informed_changes: Array = []
		for strategy: Dictionary in STRATEGIES:
			var name: String = strategy["name"]
			# The uninformed strategy needs the informed one's change days on each town.
			if not only.is_empty() and not only.has(name) and not (name == "informed" and only.has("uninformed")):
				continue
			var started: int = Time.get_ticks_msec()
			var results: Array[Dictionary] = []
			for index in range(sites.size()):
				var replay: Array = informed_changes[index] if name == "uninformed" and index < informed_changes.size() else []
				var result: Dictionary = play(sites[index], strategy, stress, years, replay)
				results.append(result)
				if name == "informed":
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
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	scenario["unfair"] = strategy.get("unfair", false)
	if strategy["name"] == "no_plots":
		(scenario["never"] as Array).append(Building.BUILDING_HOUSE)
	var plan: Plan = Plan.new(strategy["name"], scenario, replay)
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
	result["lots_of_food_sold"] = plan.lots_of_food_sold
	result["storehouses_commissioned"] = plan.storehouses_commissioned
	result["site_seed"] = int(site["seed"])
	return result

func summarize(strategy: Dictionary, results: Array[Dictionary], baseline: Array) -> void:
	var name: String = strategy["name"]
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var totals: Dictionary = {}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in ["population", "households", "departed", "shortage_days", "first_winter_low", "food_after_first_winter", "improvements_by_families", "held_back_by_stores", "trust", "trust_fickle", "help_rate", "changes", "wood", "tools", "lots_of_food_sold", "storehouses_commissioned"]:
			totals[key] = float(totals.get(key, 0.0)) + float(result[key])
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
	_report("%-12s %-11s food: shortage days %.0f, first winter's low %.0f days, store after it %.0f | improved %.1f, held back %.1f | trust %+.2f (from changing %+.2f) | helped %.0f%% | policy changes %.1f | end wood %.0f, tools %.0f%s" % [
		name, "", avg.call("shortage_days"), avg.call("first_winter_low"), avg.call("food_after_first_winter"), avg.call("improvements_by_families"), avg.call("held_back_by_stores"),
		avg.call("trust"), avg.call("trust_fickle"), avg.call("help_rate") * 100.0, avg.call("changes"), avg.call("wood"), avg.call("tools"), extras(name, avg)])
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

func extras(name: String, avg: Callable) -> String:
	match name:
		"sell_food":
			return " | lots of food sold %.1f" % avg.call("lots_of_food_sold")
		"squander":
			return " | storehouses commissioned %.1f" % avg.call("storehouses_commissioned")
	return ""

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
