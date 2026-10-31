extends SceneTree

# Home site check (HomeSites): the same towns, seeds and families with residential land set aside
# in different ways, families choosing their own sites on it. Families lead (FamilyInitiative,
# social model on); the stand-in player builds nothing else.
#
# - plots:     the stand-in player's plots (two homes ahead, nearest the stockpile), as before;
# - compact:   one block around the stockpile;
# - dispersed: four small blocks well out from the stockpile;
# - poor:      one block in the map's corner farthest from the stockpile;
# - preferred: the dispersed blocks, with the one nearest the stockpile marked preferred.
#
# Reports getting off the ground, people, when founders were all housed, homes families built,
# the share of the working day lost to travel, site-days waiting for builders, and the stages.
# Run: <godot> --headless --path . --script res://tests/sim/home_site_check.gd > homes.log; filter
# for [HOME] (write to a file: a shell pipe stalls Godot on Windows). "-- --years=N --sites=N"

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const LAYOUTS: Array[String] = ["plots", "compact", "dispersed", "poor", "preferred"]
const COMPACT_RADIUS: int = 4
const DISPERSED_OFFSET: int = 12
const BLOCK: int = 4

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 3
	var site_count: int = 12
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
	var sites: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	_report("%d towns on real town maps, %d years, six founding families choosing their own home sites" % [sites.size(), years])
	for layout: String in LAYOUTS:
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
		set_aside(city, layout)
	var land: int = HomeSites.count_land(city)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	result["land"] = land
	result["blocked_notes"] = city.households.filter(func(h: Household) -> bool: return h.home_site_note.contains("cannot build")).size()
	return result

func set_aside(city: City, layout: String) -> void:
	var heart: Vector2i = city.logistics.stockpile_tile
	match layout:
		"compact":
			HomeSites.mark(city, heart - Vector2i(COMPACT_RADIUS, COMPACT_RADIUS), heart + Vector2i(COMPACT_RADIUS, COMPACT_RADIUS), HomeSites.LAND_PERMITTED)
		"dispersed", "preferred":
			var offsets: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
			for offset: Vector2i in offsets:
				var corner: Vector2i = heart + offset * DISPERSED_OFFSET
				HomeSites.mark(city, corner, corner + Vector2i(BLOCK - 1, BLOCK - 1), HomeSites.LAND_PERMITTED)
			if layout == "preferred":
				var corner: Vector2i = heart + offsets[0] * DISPERSED_OFFSET
				HomeSites.mark(city, corner, corner + Vector2i(BLOCK - 1, BLOCK - 1), HomeSites.LAND_PREFERRED)
		"poor":
			var size: Vector2i = city.logistics.map_size()
			var corner: Vector2i = Vector2i(0 if heart.x > size.x / 2 else size.x - 6, 0 if heart.y > size.y / 2 else size.y - 6)
			HomeSites.mark(city, corner, corner + Vector2i(5, 5), HomeSites.LAND_PERMITTED)

func summarize(layout: String, results: Array[Dictionary]) -> void:
	var n: float = maxf(1.0, results.size())
	var made_it: int = 0
	var totals: Dictionary = {}
	var housed: Array[int] = []
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in ["population", "households", "homes_by_families", "travel_share", "stalled_site_days", "land", "blocked_notes"]:
			totals[key] = float(totals.get(key, 0.0)) + float(result[key])
		if int(result["founders_housed_day"]) >= 0:
			housed.append(int(result["founders_housed_day"]))
	housed.sort()
	var avg: Callable = func(key: String) -> float: return float(totals.get(key, 0.0)) / n
	_report("%-10s %2d/%d off the ground | people %5.1f | families %4.1f | founders housed by day %s (%d/%d) | homes families built %.1f | travel %.1f%% of the day | site-days with no builder %.0f | land tiles %.0f | families blocked at the end %.1f" % [
		layout, made_it, results.size(), avg.call("population"), avg.call("households"), str(housed[housed.size() / 2]) if not housed.is_empty() else "-", housed.size(), results.size(),
		avg.call("homes_by_families"), avg.call("travel_share") * 100.0, avg.call("stalled_site_days"), avg.call("land"), avg.call("blocked_notes")])

func _report(line: String) -> void:
	print("[HOME] " + line)
