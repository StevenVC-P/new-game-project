extends SceneTree

# Gameplay regression: the town the sidebar test founds (the same founding seed, the real game's
# founding with families leading) is played for a year by the stand-in player, and must come through
# it: its founding families still here, fed on the last day, and at least one of them in a proper
# home. Moved here from tests/town_sidebar_validation.gd, which checks the interface and sets the
# state it needs; a failure here is the simulation's, not the sidebar's.

const MainScript = preload("res://scripts/main.gd")
const StandInPlayerScript = preload("res://tests/sim/stand_in_player.gd")
const SidebarTest = preload("res://tests/town_sidebar_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	var main: Node2D = MainScript.new()
	main.use_authored_world = true
	root.add_child(main)
	main.rng.seed = SidebarTest.FOUNDING_SEED
	await _settle()
	var region: WorldMapData.Region = main.world_map_data.find_region_by_name("Meander Plains")
	main.world_map_view.request_region_entry(region.id)
	main.wait_for_neighbourhood_job()
	await _settle()
	var middle: Vector2 = Vector2(main.region_map_size) * 0.5
	var site: Vector2i = main.region_founding_sites[0]
	for tile: Vector2i in main.region_founding_sites:
		if Vector2(tile).distance_to(middle) < Vector2(site).distance_to(middle):
			site = tile
	main.set_pending_founding_tile(site)
	_check(main.found_player_city_at_pending_site(), "founding should open the town")
	main.simulation_clock.is_paused = true
	var city: City = main.cities[main.selected_city_index]
	var founders: Array = city.households.map(func(h: Household) -> String: return "/".join(CultureEffects.get_callings(h.values)))
	StandInPlayerScript.new().play(city, {}, 360)
	var work: Dictionary = {}
	for building: Building in city.buildings:
		if building.is_production_building() and building.assigned_household_id >= 0:
			work[building.type] = int(work.get(building.type, 0)) + 1
	print("Founded town after a year: founders %s | families %d, people %d | food %d (shortage %s) | tools %d | work %s" % [str(founders), city.households.size(), city.get_total_population(), int(city.resources["food"]), str(city.resources["food_shortage"]), int(city.resources["tools"]), str(work)])
	_check(city.households.size() >= EconomyBalance.FOUNDING_FAMILIES, "the town keeps its founding families through its first year (%d families)" % city.households.size())
	_check(city.resources["food_shortage"] != true, "the town is fed at the end of its first year (food %d)" % int(city.resources["food"]))
	var housed: bool = city.households.any(func(h: Household) -> bool: return city.buildings.any(func(b: Building) -> bool: return b.id == h.residence_building_id and b.is_house()))
	_check(housed, "a family lives in a proper home within the year")
	main.regional_terrain.wait_for_tasks()
	main.queue_free()
	await _settle()
	if failure_count > 0:
		push_error("Founded town regression failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Founded town regression passed.")
	quit()

func _settle() -> void:
	for _i in range(3):
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
