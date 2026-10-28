extends SceneTree

# The first stage loop's rules (docs/FIRST_STAGE_LOOP.md): each workplace gets its own upkeep
# grace when finished or upgraded; fields yield by season and winter lives on stores; felling is
# winter work.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_upkeep_grace_per_building()
	test_fields_yield_by_season()
	test_felling_is_winter_work()

	if failure_count > 0:
		push_error("First stage validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("First stage validation passed.")
	quit()

# A workplace finished late in the town's life still gets its full grace before it needs tools.
func test_upkeep_grace_per_building() -> void:
	var city: City = City.new("Grace Town", Vector2(6, 6), City.ROLE_PLAYER, 4)
	city.resources["food"] = 100000
	ConstructionTest.run_days(city, 200)
	city.resources["tools"] = 0
	city.add_building(Building.new(-1, "woodcutter", Vector2i(0, 0), Vector2i(2, 2)), city.households[0])
	var woodcutter: Building = city.buildings[-1]
	ConstructionTest.run_days(city, EconomyBalance.MAINTENANCE_GRACE_DAYS - 1)
	_check(woodcutter.maintenance_level == 100, "a workplace built on day 200 runs its first %d days without tools" % EconomyBalance.MAINTENANCE_GRACE_DAYS)
	ConstructionTest.run_days(city, 40)
	_check(woodcutter.maintenance_level < 100, "after its grace, a workplace without tools decays")
	city.add_building(Building.new(-1, "gatherer_camp", Vector2i(4, 0), Vector2i(2, 2)), city.households[1])
	var camp: Building = city.buildings[-1]
	camp.upkeep_grace_days = 0
	city.complete_upgrade(camp.id)
	_check(camp.upkeep_grace_days == EconomyBalance.MAINTENANCE_GRACE_DAYS, "an upgraded workplace starts a new grace")

# The harvest comes mostly in summer and autumn; over a year it is what it was.
func test_fields_yield_by_season() -> void:
	var city: City = City.new("Season Town", Vector2(6, 6), City.ROLE_PLAYER, 4)
	city.resources["food"] = 100000
	city.add_building(Building.new(-1, "farm", Vector2i(0, 0), Vector2i(3, 3)), city.households[0])
	var farm: Building = city.buildings[-1]
	var by_season: Array[int] = [0, 0, 0, 0]
	for day in range(1, Calendar.DAYS_PER_YEAR + 1):
		city.day_of_year = day
		city.resources["production_tick_count"] = day
		by_season[city.get_season_index()] += city.get_current_building_output_amount(farm)
	var year: int = by_season[0] + by_season[1] + by_season[2] + by_season[3]
	var flat: float = EconomyBalance.FARM_FOOD_PER_DAY * Calendar.DAYS_PER_YEAR
	print("[STAGE] a farm's food by season (spring, summer, autumn, winter): %s, %d in the year (flat would be about %d)" % [str(by_season), year, int(flat)])
	_check(by_season[2] > by_season[1] and by_season[1] > by_season[0] and by_season[3] < by_season[1], "autumn yields most, then summer; spring and winter little")
	_check(absf(float(year) - flat) < flat * 0.1, "a year's harvest is about what it was")

# Woodcutters fell faster in winter.
func test_felling_is_winter_work() -> void:
	var felled: Array[int] = []
	for season_day: int in [120, 300]:
		var city: City = ConstructionTest.make_city()
		city.logistics.ensure_ready()
		city.add_building(Building.new(-1, "woodcutter", Vector2i(52, 20), Vector2i(2, 2)))
		for _day in range(60):
			city.day_of_year = season_day
			city.tick()
		felled.append(city.woodland.felled_count)
	print("[STAGE] trees a woodcutter fells unmarked in 60 days: %d in summer, %d in winter" % [felled[0], felled[1]])
	_check(felled[1] > felled[0], "felling goes faster in winter")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
