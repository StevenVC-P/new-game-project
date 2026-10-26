extends SceneTree

# Data-level checks for the fixed world map. Rendering is checked visually with
# tests/visual/world_map_capture.gd.

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var world: WorldMapData = FixedWorldDefinition.build()
	print("[WORLD] built in %.0f ms: %d regions, %d settlements, %d roads, %d rivers" % [
		(Time.get_ticks_usec() - started_usec) / 1000.0, world.regions.size(), world.settlements.size(), world.roads.size(), world.rivers.size()])

	test_build_has_no_warnings(world)
	test_world_is_a_planet(world)
	test_every_region_has_land(world)
	test_settlements_stand_on_land_in_their_region(world)
	test_kingdoms_have_capitals_inside_their_borders(world)
	test_capital_status_is_independent_of_size(world)
	test_world_has_unclaimed_and_contested_frontier(world)
	test_every_authored_road_is_routed(world)
	test_wrapping_math(world)
	test_build_is_deterministic(world)
	test_region_seeds_are_stable(world)

	if failure_count > 0:
		push_error("World map validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return

	print("World map validation passed.")
	quit()

func test_build_has_no_warnings(world: WorldMapData) -> void:
	for warning: String in world.build_warnings:
		print("[WORLD] warning: ", warning)
	_check(world.build_warnings.is_empty(), "building the fixed world should produce no warnings")

func test_world_is_a_planet(world: WorldMapData) -> void:
	var land_cells: int = 0
	for region_id: int in world.region_grid:
		if region_id >= 0:
			land_cells += 1
	var land_fraction: float = float(land_cells) / float(world.region_grid.size())
	print("[WORLD] land fraction: %.2f" % land_fraction)
	_check(land_fraction > 0.2 and land_fraction < 0.45, "the planet should be mostly ocean with substantial land")
	_check(world.kingdoms.size() >= 6, "the world should start with several established kingdoms")
	_check(world.rivers.size() >= 10, "the world should have major river systems")

func test_every_region_has_land(world: WorldMapData) -> void:
	for region: WorldMapData.Region in world.regions:
		_check(region.cell_count > 0, "region should own land: " + region.name)
		_check(region.climate != "" and region.landscape != "", "region should have a geographic summary: " + region.name)

func test_settlements_stand_on_land_in_their_region(world: WorldMapData) -> void:
	for settlement: WorldMapData.Settlement in world.settlements:
		_check(world.region_id_at(settlement.position) == settlement.region_id or world.region_grid[_cell_index(world, settlement.position)] == settlement.region_id, "settlement region should match the map: " + settlement.name)
		_check(settlement.region_id >= 0, "settlement should stand in a region: " + settlement.name)
		var region: WorldMapData.Region = world.get_region(settlement.region_id)
		if region != null:
			_check(settlement.kingdom_id == region.owner_kingdom_id, "settlement allegiance should follow its region: " + settlement.name)

func test_kingdoms_have_capitals_inside_their_borders(world: WorldMapData) -> void:
	for kingdom: WorldMapData.Kingdom in world.kingdoms:
		var capital: WorldMapData.Settlement = world.get_settlement(kingdom.capital_settlement_id)
		_check(capital != null, "kingdom should have a capital: " + kingdom.name)
		if capital != null:
			_check(capital.is_capital, "capital should be flagged: " + capital.name)
			_check(capital.kingdom_id == kingdom.id, "capital should lie inside its kingdom: " + capital.name)
		_check(world.get_kingdom_regions(kingdom.id).size() >= 2, "kingdom should hold more than one region: " + kingdom.name)

func test_capital_status_is_independent_of_size(world: WorldMapData) -> void:
	var small_capital_found: bool = false
	var capital_outgrown: bool = false
	for kingdom: WorldMapData.Kingdom in world.kingdoms:
		var capital: WorldMapData.Settlement = world.get_settlement(kingdom.capital_settlement_id)
		if capital == null:
			continue
		if capital.tier <= WorldMapData.TIER_TOWN:
			small_capital_found = true
		for settlement: WorldMapData.Settlement in world.settlements:
			if settlement.kingdom_id == kingdom.id and settlement.population > capital.population:
				capital_outgrown = true
	_check(small_capital_found, "at least one capital should be a small settlement")
	_check(capital_outgrown, "at least one kingdom should have a city larger than its capital")

func test_world_has_unclaimed_and_contested_frontier(world: WorldMapData) -> void:
	var unclaimed: int = 0
	var contested: int = 0
	for region: WorldMapData.Region in world.regions:
		if region.is_unclaimed():
			unclaimed += 1
		if region.is_contested():
			contested += 1
	_check(unclaimed >= 10, "the world should leave unclaimed frontier regions")
	_check(contested >= 2, "some regions should be politically contested")

func test_every_authored_road_is_routed(world: WorldMapData) -> void:
	_check(world.roads.size() == FixedWorldDefinition.ROADS.size(), "every authored road should be routed")
	var classes: Dictionary = {}
	for road: WorldMapData.Road in world.roads:
		classes[road.road_class] = true
		var from_settlement: WorldMapData.Settlement = world.get_settlement(road.from_settlement_id)
		var to_settlement: WorldMapData.Settlement = world.get_settlement(road.to_settlement_id)
		_check(road.points.size() >= 2, "road should have geometry")
		_check(road.points[0].distance_to(from_settlement.position) < 0.01, "road should start at its settlement")
		_check(road.points[road.points.size() - 1].distance_to(to_settlement.position) < 0.01, "road should end at its settlement")
	_check(classes.size() == 3, "local, regional, and major roads should all exist")

func test_wrapping_math(world: WorldMapData) -> void:
	var width: float = world.world_size.x
	_check(is_equal_approx(world.wrap_x(-10.0), width - 10.0), "wrap_x should wrap negative x")
	_check(is_equal_approx(world.wrap_x(width + 5.0), 5.0), "wrap_x should wrap past the east edge")
	_check(is_equal_approx(world.wrapped_delta_x(width - 10.0, 10.0), 20.0), "shortest offset should cross the seam")
	var settlement: WorldMapData.Settlement = world.settlements[0]
	_check(world.region_id_at(settlement.position + Vector2(width, 0.0)) == world.region_id_at(settlement.position), "region lookup should wrap around the planet")

func test_build_is_deterministic(world: WorldMapData) -> void:
	var second: WorldMapData = FixedWorldDefinition.build()
	_check(second.region_grid == world.region_grid, "region partition should be identical on every build")
	_check(second.terrain_image.get_data() == world.terrain_image.get_data(), "terrain fields should be identical on every build")
	var same_roads: bool = second.roads.size() == world.roads.size()
	for i in range(mini(second.roads.size(), world.roads.size())):
		same_roads = same_roads and second.roads[i].points == world.roads[i].points
	_check(same_roads, "road geometry should be identical on every build")

func test_region_seeds_are_stable(world: WorldMapData) -> void:
	var seeds: Dictionary = {}
	for region: WorldMapData.Region in world.regions:
		_check(not seeds.has(region.regional_map_seed), "regional map seeds should be distinct: " + region.name)
		seeds[region.regional_map_seed] = true
	var frontier: WorldMapData.Region = world.find_region_by_name("Meander Plains")
	_check(frontier != null and frontier.regional_map_seed == absi("Meander Plains".hash()), "a region's map seed should come from its name, not build order")

func _cell_index(world: WorldMapData, world_pos: Vector2) -> int:
	var cell: Vector2i = world.political_cell_at(world_pos)
	return cell.y * world.political_size.x + cell.x

func _check(condition: bool, message: String) -> void:
	if condition:
		return

	failure_count += 1
	push_error(message)
