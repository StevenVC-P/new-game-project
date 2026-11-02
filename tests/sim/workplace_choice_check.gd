extends SceneTree

# Investigation (owner playtest, 2026-11-01): why do families not build a toolmaker's workshop or a
# herder's fold? Plays the wisdom check's towns with families leading and the social model on (no
# wisdom, no priority unless asked), the stand-in building only homes and shared works, and traces
# every family decision about work:
#
# - taking up work: the day before the weekly decision (same week, so the same noise) each free
#   family's desire for food, wood and tools is evaluated with its reasons, then the decision it
#   actually took is read from its note;
# - improving hand work: the same for every family on hand work (score against the threshold, and
#   whether the stores rule held it back);
# - herding: which families' callings draw them to a fold, whether they wish for it, whether the
#   land would take one, and whether any fold exists.
#
# Changes nothing in the game. One condition per process; filter for [WPC]:
#   <godot> --headless --path . --script res://tests/sim/workplace_choice_check.gd -- --conditions=ordinary > wpc.log
# Options: --years=N (3), --sites=N (12), --priority=investment|food|..., --no-self-sufficiency.

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const DIFFICULT_POOL_REGIONS: int = 30
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const TYPES: Array[String] = ["forager_garden", "farm", "gatherer_camp", "woodcutter", "tool_mender", "toolmaker", "herder", "fisher", "hunter"]

var priority: String = ""
var self_sufficiency: bool = true

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 3
	var site_count: int = 12
	var conditions: Array[String] = ["ordinary"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--priority="):
			priority = argument.trim_prefix("--priority=")
		elif argument == "--no-self-sufficiency":
			self_sufficiency = false
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	for condition: String in conditions:
		var sites: Array = get_difficult_sites() if condition == "difficult" else ordinary
		for site: Dictionary in sites:
			var result: Dictionary = play(site, condition == "stressed", years)
			_report("TOWN %s | seed %d | %s" % [condition, int(site["seed"]), JSON.stringify(result)])
	quit()

func play(site: Dictionary, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	city.influence.self_sufficiency = self_sufficiency
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var trace: Dictionary = {
		"takeups": [], "improve_evals": {}, "first_day": {}, "yearly": [],
		"tools_reasons_against": {}, "tools_reasons_for": {}, "herd_wishes": 0, "herd_wish_families": {},
	}
	var pending: Dictionary = {}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0 and priority != "":
			town.influence.set_priority(priority)
		var today: int = town.construction.day
		# Founders choose on the first day, before anything can be traced: their own words only.
		if day == 0:
			var founders: Array = []
			for household: Household in town.households:
				founders.append({"note": household.initiative_note.substr(0, 160), "forge": household.get_match_quality("toolmaker"), "trade": household.family_trade})
			trace["founders"] = founders
		# The day before the weekly decision: evaluate every family's options as it will see them.
		if today % FamilyInitiative.INTERVAL_DAYS == 0:
			pending.clear()
			for household: Household in town.households:
				if household.labor_capacity <= 0 or FamilyInitiative.has_own_project(town, household):
					continue
				var holding: Building = FamilyInitiative.get_holding(town, household)
				if holding == null and household.assigned_workers <= 0 and not town.construction.is_promised_to_workplace(household.id):
					var options: Dictionary = {}
					# By the first three trades' old names (food, wood, tools), and the others' own.
					for occupation: String in FamilyInitiative.get_occupations(town):
						var desire: Dictionary = FamilyInitiative.get_work_desire(town, household, occupation)
						var key: String = FamilyInitiative.get_choice_key(occupation)
						if bool(desire["available"]):
							options[key] = {"score": float(desire["score"]) + FamilyInitiative.get_noise(town, household, key), "terms": desire["terms"]}
					pending[household.id] = {"kind": "takeup", "options": options, "calling": household.get_match_quality("toolmaker"), "trade": household.family_trade}
				elif holding != null and holding.is_tier0() and FamilyInitiative.get_activity(holding.type) != "" and town.construction.get_upgrade_project(holding.id) == null:
					var proper: String = BuildingTiers.get_upgrade_type(holding.type)
					var desire: Dictionary = FamilyInitiative.get_improve_desire(town, household, proper)
					pending[household.id] = {"kind": "improve", "type": holding.type, "score": float(desire["score"]) + FamilyInitiative.get_noise(town, household, "improve"), "terms": desire["terms"]}
		# The decision itself, read from what the family says.
		if today % FamilyInitiative.INTERVAL_DAYS == 1:
			for id in pending.keys():
				var household: Household = town.get_household_by_id(int(id))
				if household == null or household.initiative_day != today:
					continue
				var entry: Dictionary = pending[id]
				if entry["kind"] == "takeup":
					record_takeup(trace, entry, household.initiative_note, today)
				else:
					record_improve(trace, entry, household.initiative_note)
			pending.clear()
		# Herding: families whose wish is work of a calling a fold answers.
		if today % 30 == 0:
			for household: Household in town.households:
				if household.ambition == FamilyAmbitions.CALLING and FamilyAmbitions.get_calling_work(household, town).has("herder"):
					trace["herd_wishes"] = int(trace["herd_wishes"]) + 1
					trace["herd_wish_families"][str(household.id)] = true
		for building: Building in town.buildings:
			if TYPES.has(building.type) and not trace["first_day"].has(building.type):
				trace["first_day"][building.type] = today
		if day % Calendar.DAYS_PER_YEAR == Calendar.DAYS_PER_YEAR - 1:
			trace["yearly"].append(snapshot(town))
	StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	trace["herd_wish_families"] = (trace["herd_wish_families"] as Dictionary).size()
	trace["land"] = land(city)
	trace["callings"] = callings(city)
	return trace

func record_takeup(trace: Dictionary, entry: Dictionary, note: String, day: int) -> void:
	var options: Dictionary = entry["options"]
	var ranked: Array = options.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return float(options[a]["score"]) > float(options[b]["score"]))
	var chosen: String = ""
	if note.contains("tool mender"):
		chosen = "tools"
	elif note.contains("garden"):
		chosen = "food"
	elif note.contains("gatherer"):
		chosen = "wood"
	var tools: Dictionary = options["tools"]
	var bucket: String = "tools_reasons_for" if chosen == "tools" else "tools_reasons_against"
	for term: Dictionary in tools["terms"]:
		var reason: String = str(term["reason"])
		if (chosen == "tools") == (float(term["weight"]) > 0.0):
			trace[bucket][reason] = int(trace[bucket].get(reason, 0)) + 1
	trace["takeups"].append({
		"day": day, "chosen": chosen, "top": ranked[0], "tools_rank": ranked.find("tools") + 1,
		"scores": {"food": snappedf(float(options["food"]["score"]), 0.01), "wood": snappedf(float(options["wood"]["score"]), 0.01), "tools": snappedf(float(tools["score"]), 0.01)},
		"forge": entry["calling"], "trade": entry["trade"], "note": note.substr(0, 160),
	})

func record_improve(trace: Dictionary, entry: Dictionary, note: String) -> void:
	var type: String = entry["type"]
	var evals: Dictionary = trace["improve_evals"].get(type, {"weeks": 0, "over": 0, "held_back": 0, "started": 0, "max": -99.0, "sum": 0.0, "against": {}, "for": {}})
	evals["weeks"] = int(evals["weeks"]) + 1
	var score: float = float(entry["score"])
	evals["sum"] = float(evals["sum"]) + score
	evals["max"] = maxf(float(evals["max"]), score)
	if score >= FamilyInitiative.IMPROVE_THRESHOLD:
		evals["over"] = int(evals["over"]) + 1
	if note.begins_with("Wants to improve"):
		evals["held_back"] = int(evals["held_back"]) + 1
	elif note.begins_with("Improving"):
		evals["started"] = int(evals["started"]) + 1
	for term: Dictionary in entry["terms"]:
		var key: String = "for" if float(term["weight"]) > 0.0 else "against"
		var reason: String = str(term["reason"])
		evals[key][reason] = int(evals[key].get(reason, 0)) + 1
	trace["improve_evals"][type] = evals

func snapshot(city: City) -> Dictionary:
	var counts: Dictionary = {}
	for building: Building in city.buildings:
		if TYPES.has(building.type):
			counts[building.type] = int(counts.get(building.type, 0)) + 1
	var projects: Dictionary = {}
	for project: ConstructionProject in city.construction.projects:
		projects[project.building_type] = int(projects.get(project.building_type, 0)) + 1
	return {"day": city.construction.day, "households": city.households.size(), "people": city.get_total_population(), "buildings": counts, "projects": projects, "tools": int(city.resources["tools"]), "wood": int(city.resources["wood"]), "food_days": FamilyInitiative.get_food_days(city), "wool": int(city.resources.get("wool", 0)), "clothing_need": city.get_clothing_need_pressure().get("status", ""), "tools_waiting_risk": FamilyInitiative.get_waiting_risk(city, "tools"), "upkeep_tools_per_year": upkeep_per_year(city)}

func upkeep_per_year(city: City) -> float:
	var total: float = 0.0
	for building: Building in city.buildings:
		if building.needs_maintenance():
			total += 360.0 / float(building.get_maintenance_interval())
	return total

# Could the land take a fold, and how much pasture is there? (TownLand: pasture within reach.)
func land(city: City) -> Dictionary:
	var pasture: int = 0
	for row: Array in city.local_map:
		for tile: Dictionary in row:
			if tile["type"] == "ground" and not tile["has_trees"] and tile["occupied"] != true:
				pasture += 2 if tile.get("is_hill", false) == true else 1
	var site: Vector2i = Vector2i(-1, -1)
	var factor: float = 0.0
	if not city.households.is_empty():
		site = FamilyInitiative.choose_site(city, city.households[0], "herder")
		if site.x >= 0:
			var probe: Building = Building.new(-1, "herder", site, city.construction.get_size("herder"))
			factor = city.land.get_output_factor(probe)
	return {"open_pasture_tiles": pasture, "fold_site_found": site.x >= 0, "fold_land_factor": factor}

func callings(city: City) -> Dictionary:
	var counts: Dictionary = {}
	for household: Household in city.households:
		for calling in CultureEffects.get_callings(household.values):
			counts[str(calling)] = int(counts.get(str(calling), 0)) + 1
	return counts

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
	print("[WPC] " + line)
