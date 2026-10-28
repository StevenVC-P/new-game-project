extends SceneTree

# Village defense (docs/FIRST_STAGE_LOOP.md, milestone 5): bandits come to towns the roads reach,
# more to rich ones, and are seen before they come; a kept watch post and a called-up militia
# guard the town, and the militia's families leave their work while they serve. A band that meets
# too little guard takes a share of the stores, never the town's last month of food.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")
const TradeTest = preload("res://tests/trade_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_bandits_follow_roads_and_riches()
	test_unguarded_raid()
	test_watch_post_drives_a_band_off()
	test_militia()
	test_raids_come_sometimes()

	if failure_count > 0:
		push_error("Defense validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Defense validation passed.")
	quit()

func linked_city() -> City:
	var city: City = ConstructionTest.make_city()
	TradeTest.lay_road_north(city)
	return city

func band_coming(city: City, strength: int) -> void:
	city.defense.raid_day = city.construction.day + EconomyBalance.BANDIT_WARNING_DAYS
	city.defense.raid_strength = strength

func test_bandits_follow_roads_and_riches() -> void:
	var isolated: City = ConstructionTest.make_city()
	_check(isolated.defense.get_monthly_chance() == 0.0, "no band takes the road to a town no road reaches")
	var city: City = linked_city()
	city.resources["food"] = 100
	var poor: float = city.defense.get_monthly_chance()
	city.resources["food"] = 6000
	city.resources["tools"] = 200
	var rich: float = city.defense.get_monthly_chance()
	print("[DEFENSE] monthly chance of a band on a road: %.0f%% poor, %.0f%% rich" % [poor * 100.0, rich * 100.0])
	_check(poor > 0.0 and rich > poor, "rich stores tempt bands more")
	band_coming(city, 3)
	_check(ConstructionDisplayHelper.get_sidebar_lines(city).any(func(line: String) -> bool: return line.begins_with("Bandits on the road")), "a band is seen before it comes")

func test_unguarded_raid() -> void:
	var city: City = linked_city()
	city.resources["food"] = 1000
	city.resources["tools"] = 100
	city.resources["wood"] = 200
	for household: Household in city.households:
		household.contentment = 2
	band_coming(city, 3)
	city.defense.resolve_raid()
	_check(int(city.resources["tools"]) == 70 and int(city.resources["wood"]) == 140, "an unguarded band takes a share of the tools and wood: %d tools, %d wood" % [int(city.resources["tools"]), int(city.resources["wood"])])
	_check(int(city.resources["food"]) == 700, "and of the food: %d" % int(city.resources["food"]))
	_check(city.households.all(func(h: Household) -> bool: return h.contentment == 1), "families left undefended lose some contentment")
	_check(city.defense.raids == 1 and city.defense.raids_driven_off == 0 and not city.defense.is_band_coming(), "the raid is over and counted")
	# The last month of food is never taken.
	var lean: City = linked_city()
	lean.resources["food_consumption_rate"] = 20
	lean.resources["food"] = 650
	band_coming(lean, 5)
	lean.defense.resolve_raid()
	_check(int(lean.resources["food"]) >= int(20 * EconomyBalance.RAID_FOOD_KEPT_DAYS), "a raid leaves a month of food, left %d" % int(lean.resources["food"]))

func test_watch_post_drives_a_band_off() -> void:
	var city: City = linked_city()
	_check(city.construction.get_size(Building.BUILDING_WATCH_POST) == Vector2i.ONE, "a watch post stands on one tile")
	_check(city.construction.validate(Building.BUILDING_WATCH_POST, Vector2i(30, 20))["is_valid"] == true, "a watch post can stand on open ground")
	city.add_building(Building.new(-1, Building.BUILDING_WATCH_POST, Vector2i(30, 20), Vector2i.ONE), city.households[0])
	_check(city.defense.get_watch_posts_kept() == 1 and city.defense.get_guard() == EconomyBalance.WATCH_POST_GUARD, "a kept watch post guards the town")
	city.resources["food"] = 1000
	band_coming(city, EconomyBalance.WATCH_POST_GUARD)
	city.defense.resolve_raid()
	_check(int(city.resources["food"]) == 1000 and city.defense.raids_driven_off == 1, "a band that meets enough guard is driven off")
	_check(city.defense.last_raid_text.begins_with("Bandits driven off"), "the town is told")

func test_militia() -> void:
	var city: City = linked_city()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var shield: Household = city.households[3]
	shield.set_values(CultureValues.make_random_profile(rng, {CultureValues.CATEGORY_CALLING: ["shield"]}))
	city.add_building(Building.new(-1, "farm", Vector2i(28, 4), Vector2i(3, 3)), city.households[1])
	_check(not city.defense.call_militia(), "no call-up without a band on the road")
	band_coming(city, 4)
	_check(city.defense.call_militia(), "the militia can be called while a band comes")
	_check(city.defense.called_household_ids.size() == EconomyBalance.MILITIA_FAMILIES and city.defense.called_household_ids[0] == shield.id, "families of the shield answer first")
	_check(city.defense.get_guard() == EconomyBalance.MILITIA_FAMILIES * EconomyBalance.MILITIA_GUARD, "the militia guards the town")
	var farm: Building = city.buildings[0]
	if city.defense.is_called_up(farm.assigned_household_id):
		_check(city.get_current_building_output_amount(farm) == 0, "a called-up family's field goes unworked")
	city.defense.called_household_ids = [farm.assigned_household_id]
	_check(city.get_current_building_output_amount(farm) == 0, "a family serving in the militia leaves its work")
	city.defense.called_household_ids.clear()
	city.defense.call_militia()
	city.defense.resolve_raid()
	_check(city.defense.called_household_ids.is_empty(), "the militia goes home once the band is dealt with")

func test_raids_come_sometimes() -> void:
	var city: City = linked_city()
	var seen: int = 0
	for day in range(1, 360 * 4):
		city.construction.day = day
		city.resources["food"] = 3000
		var before: bool = city.defense.is_band_coming()
		city.defense.advance_day()
		if city.defense.is_band_coming() and not before:
			seen += 1
	print("[DEFENSE] bands seen on a road over four years with steady stores: %d" % seen)
	_check(seen >= 1 and seen <= 12, "bands come some years, not every month")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failure_count += 1
		push_error(message)
