extends SceneTree

# Planning check (docs/FIRST_STAGE_LOOP.md, Planning Pays Off): does a well-planned town clearly
# outdo a careless one on the same land after several years, and does more than one plan do
# well? Plays the same 20 real town sites for five years with the stand-in player under three
# policies:
#
# - careless: everything built far out from the heart (the town building check's "scattered");
# - compact: everything built outward from the heart, homes placed by the player;
# - planned: compact, and once the town runs, fields people walk through are fenced and a
#   storehouse goes up beside the workplace that loses the most of its day to carrying;
# - wishes: planned, and the work families wish for (FamilyAmbitions) is built for them.
#
# Reports towns off the ground, people, households, the share of the working day lost to travel,
# food in store, and the fences and storehouses the plan built.
# Run: <godot> --headless --path . --script res://tests/sim/planning_check.gd > log; then filter for [PLAN]
# (the household log is long: write it to a file rather than a pipe, which stalls Godot on Windows).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

const DAYS: int = 1800
const POLICIES: Array = [
	{"name": "careless", "scattered": true},
	{"name": "compact"},
	{"name": "planned", "planned": true},
	{"name": "wishes", "planned": true, "answer_wishes": true},
]

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var sites: Array = TownBuildingCheck.collect_sites()
	_report("%d towns on real town maps, %d days (%d years)" % [sites.size(), DAYS, DAYS / Calendar.DAYS_PER_YEAR])
	for policy: Dictionary in POLICIES:
		var results: Array[Dictionary] = []
		for site: Dictionary in sites:
			var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
			city.site_profile = site["profile"]
			city.local_map = (site["map"] as Array).duplicate(true)
			results.append(StandInPlayerScript.new().play(city, policy, DAYS))
		summarize(policy["name"], results)
	quit()

func summarize(policy_name: String, results: Array[Dictionary]) -> void:
	var made_it: int = 0
	var totals: Dictionary = {"population": 0.0, "households": 0.0, "travel_share": 0.0, "food": 0.0, "fences": 0.0, "storehouses": 0.0, "content": 0.0, "calling_wishes": 0.0}
	for result: Dictionary in results:
		made_it += 1 if result["off_the_ground"] else 0
		for key: String in totals.keys():
			totals[key] = float(totals[key]) + float(result[key])
	var n: float = maxf(1.0, results.size())
	var reasons: Dictionary = {}
	var buildings: float = 0.0
	for result: Dictionary in results:
		buildings += float(result["buildings"])
		for reason: String in result["reasons"]:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
	_report("%-9s %2d/%d off the ground | people %.0f | households %.1f | travel %.0f%% of the working day | food in store %.0f | fences %.1f | storehouses %.1f | content families %.1f | waiting on a calling %.1f" % [
		policy_name, made_it, results.size(), float(totals["population"]) / n, float(totals["households"]) / n,
		float(totals["travel_share"]) / n * 100.0, float(totals["food"]) / n, float(totals["fences"]) / n, float(totals["storehouses"]) / n, float(totals["content"]) / n, float(totals["calling_wishes"]) / n])
	_report("%-9s buildings %.1f | problems: %s" % [policy_name, buildings / n, str(reasons)])

func _report(line: String) -> void:
	print("[PLAN] " + line)
