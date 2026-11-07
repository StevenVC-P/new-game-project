extends SceneTree

# The scale benchmark (master roadmap Phase 1, decision 6): can the architecture hold millions of
# inhabitants, concentrated in a few large cities or distributed over many towns? Synthetic family
# records, no gameplay: each record is a group of like households (weight), with a settlement, an
# occupation, a life stage, a set of values (a bitmask), people per household and food in store,
# held as packed arrays. A month's pass: households make and eat food by occupation, the hungry part
# of a group splits off by a seeded draw, mature groups found new families that inherit values with
# variation, and identical records merge. Measured for each scenario: memory, the monthly pass,
# merging, how records grow over a year, save size, and the land-use record's size.
# Run: <godot> --headless --path . --script res://tests/benchmarks/population_scale_benchmark.gd > pop.log
#   (filter for [POP]; "-- --only=NAME" runs one scenario).
#
# Two record budgets bracket the design: weight 1 (every household its own record, today's game) and
# weighted (households of a settlement with the same occupation, stage and values share a record).

const PEOPLE_PER_HOUSEHOLD: float = 4.5
const OCCUPATIONS: int = 12
const STAGES: int = 5
const VALUE_BITS: int = 40
# Values a household holds, of VALUE_BITS (the catalog has 3-5 strong convictions, 1-2 defining).
const VALUES_HELD: int = 5
# Of every value set, a household inherits each value with this chance, else a neighbouring one.
const INHERIT_KEEP: float = 0.9
const FOOD_OCCUPATIONS: int = 4
# Food a food household makes in a month, in household-months of eating (each feeds about one other).
const FOOD_MADE: float = 2.0
# Distinct value sets a settlement's culture draws from: a few common, a long tail.
const CULTURE_SETS: int = 60
# The share of Edo-like density: people per regional tile (40 m square) of built land.
const PEOPLE_PER_REGIONAL_TILE: float = 96.0
# Below this many households a settlement is one record per household anyway.
const MONTHS: int = 12
const TIME_CAP_MSEC: int = 240000

# Scenarios: name, inhabitants, settlement sizes (people), weighted or not.
var scenarios: Array = [
	["1M concentrated, weight 1", 1000000, [800000, 50000, 50000, 50000, 50000], false],
	["1M concentrated, weighted", 1000000, [800000, 50000, 50000, 50000, 50000], true],
	["1M distributed, weight 1", 1000000, repeat(2500, 400), false],
	["1M distributed, weighted", 1000000, repeat(2500, 400), true],
	["10M concentrated, weighted", 10000000, repeat(1600000, 5) + repeat(40000, 50), true],
	["10M distributed, weighted", 10000000, repeat(5000, 2000), true],
	["10M distributed, weight 1", 10000000, repeat(5000, 2000), false],
]

var weight: PackedInt32Array
var settlement: PackedInt32Array
var occupation: PackedByteArray
var stage: PackedByteArray
var values: PackedInt64Array
var people: PackedFloat32Array
var food: PackedFloat32Array
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	call_deferred("run")

static func repeat(size: int, count: int) -> Array:
	var sizes: Array = []
	for i in range(count):
		sizes.append(size)
	return sizes

func say(line: String) -> void:
	print("[POP] " + line)

func run() -> void:
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	# Today's Household object, for comparison: memory per household as the game holds it.
	var before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var objects: Array[Household] = []
	var city: City = City.new("Probe", Vector2.ZERO, City.ROLE_PLAYER, 0)
	for i in range(20000):
		var household: Household = Household.new()
		household.set_values(CultureValues.make_random_profile(rng))
		objects.append(household)
	var per_household_kb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - before) / 1024.0 / 20000.0
	say("Household objects: %.1f KB each; 1M people (222,222 households) %.0f MB; 10M %.1f GB" % [per_household_kb, per_household_kb * 222222 / 1024.0, per_household_kb * 2222222 / 1048576.0])
	objects.clear()
	city = null
	say("scenario | settlements | records start -> after %d months | memory MB | MB per million people | month pass ms | merge ms | save MB | land tiles, packed MB, dictionary MB | households check" % MONTHS)
	for scenario: Array in scenarios:
		if only != "" and not str(scenario[0]).contains(only):
			continue
		measure(scenario)
	quit()

func measure(scenario: Array) -> void:
	var name: String = scenario[0]
	var inhabitants: int = scenario[1]
	var sizes: Array = scenario[2]
	var weighted: bool = scenario[3]
	rng.seed = hash(name)
	var memory_before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var started: int = Time.get_ticks_msec()
	populate(sizes, weighted)
	var start_records: int = weight.size()
	var households_start: int = total_households()
	var pass_ms: Array[float] = []
	var merge_ms: Array[float] = []
	for month in range(MONTHS):
		if Time.get_ticks_msec() - started > TIME_CAP_MSEC:
			break
		var t0: int = Time.get_ticks_usec()
		month_pass()
		pass_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		if weighted:
			var t1: int = Time.get_ticks_usec()
			merge()
			merge_ms.append((Time.get_ticks_usec() - t1) / 1000.0)
	var memory_mb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - memory_before) / 1048576.0
	var packed_mb: float = float(weight.size() * (4 + 4 + 1 + 1 + 8 + 4 + 4)) / 1048576.0
	var t2: int = Time.get_ticks_usec()
	var save_bytes: int = var_to_bytes([weight, settlement, occupation, stage, values, people, food]).size()
	var save_ms: float = (Time.get_ticks_usec() - t2) / 1000.0
	var land: Array = land_record_size(inhabitants)
	say("%s | %d | %d -> %d | %.1f (packed %.1f) | %.1f | %s | %s | %.1f (%.0f ms) | %d, %.2f, %.1f | %d -> %d households over %d months" % [name, sizes.size(), start_records, weight.size(), memory_mb, packed_mb, packed_mb / (inhabitants / 1000000.0), summary(pass_ms), summary(merge_ms), save_bytes / 1048576.0, save_ms, land[0], land[1], land[2], households_start, total_households(), pass_ms.size()])
	clear()

func clear() -> void:
	weight = PackedInt32Array()
	settlement = PackedInt32Array()
	occupation = PackedByteArray()
	stage = PackedByteArray()
	values = PackedInt64Array()
	people = PackedFloat32Array()
	food = PackedFloat32Array()

# Households for each settlement, drawn from its culture: a few common value sets and a long tail.
func populate(sizes: Array, weighted: bool) -> void:
	clear()
	for s in range(sizes.size()):
		var households: int = int(float(sizes[s]) / PEOPLE_PER_HOUSEHOLD)
		var culture: Array[int] = []
		for i in range(CULTURE_SETS):
			culture.append(random_values())
		if not weighted:
			for h in range(households):
				append(1, s, rng.randi_range(0, OCCUPATIONS - 1), rng.randi_range(0, STAGES - 1), culture[mini(CULTURE_SETS - 1, int(pow(rng.randf(), 2.0) * CULTURE_SETS))], PEOPLE_PER_HOUSEHOLD, 2.0)
			continue
		# Weighted: one record per occupation, stage and value set present, its weight the households in it.
		var groups: Dictionary = {}
		for h in range(households):
			var key: Vector3i = Vector3i(rng.randi_range(0, OCCUPATIONS - 1), rng.randi_range(0, STAGES - 1), mini(CULTURE_SETS - 1, int(pow(rng.randf(), 2.0) * CULTURE_SETS)))
			groups[key] = int(groups.get(key, 0)) + 1
		for key: Vector3i in groups:
			append(groups[key], s, key.x, key.y, culture[key.z], PEOPLE_PER_HOUSEHOLD, 2.0)

func random_values() -> int:
	var mask: int = 0
	while popcount(mask) < VALUES_HELD:
		mask |= 1 << rng.randi_range(0, VALUE_BITS - 1)
	return mask

static func popcount(mask: int) -> int:
	var count: int = 0
	while mask != 0:
		mask &= mask - 1
		count += 1
	return count

func append(w: int, s: int, o: int, st: int, v: int, p: float, f: float) -> void:
	weight.append(w)
	settlement.append(s)
	occupation.append(o)
	stage.append(st)
	values.append(v)
	people.append(p)
	food.append(f)

func total_households() -> int:
	var total: int = 0
	for w: int in weight:
		total += w
	return total

# A month: food made and eaten (in household-months), the hungry part of a group splitting off, and
# mature groups founding families whose values are inherited with variation.
func month_pass() -> void:
	var count: int = weight.size()
	# Food households eat one and sell the rest; the others share what is sold, with a seeded swing.
	var ration: float = float(FOOD_OCCUPATIONS) * (FOOD_MADE - 1.0) / float(OCCUPATIONS - FOOD_OCCUPATIONS)
	for i in range(count):
		var swing: float = rng.randf_range(-0.3, 0.3)
		food[i] += swing if occupation[i] < FOOD_OCCUPATIONS else ration + swing - 1.0
		if food[i] < 0.0 and weight[i] > 1:
			# Part of the group goes hungry: it splits off as its own record (a seeded draw).
			var hungry: int = rng.randi_range(1, weight[i] - 1)
			weight[i] -= hungry
			append(hungry, settlement[i], occupation[i], stage[i], values[i], people[i], food[i])
			food[i] = 0.0
		elif food[i] < 0.0:
			food[i] = 0.0
		# Life: a stage lasts about a year; mature groups found new families (1% a month).
		if rng.randf() < 1.0 / 12.0:
			stage[i] = (stage[i] + 1) % STAGES
		if stage[i] == 3 and weight[i] >= 1 and rng.randf() < 0.01 * weight[i]:
			var founded: int = maxi(1, int(round(weight[i] * 0.01)))
			append(founded, settlement[i], rng.randi_range(0, OCCUPATIONS - 1), 0, inherit(values[i]), PEOPLE_PER_HOUSEHOLD, 1.0)

func inherit(parent: int) -> int:
	var child: int = 0
	var held: int = parent
	while held != 0:
		var bit: int = held & -held
		held &= held - 1
		if rng.randf() < INHERIT_KEEP:
			child |= bit
		else:
			child |= 1 << rng.randi_range(0, VALUE_BITS - 1)
	return child

# Identical records (settlement, occupation, stage, values) merge, weights added and food averaged.
func merge() -> void:
	var index: Dictionary = {}
	var keep: PackedInt32Array = PackedInt32Array()
	for i in range(weight.size()):
		var key: Array = [settlement[i], occupation[i], stage[i], values[i]]
		var at: Variant = index.get(key, null)
		if at == null:
			index[key] = keep.size()
			keep.append(i)
			continue
		var j: int = keep[int(at)]
		var total: int = weight[j] + weight[i]
		food[j] = (food[j] * weight[j] + food[i] * weight[i]) / total
		weight[j] = total
	var w2: PackedInt32Array = PackedInt32Array()
	var s2: PackedInt32Array = PackedInt32Array()
	var o2: PackedByteArray = PackedByteArray()
	var st2: PackedByteArray = PackedByteArray()
	var v2: PackedInt64Array = PackedInt64Array()
	var p2: PackedFloat32Array = PackedFloat32Array()
	var f2: PackedFloat32Array = PackedFloat32Array()
	for i: int in keep:
		w2.append(weight[i])
		s2.append(settlement[i])
		o2.append(occupation[i])
		st2.append(stage[i])
		v2.append(values[i])
		p2.append(people[i])
		f2.append(food[i])
	weight = w2
	settlement = s2
	occupation = o2
	stage = st2
	values = v2
	people = p2
	food = f2

# The land-use record for this many people's built land: regional tiles, as packed bytes (5 counts a
# tile) and as today's Dictionary of Arrays (measured on a sample, scaled).
func land_record_size(inhabitants: int) -> Array:
	var tiles: int = int(inhabitants / PEOPLE_PER_REGIONAL_TILE)
	var packed_mb: float = tiles * (5 + 8) / 1048576.0
	var sample: int = mini(tiles, 200000)
	var before: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var record: Dictionary = {}
	for i in range(sample):
		record[Vector2i(i % 4096, i / 4096)] = [0, 0, 0, 0, 0]
	var dictionary_mb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - before) / 1048576.0 * float(tiles) / maxf(1.0, sample)
	record.clear()
	return [tiles, packed_mb, dictionary_mb]

static func summary(values_ms: Array[float]) -> String:
	if values_ms.is_empty():
		return "n/a"
	var sorted: Array[float] = values_ms.duplicate()
	sorted.sort()
	return "%.0f [%.0f-%.0f]" % [sorted[sorted.size() / 2], sorted[0], sorted[sorted.size() - 1]]
