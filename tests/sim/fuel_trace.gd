extends SceneTree

# Diagnostic (sprint S3 review): one divergence-check town replayed with a monthly line of its wood
# and winter fuel, to see when and why hearths go cold.
#   <godot> --headless --path . --script res://tests/sim/fuel_trace.gd -- --environment=forested --start=1 --years=3 > trace.log
# Filter for [FUEL].

const Divergence = preload("res://tests/sim/divergence_check.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var environment: String = "forested"
	var start: int = 1
	var years: int = 3
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--environment="):
			environment = argument.trim_prefix("--environment=")
		elif argument.begins_with("--start="):
			start = int(argument.trim_prefix("--start="))
		elif argument.begins_with("--years="):
			years = int(argument.trim_prefix("--years="))
	var site: Dictionary = (Divergence.classify(Divergence.collect_pool())[environment] as Array)[start]
	var city: City = Divergence.found(site, start)
	print("[FUEL] %s start %d seed %d | climate %s" % [environment, start, int(site["seed"]), str(city.site_profile.climate)])
	var scenario: Dictionary = Divergence.BASE.duplicate(true)
	var last: Dictionary = {}
	scenario["each_day"] = func(town: City, day: int, _player) -> void:
		var cold: int = town.households.filter(func(h: Household) -> bool: return h.cold_today).size()
		if day % 15 != 0 and cold == 0:
			return
		var flows: Dictionary = town._flows.get("wood", {})
		var line: String = "[FUEL] day %4d season %d | wood %5d | need/day %5.2f | cold families %d of %d | short days so far %d | woodcutters working %d | made %d used %d built %d burned %d" % [day, town.get_season_index(), int(town.resources["wood"]), TownFuel.get_daily_need(town), cold, town.households.size(), town.fuel_short_days,
			town.woodland.get_woodcutters().size(), int(flows.get("made", 0)), -int(flows.get("used", 0)), -int(flows.get("built", 0)), -int(flows.get("need_fuel", 0))]
		if cold > 0 and last.get("cold", 0) == 0 or day % 15 == 0:
			print(line)
		if day % 30 == 29:
			var holdings: Array[String] = []
			for household: Household in town.households:
				var holding: Building = FamilyInitiative.get_holding(town, household)
				holdings.append("%d:%s side %s %.0f%% woods %.2f note '%s'" % [household.id, holding.type if holding != null else "-", household.secondary_activity, household.secondary_share * 100.0, HouseholdEconomy.get_woods_land(town, household), household.economy_note.substr(0, 90)])
			print("[FUEL]   reviews %d changes %d deferred %d triggers %s | %s" % [town.influence.work_reviews, town.influence.work_changes, town.influence.work_deferred, str(town.influence.work_triggers), " ; ".join(holdings)])
		last["cold"] = cold
	StandInPlayerScript.new().play(city, scenario, years * Calendar.DAYS_PER_YEAR)
	for entry: Dictionary in city.influence._work_review_log:
		print("[FUEL] REVIEW %s" % JSON.stringify(entry))
	quit()
