extends SceneTree

# Player agency (docs/AUTONOMOUS_OCCUPATIONS.md, Player Agency): the occupation check's towns under
# all the rules of autonomous occupations, played by four kinds of player who act only on what the
# game shows them at the time (the sidebar's Needs attention cards, the stores, the town map) and
# only through the controls the game has (the community priority, commissioning a workplace, woods
# marked for clearing). No player orders a family.
#
# - none: never intervenes;
# - informed: answers each warning when it first shows (food falling or out: food first, and a
#   field commissioned; tools low: investment first, and a tool mender commissioned; both calm for a
#   season: no priority), and once hunters and woodcutters share the woods, marks woods for
#   clearing far from the hunting grounds so the woodcutters fell there;
# - late: the same answers, only once food has run out or tools are running out (no woods marked);
# - inappropriate: puts productive investment first from founding and keeps it.
#
# Records when each warning first showed (could the player see it in time?), what the player did
# and when, and what families decided (takeups, reviews, changes, decisions the priority tipped).
#   <godot> --headless --path . --script res://tests/sim/intervention_check.gd -- --conditions=stressed --policies=none,informed > int.log
# Options: --years=N (6), --sites=N (12), --from=K, --mode=all|shortage_survival|existing (the rules).

const TownBuildingCheck = preload("res://tests/sim/town_building_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const Layouts = preload("res://tests/sim/residential_layouts.gd")

const BASE: Dictionary = {"hand_method": true, "families_develop": true, "homes_on_plots": true, "social": true, "land_food": false, "never": ["herder", "fisher", "hunter", "house"]}
const MODES: Dictionary = {
	"existing": ["occupations_first_three", "no_shortage_recognition", "no_survival_awareness", "food_ratio_counts_empty", "stay_value_ignores_yield"],
	"shortage_survival": ["occupations_first_three"],
	"all": [],
}
const DIFFICULT_POOL_REGIONS: int = 30
const DIFFICULT_CACHE: String = "user://wisdom_difficult_seeds.txt"
const CARDS: Array[String] = ["Food stores are falling", "Food has run out", "Tools are low", "Tools are running out", "Workplaces are wearing down", "thinking of leaving"]
const CALM_DAYS: int = 90
const COMMISSION_GAP_DAYS: int = 90
# Woods kept for hunting: the player marks woods for clearing at least this far from any hunting
# ground (a hunter's reach plus a margin).
const HUNTING_MARGIN: int = EconomyBalance.HUNTER_REACH + 3
# Marked woods are felled at a woodcutter's full day (TownWoodland), many times faster than unmarked
# trees: a sensible player marks a small stand, and not again for a while.
const MARK_GAP_DAYS: int = 60

var mode: String = "all"

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var years: int = 6
	var site_count: int = 12
	var first: int = 0
	var conditions: Array[String] = ["ordinary", "stressed", "difficult"]
	var policies: Array[String] = ["none", "informed", "late", "inappropriate"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--sites="):
			site_count = int(argument.trim_prefix("--sites="))
		elif argument.begins_with("--from="):
			first = int(argument.trim_prefix("--from="))
		elif argument.begins_with("--conditions="):
			conditions.assign(argument.trim_prefix("--conditions=").split(","))
		elif argument.begins_with("--policies="):
			policies.assign(argument.trim_prefix("--policies=").split(","))
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	for condition: String in conditions:
		var sites: Array = (get_difficult_sites() if condition == "difficult" else ordinary).slice(first, site_count)
		for policy: String in policies:
			for site: Dictionary in sites:
				var result: Dictionary = play(site, policy, condition == "stressed", years)
				_report("TOWN %s | %s | seed %d | %s" % [condition, policy, int(site["seed"]), JSON.stringify(result)])
	quit()

func play(site: Dictionary, policy: String, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	for meta: String in MODES[mode]:
		city.set_meta(meta, true)
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var state: Dictionary = {"first_card": {}, "actions": [], "calm_since": 0, "last_commission": -COMMISSION_GAP_DAYS, "food_short_days": 0, "tools_out_days": 0, "first_departure": -1, "takeups": {}}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0 and policy == "inappropriate":
			act(town, state, day, "priority investment", func() -> void: town.influence.set_priority(CommunityPriority.INVESTMENT))
		state["food_short_days"] = int(state["food_short_days"]) + (1 if town.resources["food_shortage"] == true else 0)
		if int(town.resources["tools"]) == 0 and town.buildings.any(func(b: Building) -> bool: return b.needs_maintenance()):
			state["tools_out_days"] = int(state["tools_out_days"]) + 1
		if int(state["first_departure"]) < 0 and int(town.resources.get("departed_households", 0)) > 0:
			state["first_departure"] = day
		for building: Building in town.buildings:
			if building.assigned_household_id >= 0 and not (state["takeups"] as Dictionary).has(building.type):
				state["takeups"][building.type] = day
		if day % 7 != 0:
			return
		var titles: Array[String] = []
		for card: Dictionary in SidebarOverviewPage.get_attention(town):
			titles.append(str(card["title"]))
		for name: String in CARDS:
			if titles.any(func(t: String) -> bool: return t.contains(name)) and not (state["first_card"] as Dictionary).has(name):
				state["first_card"][name] = day
		if policy == "informed" or policy == "late":
			respond(town, state, day, titles, policy == "late")
		if policy == "informed":
			protect_hunting_grounds(town, state, day)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	return measure(city, state, bool(result["off_the_ground"]))

# Answers the warnings on the cards with the cards' own buttons: a priority and a commission.
func respond(city: City, state: Dictionary, day: int, titles: Array[String], late: bool) -> void:
	var food_out: bool = titles.has("Food has run out")
	var food_falling: bool = titles.has("Food stores are falling")
	var tools_out: bool = titles.has("Tools are running out")
	var tools_low: bool = titles.has("Tools are low")
	var food_warning: bool = food_out or (food_falling and not late)
	var tools_warning: bool = tools_out or (tools_low and not late)
	if food_warning:
		state["calm_since"] = day
		if city.influence.priority != CommunityPriority.FOOD:
			act(city, state, day, "priority food", func() -> void: city.influence.set_priority(CommunityPriority.FOOD))
		commission(city, state, day, "farm", "forager_garden")
	elif tools_warning:
		state["calm_since"] = day
		if city.influence.priority != CommunityPriority.INVESTMENT:
			act(city, state, day, "priority investment", func() -> void: city.influence.set_priority(CommunityPriority.INVESTMENT))
		if FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS) == 0:
			commission(city, state, day, "tool_mender", "tool_mender")
	elif city.influence.priority != CommunityPriority.NONE and day - int(state["calm_since"]) >= CALM_DAYS:
		act(city, state, day, "no priority", func() -> void: city.influence.set_priority(CommunityPriority.NONE))

# Plans a workplace near the stores, the proper one when the stores can supply it, else hand work.
func commission(city: City, state: Dictionary, day: int, proper: String, hand: String) -> void:
	if day - int(state["last_commission"]) < COMMISSION_GAP_DAYS or city.households.is_empty():
		return
	var building_type: String = proper if city.construction.can_supply(EconomyBalance.get_build_cost(proper)) else hand
	var site: Vector2i = FamilyInitiative.choose_site(city, city.households[0], building_type)
	if site.x < 0:
		return
	if city.construction.request_building(building_type, site, ConstructionProject.REQUESTED_BY_PLAYER) != null:
		state["last_commission"] = day
		(state["actions"] as Array).append({"day": day, "action": "commission " + building_type})

# Once hunters and woodcutters share the woods, and nothing is marked, marks a block of woods for
# clearing as far as the woodcutters reach from any hunting ground, so they fell there.
func protect_hunting_grounds(city: City, state: Dictionary, day: int) -> void:
	if not city.woodland.marked.is_empty() or day - int(state.get("last_mark", -MARK_GAP_DAYS)) < MARK_GAP_DAYS:
		return
	var hunting: Array[Vector2i] = []
	var cutting: Array[Vector2i] = []
	for building: Building in city.buildings:
		var base: String = BuildingTiers.get_base_type(building.type)
		if base == Building.BUILDING_HUNTER:
			hunting.append(building.tile)
		elif base == "woodcutter":
			cutting.append(building.tile)
	if hunting.is_empty() or cutting.is_empty():
		return
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			if city.local_map[y][x]["has_trees"] != true:
				continue
			var tile: Vector2i = Vector2i(x, y)
			var from_hunting: float = INF
			for h: Vector2i in hunting:
				from_hunting = minf(from_hunting, Vector2(tile).distance_to(Vector2(h)))
			if from_hunting < HUNTING_MARGIN:
				continue
			var from_cutting: float = INF
			for c: Vector2i in cutting:
				from_cutting = minf(from_cutting, Vector2(tile).distance_to(Vector2(c)))
			var score: float = -from_cutting
			if score > best_score:
				best_score = score
				best = tile
	if best.x < 0:
		return
	state["last_mark"] = day
	act(city, state, day, "mark woods %s" % str(best), func() -> void: city.woodland.mark_block(best - Vector2i.ONE, best + Vector2i.ONE))

func act(_city: City, state: Dictionary, day: int, what: String, do: Callable) -> void:
	do.call()
	(state["actions"] as Array).append({"day": day, "action": what})

func measure(city: City, state: Dictionary, off_the_ground: bool) -> Dictionary:
	var influence: TownInfluence = city.influence
	var worked: Dictionary = {}
	var proper: int = 0
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null:
			var trade: String = BuildingTiers.get_base_type(holding.type)
			worked[trade] = int(worked.get(trade, 0)) + 1
			proper += 0 if holding.is_tier0() else 1
	var triggers: Dictionary = {}
	var changed_for: Dictionary = {}
	for entry: Dictionary in influence._work_review_log:
		if entry.has("deferred"):
			continue
		for trigger: String in entry["triggers"]:
			triggers[trigger] = int(triggers.get(trigger, 0)) + 1
			if bool(entry["changed"]):
				changed_for[trigger] = int(changed_for.get(trigger, 0)) + 1
	var swayed: int = 0
	for key: String in influence.swayed.keys():
		swayed += int(influence.swayed[key])
	return {
		"people": city.get_total_population(), "households": city.households.size(),
		"kept": 1 if city.households.size() >= EconomyBalance.FOUNDING_FAMILIES else 0, "off_the_ground": off_the_ground,
		"departed": int(city.resources.get("departed_households", 0)), "first_departure": state["first_departure"],
		"food_short_days": state["food_short_days"], "tools_out_days": state["tools_out_days"],
		"worked": worked, "trades": worked.size(), "proper": proper, "improvements": influence.improvements_started,
		"reviews": influence.work_reviews, "changes": influence.work_changes, "triggers": triggers, "changed_for": changed_for,
		"swayed": influence.swayed.duplicate(), "swayed_total": swayed, "first_card": state["first_card"], "actions": state["actions"], "takeups": state["takeups"],
	}

func get_difficult_sites() -> Array:
	var by_seed: Dictionary = {}
	for site: Dictionary in TownBuildingCheck.collect_sites(DIFFICULT_POOL_REGIONS, 2):
		by_seed[int(site["seed"])] = site
	var picked: Array = []
	for line: String in FileAccess.get_file_as_string(DIFFICULT_CACHE).split("\n", false):
		picked.append(by_seed[int(line)])
	return picked

func _report(line: String) -> void:
	print("[INT] " + line)
