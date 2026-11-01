extends SceneTree

# Home site check (HomeSites): the same towns, seeds and families with residential land set aside
# in different ways, families choosing their own sites on it. Families lead (FamilyInitiative,
# social model on); the stand-in player builds nothing else.
#
# - starting:      the modest starting land a passive player has (HomeSites.set_aside_starting_land);
# - plots:         the stand-in player's plots, two homes ahead, nearest the stockpile (reference:
#                  its homes come over time, not all at once);
# - compact, dispersed, poor, far_only, preferred_far: the same housing capacity from the first day,
#                  placed differently (residential_layouts.gd); preferred_far sets the player's hope
#                  against families' wish to live near their work;
# - twin, twin_preferred (run with --layouts=twin,twin_preferred): two equal blocks on opposite
#                  sides, plain, then the first preferred; homes on the first block, by temperament.
#
# Reports getting off the ground, people, when founders were all housed, homes families built,
# the share of the working day lost to travel, site-days waiting for builders, and, where land is
# preferred, the share of homes on it, by how readily families heed the gathering.
# Run: <godot> --headless --path . --script res://tests/sim/home_site_check.gd > homes.log; filter
# for [HOME] (write to a file: a shell pipe stalls Godot on Windows). "-- --years=N --sites=N"

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const LAYOUTS: Array[String] = ["starting", "plots", "compact", "dispersed", "poor", "far_only", "preferred_far"]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 3
	var site_count: int = 12
	var only: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--layouts="):
			only.assign(argument.trim_prefix("--layouts=").split(","))
	var sites: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	_report("%d towns on real town maps, %d years, six founding families choosing their own home sites" % [sites.size(), years])
	# --layouts= picks among LAYOUTS and the twin layouts, which only run when named.
	for layout: String in (only if not only.is_empty() else LAYOUTS):
		var results: Array[Dictionary] = []
		for site: Dictionary in sites:
			results.append(play(site, layout, years))
		summarize(layout, results)
	quit()

func play(site: Dictionary, layout: String, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	city.logistics.ensure_ready()
	var scenario: Dictionary = BASE.duplicate(true)
	if layout == "plots":
		(scenario["never"] as Array).erase("house")
	else:
		Layouts.set_aside(city, layout)
	var room: int = HomeSites.count_room(city)
	var sides: Array[Vector2i] = Layouts.get_twin_centres(city, Layouts.get_heart(city)) if layout.begins_with("twin") else ([] as Array[Vector2i])
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	result["room"] = room
	result["blocked_notes"] = city.households.filter(func(h: Household) -> bool: return h.home_site_note.contains("cannot build")).size()
	result["homes_by_group"] = count_homes_by_group(city, sides)
	result["land_under_work"] = count_land_under_other_buildings(city)
	return result

# Residential tiles that ended up under something other than a home (workplaces, fields, stores,
# their sites): nothing reserves residential land for homes alone.
func count_land_under_other_buildings(city: City) -> int:
	var count: int = 0
	var footprints: Array = []
	for building: Building in city.buildings:
		if not building.is_house():
			footprints.append(TownLogistics.footprint(building.tile, building.size))
	for project: ConstructionProject in city.construction.projects:
		if not project.is_home() and project.kind == ConstructionProject.KIND_BUILDING:
			footprints.append(project.get_footprint())
	for footprint: Array in footprints:
		for tile: Vector2i in footprint:
			if city.construction.is_inside(tile) and HomeSites.get_land(city, tile) != HomeSites.LAND_NONE:
				count += 1
	return count

# Homes standing at the end, by the land under them and how readily the family heeds the gathering:
# {"heeds" | "self_governing" | "other": {"preferred": n, "other": n}}. With twin `sides`, "preferred"
# is the first side (nearer its centre), plain or preferred, so both twin layouts count alike.
func count_homes_by_group(city: City, sides: Array[Vector2i] = []) -> Dictionary:
	var groups: Dictionary = {}
	for household: Household in city.households:
		if household.residence_building_id < 0 or household.residence_building_id >= city.buildings.size():
			continue
		var home: Building = city.buildings[household.residence_building_id]
		var group: String = "other"
		if HouseholdCharacter.get_strength(household, "deferential") > 0:
			group = "heeds"
		elif HouseholdCharacter.get_strength(household, "self_governing") > 0:
			group = "self_governing"
		if not groups.has(group):
			groups[group] = {"preferred": 0, "other": 0}
		var on_preferred: bool = HomeSites.get_land(city, home.tile) == HomeSites.LAND_PREFERRED
		if not sides.is_empty():
			on_preferred = Vector2(home.tile).distance_to(Vector2(sides[0])) < Vector2(home.tile).distance_to(Vector2(sides[1]))
		groups[group]["preferred" if on_preferred else "other"] += 1
	return groups

func summarize(layout: String, results: Array[Dictionary]) -> void:
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var totals: Dictionary = {}
	var housed: Array[int] = []
	var groups: Dictionary = {}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in ["population", "households", "homes_by_families", "travel_share", "stalled_site_days", "room", "blocked_notes", "land_under_work"]:
			totals[key] = float(totals.get(key, 0.0)) + float(result[key])
		if int(result["founders_housed_day"]) >= 0:
			housed.append(int(result["founders_housed_day"]))
		for group: String in (result["homes_by_group"] as Dictionary).keys():
			if not groups.has(group):
				groups[group] = {"preferred": 0, "other": 0}
			for key: String in ["preferred", "other"]:
				groups[group][key] += int(result["homes_by_group"][group][key])
	housed.sort()
	var avg: Callable = func(key: String) -> float: return float(totals.get(key, 0.0)) / n
	_report("%-13s %2d/%d off the ground | people %5.1f | families %4.1f | founders housed by day %s (%d/%d) | homes families built %.1f | travel %.1f%% of the day | site-days with no builder %.0f | spots at the start %.0f | families blocked at the end %.1f | residential tiles under other buildings %.1f" % [
		layout, made_it, results.size(), avg.call("population"), avg.call("households"), str(housed[housed.size() / 2]) if not housed.is_empty() else "-", housed.size(), results.size(),
		avg.call("homes_by_families"), avg.call("travel_share") * 100.0, avg.call("stalled_site_days"), avg.call("room"), avg.call("blocked_notes"), avg.call("land_under_work")])
	if layout == "preferred_far" or layout.begins_with("twin"):
		var words: Array[String] = []
		for group: String in ["heeds", "other", "self_governing"]:
			if groups.has(group):
				var all: int = int(groups[group]["preferred"]) + int(groups[group]["other"])
				words.append("%s %d of %d" % [group, groups[group]["preferred"], all])
		_report("%-13s homes on the preferred land at the end, by how readily the family heeds the gathering: %s" % [layout, ", ".join(words)])

func _report(line: String) -> void:
	print("[HOME] " + line)
