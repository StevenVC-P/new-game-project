extends SceneTree

# Diagnostic: one divergence-check town replayed under a compact, with a monthly line of its stores
# and exchange and each family's work and holdings, then every work review and first choice. It
# changes nothing in play, so two runs of the same town can be compared line by line.
#   <godot> --headless --path . --script res://tests/sim/town_trace.gd -- --environment=balanced --start=5 --compact=private --years=6 > trace.log
# Filter for [TRACE]. Add --meta=no_wood_plenty for the judgment before S5b.

const Divergence = preload("res://tests/sim/divergence_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

var metas: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var environment: String = "balanced"
	var start: int = 0
	var years: int = 6
	var compact: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--environment="):
			environment = argument.trim_prefix("--environment=")
		elif argument.begins_with("--start="):
			start = int(argument.trim_prefix("--start="))
		elif argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
		elif argument.begins_with("--compact="):
			compact = argument.trim_prefix("--compact=")
		elif argument.begins_with("--meta="):
			metas.assign(argument.trim_prefix("--meta=").split(","))
	var site: Dictionary = (Divergence.classify(Divergence.collect_pool())[environment] as Array)[start]
	var city: City = Divergence.found(site, start)
	for meta: String in metas:
		city.set_meta(meta, true)
	city.set_meta("trace_choices", [])
	if compact != "":
		TownCompact.set_preset(city, compact)
	print("[TRACE] %s start %d seed %d compact %s metas %s" % [environment, start, int(site["seed"]), compact, str(metas)])
	var scenario: Dictionary = Divergence.BASE.duplicate(true)
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		if day % Calendar.DAYS_PER_MONTH == Calendar.DAYS_PER_MONTH - 1:
			print_month(town, day)
	var result: Dictionary = StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	print("[TRACE] END off_the_ground %s people %d households %d" % [str(result["off_the_ground"]), city.get_total_population(), city.households.size()])
	for entry: Dictionary in city.influence._work_review_log:
		print("[TRACE] REVIEW %s" % JSON.stringify(entry))
	for entry: Dictionary in city.get_meta("trace_choices", []):
		var ranked: Array[String] = []
		for option: Dictionary in (entry["ranked"] as Array).slice(0, 3):
			ranked.append("%s %.2f for %s against %s" % [option["occupation"], float(option["score"]), str(option["for"]), str(option["against"])])
		print("[TRACE] CHOICE day %d household %d food coverage %.2f | %s" % [int(entry["day"]), int(entry["household"]), float(entry["coverage"]), " || ".join(ranked)])
	quit()

func print_month(town: City, day: int) -> void:
	var flows: Dictionary = town._flows
	var food: Dictionary = flows.get("food", {})
	var wood: Dictionary = flows.get("wood", {})
	print("[TRACE] day %4d y%d | food %5d comm %5d | wood %5d comm %5d | tools %4d | fuel-short %4d | made food %6d wood %5d built %4d used %4d burned %4d | market emergency %d help %d/%.0f | people %d" % [
		day, day / Calendar.DAYS_PER_YEAR + 1,
		int(town.resources["food"]), TownLedger.get_community(town, "food"), int(town.resources["wood"]), TownLedger.get_community(town, "wood"), int(town.resources["tools"]),
		town.fuel_short_days,
		int(food.get("made", 0)), int(wood.get("made", 0)), -int(wood.get("built", 0)), -int(wood.get("used", 0)), -int(wood.get("need_fuel", 0)),
		town.market_emergency_sales, town.commons_help_asked, town.commons_help_given, town.get_total_population()])
	var families: Array[String] = []
	for household: Household in town.households:
		var holding: Building = FamilyInitiative.get_holding(town, household)
		families.append("%d:%s n%d side %s %.0f%% food %d lard %.0f wood %d reach %d plenty %.2f tools %d short %d cold %d" % [
			household.id, BuildingTiers.get_base_type(holding.type) if holding != null else "-", household.total_population, household.secondary_activity, household.secondary_share * 100.0,
			TownLedger.get_share(household, "food"), household.larder, TownLedger.get_share(household, "wood"), FamilyInitiative.get_reachable_wood(town, household), FamilyInitiative.get_wood_plenty(town, household), TownLedger.get_share(household, "tools"), household.short_days_this_month, household.cold_days_this_month])
	print("[TRACE]   " + " ; ".join(families))
