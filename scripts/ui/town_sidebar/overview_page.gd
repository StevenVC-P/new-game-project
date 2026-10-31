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
		var buttons: Array = []
		if families_lead and city.influence.priority != CommunityPriority.FOOD:
			buttons.append({"text": "Put food first", "action": {"action": "set_priority", "priority": CommunityPriority.FOOD}})
		buttons.append({"text": "Plan a farm (2)", "action": {"action": "select_tool", "tool": Building.BUILDING_FARM}})
		cards.append(make_card(100, SP.TONE_ALERT, "Food has run out", ["Families are going hungry. Hardship builds and newcomers stay away."], buttons))

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
	if food["severity"] == "warning" and resources["food_shortage"] != true:
		var buttons: Array = []
		if families_lead and city.influence.priority != CommunityPriority.FOOD:
			buttons.append({"text": "Put food first", "action": {"action": "set_priority", "priority": CommunityPriority.FOOD}})
		buttons.append({"text": "Plan a farm (2)", "action": {"action": "select_tool", "tool": Building.BUILDING_FARM}})
		cards.append(make_card(70, SP.TONE_CAUTION, "Food stores are falling", ["%d days of food left at today's rate." % int(floor(float(food["values"]["days_stored"])))], buttons))

	var tools: Dictionary = pressure["tools"]
	if tools["severity"] == "danger" or tools["severity"] == "warning":
		var buttons: Array = []
		if families_lead and city.influence.priority != CommunityPriority.INVESTMENT:
			buttons.append({"text": "Put investment first", "action": {"action": "set_priority", "priority": CommunityPriority.INVESTMENT}})
		buttons.append({"text": "Plan a tool mender", "action": {"action": "select_tool", "tool": "tool_mender"}})
		var danger: bool = tools["severity"] == "danger"
		cards.append(make_card(75 if danger else 50, SP.TONE_ALERT if danger else SP.TONE_CAUTION, "Tools are running out" if danger else "Tools are low", ["%d tools stored; workplaces use them for upkeep." % int(resources["tools"])], buttons))

	var upkeep: Dictionary = pressure["maintenance"]
	if upkeep["severity"] == "danger":
		cards.append(make_card(65, SP.TONE_ALERT, "Workplaces are wearing down", ["%d workplaces are below half their upkeep and lose output." % int(upkeep["values"]["critical"]), "Select a workplace to see its upkeep."], []))

	var labor: Dictionary = pressure["labor"]
	if labor["severity"] == "danger" or labor["severity"] == "warning":
		var unstaffed: int = int(labor["values"]["unassigned_jobs"])
		cards.append(make_card(45, severity_tone(labor["severity"]), "Workplaces stand empty", ["%d workplace%s no family to work %s." % [unstaffed, " has" if unstaffed == 1 else "s have", "it" if unstaffed == 1 else "them"], "Select one to see who could take it."], []))

	if city.social.enabled:
		var open: int = city.social.disputes.filter(func(d: Dictionary) -> bool: return not bool(d["settled"])).size()
		if open > 0 and city.social.dispute_pressure >= 2 and not bool(city.social.norms[TownSocial.NORM_CLAIMS]["promoted"]):
			cards.append(make_card(35, SP.TONE_CAUTION, "Quarrels over land", ["%d disputes are unsettled, and families are looking for agreed rules." % open], [{"text": "Ask families to respect claims", "action": {"action": "toggle_norm", "norm": TownSocial.NORM_CLAIMS}}]))

	var needs: Dictionary = city.get_need_pressure_summary()
	var clothing: Dictionary = needs.get(GoodsNeedBucketHelper.BUCKET_CLOTHING, {})
	if bool(clothing.get("active", false)) and str(clothing.get("status", "")) == "unmet" and not has_working(city, Building.BUILDING_HERDER):
		cards.append(make_card(25, SP.TONE_INFO, "No clothing to be had", ["A herder's fold gives wool for clothing."], [{"text": "Plan a herder's fold (H)", "action": {"action": "select_tool", "tool": Building.BUILDING_HERDER}}]))

	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) > int(b["priority"]))
	return cards

const LAND_BUTTON: Dictionary = {"text": "Set aside residential land (N)", "action": {"action": "select_tool", "tool": HomeSites.TOOL_LAND}}

# Why families wanting a home last month could not build one, in the words of the latest of them
# (HomeSites: no land set aside, all of it taken, or none reachable from their work).
static func get_home_site_obstacle(city: City) -> String:
	var latest: Household = null
	for household: Household in city.households:
		if household.home_site_note.contains("cannot build a home") and (latest == null or household.home_site_day > latest.home_site_day):
			latest = household
	var waiting: int = city.construction.families_without_plot
	var count: String = "%d famil%s found nowhere to build last month" % [waiting, "y" if waiting == 1 else "ies"]
	if latest == null:
		return count + "."
	return "%s: %s." % [count, latest.home_site_note.get_slice(": ", 1)]

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
		notices.append("Woods to clear: %d tiles%s" % [city.woodland.marked.size(), "" if not city.woodland.get_woodcutters().is_empty() else " (needs a working woodcutter)"])
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
			if str(note[0]) == "" or int(note[1]) < today - RECENT_DAYS:
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
