extends SceneTree

# Player agency (docs/AUTONOMOUS_OCCUPATIONS.md, Player Agency): the occupation check's towns under
# all the rules of autonomous occupations, played by four kinds of player who act only on what the
# game shows them at the time (the sidebar's Needs attention cards, the stores, the town map) and
# only through the controls the game has (the community priority, commissioning a workplace, woods
# marked for clearing). No player orders a family.
#
# - none: never intervenes;
# - informed: answers each warning with what its card offers first (round 3, owner 2026-11-01):
#   food short ("Food will run short", "grows less food than it eats", "Food has run out"): asks
#   families to grow food (FocusedAppeal) and marks land near the families' homes to till; tools
#   short with no one making them: asks someone to take up toolmaking; families finding no land:
#   land near them marked to till; hunting grounds being felled: the woods round the lodges kept
#   (TownWoodland.protect_block). No priority, no commissions;
# - informed_appeal, informed_land: the informed player's appeals alone, its land tools alone;
# - priority_switcher: answers every warning with a whole-town priority (food first, investment
#   first), as the cards suggested before, and commissions the workplace the card offered;
# - inappropriate: puts productive investment first from founding and keeps it;
# - overprotect: keeps every wood within reach of the town from its founding;
# - (earlier rounds) informed_priority, informed_commission, late;
# - informed_appeal_once: the appeals only, each good asked for once in the town's life (owner,
#   2026-11-01: the benefit of one appeal apart from repeated ones);
# - keep_hunting: only keeps the woods round lodges whose land is failing (two thirds of their best
#   yield or less: the late card before 2026-11-02, kept as "late" preservation);
#   keep_lodges: keeps the woods round every hunting workplace as soon as a family works it;
# - keep_on_warning: keeps the woods round the lodges the early hunting-grounds card names, with the
#   card's own buttons, the week it shows (owner, 2026-11-02). The informed players answer that card
#   the same way.
#
# Records when each warning first showed (could the player see it in time?), what the player did
# and when, and what families decided (takeups, reviews, changes, decisions the priority tipped).
#   <godot> --headless --path . --script res://tests/sim/intervention_check.gd -- --conditions=stressed --policies=none,informed > int.log
# Options: --years=N (6), --sites=N (12), --from=K, --mode=all|shortage_survival|existing (the rules),
# --seed=N (only that town) with --trace (its timeline: warnings, the player's acts, every family's
# choice and review of its work with reasons, and the town each month; filter for [TRACE]).
# Diagnostics (Priority 5): --leave-out=hunter,herder with --leave-out-until=DAY (trades families may
# not choose, until a day); --veto=HOUSEHOLD:OCCUPATION:UNTIL[;...] (one family may not choose one
# trade until a day: what that one decision did); --meta=a,b (comparison metas). With --trace, each first choice of work is printed
# ranked, with its reasons and the town's food as the family saw it.
# The tool trap (Phase 5 diagnostic): --trace-tools (with --seed=N) prints, every 30 days, the tool and
# wood stores against what the queue has claimed and the protected reserve keeps back, the proper
# workplaces' upkeep (paid from the store, mended by their families, or missed), toolmaking and its
# output, and, whenever it changes, each family's word on improving its work (filter for [TOOLS]).
# Founding provisions (Phase 7 diagnostic, owner 2026-11-02; comparison only): --provisions=food:380,tools:6
# sets what the expedition arrives with (default 300 food, 45 wood, 14 tools; worth 507.5 in grain
# at EconomyBalance.VALUE_IN_GRAIN, by which equal-value cargoes are compared).

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
const CARDS: Array[String] = ["Food supply not yet established", "Food will run short", "The town grows less food than it eats", "Food stores are falling", "Food has run out", "Tools are low", "Tools are running out", "Workplaces are wearing down", "thinking of leaving", "Families find no land for their work", "Hunting grounds are being felled", SidebarOverviewPage.HUNTING_GROUNDS_TITLE]
const NO_LAND: String = "Families find no land for their work"
const FELLED: String = "Hunting grounds are being felled"
# A block of land marked to till, tiles per side, and how often the player marks again.
const TILL_SIDE: int = 4
const CALM_DAYS: int = 90
const COMMISSION_GAP_DAYS: int = 90
# Woods kept for hunting: the player marks woods for clearing at least this far from any hunting
# ground (a hunter's reach plus a margin).
const HUNTING_MARGIN: int = EconomyBalance.HUNTER_REACH + 3
# Marked woods are felled at a woodcutter's full day (TownWoodland), many times faster than unmarked
# trees: a sensible player marks a small stand, and not again for a while.
const MARK_GAP_DAYS: int = 60

var mode: String = "all"
var only_seed: int = -1
var trace: bool = false
var trace_tools: bool = false
var left_out: Array[String] = []
var left_out_until: int = 1 << 30
var vetoes: Array = []
var extra_metas: Array[String] = []
var provisions: Dictionary = {}

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
		elif argument.begins_with("--seed="):
			only_seed = int(argument.trim_prefix("--seed="))
		elif argument == "--trace":
			trace = true
		elif argument == "--trace-tools":
			trace_tools = true
		elif argument.begins_with("--leave-out="):
			left_out.assign(argument.trim_prefix("--leave-out=").split(","))
		elif argument.begins_with("--leave-out-until="):
			left_out_until = int(argument.trim_prefix("--leave-out-until="))
		elif argument.begins_with("--provisions="):
			for part: String in argument.trim_prefix("--provisions=").split(","):
				provisions[part.get_slice(":", 0)] = int(part.get_slice(":", 1))
		elif argument.begins_with("--meta="):
			extra_metas.assign(argument.trim_prefix("--meta=").split(","))
		elif argument.begins_with("--veto="):
			for veto: String in argument.trim_prefix("--veto=").split(";"):
				var parts: PackedStringArray = veto.split(":")
				vetoes.append({"household": int(parts[0]), "occupation": parts[1], "until": int(parts[2])})
	var ordinary: Array = TownBuildingCheck.collect_sites().slice(0, site_count)
	for condition: String in conditions:
		var sites: Array = (get_difficult_sites() if condition == "difficult" else ordinary).slice(first, site_count) if only_seed < 0 else (get_difficult_sites() if condition == "difficult" else TownBuildingCheck.collect_sites())
		for policy: String in policies:
			for site: Dictionary in sites:
				if only_seed >= 0 and int(site["seed"]) != only_seed:
					continue
				var result: Dictionary = play(site, policy, condition == "stressed", years)
				_report("TOWN %s | %s | seed %d | %s" % [condition, policy, int(site["seed"]), JSON.stringify(result)])
	quit()

func play(site: Dictionary, policy: String, stress: bool, years: int) -> Dictionary:
	var city: City = City.new("Player Town", Vector2(site["site"]), City.ROLE_PLAYER, EconomyBalance.FOUNDING_FAMILIES, int(site["seed"]))
	city.site_profile = site["profile"]
	city.local_map = (site["map"] as Array).duplicate(true)
	Layouts.set_aside(city, "starting")
	for good: String in provisions.keys():
		city.resources[good] = int(provisions[good])
	for meta: String in MODES[mode]:
		city.set_meta(meta, true)
	for meta: String in extra_metas:
		city.set_meta(meta, true)
	if not left_out.is_empty():
		city.set_meta("occupations_left_out", left_out)
		city.set_meta("occupations_left_out_until", left_out_until)
	if not vetoes.is_empty():
		city.set_meta("occupation_vetoes", vetoes)
	if trace:
		city.set_meta("trace_choices", [])
	var scenario: Dictionary = BASE.duplicate(true)
	scenario["hard_winter"] = stress
	var state: Dictionary = {"first_card": {}, "actions": [], "calm_since": 0, "last_commission": -COMMISSION_GAP_DAYS, "food_short_days": 0, "tools_out_days": 0, "first_departure": -1, "takeups": {},
		"years": {}, "first_year_food_short_days": 0, "first_year_tools_out_days": 0, "work_history": {}, "founders": [], "woodcutter_days_lost": 0.0, "hunting_warning": {}, "made": {}}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day == 0 and policy == "inappropriate":
			act(town, state, day, "priority investment", func() -> void: town.influence.set_priority(CommunityPriority.INVESTMENT))
		state["food_short_days"] = int(state["food_short_days"]) + (1 if town.resources["food_shortage"] == true else 0)
		if day < Calendar.DAYS_PER_YEAR and town.resources["food_shortage"] == true:
			state["first_year_food_short_days"] = int(state["first_year_food_short_days"]) + 1
		if int(town.resources["tools"]) == 0 and town.buildings.any(func(b: Building) -> bool: return b.needs_maintenance()):
			state["tools_out_days"] = int(state["tools_out_days"]) + 1
			if day < Calendar.DAYS_PER_YEAR:
				state["first_year_tools_out_days"] = int(state["first_year_tools_out_days"]) + 1
		record_day(town, day, state)
		if int(state["first_departure"]) < 0 and int(town.resources.get("departed_households", 0)) > 0:
			state["first_departure"] = day
		for building: Building in town.buildings:
			if building.assigned_household_id >= 0 and not (state["takeups"] as Dictionary).has(building.type):
				state["takeups"][building.type] = day
		if trace:
			trace_day(town, day, state)
		if trace_tools:
			trace_tool_day(town, day, state)
		if day % 7 != 0:
			return
		var titles: Array[String] = []
		for card: Dictionary in SidebarOverviewPage.get_attention(town):
			titles.append(str(card["title"]))
		for name: String in CARDS:
			if titles.any(func(t: String) -> bool: return t.contains(name)) and not (state["first_card"] as Dictionary).has(name):
				state["first_card"][name] = day
				if trace:
					print("[TRACE] day %d | WARNING SHOWN: %s" % [day, name])
		if policy in ["late", "informed_priority", "informed_commission", "priority_switcher"]:
			respond(town, state, day, titles, policy == "late", policy != "informed_commission", policy != "informed_priority")
		if policy in ["informed", "informed_appeal", "informed_land", "informed_appeal_once"]:
			answer_with_cards(town, state, day, titles, policy != "informed_land", policy != "informed_appeal" and policy != "informed_appeal_once", policy == "informed_appeal_once")
		if policy == "keep_hunting":
			keep_hunting_grounds(town, state, day)
		if policy == "keep_on_warning" and titles.has(SidebarOverviewPage.HUNTING_GROUNDS_TITLE):
			keep_as_card_offers(town, state, day)
		if policy == "keep_lodges":
			keep_lodge_woods(town, state, day)
		if policy == "overprotect" and day == 7:
			keep_all_woods(town, state, day)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	return measure(city, state, bool(result["off_the_ground"]))

# Answers the warnings on the cards with the cards' own buttons: a priority and a commission.
func respond(city: City, state: Dictionary, day: int, titles: Array[String], late: bool, priorities: bool = true, commissions: bool = true) -> void:
	var food_out: bool = titles.has("Food has run out")
	var food_falling: bool = titles.has("Food stores are falling") or titles.has("Food will run short") or titles.has("The town grows less food than it eats")
	var tools_out: bool = titles.has("Tools are running out")
	var tools_low: bool = titles.has("Tools are low")
	var food_warning: bool = food_out or (food_falling and not late)
	var tools_warning: bool = tools_out or (tools_low and not late)
	if food_warning:
		state["calm_since"] = day
		if priorities and city.influence.priority != CommunityPriority.FOOD:
			act(city, state, day, "priority food", func() -> void: city.influence.set_priority(CommunityPriority.FOOD))
		if commissions:
			commission(city, state, day, "farm", "forager_garden")
	elif tools_warning:
		state["calm_since"] = day
		if priorities and city.influence.priority != CommunityPriority.INVESTMENT:
			act(city, state, day, "priority investment", func() -> void: city.influence.set_priority(CommunityPriority.INVESTMENT))
		if commissions and FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS) == 0:
			commission(city, state, day, "tool_mender", "tool_mender")
	elif city.influence.priority != CommunityPriority.NONE and day - int(state["calm_since"]) >= CALM_DAYS:
		act(city, state, day, "no priority", func() -> void: city.influence.set_priority(CommunityPriority.NONE))

# What the cards offer first: a focused appeal for what is short, land to till, woods to keep.
func answer_with_cards(city: City, state: Dictionary, day: int, titles: Array[String], appeals: bool, land: bool, once: bool = false) -> void:
	# The founding card ("not yet established") is answered as before it had its own title, so this
	# round's players stay comparable with round 3's.
	var food_short: bool = titles.has("Food supply not yet established") or titles.has("Food will run short") or titles.has("The town grows less food than it eats") or titles.has("Food has run out")
	var tools_short: bool = (titles.has("Tools are low") or titles.has("Tools are running out")) and FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS) == 0
	var asked: Array = (state["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["action"]))
	if appeals and food_short and not FocusedAppeal.is_active(city, TownInfluence.ACTIVITY_FOOD) and not (once and asked.has("appeal food")):
		act(city, state, day, "appeal food", func() -> void: FocusedAppeal.make(city, TownInfluence.ACTIVITY_FOOD))
	if appeals and tools_short and not FocusedAppeal.is_active(city, TownInfluence.ACTIVITY_TOOLS) and not (once and asked.has("appeal tools")):
		act(city, state, day, "appeal tools", func() -> void: FocusedAppeal.make(city, TownInfluence.ACTIVITY_TOOLS))
	if land:
		if titles.has(NO_LAND) or food_short:
			till_near_blocked(city, state, day)
		if titles.has(FELLED):
			keep_hunting_grounds(city, state, day)
		if titles.has(SidebarOverviewPage.HUNTING_GROUNDS_TITLE):
			keep_as_card_offers(city, state, day)

# Hunting grounds are being felled: keeps the woods within a lodge's reach, round each lodge whose
# land is failing (as the card shows), so no woodcutter fells there.
func keep_hunting_grounds(city: City, state: Dictionary, day: int) -> void:
	for building: Building in city.buildings:
		if TownLand.get_reach_kind(building.type) != "woods" or building.assigned_household_id < 0 or building.peak_land_yield < SidebarOverviewPage.FAILING_MIN_PEAK:
			continue
		if city.land.get_reach_factor(building) > building.peak_land_yield * SidebarOverviewPage.FAILING_SHARE:
			continue
		var reach: Vector2i = Vector2i(EconomyBalance.HUNTER_REACH, EconomyBalance.HUNTER_REACH)
		var from: Vector2i = building.tile - reach
		var to: Vector2i = building.tile + building.size - Vector2i.ONE + reach
		if city.woodland.get_wooded_in_block(from, to).all(func(tile: Vector2i) -> bool: return city.woodland.is_protected(tile)):
			continue
		act(city, state, day, "keep woods %s" % str(building.tile), func() -> void: city.woodland.protect_block(from, to))

# The early hunting-grounds card answered with its own buttons: the woods round each lodge it names
# kept, as a click on its keep button does (main.gd, keep_hunting_ground).
func keep_as_card_offers(city: City, state: Dictionary, day: int) -> void:
	for card: Dictionary in SidebarOverviewPage.get_hunting_ground_cards(city):
		for button: Dictionary in card["buttons"]:
			if str(button["action"]["action"]) != "keep_hunting_ground":
				continue
			for building: Building in city.buildings:
				if building.id == int(button["action"]["building"]):
					act(city, state, day, "keep hunting ground %s" % str(building.tile), func() -> void: city.woodland.keep_hunting_ground(building))

# Keeping early: the woods within reach of every hunting workplace a family works, from the week it
# works it, before any felling shows.
func keep_lodge_woods(city: City, state: Dictionary, day: int) -> void:
	for building: Building in city.buildings:
		if TownLand.get_reach_kind(building.type) != "woods" or building.assigned_household_id < 0:
			continue
		var reach: Vector2i = Vector2i(EconomyBalance.HUNTER_REACH, EconomyBalance.HUNTER_REACH)
		var from: Vector2i = building.tile - reach
		var to: Vector2i = building.tile + building.size - Vector2i.ONE + reach
		if city.woodland.get_wooded_in_block(from, to).all(func(tile: Vector2i) -> bool: return city.woodland.is_protected(tile)):
			continue
		act(city, state, day, "keep woods %s" % str(building.tile), func() -> void: city.woodland.protect_block(from, to))

# A poor use of keeping: every wood within reach of the town kept from its founding.
func keep_all_woods(city: City, state: Dictionary, day: int) -> void:
	var heart: Vector2i = city.logistics.stockpile_tile if city.logistics.stockpile_tile.x >= 0 else Vector2i(city.logistics.map_size() / 2)
	var side: int = TownWoodland.MAX_MARK_SIDE
	for by in range(heart.y - 24, heart.y + 24, side):
		for bx in range(heart.x - 24, heart.x + 24, side):
			var from: Vector2i = Vector2i(bx, by)
			var to: Vector2i = from + Vector2i(side - 1, side - 1)
			if not city.woodland.get_wooded_in_block(from, to).is_empty():
				city.woodland.protect_block(from, to)
	(state["actions"] as Array).append({"day": day, "action": "keep all woods (%d tiles)" % city.woodland.protected.size()})

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

# Families find no land for their work: marks open ground nearest the first blocked family's home to
# till; the families on fields till it as part of their work (TownFarmland).
func till_near_blocked(city: City, state: Dictionary, day: int) -> void:
	if not city.farmland.marked.is_empty() or day - int(state.get("last_till", -MARK_GAP_DAYS)) < MARK_GAP_DAYS:
		return
	var anchor: Vector2i = Vector2i(-1, -1)
	for household: Household in city.households:
		if household.blocked_work_type != "" and day - household.blocked_work_day <= SidebarOverviewPage.NO_LAND_DAYS:
			anchor = FamilyInitiative.get_anchor(city, household)
			break
	if anchor.x < 0 and not city.households.is_empty():
		anchor = FamilyInitiative.get_anchor(city, city.households[0])
	if anchor.x < 0:
		return
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for y in range(city.local_map.size()):
		for x in range((city.local_map[y] as Array).size()):
			if TownFarmland.can_till(city.local_map[y][x]):
				var distance: float = Vector2(x, y).distance_to(Vector2(anchor))
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(x, y)
	if best.x < 0:
		return
	state["last_till"] = day
	act(city, state, day, "till land %s" % str(best), func() -> void: city.farmland.mark_block(best, best + Vector2i(TILL_SIDE - 1, TILL_SIDE - 1)))

# Hunting grounds are being felled, and nothing is marked: marks a block of woods for clearing as far
# as the woodcutters reach from any hunting ground, so they fell there.
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

# What the comparison follows each day: the town at the end of years 1 and 3; every family's work as it
# changes (which trades families take up, and the founding families' first year); what kept woods
# cost the woodcutters (days of woodcutting lost to the walk); and, the first time the early
# hunting-grounds card would show, how much of their bag the lodges it names still had.
func record_day(city: City, day: int, state: Dictionary) -> void:
	if day == 0:
		for household: Household in city.households:
			(state["founders"] as Array).append(household.id)
	if day == Calendar.DAYS_PER_YEAR - 1 or day == 3 * Calendar.DAYS_PER_YEAR - 1:
		state["years"][str((day + 1) / Calendar.DAYS_PER_YEAR)] = {"people": city.get_total_population(), "households": city.households.size(), "food": int(city.resources["food"]), "tools": int(city.resources["tools"])}
	var history: Dictionary = state["work_history"]
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding == null:
			continue
		var trade: String = BuildingTiers.get_base_type(holding.type)
		var list: Array = history.get(household.id, [])
		if list.is_empty() or str((list[list.size() - 1] as Array)[1]) != trade:
			list.append([day, trade])
			history[household.id] = list
	# What the land trades bring in (about: each worked workplace at its family's pace, with its land
	# and season, as FamilyInitiative counts it), summed over the game.
	var made: Dictionary = state["made"]
	for building: Building in city.buildings:
		var base: String = BuildingTiers.get_base_type(building.type)
		if building.assigned_household_id >= 0 and building.can_produce() and base in [Building.BUILDING_FISHER, Building.BUILDING_HUNTER, Building.BUILDING_HERDER]:
			var reach: float = city.land.get_reach_factor(building)
			made[base] = float(made.get(base, 0.0)) + FamilyInitiative.get_building_output(city, building) / maxf(reach, 0.0001) * city.land.get_output_factor(building)
	if not city.woodland.protected.is_empty():
		for woodcutter: Building in city.woodland.get_woodcutters():
			state["woodcutter_days_lost"] = float(state["woodcutter_days_lost"]) + (1.0 - city.woodland.get_felling_factor(woodcutter))
	if day % 7 == 0 and (state["hunting_warning"] as Dictionary).is_empty():
		var threats: Array[Dictionary] = city.woodland.get_hunting_threats()
		if not threats.is_empty():
			var factors: Array = []
			for threat: Dictionary in threats:
				var lodge: Building = threat["building"]
				factors.append({"lodge": lodge.id, "factor": snappedf(float(threat["factor"]), 0.01), "peak": snappedf(maxf(lodge.peak_land_yield, float(threat["factor"])), 0.01), "after": snappedf(float(threat["after"]), 0.01), "days": roundi(minf(9999.0, float(threat["days"])))})
			state["hunting_warning"] = {"day": day, "lodges": factors}

# Which trades families took up over the game (each change counted), and how the founding families
# worked in their first year: how many herded at some point, and each one's trades.
static func summarize_work(state: Dictionary) -> Dictionary:
	var taken: Dictionary = {}
	var founding_herders: int = 0
	var founding_first_year: Dictionary = {}
	for id in state["work_history"].keys():
		var list: Array = state["work_history"][id]
		for entry: Array in list:
			taken[entry[1]] = int(taken.get(entry[1], 0)) + 1
		if (state["founders"] as Array).has(id):
			var first_year: Array = list.filter(func(e: Array) -> bool: return int(e[0]) < Calendar.DAYS_PER_YEAR).map(func(e: Array) -> String: return str(e[1]))
			founding_first_year[str(id)] = first_year
			founding_herders += 1 if first_year.has(Building.BUILDING_HERDER) else 0
	return {"taken": taken, "founding_herders": founding_herders, "founding_first_year": founding_first_year}

func act(_city: City, state: Dictionary, day: int, what: String, do: Callable) -> void:
	do.call()
	(state["actions"] as Array).append({"day": day, "action": what})
	if trace:
		print("[TRACE] day %d | PLAYER: %s" % [day, what])

# One town's day for the trace: families' new choices of work and reviews with their reasons, and
# the town each month.
func trace_day(city: City, day: int, state: Dictionary) -> void:
	var choices: Array = city.get_meta("trace_choices", [])
	for entry: Dictionary in choices:
		var ranked: Array[String] = []
		for option: Dictionary in entry["ranked"]:
			ranked.append("%s %.2f [%s | against: %s]" % [option["occupation"], float(option["score"]), "; ".join(option["for"]), "; ".join(option["against"])])
		print("[TRACE] day %d | CHOICE family %d: hardship %.2f, food coverage %.2f, grows %.2f of what it eats | %s" % [int(entry["day"]), int(entry["household"]), float(entry["hardship"]), float(entry["coverage"]), float(entry["ratio"]), " >> ".join(ranked)])
	choices.clear()
	var seen: Dictionary = state.get("notes", {})
	for household: Household in city.households:
		var note: String = household.initiative_note
		if (note.begins_with("Took up") or note.begins_with("It is leaving")) and seen.get(household.id, "") != note:
			print("[TRACE] day %d | family %d (%s) %s" % [day, household.id, "/".join(CultureEffects.get_callings(household.values)), note.substr(0, 260)])
		seen[household.id] = note
	state["notes"] = seen
	var log: Array = city.influence._work_review_log
	var reviewed: int = int(state.get("reviewed", 0))
	while reviewed < log.size():
		var entry: Dictionary = log[reviewed]
		if not entry.has("deferred"):
			var who: Household = city.get_household_by_id(int(entry["household"]))
			var blocked: String = ""
			if who != null and not bool(entry["changed"]) and float(entry["margin"]) >= OccupationReview.CHANGE_MARGIN and who.work_review_note.contains("found no free land"):
				blocked = " (BLOCKED: it found no free land)"
			print("[TRACE] day %d | REVIEW family %d on %s, triggers %s -> best %s, margin %.2f, %s%s | for: %s | stays for: %s" % [int(entry["day"]), int(entry["household"]), entry["from"], str(entry["triggers"]), entry["to"], float(entry["margin"]), "CHANGED" if bool(entry["changed"]) else "stayed", blocked, "; ".join(entry["for"]), "; ".join(entry["against"])])
		reviewed += 1
	state["reviewed"] = reviewed
	if day % 60 == 0:
		var work: Dictionary = {}
		for building: Building in city.buildings:
			if building.is_production_building():
				var key: String = building.type + ("" if building.assigned_household_id >= 0 else "(empty)")
				work[key] = int(work.get(key, 0)) + 1
		print("[TRACE] day %d | TOWN food %d (%.0f days, grows %.2f of what it eats, outlook shortfall %.2f) | tools %d (shortage %.2f) | families %d, people %d | priority '%s' | work %s" % [day, int(city.resources["food"]), FamilyInitiative.get_food_days(city), FamilyInitiative.get_food_ratio(city), FamilyInitiative.get_food_outlook(city), int(city.resources["tools"]), FamilyInitiative.get_shortage(city, TownInfluence.ACTIVITY_TOOLS), city.households.size(), city.get_total_population(), city.influence.priority, str(work)])

# One town's tools, day by day, summed and printed every 30 days (--trace-tools).
func trace_tool_day(city: City, day: int, state: Dictionary) -> void:
	var t: Dictionary = state.get("tools_trace", {"paid": 0, "mended": 0, "missed": 0, "levels": {}, "notes": {}, "mended_total": 0, "made": 0.0})
	state["tools_trace"] = t
	var levels: Dictionary = t["levels"]
	var mended_now: int = city.influence.mended_upkeep
	var mended_today: int = mended_now - int(t["mended_total"])
	t["mended_total"] = mended_now
	# An upkeep fell due where a workplace's timer started again: met if its level did not fall.
	var paid_today: int = 0
	for building: Building in city.buildings:
		if not building.needs_maintenance():
			continue
		var before: Array = levels.get(building.id, [building.maintenance_timer, building.maintenance_level])
		if building.maintenance_timer < int(before[0]):
			if building.maintenance_level >= int(before[1]):
				paid_today += 1
			else:
				t["missed"] = int(t["missed"]) + 1
		levels[building.id] = [building.maintenance_timer, building.maintenance_level]
	t["mended"] = int(t["mended"]) + mended_today
	t["paid"] = int(t["paid"]) + maxi(0, paid_today - mended_today)
	for building: Building in city.buildings:
		if building.can_produce() and FamilyInitiative.get_activity(building.type) == TownInfluence.ACTIVITY_TOOLS:
			var family: Household = city.get_household_by_id(building.assigned_household_id)
			var pace: float = city.get_family_labor_factor(family) * HouseholdEconomy.get_output_factor(city, family, building.type) * city.get_work_time_factor(building) * (EconomyBalance.TIER0_OUTPUT_FRACTION if building.is_working_by_hand() else 1.0)
			t["made"] = float(t["made"]) + city.get_base_building_output_amount(building.type) * pace
	var notes: Dictionary = t["notes"]
	for household: Household in city.households:
		var note: String = household.initiative_note
		if (note.begins_with("Wants to improve") or note.begins_with("Keeps to hand work") or note.begins_with("Improving")) and notes.get(household.id, "") != note:
			print("[TOOLS] day %d | family %d (%s) %s" % [day, household.id, "/".join(CultureEffects.get_callings(household.values)), note.substr(0, 240)])
		notes[household.id] = note
	if day % 30 != 0:
		return
	var reserve: Dictionary = city.influence.get_protected_reserve()
	var committed: Dictionary = city.construction.get_committed_materials()
	var proper: int = 0
	var by_hand: int = 0
	var idle: int = 0
	for building: Building in city.buildings:
		if building.needs_maintenance():
			proper += 1
			by_hand += 1 if building.is_working_by_hand() else 0
			idle += 1 if building.assigned_household_id >= 0 and not building.can_produce() else 0
	var makers: Array[String] = []
	for building: Building in city.buildings:
		if FamilyInitiative.get_activity(building.type) == TownInfluence.ACTIVITY_TOOLS:
			makers.append("%s%s%s" % [building.type, "" if building.assigned_household_id >= 0 else "(empty)", "(by hand)" if building.is_working_by_hand() else ""])
	var hand_work: int = city.buildings.filter(func(b: Building) -> bool: return b.is_tier0() and b.assigned_household_id >= 0 and FamilyInitiative.get_activity(b.type) != "").size()
	print("[TOOLS] day %d | tools %d, committed %d, reserve %d, free %d | wood %d, committed %d, reserve %d, free %d | proper workplaces %d (by hand %d, idle %d), hand work %d | last 30 days: upkeep paid %d, mended %d, missed %d; toolmaking made about %.1f | makers %s | food %d, families %d, people %d" % [day, int(city.resources["tools"]), int(committed.get("tools", 0)), int(reserve["tools"]), int(city.resources["tools"]) - int(committed.get("tools", 0)) - int(reserve["tools"]), int(city.resources["wood"]), int(committed.get("wood", 0)), int(reserve["wood"]), int(city.resources["wood"]) - int(committed.get("wood", 0)) - int(reserve["wood"]), proper, by_hand, idle, hand_work, int(t["paid"]), int(t["mended"]), int(t["missed"]), float(t["made"]), str(makers), int(city.resources["food"]), city.households.size(), city.get_total_population()])
	t["paid"] = 0
	t["mended"] = 0
	t["missed"] = 0
	t["made"] = 0.0

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
		"swayed": influence.swayed.duplicate(), "swayed_total": swayed,
		"appeals_made": influence.appeals_made, "appeals_answered": influence.appeals_answered, "appeals_tipped": influence.appeals_tipped, "kept_woods": city.woodland.protected.size(), "first_card": state["first_card"], "actions": state["actions"], "takeups": state["takeups"],
		"years": state["years"], "first_year_food_short_days": state["first_year_food_short_days"], "first_year_tools_out_days": state["first_year_tools_out_days"],
		"work": summarize_work(state), "woodcutter_days_lost": snappedf(float(state["woodcutter_days_lost"]), 0.1), "made": (state["made"] as Dictionary).keys().reduce(func(acc: Dictionary, k: String) -> Dictionary: acc[k] = roundi(float(state["made"][k])); return acc, {}), "hunting_warning": state["hunting_warning"], "felled": city.woodland.felled_count,
		"fade_changed": city.get_meta("comfort_calling_changed", {}), "fade_cases": city.get_meta("comfort_calling_cases", []),
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
