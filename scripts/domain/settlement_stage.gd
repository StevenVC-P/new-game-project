class_name SettlementStage
extends RefCounted

# The settlement's stage and chronicle (docs/SETTLEMENT_GROWTH_SCALE_MODEL.md, stages and the
# player-facing display; docs/FIRST_STAGE_LOOP.md, milestone 6). Read-only: it watches the town
# and changes nothing in it.
#
# - Founding Camp, until every family is housed; then Hamlet.
# - Hamlet, until all of: 10 or more households, a family formed in the town (generation 1+), one
#   full season with no food shortage and no one unsheltered, and the first winter survived; then
#   Village.
# Stage titles never drop back once earned (owner, 2026-10-19): a village that shrinks below
# village size keeps its title and is shown as declining. Events such as a raid or the first
# trade are chronicle entries, never requirements.

const CAMP: int = 0
const HAMLET: int = 1
const VILLAGE: int = 2
const NAMES: Array[String] = ["Founding Camp", "Hamlet", "Village"]
const SEASON_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]
const VILLAGE_HOUSEHOLDS: int = 10
# Days of food in store at the end of autumn that count as the first harvest surplus.
const SURPLUS_FOOD_DAYS: float = 60.0
const CHRONICLE_SHOWN: int = 2

var _city_ref: WeakRef = null
var city: City:
	get:
		return _city_ref.get_ref() as City
var stage: int = CAMP
var stage_days: Array[int] = [0, -1, -1]
# Entries: {"day": int (days since founding), "season": int, "text": String}; each first is
# written once (keys in `recorded`).
var chronicle: Array[Dictionary] = []
var recorded: Dictionary = {}
var winters_survived: int = 0
var stable_seasons: int = 0
var season_seen: int = -1
var season_clean: bool = true

func _init(owner: City) -> void:
	_city_ref = weakref(owner)

func advance_day() -> void:
	if city.households.is_empty():
		return
	var season: int = city.get_season_index()
	if season != season_seen:
		if season_seen >= 0:
			end_season(season_seen)
		season_seen = season
		season_clean = true
	if city.resources["food_shortage"] == true or int(city.resources.get("unsheltered_population", 0)) > 0:
		season_clean = false
	record_firsts()
	if stage == CAMP and all_housed():
		reach(HAMLET)
	if stage == HAMLET and get_village_conditions().values().all(func(met: bool) -> bool: return met):
		reach(VILLAGE)

func end_season(season: int) -> void:
	if season_clean:
		stable_seasons += 1
	if season == 3:
		winters_survived += 1
		record("first_winter", "The first winter survived")
	if season == 2 and food_days() >= SURPLUS_FOOD_DAYS:
		record("first_surplus", "The first harvest surplus")

func reach(new_stage: int) -> void:
	stage = new_stage
	stage_days[new_stage] = city.construction.day
	record("stage_%d" % new_stage, "Became a " + NAMES[new_stage].to_lower())

func record_firsts() -> void:
	if all_housed():
		record("housed", "Every family housed")
	for household: Household in city.households:
		if household.generation >= 1:
			record("new_family", "The first family formed here")
			break
	if city.trade.first_trade_day >= 0:
		record("first_trade", "The first trade, with " + city.trade.partner_name)
	if city.defense.raids_driven_off > 0:
		record("raid_driven_off", "Bandits driven off")
	if city.defense.raids > city.defense.raids_driven_off:
		record("first_raid", "Bandits raided the stores")
	if int(city.resources.get("departed_households", 0)) > 0:
		record("first_departure", "A family left in hard times")

func record(key: String, text: String) -> void:
	if recorded.has(key):
		return
	recorded[key] = true
	chronicle.append({"day": city.construction.day, "season": city.get_season_index(), "text": text})

func all_housed() -> bool:
	return city.households.all(func(h: Household) -> bool: return h.housing_status == Household.RESIDENCE_HOUSED)

func food_days() -> float:
	return float(city.resources["food"]) / maxf(1.0, float(city.resources["food_consumption_rate"]))

func get_village_conditions() -> Dictionary:
	return {
		"households": city.households.size() >= VILLAGE_HOUSEHOLDS,
		"new_family": recorded.has("new_family"),
		"stable_season": stable_seasons > 0,
		"winter": winters_survived > 0,
	}

# "Year 2, autumn": years counted from the founding.
static func format_entry_time(entry: Dictionary) -> String:
	return "Year %d, %s" % [maxi(0, int(entry["day"]) - 1) / Calendar.DAYS_PER_YEAR + 1, SEASON_NAMES[clampi(int(entry.get("season", 0)), 0, 3)]]

# "Hamlet", or "A declining village" for a village shrunk below village size.
func get_title() -> String:
	if stage == VILLAGE and city.households.size() < VILLAGE_HOUSEHOLDS:
		return "A declining village"
	return NAMES[stage]

# The sidebar, kept short (the panel is full): the stage, what stands between it and the next,
# and the latest chronicle entries. The game's top bar already names the stage and counts the
# people, so it leaves the first line out (with_title false).
func get_display_lines(with_title: bool = true) -> Array[String]:
	var lines: Array[String] = []
	var households: int = city.households.size()
	if with_title:
		lines.append("%s: %d households, %d people" % [get_title(), households, city.get_total_population()])
	if stage == CAMP:
		lines.append("Hamlet when every family is housed")
	elif stage == HAMLET:
		var met: Dictionary = get_village_conditions()
		lines.append("Village: %s winter  %s households %d/%d" % [tick(met["winter"]), tick(met["households"]), households, VILLAGE_HOUSEHOLDS])
		lines.append("%s a family formed  %s a stable season" % [tick(met["new_family"]), tick(met["stable_season"])])
	for entry: Dictionary in chronicle.slice(maxi(0, chronicle.size() - CHRONICLE_SHOWN)):
		lines.append("%s: %s" % [format_entry_time(entry), entry["text"]])
	return lines

static func tick(met: bool) -> String:
	return "[x]" if met else "[ ]"

# The whole chronicle, oldest first.
func get_chronicle_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in chronicle:
		lines.append("%s: %s" % [format_entry_time(entry), entry["text"]])
	return lines
