class_name SidebarFamiliesPage
extends RefCounted

# The town's families (docs/TOWN_UI.md): one card each with who they are, what they are doing,
# where they live, and what they want; the focused family opens to the reasons behind its
# decisions. Reasons come only from what the simulation recorded (FamilyInitiative's notes and
# reasons, TownSocial's notes, memories, ties); where it records none, the card says nothing.

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

static func build(context: Dictionary) -> Array:
	var city: City = context["city"]
	var focused: int = int(context.get("focused_household_id", -1))
	var blocks: Array = []
	var content: int = 0
	var wanting: int = 0
	var leaving: int = 0
	for household: Household in city.households:
		content += 1 if household.contentment > 0 else 0
		wanting += 1 if household.ambition != "" else 0
		leaving += 1 if HouseholdMigration.is_considering_departure(household) else 0
	blocks.append({"kind": "heading", "text": "Families", "note": "%d families · %d people" % [city.households.size(), city.get_total_population()]})
	var summary: Array[String] = ["%d content" % content, "%d wanting something" % wanting]
	if leaving > 0:
		summary.append("%d thinking of leaving" % leaving)
	blocks.append({"kind": "text", "text": ", ".join(summary) + ".", "muted": true})
	if not city.influence.enabled:
		blocks.append({"kind": "text", "text": "Classic rules: you assign work, so families record no decisions of their own. Esc > Town rules (or I) lets families lead.", "muted": true})
	if city.households.is_empty():
		blocks.append({"kind": "text", "text": "No families live here.", "muted": true})
	blocks.append({"kind": "gap", "size": 4.0})

	# Families in trouble first, then in the order they came.
	var ordered: Array[Household] = city.households.duplicate()
	ordered.sort_custom(func(a: Household, b: Household) -> bool:
		var trouble_a: int = get_trouble(city, a)
		var trouble_b: int = get_trouble(city, b)
		return trouble_a > trouble_b or (trouble_a == trouble_b and a.id < b.id))
	for household: Household in ordered:
		blocks.append(get_card(city, household, household.id == focused))
	return blocks

# 2: thinking of leaving; 1: without shelter or going hungry; 0: otherwise.
static func get_trouble(city: City, household: Household) -> int:
	if HouseholdMigration.is_considering_departure(household):
		return 2
	if household.housing_status == Household.RESIDENCE_UNSHELTERED or city.resources["food_shortage"] == true:
		return 1
	return 0

static func get_card(city: City, household: Household, focused: bool) -> Dictionary:
	var tone: String = ""
	match get_trouble(city, household):
		2:
			tone = SP.TONE_ALERT
		1:
			tone = SP.TONE_CAUTION
	var lines: Array = []
	var calling: String = get_calling(household)
	lines.append((calling + " · " if calling != "" else "") + describe_now(city, household))
	lines.append("Home: " + describe_home(city, household))
	if FamilyDevelopment.is_home_site_blocked(city, household):
		lines.append("Cannot build a home: " + household.home_site_obstacle)
	var wants: String = FamilyAmbitions.describe(city, household)
	if HouseholdMigration.is_considering_departure(household):
		lines.append("Thinking of leaving: its hardship is near what it will endure")
	elif wants != "":
		lines.append("Wants " + wants)
	elif household.contentment > 0:
		lines.append("Content")
	var muted: Array = []
	var brief: String = HouseholdCharacter.describe_briefly(household)
	if brief != "":
		muted.append(sentence(brief))
	if household.initiative_note != "" and not focused and FamilyDevelopment.is_note_current(city, household, household.initiative_note):
		muted.append("Why: " + household.initiative_note)
	var card: Dictionary = {"kind": "card", "title": city.get_household_label(household.id), "tag": "%d %s" % [household.total_population, "person" if household.total_population == 1 else "people"], "lines": lines, "muted": muted, "selected": focused, "action": {"action": "focus_household", "household": household.id}}
	if tone != "":
		card["tone"] = tone
	if focused:
		muted.append_array(get_detail_lines(city, household))
		card["buttons"] = get_detail_buttons(city, household)
		card["columns"] = 2
	return card

static func sentence(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)

static func get_calling(household: Household) -> String:
	var names: Array[String] = []
	for calling in household.values.get(CultureValues.CATEGORY_CALLING, []):
		names.append(CultureValues.get_display_name(calling))
	return ", ".join(names)

# What the family is doing today, as the town records it.
static func describe_now(city: City, household: Household) -> String:
	if city.defense.called_household_ids.has(household.id):
		return "called up to the militia"
	for project: ConstructionProject in city.construction.projects:
		if project.crew_household_ids.has(household.id) and city.construction.builders_today.has(household.id):
			var what: String = ConstructionDisplayHelper.get_project_title(city, project).to_lower()
			return ("helping build " if city.construction.spare_time_today.has(household.id) else "building ") + what
	var holding: Building = FamilyInitiative.get_holding(city, household)
	if holding != null:
		return "works its %s%s" % [BuildingTiers.get_display_name(holding.type).to_lower(), ", long days" if household.long_days else ""]
	return "no work of its own yet"

static func describe_home(city: City, household: Household) -> String:
	match household.housing_status:
		Household.RESIDENCE_HOUSED:
			if city.is_household_in_rough_housing(household):
				return "a hut (rough shelter)"
			return "its own house"
		Household.RESIDENCE_TEMPORARY:
			return "temporary shelter"
	return "no shelter"

# The focused family's reasons and history, newest decision first.
static func get_detail_lines(city: City, household: Household) -> Array:
	var lines: Array = []
	var today: int = city.construction.day
	if household.initiative_note != "" and FamilyDevelopment.is_note_current(city, household, household.initiative_note):
		lines.append("Decided (%s): %s" % [SidebarOverviewPage.days_ago(today - household.initiative_day), household.initiative_note])
	if household.home_site_note != "" and household.home_site_note != household.initiative_note and FamilyDevelopment.is_note_current(city, household, household.home_site_note):
		lines.append("Home site (%s): %s" % [SidebarOverviewPage.days_ago(today - household.home_site_day), household.home_site_note])
	if city.influence.enabled:
		var outlook: Dictionary = FamilyInitiative.predict_improvement(city, household, true)
		if str(outlook["outlook"]) != "":
			var reasons: Array = outlook["reasons"]
			lines.append("If investment were put first: %s%s" % [outlook["outlook"], " (" + "; ".join(reasons) + ")" if not reasons.is_empty() else ""])
		if city.influence.priority != CommunityPriority.NONE:
			var view: Dictionary = CommunityPriority.get_view(city, household, city.influence.priority)
			var view_reasons: Array = FamilyInitiative.get_reasons(view["terms"], view["stance"] != CommunityPriority.OPPOSES and float(view["score"]) > 0.0)
			lines.append("On %s first: %s%s" % [CommunityPriority.PHRASES[city.influence.priority], view["stance"], " (" + "; ".join(view_reasons) + ")" if not view_reasons.is_empty() else ""])
	lines.append_array(HouseholdRosterHelper.get_card_lines(city, household))
	var defining: Array[String] = []
	for value_id: String in city.get_household_defining_values(household):
		defining.append(CultureValues.get_display_name(value_id))
	if not defining.is_empty():
		lines.append("Holds to: " + ", ".join(defining))
	lines.append_array(HouseholdLifecycleDisplayHelper.get_lifecycle_lines(household, city))
	return lines

static func get_detail_buttons(city: City, household: Household) -> Array:
	var buttons: Array = []
	if household.residence_building_id >= 0 and household.residence_building_id < city.buildings.size() and city.buildings[household.residence_building_id].is_house():
		buttons.append({"text": "Show on map", "action": {"action": "select_household", "household": household.id, "focus_camera": true}})
	buttons.append({"text": "Close", "action": {"action": "focus_household", "household": household.id}})
	if city.social.enabled:
		buttons.append_array(get_honour_buttons(household))
	return buttons

# Honouring a family for one of the four kinds of contribution (TownSocial.recognize).
static func get_honour_buttons(household: Household) -> Array:
	var buttons: Array = []
	var labels: Array[String] = ["Honour: service", "Honour: holding", "Honour: craft", "Honour: civic"]
	for index in range(TownSocial.RECOGNITIONS.size()):
		buttons.append({"text": labels[index], "action": {"action": "honour_household", "household": household.id, "category": TownSocial.RECOGNITIONS[index]}})
	return buttons
