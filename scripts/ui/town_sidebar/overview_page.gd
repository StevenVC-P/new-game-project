class_name SidebarOverviewPage
extends RefCounted

# The sidebar's default page (docs/TOWN_UI.md): the town's condition at a glance, what needs the
# player now, and what the community is doing. Every line reads the simulation; nothing here
# changes it. Exact figures sit in collapsed sections for whoever wants them.

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

# How many recent decisions and events the activity section shows, and how far back it looks.
const RECENT_DAYS: int = 30
const RECENT_DECISIONS: int = 3
const ACTIVITY_PROJECTS: int = 3

static func build(context: Dictionary) -> Array:
	var city: City = context["city"]
	var blocks: Array = []
	blocks.append(get_stage_card(city))
	blocks.append({"kind": "heading", "text": "Settlement"})
	blocks.append_array(get_summary(city))

	var attention: Array[Dictionary] = get_attention(city, context)
	blocks.append({"kind": "heading", "text": "Needs attention", "note": "%d" % attention.size() if not attention.is_empty() else ""})
	if attention.is_empty():
		blocks.append({"kind": "text", "text": "Nothing needs you right now.", "tone": SP.TONE_GOOD})
	for card: Dictionary in attention:
		blocks.append(card)

	blocks.append({"kind": "heading", "text": "Current activity"})
	blocks.append_array(get_activity(city))

	blocks.append({"kind": "gap", "size": 6.0})
	blocks.append({"kind": "expander", "id": "overview_figures", "title": "Stores and figures", "blocks": get_figures(city)})
	var chronicle: Array[String] = city.settlement.get_chronicle_lines()
	if not chronicle.is_empty():
		var lines: Array = []
		for line: String in chronicle:
			lines.append({"kind": "text", "text": line, "muted": true})
		blocks.append({"kind": "expander", "id": "overview_chronicle", "title": "Chronicle (%d)" % chronicle.size(), "blocks": lines})
	return blocks

# --- Stage ----------------------------------------------------------------------------------------

static func get_stage_card(city: City) -> Dictionary:
	var settlement: SettlementStage = city.settlement
	var lines: Array = []
	var muted: Array = []
	match settlement.stage:
		SettlementStage.CAMP:
			var housed: int = 0
			for household: Household in city.households:
				housed += 1 if household.housing_status == Household.RESIDENCE_HOUSED else 0
			lines.append("Becomes a hamlet when every family has a home.")
			muted.append("%d of %d families housed" % [housed, city.households.size()])
		SettlementStage.HAMLET:
			var met: Dictionary = settlement.get_village_conditions()
			var done: Array[String] = []
			var needed: Array[String] = []
			(done if met["winter"] else needed).append("a winter survived")
			(done if met["households"] else needed).append("%d households (%d now)" % [SettlementStage.VILLAGE_HOUSEHOLDS, city.households.size()])
			(done if met["new_family"] else needed).append("a family formed here")
			(done if met["stable_season"] else needed).append("a season without hunger or departures")
			lines.append("Toward a village, still needed: " + ", ".join(needed) + "." if not needed.is_empty() else "Ready to become a village.")
			if not done.is_empty():
				muted.append("Done: " + ", ".join(done))
		_:
			lines.append("Families, fields, and workshops of a settled village.")
	var latest: Array[String] = settlement.get_chronicle_lines()
	if not latest.is_empty():
		muted.append("Latest: " + latest.back())
	return {"kind": "card", "title": settlement.get_title(), "tag": "%d families · %d people" % [city.households.size(), city.get_total_population()], "lines": lines, "muted": muted}

# --- Summary --------------------------------------------------------------------------------------

static func get_summary(city: City) -> Array:
	var pressure: Dictionary = city.get_pressure_summary()
	var resources: Dictionary = city.resources
	var blocks: Array = []

	var food: Dictionary = pressure["food"]
	var days: int = int(floor(float(food["values"]["days_stored"])))
	var food_words: Dictionary = {"danger": "Run out", "warning": "Declining", "positive": "Growing", "neutral": "Steady"}
	var food_value: String = str(food_words.get(food["severity"], food["status"]))
	if food["severity"] != "danger":
		food_value += " — %d days stored" % days
	blocks.append({"kind": "status", "label": "Food", "value": food_value, "tone": severity_tone(food["severity"]), "detail": "Families are going hungry" if food["severity"] == "danger" else ""})

	var unsheltered: int = int(resources["unsheltered_population"])
	var temporary: int = int(resources["temporary_sheltered_population"])
	if unsheltered > 0:
		blocks.append({"kind": "status", "label": "Shelter", "value": "%d people without shelter" % unsheltered, "tone": SP.TONE_ALERT})
	elif temporary > 0:
		blocks.append({"kind": "status", "label": "Shelter", "value": "Temporary shelters in use", "tone": SP.TONE_CAUTION, "detail": "%d people in tents or huts" % temporary})
	else:
		blocks.append({"kind": "status", "label": "Shelter", "value": "Every family has a home", "tone": SP.TONE_GOOD})

	blocks.append(get_work_status(city, pressure["labor"]))

	var tools: Dictionary = pressure["tools"]
	var tool_words: Dictionary = {"danger": "Upkeep at risk", "warning": "Running low", "positive": "Adequate"}
	blocks.append({"kind": "status", "label": "Tools", "value": "%s — %d stored" % [tool_words.get(tools["severity"], str(tools["status"])), int(resources["tools"])], "tone": severity_tone(tools["severity"])})

	var upkeep: Dictionary = pressure["maintenance"]
	var upkeep_values: Dictionary = upkeep["values"]
	if upkeep["severity"] == "danger":
		blocks.append({"kind": "status", "label": "Upkeep", "value": "%d workplaces below half" % int(upkeep_values["critical"]), "tone": SP.TONE_ALERT})
	elif upkeep["severity"] == "warning":
		var parts: Array[String] = []
		if int(upkeep_values["worn"]) > 0:
			parts.append("%d worn" % int(upkeep_values["worn"]))
		if int(upkeep_values["disabled"]) > 0:
			parts.append("%d without upkeep" % int(upkeep_values["disabled"]))
		blocks.append({"kind": "status", "label": "Upkeep", "value": ", ".join(parts), "tone": SP.TONE_CAUTION})
	else:
		blocks.append({"kind": "status", "label": "Upkeep", "value": "All workplaces kept up", "tone": SP.TONE_GOOD})

	# Goods the families want beyond food: only those the town tracks, and only when wanted.
	var needs: Dictionary = city.get_need_pressure_summary()
	for bucket: String in [GoodsNeedBucketHelper.BUCKET_HOUSEHOLD_GOODS, GoodsNeedBucketHelper.BUCKET_CLOTHING]:
		var need: Dictionary = needs.get(bucket, {})
		if not bool(need.get("active", false)) or int(need.get("demand", 0)) <= 0:
			continue
		var status: String = str(need.get("status", ""))
		var tone: String = SP.TONE_GOOD if status == "met" else SP.TONE_CAUTION
		var value: String = "Enough" if status == "met" else ("Short" if status == "low" else "None to be had")
		blocks.append({"kind": "status", "label": str(need.get("display_name", bucket)).replace("Household Goods", "House goods"), "value": value, "tone": tone, "detail": "%d in store, %d wanted" % [int(need.get("available", 0)), int(need.get("demand", 0))]})

	var construction: TownConstruction = city.construction
	if construction.projects.is_empty():
		blocks.append({"kind": "status", "label": "Building", "value": "No projects underway", "tone": SP.TONE_NEUTRAL})
	else:
		blocks.append({"kind": "status", "label": "Building", "value": "%d site%s, %d famil%s at work today" % [construction.projects.size(), "" if construction.projects.size() == 1 else "s", construction.builders_today.size(), "y" if construction.builders_today.size() == 1 else "ies"], "tone": SP.TONE_INFO})
	blocks.append({"kind": "status", "label": "Newcomers", "value": HouseholdMigration.get_arrival_blocker_text(HouseholdMigration.get_arrival_blocker(city)), "tone": SP.TONE_NEUTRAL})
	return blocks

static func get_work_status(city: City, labor: Dictionary) -> Dictionary:
	var values: Dictionary = labor["values"]
	var building: int = mini(int(values["idle"]), city.construction.builders_today.size())
	var idle: int = int(values["idle"]) - building
	match str(labor["status"]):
		"Labor Shortage", "Overextended":
			return {"kind": "status", "label": "Work", "value": "%d workplaces stand empty" % int(values["unassigned_jobs"]), "tone": severity_tone(labor["severity"])}
		"Idle Labor":
			return {"kind": "status", "label": "Work", "value": "%d families without work" % idle, "tone": SP.TONE_NEUTRAL, "detail": "%d building" % building if building > 0 else ""}
	var detail: String = "%d building" % building if building > 0 else ""
	return {"kind": "status", "label": "Work", "value": "%d of %d families at work" % [int(values["assigned"]), int(values["capacity"])], "tone": SP.TONE_GOOD, "detail": detail}

static func severity_tone(severity: String) -> String:
	match severity:
		"danger":
			return SP.TONE_ALERT
		"warning":
			return SP.TONE_CAUTION
		"positive":
			return SP.TONE_GOOD
	return SP.TONE_GOOD

# --- Needs attention ------------------------------------------------------------------------------

# Problems and chances the player can act on, most pressing first. Each comes from the town's own
# state; suggestions name only tools and appeals the game has.
static func get_attention(city: City, context: Dictionary = {}) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var resources: Dictionary = city.resources
	var pressure: Dictionary = city.get_pressure_summary()
	var families_lead: bool = city.influence.enabled

	if resources["food_shortage"] == true:
		var lines: Array = ["Families are going hungry. Hardship builds and newcomers stay away."]
		var buttons: Array = [FARM_BUTTON]
		if families_lead:
			lines.append_array(get_food_causes(city))
			buttons = get_food_responses(city, lines)
		cards.append(make_card(100, SP.TONE_ALERT, "Food has run out", lines, buttons))

	if city.defense.is_band_coming():
		var days: int = maxi(0, city.defense.raid_day - city.construction.day)
		var lines: Array = ["A band of %d is on the road, here in %d day%s. The town's guard is %d." % [city.defense.raid_strength, days, "" if days == 1 else "s", city.defense.get_guard()]]
		var buttons: Array = []
		if city.defense.called_household_ids.is_empty():
			buttons.append({"text": "Call the militia (M)", "action": {"action": "call_militia"}})
			lines.append("Calling the militia takes %d families from their work until the band is dealt with." % EconomyBalance.MILITIA_FAMILIES)
		else:
			lines.append("The militia is called: %d families have left their work." % city.defense.called_household_ids.size())
		cards.append(make_card(95, SP.TONE_ALERT, "Bandits on the road", lines, buttons))

	var leaving: int = int(resources.get("households_considering_departure", 0))
	if leaving > 0:
		cards.append(make_card(90, SP.TONE_ALERT, "%d famil%s thinking of leaving" % [leaving, "y is" if leaving == 1 else "ies are"], ["Their hardship is close to what they will endure. Food, a home, and less crowding ease it."], [{"text": "See families", "action": {"action": "show_tab", "tab": "families"}}]))

	if city.trade.is_trader_here():
		cards.append(get_trader_card(city))

	var unsheltered: int = int(resources["unsheltered_population"])
	var temporary: int = int(resources["temporary_sheltered_population"])
	var want_plot: int = city.construction.families_without_plot
	if unsheltered > 0 or temporary > 0:
		var homes_building: int = 0
		for project: ConstructionProject in city.construction.projects:
			homes_building += 1 if project.is_home() else 0
		var lines: Array = ["%d people have no shelter at all." % unsheltered if unsheltered > 0 else "Families are still living in temporary shelters."]
		var buttons: Array = []
		if want_plot > 0 and families_lead:
			lines.append(get_home_site_obstacle(city))
			buttons.append(LAND_BUTTON)
		elif want_plot > 0:
			lines.append("Suggested: designate residential land. %d famil%s waiting for a home plot." % [want_plot, "y is" if want_plot == 1 else "ies are"])
			buttons.append({"text": "Designate home plots (P)", "action": {"action": "select_tool", "tool": TownConstruction.PLOT}})
		elif homes_building > 0:
			lines.append("%d home%s being built." % [homes_building, " is" if homes_building == 1 else "s are"])
		elif families_lead and HomeSites.count_room(city) > 0:
			lines.append("Families choose their own sites on the land set aside for homes, and build when they can.")
		elif families_lead:
			lines.append("Suggested: set aside residential land; families choose their own sites on it.")
			buttons.append(LAND_BUTTON)
		else:
			lines.append("Suggested: set aside home plots, or plan houses.")
			buttons.append({"text": "Designate home plots (P)", "action": {"action": "select_tool", "tool": TownConstruction.PLOT}})
		cards.append(make_card(85 if unsheltered > 0 else 60, SP.TONE_ALERT if unsheltered > 0 else SP.TONE_CAUTION, "Permanent housing needed", lines, buttons))
	elif want_plot > 0 and families_lead:
		cards.append(make_card(55, SP.TONE_CAUTION, "Families cannot find a home site", [get_home_site_obstacle(city)], [LAND_BUTTON]))
	elif want_plot > 0:
		cards.append(make_card(55, SP.TONE_CAUTION, "Families want home plots", ["%d famil%s ready to build a home but no plot is free." % [want_plot, "y is" if want_plot == 1 else "ies are"]], [{"text": "Designate home plots (P)", "action": {"action": "select_tool", "tool": TownConstruction.PLOT}}]))

	var food: Dictionary = pressure["food"]
	if resources["food_shortage"] != true:
		if families_lead:
			var card: Dictionary = get_food_outlook_card(city)
			if not card.is_empty():
				cards.append(card)
		elif food["severity"] == "warning":
			cards.append(make_card(70, SP.TONE_CAUTION, "Food stores are falling", ["%d days of food left at today's rate." % int(floor(float(food["values"]["days_stored"])))], [FARM_BUTTON]))

	var tools: Dictionary = pressure["tools"]
	if tools["severity"] == "danger" or tools["severity"] == "warning":
		var danger: bool = tools["severity"] == "danger"
		var lines: Array = ["%d tools stored; workplaces use them for upkeep." % int(resources["tools"])]
		var buttons: Array = [TOOL_MENDER_BUTTON]
		if families_lead:
			buttons = get_tool_responses(city, lines)
		cards.append(make_card(75 if danger else 50, SP.TONE_ALERT if danger else SP.TONE_CAUTION, "Tools are running out" if danger else "Tools are low", lines, buttons))

	var upkeep: Dictionary = pressure["maintenance"]
	if upkeep["severity"] == "danger":
		cards.append(make_card(65, SP.TONE_ALERT, "Workplaces are wearing down", ["%d workplaces are below half their upkeep and lose output." % int(upkeep["values"]["critical"]), "Select a workplace to see its upkeep."], []))

	var labor: Dictionary = pressure["labor"]
	if labor["severity"] == "danger" or labor["severity"] == "warning":
		var unstaffed: int = int(labor["values"]["unassigned_jobs"])
		cards.append(make_card(45, severity_tone(labor["severity"]), "Workplaces stand empty", ["%d workplace%s no family to work %s." % [unstaffed, " has" if unstaffed == 1 else "s have", "it" if unstaffed == 1 else "them"], "Select one to see who could take it."], []))

	if city.social.enabled:
		var open: int = city.social.disputes.filter(func(d: Dictionary) -> bool: return not bool(d["settled"])).size()
		if open > 0 and city.social.dispute_pressure >= 2 and not GuidingWisdom.is_active(city, GuidingWisdom.RESPECT):
			var choosable: bool = GuidingWisdom.can_choose(city, GuidingWisdom.RESPECT)
			cards.append(make_card(35, SP.TONE_CAUTION, "Quarrels over land", ["%d disputes are unsettled, and families are looking for agreed rules." % open], [{"text": "Wisdom: Respect What Others Build", "action": {"action": "show_tab", "tab": "community"}}] if choosable else []))

	var needs: Dictionary = city.get_need_pressure_summary()
	var clothing: Dictionary = needs.get(GoodsNeedBucketHelper.BUCKET_CLOTHING, {})
	if bool(clothing.get("active", false)) and str(clothing.get("status", "")) == "unmet" and not has_working(city, Building.BUILDING_HERDER):
		cards.append(make_card(25, SP.TONE_INFO, "No clothing to be had", ["A herder's fold gives wool for clothing."], [{"text": "Plan a herder's fold (H)", "action": {"action": "select_tool", "tool": Building.BUILDING_HERDER}}]))

	if families_lead:
		cards.append_array(get_no_land_cards(city))
		cards.append_array(get_failing_livelihood_cards(city))
		if not city.has_meta("late_hunting_card"):
			cards.append_array(get_hunting_ground_cards(city))

	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) > int(b["priority"]))
	return cards

# Families who chose work in the last two months and could find no free land for it, and still do not
# have it (Household.blocked_work_type): what they want, why the land fails them, and the land tools
# that make such land.
const NO_LAND_DAYS: int = 60
const NO_LAND_REASONS: Dictionary = {
	"farm": "A field needs fertile land, and the fertile land within reach of their homes is taken.",
	"fisher": "A weir needs a bank with water beside it, and the banks within reach are taken.",
	"hunter": "A snare line needs woods close by, and none are free within reach.",
	"herder": "A pen needs open ground, and none is free within reach.",
}
const NO_LAND_TOOLS: Dictionary = {
	"farm": [{"text": "Till land into farmland (F)", "action": {"action": "select_tool", "tool": TownFarmland.TILL}}, {"text": "Clear woods (C)", "action": {"action": "select_tool", "tool": TownWoodland.CLEAR}}],
	"herder": [{"text": "Clear woods (C)", "action": {"action": "select_tool", "tool": TownWoodland.CLEAR}}],
}

static func get_no_land_cards(city: City) -> Array[Dictionary]:
	var wanting: Dictionary = {}
	for household: Household in city.households:
		if household.blocked_work_type == "" or city.construction.day - household.blocked_work_day > NO_LAND_DAYS:
			continue
		var holding: Building = FamilyInitiative.get_holding(city, household)
		if holding != null and BuildingTiers.get_base_type(holding.type) == BuildingTiers.get_base_type(household.blocked_work_type):
			continue
		var list: Array = wanting.get(household.blocked_work_type, [])
		list.append(household)
		wanting[household.blocked_work_type] = list
	var cards: Array[Dictionary] = []
	for building_type: String in wanting.keys():
		var families: Array = wanting[building_type]
		var base: String = BuildingTiers.get_base_type(building_type)
		var hungry: int = families.filter(func(h: Household) -> bool: return h.short_days_this_month > 0).size()
		var lines: Array = ["%d famil%s want to take up %s, but find no free land for it near their homes." % [families.size(), "y" if families.size() == 1 else "ies", FamilyInitiative.describe_type(building_type)]]
		lines.append(str(NO_LAND_REASONS.get(base, "The land it needs is taken within reach of their homes.")))
		if hungry > 0:
			lines.append("%d of them %s going hungry." % [hungry, "is" if hungry == 1 else "are"])
		cards.append(make_card(72 if hungry > 0 else 48, SP.TONE_ALERT if hungry > 0 else SP.TONE_CAUTION, "Families find no land for their work", lines, NO_LAND_TOOLS.get(base, [])))
	return cards

# Work that lives off the land whose yield has fallen to two thirds of the best it gave, or less:
# its water, woods or pasture are going (TownLand), with what is taking them.
const FAILING_SHARE: float = 0.67
const FAILING_MIN_PEAK: float = 0.5

static func get_failing_livelihood_cards(city: City) -> Array[Dictionary]:
	var failing: Dictionary = {}
	for building: Building in city.buildings:
		var kind: String = TownLand.get_reach_kind(building.type)
		# Woods have their own, earlier card (get_hunting_ground_cards), unless the comparison asks
		# for the late one (meta "late_hunting_card").
		if kind == "woods" and not city.has_meta("late_hunting_card"):
			continue
		if kind == "" or building.assigned_household_id < 0 or building.peak_land_yield < FAILING_MIN_PEAK:
			continue
		var now: float = city.land.get_reach_factor(building)
		if now <= building.peak_land_yield * FAILING_SHARE:
			var row: Array = failing.get(kind, [0, 0.0, 0.0, 0])
			row[0] = int(row[0]) + 1
			row[1] = float(row[1]) + now
			row[2] = float(row[2]) + building.peak_land_yield
			var family: Household = city.get_household_by_id(building.assigned_household_id)
			row[3] = int(row[3]) + (1 if family != null and family.short_days_this_month > 0 else 0)
			failing[kind] = row
	var cards: Array[Dictionary] = []
	for kind: String in failing.keys():
		var row: Array = failing[kind]
		var count: int = int(row[0])
		var share: int = roundi(100.0 * float(row[1]) / maxf(0.01, float(row[2])))
		var plural: String = "" if count == 1 else "s"
		var title: String = ""
		var lines: Array = []
		var buttons: Array = []
		match kind:
			"woods":
				title = "Hunting grounds are being felled"
				lines.append("The woods round %d hunting workplace%s now give %d%% of the game they did." % [count, plural, share])
				var felling: Array[String] = []
				if city.buildings.any(func(b: Building) -> bool: return BuildingTiers.get_base_type(b.type) == "woodcutter" and b.assigned_household_id >= 0):
					felling.append("the town's woodcutters fell the trees nearest them")
				if not city.woodland.marked.is_empty():
					felling.append("woods are marked for clearing")
				if not felling.is_empty():
					var cause: String = " and ".join(felling)
					lines.append(cause.substr(0, 1).to_upper() + cause.substr(1) + ".")
				lines.append("Woodcutters fell woods marked for clearing before any others.")
				buttons.append({"text": "Mark woods to fell elsewhere (C)", "action": {"action": "select_tool", "tool": TownWoodland.CLEAR}})
			TownLand.TIMBER:
				title = "Timber is running out"
				lines.append("The trees round %d woodcutter%s now give %d%% of the wood they did." % [count, plural, share])
				lines.append("Felled land grows young woods again only slowly; keeping woods saves them for later.")
			"pasture":
				title = "Grazing land is being lost"
				lines.append("The open ground round %d grazing workplace%s now feeds %d%% of the flock it did." % [count, plural, share])
				lines.append("Buildings, fields and spreading woods take the open ground.")
			_:
				title = "Fishing water is thinning"
				lines.append("The water round %d fishing workplace%s now gives %d%% of the catch it did." % [count, plural, share])
		if int(row[3]) > 0:
			lines.append("%d of their families %s going hungry." % [int(row[3]), "is" if int(row[3]) == 1 else "are"])
		cards.append(make_card(68 if int(row[3]) > 0 else 46, SP.TONE_ALERT if int(row[3]) > 0 else SP.TONE_CAUTION, title, lines, buttons))
	return cards

# Woodcutters felling inside the reach of a lodge a family hunts from, soon enough to cost it game
# (TownWoodland.get_hunting_threats): shown before much is lost. Both sides, as a choice and not a
# recommendation (owner, 2026-11-02): which lodges and woods, what continued felling costs the
# hunting, what keeping the woods costs the woodcutting, and what the town has of each now. Nothing
# is kept unless the player chooses it; what the player keeps is binding.
const HUNTING_GROUNDS_TITLE: String = "Woodcutting and hunting share the same woods"
const HUNTING_LODGES_NAMED: int = 3

static func get_hunting_ground_cards(city: City) -> Array[Dictionary]:
	var threats: Array[Dictionary] = city.woodland.get_hunting_threats()
	if threats.is_empty():
		return []
	var lines: Array = []
	var buttons: Array = []
	var hungry: int = 0
	var cutters: Array[Building] = []
	var hunted: float = 0.0
	for threat: Dictionary in threats.slice(0, HUNTING_LODGES_NAMED):
		var lodge: Building = threat["building"]
		var family: Household = city.get_household_by_id(lodge.assigned_household_id)
		var whose: String = city.get_household_label(lodge.assigned_household_id)
		hungry += 1 if family != null and family.short_days_this_month > 0 else 0
		var place: String = describe_place(city, TownLogistics.center_tile(lodge.tile, lodge.size))
		hunted += FamilyInitiative.get_building_output(city, lodge) if family != null else 0.0
		lines.append("%s's %s%s hunts the woods within %d tiles of it: %d wooded tiles%s, %d%% of a full bag." % [whose, FamilyInitiative.describe_type(lodge.type, false), place, EconomyBalance.HUNTER_REACH, roundi(float(threat["wooded"])), " (its share of woods it shares)" if city.land.get_rival_reaches(lodge.type, lodge.tile, false).size() > 0 else "", roundi(100.0 * float(threat["factor"]))])
		var felling: Array[String] = []
		if not (threat["woodcutters"] as Array).is_empty():
			felling.append("%s fell%s inside it" % [describe_woodcutters(city, threat["woodcutters"]), "s" if (threat["woodcutters"] as Array).size() == 1 else ""])
		if int(threat["marked"]) > 0:
			felling.append("%d of its wooded tiles are marked for clearing" % int(threat["marked"]))
		var when: String = "each tree felled there now takes from its bag" if float(threat["days"]) <= 0.0 else "at this pace its bag starts to fall in about %d days" % roundi(float(threat["days"]))
		var cause: String = " and ".join(felling)
		lines.append("If felling goes on: %s; %s, to about %d%% of a full bag in half a year." % [cause, when, roundi(100.0 * float(threat["after"]))])
		buttons.append({"text": "Keep %s's hunting grounds" % whose, "action": {"action": "keep_hunting_ground", "building": lodge.id}})
		for woodcutter: Building in threat["woodcutters"]:
			if not cutters.has(woodcutter):
				cutters.append(woodcutter)
	if threats.size() > HUNTING_LODGES_NAMED:
		lines.append("%d more hunting workplaces are threatened." % (threats.size() - HUNTING_LODGES_NAMED))
	if hungry > 0:
		lines.append("%d of their families %s going hungry." % [hungry, "is" if hungry == 1 else "are"])
	var kept: String = "If the woods are kept: no one may fell them, whatever the families want, until you mark them for clearing"
	if not cutters.is_empty():
		var rect: Rect2i = threats[0]["rect"]
		var keeps: float = 1.0
		for woodcutter: Building in cutters:
			keeps = minf(keeps, city.woodland.estimate_felling_factor_if_kept(woodcutter, rect))
		kept += ", and the woodcutters fell farther off, bringing in about %d%% of the wood they do now." % roundi(100.0 * keeps) if keeps < 0.97 else ", and the woodcutters, with other trees about as near, lose little wood."
	else:
		kept += "."
	lines.append(kept)
	var food: float = FamilyInitiative.get_working_output(city, TownInfluence.ACTIVITY_FOOD)
	var share: String = "about %d%% of the food the town's work brings in" % roundi(100.0 * hunted / food) if food > 0.0 else "food"
	lines.append("Neither is always right: these lodges bring in %s, and the town holds %d wood. Lumber builds homes, fields and workshops; game feeds families." % [share, int(city.resources["wood"])])
	buttons.append({"text": "Keep woods (V)", "action": {"action": "select_tool", "tool": TownWoodland.PROTECT}})
	return [make_card(68 if hungry > 0 else 58, SP.TONE_ALERT if hungry > 0 else SP.TONE_CAUTION, HUNTING_GROUNDS_TITLE, lines, buttons)]

# "the woodcutter" or "2 woodcutters", with whose they are when one family works them.
static func describe_woodcutters(city: City, woodcutters: Array) -> String:
	if woodcutters.size() == 1:
		var woodcutter: Building = woodcutters[0]
		return "%s's %s" % [city.get_household_label(woodcutter.assigned_household_id), FamilyInitiative.describe_type(woodcutter.type, false)] if woodcutter.assigned_household_id >= 0 else "a woodcutter"
	return "%d woodcutters" % woodcutters.size()

# Where a tile lies from the town's stores, for naming a place: " (north-east of the stores)".
static func describe_place(city: City, tile: Vector2i) -> String:
	var heart: Vector2i = city.logistics.stockpile_tile
	if heart.x < 0:
		return ""
	var offset: Vector2 = Vector2(tile - heart)
	if offset.length() < 3.0:
		return " (by the stores)"
	var names: Array[String] = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return " (%s of the stores)" % names[posmod(roundi(offset.angle() / (PI / 4.0)), 8)]

const FARM_BUTTON: Dictionary = {"text": "Plan a farm (2)", "action": {"action": "select_tool", "tool": Building.BUILDING_FARM}}
const TOOL_MENDER_BUTTON: Dictionary = {"text": "Plan a tool mender", "action": {"action": "select_tool", "tool": "tool_mender"}}
const TILL_BUTTON: Dictionary = {"text": "Till land into farmland (F)", "action": {"action": "select_tool", "tool": TownFarmland.TILL}}

# --- Food and tools: what the families see coming, and what the player could do ----------------

# The town's food as its families judge it (FamilyInitiative: store, larders, and what the work
# families actually do will bring in over the coming months, seasons included): a warning while
# there is still time to act, with its causes. Reading it changes nothing. While families are still
# setting up their first work and no food work runs yet, the forecast is provisional and says so
# (owner, 2026-11-01), but a danger it already sees is still shown.
static func get_food_outlook_card(city: City) -> Dictionary:
	var coverage: float = FamilyInitiative.get_food_coverage(city)
	var ratio: float = FamilyInitiative.get_food_ratio(city)
	if coverage >= 1.0 and ratio >= 1.0:
		return {}
	var eats: float = float(city.get_food_consumption_for_population(city.get_total_population()))
	var held: float = float(int(city.resources["food"]))
	for household: Household in city.households:
		held += household.larder
	var coming: float = FamilyInitiative.get_working_output(city, TownInfluence.ACTIVITY_FOOD, true) / float(FamilyInitiative.SURVIVAL_HORIZON_DAYS)
	var lines: Array = []
	var title: String = ""
	var priority: int = 0
	var tone: String = SP.TONE_CAUTION
	if is_food_unproven(city):
		var setting_up: int = 0
		for project: ConstructionProject in city.construction.projects:
			if project.claimant_household_id >= 0 and FamilyInitiative.get_activity(project.building_type) == TownInfluence.ACTIVITY_FOOD:
				setting_up += 1
		var stored: int = int(floor(held / maxf(0.1, eats)))
		title = "Food supply not yet established"
		lines.append("Families are still setting up their work, and no food work has brought anything in yet: this forecast is provisional.")
		if setting_up > 0:
			lines.append("%d famil%s setting up food work; until it runs, the town lives on its stores, about %d days." % [setting_up, "y is" if setting_up == 1 else "ies are", stored])
		else:
			lines.append("No family has taken up food work yet; the town lives on its stores, about %d days." % stored)
		if coverage < 1.0:
			var days: int = int(floor(held / maxf(0.1, eats - coming)))
			lines.append("Counting the food work being set up, at the pace its families can manage, food runs out in about %d days, %s." % [days, "before the next harvest" if city.get_season_index() < 2 else "before the winter is out"])
		priority = 78 if stored < 30 or setting_up == 0 else 70
		tone = SP.TONE_ALERT if stored < 30 or setting_up == 0 else SP.TONE_CAUTION
	elif coverage < 1.0:
		var days: int = int(floor(held / maxf(0.1, eats - coming)))
		title = "Food will run short"
		lines.append("At this rate the town's food runs out in about %d days, %s." % [days, "before the next harvest" if city.get_season_index() < 2 else "before the winter is out"])
		priority = 78 if days < 30 else 70
		tone = SP.TONE_ALERT if days < 30 else SP.TONE_CAUTION
	else:
		var days: int = int(floor(held / maxf(0.1, eats - coming)))
		title = "The town grows less food than it eats"
		lines.append("Its stores carry it about %d days; after that it goes hungry unless more food is grown." % days)
		priority = 52
	lines.append_array(get_food_causes(city))
	var buttons: Array = get_food_responses(city, lines)
	return make_card(priority, tone, title, lines, buttons)

# Food production is unproven while no food workplace is yet worked and most families are still
# setting up their first work (the founding): the forecast then rests on plans, not on anything
# brought in. Once most families have settled, a town without food work has a real shortage.
static func is_food_unproven(city: City) -> bool:
	for building: Building in city.buildings:
		if building.assigned_household_id >= 0 and FamilyInitiative.get_activity(building.type) == TownInfluence.ACTIVITY_FOOD:
			return false
	var working: Array = city.households.filter(func(h: Household) -> bool: return h.labor_capacity > 0)
	var settling: int = working.filter(func(h: Household) -> bool: return FamilyInitiative.get_holding(city, h) == null).size()
	return settling * 2 > working.size()

# Why the town's food falls short, from what the town holds: its work's share of what it eats, the
# season ahead, fields standing empty or worked by hand for want of tools, families going hungry.
static func get_food_causes(city: City) -> Array:
	var causes: Array = []
	causes.append("Its food work brings in %d%% of what its people eat." % roundi(100.0 * FamilyInitiative.get_food_ratio(city)))
	if FamilyInitiative.get_season_days(city, Building.BUILDING_FARM) < float(FamilyInitiative.SURVIVAL_HORIZON_DAYS) * 0.95:
		causes.append("Winter is coming: fields will yield less.")
	var empty: int = 0
	var by_hand: int = 0
	for building: Building in city.buildings:
		if FamilyInitiative.get_activity(building.type) != TownInfluence.ACTIVITY_FOOD:
			continue
		empty += 1 if building.assigned_household_id < 0 else 0
		by_hand += 1 if building.assigned_household_id >= 0 and building.is_working_by_hand() else 0
	if empty > 0:
		causes.append("%d food workplace%s stand%s empty." % [empty, "" if empty == 1 else "s", "s" if empty == 1 else ""])
	if by_hand > 0:
		causes.append("%d food workplace%s work%s by hand for want of tools." % [by_hand, "" if by_hand == 1 else "s", "s" if by_hand == 1 else ""])
	var hungry: int = city.households.filter(func(h: Household) -> bool: return h.short_days_this_month > 0).size()
	if hungry > 0:
		causes.append("%d famil%s already going hungry." % [hungry, "y is" if hungry == 1 else "ies are"])
	return causes

# A focused appeal for a good, with who would likely answer, and its button while none stands.
static func add_appeal_response(city: City, good: String, text: String, lines: Array, buttons: Array) -> void:
	lines.append_array(FocusedAppeal.describe(city, good))
	if not FocusedAppeal.is_active(city, good):
		buttons.append({"text": text, "action": {"action": "make_appeal", "good": good}})

# What the player could do about food, with what each costs; nothing is prescribed.
static func get_food_responses(city: City, lines: Array) -> Array:
	var buttons: Array = []
	add_appeal_response(city, TownInfluence.ACTIVITY_FOOD, "Ask families to grow food", lines, buttons)
	lines.append("Land: more farmland lets more families farm. Families working fields till land you mark, as part of their work.")
	buttons.append(TILL_BUTTON)
	if not has_free_family(city):
		lines.append("A farm you plan yourself costs wood and a tool, and stands empty until a family is free to take it; none is now.")
	else:
		lines.append("A farm you plan yourself costs wood and a tool; a family free to work may take it.")
	buttons.append(FARM_BUTTON)
	if city.influence.priority != CommunityPriority.FOOD:
		lines.append("Putting food first would draw every family choosing its work toward food, and away from tools and wood.")
	return buttons

# What the player could do about tools, with what each costs.
static func get_tool_responses(city: City, lines: Array) -> Array:
	var use: int = roundi(FamilyInitiative.get_use(city, TownInfluence.ACTIVITY_TOOLS, FamilyInitiative.SHORTAGE_HORIZON_DAYS))
	if use > 0:
		lines.append("The town's workplaces will use about %d in the coming season." % use)
	var makers: int = FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS)
	lines.append("No one makes tools." if makers == 0 else "%d famil%s make tools." % [makers, "y" if makers == 1 else "ies"])
	var buttons: Array = []
	if makers == 0:
		add_appeal_response(city, TownInfluence.ACTIVITY_TOOLS, "Ask someone to take up toolmaking", lines, buttons)
		if has_free_family(city):
			lines.append("A tool mender you plan costs nothing to build; a family free to work may take it.")
		else:
			lines.append("A tool mender you plan costs nothing to build, but no family is free to take it now.")
		buttons.append(TOOL_MENDER_BUTTON)
	if city.influence.priority != CommunityPriority.INVESTMENT:
		lines.append("Putting investment first would draw families toward tools and better work, and away from food.")
	return buttons

static func has_free_family(city: City) -> bool:
	return city.households.any(func(h: Household) -> bool: return h.labor_capacity > 0 and FamilyInitiative.get_holding(city, h) == null and not city.construction.is_promised_to_workplace(h.id))

const LAND_BUTTON: Dictionary = {"text": "Set aside residential land (N)", "action": {"action": "select_tool", "tool": HomeSites.TOOL_LAND}}

# Why families wanting a home last month could not build one, in the words of the latest of them
# (HomeSites: no land set aside, all of it taken, or none reachable from their work).
static func get_home_site_obstacle(city: City) -> String:
	var latest: Household = null
	for household: Household in city.households:
		if FamilyDevelopment.is_home_site_blocked(city, household) and (latest == null or household.home_site_day > latest.home_site_day):
			latest = household
	var waiting: int = city.construction.families_without_plot
	var count: String = "%d famil%s found nowhere to build last month" % [waiting, "y" if waiting == 1 else "ies"]
	if latest == null:
		return count + "."
	return "%s: %s." % [count, latest.home_site_obstacle]

static func get_trader_card(city: City) -> Dictionary:
	var stay: int = city.trade.trader_until_day - city.construction.day + 1
	var buttons: Array = []
	var lots: Array[Dictionary] = city.trade.get_lots()
	for index in range(lots.size()):
		buttons.append({"text": "Give " + TownTrade.describe_lot(lots[index]), "action": {"action": "trade_lot", "lot": index}})
	var lines: Array = ["A trader from %s is here for %d more day%s." % [city.trade.partner_name, stay, "" if stay == 1 else "s"]]
	if lots.is_empty():
		lines.append("Nothing the town holds is wanted.")
	var muted: Array = []
	muted.append_array(city.trade.get_price_lines())
	if city.trade.last_trade_text != "":
		muted.append("Last trade: " + city.trade.last_trade_text)
	var card: Dictionary = make_card(80, SP.TONE_INFO, "A trader is in town", lines, buttons)
	card["muted"] = muted
	return card

static func make_card(priority: int, tone: String, title: String, lines: Array, buttons: Array) -> Dictionary:
	return {"kind": "card", "priority": priority, "tone": tone, "title": title, "lines": lines, "buttons": buttons}

static func has_working(city: City, building_type: String) -> bool:
	for building: Building in city.buildings:
		if building.type == building_type and building.assigned_workers > 0:
			return true
	return false

# --- Activity -------------------------------------------------------------------------------------

static func get_activity(city: City) -> Array:
	var blocks: Array = []
	var construction: TownConstruction = city.construction
	# Identical sites (two houses both waiting for builders) share a line.
	var project_counts: Dictionary = {}
	for project: ConstructionProject in construction.projects:
		var line: String = "%s: %s" % [ConstructionDisplayHelper.get_project_title(city, project), construction.get_status_text(project)]
		project_counts[line] = int(project_counts.get(line, 0)) + 1
	var project_lines: Array = []
	for line: String in project_counts.keys().slice(0, ACTIVITY_PROJECTS):
		project_lines.append(("%d × " % project_counts[line] if int(project_counts[line]) > 1 else "") + line)
	if project_counts.size() > ACTIVITY_PROJECTS:
		project_lines.append("and more under Planning")
	for completion: Dictionary in construction.recent_completions.slice(maxi(0, construction.recent_completions.size() - 2)):
		if int(completion["day"]) >= construction.day - RECENT_DAYS:
			project_lines.append("Finished %s: %s" % [days_ago(construction.day - int(completion["day"])), completion["label"]])
	if not project_lines.is_empty():
		blocks.append({"kind": "card", "title": "Building", "lines": project_lines})

	var decisions: Array = []
	for entry: Dictionary in get_recent_decisions(city):
		decisions.append("%s, %s: %s" % [entry["who"], entry["when"], entry["text"]])
	if not decisions.is_empty():
		blocks.append({"kind": "card", "title": "Family decisions", "lines": decisions, "muted": ["Their reasons are under Families."], "action": {"action": "show_tab", "tab": "families"}})

	var notices: Array = []
	notices.append_array(city.land.get_notices())
	notices.append_array(FamilyAmbitions.get_notices(city))
	notices.append_array(city.trade.get_notices())
	notices.append_array(city.defense.get_notices())
	if construction.families_without_plot > 0:
		notices.append("%d famil%s want a home plot" % [construction.families_without_plot, "y" if construction.families_without_plot == 1 else "ies"])
	if not city.woodland.marked.is_empty():
		notices.append("Woods to clear: %d tiles%s" % [city.woodland.marked.size(), "" if city.woodland.get_clearing_obstacle() == "" else " (%s)" % city.woodland.get_clearing_obstacle()])
	if not city.farmland.marked.is_empty():
		notices.append("Land to till: %d tiles%s" % [city.farmland.marked.size(), "" if not city.farmland.get_farms().is_empty() else " (needs a working field)"])
	if not notices.is_empty():
		blocks.append({"kind": "card", "title": "Around the town", "muted": notices})
	if blocks.is_empty():
		blocks.append({"kind": "text", "text": "The town is quiet.", "muted": true})
	return blocks

# The latest things families decided for themselves, newest first: {"who", "when", "text"}. The
# reasons in brackets are left to the Families page, and families who decided the same thing share
# an entry ("Households 1, 2").
static func get_recent_decisions(city: City, count: int = RECENT_DECISIONS) -> Array[Dictionary]:
	var today: int = city.construction.day
	var by_text: Dictionary = {}
	for household: Household in city.households:
		for note: Array in [[household.initiative_note, household.initiative_day], [household.social_note, household.social_note_day]]:
			if str(note[0]) == "" or int(note[1]) < today - RECENT_DAYS or not FamilyDevelopment.is_note_current(city, household, str(note[0])):
				continue
			var text: String = str(note[0])
			if text.contains(" ("):
				text = text.left(text.find(" ("))
			var entry: Dictionary = by_text.get(text, {"day": int(note[1]), "ids": [], "text": text})
			entry["day"] = maxi(int(entry["day"]), int(note[1]))
			(entry["ids"] as Array).append(household.id + 1)
			by_text[text] = entry
	var entries: Array[Dictionary] = []
	for entry: Dictionary in by_text.values():
		var ids: Array = entry["ids"]
		entry["who"] = ("Household %d" % ids[0]) if ids.size() == 1 else "Households " + ", ".join(ids.map(func(id: int) -> String: return str(id)))
		entry["when"] = days_ago(today - int(entry["day"]))
		entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["day"]) > int(b["day"]))
	return entries.slice(0, count)

static func days_ago(days: int) -> String:
	if days <= 0:
		return "today"
	if days == 1:
		return "yesterday"
	return "%d days ago" % days

# --- Figures (the detail view) --------------------------------------------------------------------

static func get_figures(city: City) -> Array:
	var resources: Dictionary = city.resources
	var blocks: Array = []
	var stock: Array[String] = []
	for key: String in ["food", "wood", "tools", "stone_blocks", "cut_stone", "bricks", "masonry", "lime", "mortar", "statues", "carved_goods", "tiles", "paving_stones", "wool", "clothing"]:
		if int(resources.get(key, 0)) != 0 or key in ["food", "wood", "tools"]:
			stock.append("%s %d" % [key.replace("_", " "), int(resources.get(key, 0))])
	blocks.append({"kind": "text", "text": "Stores: " + ", ".join(stock)})
	blocks.append({"kind": "text", "text": "Food eaten: %d a day" % int(resources["food_consumption_rate"]), "muted": true})
	var pressure: Dictionary = city.get_pressure_summary()
	for key: String in ["food", "shelter", "labor", "tools", "maintenance"]:
		var entry: Dictionary = pressure[key]
		blocks.append({"kind": "text", "text": "%s: %s. %s" % [key.capitalize(), entry["status"], entry["detail"]], "muted": true})
	var needs: Dictionary = city.get_need_pressure_summary()
	for bucket: String in needs.keys():
		var need: Dictionary = needs[bucket]
		var state: String = str(need.get("status", "")).replace("_", " ") if bool(need.get("active", false)) else "not tracked yet"
		blocks.append({"kind": "text", "text": "Need, %s: %s (%d available, %d demand)" % [str(need.get("display_name", bucket)).to_lower(), state, int(need.get("available", 0)), int(need.get("demand", 0))], "muted": true})
	blocks.append({"kind": "text", "text": "Shelter: %d homes' room, %d housed, %d temporary of %d, %d unsheltered" % [int(resources["house_shelter_capacity"]), int(resources["housed_population"]), int(resources["temporary_sheltered_population"]), int(resources["temporary_shelter_capacity"]), int(resources["unsheltered_population"])], "muted": true})
	var counts: Dictionary = city.get_household_counts_by_preference()
	blocks.append({"kind": "text", "text": "Homes by leaning: %d agrarian, %d industrial" % [int(counts.get(Household.WORK_PREF_AGRARIAN, 0)), int(counts.get(Household.WORK_PREF_INDUSTRIAL, 0))], "muted": true})
	blocks.append({"kind": "text", "text": "Developer views: F4 town pressures, F3 household inspector.", "muted": true})
	return blocks
