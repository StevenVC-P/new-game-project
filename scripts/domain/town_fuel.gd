class_name TownFuel
extends RefCounted

# Winter fuel (sprint S3, docs/ECONOMIC_FOUNDATIONS_ROADMAP.md; owner decision D5). In the cold
# seasons every household's hearth burns wood from the common store, more the colder the season at
# the town's site, the more people it keeps warm, and the rougher its shelter (EconomyBalance, Winter
# fuel). So winter fuel competes with building and toolmaking for the town's wood, and a timber-poor
# cold site pays for it. When the store can't cover the day's need, every hearth goes short alike:
# the families lose some working days and, after enough cold days in a month, hardship builds as it
# does in hunger (HouseholdMigration). Families answer it through their own reasoning: the town's
# coming fuel need counts in the wood they judge it will use (FamilyInitiative.get_use), and a
# family whose hearth went cold gives time to gathering wood (HouseholdEconomy).
#
# Only a town with a town map heats; comparisons can switch it off with the meta "no_winter_fuel".

# What a season's warmth is at the town, 0 (bitter) to 1.
static func get_warmth(city: City, season: int) -> float:
	var climate: Dictionary = city.site_profile.climate if city.site_profile != null else LocalCityMapGenerator.DEFAULT_CLIMATE
	return clampf(float(climate.get("temperature", 0.55)) + EconomyBalance.SEASON_TEMPERATURE_OFFSET[season], 0.0, 1.0)

# 0 (no heating) to 1 (full cold).
static func get_coldness(city: City, season: int) -> float:
	return clampf((EconomyBalance.HEATING_BELOW_TEMPERATURE - get_warmth(city, season)) / EconomyBalance.HEATING_BELOW_TEMPERATURE, 0.0, 1.0)

static func is_on(city: City) -> bool:
	return not city.local_map.is_empty() and not city.has_meta("no_winter_fuel")

static func get_household_need(city: City, household: Household, season: int) -> float:
	var need: float = float(household.total_population) * EconomyBalance.FUEL_PER_PERSON_DAY * get_coldness(city, season)
	if household.housing_status != Household.RESIDENCE_HOUSED or city.is_household_in_rough_housing(household):
		need *= EconomyBalance.ROUGH_SHELTER_FUEL_FACTOR
	return need

static func get_daily_need(city: City, season: int = -1) -> float:
	if not is_on(city):
		return 0.0
	if season < 0:
		season = city.get_season_index()
	var total: float = 0.0
	for household: Household in city.households:
		total += get_household_need(city, household, season)
	return total

# The town's fuel need over the coming `days`, season by season from today, at today's families.
static func get_need_over(city: City, days: int) -> float:
	if not is_on(city):
		return 0.0
	var total: float = 0.0
	var day_of_year: int = city.get_day_of_year()
	var by_season: Array[float] = []
	for season in range(4):
		by_season.append(get_daily_need(city, season))
	for i in range(days):
		var day: int = posmod(day_of_year - 1 + i, Calendar.DAYS_PER_YEAR)
		total += by_season[clampi(day / Calendar.DAYS_PER_MONTH / 3, 0, 3)]
	return total

# The day's burning (City.tick, after eating). Whole units come from the store; the fraction is
# carried to the next day (City.fuel_carry).
static func burn(city: City) -> void:
	for household: Household in city.households:
		household.cold_today = false
	if not is_on(city):
		return
	var need: float = get_daily_need(city) + city.fuel_carry
	var whole: int = int(floor(need))
	city.fuel_carry = need - float(whole)
	if whole <= 0:
		return
	var burned: int = city.consume_need_bucket(GoodsNeedBucketHelper.BUCKET_FUEL, whole)
	city.fuel_burned += burned
	if burned >= whole:
		return
	# Short: the warmth missed today is gone, not owed, so nothing is carried; every hearth that needs
	# fuel goes cold today.
	city.fuel_carry = 0.0
	city.fuel_short_days += 1
	var season: int = city.get_season_index()
	for household: Household in city.households:
		if get_household_need(city, household, season) > 0.0:
			household.cold_today = true
			household.cold_days_this_month += 1

# Whether a cold family loses today's work: one day in COLD_SKIP_TICK_INTERVAL, on other days than
# hunger's (City.skips_work_today).
static func skips_work(city: City, household: Household) -> bool:
	if household == null or not household.cold_today:
		return false
	var interval: int = EconomyBalance.COLD_SKIP_TICK_INTERVAL
	return int(city.resources["production_tick_count"]) % interval == interval / 2

# Days of fuel the store holds at today's need (INF when nothing burns now).
static func get_fuel_days(city: City) -> float:
	var need: float = get_daily_need(city)
	if need <= 0.0:
		return INF
	return float(int(city.resources.get("wood", 0))) / need
