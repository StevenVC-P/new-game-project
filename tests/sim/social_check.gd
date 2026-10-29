extends SceneTree

# Social check (docs/HOUSEHOLD_SOCIAL_MODEL.md, directive Section 16): the same towns, seeds, and
# starting conditions under five approaches, to see whether the player's choices make materially
# and socially different settlements. Each town starts with its six founding families, develops
# its own work (FamilyInitiative), sets plots aside and plans public works as the stand-in player
# does, and loses most of its stores as its first winter begins, so every town meets a shortage.
#
# - none: no intervention;
# - encourage: the community asks for both norms (help neighbours in need; respect land claims);
# - incentives: families who help or share get first claim on the stores;
# - restricted: the stores are kept for the community's priorities (food only);
# - unfair: every few months the household that has given least is honoured and favoured.
#
# Reports participation, satisfaction, relationships, trust, standing, survival, construction,
# production, norms, value changes, the year-by-year course, and the cost of the weekly pass, then
# a scale probe of the weekly pass on towns of 50 to 400 households.
# Run: <godot> --headless --path . --script res://tests/sim/social_check.gd > log; filter for [SOC]
# (write to a file: a shell pipe stalls Godot on Windows). "-- --years=N --sites=N" shorten it.

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const BASE: Dictionary = {"planned": true, "hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "hard_winter": true, "land_food": false, "never": ["herder", "fisher", "hunter"]}
const APPROACHES: Array = [
	{"name": "none"},
	{"name": "encourage", "promote": true},
	{"name": "incentives", "incentive": true},
	{"name": "restricted", "restricted": true},
	{"name": "unfair", "unfair": true},
	# After the owner's review: honours where they were earned, one kind of contribution after another;
	# and unfair honours for the first year only, to see whether the town settles again.
	{"name": "fair", "fair": true},
	{"name": "brief_unfair", "unfair": true, "brief": true},
]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 3
	var site_count: int = 12
	var only: Array[String] = []
	var scale: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--approaches="):
			only.assign(argument.trim_prefix("--approaches=").split(","))
		elif argument == "--no-scale":
			scale = false
	var sites: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	_report("%d towns on real town maps, %d years, six founding families, first winter's stores lost" % [sites.size(), years])
	for approach: Dictionary in APPROACHES:
		if not only.is_empty() and not only.has(str(approach["name"])):
			continue
		var scenario: Dictionary = BASE.duplicate(true)
		scenario.merge(approach, true)
		var results: Array[Dictionary] = []
		for site: Dictionary in sites:
			var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
			city.site_profile = site["profile"]
			city.local_map = (site["map"] as Array).duplicate(true)
			results.append(StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR))
		summarize(approach["name"], results)
	if scale:
		probe_scale()
	quit()

func summarize(name: String, results: Array[Dictionary]) -> void:
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var totals: Dictionary = {}
	var statuses: Dictionary = {}
	var by_year: Array = []
	var trust_sources: Dictionary = {}
	var declines: Dictionary = {}
	var housed_days: Array[int] = []
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in ["population", "households", "content", "food", "opened_by_families", "improvements_by_families", "player_actions", "stalled_site_days", "homes_by_families"]:
			totals[key] = float(totals.get(key, 0.0)) + float(result[key])
		housed_days.append(int(result["founders_housed_day"]))
		var social: Dictionary = result["social"]
		for key: String in social.keys():
			if social[key] is float or social[key] is int:
				totals["s_" + key] = float(totals.get("s_" + key, 0.0)) + float(social[key])
		for source: String in (social["trust_by_source"] as Dictionary).keys():
			trust_sources[source] = float(trust_sources.get(source, 0.0)) + float(social["trust_by_source"][source]) / maxf(1.0, float(social["households"]))
		for reason: String in (social["decline_reasons"] as Dictionary).keys():
			declines[reason] = int(declines.get(reason, 0)) + int(social["decline_reasons"][reason])
		for key: String in ["help_status", "claims_status"]:
			var label: String = key + ": " + str(social[key])
			statuses[label] = int(statuses.get(label, 0)) + 1
		for year in range((result["social_years"] as Array).size()):
			if by_year.size() <= year:
				by_year.append({"help": 0.0, "trust": 0.0, "disposition": 0.0, "values": 0.0, "count": 0})
			var snapshot: Dictionary = result["social_years"][year]
			by_year[year]["help"] += float(snapshot["help_acceptance"])
			by_year[year]["trust"] += float(snapshot["trust"])
			by_year[year]["disposition"] += float(snapshot["mean_disposition"])
			var before: int = int(result["social_years"][year - 1]["value_changes"]) if year > 0 else 0
			by_year[year]["values"] += float(int(snapshot["value_changes"]) - before)
			by_year[year]["count"] += 1
	var avg: Callable = func(key: String) -> float: return float(totals.get(key, 0.0)) / n
	_report("%-10s %2d/%d off the ground | people %.0f | households %.1f | content families %.1f | food in store %.0f | families opened %.1f, improved %.1f | player decisions %.0f" % [
		name, made_it, results.size(), avg.call("population"), avg.call("households"), avg.call("content"), avg.call("food"), avg.call("opened_by_families"), avg.call("improvements_by_families"), avg.call("player_actions")])
	_report("%-10s helped a neighbour in need %.0f%% of %.0f chances (help-weeks %.0f) | shared in %.0f%% of %.1f requests | disputes raised %.1f, settled %.1f, let pass %.1f, unsettled pressure %.1f" % [
		name, avg.call("s_help_rate") * 100.0, avg.call("s_help_opportunities"), avg.call("s_help_weeks"), avg.call("s_share_rate") * 100.0, avg.call("s_share_requests"), avg.call("s_disputes_raised"), avg.call("s_disputes_settled"), avg.call("s_disputes_let_pass"), avg.call("s_dispute_pressure")])
	_report("%-10s ties a household %.1f (mean disposition %+.2f), friends %.2f, rivals %.2f | trust %+.2f | standing spread %.1f | acceptance: help %.2f, claims %.2f | value changes %.1f | weekly pass %.0f us (%.1f households)" % [
		name, avg.call("s_ties"), avg.call("s_mean_disposition"), avg.call("s_friends"), avg.call("s_rivals"), avg.call("s_trust"), avg.call("s_standing_spread"), avg.call("s_help_acceptance"), avg.call("s_claims_acceptance"), avg.call("s_value_changes"), avg.call("s_week_usec"), avg.call("s_households")])
	var course: Array[String] = []
	for year in range(by_year.size()):
		var c: float = maxf(1.0, by_year[year]["count"])
		course.append("year %d: help %.2f, trust %+.2f, disposition %+.2f, value changes %.1f" % [year + 1, by_year[year]["help"] / c, by_year[year]["trust"] / c, by_year[year]["disposition"] / c, by_year[year]["values"] / c])
	_report("%-10s %s | norms: %s" % [name, " | ".join(course), str(statuses)])
	housed_days.sort()
	var never: int = housed_days.filter(func(d: int) -> bool: return d < 0).size()
	var housed: Array[int] = housed_days.filter(func(d: int) -> bool: return d >= 0)
	_report("%-10s building: founders all in proper homes by day %s (median; %d towns never) | site-days with no builder free %.0f | homes families built %.1f | long-day weeks %.1f | help to kin %.0f%% of help-weeks" % [
		name, str(housed[housed.size() / 2]) if not housed.is_empty() else "-", never, avg.call("stalled_site_days"), avg.call("homes_by_families"), avg.call("s_long_day_weeks"), avg.call("s_kin_help_share") * 100.0])
	_report("%-10s behavior and conviction: help choices changed %.1f times, value changes %.1f (reversed %.1f) | readings of each honour %.1f | land contests %.1f (yielded %.1f, kept %.1f, not pressed %.1f) | respected voices %.1f" % [
		name, avg.call("s_help_choice_changes"), avg.call("s_value_changes"), avg.call("s_value_reversals"), avg.call("s_honour_readings"), avg.call("s_land_contests"), avg.call("s_land_yielded"), avg.call("s_land_kept"), avg.call("s_land_not_pressed"), avg.call("s_voices")])
	var sources: Array[String] = []
	for source: String in trust_sources.keys():
		sources.append("%s %+.2f" % [source, float(trust_sources[source]) / n])
	sources.sort()
	var reasons: Array = declines.keys()
	reasons.sort_custom(func(a: String, b: String) -> bool: return int(declines[a]) > int(declines[b]))
	var top: Array[String] = []
	for reason: String in reasons.slice(0, 4):
		top.append("%s (%.0f)" % [reason, int(declines[reason]) / n])
	_report("%-10s trust a household, by source: %s | declined help mostly because: %s" % [name, ", ".join(sources) if not sources.is_empty() else "none", "; ".join(top)])

# The weekly pass on towns of 50 to 400 households with homes spread over a map, each on a holding,
# with a home being built for every tenth: what one household costs a week, and whether that cost
# grows with the town (it should not: candidates are local and capped).
func probe_scale() -> void:
	for count: int in [50, 100, 200, 400]:
		var city: City = City.new("Probe", Vector2.ZERO, City.ROLE_PLAYER, count, 7)
		city.local_map = TownBuildingCheck.collect_sites()[0]["map"].duplicate(true)
		city.social.set_enabled(true)
		var size: Vector2i = city.logistics.map_size()
		for i in range(city.households.size()):
			var household: Household = city.households[i]
			var home_tile: Vector2i = Vector2i((i * 7) % size.x, (i * 13 / size.x * 3 + i) % size.y)
			city.add_building(Building.new(-1, "house", home_tile, Vector2i.ONE), household)
			city.add_building(Building.new(-1, "gatherer_camp", Vector2i((home_tile.x + 3) % size.x, home_tile.y), Vector2i.ONE), household)
		for i in range(0, city.households.size(), 10):
			var project: ConstructionProject = ConstructionProject.new()
			project.id = 10000 + i
			project.kind = ConstructionProject.KIND_BUILDING
			project.building_type = "house"
			project.claimant_household_id = city.households[i].id
			project.tile = city.logistics.get_home_tile(city.households[i])
			project.size = Vector2i.ONE
			project.materials_needed = {}
			project.work_required = 8.0
			city.construction.projects.append(project)
		city.social.week_usec_total = 0
		city.social.weeks_run = 0
		for week in range(4):
			city.construction.day = 7 * week + TownSocial.WEEK_OFFSET
			city.social.advance_week()
		var per_week: float = float(city.social.week_usec_total) / maxf(1.0, city.social.weeks_run)
		_report("scale %3d households: weekly pass %.1f ms, %.0f us a household" % [count, per_week / 1000.0, per_week / count])

func _report(line: String) -> void:
	print("[SOC] " + line)
