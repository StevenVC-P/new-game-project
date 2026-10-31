class_name SidebarCommunityPage
extends RefCounted

# How the player leads families who decide for themselves (docs/TOWN_UI.md): the one priority the
# community puts first (CommunityPriority) and how families take it, the rule for the common stores, the customs it appeals to, and the rewards and
# honours it gives. Each control says what it asks and what the town has recorded since; none
# promises what families will do, because they decide (TownInfluence, TownSocial).

const SP = preload("res://scripts/ui/town_sidebar/sidebar_painter.gd")

# What each priority asks, in the player's terms (CommunityPriority holds what it does).
const PRIORITY_ASKS: Dictionary = {
	CommunityPriority.NONE: "Families weigh only their own reasons.",
	CommunityPriority.FOOD: "Families choosing or improving their work lean toward food.",
	CommunityPriority.HOUSING: "Families give spare time and long days to home sites, and homes come first for builders and materials.",
	CommunityPriority.INVESTMENT: "Families on hand work lean toward improving it into proper workplaces, and toward making tools.",
	CommunityPriority.COOPERATION: "Families give spare time to neighbours' and the town's sites.",
}
# Button labels short enough for the narrowest sidebar; the card's tag gives the full name.
const SHORT_NAMES: Dictionary = {CommunityPriority.NONE: "None", CommunityPriority.FOOD: "Food", CommunityPriority.HOUSING: "Housing", CommunityPriority.INVESTMENT: "Investment", CommunityPriority.COOPERATION: "Cooperation"}
const SWAYED_NAMES: Dictionary = {"improve": "improvements", "help": "days of help", "long_days": "long days"}
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
	var current: String = influence.priority
	var blocks: Array = [{"kind": "heading", "text": "Community priority"}]
	var buttons: Array = []
	for priority: String in [CommunityPriority.NONE] + CommunityPriority.ALL:
		buttons.append({"text": SHORT_NAMES[priority], "toggle": true, "active": priority == current, "action": {"action": "set_priority", "priority": priority}})
	var muted: Array = []
	var changes: int = city.social.get_recent_policy_changes() if city.social.enabled else 0
	if city.social.enabled:
		muted.append("Changed %d time%s in the last %d days; families lose trust in a gathering that changes its mind %d times." % [changes, "" if changes == 1 else "s", TownSocial.POLICY_WINDOW_DAYS, TownSocial.MANY_CHANGES])
	blocks.append({"kind": "card", "title": "What the community puts first", "tag": CommunityPriority.get_display_name(current).to_lower(), "lines": [PRIORITY_ASKS[current]], "muted": muted, "buttons": buttons, "columns": 2, "tone": SP.TONE_CAUTION if changes >= TownSocial.MANY_CHANGES - 1 else ""})
	var earlier: Array[String] = influence.get_earlier_asks()
	if not earlier.is_empty():
		var names: Array[String] = []
		for activity: String in earlier:
			names.append(TownInfluence.get_activity_name(activity))
		blocks.append({"kind": "text", "text": "Asks from before the community priority still stand (%s). Choosing a priority, or none, replaces them." % ", ".join(names), "tone": SP.TONE_CAUTION})

	var warnings: Array[String] = CommunityPriority.get_warnings(city, current, influence.store_rule)
	if not warnings.is_empty():
		blocks.append({"kind": "card", "title": "Before you lean on it", "tone": SP.TONE_CAUTION, "lines": warnings, "muted": ["Warnings only: families still decide, and nothing stops a choice."]})

	if current != CommunityPriority.NONE:
		blocks.append(get_backing_card(city, current))
		var views: Array = []
		for view: Dictionary in CommunityPriority.get_views(city, current):
			var reasons: Array = view["reasons"]
			var line: Dictionary = {"kind": "text", "text": "%s %s%s" % [city.get_household_label((view["household"] as Household).id), view["stance"], ": " + "; ".join(reasons.slice(0, 3)) if not reasons.is_empty() else ""], "muted": view["stance"] == CommunityPriority.INDIFFERENT}
			if view["stance"] == CommunityPriority.OPPOSES:
				line["tone"] = SP.TONE_CAUTION
			views.append(line)
		blocks.append({"kind": "expander", "id": "community_views", "title": "How each family sees it (%d)" % views.size(), "blocks": views})

	var others: Array = []
	for priority: String in CommunityPriority.ALL:
		if priority == current:
			continue
		var other_warnings: Array[String] = CommunityPriority.get_warnings(city, priority, influence.store_rule)
		others.append({"kind": "text", "text": "%s: backed %d%%%s" % [CommunityPriority.get_display_name(priority), roundi(CommunityPriority.get_backing(city, priority) * 100.0), "; " + other_warnings[0] if not other_warnings.is_empty() else ""], "muted": true})
	blocks.append({"kind": "expander", "id": "community_other_priorities", "title": "How the town would take the others", "blocks": others})
	return blocks

# The town's backing for its priority, families' stances, and what the priority has tipped.
static func get_backing_card(city: City, priority: String) -> Dictionary:
	var counts: Dictionary = {CommunityPriority.SUPPORTS: 0, CommunityPriority.INDIFFERENT: 0, CommunityPriority.OPPOSES: 0}
	for view: Dictionary in CommunityPriority.get_views(city, priority):
		counts[view["stance"]] = int(counts[view["stance"]]) + 1
	# Worked out afresh: the weekly figure families act on (get_town_backing) is cached on the town,
	# and a page must not set it.
	var backing: float = CommunityPriority.get_backing(city, priority)
	var lines: Array = ["%d support it, %d do not much mind, %d oppose it." % [counts[CommunityPriority.SUPPORTS], counts[CommunityPriority.INDIFFERENT], counts[CommunityPriority.OPPOSES]]]
	lines.append("What the town backs pulls on time families give freely, never on their choice of work.")
	var tipped: Array[String] = []
	for decision: String in SWAYED_NAMES.keys():
		var count: int = int(city.influence.swayed.get("%s:%s" % [priority, decision], 0))
		if count > 0:
			tipped.append("%d %s" % [count, SWAYED_NAMES[decision]])
	var muted: Array = ["Respected voices count double."]
	muted.append("Decisions it has tipped so far: " + (", ".join(tipped) if not tipped.is_empty() else "none yet"))
	var tone: String = SP.TONE_GOOD if backing >= 0.6 else SP.TONE_CAUTION if backing < 0.4 else SP.TONE_INFO
	return {"kind": "card", "title": "How the town takes it", "tag": "backed %d%%" % roundi(backing * 100.0), "tone": tone, "lines": lines, "muted": muted}

static func get_stores(city: City) -> Array:
	var influence: TownInfluence = city.influence
	var priorities: bool = influence.store_rule == TownInfluence.RULE_PRIORITIES
	var reserve: Dictionary = influence.get_protected_reserve()
	var reserve_parts: Array[String] = []
	for material: String in reserve.keys():
		reserve_parts.append("%d %s" % [int(reserve[material]), material])
	var lines: Array = ["Only families' projects that serve the community's priority may draw on the stores; the rest wait." if priorities else "Families' own projects may draw on the stores above what is kept back, whatever the priority."]
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
