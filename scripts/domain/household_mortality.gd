class_name HouseholdMortality
extends RefCounted

# Fatal hardship (sprint S3b, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md; owner decision Q5): severe and
# sustained hunger or cold can kill. A month is severe for a family when it went hungry, or its
# hearth cold, on most of its days (EconomyBalance.HARDSHIP_SEVERE_DAYS). Only after
# HARDSHIP_SUSTAINED_MONTHS such months running does a family risk a death, never from one bad day
# or month, and the risk grows each further month, up to a cap: more for a larger family, and more
# for cold without a proper home. When conditions lift the count starts again. The roll is seeded
# from the town, the family and the month, so a loaded game dies as the original would have.
#
# Who dies: the most vulnerable first: a young child, the old in an old couple, an older or grown
# child, then a working adult. A family with no adult left has ended, and goes as an old couple's
# does (City.end_household): its work passes to an heir or stands vacant, its house is freed. Each
# death is logged with its cause and what the family had been doing about it, put in the chronicle,
# and noted for the family.
#
# Families try to survive before any of this through their existing reasoning (larders, the common
# store, sharing, taking up food or wood work, leaving); this only lets those attempts fail. The
# comparison meta "no_hardship_deaths" turns it off.

const HUNGER: String = "hunger"
const COLD: String = "cold"

static func is_on(city: City) -> bool:
	return not city.has_meta("no_hardship_deaths")

# Monthly (HouseholdMigration.advance_month), after hardship is counted and before the month's
# counts reset.
static func advance_month(city: City, city_index: int = 0) -> void:
	var month: int = int(city.resources.get("migration_month_index", 0))
	var ended: Array[Household] = []
	for household: Household in city.households:
		household.severe_hunger_months = household.severe_hunger_months + 1 if HouseholdMigration.get_short_days(city, household) >= EconomyBalance.HARDSHIP_SEVERE_DAYS else 0
		household.severe_cold_months = household.severe_cold_months + 1 if household.cold_days_this_month >= EconomyBalance.HARDSHIP_SEVERE_DAYS else 0
		if not is_on(city):
			continue
		var hunger: float = get_risk(household, household.severe_hunger_months, 1.0)
		var shelter: float = EconomyBalance.ROUGH_SHELTER_COLD_RISK if household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household) else 1.0
		var cold: float = get_risk(household, household.severe_cold_months, shelter)
		if hunger <= 0.0 and cold <= 0.0:
			continue
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([city.founding_seed, household.id, month, "hardship_death"])
		var roll: float = rng.randf()
		var cause: String = ""
		if roll < hunger:
			cause = HUNGER
		elif roll < hunger + (1.0 - hunger) * cold:
			cause = COLD
		if cause == "":
			continue
		if die(city, household, cause, city_index):
			ended.append(household)
	for household: Household in ended:
		city.end_household(household, "hardship_" + str(household.last_death_cause), city_index)

# A month's chance of a death in the family, from how many severe months it has had running.
static func get_risk(household: Household, months: int, factor: float) -> float:
	if months < EconomyBalance.HARDSHIP_SUSTAINED_MONTHS or household.total_population <= 0:
		return 0.0
	var steps: int = months - EconomyBalance.HARDSHIP_SUSTAINED_MONTHS + 1
	var size: float = float(household.total_population) / float(EconomyBalance.STARTING_HOUSEHOLD_POPULATION_FOR_RISK)
	return clampf(EconomyBalance.HARDSHIP_DEATH_CHANCE_PER_MONTH * float(steps) * size * factor, 0.0, EconomyBalance.HARDSHIP_DEATH_CHANCE_MAX)

# One member dies. Returns whether the family has ended (no adult left).
static func die(city: City, household: Household, cause: String, city_index: int) -> bool:
	var who: String = ""
	if household.young_children > 0:
		household.young_children -= 1
		who = "a young child"
	elif household.lifecycle_stage == Household.LIFECYCLE_OLD_COUPLE and household.working_adults > 0:
		household.working_adults -= 1
		who = "one of the old couple"
	elif household.older_children > 0:
		household.older_children -= 1
		who = "a child"
	elif household.adult_children > 0:
		household.adult_children -= 1
		who = "a grown child"
	else:
		household.working_adults = maxi(0, household.working_adults - 1)
		who = "a parent"
	household.total_population = household.working_adults + household.get_total_child_count()
	household.update_labor_capacity()
	household.recalculate_succession_pressure()
	household.last_death_cause = cause
	household.hardship_deaths += 1
	city.hardship_deaths[cause] = int(city.hardship_deaths.get(cause, 0)) + 1
	var months: int = household.severe_hunger_months if cause == HUNGER else household.severe_cold_months
	var doing: String = "gathering %s" % household.secondary_activity if household.secondary_activity != "" else "no side work"
	city.log_household_lifecycle_event(city_index, household.id, "HardshipDeath", "cause=%s who=%s months=%d larder=%.1f side_work=%s hardship=%d" % [cause, who.replace(" ", "_"), months, household.larder, doing.replace(" ", "_"), household.hardship_points])
	var whom: String = who.substr(0, 1).to_upper() + who.substr(1)
	city.settlement.record("death_%d_%d" % [household.id, city.construction.day], "%s of Household %d died of %s" % [whom, household.id, "hunger" if cause == HUNGER else "cold"])
	household.economy_note = "%s died of %s after %d hard months" % [whom, "hunger" if cause == HUNGER else "the cold", months]
	household.economy_note_day = city.construction.day
	return household.working_adults <= 0
