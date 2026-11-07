extends SceneTree

# Stage C foundations (master roadmap Phase 1): the demographic record, the culture observer and
# the settlement's identity. Observing a town changes nothing (the same town played with and without
# observing it every day ends identical); the labour table and life stages account for every
# household and person; the culture's spreads, pairs and combinations agree with each other; a
# settlement keeps its heart and identity through a save.

const ConstructionTest = preload("res://tests/town_construction_validation.gd")

var failure_count: int = 0

func _init() -> void:
	call_deferred("run_all")

func run_all() -> void:
	test_observing_changes_nothing()
	test_the_labour_table_counts_everyone()
	test_the_culture_observer()
	test_settlement_identity()
	if failure_count > 0:
		push_error("Stage C foundations validation failed: " + str(failure_count) + " failure(s)")
		quit(1)
		return
	print("Stage C foundations validation passed.")
	quit()

func town() -> City:
	var city: City = ConstructionTest.make_city()
	city.influence.enabled = true
	city.social.set_enabled(true)
	city.resources["wood"] = 300
	city.resources["tools"] = 40
	return city

func test_observing_changes_nothing() -> void:
	var plain: City = town()
	var observed: City = town()
	for _day in range(720):
		plain.tick()
		observed.tick()
		TownDemographics.labour_table(observed)
		TownDemographics.life_stages(observed)
		TownDemographics.group(observed, "industry")
		CultureObserver.spread(observed)
		CultureObserver.pairs(observed)
		CultureObserver.top_combinations(observed, 5)
	_check(GameState.capture_city(plain) == GameState.capture_city(observed), "a town observed every day for two years ends exactly as one left alone")
	print("[STAGEC] after two years: %d households, %d people" % [observed.households.size(), observed.get_total_population()])

func test_the_labour_table_counts_everyone() -> void:
	var city: City = town()
	for _day in range(360):
		city.tick()
	var households: int = 0
	var people: int = 0
	var table: Dictionary = TownDemographics.labour_table(city)
	for industry: String in table:
		for occupation: String in table[industry]:
			_check(TownDemographics.industry_of(occupation) == industry, "%s belongs to %s" % [occupation, industry])
			households += int(table[industry][occupation]["households"])
			people += int(table[industry][occupation]["people"])
	_check(households == city.households.size() and people == city.get_total_population(), "the labour table counts every household and person (%d of %d, %d of %d)" % [households, city.households.size(), people, city.get_total_population()])
	var staged: int = 0
	for stage: String in TownDemographics.life_stages(city):
		staged += int(TownDemographics.life_stages(city)[stage]["households"])
	_check(staged == city.households.size(), "every household has a life stage")
	var grouped: int = 0
	for key: String in TownDemographics.group(city, "occupation"):
		grouped += (TownDemographics.group(city, "occupation")[key] as Array).size()
	_check(grouped == city.households.size(), "grouping by occupation holds every household once")
	print("[STAGEC] labour: ", table)

func test_the_culture_observer() -> void:
	var city: City = town()
	var spread: Dictionary = CultureObserver.spread(city)
	var pairs: Dictionary = CultureObserver.pairs(city)
	_check(not spread.is_empty(), "the founders hold values")
	var consistent: bool = true
	for key: String in pairs:
		var parts: PackedStringArray = key.split("|")
		consistent = consistent and int(pairs[key]) <= mini(int(spread[parts[0]]), int(spread[parts[1]]))
	_check(consistent, "no pair is held by more households than either of its values")
	var top: Array = CultureObserver.top_combinations(city, 3)
	var total: int = 0
	for entry: Array in CultureObserver.top_combinations(city, 1000):
		total += int(entry[1])
	_check(total == city.households.size() and top.size() <= 3, "every household carries one combination")

func test_settlement_identity() -> void:
	var city: City = town()
	_check(city.get_settlement_id(4096) == -1, "a town with no known site has no settlement identity")
	city.global_site = Vector2i(4100, 1400)
	_check(city.get_settlement_id(4096) == City.settlement_id_for(Vector2i(4, 1400), 4096), "a site past the date line is the same settlement as its wrapped tile")
	_check(City.settlement_id_for(Vector2i(5, 1400), 4096) != City.settlement_id_for(Vector2i(4, 1400), 4096) and City.settlement_id_for(Vector2i(4, 1401), 4096) != City.settlement_id_for(Vector2i(4, 1400), 4096), "different sites are different settlements")
	var restored: City = GameState.restore_city(GameState.capture_city(city))
	_check(restored.global_site == city.global_site, "the heart survives a save (%s)" % str(restored.global_site))

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
