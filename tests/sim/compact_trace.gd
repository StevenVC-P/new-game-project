extends SceneTree

# Diagnostic (sprint S7): one divergence-check town under a compact, with a line (the first 40) for
# each family short on a day: its trade, its own food, its need, and the table. The figures are read
# after the day's work, so its own food includes what it made that day.
#   <godot> --headless --path . --script res://tests/sim/compact_trace.gd -- --environment=forested --start=0 --compact=private > trace.log

const Divergence = preload("res://tests/sim/divergence_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var environment: String = "forested"
	var start: int = 0
	var preset: String = "private"
	var days: int = 360
	var commons: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--environment="):
			environment = argument.trim_prefix("--environment=")
		elif argument.begins_with("--start="):
			start = int(argument.trim_prefix("--start="))
		elif argument.begins_with("--compact="):
			preset = argument.trim_prefix("--compact=")
		elif argument.begins_with("--days="):
			days = int(argument.trim_prefix("--days="))
		elif argument.begins_with("--commons="):
			commons = argument.trim_prefix("--commons=")
	var site: Dictionary = (Divergence.classify(Divergence.collect_pool())[environment] as Array)[start]
	var city: City = Divergence.found(site, start)
	TownCompact.set_preset(city, preset)
	if commons != "":
		TownCommons.set_reserve_days(city, int(commons.get_slice(":", 0)))
		TownCommons.set_grants(city, commons.get_slice(":", 1))
	var scenario: Dictionary = Divergence.BASE.duplicate(true)
	var printed: Array = [0]
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		# The month's end, before hardship is counted: each family's month (filter for [CTM]).
		if day % Calendar.DAYS_PER_MONTH == Calendar.DAYS_PER_MONTH - 2:
			for household: Household in town.households:
				print("[CTM] day %d household %d | short %d cold %d | hardship %d of %d | rough %d | own food %.0f | danger %s | commons %d reserve %d" % [day, household.id, household.short_days_this_month, household.cold_days_this_month, household.hardship_points, HouseholdMigration.get_departure_threshold(household), household.rough_housing_months, HouseholdEconomy.get_own_food(household), str(TownCommons.is_in_danger(town, household)), TownLedger.get_community(town, "food"), TownCommons.get_reserve(town)])
		for household: Household in town.households:
			var holding: Building = FamilyInitiative.get_holding(town, household)
			var trade: String = BuildingTiers.get_base_type(holding.type) if holding != null else "none"
			if household.short_today and printed[0] < 40:
				printed[0] += 1
				print("[CT] day %d household %d %s | own food %d owed %.2f need %.2f larder %.1f | table %d | holding %s worker %d" % [day, household.id, trade, TownLedger.get_share(household, "food"), household.share_food_owed, HouseholdEconomy.get_daily_need(household), household.larder, TownLedger.get_community(town, "food"), holding.type if holding != null else "-", holding.assigned_household_id if holding != null else -1])
	StandInPlayerScript.new().play(city, scenario, days)
	quit()
