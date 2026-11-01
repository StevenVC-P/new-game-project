extends SceneTree

# Replays a copy of a saved game's town (the owner's playtest autosave) under the four modes of
# occupation_check, and traces every family decision about work: what each family weighs when it
# chooses or reconsiders its work, whether it sees a shortage coming, and whether the community's
# priority tipped the decision (the same decision with the priority's ask taken out).
#
# Reads the save given; never writes it. The town alone is replayed: no neighbouring towns or trade
# routes, so traders and the world calendar's other effects are left out.
#   <godot> --headless --path . --script res://tests/sim/autosave_replay.gd -- --save=C:/path/copy.save --mode=both --days=360 > replay.log
# Options: --mode=existing|occupations|shortage|both, --days=N (360), --no-priority (clear the
# town's priority at the start, to compare).

const MODES: Dictionary = {
	"existing": ["occupations_first_three", "no_shortage_recognition", "no_survival_awareness"],
	"shortage": ["occupations_first_three", "no_survival_awareness"],
	"occupations": ["no_shortage_recognition"],
	"both": [],
}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var path: String = ""
	var mode: String = "both"
	var days: int = 360
	var clear_priority: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			path = argument.trim_prefix("--save=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--days="):
			days = int(argument.trim_prefix("--days="))
		elif argument == "--no-priority":
			clear_priority = true
	var state: Dictionary = SaveStore.new().read_state(path)
	if state.is_empty() or not state.has("cities"):
		_report("could not read a town from %s" % path)
		quit(1)
		return
	var index: int = int(state.get("selected_city_index", 0))
	var city: City = GameState.restore_city(state["cities"][index])
	var calendar: Calendar = Calendar.new()
	SaveCodec.restore(calendar, state["calendar"])
	for meta: String in MODES[mode]:
		city.set_meta(meta, true)
	if clear_priority:
		city.influence.set_priority(CommunityPriority.NONE)
	_report("MODE %s%s | day %d (%s) | priority %s | stores rule %s | wisdoms %s" % [mode, " (priority cleared)" if clear_priority else "", city.construction.day, calendar.get_formatted_date(), city.influence.priority, city.influence.store_rule, str(city.social.wisdoms)])
	describe_town(city, "start")
	var reviews_seen: int = 0
	var pending: Dictionary = {}
	var first_tool_work: Dictionary = {}
	var min_tools: int = int(city.resources["tools"])
	for day in range(days):
		# The day before families decide (the same week, so the same unknown): what each free family weighs.
		if (city.construction.day + 1) % FamilyInitiative.INTERVAL_DAYS == 1:
			pending = score_free_families(city)
		var month_before: int = calendar.current_month
		var season_before: String = calendar.get_current_season()
		calendar.advance_day()
		city.day_of_year = calendar.get_day_of_year()
		city.tick()
		if calendar.current_month != month_before:
			city.advance_household_lifecycle_month(index)
		if calendar.get_current_season() != season_before:
			city.advance_household_birth_rolls_season(calendar, index)
		city.record_resource_history()
		for id in pending.keys():
			var household: Household = city.get_household_by_id(int(id))
			if household != null and household.initiative_day == city.construction.day:
				_report("CHOICE day %d | family %d (%s) | %s | took: %s" % [city.construction.day, int(id), callings(household), pending[id], household.initiative_note])
		pending.clear()
		var log: Array = city.influence._work_review_log
		while reviews_seen < log.size():
			report_review(city, log[reviews_seen])
			reviews_seen += 1
		min_tools = mini(min_tools, int(city.resources["tools"]))
		if first_tool_work.is_empty() and FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS) > 0:
			for project: ConstructionProject in city.construction.projects:
				if FamilyInitiative.get_activity(project.building_type) == TownInfluence.ACTIVITY_TOOLS and project.kind == ConstructionProject.KIND_BUILDING:
					first_tool_work = {"day": city.construction.day, "family": project.requester_household_id, "type": project.building_type}
			for building: Building in city.buildings:
				if first_tool_work.is_empty() and FamilyInitiative.get_activity(building.type) == TownInfluence.ACTIVITY_TOOLS:
					first_tool_work = {"day": city.construction.day, "family": building.assigned_household_id, "type": building.type}
			_report("TOOL WORK day %d | %s" % [city.construction.day, str(first_tool_work)])
		if day % 30 == 29:
			_report("MONTH day %d | tools %d | shortage %.2f | food days %.0f | proper workplaces %d (short of upkeep %d) | tool producers %d | families %d, people %d" % [
				city.construction.day, int(city.resources["tools"]), FamilyInitiative.get_shortage(city, TownInfluence.ACTIVITY_TOOLS), FamilyInitiative.get_food_days(city),
				city.buildings.filter(func(b: Building) -> bool: return b.needs_maintenance()).size(), city.buildings.filter(func(b: Building) -> bool: return b.needs_maintenance() and b.maintenance_level < 50).size(),
				FamilyInitiative.count_producers(city, TownInfluence.ACTIVITY_TOOLS), city.households.size(), city.get_total_population()])
	describe_town(city, "end")
	_report("SUMMARY %s%s | days %d | lowest tools %d | first tool work %s | reviews %d (for a shortage %d) | changes %d | swayed by the priority %s" % [
		mode, " (priority cleared)" if clear_priority else "", days, min_tools, str(first_tool_work) if not first_tool_work.is_empty() else "none",
		city.influence.work_reviews, int(city.influence.work_triggers.get(OccupationReview.SHORTAGE, 0)), city.influence.work_changes, str(city.influence.swayed)])
	quit()

# Each free family's options this week, best first, with the reasons and the priority's part.
func score_free_families(city: City) -> Dictionary:
	var scored: Dictionary = {}
	for household: Household in city.households:
		if household.labor_capacity <= 0 or FamilyInitiative.has_own_project(city, household) or FamilyInitiative.get_holding(city, household) != null:
			continue
		if household.assigned_workers > 0 or city.construction.is_promised_to_workplace(household.id):
			continue
		var options: Array = []
		for occupation: String in FamilyInitiative.get_occupations(city):
			var desire: Dictionary = FamilyInitiative.get_work_desire(city, household, occupation)
			if not bool(desire["available"]):
				continue
			var noise: float = FamilyInitiative.get_noise(city, household, FamilyInitiative.get_choice_key(occupation))
			options.append({"occupation": occupation, "score": float(desire["score"]) + noise, "appeal": float(desire["appeal"]), "terms": desire["terms"]})
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
		var without: Array = options.duplicate()
		without.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) - float(a["appeal"]) > float(b["score"]) - float(b["appeal"]))
		var parts: Array[String] = []
		for option: Dictionary in options:
			parts.append("%s %.2f [%s]" % [option["occupation"], float(option["score"]), reasons(option["terms"])])
		var tipped: String = "" if options.is_empty() or without[0]["occupation"] == options[0]["occupation"] else " | WITHOUT THE PRIORITY: %s" % without[0]["occupation"]
		scored[household.id] = " ; ".join(parts) + tipped
	return scored

func report_review(city: City, entry: Dictionary) -> void:
	if entry.has("deferred"):
		_report("REVIEW day %d | family %d | deferred (another family is changing its work this month)" % [int(entry["day"]), int(entry["household"])])
		return
	var household: Household = city.get_household_by_id(int(entry["household"]))
	var margin: float = float(entry["margin"])
	var appeal: float = float(entry["appeal"])
	var stay_appeal: float = float(entry["stay_appeal"])
	var swayed: bool = CommunityPriority.is_swayed(margin, appeal, OccupationReview.CHANGE_MARGIN)
	var without: float = margin - appeal + stay_appeal
	_report("REVIEW day %d | family %d (%s) | triggers %s | on %s%s -> best %s | margin %.2f (needs %.1f; priority's part %+.2f, without it %.2f%s) | %s | for: %s | stays for: %s | note: %s" % [
		int(entry["day"]), int(entry["household"]), callings(household) if household != null else "?", str(entry["triggers"]), entry["from"], "" if bool(entry["proper"]) else " (by hand)", entry["to"], margin,
		OccupationReview.CHANGE_MARGIN, appeal - stay_appeal, without, ", TIPPED BY THE PRIORITY" if swayed else "",
		"CHANGED" if bool(entry["changed"]) else "stayed", "; ".join(entry["for"]), "; ".join(entry["against"]), household.work_review_note if household != null else ""])

func describe_town(city: City, label: String) -> void:
	_report("TOWN %s | day %d | tools %d | wood %d | food %d (%.0f days) | shortage of tools %.2f (use this season %.1f)" % [label, city.construction.day, int(city.resources["tools"]), int(city.resources["wood"]), int(city.resources["food"]), FamilyInitiative.get_food_days(city), FamilyInitiative.get_shortage(city, TownInfluence.ACTIVITY_TOOLS), FamilyInitiative.get_use(city, TownInfluence.ACTIVITY_TOOLS, FamilyInitiative.SHORTAGE_HORIZON_DAYS)])
	for household: Household in city.households:
		var holding: Building = FamilyInitiative.get_holding(city, household)
		var work: String = "no work" if holding == null else "%s%s" % [holding.type, "" if holding.is_tier0() else " (grace %d, upkeep %d%%)" % [holding.upkeep_grace_days, holding.maintenance_level]]
		var triggers: Array[String] = OccupationReview.get_triggers(city, household, holding) if holding != null and FamilyInitiative.get_activity(holding.type) != "" else ([] as Array[String])
		_report("  family %d (%s) | %s | at it since day %d | last review %d | due %s, due in danger %s | triggers %s | knows tools %.2f | risk %d | ambition %s | note: %s" % [
			household.id, callings(household), work, household.work_since, household.work_review_day, OccupationReview.is_due(city, household), OccupationReview.is_due_in_danger(city, household),
			str(triggers), HouseholdEconomy.get_level(household, "toolmaker"), HouseholdCharacter.get_axis(household, HouseholdCharacter.RISK), household.ambition, household.initiative_note.substr(0, 140)])

func callings(household: Household) -> String:
	return "/".join(CultureEffects.get_callings(household.values))

func reasons(terms: Array) -> String:
	return ", ".join(terms.map(func(t: Dictionary) -> String: return "%s %+.2f" % [t["reason"], float(t["weight"])]))

func _report(line: String) -> void:
	print("[REPLAY] " + line)
