class_name SidebarCommunityPage
extends RefCounted

# How the player leads families who decide for themselves (docs/TOWN_UI.md): what the community
# asks of them, the rule for the common stores, the customs it appeals to, and the rewards and
# honours it gives. Each control says what it asks and what the town has recorded since; none
# promises what families will do, because they decide (TownInfluence, TownSocial).

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

const WORK_ASKS: Array[String] = [TownInfluence.ACTIVITY_FOOD, TownInfluence.ACTIVITY_WOOD, TownInfluence.ACTIVITY_TOOLS]
const HONOUR_LABELS: Array[String] = ["Service", "Holding", "Craft", "Civic"]

static func build(context: Dictionary) -> Array:
	var city: City = context["city"]
	var blocks: Array = []
	if not city.influence.enabled and not city.social.enabled:
		blocks.append({"kind": "heading", "text": "Community"})
		blocks.append({"kind": "card", "title": "Classic rules", "lines": ["You assign work directly, and families make no choices of their own here."], "muted": ["Esc > Town rules (or I) lets families lead: they choose their work, and this page holds the appeals, store rules, and honours that guide them."]})
		return blocks
	blocks.append({"kind": "text", "text": "Families weigh what the community asks alongside their own reasons. Receptive families answer more readily; none is bound to.", "muted": true})
	if city.influence.enabled:
		blocks.append_array(get_priorities(city))
		blocks.append_array(get_stores(city))
	if city.social.enabled:
		blocks.append_array(get_expectations(city))
		blocks.append_array(get_recognition(city, int(context.get("focused_household_id", -1))))
		blocks.append_array(get_gathering(city))
	return blocks

static func get_priorities(city: City) -> Array:
	var influence: TownInfluence = city.influence
	var blocks: Array = [{"kind": "heading", "text": "Community priorities"}]
	var work_buttons: Array = []
	for activity: String in WORK_ASKS:
		work_buttons.append({"text": TownInfluence.get_activity_name(activity).capitalize(), "toggle": true, "active": influence.is_encouraged(activity), "action": {"action": "toggle_encourage", "activity": activity}})
	var work_lines: Array = ["Families choosing their work count the community's asks among their reasons."]
	if influence.store_rule == TownInfluence.RULE_PRIORITIES:
		work_lines.append("Under 'priorities first', only projects for what is asked may draw on the stores.")
	blocks.append({"kind": "card", "title": "Ask for work in", "lines": work_lines, "buttons": work_buttons, "columns": 3})

	var asking: bool = influence.is_encouraged(TownInfluence.ACTIVITY_IMPROVE)
	var outlooks: Array = []
	for household: Household in city.households:
		var outlook: Dictionary = FamilyInitiative.predict_improvement(city, household, true)
		if str(outlook["outlook"]) == "":
			continue
		var reasons: Array = outlook["reasons"]
		outlooks.append({"kind": "text", "text": "%s: %s%s" % [city.get_household_label(household.id), outlook["outlook"], " (" + "; ".join(reasons.slice(0, 2)) + ")" if not reasons.is_empty() else ""], "muted": true})
	var improve: Dictionary = {"kind": "card", "title": "Ask for better work", "lines": ["Families on hand work weigh improving it into a proper workplace."], "muted": ["So far families have opened %d workplaces and improved %d." % [influence.workplaces_opened, influence.improvements_started]], "buttons": [{"text": "Asking for better work" if asking else "Ask for better work", "toggle": true, "active": asking, "action": {"action": "toggle_encourage", "activity": TownInfluence.ACTIVITY_IMPROVE}}]}
	blocks.append(improve)
	if not outlooks.is_empty():
		blocks.append({"kind": "expander", "id": "community_outlooks", "title": "Who might answer (%d on hand work)" % outlooks.size(), "blocks": outlooks})
	return blocks

static func get_stores(city: City) -> Array:
	var influence: TownInfluence = city.influence
	var priorities: bool = influence.store_rule == TownInfluence.RULE_PRIORITIES
	var reserve: Dictionary = influence.get_protected_reserve()
	var reserve_parts: Array[String] = []
	for material: String in reserve.keys():
		reserve_parts.append("%d %s" % [int(reserve[material]), material])
	var lines: Array = ["Only projects for what the community asks for may draw on the stores; the rest wait." if priorities else "Families' own projects may draw on the stores above what is kept back."]
	var muted: Array = ["Always kept back from families' projects: " + ", ".join(reserve_parts) + ".", "Times a family's improvement was held back by the stores: %d" % influence.held_back_by_stores]
	return [
		{"kind": "heading", "text": "Shared resources"},
		{"kind": "card", "title": "Common stores", "tag": "priorities first" if priorities else "open", "lines": lines, "muted": muted, "columns": 2, "buttons": [
			{"text": "Open", "toggle": true, "active": not priorities, "action": {"action": "set_store_rule", "rule": TownInfluence.RULE_OPEN}},
			{"text": "Priorities first", "toggle": true, "active": priorities, "action": {"action": "set_store_rule", "rule": TownInfluence.RULE_PRIORITIES}},
		]},
	]

static func get_expectations(city: City) -> Array:
	var social: TownSocial = city.social
	var blocks: Array = [{"kind": "heading", "text": "Social expectations"}]
	for norm_id: String in [TownSocial.NORM_HELP, TownSocial.NORM_CLAIMS]:
		var norm: Dictionary = social.norms[norm_id]
		var promoted: bool = bool(norm["promoted"])
		var status: String = str(norm["status"])
		var tone: String = SP.TONE_GOOD if status != TownSocial.STATUS_NONE else SP.TONE_NEUTRAL
		blocks.append({"kind": "card", "title": TownSocial.NORM_NAMES[norm_id], "tone": tone, "tag": status, "lines": ["%s families to %s." % ["The community asks" if promoted else "Ask", TownSocial.NORM_ASKS[norm_id]]], "muted": ["Accepted by about %d%% of families' choices so far." % roundi(float(norm["acceptance"]) * 100.0)], "buttons": [{"text": "Asking" if promoted else "Ask", "toggle": true, "active": promoted, "action": {"action": "toggle_norm", "norm": norm_id}}]})
	var open: int = social.disputes.filter(func(d: Dictionary) -> bool: return not bool(d["settled"])).size()
	if open > 0:
		blocks.append({"kind": "text", "text": "Unsettled disputes over land: %d%s" % [open, "; families are looking for agreed rules" if social.dispute_pressure >= 2 else ""], "tone": SP.TONE_CAUTION})
	return blocks

static func get_recognition(city: City, focused_household_id: int) -> Array:
	var social: TownSocial = city.social
	var blocks: Array = [{"kind": "heading", "text": "Recognition and incentives"}]
	blocks.append({"kind": "card", "title": "Reward helping", "tag": "on" if social.incentive else "off", "lines": ["Families who help a neighbour build, or share food in a shortage, get first claim on the stores for %d days." % TownSocial.FIRST_CLAIM_DAYS], "muted": ["First claim passes the priorities rule, never what is kept back."], "buttons": [{"text": "Rewarding help" if social.incentive else "Reward help", "toggle": true, "active": social.incentive, "action": {"action": "toggle_incentive"}}]})
	var focused: Household = city.get_household_by_id(focused_household_id) if focused_household_id >= 0 else null
	var lines: Array = ["Each family judges an honour by what it prizes and by what the honoured family did. An undeserved honour breeds resentment."]
	if focused == null:
		blocks.append({"kind": "card", "title": "Honour a family", "lines": lines, "muted": ["Select a family on the map or under Families first.", "Honours given so far: %d" % social.honours], "buttons": [{"text": "Choose a family", "action": {"action": "show_tab", "tab": "families"}}]})
		return blocks
	var buttons: Array = []
	for index in range(TownSocial.RECOGNITIONS.size()):
		buttons.append({"text": HONOUR_LABELS[index], "action": {"action": "honour_household", "household": focused.id, "category": TownSocial.RECOGNITIONS[index]}})
	var muted: Array = ["Honours given so far: %d" % social.honours]
	if focused.social_note != "":
		muted.append("%s lately: %s" % [city.get_household_label(focused.id), focused.social_note])
	blocks.append({"kind": "card", "title": "Honour " + city.get_household_label(focused.id), "lines": lines, "muted": muted, "buttons": buttons, "columns": 2})
	return blocks

static func get_gathering(city: City) -> Array:
	var social: TownSocial = city.social
	var voices: Array[String] = []
	for voice: Household in social.get_respected_voices():
		voices.append(city.get_household_label(voice.id))
	var trusting: int = 0
	var wary: int = 0
	for household: Household in city.households:
		trusting += 1 if household.trust >= 1 else 0
		wary += 1 if household.trust <= -1 else 0
	var lines: Array = ["Respected voices: " + (", ".join(voices) if not voices.is_empty() else "no family stands out yet")]
	var muted: Array = ["%d families trust how the gathering decides; %d are wary." % [trusting, wary]]
	var changes: int = social.get_recent_policy_changes()
	if changes > 0:
		muted.append("The community changed what it asks %d time%s in the last %d days." % [changes, "" if changes == 1 else "s", TownSocial.POLICY_WINDOW_DAYS])
	return [{"kind": "heading", "text": "The gathering"}, {"kind": "card", "title": "Informal gatherings of households", "lines": lines, "muted": muted}]
